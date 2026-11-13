#!/usr/bin/env python3
"""Talks to the running coordinator (coordinator.py) from this session.

  tools/coordinator/client.py status          # the run, the roster by name, queued units per task
  tools/coordinator/client.py machines        # what each machine is doing now
  tools/coordinator/client.py build <commit> [--no-upload] [--wait S] [--preview A,B] [--preview-only] [--units N]
  tools/coordinator/client.py stop-machines   # standby machines end now
  tools/coordinator/client.py clear-tasks     # drop open tasks (after ALERT STRANDED_TASK)
  tools/coordinator/client.py mint-workers <count>
  tools/coordinator/client.py open-workers    # no longer needed: says so and does nothing
  tools/coordinator/client.py numbered        # the numbers of the numbered machines connected, one line
  tools/coordinator/client.py machine-tokens <first> <last>  # no coordinator needed
                                              # tokens for a new pool of workers
                                              # (scripts/cloud-worker.sh), one
                                              # line each: <shard> <count> <token>
  tools/coordinator/client.py wait-machines [N] [--wait S]
                                              # returns once N machines are up
                                              # (default: all of the run)
  tools/coordinator/client.py update <full sha> [--force] [--wait S]
                                              # hot update: the hub and every machine
                                              # move to that commit (default wait 180 s)
  tools/coordinator/client.py engine <full sha> [--wait S]
                                              # compile the engine on one machine with
                                              # cargo; exits 1 on a failed compile

While it waits, `build` prints a summary every 30 seconds and a line starting
STALL that names any machine that goes quiet (RECOVERED when it comes back).
`status` and `build` print abnormalities as one line each, starting ALERT
<KIND>: (CLEARED <KIND> when one resolves); the kinds are listed in
docs/plans/multi-machine.md, Alerts.

`build` posts a task, which the hub cuts into units (one per machine
connected, or --units N) and leases to machines as they come free
(docs/plans/multi-machine.md, Pull queue). Preview shares are sized by each
model's measured machine-seconds, kept in ~/.cache/scrap-heist/preview-seconds.json
and updated after every task. It prints each unit's result (S<i>, with the
machine that built it) the moment it arrives, and ALERT REDEALT when the
hub takes a unit back from a machine and gives it to another, then the upload's, and exits 0 when every machine built and every
object uploaded. Results land in .standby-results/<task>/ for
scripts/merge-shards.sh. With --preview, the machines also render those
models with modelkit; each machine's renders come back with its result,
often before the uploads end; the coordinator puts them in
art/models/<Name>/ (preview.png, views.png) and each is printed as it
lands. Exits 2 when no
coordinator is running.

From a coordinator on machine 1 (--relay-results) the results come over
the connection as files, are written here under the same paths, and an
uploaded task is merged here (scripts/merge-shards.sh).

If the connection drops mid-task (the coordinator restarting), `build`
reconnects for up to 60 s and watches the same task again; it exits 3 if
the task is unknown there, the coordinator stays gone, or a build has
used its 5 reconnects or 180 s of reconnecting.
"""
import argparse
import asyncio
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# The modules below hold the code; every name client.py had is still importable from it.
import wire  # noqa: E402,F401
from client_connection import (ROOT, STATE, CONTROL_KEY, CONTROL_NAMESPACE, MAX_MESSAGE, RECONNECT_SECONDS,  # noqa: E402,F401
	MAX_RECONNECTS, RECONNECT_BUDGET_SECONDS, control_url, Control, sign, connect, alert, http_status, control, watch_again)
from client_progress import (TICK_SECONDS, SUMMARY_SECONDS, STEP_STALL_SECONDS, SILENT_STALL_SECONDS, WEDGED_SECONDS,  # noqa: E402,F401
	SILENT_REDEAL_SECONDS, SHORT_SECONDS, ALL_FAILED_SECONDS, LOW_GB, LIFETIME_WARN_SECONDS, lifetime_alert, Progress)
from client_commands import (STRANDED_AGE_SECONDS, status, roster_state, status_alerts, clear_tasks, mint_workers,  # noqa: E402,F401
	wait_machines, numbered, open_workers, machine_tokens, stop_machines, machines)
