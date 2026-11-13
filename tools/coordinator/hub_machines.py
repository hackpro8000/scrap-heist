"""Machine connections: admission, the roster, greeting, and every message
and file a machine sends (a part of Coordinator)."""
import asyncio
import hmac
import json
import os
import time
import traceback

import websockets

import oidc
import wire
from hub_config import MAX_SHARD_BYTES, MAX_SHARD_FILES, MAX_WORKERS, REPOSITORY, WORKER_PREFIX, WORKFLOW, say
from units import Machine


class MachineLinks:
	# --- machines ---

	async def agent(self, socket, path=None):
		if self.watchdog is None:
			self.watchdog = asyncio.ensure_future(self.watch_leases())
		record = None
		try:
			hello = json.loads(await asyncio.wait_for(socket.recv(), 30))
			token = hello.get("token", "")
			run, count = None, 0
			if "machine" in hello:
				# A numbered machine: admitted by the token made from the worker key.
				number = hello["machine"]
				good = (self.worker_key and isinstance(number, int) and 1 <= number <= MAX_WORKERS and isinstance(token, str)
					and hmac.compare_digest(token.encode(), (WORKER_PREFIX + wire.machine_token(self.worker_key, number)).encode()))
				if not good:
					raise ValueError("unknown machine token")
				name, kind = f"m{number}", "numbered"
			elif isinstance(token, str) and token.startswith(WORKER_PREFIX):
				# A minted worker: who it is comes from the token, never the hello.
				record = self.worker(token[len(WORKER_PREFIX):]) if len(token) > len(WORKER_PREFIX) else None
				if not record:
					raise ValueError("unknown worker token")
				if record["socket"] is not None and not record["socket"].closed:
					record = None
					raise ValueError("that worker token is already connected")
				record["socket"] = socket
				name, kind = record["name"], "worker"
			else:
				if self.test_without_identity and token == "test":
					claims = {"run_id": "1", "workflow_ref": WORKFLOW}
				else:
					claims = await asyncio.to_thread(oidc.verify, token, REPOSITORY)
				if WORKFLOW not in claims.get("workflow_ref", ""):
					raise ValueError("not a standby machine")
				run, shard, count = str(claims["run_id"]), int(hello["shard"]), int(hello["count"])
				if not 1 <= shard <= MAX_WORKERS:
					raise ValueError(f"shard {shard} out of range")
				name, kind = f"g{shard}", "github"
		except Exception as error:
			say(f"refused a connection: {error}")
			await socket.close(code=4001, reason="not allowed")
			return
		if kind == "github" and not await self.newest_run(run, count):
			await socket.close(code=4002, reason="an older run")
			return
		machine = self.roster.get(name)
		if machine is None:
			machine = self.roster[name] = Machine(name, kind)
		elif machine.socket is not None and not machine.socket.closed and time.time() - machine.heard < self.silent:
			# Two machines under one name would take each other's connection
			# forever; the one already here and heard from keeps it.
			say(f"refused a second connection as {name}: the first is open and was heard {time.time() - machine.heard:.0f}s ago")
			if record and record["socket"] is socket:
				record["socket"] = None
			await socket.close(code=4003, reason="that name is already connected")
			return
		old, machine.socket, machine.run = machine.socket, socket, run
		machine.closed_at, machine.heard = None, time.time()
		if old is not None and not old.closed:
			await old.close(code=4004, reason="connected again")
		try:
			await self.serve_machine(machine, socket, hello)
		finally:
			# Its token may connect again.
			if record and record["socket"] is socket:
				record["socket"] = None

	async def newest_run(self, run, count):
		"""Whether a GitHub machine of `run` may join: not when a newer run
		has. A newer run closes the older one's machines; their units go back."""
		rank = int(run) if run.isdigit() else 0
		if self.run_id is not None and run != self.run_id and rank < self.run_rank:
			return False
		if run == self.run_id:
			return True
		for machine in [machine for machine in self.roster.values() if machine.kind == "github"]:
			if machine.lease:
				task = self.tasks.get(machine.lease[0])
				if task:
					await self.redeal(task, machine.lease[1], "its standby run was replaced by a newer one")
			if machine.socket is not None:
				await machine.socket.close(code=4002, reason="an older run")
			del self.roster[machine.name]
		self.run_id, self.run_rank, self.count, self.run_started = run, rank, count, time.time()
		say(f"standby run {run} with {count} machines")
		return True

	async def greet(self, machine, hello):
		"""A machine that just connected. First the units its hello says it is
		still on: one still queued goes back to it with no cancel (give_back:
		a reconnect after the grace, or a restarted coordinator); any other
		it is told to stop. Then its lease again (a reconnect inside the
		grace), every cancel still owed, and a unit if it is idle."""
		if machine.lease and machine.lease[0] not in self.tasks:
			machine.lease = None
		elif machine.lease:
			await self.send_to(machine, self.unit_message(self.tasks[machine.lease[0]], machine.lease[1]))
		named = hello.get("units") if isinstance(hello.get("units"), list) else []
		for entry in named[:8]:
			if not (isinstance(entry, list) and len(entry) == 2 and isinstance(entry[0], str) and isinstance(entry[1], int)):
				continue
			task_id, shard = entry
			task = self.tasks.get(task_id)
			if machine.lease == (task_id, shard) or (task and task.unit_over(shard)):
				continue
			if task and not machine.lease and shard in task.queue:
				task.queue.remove(shard)
				await self.give_back(machine, task, shard)
				continue
			machine.cancelling[(task_id, shard)] = time.time()
		for task_id, shard in list(machine.cancelling):
			await self.tell_cancel(machine, task_id, shard)
		await self.deal()

	def holding(self, machine, event):
		"""The task, shard and lease a message is about, if this machine holds
		that lease now; else None (a late message from an old holder, or a
		claim naming a lease of this machine's that was cancelled)."""
		task = self.tasks.get(event.get("task")) if isinstance(event.get("task"), str) else None
		shard = event.get("shard")
		lease = task.leases.get(shard) if task and isinstance(shard, int) else None
		number = event.get("lease")
		if lease and lease.machine == machine.name and machine.lease == (task.id, shard) and (number is None or number == lease.number):
			return task, shard, lease
		key = (event.get("task"), shard)
		# The last heartbeat of a unit that is over is no news.
		if task and key not in machine.dropped and not task.unit_over(shard):
			machine.dropped.add(key)
			say(f"task {task.id}: dropping what {machine.name} sends for S{shard}, a unit it does not hold")
		return None

	async def serve_machine(self, machine, socket, hello):
		"""An admitted machine's connection, from its hello to its close."""
		name = machine.name
		if machine.kind == "github":
			self.hosts.add(socket)
		await self.emit(self.machines_event(machine))
		# A worker has no Roblox key; only a GitHub machine 1 uploads.
		if self.uploads_on_machine and name == "g1":
			width = known = None
			if os.path.isfile(self.uploader.width_path):
				try:
					fields = [float(field) for field in open(self.uploader.width_path).read().split()]
					width, known = fields[0], fields[1] if len(fields) > 1 else None
				except (ValueError, IndexError):
					pass
			await socket.send(json.dumps({"type": "uploader", "layout": self.layout, "width": width, "known": known}))
			await self.uploader.connected(socket)
		parts = {}  # big files arriving in parts on this connection (join_part)
		try:
			await self.greet(machine, hello)
			async for message in socket:
				if machine.socket is not socket:
					break
				machine.heard = time.time()
				if isinstance(message, bytes):
					header, data = wire.unpack(message)
					if header.get("type") == "file-part":
						data = self.join_part(parts, header, data)
						if data is None:
							continue
					unit = self.holding(machine, header)
					if unit:
						unit[2].moved = time.time()
						await self.file(unit[0], unit[1], header, data)
					continue
				event = json.loads(message)
				kind = event.get("type")
				if kind == "uploaded" and self.uploads_on_machine:
					self.uploader.answered(event)
					await self.uploaded(event["id"], event.get("asset"), event.get("error"))
					continue
				if kind == "idle":
					if isinstance(event.get("task"), str) and isinstance(event.get("shard"), int):
						machine.cancelling.pop((event["task"], event["shard"]), None)
					await self.deal()
					continue
				if kind == "log":
					held = machine.lease[1] if machine.lease else None
					say(f"{name}: {event.get('text', '')}")
					await self.emit({"type": "log", "machine": name, "shard": held, "text": event.get("text", "")})
					continue
				unit = self.holding(machine, event)
				if not unit:
					if kind == "claim":
						# A stopped unit's engine gets nothing more.
						await socket.send(json.dumps({"type": "claimed", "id": event.get("id"), "job": -1}))
					continue
				task, shard, lease = unit
				if kind != "progress":
					lease.moved = time.time()
				if kind == "done":
					await self.finished_shard(task, shard, event, name)
				elif kind == "preview-ready":
					await self.preview_ready(task, shard, event, lease)
				elif kind == "preview-pushed":
					await self.preview_pushed(task, shard, event, lease)
				elif kind == "previews-done":
					await self.previews_done(task, shard)
				elif kind == "claim":
					await socket.send(json.dumps({"type": "claimed", "id": event["id"], "job": self.next_job(task, lease, event)}))
				elif kind == "bakes-pushed":
					await self.bakes_pushed(task, event, lease, machine)
				elif kind == "progress":
					now = time.time()
					quiet = event.get("quiet") if isinstance(event.get("quiet"), (int, float)) else 0
					lease.moved = max(lease.moved, now - quiet)
					machine.progress = {**event, "heard": now}
					await self.emit({**event, "shard": shard, "machine": name})
		except websockets.ConnectionClosed as closed:
			say(f"{name} closed: {closed}")
		except Exception:
			# Anything else would close the connection without a word.
			say(f"{name} handler failed:\n{traceback.format_exc()}")
		finally:
			if self.uploads_on_machine and self.uploader.agent is socket:
				self.uploader.agent = None
				if self.uploader.pending:
					await self.emit({"type": "warning", "text": f"machine 1 dropped with {len(self.uploader.pending)} uploads unanswered; they go again when it reconnects"})
			self.hosts.discard(socket)
			if machine.socket is socket:
				machine.socket, machine.closed_at = None, time.time()
				say(f"{name} disconnected" + (f"; S{machine.lease[1]} of {machine.lease[0]} comes back after {self.grace:.0f}s unless it reconnects" if machine.lease else ""))
				await self.emit(self.machines_event(machine, gone=True))

	async def file(self, task, shard, header, data):
		raw = header.get("path")
		# A unit re-dealt after its build came in sends only its previews.
		if shard in task.done and not (isinstance(raw, str) and raw.startswith("previews/")):
			return
		folder = os.path.realpath(os.path.join(task.out, f"S{shard}"))
		name = os.path.normpath(raw) if isinstance(raw, str) and raw else ""
		path = os.path.join(folder, name)
		# Whatever the machine names must land inside its own shard folder.
		if (not name or os.path.isabs(name) or ".." in raw.replace("\\", "/").split("/")
				or not os.path.realpath(path).startswith(folder + os.sep)):
			say(f"task {task.id}: S{shard} sent a file outside its folder, dropped: {str(raw)[:80]!r}")
			return
		received = task.received.setdefault(shard, [0, 0])
		if received[0] + 1 > MAX_SHARD_FILES or received[1] + len(data) > MAX_SHARD_BYTES:
			if received[0] <= MAX_SHARD_FILES:
				say(f"task {task.id}: S{shard} went over {MAX_SHARD_FILES} files or {MAX_SHARD_BYTES} bytes; refusing its further files")
			received[0] = MAX_SHARD_FILES + 1
			return
		received[0] += 1
		received[1] += len(data)
		os.makedirs(os.path.dirname(path), exist_ok=True)
		with open(path, "wb") as file:
			file.write(data)
		await self.relay(task, "results", os.path.join(f"S{shard}", name), data)
		if name == os.path.join("handed", "names.tsv"):
			for line in data.decode().splitlines():
				if "\t" in line:
					identity, label = line.split("\t", 1)
					task.labels[(shard, identity)] = label
		elif name == "handed-commit.txt" and task.by_branch and task.upload:
			await self.hand_to_machine_one(task, shard, data.decode().strip())
		elif name.startswith("handed" + os.sep) and name.endswith(".glb") and task.upload:
			identity = os.path.basename(name)[:-4]
			label = task.labels.get((shard, identity), identity)
			if identity not in task.handed:
				task.handed[identity] = (shard, label)
			if self.uploads_on_machine:
				self.uploader.sent_paths[identity] = (identity, path, label, shard)
			if self.uploader.add(identity, path, label, shard):
				task.sent.add(identity)
				say(f"task {task.id}: uploading {label} ({identity}) from S{shard}")
				await self.emit({"type": "uploading", "task": task.id, "object": identity, "label": label, "queued": len(task.sent)})
