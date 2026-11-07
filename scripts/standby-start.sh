#!/usr/bin/env bash
# Warms up standby build machines. With a coordinator running in this
# session (scripts/coordinator.sh start), they connect to it and get tasks
# live; without one, they wait on the build-queue branch as before.
#
#   scripts/standby-start.sh [machines, default 20] [ref, default wip/coordinator]
#   scripts/standby-start.sh --on-machine [machines] [ref]
#
# --on-machine, for a session that can't connect out: build machine 1 runs
# the coordinator and does the uploads, and this session reaches it through
# the build-queue branch. Needs the repo's TS_AUTHKEY secret.

set -euo pipefail

on_machine=no
if [ "${1:-}" = "--on-machine" ]; then
	on_machine=yes
	shift
fi
shards="${1:-20}"
ref="${2:-wip/coordinator}"
cd "$(dirname "$0")/.."
if [ "${on_machine}" = yes ]; then
	url="machine-1"
else
	url="$(scripts/coordinator.sh url 2> /dev/null || true)"
fi
# One standby at a time: an older run still up would hold the account's
# machine slots and this one would wait behind it in GitHub's queue.
for old in $(gh run list --workflow build-standby.yml --limit 20 --json databaseId,status \
	--jq '.[] | select(.status == "in_progress" or .status == "queued" or .status == "waiting") | .databaseId'); do
	echo "stopping standby run ${old} first" >&2
	gh run cancel "${old}" > /dev/null || true
done
branch="$(git rev-parse --abbrev-ref HEAD)"
gh workflow run build-standby.yml --ref "${branch}" -f ref="${ref}" -f shards="${shards}" -f coordinator="${url}"
# Say straight away if GitHub holds the run back.
sleep 8
state="$(gh run list --workflow build-standby.yml --limit 1 --json status,databaseId --jq '.[0] | "\(.databaseId) \(.status)"')"
echo "standby run ${state}" >&2
case "${state}" in *queued*) echo "warning: the run is queued; another run may still hold the machine slots (gh run list)" >&2 ;; esac
if [ "${url}" = "machine-1" ]; then
	echo "starting ${shards} machines; machine 1 coordinates and uploads, tasks go by the build-queue branch" >&2
elif [ -n "${url}" ]; then
	echo "starting ${shards} machines; they connect to ${url} (scripts/coordinator.sh status shows them)" >&2
else
	echo "starting ${shards} machines on the build-queue branch (no coordinator running here)" >&2
fi
