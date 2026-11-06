#!/usr/bin/env bash
# Posts a build task to the machines on standby (build-standby workflow),
# prints each shard's result as it arrives, and checks them once all are
# back. The commit must already be on GitHub (scripts/push-wip.sh pushes
# unfinished work).
#
#   scripts/send-build.sh                      # main, 8 shards, wait 5 min
#   scripts/send-build.sh "$(scripts/push-wip.sh)" 8 300
#   scripts/send-build.sh main 8 300 no         # build without uploading
#
# Results land in .standby-results/<task id>/S<i>/ (ignored by git).

set -euo pipefail

ref="${1:-main}"
count="${2:-8}"
wait_seconds="${3:-300}"
upload="${4:-yes}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"

git fetch -q origin "${ref}" 2> /dev/null || true
commit="$(git rev-parse --verify -q "origin/${ref}^{commit}" || git rev-parse --verify "${ref}^{commit}")"
# Starts with the time it was posted, which standby machines sort and filter by.
id="t$(date +%s)-$$"

# The task is a file added to the queue branch on top of the earlier ones,
# made without touching the checkout; a push that loses a race retries.
blob="$(printf 'ref=%s\nupload=%s\n' "${commit}" "${upload}" | git hash-object -w --stdin)"
posted=0
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
	task="$(git commit-tree "${tree}" "${parent[@]}" -m "task ${id}: build ${commit}")"
	if git push -q origin "${task}:refs/heads/build-queue" 2> /dev/null; then
		posted=1
		break
	fi
	sleep "${attempt}"
done
[ "${posted}" = 1 ] || { echo "could not post task ${id}" >&2; exit 1; }
started=$(date +%s)
echo "posted task ${id} (${commit:0:7}); waiting for ${count} shards" >&2

out=".standby-results/${id}"
mkdir -p "${out}"
declare -A arrived=()
while [ "${#arrived[@]}" -lt "${count}" ] && [ $(($(date +%s) - started)) -lt "${wait_seconds}" ]; do
	sleep 2
	git fetch -q origin '+refs/heads/build-results/*:refs/remotes/origin/build-results/*' 2> /dev/null || continue
	for i in $(seq 1 "${count}"); do
		[ -z "${arrived[${i}]:-}" ] || continue
		# Each results branch keeps a history, so the task's commit is found
		# even after the machine has gone on to the next one.
		# awk stops at the first match, which breaks git log's pipe: not a failure.
		sha="$(git log -n 50 --format='%H %s' "origin/build-results/s${i}" 2> /dev/null | awk -v want="task ${id} " 'index($0, want) == 42 { print $1; exit }' || true)"
		[ -n "${sha}" ] || continue
		arrived[${i}]=1
		mkdir -p "${out}/S${i}"
		git archive "${sha}" | tar -x -C "${out}/S${i}"
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
echo "task ${id}: ${#arrived[@]} of ${count} shards back in ${elapsed}s, $(cat "${out}"/S*/parts.txt 2> /dev/null | wc -l) parts; results in ${out}"
exit "${failed}"
