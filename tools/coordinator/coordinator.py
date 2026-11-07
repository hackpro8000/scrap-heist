#!/usr/bin/env python3
"""The build coordinator: hands tasks to the standby build machines the
moment they're posted, takes their results back the moment they're done,
and uploads their new objects as they arrive, all over live connections,
so nothing polls.

  tools/coordinator/coordinator.py serve [--dry-upload] [--agent-host H]
                                         [--agent-port P] [--control-port C]

Machines (scripts/standby-agent.py) connect to the agent port, proving with
GitHub's identity token that they are this repo's standby machines (oidc.py),
and keep the connection open. The session talks to the control port, which
listens on this machine only (tools/coordinator/client.py). Both carry JSON
messages; a file is one binary message, its description and bytes together
(wire.py). Everything the machines report, their log lines included, is
written to the coordinator's log and passed on to the session as it happens.

A build task goes to every machine of the newest standby run, and to any
that connect later. Each machine sends back its results (summary.txt,
parts.txt, manifest.json, costs.txt, error.txt, build.log) and the objects
it built that have no asset (handed/names.tsv first, then each .glb), into
.standby-results/<task>/S<i>/ as scripts/merge-shards.sh reads them. Each
object goes to the uploader (uploader.py) as soon as it lands. Once every
machine is done and every object uploaded, the task's uploaded.tsv is
written and the session told.

If a machine reconnects mid-task, it is sent the task again; it resends
what it already built instead of building twice.

With --uploads-on-machine (what scripts/coordinator.sh chooses when this
session has no Roblox key), objects are uploaded by build machine 1 with the
repo's ROBLOX_API_KEY secret instead: each goes to it over its live
connection and its asset id comes straight back (RemoteUploader).

With --git-link, the coordinator runs on build machine 1, for a session
that can't connect out (scripts/standby-start.sh --on-machine): it takes
build tasks from the build-queue branch (scripts/send-build.sh posts them
there; the one link that still polls) and pushes each finished task's
results, objects left out, as one commit to build-results/coordinator.
"""
import argparse
import asyncio
import json
import os
import subprocess
import sys
import tempfile
import time

import websockets

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import oidc  # noqa: E402
import uploader as uploading  # noqa: E402
import wire  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REPOSITORY = "hackpro8000/scrap-heist"
WORKFLOW = ".github/workflows/build-standby.yml"
MAX_MESSAGE = 64 * 1024 * 1024
STATE = os.path.expanduser("~/.cache/scrap-heist/coordinator.json")
LINK_RESULTS = "build-results/coordinator"
LINK_INTERVAL = 3


def say(message):
	print(f"coordinator: {message}", file=sys.stderr, flush=True)


class Task:
	def __init__(self, identity, ref, upload, count):
		self.id, self.ref, self.upload, self.count = identity, ref, upload, count
		self.started = time.time()
		self.done = {}  # shard -> summary text
		self.handed = {}  # object id -> (shard, label)
		self.labels = {}  # (shard, object id) -> label, from names.tsv
		self.sent = set()  # objects this task uploaded (the rest had assets)
		self.by_branch = False
		self.answered = 0
		self.out = os.path.join(ROOT, ".standby-results", identity)
		os.makedirs(self.out, exist_ok=True)

	def text(self):
		# When machine 1 uploads, objects go to it through GitHub, not this link.
		hand_over = "branch" if self.by_branch else "coordinator"
		return f"ref={self.ref}\nhand-over={hand_over}\n" + ("" if self.upload else "upload=no\n")


