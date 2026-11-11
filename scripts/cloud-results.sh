#!/usr/bin/env bash
# Collects the results of a build done by cloud session machines
# (scripts/cloud-shard.sh): each session pushed its shard to the branch
# cloud-results/<task>/s<index>. Waits until every shard's branch is there,
# then puts the files in .standby-results/<task>/S<index>/, where
# scripts/merge-shards.sh reads them, and prints one line per shard.
#
#   scripts/cloud-results.sh <task> <count> [seconds to wait, default 600]
set -euo pipefail

task="${1:?task name required}"
count="${2:?shard count required}"
wait_seconds="${3:-600}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"
out=".standby-results/${task}"
started="${SECONDS}"

while true; do
	found="$(git ls-remote origin "refs/heads/cloud-results/${task}/s*" | wc -l)"
	[ "${found}" -ge "${count}" ] && break
	if [ $((SECONDS - started)) -ge "${wait_seconds}" ]; then
		echo "only ${found} of ${count} shards arrived in ${wait_seconds}s" >&2
		break
	fi
	sleep 5
done
echo "${found} of ${count} shards pushed after $((SECONDS - started))s"

failed=0
for index in $(seq 1 "${count}"); do
	branch="cloud-results/${task}/s${index}"
	if ! git fetch -q origin "${branch}" 2> /dev/null; then
		echo "S${index}: missing"
		failed=1
		continue
	fi
	rm -rf "${out}/S${index}"
	mkdir -p "${out}/S${index}"
	git archive FETCH_HEAD "cloud-results/S${index}" | tar -x -C "${out}/S${index}" --strip-components=2
	seconds="$(awk -F= '$1 == "seconds" { print $2 }' "${out}/S${index}/machine.txt" 2> /dev/null)"
	status="$(awk -F= '$1 == "status" { print $2 }' "${out}/S${index}/summary.txt" 2> /dev/null)"
	parts="$(awk -F= '$1 == "parts" { print $2 }' "${out}/S${index}/summary.txt" 2> /dev/null)"
	echo "S${index}: status=${status:-none} seconds=${seconds:-?} parts=${parts:-?}"
	[ "${status}" = "DONE" ] || failed=1
done
echo "results in ${out}"
exit "${failed}"
