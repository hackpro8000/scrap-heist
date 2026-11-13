"""The Agent: its state, the connection to the coordinator (hello, reading
events), the idle/max clock, and the reconnect loop; the rest is in its mixins."""
import asyncio
import json
import os
import shutil
import subprocess
import threading
import time

import websockets

from standby_agent import common, machine
from standby_agent.common import ADDRESS_BRANCH, LOST_MINUTES, MAX_MESSAGE, REQUIRED_TOOLS, TUNNEL_ALERT_FAILURES, alert, say
from standby_agent.machine import ensure_tools, http_status, identity_token
from standby_agent.previews import Previews
from standby_agent.sending import Sending
from standby_agent.units import Units
from standby_agent.uploads import Uploads
import wire  # noqa: E402


class Agent(Units, Sending, Previews, Uploads):
	def __init__(self, url, layout, index, count, idle_minutes, max_minutes):
		self.url, self.layout, self.index, self.count = url, layout, int(index), int(count)
		self.published = url == "published"
		self.machine = self.index if self.count == 0 else None
		self.idle_seconds = int(idle_minutes) * 60
		self.stop_at = time.monotonic() + int(max_minutes) * 60
		self.idle_until = time.monotonic() + self.idle_seconds
		# A unit is (task id, shard); a machine may do several units of one task.
		self.built = {}  # unit -> results folder
		self.by_branch = {}  # task id -> whether its objects went to a branch
		self.git_lock = threading.Lock()
		self.handling = set()  # units with a handle() still running
		self.cancelling = {}  # unit -> its cancel() while it runs (stop_unit)
		# unit -> {"cancelled": bool, "processes": set of Popen, "task": its asyncio task}
		self.units = {}
		self.claims = {}  # claim number -> future for the job the coordinator gives it
		self.claim_number = 0
		self.timings = {}  # (task id, model) -> seconds per stage, reported when the model is done
		self.bakes_ready = {}  # (task id, model) -> future for the commits of every machine's bakes
		self.bakes_seen = {}  # (task id, model) -> the commits announced so far
		self.activities = {}  # unit -> what this machine is doing for it (heartbeat() reports them)
		self.stopped = False
		self.failures = 0  # connections in a row that failed or dropped (ALERT TUNNEL_DOWN)
		self.address = url  # the coordinator address last dialled
		self.uploader = None
		self.socket = None
		self.loop = None
		self.inbox = os.path.join(os.getcwd(), "upload-inbox")

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
			# The units still under way, so a restarted coordinator gives them back; not one being cancelled.
			hello = {"type": "hello", "token": token, "shard": self.index, "count": self.count, "layout": self.layout,
				"units": [list(unit) for unit in self.handling if unit not in self.cancelling]}
			if self.machine is not None:
				hello["machine"] = self.machine
			await socket.send(json.dumps(hello))
			say(f"connected to {url}")
			self.backoff = 1
			self.socket, self.loop = socket, asyncio.get_running_loop()
			loop = self.loop

			def forward_line(text):
				# say() may run on an uploader thread.
				loop.call_soon_threadsafe(lambda: asyncio.ensure_future(socket.send(json.dumps({"type": "log", "text": text}))))

			common.forward = forward_line
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
						self.take(event)
					elif event["type"] == "cancel":
						self.stop_unit(event)
					elif event["type"] == "claimed":
						claim = self.claims.get(event["id"])
						if claim and not claim.done():
							claim.set_result(event["job"])
					elif event["type"] == "bakes-ready":
						self.bakes_seen[(event["task"], event["name"])] = event["commits"]
						ready = self.bakes_ready.get((event["task"], event["name"]))
						if ready and not ready.done() and event.get("done", True):
							ready.set_result(event["commits"])
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
		# Out of the environment before any child process can see it.
		machine.WORKER_TOKEN = os.environ.pop("COORDINATOR_WORKER_TOKEN", "")
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
			common.forward = None
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
