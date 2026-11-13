"""Cases for the bake swap and the early publish (hub_previews.py), run by
test_queue.py with its other cases. The fake machines here do what the engine
does through the real agent: claim bake chunks until none are left, push,
wait in the swap until the hub says it is over (asking again as the agent
does, with no time limit), paint, claim renders, and send their share."""
import asyncio
import json
import os
import time

import hub_previews

BAKE_CHUNKS = 6
RENDERS = 3  # preview.png and two turns: short of four, so no montage runs
REAL_ROOT = hub_previews.ROOT


def cases(q):
	"""The cases, given test_queue's own module (its Hub, Fake, post, check)."""

	class Sharer(q.Fake):
		"""A machine on one share of a model: `bake` seconds a chunk, `paint`
		seconds between the swap and its first render claim."""

		def __init__(self, at, name, bake=0.05, paint=0.05):
			super().__init__(at, name)
			self.bake, self.paint = bake, paint
			self.answers = {}  # claim number -> future for its job
			self.asked = 0
			self.baked, self.rendered = [], []
			self.commit = f"{int(name[1:]):040x}"
			self.swapping = False
			self.over = asyncio.Event()  # the hub said the swap is over
			self.commits = None
			self.pushed_at = self.swap_over = None

		def heard(self, event):
			if event["type"] == "claimed" and event["id"] in self.answers:
				if not self.answers[event["id"]].done():
					self.answers[event["id"]].set_result(event["job"])
			elif event["type"] == "bakes-ready" and event.get("done") and self.swapping:
				self.commits = event["commits"]
				self.over.set()

		async def claim(self, unit, model, kind, total, lease):
			self.asked += 1
			answer = self.answers[self.asked] = asyncio.get_running_loop().create_future()
			await self.send(json.dumps({"type": "claim", "task": unit[0], "shard": unit[1], "name": model, "kind": kind,
				"total": total, "id": self.asked, "lease": lease}))
			return await answer

		async def beat(self, unit):
			while True:
				await self.send(json.dumps({"type": "progress", "task": unit[0], "shard": unit[1], "stage": "swap", "model": "",
					"line": "", "quiet": 0, "seconds": 0}))
				await asyncio.sleep(q.BEAT)

		async def work(self, unit, event):
			shard, lease = unit[1], event["lease"]
			self.starts.append(unit)
			names = next(line[8:] for line in event["task"].splitlines() if line.startswith("preview=")).split(",")
			share = names[shard - 1]
			model = share.split("@")[0]
			beating = asyncio.ensure_future(self.beat(unit))
			try:
				await self.send(json.dumps({"type": "done", "task": unit[0], "shard": shard, "summary": "status=DONE\n"}))
				while (job := await self.claim(unit, model, "bake", BAKE_CHUNKS, lease)) >= 0:
					self.baked.append(job)
					await asyncio.sleep(self.bake)
				self.swapping, self.pushed_at = True, time.time()
				while not self.over.is_set():
					await self.send(json.dumps({"type": "bakes-pushed", "task": unit[0], "shard": shard, "share": share,
						"commit": self.commit if self.baked else "", "lease": lease}))
					try:
						await asyncio.wait_for(self.over.wait(), 0.5)
					except asyncio.TimeoutError:
						pass
				self.swap_over = time.time()
				await asyncio.sleep(self.paint)
				while (job := await self.claim(unit, model, "render", RENDERS, lease)) >= 0:
					self.rendered.append(job)
					await asyncio.sleep(0.05)
				await self.send_file(unit, f"previews/{share}/build.log", b"built\n")
				for job in self.rendered:
					name = "preview.png" if job == 0 else f"view{job - 1}.png"
					await self.send_file(unit, f"previews/{share}/{name}", f"render {job}".encode())
				await self.send(json.dumps({"type": "preview-ready", "task": unit[0], "shard": shard, "name": share, "seconds": 1.0}))
				await self.send(json.dumps({"type": "previews-done", "task": unit[0], "shard": shard}))
				self.finished.append(unit)
			finally:
				beating.cancel()
				if self.running.get(unit) is asyncio.current_task():
					del self.running[unit]

	async def begin(machines, units):
		"""A hub whose model folder is a temporary one, the machines connected, and a previews-only task of Model."""
		at = await q.Hub().start()
		model = os.path.join(at.folder, "root", "art", "models", "Model")
		os.makedirs(model)
		open(os.path.join(model, "model.luau"), "w").close()
		hub_previews.ROOT = os.path.join(at.folder, "root")
		fakes = [Sharer(at, name, **options) for name, options in machines]
		await asyncio.gather(*(fake.connect() for fake in fakes))
		await q.until(lambda: len(at.c.connected()) == len(fakes))
		watch = await q.post(at, units=units, previews=["Model"], build=False)
		return at, fakes, watch, model

	async def end(at, fakes):
		hub_previews.ROOT = REAL_ROOT
		await at.stop(fakes)

	async def published(at, watch, model):
		"""The task over with nothing waiting, and Model's preview stored once, whole."""
		await watch.finished()
		await q.until(lambda: watch.task not in at.c.tasks and watch.of("preview"), timeout=5)
		# The session reads a moment behind the hub; a second preview event would show by then.
		await asyncio.sleep(0.2)
		shown = [event["path"] for event in watch.of("preview")]
		q.check(len(shown) == 1 and "FAILED" not in shown[0], f"preview events: {shown}")
		q.check(open(os.path.join(model, "preview.png")).read() == "render 0", "the stored preview is not render 0")
		merged = os.listdir(os.path.join(at.task(watch.task).out, "previews", "Model"))
		q.check({"preview.png", "view0.png", "view1.png"} <= set(merged), f"renders missing from the merged folder: {merged}")

	async def case_p():
		"""Five shares, three machines: the swap ends when every claimed chunk
		is pushed, not when every share has; then the preview is published
		when its renders are in, and the other shares are stopped or dropped."""
		at, fakes, watch, model = await begin([("g1", {"paint": 30}), ("g2", {"paint": 30}), ("g3", {"bake": 0.8})], 5)
		quick, _, slow = fakes
		try:
			await published(at, watch, model)
			baked = sorted(job for fake in fakes for job in fake.baked)
			q.check(baked == list(range(BAKE_CHUNKS)), f"chunks baked: {baked}")
			q.check(slow.baked and quick.swap_over >= slow.pushed_at - 0.05, "the swap ended before a machine holding a chunk had pushed")
			q.check(quick.swap_over - slow.pushed_at < 0.5, "the swap waited on shares that had claimed nothing")
			q.check(set(quick.commits) == {fake.commit for fake in fakes if fake.baked}, f"commits to fetch: {quick.commits}")
			q.check(slow.rendered == list(range(RENDERS)), f"renders made by the first to paint: {slow.rendered}")
			q.check(all((watch.task, n) in fakes[n - 1].cancels for n in (1, 2)), "the shares still painting were not stopped")
			q.check(sum(len(fake.starts) for fake in fakes) == 3, "a share was started after the preview was complete")
			task = at.task(watch.task)
			q.check(len(task.done) == 5 and not task.queue and not task.leases, "hub bookkeeping not finished")
			await q.until(lambda: all(not machine.lease and not machine.cancelling for machine in at.c.roster.values()), timeout=5)
			return "swap over at the last baker's push with 2 shares unstarted; published on the renders, 2 painters stopped, 2 shares dropped"
		finally:
			await end(at, fakes)

	async def case_q():
		"""A baker dies holding a chunk and no machine is free: once its lease
		is lost the swap ends, and the others bake that chunk themselves."""
		at, fakes, watch, model = await begin([("g1", {}), ("g2", {}), ("g3", {"bake": 30})], 3)
		try:
			await q.until(lambda: fakes[2].baked and fakes[0].pushed_at and fakes[1].pushed_at)
			await asyncio.sleep(0.4)
			q.check(not fakes[0].over.is_set(), "the swap ended while a live machine still held a chunk")
			died = time.time()
			await fakes[2].kill()
			await q.until(lambda: fakes[0].swap_over and fakes[1].swap_over, timeout=6)
			q.check(fakes[0].swap_over - died >= q.TIMEOUTS["grace"] * 0.8, "the swap ended before the dead baker's lease was lost")
			q.check(fakes[2].commit not in fakes[0].commits, "a commit never pushed was named")
			await published(at, watch, model)
			return f"swap held for the baker's lease ({fakes[0].swap_over - died:.1f}s), then ended without its chunk"
		finally:
			await end(at, fakes)

	async def case_r():
		"""A baker dies holding a chunk and a machine is free: the chunk goes
		to the replacement, and the swap waits for it."""
		at, fakes, watch, model = await begin([("g1", {}), ("g2", {"bake": 30}), ("g3", {})], 2)
		waiting, dying, spare = fakes
		try:
			await q.until(lambda: dying.baked and waiting.pushed_at)
			await dying.kill()
			await published(at, watch, model)
			q.check(spare.baked == dying.baked, f"the replacement baked {spare.baked}, the lost lease held {dying.baked}")
			q.check(waiting.swap_over >= spare.pushed_at - 0.05, "the swap ended before the replacement pushed the returned chunk")
			q.check(spare.commit in waiting.commits, "the replacement's bakes were not named to fetch")
			return f"returned chunk {spare.baked} baked by the replacement, and waited for"
		finally:
			await end(at, fakes)

	async def case_s():
		"""Two shares, both through the swap: the one that paints first makes
		every render, the preview is published then, and the other is stopped."""
		at, fakes, watch, model = await begin([("g1", {}), ("g2", {"paint": 30})], 2)
		try:
			began = time.time()
			await published(at, watch, model)
			q.check((watch.task, 2) in fakes[1].cancels and not fakes[1].finished, "the share still painting was not stopped")
			q.check(len(watch.of("preview-share")) == 2, "the stopped share's seconds were not reported")
			await q.until(lambda: not at.c.roster["g2"].lease and not at.c.roster["g2"].cancelling, timeout=5)
			return f"published {time.time() - began:.1f}s in, on one share's renders; the painter stopped and idle again"
		finally:
			await end(at, fakes)

	return [("p", case_p), ("q", case_q), ("r", case_r), ("s", case_s)]
