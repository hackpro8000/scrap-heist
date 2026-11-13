#!/usr/bin/env bash
# Makes any Ubuntu 24.04 machine with this repo checked out a build worker
# for the coordinator, as the standby workflow's steps before "Wait for
# tasks" make a GitHub machine one, then runs scripts/standby-agent.py. It
# needs no GitHub secrets and does no uploads; it is admitted by a token
# from `tools/coordinator/client.py mint-workers <count>`. Safe to run
# again: whatever is already there is left alone.
#
#   scripts/cloud-worker.sh [--detach] <agent address> <shard> <count> <token> [layout, default ServerMap]
#   scripts/cloud-worker.sh join [<machine number> <token>]
#   scripts/cloud-worker.sh --wait [seconds]
#
# Pass the token as - to read it from COORDINATOR_WORKER_TOKEN instead, so
# it never shows in `ps`. The worker ends after 60 idle minutes, or 5 hours at
# most, which is as long as a hub lives.
#
# join makes this a numbered machine, for good: its number and lasting token
# (tools/coordinator/client.py machine-tokens) are saved in the clone's .git
# folder, and a worker starts in the background that finds the coordinator's
# address by itself (the "published" address of scripts/standby-agent.py) and
# follows it when it changes. It takes units from the hub's queue as soon as
# it connects (no seating). join without arguments starts it again from the
# saved number and token; a worker still running is replaced. That worker ends after 12 hours, or when told to.
set -euo pipefail

usage() { awk 'NR >= 9 && NR <= 22' "$0" | cut -c3-; }
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then usage; exit 0; fi
if [ "${1:-}" = "join" ]; then
	cd "$(dirname "$0")/.."
	seat="$(git rev-parse --absolute-git-dir)/scrap-worker"
	if [ $# -ge 3 ]; then
		case "$2" in ''|*[!0-9]*) echo "cloud-worker: the machine number must be a whole number" >&2; exit 2;; esac
		(umask 077; printf '%s %s\n' "$2" "$3" > "$seat")
	fi
	[ -f "$seat" ] || { echo "cloud-worker: no saved number and token here; run join <machine number> <token> once" >&2; exit 2; }
	read -r machine token < "$seat"
	# A worker still running is replaced, so joining again also takes up new
	# code; its whole process group goes, a build under way included.
	pid="$(cat /tmp/cloud-worker.pid 2> /dev/null || true)"
	if [ -n "$pid" ] && kill -0 "$pid" 2> /dev/null; then
		kill -- "-$pid" 2> /dev/null || kill "$pid" 2> /dev/null || true
		sleep 1
	fi
	# A full disk stops the worker before it can build anything.
	if [ "$(df --output=avail -BG . | tail -n 1 | tr -dc 0-9)" -lt 8 ]; then
		rm -rf art/models/*/.cache "$(git rev-parse --absolute-git-dir)"/scrap-lanes/*/art/models/*/.cache results
	fi
	export COORDINATOR_WORKER_TOKEN="$token"
	nohup setsid scripts/cloud-worker.sh published "$machine" 0 - > /tmp/cloud-worker.log 2>&1 < /dev/null &
	echo $! > /tmp/cloud-worker.pid
	echo "cloud-worker: started in the background as machine $machine (log: /tmp/cloud-worker.log)"
	exit 0
fi
# --detach: start the worker in the background and return at once, so the
# session that ran this can end its turn. The log is /tmp/cloud-worker.log.
if [ "${1:-}" = "--detach" ]; then
	shift
	[ $# -ge 4 ] || { usage >&2; exit 2; }
	[ "$4" = "-" ] || export COORDINATOR_WORKER_TOKEN="$4"
	nohup setsid "$0" "$1" "$2" "$3" - "${5:-ServerMap}" > /tmp/cloud-worker.log 2>&1 < /dev/null &
	echo $! > /tmp/cloud-worker.pid
	echo "cloud-worker: started in the background as shard $2 of $3 (log: /tmp/cloud-worker.log)"
	exit 0
fi
# --wait [seconds]: stay until the detached worker ends or the time is up
# (default 540 s), then say which. A cloud session's machine is paused a few
# minutes after its turn ends, which kills the worker, so the session keeps
# its turn open by running this again for as long as it prints "running".
if [ "${1:-}" = "--wait" ]; then
	pid="$(cat /tmp/cloud-worker.pid 2> /dev/null || true)"
	until=$((SECONDS + ${2:-540}))
	while [ -n "$pid" ] && kill -0 "$pid" 2> /dev/null && [ "$SECONDS" -lt "$until" ]; do sleep 5; done
	if [ -n "$pid" ] && kill -0 "$pid" 2> /dev/null; then
		echo "cloud-worker: running; $(tail -n 1 /tmp/cloud-worker.log 2> /dev/null | cut -c1-120)"
	else
		echo "cloud-worker: ended; $(tail -n 2 /tmp/cloud-worker.log 2> /dev/null | cut -c1-200)"
	fi
	exit 0
fi
[ $# -ge 4 ] || { usage >&2; exit 2; }
address="$1" shard="$2" count="$3" layout="${5:-ServerMap}"
if [ "$4" = "-" ]; then
	token="${COORDINATOR_WORKER_TOKEN:-}"
else
	token="$4"
fi
[ -n "$token" ] || { echo "cloud-worker: no token (argument 4, or - with COORDINATOR_WORKER_TOKEN)" >&2; exit 2; }
case "$shard" in ''|*[!0-9]*) echo "cloud-worker: shard must be a whole number" >&2; exit 2;; esac
case "$count" in ''|*[!0-9]*) echo "cloud-worker: count must be a whole number" >&2; exit 2;; esac
# A numbered machine (count 0) is m<shard> on the hub; like every machine it
# is leased one unit at a time, each naming its own shard and count.
[ "$((10#$count))" -eq 0 ] || { [ "$((10#$shard))" -ge 1 ] && [ "$((10#$shard))" -le "$((10#$count))" ]; } || { echo "cloud-worker: shard must be from 1 to count" >&2; exit 2; }

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

# Tools, toolchain and the websocket library (scripts/machine-setup/).
scripts/machine-setup/map-build.sh
export PATH="$HOME/.local/bin:$PATH"
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# As the workflow sets for every machine.
export MODELKIT_PRUNE=1
# A cloud machine that compiles a changed engine leaves it on the
# build-engine branch, so the GitHub machines take it instead of waiting.
export MODELKIT_SHARE_ENGINE=1
# The token goes by environment only; the agent takes it out before building.
export COORDINATOR_WORKER_TOKEN="$token"
unset token
if [ "$address" = "published" ]; then
	exec python3 scripts/standby-agent.py "$address" "$layout" "$shard" "$count" 720 720
fi
exec python3 scripts/standby-agent.py "$address" "$layout" "$shard" "$count" 60 300