class RemoteUploader:
	"""The uploader's interface, with the uploading done by build machine 1:
	objects are sent to it as they land and asset ids come back. Objects
	wait here until machine 1 is connected."""

	def __init__(self, layout):
		self.ledger_path = os.path.join(ROOT, "art", "src", "layouts", f"{layout}Uploads.tsv")
		# Machines come and go; the width machine 1 learns is kept here and
		# handed to each new machine 1 (uploader.py keeps it the same way).
		self.width_path = os.path.join(ROOT, "art", "models", layout, "upload-width.txt")
		self.record, self.failed, self.pending = {}, {}, set()
		self.waiting = []  # (identity, path, label, shard) not yet sent
		self.fetches = []  # fetch-objects messages not yet sent
		self.sent_fetches = []  # sent, in case machine 1 drops before answering
		self.agent = None
		self.loop = None
		self.changed = asyncio.Event()
		self.throttle = type("Width", (), {"limit": 0})()

	def add(self, identity, path, label, shard):
		if identity in self.pending or identity in self.record or identity in uploading.ids_in(self.ledger_path):
			return False
		self.pending.add(identity)
		self.waiting.append((identity, path, label, shard))
		asyncio.get_event_loop().create_task(self.flush())
		return True

	async def flush(self):
		while self.agent and self.waiting:
			identity, path, label, shard = self.waiting.pop(0)
			with open(path, "rb") as file:
				data = file.read()
			try:
				await self.agent.send(wire.pack({"type": "upload", "id": identity, "label": label, "shard": shard}, data))
			except Exception:
				self.waiting.insert(0, (identity, path, label, shard))
				return

	def track(self, identity):
		"""Counts an object as on its way, without sending it from here."""
		if identity in self.pending or identity in self.record or identity in uploading.ids_in(self.ledger_path):
			return False
		self.pending.add(identity)
		return True

	async def request_fetch(self, message):
		self.fetches.append(message)
		await self.send_fetches()

	async def send_fetches(self):
		while self.agent and self.fetches:
			message = self.fetches[0]
			try:
				await self.agent.send(json.dumps(message))
			except Exception:
				return
			self.sent_fetches.append(self.fetches.pop(0))

	async def connected(self, agent):
		self.agent = agent
		# Anything sent to a machine 1 that dropped goes again.
		for identity in list(self.pending):
			if not any(entry[0] == identity for entry in self.waiting) and identity in self.sent_paths:
				self.waiting.append(self.sent_paths[identity])
		await self.flush()
		# Fetches a dropped machine 1 never answered go again.
		for message in self.sent_fetches:
			if any(identity in self.pending for identity in message["ids"]):
				self.fetches.append(message)
		self.sent_fetches = []
		await self.send_fetches()

	def answered(self, event):
		identity = event["id"]
		if event.get("asset"):
			self.record[identity] = (str(event["asset"]), str(event.get("shard", 1)))
		else:
			self.failed[identity] = event.get("error", "failed")
		self.pending.discard(identity)
		if event.get("width"):
			self.throttle.limit = event["width"]
			os.makedirs(os.path.dirname(self.width_path), exist_ok=True)
			with open(self.width_path, "w") as file:
				file.write(f"{event['width']:.2f} {event.get('known', event['width']):.2f}\n")
		self.changed.set()

	def wait(self, identities, timeout=None):
		raise RuntimeError("use wait_async")

	async def wait_async(self, identities):
		while self.pending & set(identities):
			self.changed.clear()
			await self.changed.wait()

	def asset_of(self, identity):
		return self.record.get(identity, (None, None))[0]

	def finish(self):
		pass


