"""The standby agent's settings and its log lines (say, alert), which also
go to the coordinator through `forward` once connected (agent.session)."""
import os
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "coordinator"))

MAX_MESSAGE = 64 * 1024 * 1024
LOST_MINUTES = 3
ADDRESS_BRANCH = "build-results/coordinator-address"
HEARTBEAT_SECONDS = 10
CLAIM_WAIT_SECONDS = 15
CLAIM_TRIES = 4
LOG_LINES_KEPT = 200
REQUIRED_TOOLS = ("rg", "sd", "jq")
AUDIENCE = "scrap-heist-coordinator"
# A file bigger than this goes in parts, so heartbeats get onto the wire
# between them instead of waiting behind the whole file (send_file).
PART_BYTES = 1024 * 1024
# Failed connections in a row before ALERT TUNNEL_DOWN.
TUNNEL_ALERT_FAILURES = 3


# Lines also go to the coordinator, live, once connected (Agent.session).
forward = None


def say(message):
	# Wall-clock time to the millisecond, so a build's steps can be lined up
	# across machines (GitHub's runners keep their clocks synced).
	now = time.time()
	message = f"{time.strftime('%H:%M:%S', time.gmtime(now))}.{int(now % 1 * 1000):03d} {message}"
	print(f"agent: {message}", file=sys.stderr, flush=True)
	if forward:
		forward(message)


def alert(line):
	"""An ALERT or CLEARED line (docs/plans/multi-machine.md, Alerts): alone
	on its line in the job log, and passed to the hub when connected."""
	print(line, file=sys.stderr, flush=True)
	if forward:
		forward(line)
