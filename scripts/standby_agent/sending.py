"""Agent mixin: sending on the live connection, heartbeats with each unit's
stage and quiet time, and a unit's result files (big ones in parts)."""
import asyncio
import json
import os
import time

import websockets

from standby_agent.common import HEARTBEAT_SECONDS, PART_BYTES
from standby_agent.machine import free_space, last_line, newest_log
import wire  # noqa: E402


class Sending:
	async def send(self, message):
		"""Sends on whichever connection is live now. session() replaces
		self.socket on every reconnect, so a connection that drops during a
		long render costs a wait, not the result."""
		while True:
			try:
				await self.socket.send(message)
				return
			except websockets.ConnectionClosed:
				await asyncio.sleep(1)

	def begin(self, unit, stage, log, model=""):
		self.activities[unit] = {"stage": stage, "model": model, "log": log, "since": time.monotonic()}

	def moved(self, unit):
		"""A send or a claim made progress: the stage is not quiet, whatever its log says."""
		work = self.activities.get(unit)
		if work:
			work["moved"] = time.monotonic()

	def report(self, unit, work):
		"""One heartbeat: the stage, the log's last line, how long the log
		has gone without a new one (a bake's line comes only when it ends),
		and the machine's free disk and memory. Waiting in the swap for other
		machines' bakes is never quiet: share_bakes bounds that wait itself,
		and a peer's long bake must not get this unit re-dealt as wedged."""
		now = time.monotonic()
		if work["stage"] == "swap":
			work["moved"] = now
		seconds = now - work["since"]
		quiet = min(seconds, now - work.get("moved", work["since"]))
		log = newest_log(work["log"])
		try:
			quiet = min(quiet, time.time() - os.path.getmtime(log))
		except OSError:
			pass
		disk, memory = free_space()
		return json.dumps({"type": "progress", "task": unit[0], "shard": unit[1], "stage": work["stage"], "model": work["model"],
			"line": last_line(log), "quiet": round(quiet), "seconds": round(seconds),
			"disk_gb": disk, "memory_gb": memory})

	async def heartbeat(self, socket):
		try:
			while True:
				await asyncio.sleep(HEARTBEAT_SECONDS)
				for unit, work in list(self.activities.items()):
					await socket.send(self.report(unit, work))
		except websockets.ConnectionClosed:
			pass  # session() ends too; the next connection starts its own

	async def send_results(self, unit, out):
		identity, shard = unit
		files = []
		for directory, _, names in os.walk(out):
			for name in names:
				path = os.path.join(directory, name)
				relative = os.path.relpath(path, out)
				# In branch mode the objects went to GitHub; only results come back.
				# Previews go on their own afterwards (send_previews).
				if relative == "task.txt" or relative.startswith("previews-run") or (self.by_branch.get(identity) and relative.endswith(".glb")):
					continue
				files.append(relative)
		# Names before objects, so the coordinator knows each object's label.
		files.sort(key=lambda path: (not path.endswith("names.tsv"), path))
		self.begin(unit, "send", os.path.join(out, "build.log"))
		for relative in files:
			with open(os.path.join(out, relative), "rb") as file:
				data = file.read()
			await self.send_file(unit, relative, data)
		summary = open(os.path.join(out, "summary.txt")).read() if os.path.isfile(os.path.join(out, "summary.txt")) else "status=FAILED\n"
		await self.send(json.dumps({"type": "done", "task": identity, "shard": shard, "summary": summary}))

	async def send_file(self, unit, relative, data):
		"""One result file. A big one goes in parts, each awaited, so a
		heartbeat waits behind one part, never the whole file; the
		coordinator joins them (Coordinator.join_part). If the connection
		changes midway, the file starts again on the new one."""
		identity, shard = unit
		if len(data) <= PART_BYTES:
			await self.send(wire.pack({"type": "file", "task": identity, "shard": shard, "path": relative, "size": len(data)}, data))
			self.moved(unit)
			return
		while True:
			socket = self.socket
			for offset in range(0, len(data), PART_BYTES):
				await self.send(wire.pack({"type": "file-part", "task": identity, "shard": shard, "path": relative, "offset": offset,
					"size": len(data)}, data[offset:offset + PART_BYTES]))
				self.moved(unit)
				if self.socket is not socket:
					break
			else:
				return
