#!/usr/bin/env bash
# Keeps one shard machine of the build-standby workflow warm: it waits for
# build tasks on the build-queue branch and builds its shard of each, with
# its cache already on disk, until no time is left.
#
#   scripts/standby.sh <Layout> <index> <count> <minutes>
#
# A task is a commit on build-queue whose task.txt holds `id=<task id>` and
# `ref=<full commit hash>` (scripts/send-build.sh posts them). Results go to
# results/<task id>/ and are pushed to build-results/s<index> as one commit
# whose message names the task. Uploads run when ROBLOX_API_KEY and
# ROBLOX_CREATOR_ID are set.

set -uo pipefail

layout="${1:?layout required}"
index="${2:?shard index required}"
count="${3:?shard count required}"
minutes="${4:?minutes required}"
deadline=$((SECONDS + minutes * 60))

say() {
	echo "standby S${index}/${count}: $*" >&2
}

queue_head() {
	git ls-remote origin refs/heads/build-queue | cut -f1
}

# Pushes a results folder as a single commit on this shard's results branch,
# through a temporary index so the checkout is left alone.
push_results() {
	local id="$1" dir="$2" index_file tree commit
	# A name only: git rejects an existing empty file as a corrupt index.
	index_file="$(mktemp -u)"
	GIT_INDEX_FILE="${index_file}" git --work-tree="${dir}" add -A
	tree="$(GIT_INDEX_FILE="${index_file}" git write-tree)"
	rm -f "${index_file}"
	commit="$(git commit-tree "${tree}" -m "task ${id} S${index}/${count}")"
	git push -q -f origin "${commit}:refs/heads/build-results/s${index}"
}

run_task() {
	local id="$1" ref="$2" started=${SECONDS} out="results/$1" status="DONE" build_seconds="-" upload="skipped"
	mkdir -p "${out}"
	say "task ${id}: building ${ref}"
	{
		git fetch -q --depth=1 origin "${ref}" &&
			git checkout -q -f FETCH_HEAD &&
			scripts/assemble-model.sh "${layout}" &&
			{
				local build_started=${SECONDS}
				scripts/build-model.sh "${layout}" -- --chunks --shard "${index}/${count}" &&
					build_seconds=$((SECONDS - build_started))
			}
	} > "${out}/build.log" 2>&1 || status="FAILED"
	if [ "${status}" = "DONE" ]; then
		python3 - "art/models/${layout}/${layout}.glb" > "${out}/parts.txt" << 'EOF' || status="FAILED"
import json, struct, sys
data = open(sys.argv[1], "rb").read()
length = struct.unpack_from("<I", data, 12)[0]
names = [node["name"] for node in json.loads(data[20:20 + length])["nodes"] if "mesh" in node]
print("\n".join(sorted(names)))
EOF
		cp "art/models/${layout}/chunks/${layout}Chunks.luau" "${out}/" 2>> "${out}/build.log" || status="FAILED"
		awk -F'\t' '$1 == "SHARD_COST" { print $2 "\t" $3 }' "${out}/build.log" > "${out}/costs.txt"
	fi
	if [ "${status}" = "DONE" ] && [ -n "${ROBLOX_API_KEY:-}" ] && [ -n "${ROBLOX_CREATOR_ID:-}" ]; then
		local upload_started=${SECONDS}
		if scripts/upload-chunks.sh "${layout}" >> "${out}/build.log" 2>&1; then
			cp "art/models/${layout}/chunks/${layout}AssetIds.txt" "${out}/"
			upload="$((SECONDS - upload_started))s"
		else
			status="FAILED"
		fi
	fi
	{
		echo "status=${status}"
		echo "build=${build_seconds}"
		echo "upload=${upload}"
		echo "total=$((SECONDS - started))"
		echo "parts=$(wc -l < "${out}/parts.txt" 2>/dev/null || echo 0)"
	} > "${out}/summary.txt"
	[ "${status}" = "DONE" ] || tail -n 30 "${out}/build.log" > "${out}/error.txt"
	push_results "${id}" "${out}" || say "task ${id}: could not push results"
	say "task ${id}: ${status} in $((SECONDS - started))s (build ${build_seconds}s)"
}

# Tasks posted since this standby run began count, even one posted while
# this machine was still starting up; older ones are ignored.
since="${STANDBY_SINCE:-$(date +%s)}"
seen="$(queue_head)"
if [ -n "${seen}" ] && git fetch -q --depth=1 origin "${seen}" && [ "$(git log -1 --format=%ct "${seen}")" -ge "${since}" ]; then
	seen=""
fi
say "waiting ${minutes} min for tasks posted since $(date -d "@${since}" +%T)"
while [ "${SECONDS}" -lt "${deadline}" ]; do
	sleep 3
	head="$(queue_head)"
	if [ -z "${head}" ] || [ "${head}" = "${seen}" ]; then
		continue
	fi
	seen="${head}"
	if ! git fetch -q --depth=1 origin "${head}"; then
		say "could not fetch task ${head}"
		continue
	fi
	task="$(git show "${head}:task.txt" 2>/dev/null)"
	id="$(sed -n 's/^id=//p' <<< "${task}")"
	ref="$(sed -n 's/^ref=//p' <<< "${task}")"
	if [ -z "${id}" ] || [ -z "${ref}" ]; then
		say "task ${head} has no id or ref"
		continue
	fi
	run_task "${id}" "${ref}"
done
say "standby over"
