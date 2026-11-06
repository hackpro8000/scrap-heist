#!/usr/bin/env bash
# Keeps one shard machine of the build-standby workflow warm: it builds its
# shard once to warm up, then waits for build tasks on the build-queue branch
# and builds its shard of each, with its cache already on disk, until no time
# is left.
#
#   scripts/standby.sh <Layout> <index> <count> <minutes>
#
# The queue is a branch of task files, tasks/<task id>.txt, each holding
# `ref=<full commit hash>`; scripts/send-build.sh adds them. Every task
# posted since this machine came up (STANDBY_SINCE) is built once, oldest
# first. Results go to results/<task id>/ and are pushed to
# build-results/s<index> as a new commit on top of the earlier ones, its
# message naming the task. Uploads run when ROBLOX_API_KEY and
# ROBLOX_CREATOR_ID are set. STANDBY_WARM=0 skips the warm-up build.

set -uo pipefail

layout="${1:?layout required}"
index="${2:?shard index required}"
count="${3:?shard count required}"
minutes="${4:?minutes required}"
deadline=$((SECONDS + minutes * 60))
since="${STANDBY_SINCE:-$(date +%s)}"
results_branch="build-results/s${index}"

say() {
	echo "standby S${index}/${count}: $*" >&2
}

queue_head() {
	git ls-remote origin refs/heads/build-queue | cut -f1
}

# Builds this machine's shard of whatever is checked out into `out`, writing
# build.log, parts.txt, the chunk manifest, costs.txt and summary.txt.
build_shard() {
	local out="$1" started=${SECONDS} status="DONE" build_seconds="-" upload="skipped"
	mkdir -p "${out}"
	{
		scripts/assemble-model.sh "${layout}" &&
			{
				local build_started=${SECONDS}
				scripts/build-model.sh "${layout}" -- --chunks --shard "${index}/${count}" &&
					build_seconds=$((SECONDS - build_started))
			}
	} >> "${out}/build.log" 2>&1 || status="FAILED"
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
	echo "${status} in $((SECONDS - started))s (build ${build_seconds}s)"
}

# Pushes a results folder as a new commit on this shard's results branch,
# on top of the earlier results, through a temporary index so the checkout
# is left alone.
push_results() {
	local id="$1" dir="$2" index_file tree commit parent=()
	# A name only: git rejects an existing empty file as a corrupt index. The
	# work tree must be absolute, or git adds nothing from here; and --sparse,
	# or the workflow's sparse checkout skips every file in it.
	index_file="$(mktemp -u)"
	GIT_INDEX_FILE="${index_file}" git --work-tree="$(cd "${dir}" && pwd)" add -A --sparse
	tree="$(GIT_INDEX_FILE="${index_file}" git write-tree)"
	rm -f "${index_file}"
	if git fetch -q --depth=1 origin "refs/heads/${results_branch}" 2> /dev/null; then
		parent=(-p "$(git rev-parse FETCH_HEAD)")
	fi
	commit="$(git commit-tree "${tree}" "${parent[@]}" -m "task ${id} S${index}/${count}")"
	git push -q origin "${commit}:refs/heads/${results_branch}"
}

run_task() {
	local id="$1" ref="$2" out="results/$1" result
	mkdir -p "${out}"
	say "task ${id}: building ${ref}"
	if git fetch -q --depth=1 origin "${ref}" > "${out}/build.log" 2>&1 && git checkout -q -f FETCH_HEAD >> "${out}/build.log" 2>&1; then
		result="$(build_shard "${out}")"
	else
		{ echo "status=FAILED"; echo "build=-"; echo "upload=skipped"; echo "total=0"; echo "parts=0"; } > "${out}/summary.txt"
		tail -n 30 "${out}/build.log" > "${out}/error.txt"
		result="FAILED: could not check out ${ref}"
	fi
	push_results "${id}" "${out}" || say "task ${id}: could not push results"
	say "task ${id}: ${result}"
}

# The first build on a fresh machine is the slow one, so do it now, from the
# commit standby started on, rather than on the first task.
if [ "${STANDBY_WARM:-1}" != "0" ]; then
	say "warming up: $(build_shard results/warm-up)"
	# Its result doubles as a signal that this machine is warm and waiting.
	push_results "warm-up-${GITHUB_RUN_ID:-local}" results/warm-up || say "could not push the warm-up result"
fi

declare -A built=()
seen=""
say "waiting ${minutes} min for tasks posted since $(date -d "@${since}" +%T)"
while [ "${SECONDS}" -lt "${deadline}" ]; do
	head="$(queue_head)"
	if [ -n "${head}" ] && [ "${head}" != "${seen}" ] && git fetch -q --depth=1 origin "${head}"; then
		seen="${head}"
		# Task ids start with the time they were posted (t<seconds>-...), so
		# they sort oldest first and tell which were posted since this machine
		# came up.
		for file in $(git ls-tree --name-only "${head}" tasks/ | sort); do
			id="$(basename "${file}" .txt)"
			posted="$(sed -n 's/^t\([0-9]*\).*/\1/p' <<< "${id}")"
			if [ -n "${built[${id}]:-}" ] || [ -z "${posted}" ] || [ "${posted}" -lt "${since}" ]; then
				continue
			fi
			built[${id}]=1
			ref="$(git show "${head}:${file}" | sed -n 's/^ref=//p')"
			if [ -z "${ref}" ]; then
				say "task ${id} has no ref"
				continue
			fi
			run_task "${id}" "${ref}"
		done
	fi
	sleep 3
done
say "standby over"
