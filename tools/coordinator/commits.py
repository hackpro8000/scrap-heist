"""Takes one commit's files from GitHub, for files that travel between build
machines and this session as commits (scripts/push-folder.sh) instead of
through the coordinator's tunnel."""
import os
import shutil
import subprocess
import time

TRIES = 3


def fetch_into(root, store_folder, commit, into):
	"""Unpacks the commit's files into `into`. Uses a bare repository of its
	own for each commit, so several download side by side (git refuses two
	fetches into one repository at once). A failed fetch is tried again."""
	store = os.path.join(store_folder, commit)
	if not os.path.isdir(store):
		origin = subprocess.run(["git", "-C", root, "remote", "get-url", "origin"], capture_output=True, text=True).stdout.strip()
		subprocess.run(["git", "init", "-q", "--bare", store], check=True)
		subprocess.run(["git", "-C", store, "remote", "add", "origin", origin], check=True)
	try:
		for attempt in range(TRIES):
			fetched = subprocess.run(["git", "-C", store, "fetch", "-q", "--depth=1", "origin", commit], capture_output=True, text=True)
			if fetched.returncode == 0:
				break
			time.sleep(0.5 * (attempt + 1))
		else:
			raise RuntimeError(f"fetch of {commit[:8]} failed: {fetched.stderr.strip()[-200:]}")
		os.makedirs(into, exist_ok=True)
		archive = subprocess.Popen(["git", "-C", store, "archive", commit], stdout=subprocess.PIPE)
		subprocess.run(["tar", "-x", "-C", into], stdin=archive.stdout, check=True)
		archive.wait()
	finally:
		shutil.rmtree(store, ignore_errors=True)
