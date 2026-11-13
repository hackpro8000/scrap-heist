#!/usr/bin/env python3
"""The build coordinator: hands tasks to the standby build machines the
moment they're posted, takes their results back the moment they're done,
and uploads their new objects as they arrive, all over live connections,
so nothing polls.

  tools/coordinator/coordinator.py serve [--dry-upload] [--agent-host H]
                                         [--agent-port P] [--control-port C]
                                         [--control-host H] [--control-key K]

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
what it already built instead of building twice. Posted tasks are kept in
tasks.json beside the state file until they complete, so a restarted
coordinator takes them back; a session that lost its connection asks for
its task again with {"type": "watch-task", "task": id}.

A machine that is not a GitHub one (scripts/cloud-worker.sh) is admitted
by a one-time token: {"type": "mint-workers", "count": n} (signed session
only) makes a new pool of n tokens, kept in memory only; a hello with
"worker:<token>" takes its run, shard and count from that token, one live
connection per token. A pool counts as the newest run from its first
connection.

A numbered machine (scripts/cloud-worker.sh join) needs no minting: with
COORDINATOR_WORKER_KEY in the coordinator's environment, a hello with
"machine": n and "worker:<its lasting token>" (wire.machine_token) is
admitted to wait. {"type": "open-workers"} (signed session only) seats
every waiting machine as shards 1..k of a new pool of k and tells each its
shard with {"type": "welcome"}; a machine that connects later waits for the
next open-workers. While a pool is the newest run, the GitHub machine that
hosts the coordinator stays on as uploader only, and is told
{"type": "active"} when a task is posted or a shard finishes, so its idle
clock restarts.

With --uploads-on-machine (what scripts/coordinator.sh chooses when this
session has no Roblox key), objects are uploaded by build machine 1 with the
repo's ROBLOX_API_KEY secret instead: each goes to it over its live
connection and its asset id comes straight back (RemoteUploader).

With --git-link, the coordinator runs on build machine 1, for a session
that can't connect out (scripts/standby-start.sh --on-machine): it takes
build tasks from the build-queue branch (scripts/send-build.sh posts them
there; the one link that still polls) and pushes each finished task's
results, objects left out, as one commit to build-results/coordinator.

With --relay-results (machine 1 with a control key), every result file but
the objects, every preview image stored, and the task's uploaded.tsv and
summary.txt also go to the task's session as one binary message each
({"type": "result-file", "task", "root", "path"}), before "finished". The
session merges; the coordinator doesn't.
"""
import argparse
import asyncio
import glob
import hashlib
import hmac
import ipaddress
import json
import os
import re
import secrets
import shutil
import subprocess
import sys
import tempfile
import time
import traceback

import websockets

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import oidc  # noqa: E402
import commits  # noqa: E402
import uploader as uploading  # noqa: E402
import wire  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REPOSITORY = "hackpro8000/scrap-heist"
WORKFLOW = ".github/workflows/build-standby.yml"
MAX_MESSAGE = 64 * 1024 * 1024
# Control only ever receives small requests; the public port refuses big ones before admission.
MAX_CONTROL_MESSAGE = 64 * 1024
MAX_SIGNATURE = 4096
STATE = os.path.expanduser("~/.cache/scrap-heist/coordinator.json")
# Posted tasks not yet completed, reloaded when a coordinator restarts.
TASKS = os.path.join(os.path.dirname(STATE), "tasks.json")
# Finished tasks a reconnecting session can still ask for (watch-task).
KEEP_FINISHED = 20
WORKER_PREFIX = "worker:"
MAX_WORKERS = 100
LINK_RESULTS = "build-results/coordinator"
LINK_INTERVAL = 3
# --control-key: a control connection counts only once the session has
# signed a fresh nonce with its key (scripts/coordinator.sh key).
CONTROL_NAMESPACE = "scrap-heist-control"
CHALLENGE_SECONDS = 30
TAILNET = ipaddress.ip_network("100.64.0.0/10")
# What a machine may name: a model folder, and a task folder.
MODEL_NAME = re.compile(r"[A-Za-z0-9_]+")
TASK_NAME = re.compile(r"[A-Za-z0-9-]+")
COMMIT = re.compile(r"[0-9a-f]{7,64}")
# Most one shard may send for one task; further files are refused.
MAX_SHARD_FILES = 20_000
MAX_SHARD_BYTES = 8 * 1024 ** 3


def say(message):
	print(f"coordinator: {message}", file=sys.stderr, flush=True)


