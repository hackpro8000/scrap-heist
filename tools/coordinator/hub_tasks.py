"""Tasks from post to finish: the tasks file, uploads answered, events to
the session, relayed files, completion and merge, and the git link (a part of Coordinator)."""
import asyncio
import json
import os
import subprocess
import tempfile
import time

import wire
from hub_config import KEEP_FINISHED, LINK_INTERVAL, LINK_RESULTS, MAX_WORKERS, ROOT, TASK_NAME, say
from units import Task


class TaskBook:
	def save_tasks(self):
		"""Writes the tasks not yet completed to the tasks file, with the
		units already done, so a restart does not build them again."""
		open_tasks = {task.id: {"ref": task.ref, "upload": task.upload, "previews": task.asked, "build": task.build,
			"count": task.count, "weights": task.weights, "done": {str(shard): summary for shard, summary in task.done.items()},
			"previews_waiting": sorted(task.previews_waiting)}
			for task in self.tasks.values() if not getattr(task, "completed", False)}
		os.makedirs(os.path.dirname(self.tasks_file), exist_ok=True)
		with open(self.tasks_file + ".new", "w") as file:
			json.dump(open_tasks, file)
		os.replace(self.tasks_file + ".new", self.tasks_file)

	def load_tasks(self):
		"""Takes back the tasks a previous coordinator left open, every unit
		not over queued but held for restart_hold: a machine that reconnects
		names the units it is still on and gets them back (greet) before any
		is dealt. Never raises: a bad file or entry is logged and skipped."""
		try:
			if not os.path.isfile(self.tasks_file):
				return
			open_tasks = json.load(open(self.tasks_file))
			if not isinstance(open_tasks, dict):
				say(f"ignoring a tasks file that is not an object: {type(open_tasks).__name__}")
				return
			for identity, fields in open_tasks.items():
				if not self.task_entry_fits(identity, fields):
					say(f"skipping a bad tasks file entry: {str(identity)[:40]!r}")
					continue
				task = Task(identity, fields["ref"], fields["upload"], fields["count"], fields.get("previews", []), fields.get("build", True),
					fields.get("weights"), self.results)
				task.by_branch = self.uploads_on_machine
				for shard, summary in (fields.get("done") or {}).items():
					if str(shard).isdigit() and 1 <= int(shard) <= task.count and isinstance(summary, str):
						task.done[int(shard)] = summary
				waiting = fields.get("previews_waiting")
				if task.previews and isinstance(waiting, list):
					task.previews_waiting = {shard for shard in waiting if isinstance(shard, int) and 1 <= shard <= task.count}
				task.queue = [shard for shard in task.queue if not task.unit_over(shard)]
				task.held_until = time.time() + self.restart_hold
				self.tasks[identity] = task
				say(f"task {identity} taken back from the tasks file, {len(task.done)} of {task.count} units done")
		except Exception as error:
			say(f"ignoring an unreadable tasks file: {error}")

	@staticmethod
	def task_entry_fits(identity, fields):
		"""Whether a tasks file entry has the shape save_tasks writes."""
		return (TASK_NAME.fullmatch(identity) is not None and isinstance(fields, dict)
			and isinstance(fields.get("ref"), str) and isinstance(fields.get("upload"), bool)
			and isinstance(fields.get("count"), int) and not isinstance(fields.get("count"), bool) and fields["count"] >= 1
			and isinstance(fields.get("previews", []), list) and all(isinstance(name, str) for name in fields.get("previews", []))
			and isinstance(fields.get("build", True), bool) and isinstance(fields.get("weights") or {}, dict)
			and isinstance(fields.get("done") or {}, dict) and isinstance(fields.get("previews_waiting") or [], list))

	async def hand_to_machine_one(self, task, shard, commit):
		"""A builder pushed its objects to its branch: queue them and tell
		machine 1 to fetch that commit and upload them."""
		wanted = {}
		for (from_shard, identity), label in task.labels.items():
			if from_shard != shard:
				continue
			if identity not in task.handed:
				task.handed[identity] = (shard, label)
			if self.uploader.track(identity):
				task.sent.add(identity)
				wanted[identity] = label
		if not wanted:
			return
		say(f"task {task.id}: S{shard} pushed {len(wanted)} objects at {commit[:8]}; machine 1 fetches them")
		await self.emit({"type": "uploading", "task": task.id, "shard": shard, "count": len(wanted), "queued": len(task.sent)})
		await self.uploader.request_fetch({"type": "fetch-objects", "task": task.id, "shard": shard, "commit": commit, "ids": wanted})

	def local_answer(self, identity, asset, error):
		"""From the local uploader's threads."""
		if self.loop:
			self.loop.call_soon_threadsafe(lambda: asyncio.ensure_future(self.uploaded(identity, asset, error)))

	async def uploaded(self, identity, asset, error):
		if error:
			say(f"upload of {identity} failed: {error}")
		for task in self.tasks.values():
			# Once per object: machine 1 answers again for one handed over twice.
			if identity in task.handed and identity not in task.answered:
				task.answered.add(identity)
				await self.emit({"type": "uploaded", "task": task.id, "object": identity, "label": task.handed[identity][1],
					"asset": asset, "error": error, "done": len(task.answered), "of": len(task.sent)})

	async def emit(self, event):
		message = json.dumps(event)
		for watcher in list(self.watchers):
			try:
				await watcher.send(message)
			except Exception:
				self.watchers.discard(watcher)

	async def relay(self, task, root, path, data=None, to=None):
		"""With --relay-results, sends one stored file to the task's session
		(or only to the socket `to`). root is "results" (path under task.out)
		or "repo" (path under ROOT)."""
		if not self.relay_results or path.endswith(".glb"):
			return
		if data is None:
			with open(os.path.join(task.out if root == "results" else ROOT, path), "rb") as file:
				data = file.read()
		message = wire.pack({"type": "result-file", "task": task.id, "root": root, "path": path}, data)
		for watcher in [to] if to else list(task.watchers):
			try:
				await watcher.send(message)
			except Exception:
				task.watchers.discard(watcher)

	async def finished_shard(self, task, shard, event, machine=""):
		if shard in task.done:
			return
		summary = event.get("summary", "")
		task.done[shard] = summary if isinstance(summary, str) else ""
		self.save_tasks()
		say(f"task {task.id}: S{shard} done by {machine} ({len(task.done)} of {task.count}): {task.done[shard].strip().replace(chr(10), ' ')}")
		await self.emit({"type": "shard", "task": task.id, "shard": shard, "machine": machine, "summary": task.done[shard],
			"seconds": round(time.time() - task.started)})
		await self.keep_hosts_awake()
		if len(task.done) >= task.count:
			asyncio.create_task(self.complete(task))
		await self.unit_over(task, shard)

	async def complete(self, task):
		built = time.time() - task.started
		if self.uploads_on_machine:
			await self.uploader.wait_async(list(task.handed))
		else:
			await asyncio.to_thread(self.uploader.wait, list(task.handed))
		self.uploader.finish()
		failed = {i: e for i, e in self.uploader.failed.items() if i in task.handed}
		with open(os.path.join(task.out, "uploaded.tsv"), "w") as file:
			for identity, (shard, _label) in task.handed.items():
				asset = self.uploader.asset_of(identity)
				if asset:
					file.write(f"{identity}\t{asset}\t{shard}\n")
		with open(os.path.join(task.out, "summary.txt"), "w") as file:
			file.write(f"built={round(built)}\ntotal={round(time.time() - task.started)}\nobjects={len(task.handed)}\n"
				f"uploaded={len(task.sent & set(self.uploader.record))}\nfailed={len(failed)}\n")
		if self.git_link:
			await asyncio.to_thread(self.push_results, task)
		await self.relay(task, "results", "uploaded.tsv")
		await self.relay(task, "results", "summary.txt")
		merged = None
		# Fake uploads must never reach the game's tables.
		mergeable = task.upload and not failed and not self.dry and not self.test_without_identity
		if mergeable and not self.git_link and not self.relay_results:
			merged = await asyncio.to_thread(self.merge, task)
		# Relayed: the session has the files and merges them itself (merge_here).
		event = {"type": "finished", "task": task.id, "out": task.out, "built": round(built),
			"total": round(time.time() - task.started), "objects": len(task.handed), "uploaded": len(task.sent & set(self.uploader.record)), "failed": failed,
			"width": round(self.uploader.throttle.limit, 1), "merged": merged, "previews_waiting": len(task.previews_waiting),
			"relayed": self.relay_results, "merge_here": bool(mergeable and self.relay_results), "layout": self.layout}
		self.finished[task.id] = (task, event)
		for old in list(self.finished)[:-KEEP_FINISHED]:
			del self.finished[old]
		await self.emit(event)
		# Kept while previews are still to come; previews_done lets it go.
		task.completed = True
		self.save_tasks()
		if not task.previews_waiting:
			self.tasks.pop(task.id, None)

	def merge(self, task):
		"""Merges a finished task into the game's tables (scripts/merge-shards.sh)
		and returns the asset ids that are new, which need the game's
		permission; or the merge's error."""
		shards = sorted(os.path.join(task.out, name) for name in os.listdir(task.out) if name.startswith("S"))
		result = subprocess.run(["scripts/merge-shards.sh", self.layout, *shards], cwd=ROOT, capture_output=True, text=True)
		if result.returncode != 0:
			say(f"task {task.id}: merge failed: {result.stderr.strip()[-300:]}")
			return {"error": result.stderr.strip()[-300:]}
		new = [line for line in result.stdout.split() if line.isdigit()]
		say(f"task {task.id}: merged; {len(new)} new assets need the game's permission")
		return {"new_assets": new}

	async def post(self, identity, ref, upload, previews=(), build=True, units=None, weights=None):
		"""Cuts a task into units (as many as machines are connected, unless
		asked) and queues them; the caller deals them (deal) once the session
		knows the task's id."""
		count = units if isinstance(units, int) and not isinstance(units, bool) and 1 <= units <= MAX_WORKERS * 4 else max(1, len(self.connected()))
		task = Task(identity, ref, upload, count, previews, build, weights, self.results)
		task.by_branch = self.uploads_on_machine
		self.tasks[identity] = task
		self.save_tasks()
		await self.keep_hosts_awake()
		say(f"task {identity}: {count} units for {len(self.connected())} machines" + (f", previews {','.join(task.units)}" if task.units else ""))
		return task

	# --- a session reached through git (--git-link) ---

	def git(self, *arguments, **options):
		return subprocess.run(["git", *arguments], cwd=ROOT, capture_output=True, text=True, **options)

	async def link(self):
		"""Takes tasks posted to build-queue since this coordinator started."""
		since, seen, taken = int(time.time()), "", set()
		while True:
			head = (await asyncio.to_thread(self.git, "ls-remote", "origin", "refs/heads/build-queue")).stdout.split("\t")[0]
			if head and head != seen and self.roster:
				fetched = await asyncio.to_thread(self.git, "fetch", "-q", "--depth=1", "origin", head)
				if fetched.returncode == 0:
					seen = head
					files = (await asyncio.to_thread(self.git, "ls-tree", "--name-only", head, "tasks/")).stdout.split()
					for name in sorted(files):
						identity = os.path.basename(name)[:-4]
						posted = identity[1:].split("-")[0]
						if identity in taken or not posted.isdigit() or int(posted) < since:
							continue
						taken.add(identity)
						text = (await asyncio.to_thread(self.git, "show", f"{head}:{name}")).stdout
						fields = dict(line.split("=", 1) for line in text.splitlines() if "=" in line)
						if "ref" in fields and "upload-of" not in fields:
							say(f"task {identity} from the build-queue branch")
							await self.post(identity, fields["ref"], fields.get("upload") != "no")
							await self.deal()
			await asyncio.sleep(LINK_INTERVAL)

	def push_results(self, task):
		"""One commit on build-results/coordinator with the task's results,
		objects left out, through a temporary index."""
		index = tempfile.mktemp()
		environment = {**os.environ, "GIT_INDEX_FILE": index}
		for directory, _, names in os.walk(task.out):
			for name in names:
				if name.endswith(".glb"):
					continue
				path = os.path.join(directory, name)
				blob = self.git("hash-object", "-w", path).stdout.strip()
				relative = os.path.relpath(path, task.out)
				self.git("update-index", "--add", "--cacheinfo", f"100644,{blob},{relative}", env=environment)
		tree = self.git("write-tree", env=environment).stdout.strip()
		if os.path.exists(index):
			os.remove(index)
		parent = []
		if self.git("fetch", "-q", "--depth=1", "origin", f"refs/heads/{LINK_RESULTS}").returncode == 0:
			parent = ["-p", self.git("rev-parse", "FETCH_HEAD").stdout.strip()]
		commit = self.git("commit-tree", tree, *parent, "-m", f"task {task.id}").stdout.strip()
		pushed = self.git("push", "-q", "origin", f"{commit}:refs/heads/{LINK_RESULTS}")
		say(f"task {task.id}: results pushed" if pushed.returncode == 0 else f"task {task.id}: push failed {pushed.stderr}")
