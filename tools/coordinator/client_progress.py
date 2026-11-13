"""client.py's watch over one task: per-machine progress, STALL lines,
summaries, and the ALERT/CLEARED lines (LIFETIME included) with their limits."""
import time

from client_connection import alert

TICK_SECONDS = 5
SUMMARY_SECONDS = 30
STEP_STALL_SECONDS = 180  # no new line in a machine's log
SILENT_STALL_SECONDS = 60  # no heartbeat from a machine (they come every 10s)
WEDGED_SECONDS = 300  # the hub's default: a unit quiet this long is re-dealt (ALERT WEDGED warns at 80%)
SILENT_REDEAL_SECONDS = 120  # the hub's default: a machine unheard this long loses its unit
SHORT_SECONDS = 120  # fewer machines than the run asked for, this long after: ALERT SHORT
ALL_FAILED_SECONDS = 30  # every shard failing within this: ALERT ALL_FAILED
LOW_GB = 2  # free disk or available memory under this: ALERT LOW_RESOURCES


LIFETIME_WARN_SECONDS = 15 * 60


def lifetime_alert(info, now):
	"""ALERT LIFETIME when the hub ends within 15 minutes, by its idle or
	its max limit; None when it doesn't or the hub doesn't know its limits."""
	ends = []
	if info.get("idle_minutes") and info.get("last_active"):
		ends.append((info["last_active"] + info["idle_minutes"] * 60, f"{info['idle_minutes']}m idle limit"))
	if info.get("max_minutes") and info.get("hub_started"):
		ends.append((info["hub_started"] + info["max_minutes"] * 60, f"{info['max_minutes']}m max limit"))
	if not ends:
		return None
	end, limit = min(ends)
	left = end - now
	if left > LIFETIME_WARN_SECONDS:
		return None
	advice = "post a task to restart its idle clock" if "idle" in limit else "start a new run (scripts/standby-start.sh) before it ends"
	return f"ALERT LIFETIME: the hub ends in {max(0, left) / 60:.0f}m ({limit}) | {advice}"


