#!/usr/bin/env bash
# Runs one job on a build worker (a long-lived cloud session) and reports it.
# Every job starts from the latest main, so a worker can take any number of
# jobs one after another without leftovers from the last one.
#
#   scripts/worker-job.sh W3 servermap-a-s3 shard ServerMap 3/8
#       build one shard of a layout and upload its chunks
#   scripts/worker-job.sh W3 crane-a model MagnetCrane
#       build one model and send back its preview
#
# Results go to art/jobs/<job id>/ on the worker's branch (its session
# branch, or worker/<w> when it sits on main), which is reset to main and
# force-pushed for each job. The report, starting "<worker> <job id> DONE"
# or "... FAILED", goes on the results PR (RESULTS_PR, default 1). Uploads
# need ROBLOX_API_KEY and ROBLOX_CREATOR_ID; without them they're skipped.

set -uo pipefail

worker="${1:?worker name required, like W3}"
job="${2:?job id required}"
kind="${3:?job kind required: shard or model}"
shift 3
pr="${RESULTS_PR:-1}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}" || exit 1
log="/tmp/job-${job}.log"
: > "${log}"
out="art/jobs/${job}"
branch="-"
commit="-"
summary=""

say() {
	echo "${worker} ${job}: $*" | tee -a "${log}" >&2
}

# Posts the report on the results PR, or prints it for the session to post
# if gh can't (not installed or not signed in).
report() {
	local status="$1" body
	shift
	body="${worker} ${job} ${status}
job: ${kind} $*
${summary}branch: ${branch}
commit: ${commit}"
	if [ "${status}" = "FAILED" ]; then
		body="${body}

\`\`\`
$(tail -n 30 "${log}")
\`\`\`"
	fi
	if gh pr comment "${pr}" --body "${body}" >> "${log}" 2>&1; then
		say "reported ${status} on PR #${pr}"
	else
		say "could not comment on PR #${pr}; post this report there yourself:"
		echo "----- report -----"
		echo "${body}"
		echo "------------------"
	fi
}
args=("$@")

fail() {
	say "FAILED: $*"
	report FAILED "${args[@]}"
	exit 1
}

# Times a step and adds "<label>: <seconds>s" to the report.
timed() {
	local label="$1" started=${SECONDS}
	shift
	"$@" >> "${log}" 2>&1 || return 1
	summary="${summary}${label}: $((SECONDS - started))s
"
}

listParts() {
	python3 - "$1" << 'EOF'
import json, struct, sys
data = open(sys.argv[1], "rb").read()
length = struct.unpack_from("<I", data, 12)[0]
names = [node["name"] for node in json.loads(data[20:20 + length])["nodes"] if "mesh" in node]
print("\n".join(sorted(names)))
EOF
}

# Start from the latest main on the worker's own branch, carrying over the
# earlier jobs' results so a report's commit stays fetchable after the next job.
git fetch -q origin main >> "${log}" 2>&1 || fail "fetching main"
branch="$(git branch --show-current)"
if [ "${branch}" = "main" ] || [ -z "${branch}" ]; then
	branch="worker/$(echo "${worker}" | tr '[:upper:]' '[:lower:]')"
fi
earlier=""
if git fetch -q origin "${branch}" >> "${log}" 2>&1; then
	earlier="$(git rev-parse FETCH_HEAD)"
fi
git checkout -q -B "${branch}" origin/main >> "${log}" 2>&1 || fail "resetting ${branch} to main"
if [ -n "${earlier}" ] && git cat-file -e "${earlier}:art/jobs" 2>/dev/null; then
	git checkout "${earlier}" -- art/jobs >> "${log}" 2>&1 || fail "carrying over earlier job results"
fi

if ! command -v jq >/dev/null 2>&1 || ! command -v rg >/dev/null 2>&1; then
	say "installing tools (scripts/cloud-setup.sh)"
	bash scripts/cloud-setup.sh >> "${log}" 2>&1 || sudo bash scripts/cloud-setup.sh >> "${log}" 2>&1 || say "cloud setup failed; carrying on"
fi
mkdir -p "${out}"

case "${kind}" in
	shard)
		name="${1:?shard job needs a layout name}"
		share="${2:?shard job needs INDEX/COUNT}"
		index="${share%/*}"
		chunks="art/models/${name}/chunks"
		say "building ${name} shard ${share}"
		timed assemble scripts/assemble-model.sh "${name}" || fail "assemble"
		timed build scripts/build-model.sh "${name}" -- --chunks --shard "${share}" || fail "build"
		listParts "art/models/${name}/${name}.glb" > "${out}/parts.txt" || fail "listing parts"
		cp "${chunks}/${name}Chunks.luau" "art/models/${name}/preview.png" "${out}/" 2>> "${log}"
		summary="${summary}parts: $(wc -l < "${out}/parts.txt")
chunks: $(ls "${chunks}/${name}_S${index}_"*.glb 2>/dev/null | wc -l)
"
		if [ -n "${ROBLOX_API_KEY:-}" ] && [ -n "${ROBLOX_CREATOR_ID:-}" ]; then
			timed upload scripts/upload-chunks.sh "${name}" || fail "upload"
			cp "${chunks}/${name}AssetIds.txt" "${out}/"
		else
			summary="${summary}upload: skipped (ROBLOX_API_KEY or ROBLOX_CREATOR_ID not set)
"
		fi
		;;
	model)
		name="${1:?model job needs a model name}"
		say "building ${name}"
		[ -f "art/src/items/${name}.luau" ] || [ -d "art/src/bots/${name}" ] && { timed assemble scripts/assemble-model.sh "${name}" || fail "assemble"; }
		timed build scripts/build-model.sh "${name}" || fail "build"
		listParts "art/models/${name}/${name}.glb" > "${out}/parts.txt" || fail "listing parts"
		cp "art/models/${name}/preview.png" "${out}/" || fail "no preview.png"
		summary="${summary}parts: $(wc -l < "${out}/parts.txt")
"
		;;
	*)
		fail "unknown job kind ${kind}; use shard or model"
		;;
esac

git add -f "${out}" >> "${log}" 2>&1 || fail "staging ${out}"
git commit -q -m "${worker} job ${job}: ${kind} $*" >> "${log}" 2>&1 || fail "commit"
git push -q -f -u origin "${branch}" >> "${log}" 2>&1 || fail "push to ${branch}"
commit="$(git rev-parse --short HEAD)"
say "pushed ${out} to ${branch} (${commit})"

report DONE "$@"
