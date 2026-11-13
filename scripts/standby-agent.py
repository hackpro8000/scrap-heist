#!/usr/bin/env python3
"""Keeps one standby build machine on a live connection to the coordinator
(tools/coordinator/coordinator.py): it is leased one unit of a task at a
time, builds it, and sends the results straight back, so nothing polls.

  scripts/standby-agent.py <coordinator url> <Layout> <index> <count> <idle minutes> <max minutes>

It proves who it is with the identity token GitHub gives this job (the
workflow grants id-token: write); <index> names it on the hub (g<index>).
A unit comes as {"type": "task", "id", "task", "shard", "count"} and is run
as scripts/standby.sh runs a task: its commit checked out, then that
commit's scripts/standby-task.sh as shard <shard> of <count>, into
results/<task id>-S<shard>/. Then every file there goes back to the
coordinator, the handed-over objects' names.tsv before the objects, and a
"done" message last; then the unit's share of the previews. Every message
about a unit names its task and shard. {"type": "cancel", "task", "shard"}
stops a unit (its processes killed, its folder removed) and is answered
{"type": "idle"}; a task for that unit arriving while the cancel runs starts
once it is over. Claims and bake pushes carry the unit's lease number, so
the coordinator refuses a cancelled lease's late ones. The hello names the
units still under way, so a restarted coordinator gives them back. Speaks
only to the coordinator of this commit.

Machine 1 may also be the uploader (the coordinator says so): objects
arrive over the connection and are uploaded with this job's
ROBLOX_API_KEY by tools/coordinator/uploader.py, each asset id sent back
as soon as it's known.

A dropped connection is retried with backoff (1 s doubling to 30 s); with
no coordinator for LOST_MINUTES the machine ends, freeing its slot. A task
sent again after a reconnect is not rebuilt: what it left is sent again.
The machine ends after <idle minutes> without a task, at <max minutes>, or
when the coordinator says stop.

A numbered machine (scripts/cloud-worker.sh join) passes "published" as the
url and 0 as the count. It reads the coordinator's address from
address.json on the branch build-results/coordinator-address before every
connection, so it follows a coordinator whose address changed or that was
started again, and it never gives up for lack of one. Its hello carries its
number (it is m<number> on the hub) and it takes units like any machine.
"""
import asyncio
import os
import sys

# The agent's modules live beside this script, in scripts/standby_agent/.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from standby_agent.common import (  # noqa: E402
	ADDRESS_BRANCH, AUDIENCE, CLAIM_TRIES, CLAIM_WAIT_SECONDS, HEARTBEAT_SECONDS, LOG_LINES_KEPT, LOST_MINUTES, MAX_MESSAGE,
	PART_BYTES, REQUIRED_TOOLS, ROOT, SWAP_WAIT_SECONDS, TUNNEL_ALERT_FAILURES, alert, forward, say)
from standby_agent.machine import (  # noqa: E402
	WORKER_TOKEN, ensure_tools, free_space, http_status, identity_token, kill_tree, last_line, newest_log, push_bakes, push_preview,
	remote_head, trim_log)
from standby_agent.agent import Agent  # noqa: E402
import commits  # noqa: E402,F401
import uploader as uploading  # noqa: E402,F401
import wire  # noqa: E402,F401


if __name__ == "__main__":
	if len(sys.argv) != 7:
		sys.exit(__doc__)
	asyncio.run(Agent(*sys.argv[1:]).main())
