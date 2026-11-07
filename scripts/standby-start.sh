#!/usr/bin/env bash
# Warms up standby build machines. With a coordinator running in this
# session (scripts/coordinator.sh start), they connect to it and get tasks
# live; without one, they wait on the build-queue branch as before.
#
#   scripts/standby-start.sh [machines, default 20] [ref, default wip/coordinator]

set -euo pipefail

shards="${1:-20}"
ref="${2:-wip/coordinator}"
cd "$(dirname "$0")/.."
url="$(scripts/coordinator.sh url 2> /dev/null || true)"
gh workflow run build-standby.yml -f ref="${ref}" -f shards="${shards}" -f coordinator="${url}"
if [ -n "${url}" ]; then
	echo "starting ${shards} machines; they connect to ${url} (scripts/coordinator.sh status shows them)" >&2
else
	echo "starting ${shards} machines on the build-queue branch (no coordinator running here)" >&2
fi