class Coordinator:
	def __init__(self, layout, dry, test_without_identity=False, git_link=False, uploads_on_machine=False):
		self.layout = layout
		self.dry = dry
		self.git_link = git_link
		self.test_without_identity = test_without_identity
		self.uploads_on_machine = uploads_on_machine
		if uploads_on_machine:
			self.uploader = RemoteUploader(layout)
			self.uploader.sent_paths = {}
		else:
			self.uploader = uploading.Uploader(ROOT, layout, say, dry=dry, on_done=self.local_answer)
		self.loop = None
		self.run_id = None
		self.count = 0
		self.agents = {}  # shard -> websocket
		self.tasks = {}
		self.watchers = set()  # control websockets waiting on events

	async def hand_to_machine_one(self, task, shard, commit):
		"""A builder pushed its objects to its branch: queue them and tell
		machine 1 to fetch that commit and upload them."""
		wanted = {}
		for (from_shard, identity), label in task.labels.items():
			if from_shard != shard:
				continue
			if identity not in task.handed:
				task.handed[identity] = (shard, label)
			if self.uploader.track(identity):
				task.sent.add(identity)
				wanted[identity] = label
		if not wanted:
			return
		say(f"task {task.id}: S{shard} pushed {len(wanted)} objects at {commit[:8]}; machine 1 fetches them")
		await self.emit({"type": "uploading", "task": task.id, "shard": shard, "count": len(wanted), "queued": len(task.sent)})
		await self.uploader.request_fetch({"type": "fetch-objects", "task": task.id, "shard": shard, "commit": commit, "ids": wanted})

	def local_answer(self, identity, asset, error):
		"""From the local uploader's threads."""
		if self.loop:
			self.loop.call_soon_threadsafe(lambda: asyncio.ensure_future(self.uploaded(identity, asset, error)))

	async def uploaded(self, identity, asset, error):
		if error:
			say(f"upload of {identity} failed: {error}")
		for task in self.tasks.values():
			if identity in task.handed:
				task.answered += 1
				await self.emit({"type": "uploaded", "task": task.id, "object": identity, "label": task.handed[identity][1],
					"asset": asset, "error": error, "done": task.answered, "of": len(task.sent)})

	async def emit(self, event):
		message = json.dumps(event)
		for watcher in list(self.watchers):
			try:
				await watcher.send(message)
			except Exception:
				self.watchers.discard(watcher)

	# --- machines ---

	async def agent(self, socket, path=None):
		try:
			hello = json.loads(await asyncio.wait_for(socket.recv(), 30))
			if self.test_without_identity and hello.get("token") == "test":
				claims = {"run_id": "1", "workflow_ref": WORKFLOW}
			else:
				claims = await asyncio.to_thread(oidc.verify, hello.get("token", ""), REPOSITORY)
			if WORKFLOW not in claims.get("workflow_ref", ""):
				raise ValueError("not a standby machine")
		except Exception as error:
			say(f"refused a connection: {error}")
			await socket.close(code=4001, reason="not allowed")
			return
		run, shard, count = str(claims["run_id"]), int(hello["shard"]), int(hello["count"])
		if self.run_id is not None and run != self.run_id and int(run) < int(self.run_id):
			await socket.close(code=4002, reason="an older run")
			return
		if run != self.run_id:
			self.run_id, self.count, self.agents = run, count, {}
			say(f"standby run {run} with {count} machines")
		self.agents[shard] = socket
		await self.emit({"type": "machine", "shard": shard, "up": len(self.agents), "count": count})
		if self.uploads_on_machine and shard == 1:
			width = known = None
			if os.path.isfile(self.uploader.width_path):
				try:
					fields = [float(field) for field in open(self.uploader.width_path).read().split()]
					width, known = fields[0], fields[1] if len(fields) > 1 else None
				except (ValueError, IndexError):
					pass
			await socket.send(json.dumps({"type": "uploader", "layout": self.layout, "width": width, "known": known}))
			await self.uploader.connected(socket)
		for task in self.tasks.values():
			if shard not in task.done:
				await socket.send(json.dumps({"type": "task", "id": task.id, "task": task.text()}))
		try:
			async for message in socket:
				if isinstance(message, bytes):
					header, data = wire.unpack(message)
					await self.file(shard, header, data)
					continue
				event = json.loads(message)
				if event["type"] == "done":
					await self.finished_shard(shard, event)
				elif event["type"] == "uploaded" and self.uploads_on_machine:
					self.uploader.answered(event)
					await self.uploaded(event["id"], event.get("asset"), event.get("error"))
				elif event["type"] == "log":
					say(f"S{shard}: {event.get('text', '')}")
					await self.emit({"type": "log", "shard": shard, "text": event.get("text", "")})
		except websockets.ConnectionClosed:
			pass
		finally:
			if self.uploads_on_machine and shard == 1 and self.uploader.agent is socket:
				self.uploader.agent = None
				if self.uploader.pending:
					await self.emit({"type": "warning", "text": f"machine 1 dropped with {len(self.uploader.pending)} uploads unanswered; they go again when it reconnects"})
			say(f"S{shard} disconnected")
			if self.agents.get(shard) is socket:
				del self.agents[shard]
				await self.emit({"type": "machine", "shard": shard, "up": len(self.agents), "count": self.count, "gone": True})

	async def file(self, shard, header, data):
		task = self.tasks.get(header["task"])
		name = os.path.normpath(header["path"])
		if not task or name.startswith("..") or os.path.isabs(name):
			return
		path = os.path.join(task.out, f"S{shard}", name)
		os.makedirs(os.path.dirname(path), exist_ok=True)
		with open(path, "wb") as file:
			file.write(data)
		if name == os.path.join("handed", "names.tsv"):
			for line in data.decode().splitlines():
				if "\t" in line:
					identity, label = line.split("\t", 1)
					task.labels[(shard, identity)] = label
		elif name == "handed-commit.txt" and task.by_branch and task.upload:
			await self.hand_to_machine_one(task, shard, data.decode().strip())
		elif name.startswith("handed" + os.sep) and name.endswith(".glb") and task.upload:
			identity = os.path.basename(name)[:-4]
			label = task.labels.get((shard, identity), identity)
			if identity not in task.handed:
				task.handed[identity] = (shard, label)
			if self.uploads_on_machine:
				self.uploader.sent_paths[identity] = (identity, path, label, shard)
			if self.uploader.add(identity, path, label, shard):
				task.sent.add(identity)
				say(f"task {task.id}: uploading {label} ({identity}) from S{shard}")
				await self.emit({"type": "uploading", "task": task.id, "object": identity, "label": label, "queued": len(task.sent)})

	async def finished_shard(self, shard, event):
		task = self.tasks.get(event["task"])
		if not task or shard in task.done:
			return
		task.done[shard] = event.get("summary", "")
		say(f"task {task.id}: S{shard} done ({len(task.done)} of {task.count}): {task.done[shard].strip().replace(chr(10), ' ')}")
		await self.emit({"type": "shard", "task": task.id, "shard": shard, "summary": task.done[shard],
			"seconds": round(time.time() - task.started)})
		if len(task.done) >= task.count:
			asyncio.create_task(self.complete(task))

	async def complete(self, task):
		built = time.time() - task.started
		if self.uploads_on_machine:
			await self.uploader.wait_async(list(task.handed))
		else:
			await asyncio.to_thread(self.uploader.wait, list(task.handed))
		self.uploader.finish()
		failed = {i: e for i, e in self.uploader.failed.items() if i in task.handed}
		with open(os.path.join(task.out, "uploaded.tsv"), "w") as file:
			for identity, (shard, _label) in task.handed.items():
				asset = self.uploader.asset_of(identity)
				if asset:
					file.write(f"{identity}\t{asset}\t{shard}\n")
		with open(os.path.join(task.out, "summary.txt"), "w") as file:
			file.write(f"built={round(built)}\ntotal={round(time.time() - task.started)}\nobjects={len(task.handed)}\n"
				f"uploaded={len(task.sent & set(self.uploader.record))}\nfailed={len(failed)}\n")
		if self.git_link:
			await asyncio.to_thread(self.push_results, task)
		merged = None
		# Fake uploads must never reach the game's tables.
		if task.upload and not failed and not self.git_link and not self.dry and not self.test_without_identity:
			merged = await asyncio.to_thread(self.merge, task)
		await self.emit({"type": "finished", "task": task.id, "out": task.out, "built": round(built),
			"total": round(time.time() - task.started), "objects": len(task.handed), "uploaded": len(task.sent & set(self.uploader.record)), "failed": failed,
			"width": round(self.uploader.throttle.limit, 1), "merged": merged})
		del self.tasks[task.id]

	def merge(self, task):
		"""Merges a finished task into the game's tables (scripts/merge-shards.sh)
		and returns the asset ids that are new, which need the game's
		permission; or the merge's error."""
		shards = sorted(os.path.join(task.out, name) for name in os.listdir(task.out) if name.startswith("S"))
		result = subprocess.run(["scripts/merge-shards.sh", self.layout, *shards], cwd=ROOT, capture_output=True, text=True)
		if result.returncode != 0:
			say(f"task {task.id}: merge failed: {result.stderr.strip()[-300:]}")
			return {"error": result.stderr.strip()[-300:]}
		new = [line for line in result.stdout.split() if line.isdigit()]
		say(f"task {task.id}: merged; {len(new)} new assets need the game's permission")
		return {"new_assets": new}

	async def post(self, identity, ref, upload):
		task = Task(identity, ref, upload, self.count)
		task.by_branch = self.uploads_on_machine
		self.tasks[identity] = task
		for agent in list(self.agents.values()):
			await agent.send(json.dumps({"type": "task", "id": identity, "task": task.text()}))
		return task

	# --- a session reached through git (--git-link) ---

	def git(self, *arguments, **options):
		return subprocess.run(["git", *arguments], cwd=ROOT, capture_output=True, text=True, **options)

	async def link(self):
		"""Takes tasks posted to build-queue since this coordinator started."""
		since, seen, taken = int(time.time()), "", set()
		while True:
			head = (await asyncio.to_thread(self.git, "ls-remote", "origin", "refs/heads/build-queue")).stdout.split("\t")[0]
			if head and head != seen and self.count:
				fetched = await asyncio.to_thread(self.git, "fetch", "-q", "--depth=1", "origin", head)
				if fetched.returncode == 0:
					seen = head
					files = (await asyncio.to_thread(self.git, "ls-tree", "--name-only", head, "tasks/")).stdout.split()
					for name in sorted(files):
						identity = os.path.basename(name)[:-4]
						posted = identity[1:].split("-")[0]
						if identity in taken or not posted.isdigit() or int(posted) < since:
							continue
						taken.add(identity)
						text = (await asyncio.to_thread(self.git, "show", f"{head}:{name}")).stdout
						fields = dict(line.split("=", 1) for line in text.splitlines() if "=" in line)
						if "ref" in fields and "upload-of" not in fields:
							say(f"task {identity} from the build-queue branch")
							await self.post(identity, fields["ref"], fields.get("upload") != "no")
			await asyncio.sleep(LINK_INTERVAL)

	def push_results(self, task):
		"""One commit on build-results/coordinator with the task's results,
		objects left out, through a temporary index."""
		index = tempfile.mktemp()
		environment = {**os.environ, "GIT_INDEX_FILE": index}
		for directory, _, names in os.walk(task.out):
			for name in names:
				if name.endswith(".glb"):
					continue
				path = os.path.join(directory, name)
				blob = self.git("hash-object", "-w", path).stdout.strip()
				relative = os.path.relpath(path, task.out)
				self.git("update-index", "--add", "--cacheinfo", f"100644,{blob},{relative}", env=environment)
		tree = self.git("write-tree", env=environment).stdout.strip()
		if os.path.exists(index):
			os.remove(index)
		parent = []
		if self.git("fetch", "-q", "--depth=1", "origin", f"refs/heads/{LINK_RESULTS}").returncode == 0:
			parent = ["-p", self.git("rev-parse", "FETCH_HEAD").stdout.strip()]
		commit = self.git("commit-tree", tree, *parent, "-m", f"task {task.id}").stdout.strip()
		pushed = self.git("push", "-q", "origin", f"{commit}:refs/heads/{LINK_RESULTS}")
		say(f"task {task.id}: results pushed" if pushed.returncode == 0 else f"task {task.id}: push failed {pushed.stderr}")

	# --- the session ---

	async def control(self, socket, path=None):
		try:
			request = json.loads(await socket.recv())
		except websockets.ConnectionClosed:
			return
		kind = request.get("type")
		if kind == "status":
			await socket.send(json.dumps({"type": "status", "run": self.run_id, "count": self.count,
				"up": sorted(self.agents), "tasks": list(self.tasks)}))
			return
		if kind == "watch":
			# Streams machine and task events until the watcher hangs up.
			await socket.send(json.dumps({"type": "machines", "run": self.run_id, "count": self.count, "up": len(self.agents)}))
			self.watchers.add(socket)
			try:
				async for _ in socket:
					pass
			except websockets.ConnectionClosed:
				pass
			finally:
				self.watchers.discard(socket)
			return
		if kind == "stop-machines":
			for agent in list(self.agents.values()):
				await agent.send(json.dumps({"type": "stop"}))
			await socket.send(json.dumps({"type": "stopped", "machines": len(self.agents)}))
			return
		if kind != "build":
			await socket.send(json.dumps({"type": "error", "text": f"unknown request {kind}"}))
			return
		if not self.count:
			await socket.send(json.dumps({"type": "error", "text": "no standby machines have connected"}))
			return
		identity = f"t{int(time.time())}-{os.getpid()}-{len(self.tasks)}"
		self.watchers.add(socket)
		task = await self.post(identity, request["ref"], request.get("upload", True))
		await socket.send(json.dumps({"type": "posted", "task": identity, "count": task.count, "up": len(self.agents)}))
		try:
			async for _ in socket:
				pass
		except websockets.ConnectionClosed:
			pass
		finally:
			self.watchers.discard(socket)


