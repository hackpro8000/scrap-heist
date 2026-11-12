#!/usr/bin/env python3
"""Talks to the running coordinator (coordinator.py) from this session.

  tools/coordinator/client.py status          # the run, machines up, tasks
  tools/coordinator/client.py machines        # what each machine is doing now
  tools/coordinator/client.py build <commit> [--no-upload] [--wait S] [--preview A,B] [--preview-only]
  tools/coordinator/client.py stop-machines   # standby machines end now
  tools/coordinator/client.py mint-workers <count>
  tools/coordinator/client.py open-workers    # seat the numbered machines now connected
  tools/coordinator/client.py numbered        # the numbers of the numbered machines connected, one line
  tools/coordinator/client.py machine-tokens <first> <last>  # no coordinator needed
                                              # tokens for a new pool of workers
                                              # (scripts/cloud-worker.sh), one
                                              # line each: <shard> <count> <token>
  tools/coordinator/client.py wait-machines [N] [--wait S]
                                              # returns once N machines are up
                                              # (default: all of the run)

While it waits, `build` prints a summary every 30 seconds and a line starting
STALL that names any machine that goes quiet (RECOVERED when it comes back).

`build` posts a task and prints each machine's result the moment it
arrives, then the upload's, and exits 0 when every machine built and every
object uploaded. Results land in .standby-results/<task>/ for
scripts/merge-shards.sh. With --preview, the machines also render those
models with modelkit; each machine's renders come back with its result,
often before the uploads end; the coordinator puts them in
art/models/<Name>/ (preview.png, views.png) and each is printed as it
lands. Exits 2 when no
coordinator is running.

From a coordinator on machine 1 (--relay-results) the results come over
the connection as files, are written here under the same paths, and an
uploaded task is merged here (scripts/merge-shards.sh).

If the connection drops mid-task (the coordinator restarting), `build`
reconnects for up to 60 s and watches the same task again; it exits 3 if
the task is unknown there, the coordinator stays gone, or a build has
used its 5 reconnects or 180 s of reconnecting.
"""
import argparse
import asyncio
import contextlib
import glob
import json
import os
import re
import subprocess
import sys
import time

import websockets

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wire  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
# The only repo files a relayed preview may write: what a local coordinator writes beside a model.
RELAYED_REPO_FILE = re.compile(r"art/models/[A-Za-z0-9_]+/(preview\.png|views\.png|previewed\.txt)")
# What a coordinator may name: task ids as it makes them, and a layout.
TASK_ID = re.compile(r"t[0-9]+-[0-9]+-[0-9]+")
LAYOUT_NAME = re.compile(r"[A-Za-z0-9_]+")
# Most a coordinator may relay for one task; past this the run fails.
MAX_RELAYED_FILES = 5_000
MAX_RELAYED_BYTES = 512 * 1024 * 1024
# Events about one task; any for another task is ignored.
TASK_EVENTS = {"progress", "shard", "uploaded", "uploading", "preview", "previews-done", "finished"}
STATE =os.path.expanduser("~/.cache/scrap-heist/coordinator.json")
# Made once by scripts/coordinator.sh key; never leaves this computer.
CONTROL_KEY = os.path.expanduser("~/.cache/scrap-heist/control-key")
CONTROL_NAMESPACE = "scrap-heist-control"
MAX_MESSAGE = 64 * 1024 * 1024


def control_url():
	if os.environ.get("COORDINATOR_CONTROL"):
		return os.environ["COORDINATOR_CONTROL"]
	if not os.path.isfile(STATE):
		return None
	state = json.load(open(STATE))
	# A remote coordinator (coordinator.sh attach) has no pid here.
	if state.get("remote"):
		return state["control"]
	try:
		os.kill(state["pid"], 0)
	except (OSError, KeyError):
		return None
	return state["control"]


class Control:
	"""A control connection with its request sent and any challenge
	answered; recv gives the coordinator's replies, the first one included."""

	def __init__(self, socket, first):
		self.socket = socket
		self.first = first

	async def recv(self):
		if self.first is not None:
			first, self.first = self.first, None
			return first
		return await self.socket.recv()


