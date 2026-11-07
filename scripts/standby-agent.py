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

A dropped connection is retried with backoff (1 s doubling to 30 s). A task
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

MAX_MESSAGE = 64 * 1024 * 1024
AUDIENCE = "scrap-heist-coordinator"


def say(message):
	print(f"agent: {message}", file=sys.stderr, flush=True)


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
		self.building = set()
		self.stopped = False

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
				if relative != "task.txt":
					files.append(relative)
		# Names before objects, so the coordinator knows each object's label.
		files.sort(key=lambda path: (not path.endswith("names.tsv"), path))
		for relative in files:
			with open(os.path.join(out, relative), "rb") as file:
				data = file.read()
			await socket.send(json.dumps({"type": "file", "task": identity, "path": relative, "size": len(data)}))
			await socket.send(data)
		summary = open(os.path.join(out, "summary.txt")).read() if os.path.isfile(os.path.join(out, "summary.txt")) else "status=FAILED\n"
		await socket.send(json.dumps({"type": "done", "task": identity, "summary": summary}))

	async def handle(self, socket, identity, text):
		self.idle_until = time.monotonic() + self.idle_seconds
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

	async def session(self):
		token = await asyncio.to_thread(identity_token)
		async with websockets.connect(self.url, max_size=MAX_MESSAGE, ping_interval=20, ping_timeout=60) as socket:
			await socket.send(json.dumps({"type": "hello", "token": token, "shard": self.index, "count": self.count,
				"layout": self.layout}))
			say(f"connected to {self.url}")
			self.backoff = 1
			async for message in socket:
				event = json.loads(message)
				if event["type"] == "task":
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
		self.backoff = 1
		clock = asyncio.create_task(self.watch_clock())
		while not self.stopped:
			connection = asyncio.create_task(self.session())
			done, _ = await asyncio.wait({connection, clock}, return_when=asyncio.FIRST_COMPLETED)
			if clock in done:
				connection.cancel()
				break
			error = connection.exception()
			if self.stopped:
				break
			say(f"connection lost ({error}); retrying in {self.backoff}s")
			await asyncio.sleep(self.backoff)
			self.backoff = min(30, self.backoff * 2)
		say("standby over")


if __name__ == "__main__":
	if len(sys.argv) != 7:
		sys.exit(__doc__)
	asyncio.run(Agent(*sys.argv[1:]).main())
