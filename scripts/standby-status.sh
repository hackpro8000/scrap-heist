#!/usr/bin/env bash
# Says whether build machines are on standby (build-standby workflow), and if
# so which layout, how many machines, how many are up and waiting, and when
# they started. Exits 1 when none are running.
#
#   scripts/standby-status.sh          # for people
#   scripts/standby-status.sh --line   # one line for scripts:
#                                      # run=<id> layout=<L> shards=<n> ready=<k> ref=<ref>

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"

# The newest standby run that's still going; its title carries its settings
# (run-name in build-standby.yml).
run="$(gh run list --workflow=build-standby.yml --limit 10 --json databaseId,status,displayTitle,createdAt \
	--jq '[.[] | select(.status == "in_progress" or .status == "queued")][0] | select(. != null) | "\(.databaseId)\t\(.displayTitle)\t\(.createdAt)"')"
if [ -z "${run}" ]; then
	[ "${1:-}" = "--line" ] || echo "no build machines on standby; start some with: gh workflow run build-standby.yml -f shards=8"
	exit 1
fi
IFS=$'\t' read -r id title created <<< "${run}"
layout="$(sed -n 's/^Standby \([^ ]*\) x.*/\1/p' <<< "${title}")"
shards="$(sed -n 's/^Standby [^ ]* x\([0-9]*\) .*/\1/p' <<< "${title}")"
ref="$(sed -n 's/.* from \([^ ]*\) (.*/\1/p' <<< "${title}")"
[ -n "${layout}" ] && [ -n "${shards}" ] || { echo "standby run ${id} has an unexpected title: ${title}" >&2; exit 1; }

# Machines push ready-<run id> to their results branch once they're waiting.
git fetch -q origin '+refs/heads/build-results/*:refs/remotes/origin/build-results/*' 2> /dev/null || true
ready=0
for i in $(seq 1 "${shards}"); do
	if git log -n 20 --format=%s "origin/build-results/s${i}" 2> /dev/null | grep -q "^task ready-${id} "; then
		ready=$((ready + 1))
	fi
done

if [ "${1:-}" = "--line" ]; then
	echo "run=${id} layout=${layout} shards=${shards} ready=${ready} ref=${ref}"
else
	echo "standby run ${id}: ${layout} on ${shards} machines, ${ready} up and waiting (started ${created})"
	echo "  ${title}"
	echo "  send a build with: scripts/send-build.sh <commit>"
fi
