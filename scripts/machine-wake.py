#!/usr/bin/env python3
"""Wakes numbered cloud build machines that were paused, so each starts its
worker again and rejoins the hub: one comment, "order: wake", on each
machine's wake-up pull request (~/.cache/scrap-heist/prs.tsv: machine, pull
request number). Each session is subscribed to its own pull request and
holds a standing instruction to rejoin on that comment
(scripts/machine-prompt.py sent both).

  scripts/machine-wake.py                 # every machine not on the hub now
  scripts/machine-wake.py --machines 4-9,12
  scripts/machine-wake.py --dry-run

GitHub takes about 80 new comments a minute from one account, so more than
70 go in groups a minute apart.
"""
import argparse
import json
import os
import subprocess
import sys
import time

PULL_REQUESTS = os.path.expanduser("~/.cache/scrap-heist/prs.tsv")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GROUP = 70
BATCH = 10


def graphql(query):
	result = subprocess.run(["gh", "api", "graphql", "-f", "query=" + query], capture_output=True, text=True, cwd=ROOT)
	try:
		reply = json.loads(result.stdout)
	except ValueError:
		return {}, [{"message": (result.stderr or result.stdout).strip()[:200]}]
	return reply.get("data") or {}, reply.get("errors") or []


def parse_machines(text):
	numbers = set()
	for part in text.split(","):
		first, _, last = part.partition("-")
		numbers.update(range(int(first), int(last or first) + 1))
	return numbers


def main():
	parser = argparse.ArgumentParser(description="Wake paused cloud build machines.")
	parser.add_argument("--machines", default="", help="machine numbers, such as 4-9,12 (default: those not on the hub)")
	parser.add_argument("--dry-run", action="store_true", help="print who would be woken and send nothing")
	arguments = parser.parse_args()

	pull_requests = {}
	with open(PULL_REQUESTS) as listing:
		for line in listing:
			name, number = line.split()
			pull_requests[int(name[1:])] = int(number)
	if arguments.machines:
		wanted = sorted(parse_machines(arguments.machines))
	else:
		connected = subprocess.run([sys.executable, "tools/coordinator/client.py", "numbered"], capture_output=True, text=True, cwd=ROOT)
		if connected.returncode != 0:
			sys.exit("could not ask the hub who is connected: " + connected.stderr.strip()[-200:])
		on_hub = {int(number) for number in connected.stdout.split()}
		wanted = sorted(set(pull_requests) - on_hub)
	missing = [machine for machine in wanted if machine not in pull_requests]
	if missing:
		sys.exit("no wake-up pull request for: " + " ".join(f"m{machine}" for machine in missing))
	if not wanted:
		print("every machine is on the hub; nobody to wake")
		return 0
	print(f"waking {len(wanted)}: " + " ".join(f"m{machine}" for machine in wanted))
	if arguments.dry_run:
		return 0

	owner, name = subprocess.run(["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"],
		capture_output=True, text=True, cwd=ROOT, check=True).stdout.strip().split("/")
	failed = []
	for start in range(0, len(wanted), GROUP):
		if start:
			time.sleep(60)
		group = wanted[start:start + GROUP]
		# Comments are added by node id, so look the ids up first, all in one request.
		lookups = " ".join(f"p{machine}: pullRequest(number: {pull_requests[machine]}) {{ id }}" for machine in group)
		data, errors = graphql(f'{{ repository(owner: "{owner}", name: "{name}") {{ {lookups} }} }}')
		ids = {machine: (data.get("repository", {}).get(f"p{machine}") or {}).get("id") for machine in group}
		# A request with dozens of comments in it comes back HTTP 502, so they
		# go BATCH at a time; a batch that fails is sent once more (a second
		# comment only makes a machine rejoin twice).
		failed += [machine for machine in group if not ids[machine]]
		found = [machine for machine in group if ids[machine]]
		for at in range(0, len(found), BATCH):
			batch = found[at:at + BATCH]
			comments = " ".join(f'c{machine}: addComment(input: {{subjectId: {json.dumps(ids[machine])}, body: "order: wake"}}) {{ clientMutationId }}'
				for machine in batch)
			for attempt in (1, 2):
				data, more = graphql(f"mutation {{ {comments} }}")
				if all(data.get(f"c{machine}") is not None for machine in batch):
					break
				if attempt == 2:
					errors += more
					failed += [machine for machine in batch if data.get(f"c{machine}") is None]
				else:
					time.sleep(3)
		for error in errors[:3]:
			print("GitHub: " + str(error.get("message", error))[:200], file=sys.stderr)
	print(f"{len(wanted) - len(failed)} of {len(wanted)} woken")
	if failed:
		print("not woken: " + ",".join(str(machine) for machine in failed) + " (try them again with --machines)", file=sys.stderr)
	return 1 if failed else 0


if __name__ == "__main__":
	sys.exit(main())