def sign(nonce):
	"""Signs a coordinator's challenge with this session's control key."""
	if not isinstance(nonce, str) or not re.fullmatch(r"[0-9a-f]{64}", nonce):
		raise SystemExit("the coordinator sent a challenge that is not a 64-character hex nonce; not signing it")
	if not os.path.isfile(CONTROL_KEY):
		raise SystemExit("the coordinator wants a signed answer and there is no key here (scripts/coordinator.sh key)")
	signed = subprocess.run(["ssh-keygen", "-q", "-Y", "sign", "-f", CONTROL_KEY, "-n", CONTROL_NAMESPACE],
		input=nonce.encode(), capture_output=True)
	if signed.returncode != 0:
		raise SystemExit(f"could not sign the challenge: {signed.stderr.decode().strip()}")
	return signed.stdout.decode()


async def connect(url, request, **options):
	"""Opens a control connection, sends the request and, when the
	coordinator was started with --control-key, answers its challenge.
	The caller closes it (Control.socket)."""
	socket = await websockets.connect(url, **options)
	try:
		await socket.send(json.dumps(request))
		first = await socket.recv()
		message = json.loads(first)
		if message.get("type") == "challenge":
			await socket.send(json.dumps({"type": "answer", "signature": sign(message["nonce"])}))
			first = await socket.recv()
	except BaseException:
		await socket.close()
		raise
	return Control(socket, first)


@contextlib.asynccontextmanager
async def control(url, request, **options):
	"""Every command talks through this (connect, closed on the way out)."""
	try:
		connection = await connect(url, request, **options)
	except websockets.ConnectionClosed:
		raise SystemExit("the coordinator closed the connection (is this session's control key the one it was started with?)")
	try:
		yield connection
	finally:
		await connection.socket.close()


RECONNECT_SECONDS = 60
# For a whole build: past either, a coordinator that keeps dropping is given up on.
MAX_RECONNECTS = 5
RECONNECT_BUDGET_SECONDS = 180


async def watch_again(url, task, seconds=RECONNECT_SECONDS):
	"""After the control connection drops mid-task: reconnects for up to
	`seconds` and watches the same task again. None if the task is
	unknown there or the coordinator stays gone."""
	print(f"control connection dropped; reconnecting for up to {seconds:.0f}s to watch task {task} again", flush=True)
	deadline = time.time() + seconds
	while time.time() < deadline:
		try:
			connection = await asyncio.wait_for(connect(url, {"type": "watch-task", "task": task}, max_size=MAX_MESSAGE), 10)
			answer = json.loads(await connection.recv())
		except (OSError, asyncio.TimeoutError, websockets.InvalidHandshake, websockets.ConnectionClosed):
			await asyncio.sleep(1)
			continue
		if answer.get("type") != "watching":
			print(f"could not watch task {task} again: {answer.get('text', answer)}", flush=True)
			await connection.socket.close()
			return None
		print(f"reconnected; watching task {task} again ({answer['up']} of {answer['count']} machines up)", flush=True)
		return connection
	print(f"the coordinator stayed unreachable for {seconds:.0f}s; giving up on task {task} (it may carry on there)", flush=True)
	return None


async def status(url):
	async with control(url, {"type": "status"}) as socket:
		answer = json.loads(await socket.recv())
	up = answer["up"]
	print(f"run={answer['run']} machines={answer['count']} up={len(up)} tasks={len(answer['tasks'])}")
	numbered, seats = answer.get("machines", []), answer.get("seats", {})
	if numbered or seats:
		waiting = [machine for machine in numbered if str(machine) not in seats]
		print(f"numbered machines connected={len(numbered)} seated={len(seats)} waiting={len(waiting)}"
			+ (f" ({' '.join(f'm{machine}' for machine in waiting)}; open-workers seats them)" if waiting else ""))
	return 0


async def mint_workers(url, count):
	"""One line per new worker: <shard> <count> <token>, for scripts/cloud-worker.sh."""
	async with control(url, {"type": "mint-workers", "count": count}) as socket:
		answer = json.loads(await socket.recv())
	if answer["type"] != "workers":
		print(answer.get("text", answer), file=sys.stderr)
		return 1
	print(f"pool {answer['pool']}", file=sys.stderr)
	for worker in answer["workers"]:
		print(f"{worker['shard']} {worker['count']} {worker['token']}")
	return 0