class Task:
	def __init__(self, identity, ref, upload, count, previews=(), build=True):
		self.id, self.ref, self.upload, self.count = identity, ref, upload, count
		# Without a build the shards only render the previews.
		self.build = build
		# Models whose previews the shards render, shared out between them,
		# and the shards whose previews haven't all come yet. With fewer
		# models than machines each model's renders are split between several
		# machines, as shares named <Name>@<i>@<n>, so every machine works;
		# shares_in counts the shares of each model that have come back.
		# A name ending in "!" is one machine's job whole, for timing a model's
		# build on its own; the "!" is dropped from the name.
		self.asked = list(previews)  # as posted, for the tasks file
		whole = {name[:-1] for name in previews if name.endswith("!")}
		self.previews = [name.rstrip("!") for name in previews]
		self.units = self.previews
		if self.previews and len(self.previews) < count:
			self.units = []
			for k, name in enumerate(self.previews):
				shares = 1 if name in whole else count // len(self.previews) + (1 if k < count % len(self.previews) else 0)
				self.units += [name] if shares == 1 else [f"{name}@{i}@{shares}" for i in range(1, shares + 1)]
		self.shares_in = {}
		self.queues = {}  # (model, bake or render) -> the next job to hand out
		self.job_answers = {}  # (shard, claim number) -> job, so a repeated claim gets the same one
		self.bakes = {}  # model -> share number -> commit of that machine's baked textures
		self.previews_waiting = set(range(1, count + 1)) if self.previews else set()
		self.started = time.time()
		self.done = {}  # shard -> summary text
		self.handed = {}  # object id -> (shard, label)
		self.labels = {}  # (shard, object id) -> label, from names.tsv
		self.sent = set()  # objects this task uploaded (the rest had assets)
		self.by_branch = False
		self.answered = 0
		self.received = {}  # shard -> [files, bytes] it sent, against MAX_SHARD_*
		self.watchers = set()  # control sockets of the session that posted it, for relayed files
		self.out = os.path.join(ROOT, ".standby-results", identity)
		os.makedirs(self.out, exist_ok=True)

	def text(self):
		# When machine 1 uploads, objects go to it through GitHub, not this link.
		hand_over = "branch" if self.by_branch else "coordinator"
		return (f"ref={self.ref}\nhand-over={hand_over}\n" + ("" if self.upload else "upload=no\n")
			+ ("" if self.build else "build=no\n")
			+ (f"preview={','.join(self.units)}\n" if self.units else ""))


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
			# A retry that worked clears an earlier failure.
			self.failed.pop(identity, None)
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
	def __init__(self, layout, dry, test_without_identity=False, git_link=False, uploads_on_machine=False, relay_results=False):
		self.layout = layout
		self.dry = dry
		self.git_link = git_link
		self.relay_results = relay_results
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
		self.progress = {}  # shard -> its latest heartbeat, with the time it came
		self.control_signers = None  # allowed-signers file, with --control-key
		self.finished = {}  # task id -> (task, its finished event), the last KEEP_FINISHED
		# Minted worker tokens, in memory only: token -> {"run": pool id,
		# "shard", "count", "socket": its live connection or None}.
		self.workers = {}
		self.pools = 0
		# run -> how new it is: a GitHub run by its id, a pool above
		# everything seen when it is minted.
		self.ranks = {}
		# Numbered machines: the key their tokens are made from (out of the
		# environment at once), machine -> its live connection, and machine
		# -> its shard in the pool of seat_count that seat_run names.
		self.worker_key = os.environ.pop("COORDINATOR_WORKER_KEY", "")
		self.machines = {}
		self.seats = {}
		self.seat_run = None
		self.seat_count = 0
		self.hosts = set()  # GitHub machines' connections, to keep their idle clocks going
		# The hub's lifetime, for ALERT LIFETIME (client.py): the job's start
		# (STANDBY_SINCE, so a restart keeps it), the last task activity, and the
		# workflow's limits, which only a coordinator on machine 1 has.
		self.started = float(os.environ.get("STANDBY_SINCE") or time.time())
		self.last_active = time.time()
		self.idle_minutes = int(os.environ.get("STANDBY_IDLE_MINUTES") or 0) or None
		self.max_minutes = int(os.environ.get("STANDBY_MAX_MINUTES") or 0) or None
		self.run_started = None  # when the newest run's first machine connected (ALERT SHORT)

	def lifetime(self):
		return {"hub_started": self.started, "last_active": self.last_active,
			"idle_minutes": self.idle_minutes, "max_minutes": self.max_minutes, "now": time.time()}

	def task_states(self):
		"""Per open task, what client.py status needs to tell a stranded one."""
		return {task.id: {"age": round(time.time() - task.started), "done": len(task.done), "count": task.count,
			"uploads_open": len(task.sent) - task.answered, "previews_waiting": len(task.previews_waiting)}
			for task in self.tasks.values()}

	@staticmethod
	def join_part(parts, header, data):
		"""A big file comes in parts (standby-agent.py send_file), kept per
		connection in `parts`; returns the whole file once its last part is
		in, else None. A part out of order drops what was gathered."""
		key = (header.get("task"), header.get("path"))
		offset, size = header.get("offset"), header.get("size")
		if not isinstance(offset, int) or not isinstance(size, int) or size > MAX_MESSAGE:
			parts.pop(key, None)
			return None
		if offset == 0:
			parts[key] = bytearray()
		gathered = parts.get(key)
		if gathered is None or len(gathered) != offset or offset + len(data) > size:
			parts.pop(key, None)
			return None
		gathered += data
		if len(gathered) < size:
			return None
		del parts[key]
		return bytes(gathered)

	def rank(self, run):
		if run not in self.ranks:
			self.ranks[run] = int(run) if run.isdigit() else max(self.ranks.values(), default=0) + 1
		return self.ranks[run]

	def worker(self, token):
		"""The minted record of a worker token, or None. Every token is
		compared, in constant time, so timing tells nothing."""
		found = None
		for minted, record in self.workers.items():
			if hmac.compare_digest(minted.encode(), token.encode()):
				found = record
		return found

	def mint(self, count):
		"""count tokens for a new pool, shards 1..count."""
		self.pools += 1
		pool = f"pool-{self.pools}"
		# Ranked now, so a later GitHub run outranks it however late it connects.
		self.ranks[pool] = max(self.ranks.values(), default=0) + 1
		minted = []
		for shard in range(1, count + 1):
			token = secrets.token_hex(32)
			self.workers[token] = {"run": pool, "shard": shard, "count": count, "socket": None}
			minted.append({"shard": shard, "count": count, "token": token})
		say(f"minted {pool} (rank {self.ranks[pool]}): {count} workers ({', '.join(entry['token'][:6] for entry in minted)}...)")
		return pool, minted

	async def open_workers(self):
		"""Seats every connected numbered machine as shards 1..k of a new
		pool and returns the machines in shard order. Their connections are
		closed; each reconnects within a second and is welcomed to its seat."""
		connected = sorted(machine for machine, socket in self.machines.items() if not socket.closed)
		self.pools += 1
		self.seat_run = f"pool-{self.pools}"
		self.ranks[self.seat_run] = max(self.ranks.values(), default=0) + 1
		self.seats = {machine: shard for shard, machine in enumerate(connected, 1)}
		self.seat_count = len(connected)
		say(f"opened {self.seat_run}: {self.seat_count} machines seated ({' '.join(f'm{machine}' for machine in connected)})")
		for socket in list(self.machines.values()):
			await socket.close(code=4005, reason="seats changed")
		return connected

	async def keep_hosts_awake(self):
		self.last_active = time.time()
		for socket in list(self.hosts):
			try:
				await socket.send(json.dumps({"type": "active"}))
			except Exception:
				self.hosts.discard(socket)

	async def wait_for_seat(self, socket, machine):
		"""A numbered machine without a seat: its connection is kept, and
		what it says dropped, until it closes (open_workers closes it)."""
		say(f"m{machine} waiting for a seat ({len(self.machines)} machines connected)")
		await self.emit({"type": "waiting", "machine": machine, "connected": len(self.machines)})
		try:
			async for _ in socket:
				pass
		except websockets.ConnectionClosed:
			pass

	def save_tasks(self):
		"""Writes the tasks not yet completed to the tasks file."""
		open_tasks = {task.id: {"ref": task.ref, "upload": task.upload, "previews": task.asked, "build": task.build,
			"count": task.count} for task in self.tasks.values() if not getattr(task, "completed", False)}
		os.makedirs(os.path.dirname(TASKS), exist_ok=True)
		with open(TASKS + ".new", "w") as file:
			json.dump(open_tasks, file)
		os.replace(TASKS + ".new", TASKS)

	def load_tasks(self):
		"""Takes back the tasks a previous coordinator left open; machines that
		reconnect are sent them again and resend what they built. Never raises:
		a bad file or entry is logged and skipped."""
		try:
			if not os.path.isfile(TASKS):
				return
			open_tasks = json.load(open(TASKS))
			if not isinstance(open_tasks, dict):
				say(f"ignoring a tasks file that is not an object: {type(open_tasks).__name__}")
				return
			for identity, fields in open_tasks.items():
				if not self.task_entry_fits(identity, fields):
					say(f"skipping a bad tasks file entry: {str(identity)[:40]!r}")
					continue
				task = Task(identity, fields["ref"], fields["upload"], fields["count"], fields.get("previews", []), fields.get("build", True))
				task.by_branch = self.uploads_on_machine
				self.tasks[identity] = task
				say(f"task {identity} taken back from the tasks file")
		except Exception as error:
			say(f"ignoring an unreadable tasks file: {error}")

	@staticmethod
	def task_entry_fits(identity, fields):
		"""Whether a tasks file entry has the shape save_tasks writes."""
		return (TASK_NAME.fullmatch(identity) is not None and isinstance(fields, dict)
			and isinstance(fields.get("ref"), str) and isinstance(fields.get("upload"), bool)
			and isinstance(fields.get("count"), int) and not isinstance(fields.get("count"), bool) and fields["count"] >= 1
			and isinstance(fields.get("previews", []), list) and all(isinstance(name, str) for name in fields.get("previews", []))
			and isinstance(fields.get("build", True), bool))

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

	async def relay(self, task, root, path, data=None, to=None):
		"""With --relay-results, sends one stored file to the task's session
		(or only to the socket `to`). root is "results" (path under task.out)
		or "repo" (path under ROOT)."""
		if not self.relay_results or path.endswith(".glb"):
			return
		if data is None:
			with open(os.path.join(task.out if root == "results" else ROOT, path), "rb") as file:
				data = file.read()
		message = wire.pack({"type": "result-file", "task": task.id, "root": root, "path": path}, data)
		for watcher in [to] if to else list(task.watchers):
			try:
				await watcher.send(message)
			except Exception:
				task.watchers.discard(watcher)

	# --- machines ---

	async def agent(self, socket, path=None):
		record = None
		machine = None
		try:
			hello = json.loads(await asyncio.wait_for(socket.recv(), 30))
			token = hello.get("token", "")
			if "machine" in hello:
				# A numbered machine: admitted by the token made from the worker key.
				number = hello["machine"]
				good = (self.worker_key and isinstance(number, int) and 1 <= number <= MAX_WORKERS and isinstance(token, str)
					and hmac.compare_digest(token.encode(), (WORKER_PREFIX + wire.machine_token(self.worker_key, number)).encode()))
				if not good:
					raise ValueError("unknown machine token")
				machine = number
				run, shard, count = self.seat_run, self.seats.get(machine), self.seat_count
			elif isinstance(token, str) and token.startswith(WORKER_PREFIX):
				# A minted worker: who it is comes from the token, never the hello.
				record = self.worker(token[len(WORKER_PREFIX):]) if len(token) > len(WORKER_PREFIX) else None
				if not record:
					raise ValueError("unknown worker token")
				if record["socket"] is not None and not record["socket"].closed:
					record = None
					raise ValueError("that worker token is already connected")
				record["socket"] = socket
				run, shard, count = record["run"], record["shard"], record["count"]
			else:
				if self.test_without_identity and token == "test":
					claims = {"run_id": "1", "workflow_ref": WORKFLOW}
				else:
					claims = await asyncio.to_thread(oidc.verify, token, REPOSITORY)
				if WORKFLOW not in claims.get("workflow_ref", ""):
					raise ValueError("not a standby machine")
				run, shard, count = str(claims["run_id"]), int(hello["shard"]), int(hello["count"])
		except Exception as error:
			say(f"refused a connection: {error}")
			await socket.close(code=4001, reason="not allowed")
			return
		if machine is not None:
			old = self.machines.get(machine)
			self.machines[machine] = socket
			if old is not None and not old.closed:
				await old.close(code=4004, reason="connected again")
			try:
				if shard is None:
					await self.wait_for_seat(socket, machine)
				else:
					await socket.send(json.dumps({"type": "welcome", "shard": shard, "count": count}))
					await self.serve_machine(socket, run, shard, count, None, False)
			finally:
				if self.machines.get(machine) is socket:
					del self.machines[machine]
			return
		await self.serve_machine(socket, run, shard, count, record, not record)

	async def serve_machine(self, socket, run, shard, count, record, github):
		"""An admitted machine's connection, from its seat to its close."""
		older = self.run_id is not None and run != self.run_id and self.rank(run) < self.rank(self.run_id)
		# The GitHub machine hosting the coordinator stays under a newer pool
		# of workers: it uploads for them and builds nothing.
		host_only = older and github and not self.run_id.isdigit()
		if older and not host_only:
			if record:
				record["socket"] = None
			await socket.close(code=4002, reason="an older run")
			return
		if github:
			self.hosts.add(socket)
		if not host_only:
			self.rank(run)
			if run != self.run_id:
				self.run_id, self.count, self.agents, self.progress = run, count, {}, {}
				self.run_started = time.time()
				say(f"standby run {run} with {count} machines")
			self.agents[shard] = socket
			await self.emit({"type": "machine", "shard": shard, "up": len(self.agents), "count": count})
		# A worker has no Roblox key; only a GitHub machine 1 uploads.
		if self.uploads_on_machine and shard == 1 and github:
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
			if not host_only and (shard not in task.done or shard in task.previews_waiting):
				await socket.send(json.dumps({"type": "task", "id": task.id, "task": task.text()}))
		parts = {}  # big files arriving in parts on this connection (join_part)
		try:
			async for message in socket:
				seated = self.agents.get(shard) is socket
				if isinstance(message, bytes):
					header, data = wire.unpack(message)
					if header.get("type") == "file-part":
						data = self.join_part(parts, header, data)
						if data is None:
							continue
					if seated:
						await self.file(shard, header, data)
					continue
				event = json.loads(message)
				if event["type"] == "uploaded" and self.uploads_on_machine:
					self.uploader.answered(event)
					await self.uploaded(event["id"], event.get("asset"), event.get("error"))
				elif not seated:
					# A host under a pool of workers holds no shard: only its
					# uploads count.
					continue
				elif event["type"] == "done":
					await self.finished_shard(shard, event)
				elif event["type"] == "preview-ready":
					await self.preview_ready(shard, event)
				elif event["type"] == "preview-pushed":
					await self.preview_pushed(shard, event)
				elif event["type"] == "previews-done":
					await self.previews_done(shard, event)
				elif event["type"] == "claim":
					await socket.send(json.dumps({"type": "claimed", "id": event["id"], "job": self.next_job(shard, event)}))
				elif event["type"] == "bakes-pushed":
					await self.bakes_pushed(event)
				elif event["type"] == "progress":
					self.progress[shard] = {**event, "heard": time.time()}
					await self.emit({**event, "shard": shard})
				elif event["type"] == "log":
					say(f"S{shard}: {event.get('text', '')}")
					await self.emit({"type": "log", "shard": shard, "text": event.get("text", "")})
		except websockets.ConnectionClosed as closed:
			say(f"S{shard} closed: {closed}")
		except Exception:
			# Anything else would close the connection without a word.
			say(f"S{shard} handler failed:\n{traceback.format_exc()}")
		finally:
			if self.uploads_on_machine and shard == 1 and self.uploader.agent is socket:
				self.uploader.agent = None
				if self.uploader.pending:
					await self.emit({"type": "warning", "text": f"machine 1 dropped with {len(self.uploader.pending)} uploads unanswered; they go again when it reconnects"})
			say(f"S{shard} disconnected")
			self.hosts.discard(socket)
			# Its token may connect again.
			if record and record["socket"] is socket:
				record["socket"] = None
			if self.agents.get(shard) is socket:
				del self.agents[shard]
				await self.emit({"type": "machine", "shard": shard, "up": len(self.agents), "count": self.count, "gone": True})

	async def file(self, shard, header, data):
		task = self.tasks.get(header.get("task")) if isinstance(header.get("task"), str) else None
		if not task:
			return
		raw = header.get("path")
		folder = os.path.realpath(os.path.join(task.out, f"S{shard}"))
		name = os.path.normpath(raw) if isinstance(raw, str) and raw else ""
		path = os.path.join(folder, name)
		# Whatever the machine names must land inside its own shard folder.
		if (not name or os.path.isabs(name) or ".." in raw.replace("\\", "/").split("/")
				or not os.path.realpath(path).startswith(folder + os.sep)):
			say(f"task {task.id}: S{shard} sent a file outside its folder, dropped: {str(raw)[:80]!r}")
			return
		received = task.received.setdefault(shard, [0, 0])
		if received[0] + 1 > MAX_SHARD_FILES or received[1] + len(data) > MAX_SHARD_BYTES:
			if received[0] <= MAX_SHARD_FILES:
				say(f"task {task.id}: S{shard} went over {MAX_SHARD_FILES} files or {MAX_SHARD_BYTES} bytes; refusing its further files")
			received[0] = MAX_SHARD_FILES + 1
			return
		received[0] += 1
		received[1] += len(data)
		os.makedirs(os.path.dirname(path), exist_ok=True)
		with open(path, "wb") as file:
			file.write(data)
		await self.relay(task, "results", os.path.join(f"S{shard}", name), data)
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

	async def preview_ready(self, shard, event):
		"""One model's renders are in: put them beside the model (preview.png,
		the four turns as views.png, and the model script's hash in
		previewed.txt, so send-build knows it has a preview) and say so."""
		task = self.tasks.get(event["task"])
		if not task or not self.preview_model(task, shard, event.get("name")):
			return
		name = event["name"]
		source = os.path.join(task.out, f"S{shard}", "previews", name)
		if "@" in name:
			# One share of a model's renders: merge it into the model's
			# folder, and carry on once every share is in.
			name, share, shares = name.split("@")
			merged = os.path.join(task.out, "previews", name)
			os.makedirs(merged, exist_ok=True)
			for file in os.listdir(source):
				if file == "build.log":
					shutil.copy(os.path.join(source, file), os.path.join(merged, f"build-{share}.log"))
				else:
					shutil.copy(os.path.join(source, file), os.path.join(merged, file))
			failed = "FAILED" in open(os.path.join(source, "build.log")).read() if os.path.isfile(os.path.join(source, "build.log")) else True
			if failed:
				await self.emit({"type": "preview", "task": task.id, "name": name, "path": f"FAILED, see {os.path.join(source, 'build.log')}"})
			task.shares_in.setdefault(name, set()).add(share)
			if len(task.shares_in[name]) < int(shares):
				return
			source = merged
		model = os.path.join(ROOT, "art", "models", name)
		if not os.path.isfile(os.path.join(source, "preview.png")):
			await self.emit({"type": "preview", "task": task.id, "name": name, "path": f"FAILED, see {os.path.join(source, 'build.log')}"})
			return
		os.makedirs(model, exist_ok=True)
		shutil.copy(os.path.join(source, "preview.png"), os.path.join(model, "preview.png"))
		views = [os.path.join(source, f"view{turn}.png") for turn in range(4)]
		sheet = os.path.join(model, "views.png")
		if shutil.which("montage") and all(os.path.isfile(view) for view in views):
			await asyncio.to_thread(subprocess.run, ["montage", *views, "-tile", "2x2", "-geometry", "+4+4", sheet])
		script = os.path.join(model, "model.luau")
		if os.path.isfile(script):
			with open(os.path.join(model, "previewed.txt"), "w") as file:
				file.write(hashlib.sha1(open(script, "rb").read()).hexdigest()[:16] + "\n")
		for stored in ("preview.png", "views.png", "previewed.txt"):
			if os.path.isfile(os.path.join(model, stored)):
				await self.relay(task, "repo", os.path.relpath(os.path.join(model, stored), ROOT))
		shown = sheet if os.path.isfile(sheet) else os.path.join(model, "preview.png")
		await self.emit({"type": "preview", "task": task.id, "name": name, "path": os.path.relpath(shown, ROOT)})

	@staticmethod
	def preview_model(task, shard, unit):
		"""The model a machine's preview names, or None (logged) unless it is
		one of the task's preview units (Name or Name@i@n) for a model that
		exists here."""
		name = unit.split("@")[0] if isinstance(unit, str) else ""
		if (unit in task.units and MODEL_NAME.fullmatch(name)
				and os.path.isfile(os.path.join(ROOT, "art", "models", name, "model.luau"))):
			return name
		say(f"task {task.id}: S{shard} named a preview the task did not ask for, ignored: {str(unit)[:80]!r}")
		return None

	def next_job(self, shard, event):
		"""Hands out a model's jobs in order to whichever machine asks next, so
		one that finishes early takes more. -1 when none are left."""
		task = self.tasks.get(event["task"])
		if not task:
			return -1
		claim = (shard, event["id"])
		if claim not in task.job_answers:
			key = (event["name"], event["kind"])
			job = task.queues.get(key, 0)
			task.job_answers[claim] = job if job < event["total"] else -1
			task.queues[key] = job + 1
		return task.job_answers[claim]

	async def bakes_pushed(self, event):
		"""A machine has baked its share of a model's textures. Once all have,
		tells them all which commits to fetch."""
		task = self.tasks.get(event["task"])
		if not task:
			return
		name, share, shares = event["share"].split("@")
		pushed = task.bakes.setdefault(name, {})
		pushed[share] = event["commit"]
		# Every push is announced, so a machine that gives up waiting for a
		# slow peer still takes what has arrived and bakes only the rest.
		message = json.dumps({"type": "bakes-ready", "task": task.id, "name": name, "done": len(pushed) >= int(shares),
			"commits": [commit for commit in pushed.values() if commit]})
		for agent in list(self.agents.values()):
			try:
				await agent.send(message)
			except websockets.ConnectionClosed:
				pass  # its share_bakes times out and the render bakes the rest

	async def preview_pushed(self, shard, event):
		"""A machine pushed a finished preview to GitHub: take its files from
		there, then treat it as arrived."""
		task = self.tasks.get(event["task"])
		if not task or not self.preview_model(task, shard, event.get("name")):
			return
		if not isinstance(event.get("commit"), str) or not COMMIT.fullmatch(event["commit"]):
			say(f"task {task.id}: S{shard} pushed preview {event['name']} with a bad commit, ignored")
			return
		into = os.path.join(task.out, f"S{shard}", "previews", event["name"])
		os.makedirs(into, exist_ok=True)
		try:
			await asyncio.to_thread(commits.fetch_into, ROOT, os.path.join(task.out, ".commit-stores"), event["commit"], into)
		except Exception as error:
			say(f"S{shard}: could not fetch preview {event['name']}: {error}")
		await self.preview_ready(shard, event)

	async def previews_done(self, shard, event):
		"""A machine has sent every preview it had to render."""
		task = self.tasks.get(event["task"])
		if not task or shard not in task.previews_waiting:
			return
		task.previews_waiting.discard(shard)
		await self.emit({"type": "previews-done", "task": task.id, "shard": shard, "left": len(task.previews_waiting)})
		if not task.previews_waiting and getattr(task, "completed", False):
			del self.tasks[task.id]

	async def finished_shard(self, shard, event):
		task = self.tasks.get(event["task"])
		if not task or shard in task.done:
			return
		task.done[shard] = event.get("summary", "")
		say(f"task {task.id}: S{shard} done ({len(task.done)} of {task.count}): {task.done[shard].strip().replace(chr(10), ' ')}")
		await self.emit({"type": "shard", "task": task.id, "shard": shard, "summary": task.done[shard],
			"seconds": round(time.time() - task.started)})
		await self.keep_hosts_awake()
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
		await self.relay(task, "results", "uploaded.tsv")
		await self.relay(task, "results", "summary.txt")
		merged = None
		# Fake uploads must never reach the game's tables.
		mergeable = task.upload and not failed and not self.dry and not self.test_without_identity
		if mergeable and not self.git_link and not self.relay_results:
			merged = await asyncio.to_thread(self.merge, task)
		# Relayed: the session has the files and merges them itself (merge_here).
		event = {"type": "finished", "task": task.id, "out": task.out, "built": round(built),
			"total": round(time.time() - task.started), "objects": len(task.handed), "uploaded": len(task.sent & set(self.uploader.record)), "failed": failed,
			"width": round(self.uploader.throttle.limit, 1), "merged": merged, "previews_waiting": len(task.previews_waiting),
			"relayed": self.relay_results, "merge_here": bool(mergeable and self.relay_results), "layout": self.layout}
		self.finished[task.id] = (task, event)
		for old in list(self.finished)[:-KEEP_FINISHED]:
			del self.finished[old]
		await self.emit(event)
		# Kept while previews are still to come; previews_done lets it go.
		task.completed = True
		self.save_tasks()
		if not task.previews_waiting:
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

	async def post(self, identity, ref, upload, previews=(), build=True):
		task = Task(identity, ref, upload, self.count, previews, build)
		task.by_branch = self.uploads_on_machine
		self.tasks[identity] = task
		self.save_tasks()
		await self.keep_hosts_awake()
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

	async def admit(self, socket):
		"""Challenges a control connection; returns its request once the
		answer verifies, else None. The answer and the request may come in
		either order, and nothing is acted on before both are in."""
		nonce = os.urandom(32).hex()
		await socket.send(json.dumps({"type": "challenge", "nonce": nonce}))
		try:
			messages = await asyncio.wait_for(self.two_messages(socket), CHALLENGE_SECONDS)
		except (asyncio.TimeoutError, ValueError):
			return None
		answers = [message for message in messages if isinstance(message, dict) and message.get("type") == "answer"]
		requests = [message for message in messages if isinstance(message, dict) and message.get("type") != "answer"]
		if len(answers) != 1 or len(requests) != 1 or not await self.signed(nonce, answers[0].get("signature")):
			say("control connection refused: no valid signature")
			return None
		return requests[0]

	async def two_messages(self, socket):
		return [json.loads(await socket.recv()) for _ in range(2)]

	async def signed(self, nonce, signature):
		if not isinstance(signature, str) or len(signature) >= MAX_SIGNATURE or not signature.isascii():
			return False
		with tempfile.NamedTemporaryFile("w", suffix=".sig") as file:
			file.write(signature)
			file.flush()
			check = await asyncio.create_subprocess_exec("ssh-keygen", "-Y", "verify", "-f", self.control_signers,
				"-I", CONTROL_NAMESPACE, "-n", CONTROL_NAMESPACE, "-s", file.name,
				stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
			await check.communicate(nonce.encode())
		return check.returncode == 0

	async def control(self, socket, path=None):
		try:
			request = await self.admit(socket) if self.control_signers else json.loads(await socket.recv())
		except websockets.ConnectionClosed:
			return
		if request is None:
			await socket.close()
			return
		kind = request.get("type")
		if kind == "status":
			await socket.send(json.dumps({"type": "status", "run": self.run_id, "count": self.count,
				"up": sorted(self.agents), "tasks": list(self.tasks), "progress": self.progress,
				"machines": sorted(self.machines), "seats": {str(machine): shard for machine, shard in self.seats.items()},
				"task_states": self.task_states(), "run_started": self.run_started, **self.lifetime()}))
			return
		if kind == "clear-tasks":
			# Tasks no machine is working on (ALERT STRANDED_TASK); a machine
			# still sending for one is ignored from now on.
			cleared = list(self.tasks)
			self.tasks.clear()
			self.save_tasks()
			say(f"cleared {len(cleared)} tasks: {' '.join(cleared)}")
			await socket.send(json.dumps({"type": "cleared", "tasks": cleared}))
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
		if kind == "watch-task":
			# A session whose connection dropped mid-task picks it up again.
			identity = request.get("task")
			task, ended = self.tasks.get(identity), self.finished.get(identity)
			if not task and not ended:
				await socket.send(json.dumps({"type": "error", "text": f"the coordinator does not know task {identity}"}))
				return
			task = task or ended[0]
			self.watchers.add(socket)
			task.watchers.add(socket)
			await socket.send(json.dumps({"type": "watching", "task": task.id, "count": task.count, "up": len(self.agents)}))
			# Relayed files sent while it was gone: everything stored so far.
			if self.relay_results:
				for directory, folders, names in os.walk(task.out):
					folders[:] = [folder for folder in folders if not folder.startswith(".")]
					for name in sorted(names):
						await self.relay(task, "results", os.path.relpath(os.path.join(directory, name), task.out), to=socket)
			if ended and ended[0] is task:
				await socket.send(json.dumps(ended[1]))
			try:
				async for _ in socket:
					pass
			except websockets.ConnectionClosed:
				pass
			finally:
				self.watchers.discard(socket)
				task.watchers.discard(socket)
			return
		if kind == "mint-workers":
			# Tokens admit machines, so only a signed session may ask for them.
			if not self.control_signers and not self.test_without_identity:
				await socket.send(json.dumps({"type": "error", "text": "mint-workers needs a coordinator started with --control-key"}))
				return
			count = request.get("count")
			if not isinstance(count, int) or not 1 <= count <= MAX_WORKERS:
				await socket.send(json.dumps({"type": "error", "text": f"mint-workers wants a count from 1 to {MAX_WORKERS}"}))
				return
			pool, minted = self.mint(count)
			await socket.send(json.dumps({"type": "workers", "pool": pool, "workers": minted}))
			return
		if kind == "open-workers":
			# Seats decide who builds, so only a signed session may change them.
			if not self.control_signers and not self.test_without_identity:
				await socket.send(json.dumps({"type": "error", "text": "open-workers needs a coordinator started with --control-key"}))
				return
			if any(not getattr(task, "completed", False) for task in self.tasks.values()):
				await socket.send(json.dumps({"type": "error", "text": "a task is still building; seats change once it is done"}))
				return
			if not any(not machine.closed for machine in self.machines.values()):
				await socket.send(json.dumps({"type": "error", "text": "no numbered machines are connected"}))
				return
			seated = await self.open_workers()
			await socket.send(json.dumps({"type": "seated", "pool": self.seat_run, "machines": seated}))
			return
		if kind == "stop-machines":
			# Waiting machines too; a seated one is told once (it is in both).
			for worker in [socket for socket in self.machines.values() if socket not in self.agents.values()]:
				try:
					await worker.send(json.dumps({"type": "stop"}))
				except Exception:
					pass
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
		task = await self.post(identity, request["ref"], request.get("upload", True), request.get("previews", []),
			request.get("build", True))
		task.watchers.add(socket)
		await socket.send(json.dumps({"type": "posted", "task": identity, "count": task.count, "up": len(self.agents), **self.lifetime()}))
		try:
			async for _ in socket:
				pass
		except websockets.ConnectionClosed:
			pass
		finally:
			self.watchers.discard(socket)
			task.watchers.discard(socket)


def local_or_tailnet(host):
	try:
		address = ipaddress.ip_address(host)
	except ValueError:
		return False
	return address.is_loopback or (address.version == 4 and address in TAILNET)


def control_signers(public_key):
	"""An allowed-signers file holding only the session's public key."""
	fields = public_key.split()
	if len(fields) < 2 or not fields[0].startswith("ssh-"):
		sys.exit("--control-key wants a public key such as scripts/coordinator.sh key prints")
	path = os.path.join(tempfile.mkdtemp(prefix="control-key-"), "allowed_signers")
	with open(path, "w") as file:
		file.write(f"{CONTROL_NAMESPACE} {fields[0]} {fields[1]}\n")
	return path


async def serve(arguments):
	if arguments.test_without_identity and (arguments.agent_host != "127.0.0.1" or not (arguments.dry_upload or arguments.uploads_on_machine)):
		sys.exit("--test-without-identity is only for a local dry run (agent host 127.0.0.1, --dry-upload)")
	if arguments.relay_results and arguments.git_link:
		sys.exit("--relay-results replaces --git-link; pick one")
	coordinator = Coordinator(arguments.layout, arguments.dry_upload, arguments.test_without_identity, arguments.git_link,
		arguments.uploads_on_machine, arguments.relay_results)
	coordinator.loop = asyncio.get_running_loop()
	coordinator.load_tasks()
	if arguments.control_key:
		coordinator.control_signers = control_signers(arguments.control_key)
	elif not local_or_tailnet(arguments.control_host):
		sys.exit("--control-host off this machine and the tailnet needs --control-key")
	# A ping waits behind whatever a machine is sending, and the tunnel is
	# slow, so a big result could outlast websockets' 20 s and drop the machine.
	agents = await websockets.serve(coordinator.agent, arguments.agent_host, arguments.agent_port, max_size=MAX_MESSAGE,
		ping_interval=20, ping_timeout=120)
	control = await websockets.serve(coordinator.control, arguments.control_host, arguments.control_port, max_size=MAX_CONTROL_MESSAGE)
	os.makedirs(os.path.dirname(STATE), exist_ok=True)
	control_host = f"[{arguments.control_host}]" if ":" in arguments.control_host else arguments.control_host
	state = {"pid": os.getpid(), "control": f"ws://{control_host}:{arguments.control_port}",
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
	say(f"machines on {arguments.agent_host}:{arguments.agent_port}, control on {arguments.control_host}:{arguments.control_port}"
		+ (" (dry upload)" if arguments.dry_upload else "")
		+ (" (machine 1 uploads)" if arguments.uploads_on_machine else "")
		+ (" (results relayed)" if arguments.relay_results else "")
		+ (" (control needs the key)" if arguments.control_key else ""))
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
	# Machine 1 puts control on its tailnet address so a session can attach.
	parser.add_argument("--control-host", default="127.0.0.1")
	parser.add_argument("--control-port", type=int, default=8766)
	# Required off this machine and the tailnet (a tunnel): the one public
	# key whose signature admits a control connection.
	parser.add_argument("--control-key", default="")
	parser.add_argument("--dry-upload", action="store_true")
	# Local tests only: agents may connect with the token "test". Never with
	# a tunnel, which makes every outside connection look local.
	parser.add_argument("--test-without-identity", action="store_true")
	parser.add_argument("--git-link", action="store_true")
	parser.add_argument("--uploads-on-machine", action="store_true")
	# Results go back over the control link to the session that posted the task.
	parser.add_argument("--relay-results", action="store_true")
	asyncio.run(serve(parser.parse_args()))


if __name__ == "__main__":
	main()
