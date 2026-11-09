#!/usr/bin/env python3
"""Talks to the running coordinator (coordinator.py) from this session.

  tools/coordinator/client.py status          # the run, machines up, tasks
  tools/coordinator/client.py machines        # what each machine is doing now
  tools/coordinator/client.py build <commit> [--no-upload] [--wait S] [--preview A,B] [--preview-only]
  tools/coordinator/client.py stop-machines   # standby machines end now
  tools/coordinator/client.py wait-machines [N] [--wait S]
                                              # returns once N machines are up
                                              # (default: all of the run)

While it waits, `build` prints a summary every 30 seconds and a line starting
STALL that names any machine that goes quiet (RECOVERED when it comes back).

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


async def machines(url):
	"""One line per machine: what it is doing and when it last said so."""
	async with websockets.connect(url) as socket:
		await socket.send(json.dumps({"type": "status"}))
		answer = json.loads(await socket.recv())
	for shard in range(1, answer["count"] + 1):
		work = answer["progress"].get(str(shard))
		if shard not in answer["up"]:
			print(f"S{shard}: not connected")
		elif not work:
			print(f"S{shard}: idle, no task reported")
		elif work["stage"] == "done":
			print(f"S{shard}: done with {work['task']}, {answer['now'] - work['heard']:.0f}s ago")
		else:
			print(f"S{shard}: {work['stage']} {work['model']} {work['seconds']}s, log quiet {work['quiet']}s, "
				f"heard {answer['now'] - work['heard']:.0f}s ago: {work['line']}")
	return 0


TICK_SECONDS = 5
SUMMARY_SECONDS = 30
STEP_STALL_SECONDS = 180  # no new line in a machine's log
SILENT_STALL_SECONDS = 60  # no heartbeat from a machine (they come every 10s)


class Progress:
	"""What each machine last said about one task, turned into a summary
	line every SUMMARY_SECONDS and an alarm naming any machine that stalls."""

	def __init__(self, count):
		self.count = count
		self.started = time.time()
		self.machines = {}  # shard -> its latest progress event, plus when it came
		self.stalled = set()
		self.next_summary = self.started + SUMMARY_SECONDS

	def update(self, event):
		"""Returns whether this heartbeat is news: a heartbeat alone only
		proves the machine is alive, not that its work is moving."""
		before = self.machines.get(event["shard"])
		self.machines[event["shard"]] = {**event, "heard": time.time()}
		return not before or (before["stage"], before["line"]) != (event["stage"], event["line"])

	def stall(self, shard, now):
		work = self.machines.get(shard)
		if not work:
			waited = now - self.started
			return f"nothing heard in the {waited:.0f}s since the task was posted" if waited >= SILENT_STALL_SECONDS else None
		if work["stage"] == "done":
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
				print(f"STALL S{shard}: {problem}", flush=True)
			elif not problem and shard in self.stalled:
				self.stalled.discard(shard)
				print(f"RECOVERED S{shard}", flush=True)
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
			line += f", {unheard} unheard"
		if self.stalled:
			line += ", stalled " + " ".join(f"S{shard}" for shard in sorted(self.stalled))
		working = [(work["quiet"] + now - work["heard"], shard, work) for shard, work in self.machines.items() if work["stage"] != "done"]
		if working:
			quiet, shard, work = max(working, key=lambda entry: entry[0])
			line += f"; slowest S{shard} {work['stage']} {work['model']}, log quiet {quiet:.0f}s: {work['line']}"
		return f"{heading} {line}"


async def build(url, ref, upload, wait, previews=(), layout=True):
	async with websockets.connect(url, max_size=MAX_MESSAGE) as socket:
		await socket.send(json.dumps({"type": "build", "ref": ref, "upload": upload, "previews": list(previews), "build": layout}))
		failed = False
		task = None
		finished = None
		started = time.time()
		progress = None
		last_news = started
		while True:
			try:
				event = json.loads(await asyncio.wait_for(socket.recv(), TICK_SECONDS))
			except asyncio.TimeoutError:
				event = None
			if progress:
				progress.tick()
			if time.time() - last_news >= wait:
				print(f"no news for {wait}s; giving up waiting (the task carries on)", flush=True)
				return 1
			if event is None:
				continue
			kind = event["type"]
			if kind == "progress":
				if progress and event["task"] == task and progress.update(event):
					last_news = time.time()
				continue
			last_news = time.time()
			if kind == "error":
				print(event["text"])
				return 1
			if kind == "posted":
				task = event["task"]
				progress = Progress(event["count"])
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
	parser.add_argument("command", choices=["status", "machines", "build", "stop-machines", "wait-machines"])
	parser.add_argument("ref", nargs="?")
	parser.add_argument("--no-upload", action="store_true")
	parser.add_argument("--wait", type=int, default=600)
	parser.add_argument("--preview", default="", help="models to render, comma-separated")
	parser.add_argument("--preview-only", action="store_true", help="render the previews without building the layout")
	arguments = parser.parse_args()
	url = control_url()
	if not url:
		print("no coordinator running (scripts/coordinator.sh start)", file=sys.stderr)
		sys.exit(2)
	if arguments.command == "status":
		code = asyncio.run(status(url))
	elif arguments.command == "machines":
		code = asyncio.run(machines(url))
	elif arguments.command == "wait-machines":
		code = asyncio.run(wait_machines(url, int(arguments.ref or 0), arguments.wait))
	elif arguments.command == "stop-machines":
		code = asyncio.run(stop_machines(url))
	else:
		if not arguments.ref:
			parser.error("build needs a commit")
		previews = [name for name in arguments.preview.split(",") if name]
		code = asyncio.run(build(url, arguments.ref, not arguments.no_upload, arguments.wait, previews, not arguments.preview_only))
	sys.exit(code)


if __name__ == "__main__":
	main()
