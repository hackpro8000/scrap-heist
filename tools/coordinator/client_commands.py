"""client.py's short commands: status, machines, numbered, clear-tasks,
mint-workers, wait-machines, stop-machines, open-workers, machine-tokens."""
import asyncio
import json
import os
import sys

import wire
from client_connection import alert, control
from client_progress import SHORT_SECONDS, lifetime_alert
from client_update import code_lines


async def status(url):
	async with control(url, {"type": "status"}) as socket:
		answer = json.loads(await socket.recv())
	up = answer["up"]
	print(f"run={answer['run']} machines={answer['count']} up={len(up)} tasks={len(answer['tasks'])} code={answer.get('code') or '?'}")
	roster = answer.get("roster", [])
	if roster:
		print("roster: " + " ".join(f"{entry['name']}={roster_state(entry)}" for entry in roster))
	for line in code_lines(answer):
		print(line)
	for task, queued in answer.get("queues", {}).items():
		state = answer.get("task_states", {}).get(task, {})
		print(f"task {task}: {state.get('done', 0)} of {state.get('count', '?')} units done, {state.get('leased', 0)} leased, {queued} queued")
	for line in status_alerts(answer):
		alert(line)
	return 0


STRANDED_AGE_SECONDS = 60  # a task younger than this may not have heard from its machines yet


def roster_state(entry):
	"""idle, stopping, S<i>@<task> for a unit, or gone-<N>s."""
	if entry.get("state") == "gone":
		return f"gone-{entry.get('gone_for', 0)}s" + (f"(S{entry['shard']})" if entry.get("shard") else "")
	if entry.get("state") == "unit":
		return f"S{entry.get('shard')}@{entry.get('task')}"
	return entry.get("state", "?")


def status_alerts(answer):
	"""The ALERT lines a status answer calls for: STRANDED_TASK, SHORT, LIFETIME."""
	now = answer["now"]
	lines = []
	states = answer.get("task_states", {})
	# Stranded: units wait in a queue and no machine is connected to take them.
	stranded = [task for task, queued in answer.get("queues", {}).items() if queued > 0
		and states.get(task, {}).get("age", STRANDED_AGE_SECONDS) >= STRANDED_AGE_SECONDS]
	if stranded and not answer["up"]:
		lines.append(f"ALERT STRANDED_TASK: {len(stranded)} open tasks ({' '.join(stranded)}) have queued units and no machine is connected "
			"| start machines (they take the units as they connect), or clear them with: tools/coordinator/client.py clear-tasks")
	started = answer.get("run_started")
	github_up = answer.get("github_up", 0)
	if started and answer["count"] and now - started >= SHORT_SECONDS and github_up < answer["count"]:
		lines.append(f"ALERT SHORT: {github_up} of {answer['count']} machines of run {answer['run']} connected {now - started:.0f}s after the run's first "
			"| check the missing jobs in the run's log (gh run view); the queue works with what is up, or start a new run")
	ending = lifetime_alert(answer, now)
	if ending:
		lines.append(ending)
	return lines


async def clear_tasks(url):
	async with control(url, {"type": "clear-tasks"}) as socket:
		answer = json.loads(await socket.recv())
	if answer.get("type") != "cleared":
		print(answer.get("text", answer), file=sys.stderr)
		return 1
	print(f"cleared {len(answer['tasks'])} tasks: {' '.join(answer['tasks'])}")
	return 0


async def mint_workers(url, count):
	"""One line per new worker: <shard> <count> <token>, for scripts/cloud-worker.sh."""
	async with control(url, {"type": "mint-workers", "count": count}) as socket:
		answer = json.loads(await socket.recv())
	if answer["type"] != "workers":
		print(answer.get("text", answer), file=sys.stderr)
		return 1
	print(f"pool {answer['pool']}", file=sys.stderr)
	for worker in answer["workers"]:
		print(f"{worker['shard']} {worker['count']} {worker['token']}")
	return 0


async def wait_machines(url, wanted, wait):
	async with control(url, {"type": "watch"}) as socket:
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


async def numbered(url):
	async with control(url, {"type": "status"}) as socket:
		print(" ".join(str(machine) for machine in json.loads(await socket.recv()).get("machines", [])))
	return 0


def open_workers():
	"""Kept so scripts that call it still work: there are no seats any more."""
	print("open-workers: nothing to do; numbered machines take units from the queue as soon as they connect", file=sys.stderr)
	return 0


def machine_tokens(first, last):
	"""One line per numbered machine: m<n>, a tab, its lasting token, made
	from the worker key on this computer (scripts/coordinator.sh worker-key)."""
	path = os.path.expanduser("~/.cache/scrap-heist/worker-key")
	if not os.path.isfile(path):
		print("no worker key on this computer (scripts/coordinator.sh worker-key makes one)", file=sys.stderr)
		return 1
	key = open(path).read().strip()
	for machine in range(first, last + 1):
		print(f"m{machine}\t{wire.machine_token(key, machine)}")
	return 0


async def stop_machines(url):
	async with control(url, {"type": "stop-machines"}) as socket:
		print(json.loads(await socket.recv()))
	return 0


async def machines(url):
	"""One line per machine: what it is doing and when it last said so."""
	async with control(url, {"type": "status"}) as socket:
		answer = json.loads(await socket.recv())
	for entry in answer.get("roster", []):
		name = entry["name"]
		work = answer["progress"].get(name)
		if entry["state"] != "unit" or not work:
			print(f"{name}: {roster_state(entry)}")
			continue
		print(f"{name}: S{entry['shard']} of {entry['task']}: {work['stage']} {work['model']} {work['seconds']}s, log quiet {work['quiet']}s, "
			f"heard {answer['now'] - work['heard']:.0f}s ago: {work['line']}")
	for task, queued in answer.get("queues", {}).items():
		print(f"task {task}: {queued} units queued")
	return 0
