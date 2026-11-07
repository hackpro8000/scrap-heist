#!/usr/bin/env bash
# Posts a build task to the machines on standby (build-standby workflow),
# prints each shard's result as it arrives, and checks them once all are
# back. Then, unless told not to upload, it has the uploader (shard 1) send
# every object that has no asset yet, in one go. The commit must already be
# on GitHub (scripts/push-wip.sh pushes unfinished work).
#
#   scripts/send-build.sh                      # main, on the running standby
#   scripts/send-build.sh "$(scripts/push-wip.sh)"
#   scripts/send-build.sh main auto 300 no      # build without uploading
#   scripts/send-build.sh main 8 300            # say the machine count yourself
#
# With the count left as `auto`, the running standby's machine count is used
# (scripts/standby-status.sh), and it stops at once if none is running.
#
# Results land in .standby-results/<task id>/S<i>/ (ignored by git), and the
# upload's in .standby-results/<task id>/uploaded.tsv. Merge them into the
# game's tables with scripts/merge-shards.sh.

set -euo pipefail

ref="${1:-main}"
count="${2:-auto}"
wait_seconds="${3:-300}"
upload="${4:-yes}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"

# A coordinator in this session hands the task to its machines live
# (tools/coordinator/): no queue branch, no polling for results.
if python3 tools/coordinator/client.py status > /dev/null 2>&1; then
	git fetch -q origin "${ref}" 2> /dev/null || true
	commit="$(git rev-parse --verify -q "origin/${ref}^{commit}" || git rev-parse --verify "${ref}^{commit}")"
	flags=(--wait "${wait_seconds}")
	[ "${upload}" = "no" ] && flags+=(--no-upload)
	exec python3 tools/coordinator/client.py build "${commit}" "${flags[@]}"
fi

# Machine 1 runs the coordinator (scripts/standby-start.sh --on-machine): the
# task goes on the build-queue branch for it, and the whole task's results
# come back as one commit on build-results/coordinator, checked for every
# LINK_SECONDS. The only polling left, for a session that can't connect out.
LINK_SECONDS=10
if [ "${count}" = "auto" ] && scripts/standby-status.sh --line 2> /dev/null | grep -q "on-machine=yes"; then
	on_machine=yes
fi

if [ "${count}" = "auto" ]; then
	if ! status="$(scripts/standby-status.sh --line)"; then
		scripts/standby-status.sh >&2 || true
		exit 1
	fi
	count="$(sed -n 's/.*shards=\([0-9]*\).*/\1/p' <<< "${status}")"
	echo "using standby: ${status}" >&2
fi

git fetch -q origin "${ref}" 2> /dev/null || true
commit="$(git rev-parse --verify -q "origin/${ref}^{commit}" || git rev-parse --verify "${ref}^{commit}")"

# Posts a task: a file added to the queue branch on top of the earlier ones,
# made without touching the checkout; a push that loses a race retries.
post_task() {
	local id="$1" body="$2" blob index_file parent tree task
	blob="$(printf '%s\n' "${body}" | git hash-object -w --stdin)"
	for attempt in 1 2 3 4 5; do
		index_file="$(mktemp -u)"
		parent=()
		if git fetch -q origin refs/heads/build-queue 2> /dev/null; then
			parent=(-p "$(git rev-parse FETCH_HEAD)")
			GIT_INDEX_FILE="${index_file}" git read-tree FETCH_HEAD
		fi
		GIT_INDEX_FILE="${index_file}" git update-index --add --cacheinfo "100644,${blob},tasks/${id}.txt"
		tree="$(GIT_INDEX_FILE="${index_file}" git write-tree)"
		rm -f "${index_file}"
		task="$(git commit-tree "${tree}" "${parent[@]}" -m "task ${id}: ${commit}")"
		if git push -q origin "${task}:refs/heads/build-queue" 2> /dev/null; then
			return 0
		fi
		sleep "${attempt}"
	done
	echo "could not post task ${id}" >&2
	return 1
}

# Unpacks a shard's result for a task into a folder, once it has arrived.
# Each results branch keeps a history, so the task's commit is found even
# after the machine has gone on to the next one.
fetch_result() {
	local id="$1" shard="$2" into="$3" sha
	# awk stops at the first match, which breaks git log's pipe: not a failure.
	sha="$(git log -n 50 --format='%H %s' "origin/build-results/s${shard}" 2> /dev/null | awk -v want="task ${id} " 'index($0, want) == 42 { print $1; exit }' || true)"
	[ -n "${sha}" ] || return 1
	mkdir -p "${into}"
	git archive "${sha}" | tar -x -C "${into}"
}

