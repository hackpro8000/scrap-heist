"""Engine checks (a part of Coordinator): `engine <sha>` from a session
becomes a one-unit task of its own kind, leased like any unit (so a lost
machine's check is taken back and dealt again) but only to a machine with
cargo, g1 first. The machine checks the commit out, runs
scripts/build-model.sh --engine, and its output streams to the session."""
import json
import os
import time

import websockets

from hub_config import say
from hub_update import SHA
from units import Task

MAX_LINES = 500  # lines one engine-output message may carry
MAX_LINE = 2000


class EngineTask(Task):
	engine = True
	completed = True  # never written to the tasks file: a restarted hub drops it, its machine is told to stop

	def __init__(self, identity, commit, results):
		super().__init__(identity, commit, False, 1, (), False, None, results)

	def message(self, shard, lease):
		return json.dumps({"type": "engine", "id": self.id, "shard": shard, "commit": self.ref, "lease": lease.number if lease else 0})


class EngineChecks:
	async def engine_request(self, socket, request):
		commit = request.get("commit")
		if not isinstance(commit, str) or not SHA.fullmatch(commit):
			await socket.send(json.dumps({"type": "error", "text": "engine wants a full 40-character commit sha"}))
			return
		self.posted += 1
		identity = f"e{int(time.time())}-{os.getpid()}-{self.posted}"
		task = self.tasks[identity] = EngineTask(identity, commit, self.results)
		self.watchers.add(socket)
		task.watchers.add(socket)
		cargo = [machine.name for machine in self.connected() if machine.cargo]
		say(f"engine check {identity} of {commit[:12]}; machines with cargo: {' '.join(cargo) or 'none yet'}")
		await socket.send(json.dumps({"type": "engine-posted", "task": identity, "cargo": cargo}))
		await self.deal()
		try:
			async for _ in socket:
				pass
		except websockets.ConnectionClosed:
			pass
		finally:
			self.watchers.discard(socket)
			task.watchers.discard(socket)

	async def deal_engine(self):
		"""Each queued engine check to an idle machine with cargo, g1 first."""
		for task in [task for task in self.tasks.values() if task.engine and task.queue]:
			idle = [machine for machine in self.roster.values() if machine.socket is not None and not machine.lease
				and not machine.cancelling and machine.cargo and not self.stale(machine)]
			if not idle:
				continue
			machine = next((machine for machine in idle if machine.name == "g1"), idle[0])
			await self.grant(machine, task, task.queue.pop(0))

	async def tell_task(self, task, event):
		message = json.dumps(event)
		for watcher in list(task.watchers):
			try:
				await watcher.send(message)
			except Exception:
				task.watchers.discard(watcher)

	async def engine_event(self, task, shard, event, name):
		if event.get("type") == "engine-output":
			lines = event.get("lines") if isinstance(event.get("lines"), list) else []
			lines = [line[:MAX_LINE] for line in lines[:MAX_LINES] if isinstance(line, str)]
			await self.tell_task(task, {"type": "engine-output", "task": task.id, "machine": name, "lines": lines})
			return
		ok = event.get("ok") is True
		tail = event.get("tail") if isinstance(event.get("tail"), list) else []
		task.done[shard] = "status=DONE\n" if ok else "status=FAILED\n"
		lease = task.leases.get(shard)
		say(f"engine check {task.id} on {name}: {'ok' if ok else 'FAILED'}")
		await self.tell_task(task, {"type": "engine-finished", "task": task.id, "machine": name, "ok": ok, "code": event.get("code"),
			"tail": [line[:MAX_LINE] for line in tail[-200:] if isinstance(line, str)],
			"seconds": round(time.time() - lease.dealt) if lease else None})
		await self.unit_over(task, shard)
		self.tasks.pop(task.id, None)
