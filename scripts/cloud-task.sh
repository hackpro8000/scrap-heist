#!/usr/bin/env bash
# What a Claude cloud machine for map building does as it starts, with no
# prompt and no agent: the scrap-map-build environment's setup script is
#
#   if [ -d scrap-heist ]; then scrap-heist/scripts/cloud-task.sh; fi
#
# It prepares the machine (scripts/machine-setup/map-build.sh). Then, if the
# commit the session checked out is a task commit made by
# scripts/cloud-dispatch.sh ("cloud-task <task> shard <i> of <n> <Layout>"),
# it builds that shard (scripts/cloud-shard.sh) and pushes the result to
# cloud-results/<task>/s<i>, the session's own branch.
#
# It always exits 0, because a failing setup script stops the session from
# starting; what happened is in /tmp/cloud-task.log on the machine.
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}" || exit 0
exec >> /tmp/cloud-task.log 2>&1
echo "cloud-task: started $(date -u +%FT%TZ) as $(id -un) in ${root}"
git config --global --add safe.directory "${root}"

subject="$(git log -1 --format=%s)"
if [[ ! "${subject}" =~ ^cloud-task\ ([A-Za-z0-9_-]+)\ shard\ ([0-9]+)\ of\ ([0-9]+)\ ([A-Za-z0-9_]+)$ ]]; then
	scripts/machine-setup/map-build.sh || echo "cloud-task: set-up failed"
	echo "cloud-task: no task in this checkout; machine prepared"
	exit 0
fi
task="${BASH_REMATCH[1]}" index="${BASH_REMATCH[2]}" count="${BASH_REMATCH[3]}" layout="${BASH_REMATCH[4]}"
echo "cloud-task: ${task} shard ${index} of ${count} of ${layout}"

scripts/cloud-shard.sh "${index}" "${count}" "${layout}"
echo "cloud-task: build exit $?"
# Pushed even after a failed build, so the log comes home.
git -c user.name="scrap-heist cloud shard" -c user.email="cloud-shard@users.noreply.github.com" \
	commit -q -m "${task} shard ${index} of ${count}" || echo "cloud-task: nothing to commit"
for attempt in 1 2 3 4; do
	if git push -q origin "HEAD:refs/heads/cloud-results/${task}/s${index}"; then
		echo "cloud-task: pushed cloud-results/${task}/s${index}"
		exit 0
	fi
	echo "cloud-task: push attempt ${attempt} failed"
	sleep $((attempt * 2))
done
exit 0