class Progress:
	"""What each machine last said about one task, turned into a summary
	line every SUMMARY_SECONDS, an alarm naming any machine that stalls,
	and ALERT lines (each once, CLEARED when it resolves)."""

	def __init__(self, count, up=None, lifetime=None):
		self.count = count  # units
		self.up = count if up is None else up
		self.lifetime = lifetime or {}
		# The GitHub run's size and its machines up (ALERT SHORT), and when the
		# hub takes a lease back (ALERT WEDGED warns before it does).
		self.run_count = self.lifetime.get("run_count") or 0
		self.github_up = self.lifetime.get("github_up") or 0
		leases = self.lifetime.get("lease_seconds") or {}
		self.silent = leases.get("silent") or SILENT_REDEAL_SECONDS
		self.wedged = leases.get("wedged") or WEDGED_SECONDS
		self.started = time.time()
		# The hub's clock may differ from this one; lifetime times are read against it.
		self.clock_offset = self.lifetime.get("now", self.started) - self.started
		self.machines = {}  # shard -> its latest progress event, plus when it came
		self.stalled = set()
		self.raised = set()  # (kind, shard or None) of alerts printed and not cleared
		self.failed = {}  # shard -> seconds after posting it failed
		self.reason = ""  # the first failure line a machine reported
		self.next_summary = self.started + SUMMARY_SECONDS

	def flag(self, key, line):
		"""Prints an ALERT once per occurrence."""
		if key not in self.raised:
			self.raised.add(key)
			alert(line)

	def unflag(self, key, line):
		if key in self.raised:
			self.raised.discard(key)
			alert(line)

	def shard_failed(self, shard, seconds, summary):
		self.failed[shard] = seconds
		if len(self.failed) < self.count or max(self.failed.values()) > ALL_FAILED_SECONDS:
			return
		self.flag(("ALL_FAILED", None), f"ALERT ALL_FAILED: {self.count} shards, first reason: {self.reason or summary} "
			"| fix the cause (a bad ref, a missing tool, a broken commit) before posting again")

	def redealt(self, event):
		"""The hub took a unit back and gave it to another machine."""
		shard = event.get("shard")
		alert(f"ALERT REDEALT: S{shard} from {event.get('from')} to {event.get('to')}: {event.get('reason')} "
			"| nothing to do; if one machine keeps losing units, restart it")
		self.machines.pop(shard, None)
		self.stalled.discard(shard)
		self.unflag(("WEDGED", shard), f"CLEARED WEDGED: S{shard} re-dealt to {event.get('to')}")

	def check_alerts(self, now):
		for shard in range(1, self.count + 1):
			work = self.machines.get(shard)
			if not work:
				continue
			unheard = now - work["heard"]
			quiet = work.get("quiet", 0) + unheard
			on = f"S{shard} on {work.get('machine', '?')}"
			if work["stage"] != "done" and (unheard >= self.silent * 0.75 or quiet >= self.wedged * 0.8):
				self.flag(("WEDGED", shard), f"ALERT WEDGED: {on} unheard for {unheard:.0f}s, log quiet {quiet:.0f}s at {work['stage']} {work['model']} "
					f"| the hub re-deals it at {self.silent:.0f}s unheard or {self.wedged:.0f}s quiet; nothing to do unless it repeats")
			elif work["stage"] == "done" or (unheard < self.silent * 0.75 and quiet < self.wedged * 0.8):
				self.unflag(("WEDGED", shard), f"CLEARED WEDGED: {on} moving again")
			low = [f"{work[field]} GB {name}" for field, name in (("disk_gb", "disk free"), ("memory_gb", "memory available"))
				if isinstance(work.get(field), (int, float)) and work[field] < LOW_GB]
			if low:
				self.flag(("LOW_RESOURCES", shard), f"ALERT LOW_RESOURCES: S{shard} has {', '.join(low)} "
					"| expect its build to fail; restart it if it does")
			else:
				self.unflag(("LOW_RESOURCES", shard), f"CLEARED LOW_RESOURCES: S{shard} has room again")
		if self.run_count and now - self.started >= SHORT_SECONDS and self.github_up < self.run_count:
			self.flag(("SHORT", None), f"ALERT SHORT: {self.github_up} of the run's {self.run_count} GitHub machines connected {now - self.started:.0f}s after posting "
				"| the queue goes on with the machines that are up; check the missing jobs (gh run view) or start a new run")
		elif self.github_up >= self.run_count:
			self.unflag(("SHORT", None), f"CLEARED SHORT: all {self.run_count} GitHub machines connected")
		ending = lifetime_alert(self.lifetime, now + self.clock_offset)
		if ending:
			self.flag(("LIFETIME", None), ending)

	def update(self, event):
		"""Returns whether this heartbeat is news: a heartbeat alone only
		proves the machine is alive, not that its work is moving."""
		before = self.machines.get(event["shard"])
		self.machines[event["shard"]] = {**event, "heard": time.time()}
		return not before or (before["stage"], before["line"]) != (event["stage"], event["line"])

	def stall(self, shard, now):
		work = self.machines.get(shard)
		# A unit not heard from yet may simply be queued.
		if not work or work["stage"] == "done":
			return None
		unheard = now - work["heard"]
		if unheard >= SILENT_STALL_SECONDS:
			return f"no heartbeat for {unheard:.0f}s (was at {work['stage']} {work['model']})"
		quiet = work["quiet"] + unheard
		if quiet >= STEP_STALL_SECONDS:
			return f"no new log line for {quiet:.0f}s in {work['stage']} {work['model']}; last: {work['line']}"
		return None

	def tick(self):
		now = time.time()
		for shard in range(1, self.count + 1):
			problem = self.stall(shard, now)
			if problem and shard not in self.stalled:
				self.stalled.add(shard)
				print(f"STALL S{shard} ({self.machines[shard].get('machine', '?')}): {problem}", flush=True)
			elif not problem and shard in self.stalled:
				self.stalled.discard(shard)
				print(f"RECOVERED S{shard}", flush=True)
		self.check_alerts(now)
		if now >= self.next_summary:
			self.next_summary = now + SUMMARY_SECONDS
			print(self.summary(now), flush=True)

	def summary(self, now):
		heading = f"[{now - self.started:4.0f}s]"
		if not self.machines:
			return f"{heading} nothing from any of {self.count} machines yet"
		counts = {}
		for work in self.machines.values():
			counts[work["stage"]] = counts.get(work["stage"], 0) + 1
		line = ", ".join(f"{counts[stage]} {stage}" for stage in sorted(counts))
		unheard = self.count - len(self.machines)
		if unheard:
			line += f", {unheard} not started"
		if self.stalled:
			line += ", stalled " + " ".join(f"S{shard}" for shard in sorted(self.stalled))
		working = [(work["quiet"] + now - work["heard"], shard, work) for shard, work in self.machines.items() if work["stage"] != "done"]
		if working:
			quiet, shard, work = max(working, key=lambda entry: entry[0])
			line += f"; slowest S{shard} ({work.get('machine', '?')}) {work['stage']} {work['model']}, log quiet {quiet:.0f}s: {work['line']}"
		return f"{heading} {line}"
