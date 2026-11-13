#!/usr/bin/env python3
"""Keeps one standby build machine on a live connection to the coordinator
(tools/coordinator/coordinator.py): it is sent each task the moment it is
posted, builds it, and sends the results straight back, so nothing polls.

  scripts/standby-agent.py <coordinator url> <Layout> <index> <count> <idle minutes> <max minutes>

It proves who it is with the identity token GitHub gives this job (the
workflow grants id-token: write). A task is run as scripts/standby.sh runs
one: its commit checked out, then that commit's scripts/standby-task.sh,
into results/<task id>/. Then every file there goes back to the
coordinator, the handed-over objects' names.tsv before the objects, and a
"done" message last.

Machine 1 may also be the uploader (the coordinator says so): objects
arrive over the connection and are uploaded with this job's
ROBLOX_API_KEY by tools/coordinator/uploader.py, each asset id sent back
as soon as it's known.

A dropped connection is retried with backoff (1 s doubling to 30 s); with
no coordinator for LOST_MINUTES the machine ends, freeing its slot. A task
sent again after a reconnect is not rebuilt: what it left is sent again.
The machine ends after <idle minutes> without a task, at <max minutes>, or
when the coordinator says stop.

A numbered machine (scripts/cloud-worker.sh join) passes "published" as the
url and 0 as the count. It reads the coordinator's address from
address.json on the branch build-results/coordinator-address before every
connection, so it follows a coordinator whose address changed or that was
started again, and it never gives up for lack of one. Its hello carries its
number; the coordinator answers {"type": "welcome"} with the shard and
count it builds as, which may change between tasks.
"""
import asyncio
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request

import websockets

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "coordinator"))
import commits  # noqa: E402
import uploader as uploading  # noqa: E402
import wire  # noqa: E402

MAX_MESSAGE = 64 * 1024 * 1024
LOST_MINUTES = 3
ADDRESS_BRANCH = "build-results/coordinator-address"
HEARTBEAT_SECONDS = 10
SWAP_WAIT_SECONDS = 60
CLAIM_WAIT_SECONDS = 15
CLAIM_TRIES = 4
LOG_LINES_KEPT = 200
REQUIRED_TOOLS = ("rg", "sd", "jq")
AUDIENCE = "scrap-heist-coordinator"
# A file bigger than this goes in parts, so heartbeats get onto the wire
# between them instead of waiting behind the whole file (send_file).
PART_BYTES = 1024 * 1024
# Failed connections in a row before ALERT TUNNEL_DOWN.
TUNNEL_ALERT_FAILURES = 3


# Lines also go to the coordinator, live, once connected (Agent.session).
forward = None


def say(message):
	# Wall-clock time to the millisecond, so a build's steps can be lined up
	# across machines (GitHub's runners keep their clocks synced).
	now = time.time()
	message = f"{time.strftime('%H:%M:%S', time.gmtime(now))}.{int(now % 1 * 1000):03d} {message}"
	print(f"agent: {message}", file=sys.stderr, flush=True)
	if forward:
		forward(message)


def alert(line):
	"""An ALERT or CLEARED line (docs/plans/multi-machine.md, Alerts): alone
	on its line in the job log, and passed to the hub when connected."""
	print(line, file=sys.stderr, flush=True)
	if forward:
		forward(line)


def http_status(error):
	"""The HTTP status a refused websocket handshake answered with, or None
	(websockets 10 names it status_code, 13 keeps it on the response)."""
	code = getattr(error, "status_code", None)
	return code or getattr(getattr(error, "response", None), "status_code", None)


def free_space():
	"""Free disk for the work folder and available memory, in GB, for heartbeats."""
	disk = shutil.disk_usage(os.getcwd()).free / 1e9
	memory = None
	try:
		with open("/proc/meminfo") as file:
			for line in file:
				if line.startswith("MemAvailable:"):
					memory = round(int(line.split()[1]) / 1e6, 1)
					break
	except OSError:
		pass
	return round(disk, 1), memory


