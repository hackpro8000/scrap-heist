#!/usr/bin/env bash
# Keeps one shard machine of the build-standby workflow online: once it's up
# (checked out, cache restored) it says so, then waits for tasks on the
# build-queue branch and runs each with its cache already on disk. It stays
# up while tasks keep coming: each task restarts the idle countdown, and it
# exits after <idle minutes> without one, or at <max minutes> whatever
# happens.
#
#   scripts/standby.sh <Layout> <index> <count> <idle minutes> [max minutes]
#
# The queue is a branch of task files, tasks/<task id>.txt, each holding
# `ref=<full commit hash>` and whatever else the task needs;
# scripts/send-build.sh adds them. Every task posted since this machine came
# up (STANDBY_SINCE) is run once, oldest first: the machine checks the task's
# commit out and hands the task to that commit's scripts/standby-task.sh, so
# what a task does can change without restarting standby. Results go to
# results/<task id>/ and, when the task left a summary.txt there, are pushed
# to build-results/s<index> as a new commit on top of the earlier ones, its
# message naming the task.

set -uo pipefail

layout="${1:?layout required}"
index="${2:?shard index required}"
count="${3:?shard count required}"
idle_minutes="${4:?idle minutes required}"
max_minutes="${5:-60}"
idle_until=$((SECONDS + idle_minutes * 60))
hard_stop=$((SECONDS + max_minutes * 60))
since="${STANDBY_SINCE:-$(date +%s)}"
results_branch="build-results/s${index}"

say() {
	echo "standby S${index}/${count}: $*" >&2
}

queue_head() {
	git ls-remote origin refs/heads/build-queue | cut -f1
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
	say "task ${id}: checking out ${ref}"
	if git fetch -q --depth=1 origin "${ref}" > "${out}/build.log" 2>&1 && git checkout -q -f FETCH_HEAD >> "${out}/build.log" 2>&1; then
		result="$(scripts/standby-task.sh "${layout}" "${index}" "${count}" "${out}")"
	else
		{ echo "status=FAILED"; echo "build=-"; echo "upload=-"; echo "total=0"; echo "parts=0"; } > "${out}/summary.txt"
		tail -n 30 "${out}/build.log" > "${out}/error.txt"
		result="FAILED: could not check out ${ref}"
	fi
	if [ -f "${out}/summary.txt" ]; then
		push_results "${id}" "${out}" || say "task ${id}: could not push results"
	fi
	say "task ${id}: ${result}"
}

# Say this machine is up and waiting, so the sender knows standby is ready.
mkdir -p results/ready
echo "up=$(date +%s)" > results/ready/summary.txt
push_results "ready-${GITHUB_RUN_ID:-local}" results/ready || say "could not push the ready signal"

declare -A built=()
seen=""
say "waiting for tasks posted since $(date -d "@${since}" +%T); up until ${idle_minutes} idle min, at most ${max_minutes} min"
while [ "${SECONDS}" -lt "${idle_until}" ] && [ "${SECONDS}" -lt "${hard_stop}" ]; do
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
			task="$(git show "${head}:${file}")"
			ref="$(sed -n 's/^ref=//p' <<< "${task}")"
			if [ -z "${ref}" ]; then
				say "task ${id} has no ref"
				continue
			fi
			mkdir -p "results/${id}"
			echo "${task}" > "results/${id}/task.txt"
			run_task "${id}" "${ref}"
			idle_until=$((SECONDS + idle_minutes * 60))
		done
	fi
	sleep 3
done
say "standby over"