async def serve(arguments):
	if arguments.test_without_identity and (arguments.agent_host != "127.0.0.1" or not (arguments.dry_upload or arguments.uploads_on_machine)):
		sys.exit("--test-without-identity is only for a local dry run (agent host 127.0.0.1, --dry-upload)")
	coordinator = Coordinator(arguments.layout, arguments.dry_upload, arguments.test_without_identity, arguments.git_link,
		arguments.uploads_on_machine)
	coordinator.loop = asyncio.get_running_loop()
	agents = await websockets.serve(coordinator.agent, arguments.agent_host, arguments.agent_port, max_size=MAX_MESSAGE)
	control = await websockets.serve(coordinator.control, "127.0.0.1", arguments.control_port, max_size=MAX_MESSAGE)
	os.makedirs(os.path.dirname(STATE), exist_ok=True)
	state = {"pid": os.getpid(), "control": f"ws://127.0.0.1:{arguments.control_port}",
		"agent_port": arguments.agent_port, "agent_host": arguments.agent_host, "dry_upload": arguments.dry_upload}
	if os.path.isfile(STATE):
		try:
			old = json.load(open(STATE))
			if "agent_url" in old and old.get("pid") == os.getpid():
				state["agent_url"] = old["agent_url"]
		except Exception:
			pass
	with open(STATE, "w") as file:
		json.dump(state, file)
	say(f"machines on {arguments.agent_host}:{arguments.agent_port}, control on 127.0.0.1:{arguments.control_port}"
		+ (" (dry upload)" if arguments.dry_upload else "")
		+ (" (machine 1 uploads)" if arguments.uploads_on_machine else ""))
	waits = [agents.wait_closed(), control.wait_closed()]
	if arguments.git_link:
		waits.append(coordinator.link())
	await asyncio.gather(*waits)


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("command", choices=["serve"])
	parser.add_argument("--layout", default="ServerMap")
	parser.add_argument("--agent-host", default="127.0.0.1")
	parser.add_argument("--agent-port", type=int, default=8765)
	parser.add_argument("--control-port", type=int, default=8766)
	parser.add_argument("--dry-upload", action="store_true")
	# Local tests only: agents may connect with the token "test". Never with
	# a tunnel, which makes every outside connection look local.
	parser.add_argument("--test-without-identity", action="store_true")
	parser.add_argument("--git-link", action="store_true")
	parser.add_argument("--uploads-on-machine", action="store_true")
	asyncio.run(serve(parser.parse_args()))


if __name__ == "__main__":
	main()
