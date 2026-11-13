#!/usr/bin/env python3
"""Sends one message of the owner's own to many reserved cloud build machines
at once, from this computer's terminal. Unlike scripts/machine-send.py, the
message goes exactly as typed, with nothing added: run this yourself, so the
words each machine receives are yours.

  scripts/machine-prompt.py [--machines 1-100] [--parallel 4] [--clear] [--dry-run] "<message>"
  scripts/machine-prompt.py --machines 4-9,12 - < message.txt
  scripts/machine-prompt.py --edit --clear --machines 1-6

--edit does it all in one command: it opens the message in your editor
($EDITOR, else nano; the last message is kept in
~/.cache/scrap-heist/message.txt), shows what would be sent, and sends once
you answer y.

Every {n} in the message becomes the machine's number (m7 gets 7). {pr}
becomes the number of that machine's wake-up pull request and {token} its
hub worker token, from ~/.cache/scrap-heist/prs.tsv and tokens.tsv (machine,
value). --clear
sends /clear to each machine first, so it starts with an empty conversation.
Machines come from ~/.cache/scrap-heist/machines.tsv (machine, session id).
Each send is a short-lived `claude -p --cloud <session>`; a send that fails
(parallel sends sometimes collide on the login token) is tried up to 3 times.
"""
import argparse
import concurrent.futures
import os
import shlex
import subprocess
import sys
import time

REGISTRY = os.path.expanduser("~/.cache/scrap-heist/machines.tsv")
DRAFT = os.path.expanduser("~/.cache/scrap-heist/message.txt")
# Per-machine values a message can name: placeholder, then its file.
VALUES = {"pr": os.path.expanduser("~/.cache/scrap-heist/prs.tsv"), "token": os.path.expanduser("~/.cache/scrap-heist/tokens.tsv")}
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def parse_machines(text):
	numbers = set()
	for part in text.split(","):
		first, _, last = part.partition("-")
		numbers.update(range(int(first), int(last or first) + 1))
	return numbers


def fill(message, number, values):
	for name, path in VALUES.items():
		if "{" + name + "}" in message:
			if number not in values[name]:
				sys.exit(f"m{number} has no entry in {path}")
			message = message.replace("{" + name + "}", values[name][number])
	return message.replace("{n}", str(number))


def send_once(session, message):
	# Without MCP servers, settings beyond the user's and slash commands, a
	# send costs about 1.3 s of CPU instead of 3.9 s (measured 2026-11-11).
	command = ("claude -p --strict-mcp-config --mcp-config '{\"mcpServers\":{}}' --disable-slash-commands"
		" --setting-sources user --cloud " + shlex.quote(session) + " " + shlex.quote(message))
	# Input from /dev/null: given the terminal, `script` would switch it to raw
	# mode and stagger every line printed afterwards.
	result = subprocess.run(["script", "-qfc", command, "/dev/null"], stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=120, cwd=ROOT)
	ok = result.returncode == 0 and "Sent to cloud session" in result.stdout
	return ok, (result.stdout + result.stderr).strip().splitlines()[-1:]


def send(session, message):
	tail = []
	for attempt in range(3):
		ok, tail = send_once(session, message)
		if ok:
			return True, []
		time.sleep(1 + attempt)
	return False, tail


def deliver(number, session, message, clear):
	started = time.time()
	if clear:
		ok, tail = send(session, "/clear")
		if not ok:
			return False, time.time() - started, ["clear failed:"] + tail
	ok, tail = send(session, message)
	return ok, time.time() - started, tail


def main():
	parser = argparse.ArgumentParser(description="Send one message to many reserved cloud build machines.")
	parser.add_argument("message", nargs="?", help="the message, or - to read it from standard input")
	parser.add_argument("--edit", action="store_true", help="write the message in your editor, preview it, then confirm")
	parser.add_argument("--machines", default="", help="machine numbers, such as 1-50 or 4-9,12 (default: all)")
	# This computer has 4 threads; more senders than that only queue for CPU.
	parser.add_argument("--parallel", type=int, default=4)
	parser.add_argument("--clear", action="store_true", help="send /clear to each machine first")
	parser.add_argument("--dry-run", action="store_true", help="print what would be sent and send nothing")
	arguments = parser.parse_args()

	if arguments.edit:
		if arguments.message and arguments.message != "-":
			with open(DRAFT, "w") as draft:
				draft.write(arguments.message + "\n")
		subprocess.run(shlex.split(os.environ.get("EDITOR", "nano")) + [DRAFT], check=True)
		with open(DRAFT) as draft:
			message = draft.read().strip()
	else:
		message = sys.stdin.read().strip() if arguments.message == "-" else arguments.message
	if not message:
		sys.exit("no message to send")
	wanted = parse_machines(arguments.machines) if arguments.machines else None
	machines = []
	with open(REGISTRY) as registry:
		for line in registry:
			name, session = line.split()
			number = int(name[1:])
			if wanted is None or number in wanted:
				machines.append((number, session))
	if not machines:
		sys.exit("no machines match")
	values = {name: {} for name in VALUES}
	for name, path in VALUES.items():
		if os.path.exists(path):
			with open(path) as listing:
				for line in listing:
					machine, value = line.split()
					values[name][int(machine[1:])] = value
	# Stops here, before anything is sent, if a machine lacks a value.
	for number, _session in machines:
		fill(message, number, values)

	if arguments.dry_run:
		for number, session in machines:
			print(f"m{number} ({session}){' after /clear' if arguments.clear else ''}: {fill(message, number, values)}")
		print(f"{len(machines)} machines, nothing sent")
		return 0

	if arguments.edit:
		number = machines[0][0]
		print(f"To {len(machines)} machines (m{machines[0][0]} to m{machines[-1][0]}){' after /clear' if arguments.clear else ''}. m{number} gets:\n")
		print(fill(message, number, values) + "\n")
		try:
			answer = input(f"Send to {len(machines)} machines? [y/N] ")
		except (KeyboardInterrupt, EOFError):
			answer = ""
			print()
		if answer.strip().lower() != "y":
			print("nothing sent")
			return 0

	started = time.time()
	failed = 0
	with concurrent.futures.ThreadPoolExecutor(arguments.parallel) as pool:
		futures = {pool.submit(deliver, number, session, fill(message, number, values), arguments.clear): number for number, session in machines}
		for future in concurrent.futures.as_completed(futures):
			ok, seconds, tail = future.result()
			failed += not ok
			print(f"m{futures[future]}: {'sent' if ok else 'FAILED'} in {seconds:.1f}s {' '.join(tail)}", flush=True)
	print(f"{len(machines) - failed} of {len(machines)} sent in {time.time() - started:.1f}s with {arguments.parallel} at a time")
	return 1 if failed else 0


if __name__ == "__main__":
	sys.exit(main())
