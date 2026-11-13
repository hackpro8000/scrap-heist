"""Agent mixin: a leased unit's life: taking it, running its build through
scripts/standby-task.sh, handling it to the end, and cancelling it."""
import asyncio
import json
import os
import shutil
import subprocess
import time

from standby_agent.common import say
from standby_agent.machine import kill_tree


class Units:
	@staticmethod
	def run_process(work, command, **options):
		"""Runs one of a unit's processes in its own session, so cancel() can
		kill it with everything under it. Returns (exit code, stdout)."""
		if work["cancelled"]:
			return -9, ""
		process = subprocess.Popen(command, start_new_session=True, **options)
		work["processes"].add(process)
		try:
			output, _ = process.communicate()
		finally:
			work["processes"].discard(process)
		return process.returncode, output or ""

	def run_task(self, unit, text, count, out, work):
		identity, shard = unit
		# A unit starts clean, whatever an earlier try of it left.
		shutil.rmtree(out, ignore_errors=True)
		os.makedirs(out, exist_ok=True)
		with open(os.path.join(out, "task.txt"), "w") as file:
			file.write(text)
		ref = next((line[4:] for line in text.splitlines() if line.startswith("ref=")), "")
		log = open(os.path.join(out, "build.log"), "w")
		work["checkout"] = True
		ok = self.run_process(work, ["git", "fetch", "-q", "--depth=1", "origin", ref], stdout=log, stderr=log)[0] == 0
		ok = ok and self.run_process(work, ["git", "checkout", "-q", "-f", "FETCH_HEAD"], stdout=log, stderr=log)[0] == 0
		work["checkout"] = False
		log.close()
		if ok:
			code, output = self.run_process(work, ["scripts/standby-task.sh", self.layout, str(shard), str(count), out],
				stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
			say(f"task {identity} S{shard}: {output.strip()}")
		else:
			with open(os.path.join(out, "summary.txt"), "w") as file:
				file.write("status=FAILED\nbuild=-\nupload=-\ntotal=0\nparts=0\n")
			say(f"task {identity} S{shard}: could not check out {ref}")
		return out

	def take(self, event):
		"""A unit leased by the coordinator. One already under way (sent again
		after a reconnect) carries on, under the lease number it is sent now,
		and answers on the new connection. One whose cancel is still running
		starts once the cancel is over."""
		unit = (event["id"], event["shard"])
		stopping = self.cancelling.get(unit)
		if stopping:
			asyncio.create_task(self.take_after(stopping, event))
			return
		if unit in self.handling:
			if unit in self.units:
				self.units[unit]["lease"] = event.get("lease")
			return
		self.handling.add(unit)
		work = self.units[unit] = {"cancelled": False, "processes": set(), "lease": event.get("lease")}
		work["task"] = asyncio.create_task(self.handle(unit, event["task"], event["count"], work))

	async def take_after(self, stopping, event):
		# wait(), not await: this waiter's own end must not cancel the cancel.
		await asyncio.wait({stopping})
		self.take(event)

	def stop_unit(self, event):
		"""A cancel from the coordinator, run beside the connection's reading
		and kept in self.cancelling until it is over, so take() can wait for it."""
		unit = (event.get("task"), event.get("shard"))
		if not isinstance(unit[0], str) or not isinstance(unit[1], int) or unit in self.cancelling:
			return
		stopping = self.cancelling[unit] = asyncio.create_task(self.cancel(event))
		stopping.add_done_callback(lambda done: self.cancelling.pop(unit, None) if self.cancelling.get(unit) is done else None)

	async def cancel(self, event):
		"""The coordinator took a unit back: kill its processes, drop what it
		made, and say this machine is idle. Answered even for a unit this
		machine never had (it may have restarted since)."""
		unit = (event.get("task"), event.get("shard"))
		work = self.units.get(unit)
		if work:
			work["cancelled"] = True
			for process in list(work["processes"]):
				kill_tree(process.pid)
			running = work.get("task")
			if running and not running.done():
				running.cancel()
				try:
					await running
				except BaseException:
					pass
			if work.get("checkout") and os.path.exists(os.path.join(".git", "index.lock")):
				# A checkout killed midway leaves its lock; the next unit's would fail.
				os.remove(os.path.join(".git", "index.lock"))
			say(f"task {unit[0]} S{unit[1]}: cancelled by the coordinator")
		self.handling.discard(unit)
		self.activities.pop(unit, None)
		if self.units.get(unit) is work:
			self.units.pop(unit, None)
		out = self.built.pop(unit, None) or os.path.join("results", f"{unit[0]}-S{unit[1]}")
		if isinstance(unit[0], str) and isinstance(unit[1], int):
			shutil.rmtree(out, ignore_errors=True)
		await self.send(json.dumps({"type": "idle", "task": unit[0], "shard": unit[1]}))
		self.update_if_due()

	async def handle(self, unit, text, count, work):
		identity, shard = unit
		self.idle_until = time.monotonic() + self.idle_seconds
		self.by_branch[identity] = "hand-over=branch" in text
		try:
			if unit not in self.built:
				out = os.path.join("results", f"{identity}-S{shard}")
				self.begin(unit, "build", os.path.join(out, "build.log"))
				try:
					self.built[unit] = await asyncio.to_thread(self.run_task, unit, text, count, out, work)
				except Exception as error:
					# A full disk, say: the coordinator must still hear this unit is over.
					say(f"task {identity} S{shard}: could not run: {error}")
					await self.send(json.dumps({"type": "done", "task": identity, "shard": shard,
						"summary": "status=FAILED\nbuild=-\nupload=-\ntotal=0\nparts=0\n"}))
					return
			if work["cancelled"]:
				return
			await self.send_results(unit, self.built[unit])
			self.idle_until = time.monotonic() + self.idle_seconds
			await self.send_previews(unit, text, count, work)
		finally:
			self.activities.pop(unit, None)
			self.handling.discard(unit)
			if self.units.get(unit) is work:
				self.units.pop(unit, None)
			# Also on the early returns above; a no-op if the call below already started it.
			asyncio.get_running_loop().call_soon(self.update_if_due)
		await self.send(json.dumps({"type": "progress", "task": identity, "shard": shard, "stage": "done", "model": "", "line": "", "quiet": 0, "seconds": 0}))
		# A hot update waits for the unit to end (update.py).
		self.update_if_due()