# Starts with the time it was posted, which standby machines sort and filter by.
id="t$(date +%s)-$$"
post_task "${id}" "$(printf 'ref=%s\nupload=%s' "${commit}" "${upload}")" || exit 1
started=$(date +%s)
echo "posted task ${id} (${commit:0:7}); waiting for ${count} shards" >&2

if [ "${on_machine:-}" = yes ]; then
	out=".standby-results/${id}"
	while [ $(($(date +%s) - started)) -lt "${wait_seconds}" ]; do
		sleep "${LINK_SECONDS}"
		git fetch -q origin "+refs/heads/build-results/coordinator:refs/remotes/origin/build-results/coordinator" 2> /dev/null || continue
		sha="$(git log -n 50 --format='%H %s' origin/build-results/coordinator | awk -v want="task ${id}" '$2 " " $3 == want { print $1; exit }' || true)"
		[ -n "${sha}" ] || continue
		mkdir -p "${out}"
		git archive "${sha}" | tar -x -C "${out}"
		for summary in "${out}"/S*/summary.txt; do
			echo "$(basename "$(dirname "${summary}")"): $(tr '\n' ' ' < "${summary}")"
		done
		echo "task ${id} on machine 1: $(tr '\n' ' ' < "${out}/summary.txt"); results in ${out}"
		grep -q "failed=0" "${out}/summary.txt" && ! grep -L "status=DONE" "${out}"/S*/summary.txt | grep -q .
		exit $?
	done
	echo "task ${id}: no result from machine 1 in ${wait_seconds}s"
	exit 1
fi

out=".standby-results/${id}"
mkdir -p "${out}"
declare -A arrived=()
while [ "${#arrived[@]}" -lt "${count}" ] && [ $(($(date +%s) - started)) -lt "${wait_seconds}" ]; do
	sleep 2
	git fetch -q origin '+refs/heads/build-results/*:refs/remotes/origin/build-results/*' 2> /dev/null || continue
	for i in $(seq 1 "${count}"); do
		[ -z "${arrived[${i}]:-}" ] || continue
		fetch_result "${id}" "${i}" "${out}/S${i}" || continue
		arrived[${i}]=1
		echo "S${i} after $(($(date +%s) - started))s: $(tr '\n' ' ' < "${out}/S${i}/summary.txt" 2> /dev/null || echo 'no summary')"
	done
done
elapsed=$(($(date +%s) - started))
failed=0
for i in $(seq 1 "${count}"); do
	if [ -z "${arrived[${i}]:-}" ]; then
		echo "S${i}: no result in ${wait_seconds}s (is standby running?)"
		failed=1
	elif ! grep -q "status=DONE" "${out}/S${i}/summary.txt" 2> /dev/null; then
		failed=1
	fi
done
twice="$(cat "${out}"/S*/parts.txt 2> /dev/null | sort | uniq -d)"
[ -z "${twice}" ] || { echo "parts built by more than one shard: $(echo "${twice}" | head -3 | tr '\n' ' ')"; failed=1; }
echo "task ${id}: ${#arrived[@]} of ${count} shards back in ${elapsed}s, $(cat "${out}"/S*/parts.txt 2>/dev/null | wc -l) parts; results in ${out}"
[ "${failed}" = 0 ] && [ "${upload}" != "no" ] || exit "${failed}"

# Every build is in: the uploader sends what they handed over.
upload_id="t$(date +%s)-$$u"
post_task "${upload_id}" "$(printf 'ref=%s\nupload-of=%s' "${commit}" "${id}")" || exit 1
upload_started=$(date +%s)
echo "posted upload ${upload_id}; waiting for the uploader" >&2
while [ $(($(date +%s) - upload_started)) -lt "${wait_seconds}" ]; do
	sleep 2
	git fetch -q origin '+refs/heads/build-results/s1:refs/remotes/origin/build-results/s1' 2> /dev/null || continue
	fetch_result "${upload_id}" 1 "${out}/upload" && break
done
if [ ! -f "${out}/upload/summary.txt" ]; then
	echo "upload ${upload_id}: no result in ${wait_seconds}s"
	exit 1
fi
cp "${out}/upload/uploaded.tsv" "${out}/uploaded.tsv" 2> /dev/null || true
echo "upload after $(($(date +%s) - upload_started))s: $(tr '\n' ' ' < "${out}/upload/summary.txt")"
grep -q "status=DONE" "${out}/upload/summary.txt"
