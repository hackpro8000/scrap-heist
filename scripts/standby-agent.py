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
"""
import asyncio
import json
import os
import subprocess
import sys
import time
import urllib.request

import websockets

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "coordinator"))
import uploader as uploading  # noqa: E402
import wire  # noqa: E402

MAX_MESSAGE = 64 * 1024 * 1024
LOST_MINUTES = 3
AUDIENCE = "scrap-heist-coordinator"


# Lines also go to the coordinator, live, once connected (Agent.session).
forward = None


def say(message):
	print(f"agent: {message}", file=sys.stderr, flush=True)
	if forward:
		forward(message)


def identity_token():
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
		self.idle_seconds = int(idle_minutes) * 60
		self.stop_at = time.monotonic() + int(max_minutes) * 60
		self.idle_until = time.monotonic() + self.idle_seconds
		self.built = {}  # task id -> results folder
		self.by_branch = {}  # task id -> whether its objects went to a branch
		self.building = set()
		self.stopped = False
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

	async def send_results(self, socket, identity, out):
		files = []
		for directory, _, names in os.walk(out):
			for name in names:
				path = os.path.join(directory, name)
				relative = os.path.relpath(path, out)
				# In branch mode the objects went to GitHub; only results come back.
				if relative == "task.txt" or (self.by_branch.get(identity) and relative.endswith(".glb")):
					continue
				files.append(relative)
		# Names before objects, so the coordinator knows each object's label.
		files.sort(key=lambda path: (not path.endswith("names.tsv"), path))
		for relative in files:
			with open(os.path.join(out, relative), "rb") as file:
				data = file.read()
			await socket.send(wire.pack({"type": "file", "task": identity, "path": relative, "size": len(data)}, data))
		summary = open(os.path.join(out, "summary.txt")).read() if os.path.isfile(os.path.join(out, "summary.txt")) else "status=FAILED\n"
		await socket.send(json.dumps({"type": "done", "task": identity, "summary": summary}))

	async def handle(self, socket, identity, text):
		self.idle_until = time.monotonic() + self.idle_seconds
		self.by_branch[identity] = "hand-over=branch" in text
		if identity in self.building:
			return
		if identity not in self.built:
			self.building.add(identity)
			try:
				self.built[identity] = await asyncio.to_thread(self.run_task, identity, text)
			finally:
				self.building.discard(identity)
		await self.send_results(socket, identity, self.built[identity])
		self.idle_until = time.monotonic() + self.idle_seconds

	def answer(self, identity, asset, error):
		"""From the uploader's threads: send the result on the live socket."""
		say(f"upload {identity}: " + (f"asset {asset}" if asset else f"FAILED {error}"))
		message = json.dumps({"type": "uploaded", "id": identity, "asset": asset, "error": error,
			"width": round(self.uploader.throttle.limit, 1), "known": round(self.uploader.throttle.known, 1)})
		socket, loop = self.socket, self.loop
		if socket and loop:
			loop.call_soon_threadsafe(lambda: asyncio.ensure_future(socket.send(message)))

	def fetch_objects(self, commit, into):
		"""Machine 1: takes a builder's objects from its GitHub branch commit."""
		os.makedirs(into, exist_ok=True)
		# The checkout this machine works in (the folder it was started from).
		fetched = subprocess.run(["git", "fetch", "-q", "--depth=1", "origin", commit], capture_output=True, text=True)
		if fetched.returncode != 0:
			raise RuntimeError(f"fetch of {commit[:8]} failed: {fetched.stderr.strip()[-200:]}")
		archive = subprocess.Popen(["git", "archive", commit], stdout=subprocess.PIPE)
		subprocess.run(["tar", "-x", "-C", into], stdin=archive.stdout, check=True)
		archive.wait()

	async def receive_fetch(self, socket, event):
		"""Machine 1: a builder pushed objects; fetch them and upload the ones asked for."""
		if self.uploader is None:
			self.uploader = uploading.Uploader(ROOT, self.layout, say,
				dry=os.environ.get("AGENT_DRY_UPLOAD") == "1", on_done=self.answer)
			if getattr(self, "start_width", None):
				self.uploader.throttle.limit = max(1.0, min(uploading.MOST, float(self.start_width)))
			if getattr(self, "start_known", None):
				self.uploader.throttle.known = max(1.0, min(uploading.MOST, float(self.start_known)))
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
				self.uploader.throttle.limit = max(1.0, min(uploading.MOST, float(self.start_width)))
			if getattr(self, "start_known", None):
				self.uploader.throttle.known = max(1.0, min(uploading.MOST, float(self.start_known)))
		os.makedirs(self.inbox, exist_ok=True)
		path = os.path.join(self.inbox, f"{header['id']}.glb")
		with open(path, "wb") as file:
			file.write(data)
		if not self.uploader.add(header["id"], path, header["label"], header.get("shard", 1)):
			# Already uploaded by this machine (or still going: its answer follows).
			asset = self.uploader.asset_of(header["id"])
			if asset:
				await socket.send(json.dumps({"type": "uploaded", "id": header["id"], "asset": asset}))

	async def session(self):
		token = await asyncio.to_thread(identity_token)
		async with websockets.connect(self.url, max_size=MAX_MESSAGE, ping_interval=20, ping_timeout=60) as socket:
			await socket.send(json.dumps({"type": "hello", "token": token, "shard": self.index, "count": self.count,
				"layout": self.layout}))
			say(f"connected to {self.url}")
			self.backoff = 1
			self.socket, self.loop = socket, asyncio.get_running_loop()
			global forward
			loop = self.loop

			def forward_line(text):
				# say() may run on an uploader thread.
				loop.call_soon_threadsafe(lambda: asyncio.ensure_future(socket.send(json.dumps({"type": "log", "text": text}))))

			forward = forward_line
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
					asyncio.create_task(self.handle(socket, event["id"], event["task"]))
				elif event["type"] == "stop":
					self.stopped = True
					return

	async def watch_clock(self):
		while not self.stopped:
			now = time.monotonic()
			if now >= self.idle_until or now >= self.stop_at:
				self.stopped = True
				return
			await asyncio.sleep(min(self.idle_until, self.stop_at) - now)

	async def main(self):
		global forward
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
			elif lost_since and time.monotonic() - lost_since > LOST_MINUTES * 60:
				say(f"no coordinator for {LOST_MINUTES} minutes; ending to free this machine's slot")
				break
			say(f"connection lost ({error}); retrying in {self.backoff}s")
			await asyncio.sleep(self.backoff)
			self.backoff = min(30, self.backoff * 2)
		say("standby over")


if __name__ == "__main__":
	if len(sys.argv) != 7:
		sys.exit(__doc__)
	asyncio.run(Agent(*sys.argv[1:]).main())
