#!/usr/bin/env bash
# Builds one shard of a layout on a machine that is not on standby, such as
# a Claude cloud session machine, and sends the result home by itself: no
# coordinator, no token, no upload. The task is this checkout's own commit.
#
#   scripts/cloud-shard.sh <task> <index> <count> [commit]
#
# It prepares the machine (scripts/machine-setup/map-build.sh), builds the
# shard of ServerMap (scripts/standby-task.sh), writes build.log, parts.txt,
# manifest.json, costs.txt and summary.txt to cloud-results/S<index>/, then
# commits that folder and pushes it, where scripts/cloud-results.sh collects
# it. The objects stay on the machine.
#
# Without a commit it builds this checkout and pushes to the branch
# cloud-results/<task>/s<index>. With one (a reused machine), it fetches and
# builds that commit and pushes to the machine's own slot branch,
# cloud/m<index>, overwriting the last task there, so reuse leaves no new
# branches. The commit message names the task either way.
#
# So the whole job is this one command: a cloud session needs only to run it.
# It pushes even on a failed build, so the log comes home either way, puts
# back the files a build regenerates (the layout's model.luau, the engine
# binary) so the checkout is left clean, and exits with the build's status.
set -uo pipefail

task="${1:?task name required}"
index="${2:?shard index required}"
count="${3:?shard count required}"
commit="${4:-}"
layout=ServerMap
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"

branch="cloud-results/${task}/s${index}"
if [ -n "${commit}" ]; then
	branch="cloud/m${index}"
	if [ "$(git rev-parse HEAD)" != "$(git rev-parse -q --verify "${commit}^{commit}" 2> /dev/null)" ]; then
		git fetch -q origin "${commit}" || { echo "cloud-shard: could not fetch ${commit}" >&2; exit 1; }
		git checkout -q -f --detach FETCH_HEAD || exit 1
		# Run the fetched commit's own copy of this script.
		exec scripts/cloud-shard.sh "${task}" "${index}" "${count}" "${commit}"
	fi
fi

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
	if git push -q -f origin "HEAD:refs/heads/${branch}"; then
		echo "cloud-shard: pushed ${branch}"
		break
	fi
	echo "cloud-shard: push attempt ${attempt} failed"
	sleep $((attempt * 2))
done
# A build regenerates the layout's model.luau and may refresh the engine
# binary; put them back so the checkout is clean for the next task.
git checkout -q -- art/models tools/modelkit/bin 2> /dev/null || true
cat "${out}/summary.txt" 2> /dev/null || tail -n 15 "${out}/task.out"
exit "${status}"
