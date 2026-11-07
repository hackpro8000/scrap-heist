#!/usr/bin/env python3
"""Talks to the running coordinator (coordinator.py) from this session.

  tools/coordinator/client.py status          # the run, machines up, tasks
  tools/coordinator/client.py build <commit> [--no-upload] [--wait S] [--preview A,B]
  tools/coordinator/client.py stop-machines   # standby machines end now
  tools/coordinator/client.py wait-machines [N] [--wait S]
                                              # returns once N machines are up
                                              # (default: all of the run)

`build` posts a task and prints each machine's result the moment it
arrives, then the upload's, and exits 0 when every machine built and every
object uploaded. Results land in .standby-results/<task>/ for
scripts/merge-shards.sh. With --preview, the machines also render those
models with modelkit; each machine's renders come back with its result,
often before the uploads end; the coordinator puts them in
art/models/<Name>/ (preview.png, views.png) and each is printed as it
lands. Exits 2 when no
coordinator is running.
"""
import argparse
import asyncio
import glob
import json
import os
import sys
import time

import websockets

STATE = os.path.expanduser("~/.cache/scrap-heist/coordinator.json")
MAX_MESSAGE = 64 * 1024 * 1024


def control_url():
	if not os.path.isfile(STATE):
		return None
	state = json.load(open(STATE))
	try:
		os.kill(state["pid"], 0)
	except (OSError, KeyError):
		return None
	return state["control"]


async def status(url):
	async with websockets.connect(url) as socket:
		await socket.send(json.dumps({"type": "status"}))
		answer = json.loads(await socket.recv())
	up = answer["up"]
	print(f"run={answer['run']} machines={answer['count']} up={len(up)} tasks={len(answer['tasks'])}")
	return 0


async def wait_machines(url, wanted, wait):
	async with websockets.connect(url) as socket:
		await socket.send(json.dumps({"type": "watch"}))
		while True:
			try:
				event = json.loads(await asyncio.wait_for(socket.recv(), wait))
			except asyncio.TimeoutError:
				print(f"no machine connected for {wait}s")
				return 1
			if event["type"] in ("machines", "machine"):
				need = wanted or event["count"]
				if event["count"]:
					print(f"{event['up']} of {event['count']} machines up", file=sys.stderr)
				if need and event["up"] >= need:
					return 0


async def stop_machines(url):
	async with websockets.connect(url) as socket:
		await socket.send(json.dumps({"type": "stop-machines"}))
		print(json.loads(await socket.recv()))
	return 0


STALL_SECONDS = 30


async def build(url, ref, upload, wait, previews=()):
	async with websockets.connect(url, max_size=MAX_MESSAGE) as socket:
		await socket.send(json.dumps({"type": "build", "ref": ref, "upload": upload, "previews": list(previews)}))
		failed = False
		task = None
		finished = None
		started = time.time()
		quiet = 0
		while True:
			try:
				event = json.loads(await asyncio.wait_for(socket.recv(), STALL_SECONDS))
				quiet = 0
			except asyncio.TimeoutError:
				quiet += STALL_SECONDS
				print(f"... nothing for {quiet}s (machines and uploads still going?)", flush=True)
				if quiet >= wait:
					print(f"nothing heard for {wait}s; giving up waiting (the task carries on)")
					return 1
				continue
			kind = event["type"]
			if kind == "error":
				print(event["text"])
				return 1
			if kind == "posted":
				task = event["task"]
				print(f"posted task {task} ({ref[:7]}) to {event['up']} of {event['count']} machines", file=sys.stderr)
			elif kind == "shard":
				summary = event["summary"].replace("\n", " ")
				print(f"S{event['shard']} after {event['seconds']}s: {summary}", flush=True)
				failed = failed or "status=DONE" not in event["summary"]
			elif kind == "machine" and event.get("gone"):
				print(f"S{event['shard']} dropped its connection (it reconnects and resumes)", flush=True)
			elif kind == "uploaded":
				state = f"asset {event['asset']}" if event.get("asset") else f"FAILED: {event.get('error')}"
				print(f"upload {event['done']}/{event['of']}: {event['label']} {state}", flush=True)
				failed = failed or not event.get("asset")
			elif kind == "preview":
				print(f"preview {event['name']} after {time.time() - started:.0f}s: {event['path']}", flush=True)
			elif kind == "previews-done" and event["task"] == task and event["left"] == 0 and finished is not None:
				return finished
			elif kind == "warning":
				print(f"warning: {event['text']}", flush=True)
			elif kind == "log" and ("FAILED" in event["text"] or "could not" in event["text"] or "error" in event["text"].lower()):
				print(f"S{event['shard']}: {event['text']}", flush=True)
			elif kind == "finished":
				out = event["out"]
				parts = [line for path in glob.glob(f"{out}/S*/parts.txt") for line in open(path).read().split()]
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
				if merged and merged.get("error"):
					print(f"merge failed: {merged['error']}")
					failed = True
				elif merged:
					new = merged.get("new_assets", [])
					print(f"merged into the game's tables; {len(new)} new assets need the game's permission")
					with open(os.path.join(out, "new-assets.txt"), "w") as file:
						file.write("\n".join(new) + ("\n" if new else ""))
				finished = 1 if failed else 0
				# Previews come after each machine's result; wait for the last.
				if not event.get("previews_waiting"):
					return finished
				print(f"waiting for previews from {event['previews_waiting']} machines", flush=True)


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("command", choices=["status", "build", "stop-machines", "wait-machines"])
	parser.add_argument("ref", nargs="?")
	parser.add_argument("--no-upload", action="store_true")
	parser.add_argument("--wait", type=int, default=600)
	parser.add_argument("--preview", default="", help="models to render, comma-separated")
	arguments = parser.parse_args()
	url = control_url()
	if not url:
		print("no coordinator running (scripts/coordinator.sh start)", file=sys.stderr)
		sys.exit(2)
	if arguments.command == "status":
		code = asyncio.run(status(url))
	elif arguments.command == "wait-machines":
		code = asyncio.run(wait_machines(url, int(arguments.ref or 0), arguments.wait))
	elif arguments.command == "stop-machines":
		code = asyncio.run(stop_machines(url))
	else:
		if not arguments.ref:
			parser.error("build needs a commit")
		previews = [name for name in arguments.preview.split(",") if name]
		code = asyncio.run(build(url, arguments.ref, not arguments.no_upload, arguments.wait, previews))
	sys.exit(code)


if __name__ == "__main__":
	main()
