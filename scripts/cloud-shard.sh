#!/usr/bin/env bash
# Builds one shard of a layout on a machine that is not on standby, such as
# a Claude cloud session machine, and leaves the result where the session
# can commit it. No coordinator, no token and no upload: the task is this
# checkout's own commit, and the result goes home as a commit on the
# session's branch (scripts/cloud-results.sh collects them).
#
#   scripts/cloud-shard.sh <index> <count> [layout, default ServerMap]
#
# It prepares the machine (scripts/machine-setup/map-build.sh), runs
# scripts/standby-task.sh for the shard, and writes build.log, parts.txt,
# manifest.json, costs.txt and summary.txt to cloud-results/S<index>/. The
# objects stay on the machine. It then stages that folder, so all that is
# left is `git commit` and `git push`.
set -uo pipefail

index="${1:?shard index required}"
count="${2:?shard count required}"
layout="${3:-ServerMap}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"

scripts/machine-setup/map-build.sh || exit 1
export PATH="${HOME}/.local/bin:${PATH}"
[ -f "${HOME}/.cargo/env" ] && . "${HOME}/.cargo/env"
# As the workflow sets for every machine.
export MODELKIT_PRUNE=1

out="${root}/cloud-results/S${index}"
rm -rf "${out}"
mkdir -p "${out}"
printf 'ref=%s\nupload=no\n' "$(git rev-parse HEAD)" > "${out}/task.txt"
started="${SECONDS}"
scripts/standby-task.sh "${layout}" "${index}" "${count}" "${out}" > "${out}/task.out" 2>&1
status=$?
rm -rf "${out}/handed"
{
	echo "machine=$(nproc) cores, $(awk '/MemTotal/ {printf "%d MB", $2 / 1024}' /proc/meminfo)"
	echo "seconds=$((SECONDS - started))"
	echo "exit=${status}"
} > "${out}/machine.txt"
git add -f "${out}"
echo "shard ${index} of ${count}: exit ${status} in $((SECONDS - started))s"
cat "${out}/summary.txt" 2> /dev/null || tail -n 15 "${out}/task.out"
exit "${status}"
