"""Agent mixin: hot updates. The hub names its code commit when it greets a
machine and again in {"type": "update", "commit"}; a machine on other code
checks that commit out and re-executes itself with the same arguments once
it holds no unit (a unit under way finishes first). A failed checkout keeps
the old code, raises ALERT UPDATE_FAILED and tells the hub, and that commit
is not tried again."""
import asyncio
import json
import os
import re
import subprocess
import sys
import time

from standby_agent import machine
from standby_agent.common import ROOT, alert, say

SHA = re.compile(r"[0-9a-f]{40}")
SCRIPT = os.path.join(ROOT, "scripts", "standby-agent.py")


def current_commit():
	"""The commit checked out at start: the code this process loaded."""
	try:
		head = subprocess.run(["git", "-C", ROOT, "rev-parse", "HEAD"], capture_output=True, text=True, timeout=30).stdout.strip()
	except (OSError, subprocess.SubprocessError):
		return None
	return head if SHA.fullmatch(head) else None


def lifetime_left(max_minutes):
	"""Seconds left of the machine's max lifetime, kept across re-executions
	through STANDBY_AGENT_STARTED, so an update does not extend it."""
	started = float(os.environ.get("STANDBY_AGENT_STARTED") or time.time())
	os.environ["STANDBY_AGENT_STARTED"] = str(started)
	return int(max_minutes) * 60 - (time.time() - started)


class Updates:
	def want_update(self, commit):
		if not isinstance(commit, str) or not SHA.fullmatch(commit) or commit == self.code_commit or commit in self.update_failed:
			return
		if self.update_to != commit:
			say(f"the hub runs {commit[:12]}, this machine {(self.code_commit or '?')[:12]}; updating"
				+ (" once its unit is over" if self.handling else ""))
		self.update_to = commit
		self.update_if_due()

	def update_if_due(self):
		"""Called when an update is asked for and whenever a unit ends."""
		if not self.update_to or self.updating or self.handling or self.cancelling:
			return
		self.updating = True
		asyncio.ensure_future(self.update())

	async def update(self):
		commit = self.update_to
		try:
			ok, error = await asyncio.to_thread(self.checkout_code, commit)
			if not ok:
				self.update_failed.add(commit)
				alert(f"ALERT UPDATE_FAILED: S{self.index} could not check out {commit[:12]} ({error}) "
					f"| it stays on {(self.code_commit or '?')[:12]} and keeps taking units; check the commit is pushed, or restart the machine")
				try:
					await self.socket.send(json.dumps({"type": "update-failed", "commit": commit, "text": error[-300:]}))
				except Exception:
					pass
				return
			say(f"checked out {commit[:12]}; starting again on it")
			if self.socket is not None:
				try:
					await asyncio.wait_for(self.socket.close(), 5)
				except Exception:
					pass
			self.reexec(commit)
			self.code_commit = commit  # reached only when a test replaces reexec
		finally:
			self.updating = False
			if self.update_to == commit:
				self.update_to = None

	def checkout_code(self, commit):
		"""Fetches and checks out `commit`; (ok, error). Tests replace it."""
		with self.git_lock:
			if current_commit() == commit:
				return True, ""
			for command in (["git", "fetch", "-q", "--depth=1", "origin", commit], ["git", "checkout", "-q", "-f", "--detach", commit]):
				try:
					done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=300)
				except (OSError, subprocess.SubprocessError) as error:
					return False, f"{' '.join(command[:2])}: {error}"
				if done.returncode != 0:
					return False, f"{' '.join(command[:2])}: {done.stderr.strip()[-300:]}"
		return True, ""

	def reexec(self, _commit):
		"""Replaces this process with the agent of the new checkout, same
		arguments, same pid (the workflow waits on it). Tests replace it."""
		environment = dict(os.environ)
		if machine.WORKER_TOKEN:
			environment["COORDINATOR_WORKER_TOKEN"] = machine.WORKER_TOKEN
		sys.stdout.flush()
		sys.stderr.flush()
		os.execve(sys.executable, [sys.executable, SCRIPT, *self.arguments], environment)