from client_previews import PREVIEW_SECONDS, model_bytes, load_preview_seconds, preview_weights, save_preview_seconds  # noqa: E402,F401
from client_relay import (RELAYED_REPO_FILE, TASK_ID, LAYOUT_NAME, MAX_RELAYED_FILES, MAX_RELAYED_BYTES,  # noqa: E402,F401
	relayed_path, write_relayed, merge_here)
from client_build import TASK_EVENTS, build, follow, resolve_ref  # noqa: E402,F401
from client_update import engine, update  # noqa: E402


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("command", choices=["status", "machines", "build", "stop-machines", "wait-machines", "mint-workers", "open-workers",
		"machine-tokens", "numbered", "clear-tasks", "update", "engine"])
	parser.add_argument("ref", nargs="?")
	parser.add_argument("last", nargs="?")
	parser.add_argument("--no-upload", action="store_true")
	parser.add_argument("--no-seat", action="store_true", help="build: accepted and ignored; there are no seats any more")
	parser.add_argument("--units", type=int, default=0, help="build: cut the task into this many units (default: one per machine connected)")
	parser.add_argument("--wait", type=int, default=None, help="seconds (build, wait-machines 600; update 180; engine 900)")
	parser.add_argument("--force", action="store_true", help="update: even with tasks open")
	parser.add_argument("--preview", default="", help="models to render, comma-separated")
	parser.add_argument("--preview-only", action="store_true", help="render the previews without building the layout")
	arguments = parser.parse_args()
	if arguments.command == "machine-tokens":
		if not (arguments.ref or "").isdigit() or not (arguments.last or arguments.ref).isdigit():
			parser.error("machine-tokens needs a first and last machine number")
		sys.exit(machine_tokens(int(arguments.ref), int(arguments.last or arguments.ref)))
	url = control_url()
	if not url:
		print("no coordinator running (scripts/coordinator.sh start)", file=sys.stderr)
		sys.exit(2)
	if arguments.command == "status":
		code = asyncio.run(status(url))
	elif arguments.command == "machines":
		code = asyncio.run(machines(url))
	elif arguments.command == "wait-machines":
		code = asyncio.run(wait_machines(url, int(arguments.ref or 0), arguments.wait or 600))
	elif arguments.command in ("update", "engine"):
		if not re.fullmatch(r"[0-9a-f]{40}", arguments.ref or ""):
			parser.error(f"{arguments.command} needs a full 40-character commit sha")
		if arguments.command == "update":
			code = asyncio.run(update(url, arguments.ref, arguments.force, arguments.wait or 180))
		else:
			code = asyncio.run(engine(url, arguments.ref, arguments.wait or 900))
	elif arguments.command == "stop-machines":
		code = asyncio.run(stop_machines(url))
	elif arguments.command == "clear-tasks":
		code = asyncio.run(clear_tasks(url))
	elif arguments.command == "open-workers":
		code = open_workers()
	elif arguments.command == "numbered":
		code = asyncio.run(numbered(url))
	elif arguments.command == "mint-workers":
		if not (arguments.ref or "").isdigit():
			parser.error("mint-workers needs a count")
		code = asyncio.run(mint_workers(url, int(arguments.ref)))
	else:
		if not arguments.ref:
			parser.error("build needs a commit")
		ref, why = resolve_ref(arguments.ref)
		if not ref:
			alert(f"ALERT BAD_REF: {arguments.ref} is not a commit the machines can fetch from GitHub ({why}) "
				"| push it first (scripts/push-wip.sh for unfinished work) and post again")
			sys.exit(1)
		previews = [name for name in arguments.preview.split(",") if name]
		if arguments.no_seat:
			print("--no-seat: nothing to do; every connected machine takes units from the queue", file=sys.stderr)
		code = asyncio.run(build(url, ref, not arguments.no_upload, arguments.wait or 600, previews, not arguments.preview_only,
			arguments.units or None))
	sys.exit(code)


if __name__ == "__main__":
	main()
