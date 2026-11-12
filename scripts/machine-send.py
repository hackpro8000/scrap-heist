#!/usr/bin/env python3
"""Delivers build orders to the reserved cloud build machines from this
computer's terminal, many at once. Each order goes as a message from the
owner's own `claude -p --cloud <session>` (which, unlike a message from
another session, wakes a machine that was paused while idle), marked as
written by Claude on the owner's behalf.

  scripts/machine-orders.sh <task> <count> <commit> | scripts/machine-send.py [--parallel N] [--only 3,7,12]

Reads "<session id> <message>" lines (lines starting with # are skipped),
runs up to N senders at a time (default 4, one per CPU thread; each is a
short-lived claude process, about 2 s and 1.3 s of CPU), and prints one line per order and the total time.
"""
import argparse
import concurrent.futures
import os
import shlex
import subprocess
import sys
import time

MARK = "Written by Claude, my coordinating session, on my behalf (I approved sending build orders this way). "


def send(session, message):
	started = time.time()
	# Without MCP servers, settings beyond the user's and slash commands, a
	# send costs about 1.3 s of CPU instead of 3.9 s (measured 2026-11-11).
	command = ("claude -p --strict-mcp-config --mcp-config '{\"mcpServers\":{}}' --disable-slash-commands"
		" --setting-sources user --cloud " + shlex.quote(session) + " " + shlex.quote(MARK + message))
	result = subprocess.run(["script", "-qfc", command, "/dev/null"], capture_output=True, text=True, timeout=120,
		cwd=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
	ok = result.returncode == 0 and "Sent to cloud session" in result.stdout
	return ok, time.time() - started, (result.stdout + result.stderr).strip().splitlines()[-1:] if not ok else []


def main():
	parser = argparse.ArgumentParser()
	# This computer has 4 threads; more senders than that only queue for CPU.
	parser.add_argument("--parallel", type=int, default=4)
	parser.add_argument("--only", default="", help="comma-separated shard numbers to send")
	arguments = parser.parse_args()
	only = {int(n) for n in arguments.only.split(",") if n}
	orders = []
	for line in sys.stdin:
		line = line.strip()
		if not line or line.startswith("#"):
			continue
		session, message = line.split(" ", 1)
		shard = int(message.split()[2])
		if only and shard not in only:
			continue
		orders.append((shard, session, message))
	started = time.time()
	failed = 0
	with concurrent.futures.ThreadPoolExecutor(arguments.parallel) as pool:
		futures = {pool.submit(send, session, message): shard for shard, session, message in orders}
		for future in concurrent.futures.as_completed(futures):
			ok, seconds, tail = future.result()
			failed += not ok
			print(f"m{futures[future]}: {'sent' if ok else 'FAILED'} in {seconds:.1f}s {' '.join(tail)}", flush=True)
	print(f"{len(orders) - failed} of {len(orders)} orders sent in {time.time() - started:.1f}s with {arguments.parallel} at a time")
	return 1 if failed else 0


if __name__ == "__main__":
	sys.exit(main())
