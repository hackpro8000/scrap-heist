#!/usr/bin/env bash
# Collects the results of a build done by cloud session machines
# (scripts/cloud-shard.sh). Waits until every shard has pushed, then puts the
# files in .standby-results/<task>/S<index>/, where scripts/merge-shards.sh
# reads them, and prints one line per shard.
#
#   scripts/cloud-results.sh <task> <count> [seconds to wait, default 600]
#
# A shard is found on the branch cloud-results/<task>/s<index> (a fresh
# session) or on the machine slot cloud/m<index> (a reused one) once that
# slot's latest commit is "<task> shard <index> of <count>".
set -euo pipefail

task="${1:?task name required}"
count="${2:?shard count required}"
wait_seconds="${3:-600}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"
out=".standby-results/${task}"
started="${SECONDS}"

# Whether ls-remote output lists exactly this ref. awk reads all its input,
# so nothing upstream is cut off (rg -q would stop early and, with pipefail,
# turn a match into a failure).
has_ref() {
	printf '%s\n' "$1" | awk -v ref="$2" '$2 == ref { found = 1 } END { exit !found }'
}

# Prints the ref holding shard <index> of this task, or nothing yet.
ref_of() {
	local index="$1" heads
	heads="$(git ls-remote origin "refs/heads/cloud-results/${task}/s${index}" "refs/heads/cloud/m${index}")"
	if has_ref "${heads}" "refs/heads/cloud-results/${task}/s${index}"; then
		echo "cloud-results/${task}/s${index}"
		return
	fi
	has_ref "${heads}" "refs/heads/cloud/m${index}" || return 0
	git fetch -q origin "cloud/m${index}" 2> /dev/null || return 0
	[ "$(git log -1 --format=%s FETCH_HEAD)" = "${task} shard ${index} of ${count}" ] && echo "cloud/m${index}"
	return 0
}

declare -A refs=()
while true; do
	for index in $(seq 1 "${count}"); do
		[ -n "${refs[${index}]:-}" ] && continue
		ref="$(ref_of "${index}")"
		[ -n "${ref}" ] && refs[${index}]="${ref}"
	done
	[ "${#refs[@]}" -ge "${count}" ] && break
	if [ $((SECONDS - started)) -ge "${wait_seconds}" ]; then
		echo "only ${#refs[@]} of ${count} shards arrived in ${wait_seconds}s" >&2
		break
	fi
	sleep 5
done
echo "${#refs[@]} of ${count} shards pushed after $((SECONDS - started))s"

failed=0
for index in $(seq 1 "${count}"); do
	ref="${refs[${index}]:-}"
	if [ -z "${ref}" ] || ! git fetch -q origin "${ref}" 2> /dev/null; then
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
	echo "S${index}: status=${status:-none} seconds=${seconds:-?} parts=${parts:-?} (${ref})"
	[ "${status}" = "DONE" ] || failed=1
done
echo "results in ${out}"
exit "${failed}"
