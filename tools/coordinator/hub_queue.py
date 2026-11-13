"""The pull queue: dealing units to idle machines, leases, taking them
back and dealing them again (a part of Coordinator)."""
import asyncio
import json
import os
import shutil
import time
import traceback

from hub_config import GONE_FORGOTTEN_SECONDS, say
from units import Lease


class LeaseQueue:
	# --- the queue ---

	async def send_to(self, machine, message):
		"""Sends to a machine if it is connected; a dropped one hears it again
		when it reconnects (its lease, its cancels)."""
		if machine.socket is None:
			return
		try:
			await machine.socket.send(message)
		except Exception:
			pass

	def unit_message(self, task, shard):
		# The lease number comes back in claims, so a cancelled lease's late claim is refused (holding).
		lease = task.leases.get(shard)
		if task.engine:
			return task.message(shard, lease)
		return json.dumps({"type": "task", "id": task.id, "task": task.text(shard), "shard": shard, "count": task.count,
			"lease": lease.number if lease else 0})

	async def tell_cancel(self, machine, task_id, shard):
		machine.cancelling[(task_id, shard)] = time.time()
		await self.send_to(machine, json.dumps({"type": "cancel", "task": task_id, "shard": shard}))

	async def deal(self):
		"""Leases the front queued unit of the oldest open task to each idle
		machine. Idle: connected, holding nothing, and every cancel answered.
		A task reloaded after a restart waits out its hold. Engine checks go
		first, to machines with cargo (hub_engine); a machine on other code
		than the hub's is dealt nothing until it updates (hub_update)."""
		await self.deal_engine()
		now = time.time()
		for machine in list(self.roster.values()):
			if machine.socket is None or machine.lease or machine.cancelling or self.stale(machine):
				continue
			task = next((task for task in self.tasks.values() if task.queue and task.held_until <= now and not task.engine), None)
			if not task:
				return
			await self.grant(machine, task, task.queue.pop(0))

	async def grant(self, machine, task, shard):
		"""A new lease of a unit already taken off the queue. A unit taken
		back from a machine starts clean here, when it is dealt again."""
		moved = task.moved_from.pop(shard, None)
		if moved and shard not in task.done:
			try:
				self.clear_unit(task, shard, moved[2].number)
			except Exception:
				# Left in place rather than lose the unit.
				say(f"task {task.id}: could not move S{shard}'s old results aside:\n{traceback.format_exc()}")
		self.leases_made += 1
		lease = Lease(self.leases_made, machine.name)
		# Leased before anything is awaited: a unit is never seen neither queued
		# nor leased (a swap asks who may still bake, hub_previews.bakes_done).
		await self.lease_to(machine, task, shard, lease)
		if moved:
			say(f"task {task.id}: S{shard} re-dealt from {moved[0]} to {machine.name}: {moved[1]}")
			await self.emit({"type": "redealt", "task": task.id, "shard": shard, "from": moved[0], "to": machine.name, "reason": moved[1]})

	async def lease_to(self, machine, task, shard, lease):
		task.leases[shard] = lease
		machine.lease = (task.id, shard)
		machine.dropped.discard((task.id, shard))
		# A unit it was told to stop and now holds again is owed no cancel.
		machine.cancelling.pop((task.id, shard), None)
		await self.send_to(machine, self.unit_message(task, shard))

	async def give_back(self, machine, task, shard):
		"""A machine reconnected still on a queued unit (its lease taken back
		after the grace, or the hub restarted): it keeps the unit, with no
		cancel. Its own returned lease comes back whole, claims and all."""
		moved = task.moved_from.get(shard)
		if not moved or moved[0] != machine.name:
			say(f"task {task.id}: {machine.name} is still on S{shard}; it keeps it")
			await self.grant(machine, task, shard)
			return
		del task.moved_from[shard]
		lease = moved[2]
		for key, job, settled in lease.claims:
			if not settled and job in task.returned.get(key, []):
				task.returned[key].remove(job)
		lease.moved = time.time()
		say(f"task {task.id}: {machine.name} came back still on S{shard}; its lease is given back")
		await self.lease_to(machine, task, shard, lease)

	async def unit_over(self, task, shard):
		"""Once a unit's build and previews are in, its machine is idle."""
		if not task.unit_over(shard):
			return
		lease = task.leases.pop(shard, None)
		if not lease:
			return
		machine = self.roster.get(lease.machine)
		if machine and machine.lease == (task.id, shard):
			machine.lease = None
		await self.emit({"type": "progress", "task": task.id, "shard": shard, "machine": lease.machine, "stage": "done",
			"model": "", "line": "", "quiet": 0, "seconds": round(time.time() - lease.dealt)})
		await self.deal()

	def lease_lost(self, machine, lease, now):
		"""Why a lease goes back to the queue now, or None while it holds."""
		if machine is None:
			return "its machine left the roster"
		if machine.socket is None:
			gone = now - (machine.closed_at or now)
			return f"connection closed for {gone:.0f}s" if gone >= self.grace else None
		heard = now - max(machine.heard, lease.dealt)
		if heard >= self.silent:
			return f"no heartbeat for {heard:.0f}s"
		quiet = now - lease.moved
		if quiet >= self.wedged:
			return f"wedged: its log quiet for {quiet:.0f}s"
		return None

	async def redeal(self, task, shard, reason):
		"""Puts a leased unit back at the front of the queue, tells its old
		holder to stop, and deals it again."""
		lease = task.leases.pop(shard, None)
		if not lease:
			return
		# Queued first, so nothing below can leave it neither queued nor leased.
		# Its folder is cleared when it is dealt again (grant), not here: its
		# machine may come back for it (give_back).
		task.queue.insert(0, shard)
		task.moved_from[shard] = (lease.machine, reason, lease)
		# Jobs it claimed and never delivered go to whoever claims next.
		for key, job, settled in lease.claims:
			if not settled:
				task.returned.setdefault(key, []).append(job)
				task.returned[key].sort()
		machine = self.roster.get(lease.machine)
		if machine and machine.lease == (task.id, shard):
			machine.lease = None
			await self.tell_cancel(machine, task.id, shard)
		say(f"task {task.id}: S{shard} taken back from {lease.machine}: {reason}")
		await self.deal()
		# After the deal: a replacement already leased is waited for (bakes_done).
		await self.claims_returned(task, lease)

	def clear_unit(self, task, shard, lease_number):
		"""A re-dealt unit starts clean: what its folder holds moves aside to
		.redealt/ (merge-shards.sh reads only S*, the relay skips dot folders).
		The objects stay: the uploader may be reading them, and the
		replacement hands over the same ones under the same ids."""
		folder = os.path.join(task.out, f"S{shard}")
		task.received.pop(shard, None)
		for key in [key for key in task.labels if key[0] == shard]:
			del task.labels[key]
		if not os.path.isdir(folder):
			return
		aside = os.path.join(task.out, ".redealt", f"S{shard}-L{lease_number}")
		os.makedirs(aside, exist_ok=True)
		for entry in os.listdir(folder):
			if entry != "handed":
				shutil.move(os.path.join(folder, entry), os.path.join(aside, entry))
				continue
			handed = os.path.join(folder, entry)
			for name in os.listdir(handed):
				if not name.endswith(".glb"):
					os.makedirs(os.path.join(aside, entry), exist_ok=True)
					shutil.move(os.path.join(handed, name), os.path.join(aside, entry, name))

	async def watch_leases(self):
		"""Takes back leases whose machines are gone, silent or wedged, drops
		cancels never answered, ends restart holds, and forgets machines long
		gone that hold nothing."""
		while True:
			await asyncio.sleep(self.tick)
			try:
				now = time.time()
				freed = False
				for task in list(self.tasks.values()):
					for shard, lease in list(task.leases.items()):
						reason = self.lease_lost(self.roster.get(lease.machine), lease, now)
						if reason:
							await self.redeal(task, shard, reason)
					if task.held_until and now >= task.held_until:
						task.held_until, freed = 0, True
				for machine in list(self.roster.values()):
					for key, since in list(machine.cancelling.items()):
						# Heard from since, yet no idle for the silent limit: the answer is not coming.
						if machine.socket is not None and machine.heard > since and now - since >= self.silent:
							del machine.cancelling[key]
							freed = True
							say(f"{machine.name} never answered the cancel of S{key[1]} of {key[0]}; taken as idle")
					if machine.socket is None and not machine.lease and now - (machine.closed_at or now) >= GONE_FORGOTTEN_SECONDS:
						del self.roster[machine.name]
				if freed:
					await self.deal()
			except Exception:
				say(f"lease watch failed:\n{traceback.format_exc()}")
