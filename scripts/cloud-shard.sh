#!/usr/bin/env bash
# Builds one shard of a layout on a machine that is not on standby, such as
# a Claude cloud session machine, and sends the result home by itself: no
# coordinator, no token, no upload. The task is this checkout's own commit.
#
#   scripts/cloud-shard.sh <task> <index> <count> [layout, default ServerMap]
#
# It prepares the machine (scripts/machine-setup/map-build.sh), builds the
# shard (scripts/standby-task.sh), writes build.log, parts.txt,
# manifest.json, costs.txt and summary.txt to cloud-results/S<index>/, then
# commits that folder and pushes it to the branch cloud-results/<task>/s<index>,
# where scripts/cloud-results.sh collects it. The objects stay on the machine.
#
# So the whole job is this one command: a cloud session needs only to run it.
# It pushes even on a failed build, so the log comes home either way, and it
# exits with the build's status.
set -uo pipefail

task="${1:?task name required}"
index="${2:?shard index required}"
count="${3:?shard count required}"
layout="${4:-ServerMap}"
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
echo "shard ${index} of ${count}: build exit ${status} in $((SECONDS - started))s"

git add -f "${out}"
git -c user.name="scrap-heist cloud shard" -c user.email="cloud-shard@users.noreply.github.com" \
	commit -q -m "${task} shard ${index} of ${count}" || echo "cloud-shard: nothing to commit"
for attempt in 1 2 3 4; do
	if git push -q -f origin "HEAD:refs/heads/cloud-results/${task}/s${index}"; then
		echo "cloud-shard: pushed cloud-results/${task}/s${index}"
		break
	fi
	echo "cloud-shard: push attempt ${attempt} failed"
	sleep $((attempt * 2))
done
cat "${out}/summary.txt" 2> /dev/null || tail -n 15 "${out}/task.out"
exit "${status}"
