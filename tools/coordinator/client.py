#!/usr/bin/env python3
"""Talks to the running coordinator (coordinator.py) from this session.

  tools/coordinator/client.py status          # the run, the roster by name, queued units per task
  tools/coordinator/client.py machines        # what each machine is doing now
  tools/coordinator/client.py build <commit> [--no-upload] [--wait S] [--preview A,B] [--preview-only] [--units N]
  tools/coordinator/client.py stop-machines   # standby machines end now
  tools/coordinator/client.py clear-tasks     # drop open tasks (after ALERT STRANDED_TASK)
  tools/coordinator/client.py mint-workers <count>
  tools/coordinator/client.py open-workers    # no longer needed: says so and does nothing
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
`status` and `build` print abnormalities as one line each, starting ALERT
<KIND>: (CLEARED <KIND> when one resolves); the kinds are listed in
docs/plans/multi-machine.md, Alerts.

`build` posts a task, which the hub cuts into units (one per machine
connected, or --units N) and leases to machines as they come free
(docs/plans/multi-machine.md, Pull queue). Preview shares are sized by each
model's measured machine-seconds, kept in ~/.cache/scrap-heist/preview-seconds.json
and updated after every task. It prints each unit's result (S<i>, with the
machine that built it) the moment it arrives, and ALERT REDEALT when the
hub takes a unit back from a machine and gives it to another, then the upload's, and exits 0 when every machine built and every
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
import shutil
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
TASK_EVENTS = {"progress", "shard", "uploaded", "uploading", "preview", "previews-done", "finished", "redealt", "preview-share"}
# Measured machine-seconds per model's previews, for cost-sized shares.
PREVIEW_SECONDS = os.path.expanduser("~/.cache/scrap-heist/preview-seconds.json")
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


def alert(line):
	"""An ALERT or CLEARED line, alone on its line, at once."""
	print(line, flush=True)


def http_status(error):
	"""The HTTP status a refused websocket handshake answered with, or None
	(websockets 10 names it status_code, 13 keeps it on the response)."""
	code = getattr(error, "status_code", None)
	return code or getattr(getattr(error, "response", None), "status_code", None)


@contextlib.asynccontextmanager
async def control(url, request, **options):
	"""Every command talks through this (connect, closed on the way out)."""
	try:
		connection = await connect(url, request, **options)
	except websockets.ConnectionClosed:
		raise SystemExit("the coordinator closed the connection (is this session's control key the one it was started with?)")
	except (OSError, asyncio.TimeoutError, websockets.InvalidHandshake) as error:
		code = http_status(error)
		answered = f"answered HTTP {code}" if code else f"could not be reached ({error})"
		alert(f"ALERT TUNNEL_DOWN: the coordinator's control address {url} {answered} "
			"| machine 1's tunnel or coordinator is down; check the run (scripts/standby-status.sh) and start a new one if it stays down")
		raise SystemExit(2)
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
	roster = answer.get("roster", [])
	if roster:
		print("roster: " + " ".join(f"{entry['name']}={roster_state(entry)}" for entry in roster))
	for task, queued in answer.get("queues", {}).items():
		state = answer.get("task_states", {}).get(task, {})
		print(f"task {task}: {state.get('done', 0)} of {state.get('count', '?')} units done, {state.get('leased', 0)} leased, {queued} queued")
	for line in status_alerts(answer):
		alert(line)
	return 0


STRANDED_AGE_SECONDS = 60  # a task younger than this may not have heard from its machines yet


def roster_state(entry):
	"""idle, stopping, S<i>@<task> for a unit, or gone-<N>s."""
	if entry.get("state") == "gone":
		return f"gone-{entry.get('gone_for', 0)}s" + (f"(S{entry['shard']})" if entry.get("shard") else "")
	if entry.get("state") == "unit":
		return f"S{entry.get('shard')}@{entry.get('task')}"
	return entry.get("state", "?")


def status_alerts(answer):
	"""The ALERT lines a status answer calls for: STRANDED_TASK, SHORT, LIFETIME."""
	now = answer["now"]
	lines = []
	states = answer.get("task_states", {})
	# Stranded: units wait in a queue and no machine is connected to take them.
	stranded = [task for task, queued in answer.get("queues", {}).items() if queued > 0
		and states.get(task, {}).get("age", STRANDED_AGE_SECONDS) >= STRANDED_AGE_SECONDS]
	if stranded and not answer["up"]:
		lines.append(f"ALERT STRANDED_TASK: {len(stranded)} open tasks ({' '.join(stranded)}) have queued units and no machine is connected "
			"| start machines (they take the units as they connect), or clear them with: tools/coordinator/client.py clear-tasks")
	started = answer.get("run_started")
	github_up = answer.get("github_up", 0)
	if started and answer["count"] and now - started >= SHORT_SECONDS and github_up < answer["count"]:
		lines.append(f"ALERT SHORT: {github_up} of {answer['count']} machines of run {answer['run']} connected {now - started:.0f}s after the run's first "
			"| check the missing jobs in the run's log (gh run view); the queue works with what is up, or start a new run")
	ending = lifetime_alert(answer, now)
	if ending:
		lines.append(ending)
	return lines


LIFETIME_WARN_SECONDS = 15 * 60


def lifetime_alert(info, now):
	"""ALERT LIFETIME when the hub ends within 15 minutes, by its idle or
	its max limit; None when it doesn't or the hub doesn't know its limits."""
	ends = []
	if info.get("idle_minutes") and info.get("last_active"):
		ends.append((info["last_active"] + info["idle_minutes"] * 60, f"{info['idle_minutes']}m idle limit"))
	if info.get("max_minutes") and info.get("hub_started"):
		ends.append((info["hub_started"] + info["max_minutes"] * 60, f"{info['max_minutes']}m max limit"))
	if not ends:
		return None
	end, limit = min(ends)
	left = end - now
	if left > LIFETIME_WARN_SECONDS:
		return None
	advice = "post a task to restart its idle clock" if "idle" in limit else "start a new run (scripts/standby-start.sh) before it ends"
	return f"ALERT LIFETIME: the hub ends in {max(0, left) / 60:.0f}m ({limit}) | {advice}"


async def clear_tasks(url):
	async with control(url, {"type": "clear-tasks"}) as socket:
		answer = json.loads(await socket.recv())
	if answer.get("type") != "cleared":
		print(answer.get("text", answer), file=sys.stderr)
		return 1
	print(f"cleared {len(answer['tasks'])} tasks: {' '.join(answer['tasks'])}")
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


def open_workers():
	"""Kept so scripts that call it still work: there are no seats any more."""
	print("open-workers: nothing to do; numbered machines take units from the queue as soon as they connect", file=sys.stderr)
	return 0


def model_bytes(name):
	path = os.path.join(ROOT, "art", "models", name, "model.luau")
	return os.path.getsize(path) if os.path.isfile(path) else 0


def load_preview_seconds():
	try:
		known = json.load(open(PREVIEW_SECONDS))
	except (OSError, ValueError):
		return {}
	if not isinstance(known, dict):
		return {}
	return {name: float(seconds) for name, seconds in known.items()
		if isinstance(seconds, (int, float)) and not isinstance(seconds, bool) and seconds > 0}


def preview_weights(previews, known=None):
	"""Each model's expected machine-seconds: measured if known; else its
	model.luau's bytes at the median seconds-per-byte of the known models
	(or the median seconds when it has no file). Empty when nothing is known:
	the hub then shares equally."""
	known = load_preview_seconds() if known is None else known
	if not known:
		return {}
	middle = lambda values: sorted(values)[len(values) // 2] if values else None
	rate = middle([seconds / model_bytes(name) for name, seconds in known.items() if model_bytes(name)])
	typical = middle(list(known.values()))
	weights = {}
	for name in (name.rstrip("!") for name in previews):
		if name in known:
			weights[name] = known[name]
		elif rate and model_bytes(name):
			weights[name] = model_bytes(name) * rate
		else:
			weights[name] = typical
	return {name: round(weight, 3) for name, weight in weights.items()}


def save_preview_seconds(shares):
	"""shares: (model, unit name) -> machine-seconds one unit spent on it.
	Each model's total replaces what was known."""
	totals = {}
	for (name, _unit), seconds in shares.items():
		totals[name] = totals.get(name, 0.0) + seconds
	totals = {name: round(seconds, 1) for name, seconds in totals.items() if seconds > 0}
	if not totals:
		return
	known = load_preview_seconds()
	known.update(totals)
	os.makedirs(os.path.dirname(PREVIEW_SECONDS), exist_ok=True)
	with open(PREVIEW_SECONDS + ".new", "w") as file:
		json.dump(known, file, indent=1, sort_keys=True)
	os.replace(PREVIEW_SECONDS + ".new", PREVIEW_SECONDS)
	print(f"preview machine-seconds kept: {' '.join(f'{name}={seconds}' for name, seconds in sorted(totals.items()))}", flush=True)


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
	for entry in answer.get("roster", []):
		name = entry["name"]
		work = answer["progress"].get(name)
		if entry["state"] != "unit" or not work:
			print(f"{name}: {roster_state(entry)}")
			continue
		print(f"{name}: S{entry['shard']} of {entry['task']}: {work['stage']} {work['model']} {work['seconds']}s, log quiet {work['quiet']}s, "
			f"heard {answer['now'] - work['heard']:.0f}s ago: {work['line']}")
	for task, queued in answer.get("queues", {}).items():
		print(f"task {task}: {queued} units queued")
	return 0