def remote_head(branch):
	"""The commit a branch on GitHub points at, or ""."""
	listed = subprocess.run(["git", "ls-remote", "origin", f"refs/heads/{branch}"], capture_output=True, text=True, timeout=60)
	return listed.stdout.split("\t")[0].strip() if listed.returncode == 0 else ""


def ensure_tools():
	"""Here rather than as a workflow step: a machine runs the workflow file
	from main but this agent from the pushed work in progress, and a machine
	that can't reach a release still takes tasks (session() names what's missing)."""
	os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
	subprocess.run([os.path.join(ROOT, "scripts/ensure-tools.sh")], capture_output=True)


def trim_log(path):
	"""A render's log runs to hundreds of KB; its end says what went wrong."""
	try:
		with open(path, errors="replace") as file:
			lines = file.readlines()
	except OSError:
		return
	if len(lines) > LOG_LINES_KEPT:
		with open(path, "w") as file:
			file.writelines(lines[-LOG_LINES_KEPT:])


def push_bakes(model, share, out, since):
	"""Pushes the paint layers saved since `since`; returns the commit, or ""."""
	cache = os.path.join("art", "models", model, ".cache")
	fresh = tempfile.mkdtemp(dir=out)
	try:
		for entry in os.scandir(cache) if os.path.isdir(cache) else []:
			if entry.stat().st_mtime >= since:
				os.link(entry.path, os.path.join(fresh, entry.name))
		if not os.listdir(fresh):
			return ""
		branch = "build-bakes/" + share.replace("@", "-")
		pushed = subprocess.run(["scripts/push-folder.sh", fresh, branch, f"bakes {share}"], capture_output=True, text=True)
		if pushed.returncode != 0 and "cannot lock ref" in pushed.stderr and "reference already exists" in pushed.stderr:
			# Another machine saved the same bake first: theirs serves as ours.
			say(f"bakes of {share} already saved by another machine; taking theirs")
			return remote_head(branch)
		if pushed.returncode != 0:
			say(f"could not push bakes of {share}: {pushed.stderr.strip()[-200:]}")
			return ""
		return pushed.stdout.strip()
	finally:
		shutil.rmtree(fresh, ignore_errors=True)


def push_preview(folder, share):
	"""The commit holding a finished preview's files, or "" if the push failed."""
	branch = "preview-results/" + share.replace("@", "-")
	pushed = subprocess.run(["scripts/push-folder.sh", folder, branch, f"preview {share}"], capture_output=True, text=True)
	if pushed.returncode != 0:
		say(f"could not push preview {share}: {pushed.stderr.strip()[-200:]}")
		return ""
	return pushed.stdout.strip()


def last_line(path):
	try:
		with open(path, "rb") as file:
			file.seek(0, os.SEEK_END)
			file.seek(max(0, file.tell() - 2000))
			lines = file.read().decode("utf-8", "replace").splitlines()
	except OSError:
		return ""
	return next((line.strip() for line in reversed(lines) if line.strip()), "")[:200]


WORKER_TOKEN = ""  # a cloud worker's minted token, taken from the environment by main()


def identity_token():
	# A worker that is not a GitHub machine (scripts/cloud-worker.sh) shows its
	# minted token; taken out of the environment so builds never see it.
	if WORKER_TOKEN:
		return "worker:" + WORKER_TOKEN
	url = os.environ.get("ACTIONS_ID_TOKEN_REQUEST_URL")
	bearer = os.environ.get("ACTIONS_ID_TOKEN_REQUEST_TOKEN")
	if not url or not bearer:
		return os.environ.get("AGENT_TEST_TOKEN", "")
	request = urllib.request.Request(f"{url}&audience={AUDIENCE}", headers={"Authorization": f"bearer {bearer}"})
	with urllib.request.urlopen(request, timeout=20) as response:
		return json.load(response)["value"]


