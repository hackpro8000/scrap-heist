"""client.py's side of --relay-results: which relayed files it accepts, writing
them under .standby-results/ or beside a model, and merging the task here."""
import os
import re
import subprocess

import wire
from client_connection import ROOT

# The only repo files a relayed preview may write: what a local coordinator writes beside a model.
RELAYED_REPO_FILE = re.compile(r"art/models/[A-Za-z0-9_]+/(preview\.png|views\.png|previewed\.txt)")
# What a coordinator may name: task ids as it makes them, and a layout.
TASK_ID = re.compile(r"t[0-9]+-[0-9]+-[0-9]+")
LAYOUT_NAME = re.compile(r"[A-Za-z0-9_]+")
# Most a coordinator may relay for one task; past this the run fails.
MAX_RELAYED_FILES = 5_000
MAX_RELAYED_BYTES = 512 * 1024 * 1024


def relayed_path(task, header):
	"""Where a relayed result file goes, or None when its path is not one
	this session accepts: relative, no "..", and for the repo root only a
	model's preview files."""
	path = header.get("path")
	if not isinstance(path, str) or not path or header.get("task") != task or not TASK_ID.fullmatch(task or ""):
		return None
	if os.path.isabs(path) or "\\" in path or ".." in path.split("/") or os.path.normpath(path) != path:
		return None
	if header.get("root") == "results":
		base = os.path.join(ROOT, ".standby-results", task)
		target = os.path.join(base, path)
		# A symlinked folder must not lead out either.
		return target if os.path.realpath(target).startswith(os.path.realpath(base) + os.sep) else None
	if header.get("root") == "repo" and RELAYED_REPO_FILE.fullmatch(path):
		target = os.path.join(ROOT, path)
		# Exactly art/models/<Name>, so a symlinked model folder is refused.
		folder = os.path.join(os.path.realpath(os.path.join(ROOT, "art", "models")), path.split("/")[2])
		return target if os.path.realpath(os.path.dirname(target)) == folder else None
	return None


def write_relayed(task, message, received):
	"""Writes one relayed result file; returns its path, or None if refused.
	received counts this task's files and bytes against MAX_RELAYED_*."""
	header, data = wire.unpack(message)
	if received["files"] + 1 > MAX_RELAYED_FILES or received["bytes"] + len(data) > MAX_RELAYED_BYTES:
		if not received.get("over"):
			print(f"the coordinator relayed more than {MAX_RELAYED_FILES} files or {MAX_RELAYED_BYTES} bytes for task {task}; "
				"refusing the rest, this run FAILED", flush=True)
		received["over"] = True
		return None
	target = relayed_path(task, header)
	if not target:
		print(f"refused a relayed file: {header.get('root')} {header.get('path')!r} for task {header.get('task')}", flush=True)
		return None
	received["files"] += 1
	received["bytes"] += len(data)
	os.makedirs(os.path.dirname(target), exist_ok=True)
	with open(target, "wb") as file:
		file.write(data)
	return target


def merge_here(layout, out):
	"""The merge Coordinator.merge does, for results relayed from machine 1."""
	if not isinstance(layout, str) or not LAYOUT_NAME.fullmatch(layout) or not os.path.isfile(os.path.join(ROOT, "art", "src", "layouts", f"{layout}.luau")):
		return {"error": f"the coordinator named a layout that is not here: {str(layout)[:80]!r}"}
	shards = sorted(os.path.join(out, name) for name in os.listdir(out) if name.startswith("S"))
	result = subprocess.run(["scripts/merge-shards.sh", layout, *shards], cwd=ROOT, capture_output=True, text=True)
	if result.returncode != 0:
		return {"error": result.stderr.strip()[-300:]}
	return {"new_assets": [line for line in result.stdout.split() if re.fullmatch(r"[0-9]+", line)]}