TICK_SECONDS = 5
SUMMARY_SECONDS = 30
STEP_STALL_SECONDS = 180  # no new line in a machine's log
SILENT_STALL_SECONDS = 60  # no heartbeat from a machine (they come every 10s)
WEDGED_SECONDS = 300  # the hub's default: a unit quiet this long is re-dealt (ALERT WEDGED warns at 80%)
SILENT_REDEAL_SECONDS = 120  # the hub's default: a machine unheard this long loses its unit
SHORT_SECONDS = 120  # fewer machines than the run asked for, this long after: ALERT SHORT
ALL_FAILED_SECONDS = 30  # every shard failing within this: ALERT ALL_FAILED
LOW_GB = 2  # free disk or available memory under this: ALERT LOW_RESOURCES


class Progress:
	"""What each machine last said about one task, turned into a summary
	line every SUMMARY_SECONDS, an alarm naming any machine that stalls,
	and ALERT lines (each once, CLEARED when it resolves)."""

	def __init__(self, count, up=None, lifetime=None):
		self.count = count  # units
		self.up = count if up is None else up
		self.lifetime = lifetime or {}
		# The GitHub run's size and its machines up (ALERT SHORT), and when the
		# hub takes a lease back (ALERT WEDGED warns before it does).
		self.run_count = self.lifetime.get("run_count") or 0
		self.github_up = self.lifetime.get("github_up") or 0
		leases = self.lifetime.get("lease_seconds") or {}
		self.silent = leases.get("silent") or SILENT_REDEAL_SECONDS
		self.wedged = leases.get("wedged") or WEDGED_SECONDS
		self.started = time.time()
		# The hub's clock may differ from this one; lifetime times are read against it.
		self.clock_offset = self.lifetime.get("now", self.started) - self.started
		self.machines = {}  # shard -> its latest progress event, plus when it came
		self.stalled = set()
		self.raised = set()  # (kind, shard or None) of alerts printed and not cleared
		self.failed = {}  # shard -> seconds after posting it failed
		self.reason = ""  # the first failure line a machine reported
		self.next_summary = self.started + SUMMARY_SECONDS

	def flag(self, key, line):
		"""Prints an ALERT once per occurrence."""
		if key not in self.raised:
			self.raised.add(key)
			alert(line)

	def unflag(self, key, line):
		if key in self.raised:
			self.raised.discard(key)
			alert(line)

	def shard_failed(self, shard, seconds, summary):
		self.failed[shard] = seconds
		if len(self.failed) < self.count or max(self.failed.values()) > ALL_FAILED_SECONDS:
			return
		self.flag(("ALL_FAILED", None), f"ALERT ALL_FAILED: {self.count} shards, first reason: {self.reason or summary} "
			"| fix the cause (a bad ref, a missing tool, a broken commit) before posting again")

	def redealt(self, event):
		"""The hub took a unit back and gave it to another machine."""
		shard = event.get("shard")
		alert(f"ALERT REDEALT: S{shard} from {event.get('from')} to {event.get('to')}: {event.get('reason')} "
			"| nothing to do; if one machine keeps losing units, restart it")
		self.machines.pop(shard, None)
		self.stalled.discard(shard)
		self.unflag(("WEDGED", shard), f"CLEARED WEDGED: S{shard} re-dealt to {event.get('to')}")

	def check_alerts(self, now):
		for shard in range(1, self.count + 1):
			work = self.machines.get(shard)
			if not work:
				continue
			unheard = now - work["heard"]
			quiet = work.get("quiet", 0) + unheard
			on = f"S{shard} on {work.get('machine', '?')}"
			if work["stage"] != "done" and (unheard >= self.silent * 0.75 or quiet >= self.wedged * 0.8):
				self.flag(("WEDGED", shard), f"ALERT WEDGED: {on} unheard for {unheard:.0f}s, log quiet {quiet:.0f}s at {work['stage']} {work['model']} "
					f"| the hub re-deals it at {self.silent:.0f}s unheard or {self.wedged:.0f}s quiet; nothing to do unless it repeats")
			elif work["stage"] == "done" or (unheard < self.silent * 0.75 and quiet < self.wedged * 0.8):
				self.unflag(("WEDGED", shard), f"CLEARED WEDGED: {on} moving again")
			low = [f"{work[field]} GB {name}" for field, name in (("disk_gb", "disk free"), ("memory_gb", "memory available"))
				if isinstance(work.get(field), (int, float)) and work[field] < LOW_GB]
			if low:
				self.flag(("LOW_RESOURCES", shard), f"ALERT LOW_RESOURCES: S{shard} has {', '.join(low)} "
					"| expect its build to fail; restart it if it does")
			else:
				self.unflag(("LOW_RESOURCES", shard), f"CLEARED LOW_RESOURCES: S{shard} has room again")
		if self.run_count and now - self.started >= SHORT_SECONDS and self.github_up < self.run_count:
			self.flag(("SHORT", None), f"ALERT SHORT: {self.github_up} of the run's {self.run_count} GitHub machines connected {now - self.started:.0f}s after posting "
				"| the queue goes on with the machines that are up; check the missing jobs (gh run view) or start a new run")
		elif self.github_up >= self.run_count:
			self.unflag(("SHORT", None), f"CLEARED SHORT: all {self.run_count} GitHub machines connected")
		ending = lifetime_alert(self.lifetime, now + self.clock_offset)
		if ending:
			self.flag(("LIFETIME", None), ending)

	def update(self, event):
		"""Returns whether this heartbeat is news: a heartbeat alone only
		proves the machine is alive, not that its work is moving."""
		before = self.machines.get(event["shard"])
		self.machines[event["shard"]] = {**event, "heard": time.time()}
		return not before or (before["stage"], before["line"]) != (event["stage"], event["line"])

	def stall(self, shard, now):
		work = self.machines.get(shard)
		# A unit not heard from yet may simply be queued.
		if not work or work["stage"] == "done":
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
				print(f"STALL S{shard} ({self.machines[shard].get('machine', '?')}): {problem}", flush=True)
			elif not problem and shard in self.stalled:
				self.stalled.discard(shard)
				print(f"RECOVERED S{shard}", flush=True)
		self.check_alerts(now)
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
			line += f", {unheard} not started"
		if self.stalled:
			line += ", stalled " + " ".join(f"S{shard}" for shard in sorted(self.stalled))
		working = [(work["quiet"] + now - work["heard"], shard, work) for shard, work in self.machines.items() if work["stage"] != "done"]
		if working:
			quiet, shard, work = max(working, key=lambda entry: entry[0])
			line += f"; slowest S{shard} ({work.get('machine', '?')}) {work['stage']} {work['model']}, log quiet {quiet:.0f}s: {work['line']}"
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


