#!/usr/bin/env bash
# Posts a build task to the machines on standby (build-standby workflow),
# waits for every shard's results and prints them. The commit must already
# be on GitHub (scripts/push-wip.sh pushes unfinished work).
#
#   scripts/send-build.sh                      # main, 8 shards, wait 5 min
#   scripts/send-build.sh "$(scripts/push-wip.sh)" 8 300
#
# Results land in .standby-results/<task id>/S<i>/ (ignored by git).

set -euo pipefail

ref="${1:-main}"
count="${2:-8}"
wait_seconds="${3:-300}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"

git fetch -q origin "${ref}" 2> /dev/null || true
commit="$(git rev-parse --verify -q "origin/${ref}^{commit}" || git rev-parse --verify "${ref}^{commit}")"
id="t$(date +%s)"

# The task is a one-file commit on build-queue, made without touching the checkout.
blob="$(printf 'id=%s\nref=%s\n' "${id}" "${commit}" | git hash-object -w --stdin)"
tree="$(printf '100644 blob %s\ttask.txt\n' "${blob}" | git mktree)"
task="$(git commit-tree "${tree}" -m "task ${id}: build ${commit}")"
git push -q -f origin "${task}:refs/heads/build-queue"
started=$(date +%s)
echo "posted task ${id} (${commit:0:7}); waiting for ${count} shards" >&2

done_count=0
while [ $(($(date +%s) - started)) -lt "${wait_seconds}" ]; do
	sleep 2
	git fetch -q origin '+refs/heads/build-results/*:refs/remotes/origin/build-results/*' 2> /dev/null || continue
	done_count=0
	for i in $(seq 1 "${count}"); do
		if git log -1 --format=%s "origin/build-results/s${i}" 2> /dev/null | grep -q "^task ${id} "; then
			done_count=$((done_count + 1))
		fi
	done
	[ "${done_count}" -lt "${count}" ] || break
done
elapsed=$(($(date +%s) - started))
[ "${done_count}" -eq "${count}" ] || { echo "only ${done_count} of ${count} shards answered in ${wait_seconds}s; is standby running?" >&2; exit 1; }

out=".standby-results/${id}"
mkdir -p "${out}"
failed=0
for i in $(seq 1 "${count}"); do
	mkdir -p "${out}/S${i}"
	git archive "origin/build-results/s${i}" | tar -x -C "${out}/S${i}"
	summary="$(tr '\n' ' ' < "${out}/S${i}/summary.txt")"
	echo "S${i}: ${summary}"
	grep -q "status=DONE" "${out}/S${i}/summary.txt" || failed=1
done
twice="$(cat "${out}"/S*/parts.txt 2> /dev/null | sort | uniq -d)"
[ -z "${twice}" ] || { echo "parts built by more than one shard: $(echo "${twice}" | head -3 | tr '\n' ' ')"; failed=1; }
echo "task ${id}: all ${count} shards back in ${elapsed}s, $(cat "${out}"/S*/parts.txt | wc -l) parts; results in ${out}"
exit "${failed}"