class Agent:
	def __init__(self, url, layout, index, count, idle_minutes, max_minutes):
		self.url, self.layout, self.index, self.count = url, layout, int(index), int(count)
		self.published = url == "published"
		self.machine = self.index if self.count == 0 else None
		self.idle_seconds = int(idle_minutes) * 60
		self.stop_at = time.monotonic() + int(max_minutes) * 60
		self.idle_until = time.monotonic() + self.idle_seconds
		self.built = {}  # task id -> results folder
		self.by_branch = {}  # task id -> whether its objects went to a branch
		self.git_lock = threading.Lock()
		self.handling = set()  # task ids with a handle() still running
		self.claims = {}  # claim number -> future for the job the coordinator gives it
		self.claim_number = 0
		self.timings = {}  # (task id, model) -> seconds per stage, reported when the model is done
		self.bakes_ready = {}  # (task id, model) -> future for the commits of every machine's bakes
		self.bakes_seen = {}  # (task id, model) -> the commits announced so far
		self.activities = {}  # task id -> what this machine is doing for it (heartbeat() reports them)
		self.stopped = False
		self.failures = 0  # connections in a row that failed or dropped (ALERT TUNNEL_DOWN)
		self.address = url  # the coordinator address last dialled
		self.uploader = None
		self.socket = None
		self.loop = None
		self.inbox = os.path.join(os.getcwd(), "upload-inbox")

	def run_task(self, identity, text):
		out = os.path.join("results", identity)
		os.makedirs(out, exist_ok=True)
		with open(os.path.join(out, "task.txt"), "w") as file:
			file.write(text)
		ref = next((line[4:] for line in text.splitlines() if line.startswith("ref=")), "")
		log = open(os.path.join(out, "build.log"), "w")
		ok = subprocess.run(["git", "fetch", "-q", "--depth=1", "origin", ref], stdout=log, stderr=log).returncode == 0
		ok = ok and subprocess.run(["git", "checkout", "-q", "-f", "FETCH_HEAD"], stdout=log, stderr=log).returncode == 0
		log.close()
		if ok:
			result = subprocess.run(["scripts/standby-task.sh", self.layout, str(self.index), str(self.count), out],
				capture_output=True, text=True)
			say(f"task {identity}: {result.stdout.strip()}")
		else:
			with open(os.path.join(out, "summary.txt"), "w") as file:
				file.write("status=FAILED\nbuild=-\nupload=-\ntotal=0\nparts=0\n")
			say(f"task {identity}: could not check out {ref}")
		return out

	async def send(self, message):
		"""Sends on whichever connection is live now. session() replaces
		self.socket on every reconnect, so a connection that drops during a
		long render costs a wait, not the result."""
		while True:
			try:
				await self.socket.send(message)
				return
			except websockets.ConnectionClosed:
				await asyncio.sleep(1)

	def begin(self, identity, stage, log, model=""):
		self.activities[identity] = {"stage": stage, "model": model, "log": log, "since": time.monotonic()}

	def moved(self, identity):
		"""A send made progress: the stage is not quiet, whatever its log says."""
		work = self.activities.get(identity)
		if work:
			work["moved"] = time.monotonic()

	def report(self, identity, work):
		"""One heartbeat: the stage, the log's last line, how long the log
		has gone without a new one (a bake's line comes only when it ends),
		and the machine's free disk and memory."""
		now = time.monotonic()
		seconds = now - work["since"]
		quiet = min(seconds, now - work.get("moved", work["since"]))
		try:
			quiet = min(quiet, time.time() - os.path.getmtime(work["log"]))
		except OSError:
			pass
		disk, memory = free_space()
		return json.dumps({"type": "progress", "task": identity, "stage": work["stage"], "model": work["model"],
			"line": last_line(work["log"]), "quiet": round(quiet), "seconds": round(seconds),
			"disk_gb": disk, "memory_gb": memory})

	async def heartbeat(self, socket):
		try:
			while True:
				await asyncio.sleep(HEARTBEAT_SECONDS)
				for identity, work in list(self.activities.items()):
					await socket.send(self.report(identity, work))
		except websockets.ConnectionClosed:
			pass  # session() ends too; the next connection starts its own

	async def send_results(self, identity, out):
		files = []
		for directory, _, names in os.walk(out):
			for name in names:
				path = os.path.join(directory, name)
				relative = os.path.relpath(path, out)
				# In branch mode the objects went to GitHub; only results come back.
				# Previews go on their own afterwards (send_previews).
				if relative == "task.txt" or relative.startswith("previews-run") or (self.by_branch.get(identity) and relative.endswith(".glb")):
					continue
				files.append(relative)
		# Names before objects, so the coordinator knows each object's label.
		files.sort(key=lambda path: (not path.endswith("names.tsv"), path))
		self.begin(identity, "send", os.path.join(out, "build.log"))
		for relative in files:
			with open(os.path.join(out, relative), "rb") as file:
				data = file.read()
			await self.send_file(identity, relative, data)
		summary = open(os.path.join(out, "summary.txt")).read() if os.path.isfile(os.path.join(out, "summary.txt")) else "status=FAILED\n"
		await self.send(json.dumps({"type": "done", "task": identity, "summary": summary}))

	async def send_file(self, identity, relative, data):
		"""One result file. A big one goes in parts, each awaited, so a
		heartbeat waits behind one part, never the whole file; the
		coordinator joins them (Coordinator.join_part). If the connection
		changes midway, the file starts again on the new one."""
		if len(data) <= PART_BYTES:
			await self.send(wire.pack({"type": "file", "task": identity, "path": relative, "size": len(data)}, data))
			self.moved(identity)
			return
		while True:
			socket = self.socket
			for offset in range(0, len(data), PART_BYTES):
				await self.send(wire.pack({"type": "file-part", "task": identity, "path": relative, "offset": offset,
					"size": len(data)}, data[offset:offset + PART_BYTES]))
				self.moved(identity)
				if self.socket is not socket:
					break
			else:
				return

	async def handle(self, identity, text):
		self.idle_until = time.monotonic() + self.idle_seconds
		self.by_branch[identity] = "hand-over=branch" in text
		# The coordinator posts a machine's unfinished tasks again when it
		# reconnects. The run already going answers on the new connection.
		if identity in self.handling:
			return
		self.handling.add(identity)
		try:
			if identity not in self.built:
				self.begin(identity, "build", os.path.join("results", identity, "build.log"))
				try:
					self.built[identity] = await asyncio.to_thread(self.run_task, identity, text)
				except Exception as error:
					# A full disk, say: the coordinator must still hear this shard is over.
					say(f"task {identity}: could not run: {error}")
					await self.send(json.dumps({"type": "done", "task": identity, "summary": "status=FAILED\nbuild=-\nupload=-\ntotal=0\nparts=0\n"}))
					return
			await self.send_results(identity, self.built[identity])
			self.idle_until = time.monotonic() + self.idle_seconds
			await self.send_previews(identity, text)
		finally:
			self.activities.pop(identity, None)
			self.handling.discard(identity)
		await self.send(json.dumps({"type": "progress", "task": identity, "stage": "done", "model": "", "line": "", "quiet": 0, "seconds": 0}))

	async def send_previews(self, identity, text):
		"""Renders this shard's share of the task's previews once its build
		result has gone (scripts/standby-previews.sh), sends them, then says
		so, even with nothing to render, so the coordinator can count shards."""
		names = next((line[8:] for line in text.splitlines() if line.startswith("preview=")), "")
		if not names:
			return
		out = os.path.join(self.built[identity], "previews-run")
		# This shard's share: every count-th name from its index. Each model
		# goes the moment it is rendered, so the first preview comes in seconds.
		share = [name for n, name in enumerate(names.split(",")) if n % self.count == self.index - 1]
		for model in share:
			folder = os.path.join(out, "previews", model)
			if not os.path.isdir(folder):
				env, server = dict(os.environ), None
				log = os.path.join(folder, "build.log")
				if "@" in model and int(model.rsplit("@", 1)[1]) > 1:
					os.makedirs(out, exist_ok=True)
					self.timings.setdefault((identity, model.split("@")[0]), {})["bake_start"] = time.monotonic()
					# A second back, for a file saved in the second this began.
					server = await self.claim_server(identity, model, out, time.time() - 1)
					env["WORK_PORT"] = str(server.sockets[0].getsockname()[1])
					self.begin(identity, "bake", log, model)
				else:
					self.begin(identity, "render", log, model)
				await asyncio.to_thread(subprocess.run, ["scripts/standby-previews.sh", model, "1", "1", out], capture_output=True, env=env)
				if server:
					server.close()
				self.timings.setdefault((identity, model.split("@")[0]), {})["render_end"] = time.monotonic()
			trim_log(os.path.join(folder, "build.log"))
			pushed = await asyncio.to_thread(push_preview, folder, model) if os.path.isdir(folder) else ""
			if pushed:
				await self.send(json.dumps({"type": "preview-pushed", "task": identity, "name": model, "commit": pushed}))
			else:
				# GitHub turned the push away: the tunnel is slower, but it works.
				for name in sorted(os.listdir(folder)) if os.path.isdir(folder) else []:
					with open(os.path.join(folder, name), "rb") as file:
						data = file.read()
					await self.send_file(identity, os.path.join("previews", model, name), data)
				await self.send(json.dumps({"type": "preview-ready", "task": identity, "name": model}))
			self.report_timing(identity, model)
		await self.send(json.dumps({"type": "previews-done", "task": identity}))
		self.idle_until = time.monotonic() + self.idle_seconds

	def report_timing(self, identity, share):
		timing = self.timings.pop((identity, share.split("@")[0]), None)
		if not timing or "bake_start" not in timing:
			return
		gap = lambda start, end: f"{timing[end] - timing[start]:.1f}" if start in timing and end in timing else "-"
		say(f"timing {share} script={gap('bake_start', 'first_bake')} chunks={gap('first_bake', 'last_bake')} "
			f"claims={timing.get('bake_claims', 0)} claim_wait={timing.get('bake_claim_wait', 0):.1f} "
			f"push={gap('bake_end', 'pushed')} wait={gap('pushed', 'ready')} fetch={gap('ready', 'fetched')} "
			f"render={gap('fetched', 'render_end')} send={time.monotonic() - timing.get('render_end', time.monotonic()):.1f}")

	async def claim(self, identity, model, kind, total):
		"""The next job of this kind for this machine, -1 when none are left.
		A retry repeats the number, so a lost answer can't lose a job."""
		self.claim_number += 1
		number = self.claim_number
		timing = self.timings.setdefault((identity, model), {})
		asked = time.monotonic()
		timing.setdefault(f"first_{kind}", asked)
		message = json.dumps({"type": "claim", "task": identity, "name": model, "kind": kind, "total": total, "id": number})
		for _ in range(CLAIM_TRIES):
			self.claims[number] = asyncio.get_running_loop().create_future()
			await self.send(message)
			try:
				job = await asyncio.wait_for(self.claims[number], CLAIM_WAIT_SECONDS)
				now = time.monotonic()
				timing[f"last_{kind}"] = now
				timing[f"{kind}_claims"] = timing.get(f"{kind}_claims", 0) + 1
				timing[f"{kind}_claim_wait"] = timing.get(f"{kind}_claim_wait", 0) + now - asked
				return job
			except asyncio.TimeoutError:
				continue
			finally:
				self.claims.pop(number, None)
		return -1

	async def claim_server(self, identity, share, out, since):
		"""A local port where this machine's engine asks for its next job, and
		says when its baking is done."""
		model = share.split("@")[0]

		async def serve(reader, writer):
			while line := await reader.readline():
				kind, total = line.decode().split()
				if kind == "swap":
					await self.share_bakes(identity, share, out, since)
					answer = 0
				else:
					answer = await self.claim(identity, model, kind, int(total))
				writer.write(f"{answer}\n".encode())
				await writer.drain()
			writer.close()

		return await asyncio.start_server(serve, "127.0.0.1", 0)

	async def share_bakes(self, identity, share, out, since):
		"""Asked by the engine once it has baked what it claimed: pushes those
		layers and takes every other machine's, so no two machines bake the
		same texture. Anything that doesn't arrive, the engine bakes itself."""
		model = share.split("@")[0]
		log = os.path.join(out, "previews", share, "build.log")
		timing = self.timings.setdefault((identity, model), {})
		timing["bake_end"] = time.monotonic()
		self.begin(identity, "swap", log, share)
		ready = self.bakes_ready[(identity, model)] = asyncio.get_running_loop().create_future()
		mine = await asyncio.to_thread(push_bakes, model, share, out, since)
		timing["pushed"] = time.monotonic()
		await self.send(json.dumps({"type": "bakes-pushed", "task": identity, "share": share, "commit": mine}))
		try:
			commits = await asyncio.wait_for(ready, max(SWAP_WAIT_SECONDS, (timing["bake_end"] - timing["bake_start"]) * 4))
		except asyncio.TimeoutError:
			commits = self.bakes_seen.get((identity, model), [])
			say(f"task {identity}: could not get every machine's bakes of {model} in time; taking the {len(commits)} that arrived, the render bakes the rest")
		finally:
			self.bakes_ready.pop((identity, model), None)
			self.bakes_seen.pop((identity, model), None)
		timing["ready"] = time.monotonic()
		cache = os.path.join("art", "models", model, ".cache")
		fetched = await asyncio.gather(*[asyncio.to_thread(self.fetch_objects, commit, cache) for commit in commits if commit != mine], return_exceptions=True)
		timing["fetched"] = time.monotonic()
		for error in [result for result in fetched if isinstance(result, Exception)]:
			say(f"task {identity}: could not fetch bakes of {model}: {error}")
		self.begin(identity, "render", log, share)

	def answer(self, identity, asset, error):
		"""From the uploader's threads: send the result on the live socket."""
		say(f"upload {identity}: " + (f"asset {asset}" if asset else f"FAILED {error}"))
		message = json.dumps({"type": "uploaded", "id": identity, "asset": asset, "error": error,
			"width": round(self.uploader.throttle.limit, 1), "known": round(self.uploader.throttle.known, 1)})
		socket, loop = self.socket, self.loop
		if socket and loop:
			loop.call_soon_threadsafe(lambda: asyncio.ensure_future(socket.send(message)))

	def fetch_objects(self, commit, into):
		"""Machine 1 takes a builder's objects, and every machine the others'
		bakes, each from a GitHub commit."""
		commits.fetch_into(os.getcwd(), os.path.join(os.getcwd(), ".objects-store"), commit, into)

	async def receive_fetch(self, socket, event):
		"""Machine 1: a builder pushed objects; fetch them and upload the ones asked for."""
		if self.uploader is None:
			self.uploader = uploading.Uploader(ROOT, self.layout, say,
				dry=os.environ.get("AGENT_DRY_UPLOAD") == "1", on_done=self.answer)
			if getattr(self, "start_width", None):
				# A run starts at least START wide, its known limit forgotten:
				# what turned uploads away last time may not hold now.
				self.uploader.throttle.limit = max(uploading.START, min(uploading.MOST, float(self.start_width)))
		into = os.path.join(self.inbox, f"{event['task']}-S{event['shard']}")
		started = time.monotonic()
		try:
			await asyncio.to_thread(self.fetch_objects, event["commit"], into)
		except Exception as error:
			say(f"S{event['shard']}'s objects: {error}")
			for identity in event["ids"]:
				await socket.send(json.dumps({"type": "uploaded", "id": identity, "error": str(error)}))
			return
		say(f"fetched S{event['shard']}'s {len(event['ids'])} objects in {time.monotonic() - started:.1f}s")
		for identity, label in event["ids"].items():
			path = os.path.join(into, f"{identity}.glb")
			if not self.uploader.add(identity, path, label, event["shard"]):
				asset = self.uploader.asset_of(identity)
				if asset:
					await socket.send(json.dumps({"type": "uploaded", "id": identity, "asset": asset}))

	async def receive_upload(self, socket, header, data):
		say(f"upload {header['label']} ({header['id']}, {len(data) // 1000} KB) received")
		if self.uploader is None:
			# AGENT_DRY_UPLOAD fakes uploads, for local tests only.
			self.uploader = uploading.Uploader(ROOT, header.get("layout", self.layout), say,
				dry=os.environ.get("AGENT_DRY_UPLOAD") == "1", on_done=self.answer)
			if getattr(self, "start_width", None):
				# A run starts at least START wide, its known limit forgotten:
				# what turned uploads away last time may not hold now.
				self.uploader.throttle.limit = max(uploading.START, min(uploading.MOST, float(self.start_width)))
		os.makedirs(self.inbox, exist_ok=True)
		path = os.path.join(self.inbox, f"{header['id']}.glb")
		with open(path, "wb") as file:
			file.write(data)
		if not self.uploader.add(header["id"], path, header["label"], header.get("shard", 1)):
			# Already uploaded by this machine (or still going: its answer follows).
			asset = self.uploader.asset_of(header["id"])
			if asset:
				await socket.send(json.dumps({"type": "uploaded", "id": header["id"], "asset": asset}))

	def published_address(self):
		# Not through FETCH_HEAD: a task's checkout may be reading it.
		with self.git_lock:
			subprocess.run(["git", "fetch", "-q", "--depth=1", "--no-write-fetch-head", "origin",
				f"+{ADDRESS_BRANCH}:refs/coordinator-address"], check=True, capture_output=True, timeout=60)
			shown = subprocess.run(["git", "show", "refs/coordinator-address:address.json"], check=True, capture_output=True, text=True)
		return json.loads(shown.stdout)["agent"]

	async def session(self):
		token = await asyncio.to_thread(identity_token)
		url = await asyncio.to_thread(self.published_address) if self.published else self.url
		self.address = url
		async with websockets.connect(url, max_size=MAX_MESSAGE, ping_interval=20, ping_timeout=120) as socket:
			hello = {"type": "hello", "token": token, "shard": self.index, "count": self.count, "layout": self.layout}
			if self.machine is not None:
				hello["machine"] = self.machine
			await socket.send(json.dumps(hello))
			say(f"connected to {url}")
			self.backoff = 1
			self.socket, self.loop = socket, asyncio.get_running_loop()
			global forward
			loop = self.loop

			def forward_line(text):
				# say() may run on an uploader thread.
				loop.call_soon_threadsafe(lambda: asyncio.ensure_future(socket.send(json.dumps({"type": "log", "text": text}))))

			forward = forward_line
			if self.failures >= TUNNEL_ALERT_FAILURES:
				alert(f"CLEARED TUNNEL_DOWN: S{self.index} connected to {url} after {self.failures} failures")
			self.failures = 0
			lacking = [tool for tool in REQUIRED_TOOLS if not shutil.which(tool)]
			if lacking:
				say(f"could not find {', '.join(lacking)} on this machine")
			beat = asyncio.create_task(self.heartbeat(socket))
			try:
				async for message in socket:
					if isinstance(message, bytes):
						header, data = wire.unpack(message)
						try:
							await self.receive_upload(socket, header, data)
						except Exception as error:
							say(f"upload {header.get('id')}: could not start: {error}")
							await socket.send(json.dumps({"type": "uploaded", "id": header.get("id"), "error": str(error)}))
						continue
					event = json.loads(message)
					if event["type"] == "uploader":
						self.start_width, self.start_known = event.get("width"), event.get("known")
						say(f"this machine uploads for the coordinator, starting {self.start_width or 'fresh'} at once")
					elif event["type"] == "fetch-objects":
						asyncio.create_task(self.receive_fetch(socket, event))
					elif event["type"] == "task":
						asyncio.create_task(self.handle(event["id"], event["task"]))
					elif event["type"] == "claimed":
						claim = self.claims.get(event["id"])
						if claim and not claim.done():
							claim.set_result(event["job"])
					elif event["type"] == "bakes-ready":
						self.bakes_seen[(event["task"], event["name"])] = event["commits"]
						ready = self.bakes_ready.get((event["task"], event["name"]))
						if ready and not ready.done() and event.get("done", True):
							ready.set_result(event["commits"])
					elif event["type"] == "welcome":
						self.index, self.count = event["shard"], event["count"]
						say(f"seated as shard {self.index} of {self.count}")
					elif event["type"] == "active":
						# The coordinator on this machine has work going for others.
						self.idle_until = time.monotonic() + self.idle_seconds
					elif event["type"] == "stop":
						self.stopped = True
						return
			finally:
				beat.cancel()

	async def watch_clock(self):
		while not self.stopped:
			now = time.monotonic()
			if now >= self.idle_until or now >= self.stop_at:
				self.stopped = True
				return
			await asyncio.sleep(min(self.idle_until, self.stop_at) - now)

	async def main(self):
		global forward, WORKER_TOKEN
		# Out of the environment before any child process can see it.
		WORKER_TOKEN = os.environ.pop("COORDINATOR_WORKER_TOKEN", "")
		# The coordinator's own; no build on this machine needs it.
		os.environ.pop("COORDINATOR_WORKER_KEY", None)
		await asyncio.to_thread(ensure_tools)
		self.backoff = 1
		clock = asyncio.create_task(self.watch_clock())
		lost_since = None
		while not self.stopped:
			connection = asyncio.create_task(self.session())
			done, _ = await asyncio.wait({connection, clock}, return_when=asyncio.FIRST_COMPLETED)
			if clock in done:
				connection.cancel()
				break
			error = connection.exception()
			if self.stopped:
				break
			forward = None
			if self.backoff == 1:
				lost_since = time.monotonic()
			elif lost_since and not self.published and time.monotonic() - lost_since > LOST_MINUTES * 60:
				say(f"no coordinator for {LOST_MINUTES} minutes; ending to free this machine's slot")
				break
			self.failures += 1
			status = http_status(error)
			answered = f"HTTP {status}" if status else "no HTTP answer"
			say(f"connection lost ({error}; {answered}); retrying in {self.backoff}s")
			if self.failures == TUNNEL_ALERT_FAILURES:
				alert(f"ALERT TUNNEL_DOWN: S{self.index} failed to reach {self.address} {self.failures} times in a row ({answered}: {error}) "
					"| machine 1's tunnel or coordinator is down; if it stays down, start a new run (scripts/standby-start.sh)")
			await asyncio.sleep(self.backoff)
			# A numbered machine waits for the next coordinator, a minute apart.
			self.backoff = min(60 if self.published else 30, self.backoff * 2)
		say("standby over")


if __name__ == "__main__":
	if len(sys.argv) != 7:
		sys.exit(__doc__)
	asyncio.run(Agent(*sys.argv[1:]).main())
