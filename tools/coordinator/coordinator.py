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

Every admitted machine joins one roster under a stable name: g<shard> for a
GitHub machine of the newest standby run (an older run's are closed),
m<n> for a numbered machine, w<k> for a minted worker. A posted task is cut
into N units (N = machines connected at post, at least 1, unless the
session asks for a number); unit i means what shard i of N always meant:
build shard i of N, then render preview unit i. The hub leases one unit at
a time to each idle machine ({"type": "task", "id", "task", "shard",
"count"}), oldest open task first; a machine that finishes its unit (done,
and previews-done when the task has previews) takes the next. A lease
comes back to the front of the queue when its machine's connection has
been closed for LEASE_GRACE_SECONDS, it has sent nothing for
LEASE_SILENT_SECONDS, or its unit has not moved for LEASE_WEDGED_SECONDS;
the old holder is sent {"type": "cancel", "task", "shard"} and is not
dealt again until it answers {"type": "idle"}. Anything it sends for that
unit afterwards is dropped. The session sees {"type": "redealt"} when the
unit goes to its new machine.

Each unit sends back its results (summary.txt, parts.txt, manifest.json,
costs.txt, error.txt, build.log) and the objects it built that have no
asset (handed/names.tsv first, then each .glb), into
.standby-results/<task>/S<i>/ as scripts/merge-shards.sh reads them. Each
object goes to the uploader (uploader.py) as soon as it lands. Once every
unit is done and every object uploaded, the task's uploaded.tsv is
written and the session told.

If a machine reconnects mid-unit, it is sent its unit again; it resends
what it already built instead of building twice. Its hello names the units
it is still working on, so a restarted coordinator gives them back to it.
Posted tasks are kept in tasks.json beside the state file until they
complete, so a restarted coordinator takes them back; a session that lost
its connection asks for its task again with {"type": "watch-task", "task": id}.

A machine that is not a GitHub one (scripts/cloud-worker.sh) is admitted
by a one-time token: {"type": "mint-workers", "count": n} (signed session
only) makes n tokens, kept in memory only, one live connection per token.
A numbered machine (scripts/cloud-worker.sh join) needs no minting: with
COORDINATOR_WORKER_KEY in the coordinator's environment, a hello with
"machine": n and "worker:<its lasting token>" (wire.machine_token) is
admitted and takes units at once. GitHub machines are told
{"type": "active"} when a task is posted or a unit finishes, so their idle
clocks restart.

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
RESULTS = os.path.join(ROOT, ".standby-results")
# When a leased unit goes back to the queue (Coordinator.lease_lost); each
# can be shortened through the environment or the constructor, for tests.
LEASE_GRACE_SECONDS = 30  # its machine's connection closed this long
LEASE_SILENT_SECONDS = 120  # nothing heard from its machine this long
LEASE_WEDGED_SECONDS = 300  # its log, files and claims all quiet this long
# A machine gone this long holding nothing leaves the roster.
GONE_FORGOTTEN_SECONDS = 600


def say(message):
	print(f"coordinator: {message}", file=sys.stderr, flush=True)


def share_out(asked, count, weights=None):
	"""The preview units of a task of `count` units: one name per unit when
	there are fewer models than units, each model given shares named
	<Name>@<i>@<n> in proportion to its weight (its measured machine-seconds,
	client.py preview_weights), at least one each, summing to count. A name
	ending in "!" is one machine's job whole, for timing a model on its own;
	the "!" is dropped. With as many models as units or more, the names as
	they are, each unit taking every count-th."""
	names = [name.rstrip("!") for name in asked]
	if not names or len(names) >= count:
		return names
	whole = {name[:-1] for name in asked if name.endswith("!")}
	split = [name for name in names if name not in whole]
	if not split:
		return names
	budget = count - (len(names) - len(split))
	weights = weights if isinstance(weights, dict) else {}
	weight = {}
	for name in split:
		given = weights.get(name)
		weight[name] = float(given) if isinstance(given, (int, float)) and not isinstance(given, bool) and given > 0 else 1.0
	total = sum(weight[name] for name in split)
	ideal = {name: budget * weight[name] / total for name in split}
	shares = {name: max(1, int(ideal[name])) for name in split}
	while sum(shares[name] for name in split) > budget:
		name = max((name for name in split if shares[name] > 1), key=lambda name: shares[name] - ideal[name])
		shares[name] -= 1
	while sum(shares[name] for name in split) < budget:
		name = max(split, key=lambda name: ideal[name] - shares[name])
		shares[name] += 1
	units = []
	for name in names:
		count_of = 1 if name in whole else shares[name]
		units += [name] if count_of == 1 else [f"{name}@{i}@{count_of}" for i in range(1, count_of + 1)]
	return units


class Lease:
	"""One unit held by one machine, from its deal until it is over or comes back."""

	def __init__(self, number, machine):
		self.number, self.machine = number, machine
		self.dealt = self.moved = time.time()
		# Jobs it claimed: [(model, kind), job, settled]. Unsettled ones go
		# back to the task when the lease does, so the replacement isn't starved.
		self.claims = []


class Machine:
	"""One roster entry: a connection that may drop and come back under the same name."""

	def __init__(self, name, kind):
		self.name, self.kind = name, kind  # kind: github, numbered or worker
		self.socket = None
		self.run = None
		self.closed_at = None
		self.heard = time.time()
		self.lease = None  # (task id, shard) it holds
		self.cancelling = {}  # (task id, shard) told to stop -> when last told, until it answers idle (or times out)
		self.progress = None  # its latest heartbeat, with the time it came
		self.dropped = set()  # (task id, shard) whose late messages were dropped, logged once

	def state(self, now):
		if self.socket is None:
			return {"name": self.name, "state": "gone", "gone_for": round(now - (self.closed_at or now)),
				"task": self.lease[0] if self.lease else None, "shard": self.lease[1] if self.lease else None}
		if self.lease:
			return {"name": self.name, "state": "unit", "task": self.lease[0], "shard": self.lease[1],
				"heard": round(now - self.heard)}
		return {"name": self.name, "state": "stopping" if self.cancelling else "idle"}


class Task:
	def __init__(self, identity, ref, upload, count, previews=(), build=True, weights=None, results=RESULTS):
		self.id, self.ref, self.upload, self.count = identity, ref, upload, count
		# Without a build the units only render the previews.
		self.build = build
		# Models whose previews the units render, shared out between them by
		# cost (share_out), and the units whose previews haven't all come yet;
		# shares_in counts the shares of each model that have come back.
		self.asked = list(previews)  # as posted, for the tasks file
		self.weights = dict(weights) if isinstance(weights, dict) else {}
		self.previews = [name.rstrip("!") for name in previews]
		self.units = share_out(self.asked, count, self.weights)
		self.shares_in = {}
		self.queues = {}  # (model, bake or render) -> the next job to hand out
		self.returned = {}  # (model, kind) -> jobs a returned lease claimed and never finished
		self.job_answers = {}  # (lease number, claim number) -> job, so a repeated claim gets the same one
		self.bakes = {}  # model -> share number -> commit of that machine's baked textures
		self.previews_waiting = set(range(1, count + 1)) if self.previews else set()
		self.queue = list(range(1, count + 1))  # units not leased, front first
		self.leases = {}  # shard -> its Lease
		self.moved_from = {}  # shard -> (machine, reason, its Lease) of a returned lease, until it is dealt again
		# Reloaded after a hub restart: not dealt before this time, so machines
		# still on its units reconnect and get them back first (load_tasks).
		self.held_until = 0
		self.started = time.time()
		self.done = {}  # shard -> summary text
		self.handed = {}  # object id -> (shard, label)
		self.labels = {}  # (shard, object id) -> label, from names.tsv
		self.sent = set()  # objects this task uploaded (the rest had assets)
		self.by_branch = False
		# Objects whose upload has been answered, each counted once however
		# often it is handed over (a re-dealt unit hands over the same ones).
		self.answered = set()
		self.received = {}  # shard -> [files, bytes] it sent, against MAX_SHARD_*
		self.watchers = set()  # control sockets of the session that posted it, for relayed files
		self.out = os.path.join(results, identity)
		os.makedirs(self.out, exist_ok=True)

	def text(self, shard=None):
		# When machine 1 uploads, objects go to it through GitHub, not this link.
		hand_over = "branch" if self.by_branch else "coordinator"
		# A unit re-dealt after its build came in only renders.
		build = self.build and shard not in self.done
		return (f"ref={self.ref}\nhand-over={hand_over}\n" + ("" if self.upload else "upload=no\n")
			+ ("" if build else "build=no\n")
			+ (f"preview={','.join(self.units)}\n" if self.units else ""))

	def unit_over(self, shard):
		return shard in self.done and shard not in self.previews_waiting


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
	def __init__(self, layout, dry, test_without_identity=False, git_link=False, uploads_on_machine=False, relay_results=False,
			timeouts=None, worker_key=None, tasks_file=None, results=None):
		self.layout = layout
		# Tests point these elsewhere (tools/coordinator/test_queue.py).
		self.tasks_file = tasks_file or TASKS
		self.results = results or RESULTS
		timeouts = timeouts or {}
		self.grace = float(timeouts.get("grace") or os.environ.get("COORDINATOR_LEASE_GRACE") or LEASE_GRACE_SECONDS)
		self.silent = float(timeouts.get("silent") or os.environ.get("COORDINATOR_LEASE_SILENT") or LEASE_SILENT_SECONDS)
		self.wedged = float(timeouts.get("wedged") or os.environ.get("COORDINATOR_LEASE_WEDGED") or LEASE_WEDGED_SECONDS)
		self.tick = min(1.0, self.grace / 4, self.silent / 4)
		# How long reloaded tasks wait for their machines after a restart: two
		# graces, the longest an agent's reconnect backoff sleeps (60 s).
		self.restart_hold = 2 * self.grace
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
		# The newest GitHub standby run, how new it is, and how many machines it asked for (ALERT SHORT).
		self.run_id = None
		self.run_rank = -1
		self.count = 0
		self.roster = {}  # name -> Machine, in the order they first joined
		self.leases_made = 0
		self.posted = 0  # tasks posted, for unique task ids
		self.tasks = {}  # oldest first: their units are dealt first
		self.watchers = set()  # control websockets waiting on events
		self.control_signers = None  # allowed-signers file, with --control-key
		self.finished = {}  # task id -> (task, its finished event), the last KEEP_FINISHED
		# Minted worker tokens, in memory only: token -> {"name": w<k>, "shard",
		# "count", "socket": its live connection or None}.
		self.workers = {}
		self.minted = 0
		# The key numbered machines' tokens are made from, out of the environment at once.
		self.worker_key = os.environ.pop("COORDINATOR_WORKER_KEY", "")
		if worker_key is not None:
			self.worker_key = worker_key
		self.watchdog = None
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
			"queued": len(task.queue), "leased": len(task.leases),
			"uploads_open": len(task.sent - task.answered), "previews_waiting": len(task.previews_waiting)}
			for task in self.tasks.values()}

	def connected(self):
		return [machine for machine in self.roster.values() if machine.socket is not None]

	def machines_event(self, machine=None, gone=False):
		connected = self.connected()
		event = {"type": "machine", "up": len(connected), "count": self.count,
			"github_up": sum(1 for each in connected if each.kind == "github" and each.run == self.run_id)}
		if machine:
			event["name"] = machine.name
		if gone:
			event["gone"], event["grace"] = True, self.grace
		return event

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

	def worker(self, token):
		"""The minted record of a worker token, or None. Every token is
		compared, in constant time, so timing tells nothing."""
		found = None
		for minted, record in self.workers.items():
			if hmac.compare_digest(minted.encode(), token.encode()):
				found = record
		return found

	def mint(self, count):
		"""count tokens, each admitting one worker named w<k>. The shard and
		count only number the printed lines (client.py mint-workers); a
		worker takes units like any other machine."""
		minted = []
		for shard in range(1, count + 1):
			token = secrets.token_hex(32)
			self.minted += 1
			self.workers[token] = {"name": f"w{self.minted}", "shard": shard, "count": count, "socket": None}
			minted.append({"shard": shard, "count": count, "token": token})
		say(f"minted {count} workers ({', '.join(entry['token'][:6] for entry in minted)}...)")
		return f"w{self.minted - count + 1}-w{self.minted}", minted

	async def keep_hosts_awake(self):
		self.last_active = time.time()
		for socket in list(self.hosts):
			try:
				await socket.send(json.dumps({"type": "active"}))
			except Exception:
				self.hosts.discard(socket)

	# --- the queue ---

	async def send_to(self, machine, message):
		"""Sends to a machine if it is connected; a dropped one hears it again
		when it reconnects (its lease, its cancels)."""
		if machine.socket is None:
			return
		try:
			await machine.socket.send(message)
		except Exception:
			pass

	def unit_message(self, task, shard):
		# The lease number comes back in claims, so a cancelled lease's late claim is refused (holding).
		lease = task.leases.get(shard)
		return json.dumps({"type": "task", "id": task.id, "task": task.text(shard), "shard": shard, "count": task.count,
			"lease": lease.number if lease else 0})

	async def tell_cancel(self, machine, task_id, shard):
		machine.cancelling[(task_id, shard)] = time.time()
		await self.send_to(machine, json.dumps({"type": "cancel", "task": task_id, "shard": shard}))

	async def deal(self):
		"""Leases the front queued unit of the oldest open task to each idle
		machine. Idle: connected, holding nothing, and every cancel answered.
		A task reloaded after a restart waits out its hold."""
		now = time.time()
		for machine in list(self.roster.values()):
			if machine.socket is None or machine.lease or machine.cancelling:
				continue
			task = next((task for task in self.tasks.values() if task.queue and task.held_until <= now), None)
			if not task:
				return
			await self.grant(machine, task, task.queue.pop(0))

	async def grant(self, machine, task, shard):
		"""A new lease of a unit already taken off the queue. A unit taken
		back from a machine starts clean here, when it is dealt again."""
		moved = task.moved_from.pop(shard, None)
		if moved and shard not in task.done:
			try:
				self.clear_unit(task, shard, moved[2].number)
			except Exception:
				# Left in place rather than lose the unit.
				say(f"task {task.id}: could not move S{shard}'s old results aside:\n{traceback.format_exc()}")
		self.leases_made += 1
		lease = Lease(self.leases_made, machine.name)
		if moved:
			say(f"task {task.id}: S{shard} re-dealt from {moved[0]} to {machine.name}: {moved[1]}")
			await self.emit({"type": "redealt", "task": task.id, "shard": shard, "from": moved[0], "to": machine.name, "reason": moved[1]})
		await self.lease_to(machine, task, shard, lease)

	async def lease_to(self, machine, task, shard, lease):
		task.leases[shard] = lease
		machine.lease = (task.id, shard)
		machine.dropped.discard((task.id, shard))
		# A unit it was told to stop and now holds again is owed no cancel.
		machine.cancelling.pop((task.id, shard), None)
		await self.send_to(machine, self.unit_message(task, shard))

	async def give_back(self, machine, task, shard):
		"""A machine reconnected still on a queued unit (its lease taken back
		after the grace, or the hub restarted): it keeps the unit, with no
		cancel. Its own returned lease comes back whole, claims and all."""
		moved = task.moved_from.get(shard)
		if not moved or moved[0] != machine.name:
			say(f"task {task.id}: {machine.name} is still on S{shard}; it keeps it")
			await self.grant(machine, task, shard)
			return
		del task.moved_from[shard]
		lease = moved[2]
		for key, job, settled in lease.claims:
			if not settled and job in task.returned.get(key, []):
				task.returned[key].remove(job)
		lease.moved = time.time()
		say(f"task {task.id}: {machine.name} came back still on S{shard}; its lease is given back")
		await self.lease_to(machine, task, shard, lease)

	async def unit_over(self, task, shard):
		"""Once a unit's build and previews are in, its machine is idle."""
		if not task.unit_over(shard):
			return
		lease = task.leases.pop(shard, None)
		if not lease:
			return
		machine = self.roster.get(lease.machine)
		if machine and machine.lease == (task.id, shard):
			machine.lease = None
		await self.emit({"type": "progress", "task": task.id, "shard": shard, "machine": lease.machine, "stage": "done",
			"model": "", "line": "", "quiet": 0, "seconds": round(time.time() - lease.dealt)})
		await self.deal()

	def lease_lost(self, machine, lease, now):
		"""Why a lease goes back to the queue now, or None while it holds."""
		if machine is None:
			return "its machine left the roster"
		if machine.socket is None:
			gone = now - (machine.closed_at or now)
			return f"connection closed for {gone:.0f}s" if gone >= self.grace else None
		heard = now - max(machine.heard, lease.dealt)
		if heard >= self.silent:
			return f"no heartbeat for {heard:.0f}s"
		quiet = now - lease.moved
		if quiet >= self.wedged:
			return f"wedged: its log quiet for {quiet:.0f}s"
		return None

	async def redeal(self, task, shard, reason):
		"""Puts a leased unit back at the front of the queue, tells its old
		holder to stop, and deals it again."""
		lease = task.leases.pop(shard, None)
		if not lease:
			return
		# Queued first, so nothing below can leave it neither queued nor leased.
		# Its folder is cleared when it is dealt again (grant), not here: its
		# machine may come back for it (give_back).
		task.queue.insert(0, shard)
		task.moved_from[shard] = (lease.machine, reason, lease)
		# Jobs it claimed and never delivered go to whoever claims next.
		for key, job, settled in lease.claims:
			if not settled:
				task.returned.setdefault(key, []).append(job)
				task.returned[key].sort()
		machine = self.roster.get(lease.machine)
		if machine and machine.lease == (task.id, shard):
			machine.lease = None
			await self.tell_cancel(machine, task.id, shard)
		say(f"task {task.id}: S{shard} taken back from {lease.machine}: {reason}")
		await self.deal()

	def clear_unit(self, task, shard, lease_number):
		"""A re-dealt unit starts clean: what its folder holds moves aside to
		.redealt/ (merge-shards.sh reads only S*, the relay skips dot folders).
		The objects stay: the uploader may be reading them, and the
		replacement hands over the same ones under the same ids."""
		folder = os.path.join(task.out, f"S{shard}")
		task.received.pop(shard, None)
		for key in [key for key in task.labels if key[0] == shard]:
			del task.labels[key]
		if not os.path.isdir(folder):
			return
		aside = os.path.join(task.out, ".redealt", f"S{shard}-L{lease_number}")
		os.makedirs(aside, exist_ok=True)
		for entry in os.listdir(folder):
			if entry != "handed":
				shutil.move(os.path.join(folder, entry), os.path.join(aside, entry))
				continue
			handed = os.path.join(folder, entry)
			for name in os.listdir(handed):
				if not name.endswith(".glb"):
					os.makedirs(os.path.join(aside, entry), exist_ok=True)
					shutil.move(os.path.join(handed, name), os.path.join(aside, entry, name))

	async def watch_leases(self):
		"""Takes back leases whose machines are gone, silent or wedged, drops
		cancels never answered, ends restart holds, and forgets machines long
		gone that hold nothing."""
		while True:
			await asyncio.sleep(self.tick)
			try:
				now = time.time()
				freed = False
				for task in list(self.tasks.values()):
					for shard, lease in list(task.leases.items()):
						reason = self.lease_lost(self.roster.get(lease.machine), lease, now)
						if reason:
							await self.redeal(task, shard, reason)
					if task.held_until and now >= task.held_until:
						task.held_until, freed = 0, True
				for machine in list(self.roster.values()):
					for key, since in list(machine.cancelling.items()):
						# Heard from since, yet no idle for the silent limit: the answer is not coming.
						if machine.socket is not None and machine.heard > since and now - since >= self.silent:
							del machine.cancelling[key]
							freed = True
							say(f"{machine.name} never answered the cancel of S{key[1]} of {key[0]}; taken as idle")
					if machine.socket is None and not machine.lease and now - (machine.closed_at or now) >= GONE_FORGOTTEN_SECONDS:
						del self.roster[machine.name]
				if freed:
					await self.deal()
			except Exception:
				say(f"lease watch failed:\n{traceback.format_exc()}")

	def save_tasks(self):
		"""Writes the tasks not yet completed to the tasks file, with the
		units already done, so a restart does not build them again."""
		open_tasks = {task.id: {"ref": task.ref, "upload": task.upload, "previews": task.asked, "build": task.build,
			"count": task.count, "weights": task.weights, "done": {str(shard): summary for shard, summary in task.done.items()},
			"previews_waiting": sorted(task.previews_waiting)}
			for task in self.tasks.values() if not getattr(task, "completed", False)}
		os.makedirs(os.path.dirname(self.tasks_file), exist_ok=True)
		with open(self.tasks_file + ".new", "w") as file:
			json.dump(open_tasks, file)
		os.replace(self.tasks_file + ".new", self.tasks_file)

	def load_tasks(self):
		"""Takes back the tasks a previous coordinator left open, every unit
		not over queued but held for restart_hold: a machine that reconnects
		names the units it is still on and gets them back (greet) before any
		is dealt. Never raises: a bad file or entry is logged and skipped."""
		try:
			if not os.path.isfile(self.tasks_file):
				return
			open_tasks = json.load(open(self.tasks_file))
			if not isinstance(open_tasks, dict):
				say(f"ignoring a tasks file that is not an object: {type(open_tasks).__name__}")
				return
			for identity, fields in open_tasks.items():
				if not self.task_entry_fits(identity, fields):
					say(f"skipping a bad tasks file entry: {str(identity)[:40]!r}")
					continue
				task = Task(identity, fields["ref"], fields["upload"], fields["count"], fields.get("previews", []), fields.get("build", True),
					fields.get("weights"), self.results)
				task.by_branch = self.uploads_on_machine
				for shard, summary in (fields.get("done") or {}).items():
					if str(shard).isdigit() and 1 <= int(shard) <= task.count and isinstance(summary, str):
						task.done[int(shard)] = summary
				waiting = fields.get("previews_waiting")
				if task.previews and isinstance(waiting, list):
					task.previews_waiting = {shard for shard in waiting if isinstance(shard, int) and 1 <= shard <= task.count}
				task.queue = [shard for shard in task.queue if not task.unit_over(shard)]
				task.held_until = time.time() + self.restart_hold
				self.tasks[identity] = task
				say(f"task {identity} taken back from the tasks file, {len(task.done)} of {task.count} units done")
		except Exception as error:
			say(f"ignoring an unreadable tasks file: {error}")

	@staticmethod
	def task_entry_fits(identity, fields):
		"""Whether a tasks file entry has the shape save_tasks writes."""
		return (TASK_NAME.fullmatch(identity) is not None and isinstance(fields, dict)
			and isinstance(fields.get("ref"), str) and isinstance(fields.get("upload"), bool)
			and isinstance(fields.get("count"), int) and not isinstance(fields.get("count"), bool) and fields["count"] >= 1
			and isinstance(fields.get("previews", []), list) and all(isinstance(name, str) for name in fields.get("previews", []))
			and isinstance(fields.get("build", True), bool) and isinstance(fields.get("weights") or {}, dict)
			and isinstance(fields.get("done") or {}, dict) and isinstance(fields.get("previews_waiting") or [], list))

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
			# Once per object: machine 1 answers again for one handed over twice.
			if identity in task.handed and identity not in task.answered:
				task.answered.add(identity)
				await self.emit({"type": "uploaded", "task": task.id, "object": identity, "label": task.handed[identity][1],
					"asset": asset, "error": error, "done": len(task.answered), "of": len(task.sent)})

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
		if self.watchdog is None:
			self.watchdog = asyncio.ensure_future(self.watch_leases())
		record = None
		try:
			hello = json.loads(await asyncio.wait_for(socket.recv(), 30))
			token = hello.get("token", "")
			run, count = None, 0
			if "machine" in hello:
				# A numbered machine: admitted by the token made from the worker key.
				number = hello["machine"]
				good = (self.worker_key and isinstance(number, int) and 1 <= number <= MAX_WORKERS and isinstance(token, str)
					and hmac.compare_digest(token.encode(), (WORKER_PREFIX + wire.machine_token(self.worker_key, number)).encode()))
				if not good:
					raise ValueError("unknown machine token")
				name, kind = f"m{number}", "numbered"
			elif isinstance(token, str) and token.startswith(WORKER_PREFIX):
				# A minted worker: who it is comes from the token, never the hello.
				record = self.worker(token[len(WORKER_PREFIX):]) if len(token) > len(WORKER_PREFIX) else None
				if not record:
					raise ValueError("unknown worker token")
				if record["socket"] is not None and not record["socket"].closed:
					record = None
					raise ValueError("that worker token is already connected")
				record["socket"] = socket
				name, kind = record["name"], "worker"
			else:
				if self.test_without_identity and token == "test":
					claims = {"run_id": "1", "workflow_ref": WORKFLOW}
				else:
					claims = await asyncio.to_thread(oidc.verify, token, REPOSITORY)
				if WORKFLOW not in claims.get("workflow_ref", ""):
					raise ValueError("not a standby machine")
				run, shard, count = str(claims["run_id"]), int(hello["shard"]), int(hello["count"])
				if not 1 <= shard <= MAX_WORKERS:
					raise ValueError(f"shard {shard} out of range")
				name, kind = f"g{shard}", "github"
		except Exception as error:
			say(f"refused a connection: {error}")
			await socket.close(code=4001, reason="not allowed")
			return
		if kind == "github" and not await self.newest_run(run, count):
			await socket.close(code=4002, reason="an older run")
			return
		machine = self.roster.get(name)
		if machine is None:
			machine = self.roster[name] = Machine(name, kind)
		elif machine.socket is not None and not machine.socket.closed and time.time() - machine.heard < self.silent:
			# Two machines under one name would take each other's connection
			# forever; the one already here and heard from keeps it.
			say(f"refused a second connection as {name}: the first is open and was heard {time.time() - machine.heard:.0f}s ago")
			if record and record["socket"] is socket:
				record["socket"] = None
			await socket.close(code=4003, reason="that name is already connected")
			return
		old, machine.socket, machine.run = machine.socket, socket, run
		machine.closed_at, machine.heard = None, time.time()
		if old is not None and not old.closed:
			await old.close(code=4004, reason="connected again")
		try:
			await self.serve_machine(machine, socket, hello)
		finally:
			# Its token may connect again.
			if record and record["socket"] is socket:
				record["socket"] = None

	async def newest_run(self, run, count):
		"""Whether a GitHub machine of `run` may join: not when a newer run
		has. A newer run closes the older one's machines; their units go back."""
		rank = int(run) if run.isdigit() else 0
		if self.run_id is not None and run != self.run_id and rank < self.run_rank:
			return False
		if run == self.run_id:
			return True
		for machine in [machine for machine in self.roster.values() if machine.kind == "github"]:
			if machine.lease:
				task = self.tasks.get(machine.lease[0])
				if task:
					await self.redeal(task, machine.lease[1], "its standby run was replaced by a newer one")
			if machine.socket is not None:
				await machine.socket.close(code=4002, reason="an older run")
			del self.roster[machine.name]
		self.run_id, self.run_rank, self.count, self.run_started = run, rank, count, time.time()
		say(f"standby run {run} with {count} machines")
		return True

	async def greet(self, machine, hello):
		"""A machine that just connected. First the units its hello says it is
		still on: one still queued goes back to it with no cancel (give_back:
		a reconnect after the grace, or a restarted coordinator); any other
		it is told to stop. Then its lease again (a reconnect inside the
		grace), every cancel still owed, and a unit if it is idle."""
		if machine.lease and machine.lease[0] not in self.tasks:
			machine.lease = None
		elif machine.lease:
			await self.send_to(machine, self.unit_message(self.tasks[machine.lease[0]], machine.lease[1]))
		named = hello.get("units") if isinstance(hello.get("units"), list) else []
		for entry in named[:8]:
			if not (isinstance(entry, list) and len(entry) == 2 and isinstance(entry[0], str) and isinstance(entry[1], int)):
				continue
			task_id, shard = entry
			task = self.tasks.get(task_id)
			if machine.lease == (task_id, shard) or (task and task.unit_over(shard)):
				continue
			if task and not machine.lease and shard in task.queue:
				task.queue.remove(shard)
				await self.give_back(machine, task, shard)
				continue
			machine.cancelling[(task_id, shard)] = time.time()
		for task_id, shard in list(machine.cancelling):
			await self.tell_cancel(machine, task_id, shard)
		await self.deal()

	def holding(self, machine, event):
		"""The task, shard and lease a message is about, if this machine holds
		that lease now; else None (a late message from an old holder, or a
		claim naming a lease of this machine's that was cancelled)."""
		task = self.tasks.get(event.get("task")) if isinstance(event.get("task"), str) else None
		shard = event.get("shard")
		lease = task.leases.get(shard) if task and isinstance(shard, int) else None
		number = event.get("lease")
		if lease and lease.machine == machine.name and machine.lease == (task.id, shard) and (number is None or number == lease.number):
			return task, shard, lease
		key = (event.get("task"), shard)
		# The last heartbeat of a unit that is over is no news.
		if task and key not in machine.dropped and not task.unit_over(shard):
			machine.dropped.add(key)
			say(f"task {task.id}: dropping what {machine.name} sends for S{shard}, a unit it does not hold")
		return None

	async def serve_machine(self, machine, socket, hello):
		"""An admitted machine's connection, from its hello to its close."""
		name = machine.name
		if machine.kind == "github":
			self.hosts.add(socket)
		await self.emit(self.machines_event(machine))
		# A worker has no Roblox key; only a GitHub machine 1 uploads.
		if self.uploads_on_machine and name == "g1":
			width = known = None
			if os.path.isfile(self.uploader.width_path):
				try:
					fields = [float(field) for field in open(self.uploader.width_path).read().split()]
					width, known = fields[0], fields[1] if len(fields) > 1 else None
				except (ValueError, IndexError):
					pass
			await socket.send(json.dumps({"type": "uploader", "layout": self.layout, "width": width, "known": known}))
			await self.uploader.connected(socket)
		parts = {}  # big files arriving in parts on this connection (join_part)
		try:
			await self.greet(machine, hello)
			async for message in socket:
				if machine.socket is not socket:
					break
				machine.heard = time.time()
				if isinstance(message, bytes):
					header, data = wire.unpack(message)
					if header.get("type") == "file-part":
						data = self.join_part(parts, header, data)
						if data is None:
							continue
					unit = self.holding(machine, header)
					if unit:
						unit[2].moved = time.time()
						await self.file(unit[0], unit[1], header, data)
					continue
				event = json.loads(message)
				kind = event.get("type")
				if kind == "uploaded" and self.uploads_on_machine:
					self.uploader.answered(event)
					await self.uploaded(event["id"], event.get("asset"), event.get("error"))
					continue
				if kind == "idle":
					if isinstance(event.get("task"), str) and isinstance(event.get("shard"), int):
						machine.cancelling.pop((event["task"], event["shard"]), None)
					await self.deal()
					continue
				if kind == "log":
					held = machine.lease[1] if machine.lease else None
					say(f"{name}: {event.get('text', '')}")
					await self.emit({"type": "log", "machine": name, "shard": held, "text": event.get("text", "")})
					continue
				unit = self.holding(machine, event)
				if not unit:
					if kind == "claim":
						# A stopped unit's engine gets nothing more.
						await socket.send(json.dumps({"type": "claimed", "id": event.get("id"), "job": -1}))
					continue
				task, shard, lease = unit
				if kind != "progress":
					lease.moved = time.time()
				if kind == "done":
					await self.finished_shard(task, shard, event, name)
				elif kind == "preview-ready":
					await self.preview_ready(task, shard, event, lease)
				elif kind == "preview-pushed":
					await self.preview_pushed(task, shard, event, lease)
				elif kind == "previews-done":
					await self.previews_done(task, shard)
				elif kind == "claim":
					await socket.send(json.dumps({"type": "claimed", "id": event["id"], "job": self.next_job(task, lease, event)}))
				elif kind == "bakes-pushed":
					await self.bakes_pushed(task, event, lease)
				elif kind == "progress":
					now = time.time()
					quiet = event.get("quiet") if isinstance(event.get("quiet"), (int, float)) else 0
					lease.moved = max(lease.moved, now - quiet)
					machine.progress = {**event, "heard": now}
					await self.emit({**event, "shard": shard, "machine": name})
		except websockets.ConnectionClosed as closed:
			say(f"{name} closed: {closed}")
		except Exception:
			# Anything else would close the connection without a word.
			say(f"{name} handler failed:\n{traceback.format_exc()}")
		finally:
			if self.uploads_on_machine and self.uploader.agent is socket:
				self.uploader.agent = None
				if self.uploader.pending:
					await self.emit({"type": "warning", "text": f"machine 1 dropped with {len(self.uploader.pending)} uploads unanswered; they go again when it reconnects"})
			self.hosts.discard(socket)
			if machine.socket is socket:
				machine.socket, machine.closed_at = None, time.time()
				say(f"{name} disconnected" + (f"; S{machine.lease[1]} of {machine.lease[0]} comes back after {self.grace:.0f}s unless it reconnects" if machine.lease else ""))
				await self.emit(self.machines_event(machine, gone=True))

	async def file(self, task, shard, header, data):
		raw = header.get("path")
		# A unit re-dealt after its build came in sends only its previews.
		if shard in task.done and not (isinstance(raw, str) and raw.startswith("previews/")):
			return
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

	def settle(self, lease, model):
		"""A lease delivered a model's work (its bakes pushed, or its renders
		in): the jobs it claimed for that model stay done if it is re-dealt."""
		for claim in lease.claims:
			if claim[0][0] == model:
				claim[2] = True

	async def preview_ready(self, task, shard, event, lease=None):
		"""One model's renders are in: put them beside the model (preview.png,
		the four turns as views.png, and the model script's hash in
		previewed.txt, so send-build knows it has a preview) and say so."""
		if not self.preview_model(task, shard, event.get("name")):
			return
		name = event["name"]
		if lease:
			self.settle(lease, name.split("@")[0])
			seconds = event.get("seconds")
			if isinstance(seconds, (int, float)) and not isinstance(seconds, bool) and seconds >= 0:
				# Machine-seconds per model share, for client.py's cost-sized shares.
				await self.emit({"type": "preview-share", "task": task.id, "name": name.split("@")[0], "unit": name,
					"seconds": round(seconds, 1)})
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

	def next_job(self, task, lease, event):
		"""Hands out a model's jobs in order to whichever machine asks next, so
		one that finishes early takes more; jobs a returned lease left
		unfinished first. -1 when none are left."""
		if not isinstance(event.get("total"), int) or not isinstance(event.get("name"), str) or not isinstance(event.get("kind"), str):
			return -1
		claim = (lease.number, event.get("id"))
		if claim not in task.job_answers:
			key = (event["name"], event["kind"])
			returned = task.returned.get(key)
			if returned:
				job = returned.pop(0)
			else:
				job = task.queues.get(key, 0)
				task.queues[key] = job + 1
				if job >= event["total"]:
					job = -1
			task.job_answers[claim] = job
			if job >= 0:
				lease.claims.append([key, job, False])
		return task.job_answers[claim]

	async def bakes_pushed(self, task, event, lease=None):
		"""A unit has baked its share of a model's textures. Once every share
		has, tells them all which commits to fetch."""
		fields = event.get("share").split("@") if isinstance(event.get("share"), str) else []
		if len(fields) != 3 or not fields[2].isdigit():
			return
		name, share, shares = fields
		if lease:
			self.settle(lease, name)
		pushed = task.bakes.setdefault(name, {})
		# A replacement that had nothing left to bake keeps its predecessor's commit.
		pushed[share] = event.get("commit") or pushed.get(share, "")
		# Every push is announced, so a machine that gives up waiting for a
		# slow peer still takes what has arrived and bakes only the rest.
		message = json.dumps({"type": "bakes-ready", "task": task.id, "name": name, "done": len(pushed) >= int(shares),
			"commits": [commit for commit in pushed.values() if commit]})
		for machine in self.connected():
			await self.send_to(machine, message)  # one that misses it times out and the render bakes the rest

	async def preview_pushed(self, task, shard, event, lease=None):
		"""A machine pushed a finished preview to GitHub: take its files from
		there, then treat it as arrived."""
		if not self.preview_model(task, shard, event.get("name")):
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
		await self.preview_ready(task, shard, event, lease)

	async def previews_done(self, task, shard):
		"""A unit has sent every preview it had to render."""
		if shard not in task.previews_waiting:
			return
		task.previews_waiting.discard(shard)
		self.save_tasks()
		await self.emit({"type": "previews-done", "task": task.id, "shard": shard, "left": len(task.previews_waiting)})
		await self.unit_over(task, shard)
		if not task.previews_waiting and getattr(task, "completed", False):
			self.tasks.pop(task.id, None)

	async def finished_shard(self, task, shard, event, machine=""):
		if shard in task.done:
			return
		summary = event.get("summary", "")
		task.done[shard] = summary if isinstance(summary, str) else ""
		self.save_tasks()
		say(f"task {task.id}: S{shard} done by {machine} ({len(task.done)} of {task.count}): {task.done[shard].strip().replace(chr(10), ' ')}")
		await self.emit({"type": "shard", "task": task.id, "shard": shard, "machine": machine, "summary": task.done[shard],
			"seconds": round(time.time() - task.started)})
		await self.keep_hosts_awake()
		if len(task.done) >= task.count:
			asyncio.create_task(self.complete(task))
		await self.unit_over(task, shard)

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
			self.tasks.pop(task.id, None)

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

	async def post(self, identity, ref, upload, previews=(), build=True, units=None, weights=None):
		"""Cuts a task into units (as many as machines are connected, unless
		asked) and queues them; the caller deals them (deal) once the session
		knows the task's id."""
		count = units if isinstance(units, int) and not isinstance(units, bool) and 1 <= units <= MAX_WORKERS * 4 else max(1, len(self.connected()))
		task = Task(identity, ref, upload, count, previews, build, weights, self.results)
		task.by_branch = self.uploads_on_machine
		self.tasks[identity] = task
		self.save_tasks()
		await self.keep_hosts_awake()
		say(f"task {identity}: {count} units for {len(self.connected())} machines" + (f", previews {','.join(task.units)}" if task.units else ""))
		return task

	# --- a session reached through git (--git-link) ---

	def git(self, *arguments, **options):
		return subprocess.run(["git", *arguments], cwd=ROOT, capture_output=True, text=True, **options)

	async def link(self):
		"""Takes tasks posted to build-queue since this coordinator started."""
		since, seen, taken = int(time.time()), "", set()
		while True:
			head = (await asyncio.to_thread(self.git, "ls-remote", "origin", "refs/heads/build-queue")).stdout.split("\t")[0]
			if head and head != seen and self.roster:
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
							await self.deal()
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
			now = time.time()
			connected = self.connected()
			await socket.send(json.dumps({"type": "status", "run": self.run_id, "count": self.count,
				"up": [machine.name for machine in connected], "tasks": list(self.tasks),
				"github_up": self.machines_event()["github_up"],
				"roster": [machine.state(now) for machine in self.roster.values()],
				"progress": {machine.name: machine.progress for machine in self.roster.values() if machine.progress and machine.lease},
				"queues": {task.id: len(task.queue) for task in self.tasks.values()},
				"machines": sorted(int(machine.name[1:]) for machine in connected if machine.kind == "numbered"),
				"lease_seconds": {"grace": self.grace, "silent": self.silent, "wedged": self.wedged},
				"task_states": self.task_states(), "run_started": self.run_started, **self.lifetime()}))
			return
		if kind == "clear-tasks":
			# Tasks no machine is working on (ALERT STRANDED_TASK); a machine
			# still on one of their units is told to stop.
			cleared = list(self.tasks)
			for task in self.tasks.values():
				for shard, lease in task.leases.items():
					machine = self.roster.get(lease.machine)
					if machine and machine.lease == (task.id, shard):
						machine.lease = None
						await self.tell_cancel(machine, task.id, shard)
			self.tasks.clear()
			self.save_tasks()
			say(f"cleared {len(cleared)} tasks: {' '.join(cleared)}")
			await socket.send(json.dumps({"type": "cleared", "tasks": cleared}))
			return
		if kind == "watch":
			# Streams machine and task events until the watcher hangs up.
			await socket.send(json.dumps({"type": "machines", "run": self.run_id, "count": self.count, "up": len(self.connected())}))
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
			await socket.send(json.dumps({"type": "watching", "task": task.id, "count": task.count, "up": len(self.connected())}))
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
		if kind == "stop-machines":
			connected = self.connected()
			for machine in connected:
				await self.send_to(machine, json.dumps({"type": "stop"}))
			await socket.send(json.dumps({"type": "stopped", "machines": len(connected)}))
			return
		if kind != "build":
			await socket.send(json.dumps({"type": "error", "text": f"unknown request {kind}"}))
			return
		previews = request.get("previews", [])
		if not isinstance(request.get("ref"), str) or not isinstance(previews, list) or not all(isinstance(name, str) for name in previews):
			await socket.send(json.dumps({"type": "error", "text": "a build wants a ref and a list of preview names"}))
			return
		self.posted += 1
		identity = f"t{int(time.time())}-{os.getpid()}-{self.posted}"
		self.watchers.add(socket)
		task = await self.post(identity, request["ref"], request.get("upload", True), previews,
			request.get("build", True), request.get("units"), request.get("weights"))
		task.watchers.add(socket)
		event = self.machines_event()
		await socket.send(json.dumps({"type": "posted", "task": identity, "count": task.count, "up": event["up"],
			"github_up": event["github_up"], "run_count": self.count, "units": task.units, "relayed": self.relay_results,
			"lease_seconds": {"grace": self.grace, "silent": self.silent, "wedged": self.wedged}, **self.lifetime()}))
		# Dealt only now, so nothing about the task reaches the session before its id.
		await self.deal()
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