async def wait_machines(url, wanted, wait):
	async with control(url, {"type": "watch"}) as socket:
		while True:
			try:
				event = json.loads(await asyncio.wait_for(socket.recv(), wait))
			except asyncio.TimeoutError:
				print(f"no machine connected for {wait}s")
				return 1
			if event["type"] in ("machines", "machine"):
				need = wanted or event["count"]
				if event["count"]:
					print(f"{event['up']} of {event['count']} machines up", file=sys.stderr)
				if need and event["up"] >= need:
					return 0


async def numbered(url):
	async with control(url, {"type": "status"}) as socket:
		print(" ".join(str(machine) for machine in json.loads(await socket.recv()).get("machines", [])))
	return 0


async def seats_stale(url):
	async with control(url, {"type": "status"}) as socket:
		answer = json.loads(await socket.recv())
	numbered = answer.get("machines", [])
	return bool(numbered) and not answer["tasks"] and {str(machine) for machine in numbered} != set(answer.get("seats", {}))


async def open_workers(url):
	async with control(url, {"type": "open-workers"}) as socket:
		answer = json.loads(await socket.recv())
	if answer["type"] != "seated":
		print(answer.get("text", answer), file=sys.stderr)
		return 1
	machines = answer["machines"]
	print(f"{answer['pool']}: {len(machines)} machines seated: " + " ".join(f"m{machine}=S{shard}" for shard, machine in enumerate(machines, 1)))
	return 0


def machine_tokens(first, last):
	"""One line per numbered machine: m<n>, a tab, its lasting token, made
	from the worker key on this computer (scripts/coordinator.sh worker-key)."""
	path = os.path.expanduser("~/.cache/scrap-heist/worker-key")
	if not os.path.isfile(path):
		print("no worker key on this computer (scripts/coordinator.sh worker-key makes one)", file=sys.stderr)
		return 1
	key = open(path).read().strip()
	for machine in range(first, last + 1):
		print(f"m{machine}\t{wire.machine_token(key, machine)}")
	return 0


async def stop_machines(url):
	async with control(url, {"type": "stop-machines"}) as socket:
		print(json.loads(await socket.recv()))
	return 0


async def machines(url):
	"""One line per machine: what it is doing and when it last said so."""
	async with control(url, {"type": "status"}) as socket:
		answer = json.loads(await socket.recv())
	for shard in range(1, answer["count"] + 1):
		work = answer["progress"].get(str(shard))
		if shard not in answer["up"]:
			print(f"S{shard}: not connected")
		elif not work:
			print(f"S{shard}: idle, no task reported")
		elif work["stage"] == "done":
			print(f"S{shard}: done with {work['task']}, {answer['now'] - work['heard']:.0f}s ago")
		else:
			print(f"S{shard}: {work['stage']} {work['model']} {work['seconds']}s, log quiet {work['quiet']}s, "
				f"heard {answer['now'] - work['heard']:.0f}s ago: {work['line']}")
	return 0


TICK_SECONDS = 5
SUMMARY_SECONDS = 30
STEP_STALL_SECONDS = 180  # no new line in a machine's log
SILENT_STALL_SECONDS = 60  # no heartbeat from a machine (they come every 10s)


