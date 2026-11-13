"""Hot updates (a part of Coordinator): the hub's code commit, told to every
machine in its greeting; `update <sha>` from a signed session, which checks
the commit out here, tells every machine, and exits so machine 1's restart
loop (.github/workflows/build-standby.yml) starts the hub again on the new
code, on the same ports and tunnels. A machine on other code than the hub's
is dealt nothing until it updates (or says its update failed)."""
import asyncio
import json
import os
import re
import secrets
import subprocess

from hub_config import ROOT, say

SHA = re.compile(r"[0-9a-f]{40}")


def current_commit(root=ROOT):
	"""The commit checked out at `root`, read at start: the code this process loaded."""
	try:
		head = subprocess.run(["git", "-C", root, "rev-parse", "HEAD"], capture_output=True, text=True, timeout=30).stdout.strip()
	except (OSError, subprocess.SubprocessError):
		return None
	return head if SHA.fullmatch(head) else None


class HubUpdate:
	code_commit = None  # set by serve() from the checkout; None: no update gating
	boot = secrets.token_hex(4)  # one per process, so a session sees the hub come back
	restarts = False  # only machine 1's --relay-results hub runs inside a restart loop

	def note_code(self, machine, hello):
		"""What a machine's hello says about its code and its compiler."""
		code = hello.get("code")
		machine.code = code if isinstance(code, str) and SHA.fullmatch(code) else None
		machine.cargo = hello.get("cargo") is True

	async def tell_code(self, machine):
		if self.code_commit:
			await self.send_to(machine, json.dumps({"type": "hub", "commit": self.code_commit}))

	def stale(self, machine):
		"""Whether a machine runs other code than the hub's and should update
		before its next unit. One whose update failed is dealt to anyway."""
		return bool(self.code_commit and machine.code and machine.code != self.code_commit
			and machine.update_failed != self.code_commit)

	def note_update_failed(self, machine, event):
		commit = event.get("commit")
		if isinstance(commit, str) and SHA.fullmatch(commit):
			machine.update_failed = commit
			say(f"{machine.name} could not update to {commit[:12]}: {str(event.get('text', ''))[:200]}; it takes units on its old code")

	def code_state(self):
		"""For status: the hub's code, its boot id, and each connected machine's code."""
		return {"code": self.code_commit, "boot": self.boot,
			"codes": {machine.name: machine.code for machine in self.connected() if machine.code}}

	def checkout_code(self, commit):
		"""Fetches and checks out `commit` in this checkout; (ok, error). Tests replace it."""
		for command in (["git", "fetch", "-q", "--depth=1", "origin", commit], ["git", "checkout", "-q", "-f", "--detach", commit]):
			try:
				done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=300)
			except (OSError, subprocess.SubprocessError) as error:
				return False, f"{' '.join(command[:2])}: {error}"
			if done.returncode != 0:
				return False, f"{' '.join(command[:2])}: {done.stderr.strip()[-300:]}"
		return True, ""

	def exit_for_update(self):
		"""Ends this process; the restart loop starts the new code. Tests replace it."""
		os._exit(0)

	async def update_request(self, socket, request):
		commit, force = request.get("commit"), request.get("force") is True
		if not isinstance(commit, str) or not SHA.fullmatch(commit):
			await socket.send(json.dumps({"type": "error", "text": "update wants a full 40-character commit sha"}))
			return
		if not self.restarts:
			await socket.send(json.dumps({"type": "error", "text": "this hub is not run by a restart loop (only machine 1's is); restart it by hand"}))
			return
		if self.tasks and not force:
			await socket.send(json.dumps({"type": "error", "text": f"{len(self.tasks)} tasks open ({' '.join(self.tasks)}); "
				"wait for them, clear them (clear-tasks), or update --force (machine 1's running unit has its checkout changed under it)"}))
			return
		ok, error = await asyncio.to_thread(self.checkout_code, commit)
		if not ok:
			await socket.send(json.dumps({"type": "error", "text": f"could not check out {commit[:12]} on the hub: {error}"}))
			return
		old, self.code_commit = self.code_commit, commit
		told = self.connected()
		say(f"updating from {(old or '?')[:12]} to {commit[:12]}; telling {len(told)} machines, then exiting for the restart loop")
		for machine in told:
			await self.send_to(machine, json.dumps({"type": "update", "commit": commit}))
		await socket.send(json.dumps({"type": "updating", "commit": commit, "from": old, "boot": self.boot, "machines": len(told)}))
		# Closed cleanly, so every message above is delivered before the exit.
		closing = [machine.socket.close(code=1012, reason="hub updating") for machine in told if machine.socket is not None]
		try:
			await asyncio.wait_for(asyncio.gather(*closing, socket.close(), return_exceptions=True), 5)
		except asyncio.TimeoutError:
			pass
		self.exit_for_update()
