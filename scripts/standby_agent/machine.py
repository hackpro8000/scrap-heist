"""Build-machine helpers for the standby agent: free space, tools, logs,
pushes of bakes and previews, killing a unit's process tree, the identity token."""
import glob
import json
import os
import shutil
import signal
import subprocess
import tempfile
import urllib.request

from standby_agent.common import AUDIENCE, LOG_LINES_KEPT, ROOT, say


def http_status(error):
	"""The HTTP status a refused websocket handshake answered with, or None
	(websockets 10 names it status_code, 13 keeps it on the response)."""
	code = getattr(error, "status_code", None)
	return code or getattr(getattr(error, "response", None), "status_code", None)


def free_space():
	"""Free disk for the work folder and available memory, in GB, for heartbeats."""
	disk = shutil.disk_usage(os.getcwd()).free / 1e9
	memory = None
	try:
		with open("/proc/meminfo") as file:
			for line in file:
				if line.startswith("MemAvailable:"):
					memory = round(int(line.split()[1]) / 1e6, 1)
					break
	except OSError:
		pass
	return round(disk, 1), memory


def remote_head(branch):
	"""The commit a branch on GitHub points at, or ""."""
	listed = subprocess.run(["git", "ls-remote", "origin", f"refs/heads/{branch}"], capture_output=True, text=True, timeout=60)
	return listed.stdout.split("\t")[0].strip() if listed.returncode == 0 else ""


def ensure_tools():
	"""Here rather than as a workflow step: a machine runs the workflow file
	from main but this agent from the pushed work in progress, and a machine
	that can't reach a release still takes tasks (session() names what's missing)."""
	os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
	subprocess.run([os.path.join(ROOT, "scripts/ensure-tools.sh")], capture_output=True)


def trim_log(path):
	"""A render's log runs to hundreds of KB; its end says what went wrong."""
	try:
		with open(path, errors="replace") as file:
			lines = file.readlines()
	except OSError:
		return
	if len(lines) > LOG_LINES_KEPT:
		with open(path, "w") as file:
			file.writelines(lines[-LOG_LINES_KEPT:])


def push_bakes(model, share, out, since):
	"""Pushes the paint layers saved since `since`; returns the commit, or ""."""
	cache = os.path.join("art", "models", model, ".cache")
	fresh = tempfile.mkdtemp(dir=out)
	try:
		for entry in os.scandir(cache) if os.path.isdir(cache) else []:
			if entry.stat().st_mtime >= since:
				os.link(entry.path, os.path.join(fresh, entry.name))
		if not os.listdir(fresh):
			return ""
		branch = "build-bakes/" + share.replace("@", "-")
		pushed = subprocess.run(["scripts/push-folder.sh", fresh, branch, f"bakes {share}"], capture_output=True, text=True)
		if pushed.returncode != 0 and "cannot lock ref" in pushed.stderr and "reference already exists" in pushed.stderr:
			# Another machine saved the same bake first: theirs serves as ours.
			say(f"bakes of {share} already saved by another machine; taking theirs")
			return remote_head(branch)
		if pushed.returncode != 0:
			say(f"could not push bakes of {share}: {pushed.stderr.strip()[-200:]}")
			return ""
		return pushed.stdout.strip()
	finally:
		shutil.rmtree(fresh, ignore_errors=True)


def push_preview(folder, share):
	"""The commit holding a finished preview's files, or "" if the push failed."""
	branch = "preview-results/" + share.replace("@", "-")
	pushed = subprocess.run(["scripts/push-folder.sh", folder, branch, f"preview {share}"], capture_output=True, text=True)
	if pushed.returncode != 0:
		say(f"could not push preview {share}: {pushed.stderr.strip()[-200:]}")
		return ""
	return pushed.stdout.strip()


def kill_tree(pid):
	"""Kills a unit's process and everything under it. Its own process group
	is not enough: scripts/standby-task.sh starts its lanes with setsid, so
	every descendant's group goes too (found through /proc)."""
	parents = {}
	for entry in os.listdir("/proc"):
		if not entry.isdigit():
			continue
		try:
			with open(f"/proc/{entry}/stat") as file:
				parents.setdefault(int(file.read().rsplit(")", 1)[1].split()[1]), []).append(int(entry))
		except (OSError, IndexError, ValueError):
			continue
	tree, at = [pid], 0
	while at < len(tree):
		tree += parents.get(tree[at], [])
		at += 1
	own = os.getpgrp()
	for process in tree:
		try:
			group = os.getpgid(process)
			if group != own:
				os.killpg(group, signal.SIGKILL)
		except OSError:
			pass
		try:
			os.kill(process, signal.SIGKILL)
		except OSError:
			pass


def newest_log(path):
	"""The log a stage wrote to last: its own, or in a build a lane's
	(scripts/standby-task.sh writes lane-<n>.log beside build.log). The
	memory probe's probe.log is left out: it writes every 10 s, hung or not."""
	best, newest = path, -1.0
	for candidate in [path, *glob.glob(os.path.join(os.path.dirname(path), "lane-*.log"))]:
		try:
			when = os.path.getmtime(candidate)
		except OSError:
			continue
		if when > newest:
			best, newest = candidate, when
	return best


def last_line(path):
	try:
		with open(path, "rb") as file:
			file.seek(0, os.SEEK_END)
			file.seek(max(0, file.tell() - 2000))
			lines = file.read().decode("utf-8", "replace").splitlines()
	except OSError:
		return ""
	return next((line.strip() for line in reversed(lines) if line.strip()), "")[:200]


WORKER_TOKEN = ""  # a cloud worker's minted token, taken from the environment by main()


def identity_token():
	# A worker that is not a GitHub machine (scripts/cloud-worker.sh) shows its
	# minted token; taken out of the environment so builds never see it.
	if WORKER_TOKEN:
		return "worker:" + WORKER_TOKEN
	url = os.environ.get("ACTIONS_ID_TOKEN_REQUEST_URL")
	bearer = os.environ.get("ACTIONS_ID_TOKEN_REQUEST_TOKEN")
	if not url or not bearer:
		return os.environ.get("AGENT_TEST_TOKEN", "")
	request = urllib.request.Request(f"{url}&audience={AUDIENCE}", headers={"Authorization": f"bearer {bearer}"})
	with urllib.request.urlopen(request, timeout=20) as response:
		return json.load(response)["value"]
