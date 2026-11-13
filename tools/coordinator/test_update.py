"""Cases for hot updates and engine checks (hub_update.py, hub_engine.py,
client_update.py, scripts/standby_agent/update.py), run by test_queue.py with
its other cases. The hub's checkout and exit, and the real agent's checkout
and re-execution, are replaced by seams that record what they were asked;
the hub's "restart" is a new boot id on the same hub."""
import asyncio
import contextlib
import io
import json
import os
import secrets
import sys

import client_update

OLD, NEW, NEWER = "a" * 40, "b" * 40, "c" * 40


def cases(q):
	"""The cases, given test_queue's own module (its Hub, Fake, post, check)."""
	client_update.POLL_SECONDS = 0.05
	# The real agent's modules (loaded with scripts/standby-agent.py) say and alert on their own.
	from standby_agent import update as agent_update
	alerts = []
	agent_update.alert = alerts.append
	if "-v" not in sys.argv:
		for name, module in list(sys.modules.items()):
			if name.startswith("standby_agent") and hasattr(module, "say"):
				module.say = lambda message: None

	class Updater(q.Fake):
		"""A machine that updates as the agent does: at once when idle, else
		when its unit ends; it reconnects whenever the hub closes on it."""

		def __init__(self, at, name, code=NEW, cargo=False, engine="ok", stubborn=False, **options):
			super().__init__(at, name, **options)
			self.code, self.cargo, self.engine, self.stubborn = code, cargo, engine, stubborn
			self.want, self.updating, self.updates, self.checks = None, False, 0, []
			self.finished_at_update = []

		def hello(self):
			return {**super().hello(), "code": self.code, "cargo": self.cargo}

		async def connect(self):
			await super().connect()
			socket = self.socket
			self.reader.add_done_callback(lambda _: self.closed(socket))

		def closed(self, socket):
			if socket is self.socket and not self.dead and not self.updating:
				asyncio.ensure_future(self.again())

		async def again(self):
			while not self.dead:
				try:
					await self.connect()
					return
				except OSError:
					await asyncio.sleep(0.05)

		def heard(self, event):
			if event["type"] in ("hub", "update") and event["commit"] != self.code and not self.stubborn:
				self.want = event["commit"]
				self.update_if_due()
			elif event["type"] == "engine":
				asyncio.ensure_future(self.check(event))

		def update_if_due(self):
			if self.want and not self.running and not self.updating:
				self.updating = True
				asyncio.ensure_future(self.restart())

		async def restart(self):
			self.finished_at_update.append(len(self.finished))
			await self.socket.close()
			self.code, self.want = self.want, None
			self.updates += 1
			await self.again()
			self.updating = False

		async def work(self, unit, event):
			await super().work(unit, event)
			self.update_if_due()

		async def check(self, event):
			unit, lease = (event["id"], event["shard"]), event["lease"]
			self.checks.append(unit)

			def output(lines):
				return self.send(json.dumps({"type": "engine-output", "task": unit[0], "shard": unit[1], "lease": lease, "lines": lines}))

			await output([f"   Compiling modelkit v0.1.0 on {self.name}"])
			if self.engine == "die":
				await self.kill()
				return
			await asyncio.sleep(0.1)
			ok = self.engine == "ok"
			if not ok:
				await output(["error[E0425]: cannot find value `x` in this scope"])
			await self.send(json.dumps({"type": "engine-done", "task": unit[0], "shard": unit[1], "lease": lease, "ok": ok,
				"code": 0 if ok else 101, "tail": [] if ok else ["error: could not compile `modelkit`"]}))

	async def begin(machines, code=NEW):
		"""A hub on `code` in a restart loop, its checkout and exit recorded, and the machines connected."""
		at = await q.Hub().start()
		at.c.code_commit, at.c.restarts = code, True
		at.checkouts, at.exits = [], []
		at.c.checkout_code = lambda commit: (at.checkouts.append(commit), (True, ""))[1]
		at.c.exit_for_update = lambda: (at.exits.append(at.c.code_commit), setattr(at.c, "boot", secrets.token_hex(4)))
		fakes = [Updater(at, name, **options) for name, options in machines]
		await asyncio.gather(*(fake.connect() for fake in fakes))
		await q.until(lambda: len(at.c.connected()) == len(fakes))
		return at, fakes

	async def captured(coroutine):
		buffer = io.StringIO()
		with contextlib.redirect_stdout(buffer):
			code = await coroutine
		return code, buffer.getvalue()

	async def case_w():
		"""An update is refused while a task runs, and goes ahead with --force:
		the machines finish their units on the old code, then update."""
		at, fakes = await begin([("g1", {"seconds": 1.5}), ("g2", {"seconds": 1.5})])
		try:
			watch = await q.post(at)
			await q.until(lambda: all(fake.running for fake in fakes))
			code, out = await captured(client_update.update(at.control_url, NEWER, False, 5))
			q.check(code == 1 and "tasks open" in out and not at.checkouts, f"not refused with a task running: {code} {out!r}")
			code, out = await captured(client_update.update(at.control_url, NEWER, True, 10))
			q.check(code == 0 and "2 of 2 machines on" in out, f"the forced update did not finish: {code} {out!r}")
			q.check(at.checkouts == [NEWER] and at.exits == [NEWER], f"hub checkouts {at.checkouts}, exits {at.exits}")
			q.check(all(fake.code == NEWER and fake.updates == 1 for fake in fakes), "a machine is not on the new code")
			q.check(all(fake.finished_at_update == [1] for fake in fakes), "a machine updated before its unit was over")
			await watch.finished()
			problem = q.each_once(fakes, watch.task, 2)
			q.check(not problem, problem)
			return "refused with a task open; forced: hub checked out and exited, both machines updated after their units, each unit done once"
		finally:
			await at.stop(fakes)

	async def case_x():
		"""Idle machines are told, update and report the new commit; one that
		cannot update is dealt nothing until it says its update failed."""
		at, fakes = await begin([(name, {"code": OLD}) for name in ("g1", "g2", "m1", "m2")], code=OLD)
		stubborn = Updater(at, "g3", code=OLD, stubborn=True)
		try:
			code, out = await captured(client_update.update(at.control_url, NEW, False, 8))
			q.check(code == 0 and "4 of 4 machines on" in out, f"update: {code} {out!r}")
			q.check(all(fake.code == NEW and fake.updates == 1 for fake in fakes), "a machine did not update")
			await stubborn.connect()
			await q.until(lambda: at.c.roster.get("g3") and at.c.roster["g3"].socket is not None)
			code, out = await captured(q.client.status(at.control_url))
			q.check(f"g3={OLD[:12]}" in out and f"code={NEW}" in out, f"status did not show the machine on other code: {out!r}")
			watch = await q.post(at, units=6)
			await watch.finished()
			q.check(not stubborn.starts, "a machine on other code than the hub's was dealt a unit")
			await stubborn.send(json.dumps({"type": "update-failed", "commit": NEW, "text": "test"}))
			await q.until(lambda: at.c.roster["g3"].update_failed == NEW)
			watch = await q.post(at, units=5)
			await watch.finished()
			q.check(stubborn.starts, "a machine whose update failed was never dealt a unit")
			return "4 idle machines updated and reported; status names the one on old code, dealt nothing until its update failed"
		finally:
			await at.stop(fakes + [stubborn])

	async def case_y():
		"""The real agent: greeted by a hub on other code while idle it updates
		at once; holding a unit it waits for the unit to end; a failed checkout
		alerts, tells the hub, and is not tried again."""
		os.environ["AGENT_TEST_TOKEN"] = "test"
		at, _ = await begin([])
		sessions = []

		def real(index, code, fail=False):
			agent = q.AGENT.Agent(at.agent_url, "ServerMap", index, 20, 60, 300)
			agent.code_commit, agent.checkouts, agent.execs = code, [], []
			agent.checkout_code = lambda commit: (agent.checkouts.append(commit), (not fail, "fetch: no such commit"))[1]
			agent.reexec = agent.execs.append
			sessions.append(asyncio.ensure_future(agent.session()))
			return agent

		try:
			idle = real(5, OLD)
			await q.until(lambda: idle.execs == [NEW])
			busy = real(6, NEW)
			await q.until(lambda: at.c.roster.get("g6") and at.c.roster["g6"].socket is not None)
			busy.handling.add(("tbusy", 1))
			await captured(client_update.update(at.control_url, NEWER, False, 0.3))
			await q.until(lambda: busy.update_to == NEWER)
			q.check(not busy.execs and not busy.checkouts, "the agent updated while holding a unit")
			busy.handling.discard(("tbusy", 1))
			busy.update_if_due()  # what the end of a unit calls (units.py handle, cancel)
			await q.until(lambda: busy.execs == [NEWER])
			failing = real(7, OLD, fail=True)
			await q.until(lambda: at.c.roster.get("g7") and at.c.roster["g7"].update_failed == NEWER)
			failing.want_update(NEWER)
			await asyncio.sleep(0.1)
			q.check(failing.checkouts == [NEWER] and not failing.execs, f"failed checkout retried or executed: {failing.checkouts} {failing.execs}")
			q.check(any(line.startswith("ALERT UPDATE_FAILED: S7 could not check out") and " | " in line for line in alerts), f"alerts: {alerts}")
			q.check(not at.c.stale(at.c.roster["g7"]), "the hub still holds back a machine whose update failed")
			return "real agent: idle updated on greeting, busy updated only after its unit, failed checkout alerted once and kept taking units"
		finally:
			for session in sessions:
				session.cancel()
			await at.stop()

	async def engine_case(machines, expect_code, expect_text, ran, idle):
		at, fakes = await begin(machines)
		try:
			code, out = await captured(client_update.engine(at.control_url, NEW, 15))
			q.check(code == expect_code and all(text in out for text in expect_text), f"engine: {code} {out!r}")
			by_name = {fake.name: fake for fake in fakes}
			q.check(all(by_name[name].checks for name in ran) and not any(by_name[name].checks for name in idle),
				f"checks: {[(fake.name, len(fake.checks)) for fake in fakes]}")
			await q.until(lambda: not at.c.tasks, timeout=3)
			return out
		finally:
			await at.stop(fakes)

	async def case_z():
		"""A failed compile, on the one machine with cargo: output relayed, exit 1."""
		await engine_case([("g1", {}), ("g2", {"cargo": True, "engine": "fail"}), ("m1", {})], 1,
			["Compiling modelkit v0.1.0 on g2", "error[E0425]", "ENGINE FAILED on g2"], ["g2"], ["g1", "m1"])
		return "dealt to the only machine with cargo, compiler error relayed, exit 1"

	async def case_za():
		"""g1 is preferred when it has cargo; a good compile exits 0."""
		await engine_case([("g1", {"cargo": True}), ("g2", {"cargo": True})], 0, ["on g1", "ENGINE OK on g1"], ["g1"], ["g2"])
		return "g1 preferred, output relayed, exit 0"

	async def case_zb():
		"""The machine compiling is lost: its check is re-dealt to another with cargo."""
		await engine_case([("g1", {"cargo": True, "engine": "die"}), ("g2", {"cargo": True})], 0,
			["on g1", "ALERT REDEALT: engine check from g1 to g2", "ENGINE OK on g2"], ["g1", "g2"], [])
		return "g1 lost mid-check, re-dealt to g2, exit 0"

	return [("w", case_w), ("x", case_x), ("y", case_y), ("z", case_z), ("za", case_za), ("zb", case_zb)]
