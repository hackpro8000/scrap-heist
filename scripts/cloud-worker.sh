#!/usr/bin/env bash
# Makes any Ubuntu 24.04 machine with this repo checked out a build worker
# for the coordinator, as the standby workflow's steps before "Wait for
# tasks" make a GitHub machine one, then runs scripts/standby-agent.py. It
# needs no GitHub secrets and does no uploads; it is admitted by a token
# from `tools/coordinator/client.py mint-workers <count>`. Safe to run
# again: whatever is already there is left alone.
#
#   scripts/cloud-worker.sh <agent address> <shard> <count> <token> [layout, default ServerMap]
#
# Pass the token as - to read it from COORDINATOR_WORKER_TOKEN instead, so
# it never shows in `ps`. The machine ends after 25 idle minutes, 30 at most.
set -euo pipefail

usage() { awk 'NR >= 9 && NR <= 12' "$0" | cut -c3-; }
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then usage; exit 0; fi
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
[ "$((10#$shard))" -ge 1 ] && [ "$((10#$shard))" -le "$((10#$count))" ] || { echo "cloud-worker: shard must be from 1 to count" >&2; exit 2; }

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

# Tools, toolchain and the websocket library (scripts/machine-setup/).
scripts/machine-setup/map-build.sh
export PATH="$HOME/.local/bin:$PATH"
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# As the workflow sets for every machine.
export MODELKIT_PRUNE=1
# The token goes by environment only; the agent takes it out before building.
export COORDINATOR_WORKER_TOKEN="$token"
unset token
exec python3 scripts/standby-agent.py "$address" "$layout" "$shard" "$count" 25 30