async def build(url, ref, upload, wait, previews=(), layout=True, units=None):
	request = {"type": "build", "ref": ref, "upload": upload, "previews": list(previews), "build": layout,
		"weights": preview_weights(previews) if previews else {}}
	if units:
		request["units"] = units
	async with control(url, request, max_size=MAX_MESSAGE) as first:
		return await follow(url, ref, wait, first)


async def follow(url, ref, wait, first):
	"""build's event loop; when the connection drops mid-task it watches the
	task again on a new one (watch_again) and carries on."""
	socket = first
	shares = {}  # (model, unit name) -> machine-seconds, saved on the way out
	relayed = False
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
				# The idle limit is left out: a task under way keeps restarting it.
				progress = Progress(event["count"], event.get("up"), {**event, "idle_minutes": None})
				relayed = bool(event.get("relayed"))
				print(f"posted task {task} ({ref[:7]}): {event['count']} units for {event['up']} machines"
					+ (f"; previews {','.join(event['units'])}" if event.get("units") else ""), file=sys.stderr)
			elif kind == "redealt":
				if progress:
					progress.redealt(event)
				# Relayed files of the unit's old holder must not mix with the new one's.
				if relayed and isinstance(event.get("shard"), int):
					shutil.rmtree(os.path.join(ROOT, ".standby-results", task, f"S{event['shard']}"), ignore_errors=True)
			elif kind == "preview-share":
				if isinstance(event.get("seconds"), (int, float)) and isinstance(event.get("name"), str):
					shares[(event["name"], event.get("unit"))] = float(event["seconds"])
			elif kind == "shard":
				summary = event["summary"].replace("\n", " ")
				print(f"S{event['shard']} ({event.get('machine', '?')}) after {event['seconds']}s: {summary}", flush=True)
				failed = failed or "status=DONE" not in event["summary"]
				if progress and "status=DONE" not in event["summary"]:
					progress.shard_failed(event["shard"], event["seconds"], summary)
			elif kind == "machine":
				if progress and isinstance(event.get("up"), int):
					progress.up = event["up"]
					progress.github_up = event.get("github_up", progress.github_up)
				if event.get("gone"):
					print(f"{event.get('name')} dropped its connection (a reconnect within {event.get('grace', 0):.0f}s keeps its unit; "
						"after that the unit is re-dealt)", flush=True)
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
			elif kind == "log" and event["text"].startswith(("ALERT ", "CLEARED ")):
				# A machine's own alert (standby-agent.py), kept alone on its line.
				alert(event["text"])
			elif kind == "log" and ("FAILED" in event["text"] or "could not" in event["text"] or "error" in event["text"].lower()):
				who = f"{event.get('machine', '?')}" + (f" S{event['shard']}" if event.get("shard") else "")
				print(f"{who}: {event['text']}", flush=True)
				if progress and not progress.reason:
					progress.reason = f"{who}: {event['text']}"
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
		save_preview_seconds(shares)
		# The first connection is closed by control().
		if socket is not first:
			await socket.socket.close()


