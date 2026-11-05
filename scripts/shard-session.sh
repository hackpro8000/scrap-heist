#!/usr/bin/env bash
# Builds one shard of a layout on this machine (a cloud session), uploads its
# chunks, pushes the shard's IDs and anchors to a branch and reports on the
# results PR, so a session's whole job is this one command:
#
#   scripts/shard-session.sh 3 8                  # shard 3 of 8 of ServerMap
#   scripts/shard-session.sh 3 8 ServerMap 1      # layout and results PR number
#
# Uploads need ROBLOX_API_KEY and ROBLOX_CREATOR_ID; without them the shard
# is built and reported, and the upload is skipped. Every step's output goes
# to /tmp/shard-<i>.log, and a failure reports the log's last lines.

set -uo pipefail

index="${1:?shard index required}"
count="${2:?shard count required}"
name="${3:-ServerMap}"
pr="${4:-1}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}" || exit 1
log="/tmp/shard-${index}.log"
: > "${log}"
out="art/shards/${name}/S${index}"
chunks="art/models/${name}/chunks"
build_seconds="-"
upload_result="-"
branch="-"

say() {
	echo "shard S${index}: $*" | tee -a "${log}" >&2
}

# Posts the report on the results PR. If gh can't post it (not installed or
# not signed in), the report is printed for the session to post instead.
report() {
	local status="$1" body
	body="S${index} ${status}
layout: ${name}, shard ${index} of ${count}
build: ${build_seconds}
upload: ${upload_result}
parts: $( [ -f "${out}/parts.txt" ] && wc -l < "${out}/parts.txt" || echo -)
chunks: $(ls "${chunks}/${name}_S${index}_"*.glb 2>/dev/null | wc -l)
branch: ${branch}"
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

fail() {
	say "FAILED: $*"
	report FAILED
	exit 1
}

if ! command -v jq >/dev/null 2>&1 || ! command -v rg >/dev/null 2>&1; then
	say "installing tools (scripts/cloud-setup.sh)"
	bash scripts/cloud-setup.sh >> "${log}" 2>&1 || sudo bash scripts/cloud-setup.sh >> "${log}" 2>&1 || say "cloud setup failed; carrying on"
fi

say "assembling ${name}"
scripts/assemble-model.sh "${name}" >> "${log}" 2>&1 || fail "assemble"

say "building shard ${index}/${count} (several minutes on CPU)"
started=${SECONDS}
scripts/build-model.sh "${name}" -- --chunks --shard "${index}/${count}" >> "${log}" 2>&1 || fail "build"
build_seconds="$((SECONDS - started))s"
say "built in ${build_seconds}"

mkdir -p "${out}"
python3 - "art/models/${name}/${name}.glb" > "${out}/parts.txt" << 'EOF' || fail "listing parts"
import json, struct, sys
data = open(sys.argv[1], "rb").read()
length = struct.unpack_from("<I", data, 12)[0]
names = [node["name"] for node in json.loads(data[20:20 + length])["nodes"] if "mesh" in node]
print("\n".join(sorted(names)))
EOF

if [ -n "${ROBLOX_API_KEY:-}" ] && [ -n "${ROBLOX_CREATOR_ID:-}" ]; then
	say "uploading chunks"
	started=${SECONDS}
	scripts/upload-chunks.sh "${name}" >> "${log}" 2>&1 || fail "upload"
	upload_result="$((SECONDS - started))s"
	cp "${chunks}/${name}AssetIds.txt" "${out}/"
else
	upload_result="skipped (ROBLOX_API_KEY or ROBLOX_CREATOR_ID not set)"
	say "${upload_result}"
fi
cp "${chunks}/${name}Chunks.luau" "${out}/"

# Cloud sessions may only push their own branch; on main, use a shard branch.
branch="$(git branch --show-current)"
if [ "${branch}" = "main" ] || [ -z "${branch}" ]; then
	branch="shard/$(echo "${name}" | tr '[:upper:]' '[:lower:]')-s${index}"
	git switch -c "${branch}" >> "${log}" 2>&1 || fail "creating branch ${branch}"
fi
git add -f "${out}" >> "${log}" 2>&1 || fail "staging ${out}"
git commit -q -m "${name} shard ${index}/${count} results" >> "${log}" 2>&1 || fail "commit"
git push -u origin "${branch}" >> "${log}" 2>&1 || fail "push to ${branch}"
say "pushed ${out} to ${branch}"

report DONE
