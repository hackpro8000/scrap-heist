#!/usr/bin/env python3
"""Proves the hub's pull queue (coordinator.py) with fake machines: the real
Coordinator runs in this process on localhost ports, and fake agents talk
to it over real websockets, sending what scripts/standby-agent.py sends.
Nothing is built: a fake "builds" by sleeping a few tenths of a second,
writing its log as it goes; its heartbeats come from the real agent's
report(), and its cancel takes time and makes a task for the same unit
wait for it, as the real agent's does. Lease timeouts are shortened
through the constructor.

  python3 tools/coordinator/test_queue.py [-v]

One PASS or FAIL line per case; exits 0 only when every case passes.
"""
import asyncio
import collections
import importlib.util
import json
import os
import shutil
import sys
import tempfile
import time
import traceback

import websockets

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import client  # noqa: E402
import coordinator as hub  # noqa: E402
import wire  # noqa: E402

# The real agent (scripts/standby-agent.py), for its heartbeat and its take/cancel.
_spec = importlib.util.spec_from_file_location("standby_agent",
	os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scripts", "standby-agent.py"))
AGENT = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(AGENT)

KEY = "test-worker-key"
TIMEOUTS = {"grace": 1.0, "silent": 1.5, "wedged": 4.0}
BEAT = 0.2  # a fake's heartbeat
CANCEL_SECONDS = 0.3  # how long a fake takes to kill a unit
CASE_SECONDS = 20

if "-v" not in sys.argv:
	# Every hub module binds its own say (from hub_config import say).
	for module in list(sys.modules.values()):
		if module is hub or getattr(module, "__name__", "").startswith("hub_"):
			if hasattr(module, "say"):
				module.say = lambda message: None
	AGENT.say = lambda message: None


async def until(condition, timeout=10, step=0.02):
	deadline = time.time() + timeout
	while not condition():
		if time.time() > deadline:
			raise TimeoutError("condition not met in time")
		await asyncio.sleep(step)


class Hub:
	"""The real Coordinator on two free localhost ports, writing into a temporary folder."""

	async def start(self, folder=None):
		"""In a new temporary folder, or in `folder` to take over a stopped hub's tasks file and results."""
		self.folder = folder or tempfile.mkdtemp(prefix="queue-test-")
		self.c = hub.Coordinator("ServerMap", True, test_without_identity=True, timeouts=TIMEOUTS, worker_key=KEY,
			tasks_file=os.path.join(self.folder, "tasks.json"), results=os.path.join(self.folder, "results"))
		self.c.loop = asyncio.get_running_loop()
		self.agents = await websockets.serve(self.c.agent, "127.0.0.1", 0, max_size=hub.MAX_MESSAGE)
		self.control = await websockets.serve(self.c.control, "127.0.0.1", 0, max_size=hub.MAX_CONTROL_MESSAGE)
		self.agent_url = f"ws://127.0.0.1:{self.agents.sockets[0].getsockname()[1]}"
		self.control_url = f"ws://127.0.0.1:{self.control.sockets[0].getsockname()[1]}"
		return self

	async def stop(self, fakes=(), keep=False):
		for fake in fakes:
			await fake.kill()
		if self.c.watchdog:
			self.c.watchdog.cancel()
		self.agents.close()
		self.control.close()
		# A session's open build connection can hold wait_closed; it is not what's tested.
		try:
			await asyncio.wait_for(asyncio.gather(self.agents.wait_closed(), self.control.wait_closed()), 1)
		except asyncio.TimeoutError:
			pass
		if not keep:
			shutil.rmtree(self.folder, ignore_errors=True)

	async def machines(self, names, **options):
		fakes = [Fake(self, name, **options) for name in names]
		await asyncio.gather(*(fake.connect() for fake in fakes))
		return fakes

	def task(self, identity):
		return self.c.tasks.get(identity) or self.c.finished[identity][0]


class Fake:
	"""A machine: g<n> a GitHub one, m<n> a numbered one."""

	def __init__(self, at, name, seconds=0.3, objects=False):
		self.hub, self.name, self.seconds, self.objects = at, name, seconds, objects
		self.folder = os.path.join(at.folder, "fakes", name)
		self.socket = None
		self.running = {}  # unit -> its asyncio task
		self.stopping = {}  # unit -> its cancel while it runs (standby-agent.py's cancelling)
		self.received = []  # (time, task, shard) of every unit message
		self.starts = []  # units it began work on
		self.finished = []  # units it sent done for
		self.cancels = []
		self.silent = False  # holds its unit without a word
		self.deaf = False  # ignores cancel
		# "build" writes its log; "stall" is a hung lane (only the memory probe
		# writes); "swap" waits on other machines' bakes. Only build ends.
		self.stage = "build"
		self.dead = False

	def hello(self):
		units = [list(unit) for unit in self.running if unit not in self.stopping]
		number = int(self.name[1:])
		if self.name.startswith("m"):
			return {"type": "hello", "machine": number, "token": hub.WORKER_PREFIX + wire.machine_token(KEY, number), "units": units}
		return {"type": "hello", "token": "test", "shard": number, "count": 20, "layout": "ServerMap", "units": units}

	async def connect(self):
		self.socket = await websockets.connect(self.hub.agent_url, max_size=hub.MAX_MESSAGE)
		await self.socket.send(json.dumps(self.hello()))
		self.reader = asyncio.ensure_future(self.read(self.socket))

	async def read(self, socket):
		try:
			async for message in socket:
				event = json.loads(message)
				if event["type"] == "task":
					unit = (event["id"], event["shard"])
					self.received.append((time.time(), *unit))
					self.take(unit, event)
				elif event["type"] == "cancel":
					unit = (event["task"], event["shard"])
					self.cancels.append(unit)
					if self.deaf or unit in self.stopping:
						continue
					self.stopping[unit] = asyncio.ensure_future(self.cancel(unit))
				else:
					self.heard(event)
		except websockets.ConnectionClosed:
			pass

	def heard(self, event):
		"""Any other message: claim answers and bakes-ready, for test_swap.py's Sharer."""

	def take(self, unit, event):
		if unit in self.stopping:
			asyncio.ensure_future(self.take_after(self.stopping[unit], unit, event))
			return
		if unit not in self.running:
			self.running[unit] = asyncio.ensure_future(self.work(unit, event))

	async def take_after(self, stopping, unit, event):
		await asyncio.wait({stopping})
		self.take(unit, event)

	async def cancel(self, unit):
		try:
			running = self.running.pop(unit, None)
			if running:
				running.cancel()
			await asyncio.sleep(CANCEL_SECONDS)
			await self.send(json.dumps({"type": "idle", "task": unit[0], "shard": unit[1]}))
		finally:
			self.stopping.pop(unit, None)

	async def send(self, message):
		while not self.dead:
			try:
				await self.socket.send(message)
				return
			except websockets.ConnectionClosed:
				await asyncio.sleep(0.05)

	async def send_file(self, unit, path, data):
		await self.send(wire.pack({"type": "file", "task": unit[0], "shard": unit[1], "path": path, "size": len(data)}, data))

	async def work(self, unit, event):
		shard = unit[1]
		self.starts.append(unit)
		out = os.path.join(self.folder, f"{unit[0]}-S{shard}")
		os.makedirs(out, exist_ok=True)
		log = os.path.join(out, "build.log")
		open(log, "w").close()
		activity = {"stage": "build", "model": "", "log": log, "since": time.monotonic()}
		try:
			if not self.silent:
				await self.send(json.dumps({"type": "log", "text": f"task {unit[0]} S{shard}: started"}))
			if self.objects:
				# The same objects for the same unit, whoever builds it.
				names = [f"obj{shard}a", f"obj{shard}b"]
				await self.send_file(unit, "handed/names.tsv", "".join(f"{name}\tlabel {name}\n" for name in names).encode())
				for name in names:
					await self.send_file(unit, f"handed/{name}.glb", b"glb " + name.encode())
			ends = time.time() + self.seconds
			while time.time() < ends or self.silent or self.stage != "build":
				activity["stage"] = "swap" if self.stage == "swap" else "build"
				if self.stage == "build" and not self.silent:
					with open(log, "a") as file:
						file.write("a step\n")
				elif self.stage == "stall":
					# The memory probe writes on whether the build moves or not.
					with open(os.path.join(out, "probe.log"), "a") as file:
						file.write("MEM 1/2\n")
				if not self.silent:
					# The real agent's heartbeat, its quiet measured from this log.
					await self.send(AGENT.Agent.report(None, unit, activity))
				await asyncio.sleep(min(BEAT, max(0.01, ends - time.time())))
			await self.send_file(unit, "summary.txt", f"status=DONE\nmachine={self.name}\n".encode())
			await self.send_file(unit, "parts.txt", f"part-{shard}\n".encode())
			await self.send(json.dumps({"type": "done", "task": unit[0], "shard": shard, "summary": f"status=DONE\nmachine={self.name}\n"}))
			self.finished.append(unit)
			if "preview=" in event["task"]:
				await self.send(json.dumps({"type": "previews-done", "task": unit[0], "shard": shard}))
		finally:
			if self.running.get(unit) is asyncio.current_task():
				del self.running[unit]

	async def kill(self):
		"""Gone for good, mid-unit or not."""
		self.dead = True
		for running in [*self.running.values(), *self.stopping.values()]:
			running.cancel()
		if self.socket:
			await self.socket.close()

	async def drop(self):
		"""The connection goes; the work carries on and resends once reconnected."""
		await self.socket.close()


class Watch:
	"""A session's build request: the events about its task, until finished."""

	def __init__(self, socket, posted):
		self.socket, self.posted, self.task = socket, posted, posted["task"]
		self.events = []
		self.over = asyncio.Event()
		self.reader = asyncio.ensure_future(self.read())

	async def read(self):
		try:
			async for message in self.socket:
				if isinstance(message, bytes):
					continue
				event = json.loads(message)
				if event.get("task") not in (None, self.task):
					continue
				self.events.append(event)
				if event["type"] == "finished":
					self.over.set()
		except websockets.ConnectionClosed:
			pass

	def of(self, kind):
		return [event for event in self.events if event["type"] == kind]

	async def finished(self, timeout=12):
		await asyncio.wait_for(self.over.wait(), timeout)
		return self.of("finished")[0]

	async def close(self):
		await self.socket.close()


async def post(at, **request):
	socket = await websockets.connect(at.control_url, max_size=hub.MAX_MESSAGE)
	await socket.send(json.dumps({"type": "build", "ref": "abc1234", "upload": False, "previews": [], "build": True, **request}))
	posted = json.loads(await socket.recv())
	if posted.get("type") != "posted":
		raise AssertionError(f"not posted: {posted}")
	return Watch(socket, posted)


def each_once(fakes, task, count):
	"""Every unit 1..count done exactly once across the fakes; returns a problem or None."""
	done = collections.Counter(unit[1] for fake in fakes for unit in fake.finished if unit[0] == task)
	twice = sorted(shard for shard, times in done.items() if times > 1)
	missing = sorted(set(range(1, count + 1)) - set(done))
	if twice or missing:
		return f"done twice {twice}, never {missing}"
	return None


def check(condition, problem):
	if not condition:
		raise AssertionError(problem)


# --- the cases ---

async def case_a():
	at = await Hub().start()
	fakes = await at.machines([f"g{n}" for n in range(1, 21)] + [f"m{n}" for n in range(1, 31)])
	try:
		await until(lambda: len(at.c.connected()) == 50)
		watch = await post(at)
		check(watch.posted["count"] == 50, f"posted {watch.posted['count']} units, wanted 50")
		await watch.finished()
		problem = each_once(fakes, watch.task, 50)
		check(not problem, problem)
		task = at.task(watch.task)
		check(len(task.done) == 50 and not task.queue and not task.leases, "hub bookkeeping not finished")
		return "50 units on 20 GitHub + 30 numbered machines, each done once"
	finally:
		await at.stop(fakes)


async def case_b():
	at = await Hub().start()
	fakes = await at.machines([f"g{n}" for n in range(1, 21)] + [f"m{n}" for n in range(1, 31)], seconds=0.8)
	try:
		await until(lambda: len(at.c.connected()) == 50)
		watch = await post(at)
		await until(lambda: all(fake.running for fake in fakes[:5]))
		await asyncio.sleep(0.2)
		victims = fakes[:5]
		for fake in victims:
			await fake.kill()
		finished = await watch.finished()
		redealt = watch.of("redealt")
		check(len(redealt) == 5, f"{len(redealt)} re-deals, wanted 5")
		check(all(event["from"] in {fake.name for fake in victims} and "closed" in event["reason"] for event in redealt), f"re-deals: {redealt}")
		problem = each_once(fakes, watch.task, 50)
		check(not problem, problem)
		check(finished["task"] == watch.task, "finished another task")
		return "5 killed mid-unit; " + "; ".join(f"ALERT REDEALT: S{event['shard']} from {event['from']} to {event['to']}: {event['reason']}" for event in redealt[:1]) + " ..."
	finally:
		await at.stop(fakes)


async def case_c():
	at = await Hub().start()
	fakes = await at.machines(["g1", "g2", "m1"], seconds=1.2)
	try:
		await until(lambda: len(at.c.connected()) == 3)
		watch = await post(at)
		await until(lambda: fakes[2].running)
		await asyncio.sleep(0.2)
		await fakes[2].drop()
		await until(lambda: at.c.roster["m1"].socket is None)
		await asyncio.sleep(0.4)  # inside the 1 s grace
		await fakes[2].connect()
		await watch.finished()
		check(not watch.of("redealt"), f"re-dealt: {watch.of('redealt')}")
		check(fakes[2].finished and fakes[2].finished[0][0] == watch.task, "the dropped machine did not finish its unit")
		problem = each_once(fakes, watch.task, 3)
		check(not problem, problem)
		return "m1 dropped and came back in 0.4 s; kept its lease, no re-deal"
	finally:
		await at.stop(fakes)


async def case_d():
	at = await Hub().start()
	fakes = await at.machines(["g1", "g2", "g3"], seconds=0.4)
	quiet = fakes[0]
	quiet.silent, quiet.deaf = True, True
	try:
		await until(lambda: len(at.c.connected()) == 3)
		watch = await post(at)
		await until(lambda: fakes[1].finished and fakes[2].finished)
		# The replacement still builds when the old holder's late done comes.
		for fake in fakes[1:]:
			fake.seconds = 6.0
		await until(lambda: watch.of("redealt"), timeout=5)
		redealt = watch.of("redealt")
		check(len(redealt) == 1 and redealt[0]["from"] == "g1" and "heartbeat" in redealt[0]["reason"], f"re-deals: {redealt}")
		shard = redealt[0]["shard"]
		check((watch.task, shard) in quiet.cancels, "the silent machine was not sent cancel")
		await asyncio.sleep(TIMEOUTS["silent"] + 0.5)
		check(at.c.roster["g1"].cancelling, "an unanswered cancel was dropped though its machine was not heard since")
		# Its late done (and files) must change nothing.
		quiet.silent = False
		await until(lambda: quiet.finished)
		await asyncio.sleep(0.3)
		task = at.task(watch.task)
		check(shard in task.leases and task.leases[shard].machine != "g1", "the replacement is not still building")
		check(shard not in task.done, f"late done counted: {task.done.get(shard)!r}")
		check(not os.path.isfile(os.path.join(task.out, f"S{shard}", "summary.txt")), "late files written")
		# Heard from since, its cancel unanswered for the silent limit: taken as idle.
		await until(lambda: not at.c.roster["g1"].cancelling, timeout=4)
		await watch.finished()
		check("machine=g1" not in task.done[shard], f"late done counted: {task.done[shard]!r}")
		return f"g1 silent: S{shard} re-dealt to {redealt[0]['to']} ({redealt[0]['reason']}), late done dropped mid-rebuild, unanswered cancel timed out"
	finally:
		await at.stop(fakes)


async def case_e():
	at = await Hub().start()
	fakes = await at.machines([f"g{n}" for n in range(1, 21)] + [f"m{n}" for n in range(1, 21)], seconds=2.0)
	late = []
	try:
		await until(lambda: len(at.c.connected()) == 40)
		watch = await post(at, units=50)
		check(watch.posted["count"] == 50, "not 50 units")
		await asyncio.sleep(1.0)
		check(len(at.task(watch.task).queue) == 10, f"{len(at.task(watch.task).queue)} queued, wanted 10")
		late = await at.machines([f"m{n}" for n in range(21, 31)], seconds=0.3)
		await watch.finished()
		problem = each_once(fakes + late, watch.task, 50)
		check(not problem, problem)
		check(sorted(len(fake.finished) for fake in late) == [1] * 10, f"late machines did {[len(fake.finished) for fake in late]}")
		return "10 machines joined 1 s late and took the 10 queued units"
	finally:
		await at.stop(fakes + late)


async def case_f():
	at = await Hub().start()
	fakes = await at.machines(["m3", "m4", "m5", "m6"])
	try:
		await until(lambda: len(at.c.connected()) == 4)
		watch = await post(at)
		await watch.finished()
		problem = each_once(fakes, watch.task, 4)
		check(not problem, problem)
	finally:
		await at.stop(fakes)
	at = await Hub().start()
	fakes = []
	try:
		watch = await post(at)
		check(watch.posted["count"] == 1 and watch.posted["up"] == 0, f"posted to nobody: {watch.posted}")
		await asyncio.sleep(0.3)
		fakes = await at.machines(["m9"])
		await watch.finished()
		check(fakes[0].finished, "the first machine did not take the waiting unit")
		return "4 numbered machines alone finished; a task posted to nobody started when m9 connected"
	finally:
		await at.stop(fakes)


async def case_g():
	asked = ["Heavy", "A", "B", "C", "D"]
	units = hub.share_out(asked, 24, {"Heavy": 20, "A": 1, "B": 1, "C": 1, "D": 1})
	shares = collections.Counter(unit.split("@")[0] for unit in units)
	check(len(units) == 24 and shares["Heavy"] == 20 and all(shares[name] == 1 for name in "ABCD"), f"shares {dict(shares)}")
	whole = hub.share_out(["Heavy", "Solo!", "A"], 10, {"Heavy": 5, "Solo": 50, "A": 1})
	check(len(whole) == 10 and whole.count("Solo") == 1 and not any(unit.startswith("Solo@") for unit in whole), f"Solo! got {whole}")
	even = hub.share_out(["A", "B"], 5)
	check(collections.Counter(unit.split("@")[0] for unit in even) == {"A": 3, "B": 2}, f"no weights: {even}")
	# Through the hub, as the client posts it.
	at = await Hub().start()
	try:
		watch = await post(at, units=24, previews=asked, weights={"Heavy": 20, "A": 1, "B": 1, "C": 1, "D": 1})
		check(watch.posted["units"] == units, f"hub units {watch.posted['units']}")
		await watch.close()
	finally:
		await at.stop()
	weights = client.preview_weights(["Heavy", "Unknown!"], {"Heavy": 120.0})
	check(weights.get("Heavy") == 120.0 and weights.get("Unknown") == 120.0, f"client weights {weights}")
	return f"20:1:1:1:1 on 24 units gives {dict(shares)}; Solo! gets one of 10"


async def case_h():
	at = await Hub().start()
	fakes = await at.machines(["g1", "g2", "m1"], seconds=0.3)
	try:
		await until(lambda: len(at.c.connected()) == 3)
		# With previews, a machine is free only once it says previews-done.
		older = await post(at, units=6, previews=["Foo"])
		newer = await post(at, units=3)
		await older.finished()
		await newer.finished()
		got = sorted(entry for fake in fakes for entry in fake.received)
		last_older = max(when for when, task, _ in got if task == older.task)
		first_newer = min(when for when, task, _ in got if task == newer.task)
		check(last_older <= first_newer, "a newer unit was dealt before the older task's queue emptied")
		for watch, count in ((older, 6), (newer, 3)):
			problem = each_once(fakes, watch.task, count)
			check(not problem, problem)
		return "6 units of the older task all dealt before the newer task's 3; both finished"
	finally:
		await at.stop(fakes)


async def case_i():
	at = await Hub().start()
	fakes = await at.machines(["g1", "g2"], seconds=0.3, objects=True)
	victim = fakes[0]
	victim.seconds = 30
	try:
		await until(lambda: len(at.c.connected()) == 2)
		watch = await post(at, upload=True)
		await until(lambda: victim.running)
		await asyncio.sleep(0.3)  # its objects are in and uploading
		await victim.kill()
		finished = await watch.finished()
		task = at.task(watch.task)
		uploading = collections.Counter(event.get("object") for event in watch.of("uploading"))
		uploaded = watch.of("uploaded")
		check(len(watch.of("redealt")) == 1, "not re-dealt")
		check(finished["objects"] == 4 and finished["uploaded"] == 4, f"finished says {finished['objects']} objects, {finished['uploaded']} uploaded")
		check(all(times == 1 for times in uploading.values()) and len(uploading) == 4, f"uploading {dict(uploading)}")
		check(len(uploaded) == 4 and max(event["done"] for event in uploaded) == 4 and all(event["of"] == 4 for event in uploaded),
			f"uploaded events {[(event['object'], event['done'], event['of']) for event in uploaded]}")
		check(len(task.answered) == 4 and task.sent == task.answered, "answered bookkeeping off")
		check(os.path.isdir(os.path.join(task.out, ".redealt")), "the old holder's results were not moved aside")
		# Machine 1 answering twice for one object (the uploader above never
		# asks twice): the task counts it once.
		twice = hub.Task("ttwice", "abc", True, 1, results=os.path.join(at.folder, "results"))
		twice.handed, twice.sent = {"objx": (1, "label x")}, {"objx"}
		at.c.tasks[twice.id] = twice
		emitted = []

		async def record(event):
			emitted.append(event)
		at.c.emit = record
		await at.c.uploaded("objx", "111", None)
		await at.c.uploaded("objx", "111", None)
		answers = [event for event in emitted if event["type"] == "uploaded" and event["task"] == "ttwice"]
		check(len(answers) == 1 and twice.answered == {"objx"}, f"an object answered twice counted {len(answers)} times")
		return "a re-dealt unit's 2 objects handed over twice: 4 objects, 4 uploads, each counted once; a double answer counted once"
	finally:
		await at.stop(fakes)


async def case_j():
	"""Jobs claimed by a returned lease go to the next claimant; a share
	re-dealt with nothing left to bake keeps the bakes its predecessor pushed."""
	at = await Hub().start()
	try:
		task = hub.Task("tclaims", "abc", False, 2, ["Model"], results=os.path.join(at.folder, "results"))
		at.c.tasks[task.id] = task
		task.queue = []
		first, second = hub.Lease(1, "g1"), hub.Lease(2, "g2")
		task.leases = {1: first, 2: second}
		# A claim naming a lease of this machine's that was cancelled is refused.
		holder = hub.Machine("g1", "github")
		holder.lease = (task.id, 1)
		check(at.c.holding(holder, {"task": task.id, "shard": 1, "lease": first.number}), "the current lease's claim refused")
		check(at.c.holding(holder, {"task": task.id, "shard": 1, "lease": first.number + 7}) is None, "an old lease's claim taken")
		claim = lambda lease, number: at.c.next_job(task, lease, {"name": "Model", "kind": "bake", "total": 4, "id": number})
		check([claim(first, 1), claim(first, 2), claim(second, 1), claim(first, 1)] == [0, 1, 2, 0], "claims out of order")
		await at.c.bakes_pushed(task, {"share": "Model@2@2", "commit": "c2"}, second)
		await at.c.redeal(task, 1, "test")
		check(task.queue == [1], "the unit is not queued again")
		third = hub.Lease(3, "g3")
		got = [claim(third, number) for number in range(1, 5)]
		check(got == [0, 1, 3, -1], f"replacement claimed {got}")
		await at.c.redeal(task, 2, "test")
		check(task.returned.get(("Model", "bake")) in (None, []), "settled jobs went back")
		await at.c.bakes_pushed(task, {"share": "Model@2@2", "commit": ""}, None)
		check(task.bakes["Model"]["2"] == "c2", "an empty push replaced the earlier bakes")
		return "returned claims 0,1 went to the replacement first; settled bakes stayed"
	finally:
		await at.stop()


async def case_k():
	"""The real agent: a task arriving while the same unit's cancel still
	runs starts once the cancel is over, under its new lease; never dropped."""
	folder, here = tempfile.mkdtemp(prefix="queue-agent-"), os.getcwd()
	os.chdir(folder)  # cancel() removes results/<unit> under the working folder
	try:
		agent = AGENT.Agent("ws://unused", "ServerMap", 1, 1, 60, 60)
		sent, starts = [], []

		async def send(message):
			sent.append((time.monotonic(), json.loads(message)))

		async def handle(unit, _text, _count, work):
			starts.append(time.monotonic())
			try:
				await asyncio.sleep(30)
			except asyncio.CancelledError:
				await asyncio.sleep(CANCEL_SECONDS)  # killing a build takes a while
				raise
			finally:
				agent.handling.discard(unit)
				if agent.units.get(unit) is work:
					agent.units.pop(unit, None)

		agent.send, agent.handle = send, handle
		task = {"type": "task", "id": "t1", "task": "ref=abc\n", "shard": 1, "count": 2, "lease": 1}
		agent.take(task)
		await asyncio.sleep(0.05)
		agent.stop_unit({"type": "cancel", "task": "t1", "shard": 1})
		agent.take({**task, "lease": 2})
		await until(lambda: len(starts) == 2, timeout=3)
		idle = [when for when, message in sent if message["type"] == "idle"]
		check(len(idle) == 1 and starts[1] >= idle[0], f"idle at {idle}, second start at {starts[1]}")
		check(agent.units[("t1", 1)]["lease"] == 2, "the new start is not under the new lease")
		check(not agent.cancelling, "the cancel is still listed")
		for work in list(agent.units.values()):
			work["task"].cancel()
		return "cancel then task for one unit: the task waited for the cancel's idle, then started under lease 2"
	finally:
		os.chdir(here)
		shutil.rmtree(folder, ignore_errors=True)


async def case_l():
	at = await Hub().start()
	first = (await at.machines(["m5"]))[0]
	second = Fake(at, "m5")
	try:
		await until(lambda: "m5" in at.c.roster and at.c.roster["m5"].socket is not None)
		await second.connect()
		await asyncio.wait_for(second.socket.wait_closed(), 3)
		check(second.socket.close_code == 4003, f"the second m5 closed with {second.socket.close_code}")
		check(not first.socket.closed, "the first m5 lost its connection")
		watch = await post(at, units=1)
		await watch.finished()
		check(first.finished and not second.received, "the second m5 got a unit")
		return "a second m5 was refused (4003) while the first was connected and heard; the first built the unit"
	finally:
		await at.stop([first, second])


async def case_m():
	at = await Hub().start()
	# g1 joins first, so the roster deals it S1, the slow one.
	fakes = await at.machines(["g1"], seconds=3.0)
	again = None
	try:
		await until(lambda: len(at.c.connected()) == 1)
		fakes += await at.machines(["g2", "g3"], seconds=0.3)
		await until(lambda: len(at.c.connected()) == 3)
		watch = await post(at)
		await until(lambda: fakes[1].finished and fakes[2].finished and fakes[0].running)
		await asyncio.sleep(0.2)
		# The hub restarts; the machines' work goes on.
		await at.stop(keep=True)
		again = await Hub().start(folder=at.folder)
		again.c.load_tasks()
		for fake in fakes:
			fake.hub = again
		dealt = len(fakes[1].received) + len(fakes[2].received)
		await fakes[1].connect()
		await fakes[2].connect()
		await asyncio.sleep(0.5)
		check(len(fakes[1].received) + len(fakes[2].received) == dealt, "an idle machine was dealt a unit during the restart hold")
		# The one still building comes back late, inside the hold.
		await fakes[0].connect()
		task = again.c.tasks[watch.task]
		await until(lambda: len(task.done) == 3, timeout=8)
		problem = each_once(fakes, watch.task, 3)
		check(not problem, problem)
		check(not fakes[0].cancels and fakes[0].starts == [(watch.task, 1)], f"g1 cancelled {fakes[0].cancels} or restarted {fakes[0].starts}")
		return "hub restarted: done units not rebuilt, idle machines held off, g1 reconnected late and kept S1"
	finally:
		await (again or at).stop(fakes)


async def case_n():
	at = await Hub().start()
	fakes = await at.machines(["g1"], seconds=2.5)
	machine = fakes[0]
	try:
		await until(lambda: len(at.c.connected()) == 1)
		watch = await post(at)
		await until(lambda: machine.running)
		await machine.drop()
		task = at.task(watch.task)
		# Taken back after the grace, and still queued: nobody else to take it.
		await until(lambda: task.queue == [1] and not task.leases, timeout=3)
		await machine.connect()
		await until(lambda: 1 in task.leases)
		check(not at.c.roster["g1"].cancelling, "it holds the unit and still owes a cancel")
		await watch.finished()
		check(not machine.cancels, f"sent cancel for its own unit: {machine.cancels}")
		check(machine.starts == [(watch.task, 1)] and machine.finished == [(watch.task, 1)], f"started {machine.starts}")
		check(not watch.of("redealt"), "reported a re-deal")
		return "g1 came back after the grace with S1 still queued: its lease back, no cancel, no restart"
	finally:
		await at.stop(fakes)


async def case_o():
	at = await Hub().start()
	fakes = await at.machines(["g1", "g2"], seconds=0.3)
	stalled, swapping = fakes
	stalled.stage, swapping.stage = "stall", "swap"
	spare = []
	try:
		await until(lambda: len(at.c.connected()) == 2)
		watch = await post(at)
		posted = time.time()
		spare = await at.machines(["g3"])
		await until(lambda: watch.of("redealt"), timeout=TIMEOUTS["wedged"] + 3)
		redealt = watch.of("redealt")
		check(redealt[0]["from"] == "g1" and "wedged" in redealt[0]["reason"], f"re-deals: {redealt}")
		await asyncio.sleep(max(0, posted + TIMEOUTS["wedged"] + 1.5 - time.time()))
		check(len(watch.of("redealt")) == 1, f"the swap wait was re-dealt: {watch.of('redealt')}")
		swapping.stage = "build"
		await watch.finished()
		check(swapping.finished and spare[0].finished, "the units did not finish")
		return f"a hung lane (probe still writing) re-dealt as wedged; a swap wait past {TIMEOUTS['wedged']:.0f}s kept"
	finally:
		await at.stop(fakes + spare)


CASES = [("a", case_a), ("b", case_b), ("c", case_c), ("d", case_d), ("e", case_e), ("f", case_f),
	("g", case_g), ("h", case_h), ("i", case_i), ("j", case_j), ("k", case_k), ("l", case_l), ("m", case_m),
	("n", case_n), ("o", case_o)]


async def main():
	started = time.time()
	failed = 0
	# The bake swap and early publish cases, kept in their own file.
	import test_swap
	CASES.extend(test_swap.cases(sys.modules[__name__]))
	# Hot updates and engine checks.
	import test_update
	CASES.extend(test_update.cases(sys.modules[__name__]))
	for name, case in CASES:
		began = time.time()
		try:
			detail = await asyncio.wait_for(case(), CASE_SECONDS)
			print(f"PASS {name} ({time.time() - began:.1f}s): {detail}", flush=True)
		except Exception as error:
			failed += 1
			reason = str(error) or type(error).__name__
			print(f"FAIL {name} ({time.time() - began:.1f}s): {reason}", flush=True)
			if "-v" in sys.argv:
				traceback.print_exc()
	print(f"{len(CASES) - failed} of {len(CASES)} cases passed in {time.time() - started:.1f}s", flush=True)
	return 1 if failed else 0


if __name__ == "__main__":
	sys.exit(asyncio.run(main()))