def resolve_ref(ref):
	"""The ref to post, checked to be on GitHub, where the machines fetch it:
	a commit id is made whole (a machine cannot fetch a short one), a branch
	name is kept. Returns (ref, None), or (None, why) when GitHub lacks it."""
	commit_id = re.fullmatch(r"[0-9a-fA-F]{4,40}", ref) is not None
	asked = ref
	if commit_id:
		local = subprocess.run(["git", "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}"], cwd=ROOT, capture_output=True, text=True)
		asked = local.stdout.strip() if local.returncode == 0 else ref
	try:
		remote = subprocess.run(["gh", "api", f"repos/{{owner}}/{{repo}}/commits/{asked}", "--jq", ".sha"],
			cwd=ROOT, capture_output=True, text=True, timeout=30)
	except (OSError, subprocess.TimeoutExpired) as error:
		return None, f"could not ask GitHub: {error}"
	if remote.returncode != 0:
		said = remote.stderr.strip().splitlines()
		return None, (said[-1] if said else "GitHub does not know it")[:200]
	return (remote.stdout.strip() if commit_id else ref), None


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("command", choices=["status", "machines", "build", "stop-machines", "wait-machines", "mint-workers", "open-workers", "machine-tokens", "numbered", "clear-tasks"])
	parser.add_argument("ref", nargs="?")
	parser.add_argument("last", nargs="?")
	parser.add_argument("--no-upload", action="store_true")
	parser.add_argument("--no-seat", action="store_true", help="build: accepted and ignored; there are no seats any more")
	parser.add_argument("--units", type=int, default=0, help="build: cut the task into this many units (default: one per machine connected)")
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
	elif arguments.command == "clear-tasks":
		code = asyncio.run(clear_tasks(url))
	elif arguments.command == "open-workers":
		code = open_workers()
	elif arguments.command == "numbered":
		code = asyncio.run(numbered(url))
	elif arguments.command == "mint-workers":
		if not (arguments.ref or "").isdigit():
			parser.error("mint-workers needs a count")
		code = asyncio.run(mint_workers(url, int(arguments.ref)))
	else:
		if not arguments.ref:
			parser.error("build needs a commit")
		ref, why = resolve_ref(arguments.ref)
		if not ref:
			alert(f"ALERT BAD_REF: {arguments.ref} is not a commit the machines can fetch from GitHub ({why}) "
				"| push it first (scripts/push-wip.sh for unfinished work) and post again")
			sys.exit(1)
		previews = [name for name in arguments.preview.split(",") if name]
		if arguments.no_seat:
			print("--no-seat: nothing to do; every connected machine takes units from the queue", file=sys.stderr)
		code = asyncio.run(build(url, ref, not arguments.no_upload, arguments.wait, previews, not arguments.preview_only,
			arguments.units or None))
	sys.exit(code)


if __name__ == "__main__":
	main()
