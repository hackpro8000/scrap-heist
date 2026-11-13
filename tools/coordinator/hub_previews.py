"""Preview and bake jobs: claims handed out in order, shared bakes, and
renders put beside their models (a part of Coordinator)."""
import asyncio
import hashlib
import json
import os
import shutil
import subprocess
import time

import commits
from hub_config import COMMIT, MODEL_NAME, ROOT, say

# What a previews-only unit reports (scripts/standby-task.sh), for one dropped unstarted.
SKIPPED_SUMMARY = "status=DONE\nbuild=-\nupload=skipped\ntotal=0\nparts=0\n"


class PreviewJobs:
	def settle(self, lease, model, kind=None):
		"""A lease delivered a model's work (its bakes pushed, or its renders
		in): the jobs it claimed for that model stay done if it is re-dealt."""
		lease.swapped.add(model)
		for claim in lease.claims:
			if claim[0][0] == model and kind in (None, claim[0][1]):
				claim[2] = True

	@staticmethod
	def jobs_in(task, key):
		"""Whether every job of a model's kind, (model, "bake" or "render"),
		is handed out and delivered: none left to claim, none returned by a
		lost lease, none claimed by a live lease and not yet settled. False
		until a claim has said how many jobs there are."""
		total = task.totals.get(key)
		return (total is not None and task.queues.get(key, 0) >= total and not task.returned.get(key)
			and not any(claim[0] == key and not claim[2] for lease in task.leases.values() for claim in lease.claims))

	async def preview_ready(self, task, shard, event, lease=None):
		"""One model's renders are in: put them beside the model (publish).
		A share's are merged into the model's folder first, and the model is
		published as soon as every render job is in (jobs_in), not when every
		share is: shares that made no render add nothing, so the ones still
		painting are stopped (skip_shares)."""
		if not self.preview_model(task, shard, event.get("name")):
			return
		name = event["name"]
		model = name.split("@")[0]
		seconds = event.get("seconds")
		if lease and isinstance(seconds, (int, float)) and not isinstance(seconds, bool) and seconds >= 0:
			# Machine-seconds per model share, for client.py's cost-sized shares.
			await self.emit({"type": "preview-share", "task": task.id, "name": model, "unit": name, "seconds": round(seconds, 1)})
		source = os.path.join(task.out, f"S{shard}", "previews", name)
		if "@" not in name:
			if lease:
				self.settle(lease, model)
			await self.publish(task, name, source)
			return
		# One share of a model's renders: merged with no await up to the
		# settle, so no other share can count this one's jobs in before its files are.
		_, share, shares = name.split("@")
		merged = os.path.join(task.out, "previews", model)
		os.makedirs(merged, exist_ok=True)
		for file in os.listdir(source):
			if file == "build.log":
				shutil.copy(os.path.join(source, file), os.path.join(merged, f"build-{share}.log"))
			else:
				shutil.copy(os.path.join(source, file), os.path.join(merged, file))
		failed = "FAILED" in open(os.path.join(source, "build.log")).read() if os.path.isfile(os.path.join(source, "build.log")) else True
		task.shares_in.setdefault(model, set()).add(share)
		if lease:
			self.settle(lease, model)
		if failed:
			await self.emit({"type": "preview", "task": task.id, "name": model, "path": f"FAILED, see {os.path.join(source, 'build.log')}"})
		every_share = len(task.shares_in[model]) >= int(shares)
		if model in task.published or not (every_share or self.jobs_in(task, (model, "render"))):
			return
		task.published.add(model)
		await self.skip_shares(task, model)
		await self.publish(task, model, merged)

	async def skip_shares(self, task, model):
		"""A model's preview is complete, so its shares not yet in have
		nothing to add. One a machine is still painting is cancelled (the
		machine answers idle and takes other work); one still queued is
		dropped, or, if it has a build to do, keeps that and loses its preview."""
		for shard in sorted(task.previews_waiting):
			unit = task.units[shard - 1] if task.share_model(shard) == model else ""
			if not unit or unit.split("@")[1] in task.shares_in.get(model, ()):
				continue
			lease = task.leases.get(shard)
			if lease and shard in task.done:
				del task.leases[shard]
				machine = self.roster.get(lease.machine)
				if machine and machine.lease == (task.id, shard):
					machine.lease = None
					await self.tell_cancel(machine, task.id, shard)
				spent = round(time.time() - lease.dealt, 1)
				say(f"task {task.id}: S{shard} stopped on {lease.machine} after {spent}s: every render of {model} is in")
				if not task.build:
					# What it cost all the same, so the shares' seconds stay comparable.
					await self.emit({"type": "preview-share", "task": task.id, "name": model, "unit": unit, "seconds": spent})
				await self.emit({"type": "progress", "task": task.id, "shard": shard, "machine": lease.machine, "stage": "done",
					"model": "", "line": "", "quiet": 0, "seconds": round(spent)})
			elif lease or shard not in task.queue:
				continue  # still building: left alone
			elif shard in task.done or not task.build:
				task.queue.remove(shard)
				task.moved_from.pop(shard, None)
				say(f"task {task.id}: S{shard} dropped unstarted: every render of {model} is in")
			else:
				task.skipped.add(shard)
			task.previews_waiting.discard(shard)
			await self.emit({"type": "previews-done", "task": task.id, "shard": shard, "left": len(task.previews_waiting)})
			if shard not in task.done and shard not in task.skipped:
				await self.finished_shard(task, shard, {"summary": SKIPPED_SUMMARY}, "-")
		self.save_tasks()
		if not task.previews_waiting and getattr(task, "completed", False):
			self.tasks.pop(task.id, None)
		await self.deal()

	async def publish(self, task, name, source):
		"""Puts a model's renders beside it (preview.png, the four turns as
		views.png, and the model script's hash in previewed.txt, so
		send-build knows it has a preview) and says so."""
		model = os.path.join(ROOT, "art", "models", name)
		if not os.path.isfile(os.path.join(source, "preview.png")):
			task.shown[name] = f"FAILED, see {os.path.join(source, 'build.log')}"
			await self.emit({"type": "preview", "task": task.id, "name": name, "path": task.shown[name]})
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
		task.shown[name] = os.path.relpath(shown, ROOT)
		await self.emit({"type": "preview", "task": task.id, "name": name, "path": task.shown[name]})

	async def replay_previews(self, task, socket):
		"""For a session that comes back to a task (watch-task): what it may
		have missed while its connection was down. Every preview published so
		far, stored files and event, and every unit that is over, so it
		neither waits for nor reports as stalled what already ended."""
		for name, path in list(task.shown.items()):
			model = os.path.join(ROOT, "art", "models", name)
			for stored in ("preview.png", "views.png", "previewed.txt"):
				if not path.startswith("FAILED") and os.path.isfile(os.path.join(model, stored)):
					await self.relay(task, "repo", os.path.relpath(os.path.join(model, stored), ROOT), to=socket)
			await socket.send(json.dumps({"type": "preview", "task": task.id, "name": name, "path": path}))
		for shard in range(1, task.count + 1):
			if task.unit_over(shard):
				await socket.send(json.dumps({"type": "progress", "task": task.id, "shard": shard, "machine": "", "stage": "done",
					"model": "", "line": "", "quiet": 0, "seconds": 0}))

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
				task.totals[key] = event["total"]
				job = task.queues.get(key, 0)
				task.queues[key] = job + 1
				if job >= event["total"]:
					job = -1
			task.job_answers[claim] = job
			if job >= 0:
				lease.claims.append([key, job, False])
		return task.job_answers[claim]

	def bakes_done(self, task, model):
		"""Whether a model's swap is over: every chunk has been claimed and
		every claimed chunk pushed by its baker. Shares that claimed nothing
		are not waited for, started or not. A chunk a lost lease gave back is
		waited for only while a live lease of this model has yet to hand over
		its bakes, since that one claims it next (or a share of it is queued
		with an idle machine about to be dealt it); with none, the machines
		in the swap carry on and bake it themselves."""
		key = (model, "bake")
		if self.jobs_in(task, key):
			return True
		total = task.totals.get(key)
		if (total is None or task.queues.get(key, 0) < total
				or any(claim[0] == key and not claim[2] for lease in task.leases.values() for claim in lease.claims)):
			return False
		if any(task.share_model(shard) == model and model not in lease.swapped for shard, lease in task.leases.items()):
			return False
		idle = any(machine.socket is not None and not machine.lease and not machine.cancelling for machine in self.roster.values())
		return not (idle and task.held_until <= time.time() and any(task.share_model(shard) == model for shard in task.queue))

	async def announce_bakes(self, task, model, only=None):
		"""Tells the machines (or only one) which commits hold a model's
		bakes, and whether the swap is over (bakes_done)."""
		message = json.dumps({"type": "bakes-ready", "task": task.id, "name": model, "done": self.bakes_done(task, model),
			"commits": task.bake_commits.get(model, [])})
		for machine in [only] if only else self.connected():
			await self.send_to(machine, message)

	async def bakes_pushed(self, task, event, lease=None, machine=None):
		"""A unit has baked the chunks it claimed of a model's textures and
		pushed them. Told to every machine, with whether the swap is over. A
		machine waiting in the swap sends this again every few seconds, and
		is answered alone, so a lost answer costs seconds, not the swap."""
		fields = event.get("share").split("@") if isinstance(event.get("share"), str) else []
		if len(fields) != 3 or not fields[2].isdigit():
			return
		name, share, _shares = fields
		commit = event.get("commit") if isinstance(event.get("commit"), str) else ""
		commits = task.bake_commits.setdefault(name, [])
		again = bool(lease and name in lease.swapped and (not commit or commit in commits))
		if lease:
			self.settle(lease, name, "bake")
		pushed = task.bakes.setdefault(name, {})
		# A replacement that had nothing left to bake keeps its predecessor's commit.
		pushed[share] = commit or pushed.get(share, "")
		if commit and commit not in commits:
			commits.append(commit)
		await self.announce_bakes(task, name, machine if again else None)

	async def claims_returned(self, task, lease):
		"""A lease was taken back (redeal): the swaps it was holding up may be
		over now, for want of anyone to bake the chunks it gave back."""
		models = {key[0] for key, _job, _settled in lease.claims if key[1] == "bake"}
		models |= {key[0] for key, jobs in task.returned.items() if key[1] == "bake" and jobs}
		for model in sorted(models):
			if self.bakes_done(task, model):
				await self.announce_bakes(task, model)

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
