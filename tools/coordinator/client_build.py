"""client.py build: checks the ref is on GitHub, posts the task and follows
its events (results, uploads, previews, alerts) until it ends."""
import asyncio
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import time

import websockets

from client_connection import (ROOT, MAX_MESSAGE, MAX_RECONNECTS, RECONNECT_BUDGET_SECONDS, RECONNECT_SECONDS,
	alert, control, watch_again)
from client_previews import preview_weights, save_preview_seconds
from client_progress import TICK_SECONDS, Progress
from client_relay import TASK_ID, merge_here, write_relayed

# Events about one task; any for another task is ignored.
TASK_EVENTS = {"progress", "shard", "uploaded", "uploading", "preview", "previews-done", "finished", "redealt", "preview-share"}


async def build(url, ref, upload, wait, previews=(), layout=True, units=None):
	request = {"type": "build", "ref": ref, "upload": upload, "previews": list(previews), "build": layout,
		"weights": preview_weights(previews) if previews else {}}
	if units:
		request["units"] = units
	async with control(url, request, max_size=MAX_MESSAGE) as first:
		return await follow(url, ref, wait, first)


async def follow(url, ref, wait, first):
	"""build's event loop; when the connection drops mid-task it watches the
	task again on a new one (watch_again) and carries on."""
	socket = first
	shares = {}  # (model, unit name) -> machine-seconds, saved on the way out
	relayed = False
	try:
		failed = False
		task = None
		finished = None
		started = time.time()
		progress = None
		last_news = started
		received = {"files": 0, "bytes": 0}
		reconnects, reconnecting = 0, 0.0
		wanted, shown = set(), {}  # models whose previews were asked for; model -> the path its preview event gave

		def over(code):
			"""The exit code once the task and its previews are over: not 0
			while a model asked for has no preview (the hub sends them again
			after a reconnect, so one missing here was never published)."""
			lacking = sorted(name for name in wanted if shown.get(name, "FAILED").startswith("FAILED"))
			if lacking:
				print(f"no preview published for {', '.join(lacking)}; FAILED", flush=True)
			return 1 if lacking else code

		while True:
			try:
				message = await asyncio.wait_for(socket.recv(), TICK_SECONDS)
			except asyncio.TimeoutError:
				message = None
			except websockets.ConnectionClosed:
				if not task:
					print("the coordinator closed the connection before the task was posted", flush=True)
					return 3
				if reconnects >= MAX_RECONNECTS or reconnecting >= RECONNECT_BUDGET_SECONDS:
					print(f"the connection dropped {reconnects + 1} times ({reconnecting:.0f}s spent reconnecting); giving up on task {task}", flush=True)
					return 3
				reconnects += 1
				began = time.time()
				replacement = await watch_again(url, task, min(RECONNECT_SECONDS, RECONNECT_BUDGET_SECONDS - reconnecting))
				reconnecting += time.time() - began
				if not replacement:
					return 3
				await socket.socket.close()
				socket = replacement
				last_news = time.time()
				continue
			if isinstance(message, bytes):
				# A result file relayed from machine 1 (--relay-results).
				last_news = time.time()
				failed = not write_relayed(task, message, received) or failed
				continue
			event = json.loads(message) if message is not None else None
			if progress:
				progress.tick()
			if time.time() - last_news >= wait:
				print(f"no news for {wait}s; giving up waiting (the task carries on)", flush=True)
				return 1
			if event is None:
				continue
			kind = event["type"]
			# Only this build's task; the coordinator streams every task's events.
			if kind in TASK_EVENTS and (task is None or event.get("task") != task):
				continue
			if kind == "progress":
				if progress and progress.update(event):
					last_news = time.time()
				continue
			last_news = time.time()
			if kind == "error":
				print(event["text"])
				return 1
			if kind == "posted":
				if task is not None:
					continue
				if not isinstance(event.get("task"), str) or not TASK_ID.fullmatch(event["task"]):
					print(f"the coordinator posted a task id that is not one it makes: {str(event.get('task'))[:80]!r}; FAILED", flush=True)
					return 1
				task = event["task"]
				# The idle limit is left out: a task under way keeps restarting it.
				progress = Progress(event["count"], event.get("up"), {**event, "idle_minutes": None})
				relayed = bool(event.get("relayed"))
				wanted = {unit.split("@")[0] for unit in event.get("units") or [] if isinstance(unit, str)}
				print(f"posted task {task} ({ref[:7]}): {event['count']} units for {event['up']} machines"
					+ (f"; previews {','.join(event['units'])}" if event.get("units") else ""), file=sys.stderr)
			elif kind == "redealt":
				if progress:
					progress.redealt(event)
				# Relayed files of the unit's old holder must not mix with the new one's.
				if relayed and isinstance(event.get("shard"), int):
					shutil.rmtree(os.path.join(ROOT, ".standby-results", task, f"S{event['shard']}"), ignore_errors=True)
			elif kind == "preview-share":
				if isinstance(event.get("seconds"), (int, float)) and isinstance(event.get("name"), str):
					shares[(event["name"], event.get("unit"))] = float(event["seconds"])
			elif kind == "shard":
				summary = event["summary"].replace("\n", " ")
				print(f"S{event['shard']} ({event.get('machine', '?')}) after {event['seconds']}s: {summary}", flush=True)
				failed = failed or "status=DONE" not in event["summary"]
				if progress and "status=DONE" not in event["summary"]:
					progress.shard_failed(event["shard"], event["seconds"], summary)
			elif kind == "machine":
				if progress and isinstance(event.get("up"), int):
					progress.up = event["up"]
					progress.github_up = event.get("github_up", progress.github_up)
				if event.get("gone"):
					print(f"{event.get('name')} dropped its connection (a reconnect within {event.get('grace', 0):.0f}s keeps its unit; "
						"after that the unit is re-dealt)", flush=True)
			elif kind == "uploaded":
				state = f"asset {event['asset']}" if event.get("asset") else f"FAILED: {event.get('error')}"
				print(f"upload {event['done']}/{event['of']}: {event['label']} {state}", flush=True)
				failed = failed or not event.get("asset")
			elif kind == "preview":
				# Sent again after a reconnect: printed once.
				if shown.get(event["name"]) != event["path"]:
					print(f"preview {event['name']} after {time.time() - started:.0f}s: {event['path']}", flush=True)
				if not str(shown.get(event["name"], "FAILED")).startswith("FAILED") and str(event["path"]).startswith("FAILED"):
					continue  # one share's failure after the model's preview came
				shown[event["name"]] = str(event["path"])
			elif kind == "previews-done" and event["left"] == 0 and finished is not None:
				return over(finished)
			elif kind == "warning":
				print(f"warning: {event['text']}", flush=True)
			elif kind == "log" and event["text"].startswith(("ALERT ", "CLEARED ")):
				# A machine's own alert (standby-agent.py), kept alone on its line.
				alert(event["text"])
			elif kind == "log" and ("FAILED" in event["text"] or "could not" in event["text"] or "error" in event["text"].lower()):
				who = f"{event.get('machine', '?')}" + (f" S{event['shard']}" if event.get("shard") else "")
				print(f"{who}: {event['text']}", flush=True)
				if progress and not progress.reason:
					progress.reason = f"{who}: {event['text']}"
			elif kind == "finished":
				# The results folder is always worked out here: relayed ones were
				# written here, and a coordinator on this computer writes the same one.
				out = os.path.join(ROOT, ".standby-results", task)
				if not event.get("relayed") and (not isinstance(event.get("out"), str) or os.path.realpath(event["out"]) != os.path.realpath(out)):
					print(f"the coordinator's results folder {str(event.get('out'))[:120]!r} is not {os.path.relpath(out)}; not reading it, FAILED", flush=True)
					return 1
				parts =[line for path in glob.glob(f"{out}/S*/parts.txt") for line in open(path).read().split()]
				twice = {part for part in parts if parts.count(part) > 1}
				if twice:
					print(f"parts built by more than one shard: {' '.join(sorted(twice)[:3])}")
					failed = True
				print(f"task {event['task']}: built in {event['built']}s, all done in {event['total']}s, "
					f"{len(parts)} parts, {event['objects']} objects handed over, {event['uploaded']} uploaded "
					f"(ending at {event['width']} at once); results in {os.path.relpath(out)}")
				for identity, error in event["failed"].items():
					print(f"upload of {identity} failed: {error}")
					failed = True
				merged = event.get("merged")
				if merged is None and event.get("merge_here") and not failed:
					merged = merge_here(event["layout"], out)
				if merged and merged.get("error"):
					print(f"merge failed: {merged['error']}")
					failed = True
				elif merged:
					given = merged.get("new_assets", [])
					new = [asset for asset in given if isinstance(asset, str) and re.fullmatch(r"[0-9]+", asset)] if isinstance(given, list) else []
					if not isinstance(given, list) or len(new) != len(given):
						print("the merge named new assets that are not asset ids; dropped them, FAILED", flush=True)
						failed = True
					print(f"merged into the game's tables; {len(new)} new assets need the game's permission")
					with open(os.path.join(out, "new-assets.txt"), "w") as file:
						file.write("\n".join(new) + ("\n" if new else ""))
				finished = 1 if failed else 0
				# Previews come after each machine's result; wait for the last.
				if not event.get("previews_waiting"):
					return over(finished)
				print(f"waiting for previews from {event['previews_waiting']} machines", flush=True)
	finally:
		save_preview_seconds(shares)
		# The first connection is closed by control().
		if socket is not first:
			await socket.socket.close()


def resolve_ref(ref):
	"""The ref to post, checked to be on GitHub, where the machines fetch it:
	a commit id is made whole (a machine cannot fetch a short one), a branch
	name is kept. Returns (ref, None), or (None, why) when GitHub lacks it."""
	commit_id = re.fullmatch(r"[0-9a-fA-F]{4,40}", ref) is not None
	asked = ref
	if commit_id:
		local = subprocess.run(["git", "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}"], cwd=ROOT, capture_output=True, text=True)
		asked = local.stdout.strip() if local.returncode == 0 else ref
	try:
		remote = subprocess.run(["gh", "api", f"repos/{{owner}}/{{repo}}/commits/{asked}", "--jq", ".sha"],
			cwd=ROOT, capture_output=True, text=True, timeout=30)
	except (OSError, subprocess.TimeoutExpired) as error:
		return None, f"could not ask GitHub: {error}"
	if remote.returncode != 0:
		said = remote.stderr.strip().splitlines()
		return None, (said[-1] if said else "GitHub does not know it")[:200]
	return (remote.stdout.strip() if commit_id else ref), None