class Progress:
	"""What each machine last said about one task, turned into a summary
	line every SUMMARY_SECONDS and an alarm naming any machine that stalls."""

	def __init__(self, count):
		self.count = count
		self.started = time.time()
		self.machines = {}  # shard -> its latest progress event, plus when it came
		self.stalled = set()
		self.next_summary = self.started + SUMMARY_SECONDS

	def update(self, event):
		"""Returns whether this heartbeat is news: a heartbeat alone only
		proves the machine is alive, not that its work is moving."""
		before = self.machines.get(event["shard"])
		self.machines[event["shard"]] = {**event, "heard": time.time()}
		return not before or (before["stage"], before["line"]) != (event["stage"], event["line"])

	def stall(self, shard, now):
		work = self.machines.get(shard)
		if not work:
			waited = now - self.started
			return f"nothing heard in the {waited:.0f}s since the task was posted" if waited >= SILENT_STALL_SECONDS else None
		if work["stage"] == "done":
			return None
		unheard = now - work["heard"]
		if unheard >= SILENT_STALL_SECONDS:
			return f"no heartbeat for {unheard:.0f}s (was at {work['stage']} {work['model']})"
		quiet = work["quiet"] + unheard
		if quiet >= STEP_STALL_SECONDS:
			return f"no new log line for {quiet:.0f}s in {work['stage']} {work['model']}; last: {work['line']}"
		return None

	def tick(self):
		now = time.time()
		for shard in range(1, self.count + 1):
			problem = self.stall(shard, now)
			if problem and shard not in self.stalled:
				self.stalled.add(shard)
				print(f"STALL S{shard}: {problem}", flush=True)
			elif not problem and shard in self.stalled:
				self.stalled.discard(shard)
				print(f"RECOVERED S{shard}", flush=True)
		if now >= self.next_summary:
			self.next_summary = now + SUMMARY_SECONDS
			print(self.summary(now), flush=True)

	def summary(self, now):
		heading = f"[{now - self.started:4.0f}s]"
		if not self.machines:
			return f"{heading} nothing from any of {self.count} machines yet"
		counts = {}
		for work in self.machines.values():
			counts[work["stage"]] = counts.get(work["stage"], 0) + 1
		line = ", ".join(f"{counts[stage]} {stage}" for stage in sorted(counts))
		unheard = self.count - len(self.machines)
		if unheard:
			line += f", {unheard} unheard"
		if self.stalled:
			line += ", stalled " + " ".join(f"S{shard}" for shard in sorted(self.stalled))
		working = [(work["quiet"] + now - work["heard"], shard, work) for shard, work in self.machines.items() if work["stage"] != "done"]
		if working:
			quiet, shard, work = max(working, key=lambda entry: entry[0])
			line += f"; slowest S{shard} {work['stage']} {work['model']}, log quiet {quiet:.0f}s: {work['line']}"
		return f"{heading} {line}"


def relayed_path(task, header):
	"""Where a relayed result file goes, or None when its path is not one
	this session accepts: relative, no "..", and for the repo root only a
	model's preview files."""
	path = header.get("path")
	if not isinstance(path, str) or not path or header.get("task") != task or not TASK_ID.fullmatch(task or ""):
		return None
	if os.path.isabs(path) or "\\" in path or ".." in path.split("/") or os.path.normpath(path) != path:
		return None
	if header.get("root") == "results":
		base = os.path.join(ROOT, ".standby-results", task)
		target = os.path.join(base, path)
		# A symlinked folder must not lead out either.
		return target if os.path.realpath(target).startswith(os.path.realpath(base) + os.sep) else None
	if header.get("root") == "repo" and RELAYED_REPO_FILE.fullmatch(path):
		target = os.path.join(ROOT, path)
		# Exactly art/models/<Name>, so a symlinked model folder is refused.
		folder = os.path.join(os.path.realpath(os.path.join(ROOT, "art", "models")), path.split("/")[2])
		return target if os.path.realpath(os.path.dirname(target)) == folder else None
	return None


def write_relayed(task, message, received):
	"""Writes one relayed result file; returns its path, or None if refused.
	received counts this task's files and bytes against MAX_RELAYED_*."""
	header, data = wire.unpack(message)
	if received["files"] + 1 > MAX_RELAYED_FILES or received["bytes"] + len(data) > MAX_RELAYED_BYTES:
		if not received.get("over"):
			print(f"the coordinator relayed more than {MAX_RELAYED_FILES} files or {MAX_RELAYED_BYTES} bytes for task {task}; "
				"refusing the rest, this run FAILED", flush=True)
		received["over"] = True
		return None
	target = relayed_path(task, header)
	if not target:
		print(f"refused a relayed file: {header.get('root')} {header.get('path')!r} for task {header.get('task')}", flush=True)
		return None
	received["files"] += 1
	received["bytes"] += len(data)
	os.makedirs(os.path.dirname(target), exist_ok=True)
	with open(target, "wb") as file:
		file.write(data)
	return target


def merge_here(layout, out):
	"""The merge Coordinator.merge does, for results relayed from machine 1."""
	if not isinstance(layout, str) or not LAYOUT_NAME.fullmatch(layout) or not os.path.isfile(os.path.join(ROOT, "art", "src", "layouts", f"{layout}.luau")):
		return {"error": f"the coordinator named a layout that is not here: {str(layout)[:80]!r}"}
	shards = sorted(os.path.join(out, name) for name in os.listdir(out) if name.startswith("S"))
	result = subprocess.run(["scripts/merge-shards.sh", layout, *shards], cwd=ROOT, capture_output=True, text=True)
	if result.returncode != 0:
		return {"error": result.stderr.strip()[-300:]}
	return {"new_assets": [line for line in result.stdout.split() if re.fullmatch(r"[0-9]+", line)]}


