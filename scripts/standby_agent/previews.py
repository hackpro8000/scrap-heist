"""Agent mixin: a unit's share of the previews, and the bake sharing behind
them: the local claim server the engine asks (work.rs), claims, bake swaps."""
import asyncio
import json
import os
import subprocess
import time

from standby_agent.common import CLAIM_TRIES, CLAIM_WAIT_SECONDS, say
from standby_agent.machine import push_bakes, push_preview, trim_log
import commits  # noqa: E402


class Previews:
	async def send_previews(self, unit, text, count, work):
		"""Renders this unit's share of the task's previews once its build
		result has gone (scripts/standby-previews.sh), sends them, then says
		so, even with nothing to render, so the coordinator can count units."""
		identity, shard = unit
		names = next((line[8:] for line in text.splitlines() if line.startswith("preview=")), "")
		if not names:
			return
		out = os.path.join(self.built[unit], "previews-run")
		# This unit's share: every count-th name from its shard. Each model
		# goes the moment it is rendered, so the first preview comes in seconds.
		share = [name for n, name in enumerate(names.split(",")) if n % count == shard - 1]
		for model in share:
			folder = os.path.join(out, "previews", model)
			began = time.monotonic()
			if not os.path.isdir(folder):
				env, server = dict(os.environ), None
				log = os.path.join(folder, "build.log")
				try:
					if "@" in model and int(model.rsplit("@", 1)[1]) > 1:
						os.makedirs(out, exist_ok=True)
						self.timings.setdefault((identity, model.split("@")[0]), {})["bake_start"] = time.monotonic()
						# A second back, for a file saved in the second this began.
						server = await self.claim_server(unit, model, out, time.time() - 1, work)
						env["WORK_PORT"] = str(server.sockets[0].getsockname()[1])
						self.begin(unit, "bake", log, model)
					else:
						self.begin(unit, "render", log, model)
					await asyncio.to_thread(self.run_process, work, ["scripts/standby-previews.sh", model, "1", "1", out],
						stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
				finally:
					# Closed on a cancel too, so a killed engine's port takes no more claims.
					if server:
						server.close()
				self.timings.setdefault((identity, model.split("@")[0]), {})["render_end"] = time.monotonic()
			if work["cancelled"]:
				return
			trim_log(os.path.join(folder, "build.log"))
			pushed = await asyncio.to_thread(push_preview, folder, model) if os.path.isdir(folder) else ""
			# Machine-seconds this share took, for cost-sized shares (client.py).
			seconds = round(time.monotonic() - began, 1)
			if pushed:
				await self.send(json.dumps({"type": "preview-pushed", "task": identity, "shard": shard, "name": model, "commit": pushed,
					"seconds": seconds}))
			else:
				# GitHub turned the push away: the tunnel is slower, but it works.
				for name in sorted(os.listdir(folder)) if os.path.isdir(folder) else []:
					with open(os.path.join(folder, name), "rb") as file:
						data = file.read()
					await self.send_file(unit, os.path.join("previews", model, name), data)
				await self.send(json.dumps({"type": "preview-ready", "task": identity, "shard": shard, "name": model, "seconds": seconds}))
			self.report_timing(identity, model)
		await self.send(json.dumps({"type": "previews-done", "task": identity, "shard": shard}))
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

	async def claim(self, unit, model, kind, total, work):
		"""The next job of this kind for this machine, -1 when none are left
		or the unit was cancelled. A retry repeats the number, so a lost
		answer can't lose a job; the lease number lets the coordinator refuse
		a cancelled lease's claim."""
		identity, shard = unit
		self.claim_number += 1
		number = self.claim_number
		timing = self.timings.setdefault((identity, model), {})
		asked = time.monotonic()
		timing.setdefault(f"first_{kind}", asked)
		self.moved(unit)
		message = json.dumps({"type": "claim", "task": identity, "shard": shard, "name": model, "kind": kind, "total": total, "id": number,
			"lease": work.get("lease")})
		for _ in range(CLAIM_TRIES):
			if work["cancelled"]:
				return -1
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

	async def claim_server(self, unit, share, out, since, work):
		"""A local port where this machine's engine asks for its next job, and
		says when its baking is done."""
		model = share.split("@")[0]

		async def serve(reader, writer):
			while line := await reader.readline():
				kind, total = line.decode().split()
				if kind == "swap":
					await self.share_bakes(unit, share, out, since, work)
					answer = 0
				else:
					answer = await self.claim(unit, model, kind, int(total), work)
				writer.write(f"{answer}\n".encode())
				await writer.drain()
			writer.close()

		return await asyncio.start_server(serve, "127.0.0.1", 0)

	async def share_bakes(self, unit, share, out, since, work):
		"""Asked by the engine once it has baked what it claimed: pushes those
		layers and takes every other machine's, so no two machines bake the
		same texture. The coordinator says when the swap is over: when every
		chunk claimed has been pushed by its baker (hub_previews.bakes_done),
		however many shares never claimed one. There is no time limit here: a
		baker that dies loses its lease, and the coordinator ends the swap or
		has another machine bake its chunks. The push is said again every
		CLAIM_WAIT_SECONDS and answered with where the swap stands, so an
		answer lost over a reconnect is asked for again."""
		identity, shard = unit
		model = share.split("@")[0]
		log = os.path.join(out, "previews", share, "build.log")
		timing = self.timings.setdefault((identity, model), {})
		timing["bake_end"] = time.monotonic()
		self.begin(unit, "swap", log, share)
		ready = self.bakes_ready[(identity, model)] = asyncio.get_running_loop().create_future()
		try:
			mine = await asyncio.to_thread(push_bakes, model, share, out, since)
			timing["pushed"] = time.monotonic()
			while True:
				if work["cancelled"]:
					return
				await self.send(json.dumps({"type": "bakes-pushed", "task": identity, "shard": shard, "share": share, "commit": mine,
					"lease": work.get("lease")}))
				try:
					commits = await asyncio.wait_for(asyncio.shield(ready), CLAIM_WAIT_SECONDS)
					break
				except asyncio.TimeoutError:
					continue
		finally:
			self.bakes_ready.pop((identity, model), None)
		timing["ready"] = time.monotonic()
		say(f"task {identity}: swap of {share} over {timing['ready'] - timing['pushed']:.1f}s after its push; taking {len([c for c in commits if c != mine])} machines' bakes")
		cache = os.path.join("art", "models", model, ".cache")
		fetched = await asyncio.gather(*[asyncio.to_thread(self.fetch_objects, commit, cache) for commit in commits if commit != mine], return_exceptions=True)
		timing["fetched"] = time.monotonic()
		for error in [result for result in fetched if isinstance(result, Exception)]:
			say(f"task {identity}: could not fetch bakes of {model}: {error}")
		self.begin(unit, "render", log, share)

	def fetch_objects(self, commit, into):
		"""Machine 1 takes a builder's objects, and every machine the others'
		bakes, each from a GitHub commit."""
		commits.fetch_into(os.getcwd(), os.path.join(os.getcwd(), ".objects-store"), commit, into)
