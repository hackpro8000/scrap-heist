"""Preview and bake jobs: claims handed out in order, shared bakes, and
renders put beside their models (a part of Coordinator)."""
import asyncio
import hashlib
import json
import os
import shutil
import subprocess

import commits
from hub_config import COMMIT, MODEL_NAME, ROOT, say


class PreviewJobs:
	def settle(self, lease, model):
		"""A lease delivered a model's work (its bakes pushed, or its renders
		in): the jobs it claimed for that model stay done if it is re-dealt."""
		for claim in lease.claims:
			if claim[0][0] == model:
				claim[2] = True

	async def preview_ready(self, task, shard, event, lease=None):
		"""One model's renders are in: put them beside the model (preview.png,
		the four turns as views.png, and the model script's hash in
		previewed.txt, so send-build knows it has a preview) and say so."""
		if not self.preview_model(task, shard, event.get("name")):
			return
		name = event["name"]
		if lease:
			self.settle(lease, name.split("@")[0])
			seconds = event.get("seconds")
			if isinstance(seconds, (int, float)) and not isinstance(seconds, bool) and seconds >= 0:
				# Machine-seconds per model share, for client.py's cost-sized shares.
				await self.emit({"type": "preview-share", "task": task.id, "name": name.split("@")[0], "unit": name,
					"seconds": round(seconds, 1)})
		source = os.path.join(task.out, f"S{shard}", "previews", name)
		if "@" in name:
			# One share of a model's renders: merge it into the model's
			# folder, and carry on once every share is in.
			name, share, shares = name.split("@")
			merged = os.path.join(task.out, "previews", name)
			os.makedirs(merged, exist_ok=True)
			for file in os.listdir(source):
				if file == "build.log":
					shutil.copy(os.path.join(source, file), os.path.join(merged, f"build-{share}.log"))
				else:
					shutil.copy(os.path.join(source, file), os.path.join(merged, file))
			failed = "FAILED" in open(os.path.join(source, "build.log")).read() if os.path.isfile(os.path.join(source, "build.log")) else True
			if failed:
				await self.emit({"type": "preview", "task": task.id, "name": name, "path": f"FAILED, see {os.path.join(source, 'build.log')}"})
			task.shares_in.setdefault(name, set()).add(share)
			if len(task.shares_in[name]) < int(shares):
				return
			source = merged
		model = os.path.join(ROOT, "art", "models", name)
		if not os.path.isfile(os.path.join(source, "preview.png")):
			await self.emit({"type": "preview", "task": task.id, "name": name, "path": f"FAILED, see {os.path.join(source, 'build.log')}"})
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
		await self.emit({"type": "preview", "task": task.id, "name": name, "path": os.path.relpath(shown, ROOT)})

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
				job = task.queues.get(key, 0)
				task.queues[key] = job + 1
				if job >= event["total"]:
					job = -1
			task.job_answers[claim] = job
			if job >= 0:
				lease.claims.append([key, job, False])
		return task.job_answers[claim]

	async def bakes_pushed(self, task, event, lease=None):
		"""A unit has baked its share of a model's textures. Once every share
		has, tells them all which commits to fetch."""
		fields = event.get("share").split("@") if isinstance(event.get("share"), str) else []
		if len(fields) != 3 or not fields[2].isdigit():
			return
		name, share, shares = fields
		if lease:
			self.settle(lease, name)
		pushed = task.bakes.setdefault(name, {})
		# A replacement that had nothing left to bake keeps its predecessor's commit.
		pushed[share] = event.get("commit") or pushed.get(share, "")
		# Every push is announced, so a machine that gives up waiting for a
		# slow peer still takes what has arrived and bakes only the rest.
		message = json.dumps({"type": "bakes-ready", "task": task.id, "name": name, "done": len(pushed) >= int(shares),
			"commits": [commit for commit in pushed.values() if commit]})
		for machine in self.connected():
			await self.send_to(machine, message)  # one that misses it times out and the render bakes the rest

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