async def build(url, ref, upload, wait, previews=(), layout=True):
	request = {"type": "build", "ref": ref, "upload": upload, "previews": list(previews), "build": layout}
	async with control(url, request, max_size=MAX_MESSAGE) as first:
		return await follow(url, ref, wait, first)


async def follow(url, ref, wait, first):
	"""build's event loop; when the connection drops mid-task it watches the
	task again on a new one (watch_again) and carries on."""
	socket = first
	try:
		failed = False
		task = None
		finished = None
		started = time.time()
		progress = None
		last_news = started
		received = {"files": 0, "bytes": 0}
		reconnects, reconnecting = 0, 0.0
		while True:
			try:
				message = await asyncio.wait_for(socket.recv(), TICK_SECONDS)
			except asyncio.TimeoutError:
				message = None
			except websockets.ConnectionClosed:
				if not task:
					print("the coordinator closed the connection before the task was posted", flush=True)
					return 3
				if reconnects >= MAX_RECONNECTS or reconnecting >= RECONNECT_BUDGET_SECONDS:
					print(f"the connection dropped {reconnects + 1} times ({reconnecting:.0f}s spent reconnecting); giving up on task {task}", flush=True)
					return 3
				reconnects += 1
				began = time.time()
				replacement = await watch_again(url, task, min(RECONNECT_SECONDS, RECONNECT_BUDGET_SECONDS - reconnecting))
				reconnecting += time.time() - began
				if not replacement:
					return 3
				await socket.socket.close()
				socket = replacement
				last_news = time.time()
				continue
			if isinstance(message, bytes):
				# A result file relayed from machine 1 (--relay-results).
				last_news = time.time()
				failed = not write_relayed(task, message, received) or failed
				continue
			event = json.loads(message) if message is not None else None
			if progress:
				progress.tick()
			if time.time() - last_news >= wait:
				print(f"no news for {wait}s; giving up waiting (the task carries on)", flush=True)
				return 1
			if event is None:
				continue
			kind = event["type"]
			# Only this build's task; the coordinator streams every task's events.
			if kind in TASK_EVENTS and (task is None or event.get("task") != task):
				continue
			if kind == "progress":
				if progress and progress.update(event):
					last_news = time.time()
				continue
			last_news = time.time()
			if kind == "error":
				print(event["text"])
				return 1
			if kind == "posted":
				if task is not None:
					continue
				if not isinstance(event.get("task"), str) or not TASK_ID.fullmatch(event["task"]):
					print(f"the coordinator posted a task id that is not one it makes: {str(event.get('task'))[:80]!r}; FAILED", flush=True)
					return 1
				task = event["task"]
				progress = Progress(event["count"])
				print(f"posted task {task} ({ref[:7]}) to {event['up']} of {event['count']} machines", file=sys.stderr)
			elif kind == "shard":
				summary = event["summary"].replace("\n", " ")
				print(f"S{event['shard']} after {event['seconds']}s: {summary}", flush=True)
				failed = failed or "status=DONE" not in event["summary"]
			elif kind == "machine" and event.get("gone"):
				print(f"S{event['shard']} dropped its connection (it reconnects and resumes)", flush=True)
			elif kind == "uploaded":
				state = f"asset {event['asset']}" if event.get("asset") else f"FAILED: {event.get('error')}"
				print(f"upload {event['done']}/{event['of']}: {event['label']} {state}", flush=True)
				failed = failed or not event.get("asset")
			elif kind == "preview":
				print(f"preview {event['name']} after {time.time() - started:.0f}s: {event['path']}", flush=True)
			elif kind == "previews-done" and event["left"] == 0 and finished is not None:
				return finished
			elif kind == "warning":
				print(f"warning: {event['text']}", flush=True)
			elif kind == "log" and ("FAILED" in event["text"] or "could not" in event["text"] or "error" in event["text"].lower()):
				print(f"S{event['shard']}: {event['text']}", flush=True)
			elif kind == "finished":
				# The results folder is always worked out here: relayed ones were
				# written here, and a coordinator on this computer writes the same one.
				out = os.path.join(ROOT, ".standby-results", task)
				if not event.get("relayed") and (not isinstance(event.get("out"), str) or os.path.realpath(event["out"]) != os.path.realpath(out)):
					print(f"the coordinator's results folder {str(event.get('out'))[:120]!r} is not {os.path.relpath(out)}; not reading it, FAILED", flush=True)
					return 1
				parts =[line for path in glob.glob(f"{out}/S*/parts.txt") for line in open(path).read().split()]
				twice = {part for part in parts if parts.count(part) > 1}
				if twice:
					print(f"parts built by more than one shard: {' '.join(sorted(twice)[:3])}")
					failed = True
				print(f"task {event['task']}: built in {event['built']}s, all done in {event['total']}s, "
					f"{len(parts)} parts, {event['objects']} objects handed over, {event['uploaded']} uploaded "
					f"(ending at {event['width']} at once); results in {os.path.relpath(out)}")
				for identity, error in event["failed"].items():
					print(f"upload of {identity} failed: {error}")
					failed = True
				merged = event.get("merged")
				if merged is None and event.get("merge_here") and not failed:
					merged = merge_here(event["layout"], out)
				if merged and merged.get("error"):
					print(f"merge failed: {merged['error']}")
					failed = True
				elif merged:
					given = merged.get("new_assets", [])
					new = [asset for asset in given if isinstance(asset, str) and re.fullmatch(r"[0-9]+", asset)] if isinstance(given, list) else []
					if not isinstance(given, list) or len(new) != len(given):
						print("the merge named new assets that are not asset ids; dropped them, FAILED", flush=True)
						failed = True
					print(f"merged into the game's tables; {len(new)} new assets need the game's permission")
					with open(os.path.join(out, "new-assets.txt"), "w") as file:
						file.write("\n".join(new) + ("\n" if new else ""))
				finished = 1 if failed else 0
				# Previews come after each machine's result; wait for the last.
				if not event.get("previews_waiting"):
					return finished
				print(f"waiting for previews from {event['previews_waiting']} machines", flush=True)
	finally:
		# The first connection is closed by control().
		if socket is not first:
			await socket.socket.close()


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("command", choices=["status", "machines", "build", "stop-machines", "wait-machines", "mint-workers", "open-workers", "machine-tokens", "numbered"])
	parser.add_argument("ref", nargs="?")
	parser.add_argument("last", nargs="?")
	parser.add_argument("--no-upload", action="store_true")
	parser.add_argument("--wait", type=int, default=600)
	parser.add_argument("--preview", default="", help="models to render, comma-separated")
	parser.add_argument("--preview-only", action="store_true", help="render the previews without building the layout")
	arguments = parser.parse_args()
	if arguments.command == "machine-tokens":
		if not (arguments.ref or "").isdigit() or not (arguments.last or arguments.ref).isdigit():
			parser.error("machine-tokens needs a first and last machine number")
		sys.exit(machine_tokens(int(arguments.ref), int(arguments.last or arguments.ref)))
	url = control_url()
	if not url:
		print("no coordinator running (scripts/coordinator.sh start)", file=sys.stderr)
		sys.exit(2)
	if arguments.command == "status":
		code = asyncio.run(status(url))
	elif arguments.command == "machines":
		code = asyncio.run(machines(url))
	elif arguments.command == "wait-machines":
		code = asyncio.run(wait_machines(url, int(arguments.ref or 0), arguments.wait))
	elif arguments.command == "stop-machines":
		code = asyncio.run(stop_machines(url))
	elif arguments.command == "open-workers":
		code = asyncio.run(open_workers(url))
	elif arguments.command == "numbered":
		code = asyncio.run(numbered(url))
	elif arguments.command == "mint-workers":
		if not (arguments.ref or "").isdigit():
			parser.error("mint-workers needs a count")
		code = asyncio.run(mint_workers(url, int(arguments.ref)))
	else:
		if not arguments.ref:
			parser.error("build needs a commit")
		previews = [name for name in arguments.preview.split(",") if name]
		# Numbered machines that connected since the seats were last given
		# out (or left) are seated first, so the build uses all that are there.
		if asyncio.run(seats_stale(url)):
			asyncio.run(open_workers(url))
			time.sleep(3)
		code = asyncio.run(build(url, arguments.ref, not arguments.no_upload, arguments.wait, previews, not arguments.preview_only))
	sys.exit(code)


if __name__ == "__main__":
	main()
