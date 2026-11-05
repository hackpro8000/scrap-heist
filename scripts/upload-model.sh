#!/usr/bin/env bash
# Uploads built models (from `scripts/build-model.sh <Name>`) to Roblox
# through Open Cloud, one Model asset each, and writes their IDs into
# Assets.Models in src/shared/Assets.luau. tools/studio/PlaceModels.luau loads
# them from there into the ServerStorage folders the game clones them from.
#
#   ROBLOX_API_KEY=... ROBLOX_CREATOR_ID=<user id> scripts/upload-model.sh Scrapper Bruiser Zapper
#
# The key needs the Assets API's asset:write permission. Every run uploads
# afresh, so rebuild first and upload only what changed.
set -euo pipefail

[ $# -gt 0 ] || { echo "usage: scripts/upload-model.sh <Name>..." >&2; exit 1; }
: "${ROBLOX_API_KEY:?set ROBLOX_API_KEY}"
: "${ROBLOX_CREATOR_ID:?set ROBLOX_CREATOR_ID (the Roblox user ID that owns the assets)}"

root="$(cd "$(dirname "$0")/.." && pwd)"
assets="${root}/src/shared/Assets.luau"
api="https://apis.roblox.com/assets/v1"

say() {
	echo "upload-model: $*" >&2
}

# Uploads one file and prints its asset ID once Roblox has processed it.
upload() {
	local file="$1" name="$2" response operation request
	request="$(jq -cn --arg name "Scrap Heist ${name}" --arg creator "${ROBLOX_CREATOR_ID}" \
		'{assetType: "Model", displayName: $name, description: "Scrap Heist model", creationContext: {creator: {userId: $creator}}}')"
	response="$(curl -sS --retry 4 --retry-delay 2 -X POST "${api}/assets" -H "x-api-key: ${ROBLOX_API_KEY}" \
		-F "request=${request};type=application/json" -F "fileContent=@${file};type=model/gltf-binary")"
	operation="$(jq -r '.path // empty' <<< "${response}")"
	[ -n "${operation}" ] || { say "${name} rejected: ${response}"; return 1; }
	for wait in 2 2 4 4 8 8 16 16 30 30 30 30; do
		sleep "${wait}"
		response="$(curl -sS --retry 4 "${api}/${operation}" -H "x-api-key: ${ROBLOX_API_KEY}")"
		if [ "$(jq -r '.done // false' <<< "${response}")" = "true" ]; then
			local id
			id="$(jq -r '.response.assetId // empty' <<< "${response}")"
			[ -n "${id}" ] || { say "${name} failed: ${response}"; return 1; }
			echo "${id}"
			return 0
		fi
	done
	say "${name} still processing after several minutes: ${operation}"
	return 1
}

# Sets Assets.Models.<name> to the ID, adding the entry if it's new.
record() {
	local name="$1" id="$2"
	name="${name}" id="${id}" awk '
		/^Assets\.Models = \{/ { inside = 1 }
		inside && $1 == ENVIRON["name"] { printf "\t%s = \"rbxassetid://%s\",\n", ENVIRON["name"], ENVIRON["id"]; done = 1; next }
		inside && /^\}/ {
			if (!done) printf "\t%s = \"rbxassetid://%s\",\n", ENVIRON["name"], ENVIRON["id"]
			inside = 0
		}
		{ print }
	' "${assets}" > "${assets}.new"
	mv "${assets}.new" "${assets}"
}

for name in "$@"; do
	file="${root}/art/models/${name}/${name}.glb"
	[ -f "${file}" ] || { say "no ${file}; build with: scripts/build-model.sh ${name}"; exit 1; }
	say "uploading ${name} ($(du -h "${file}" | cut -f1))"
	id="$(upload "${file}" "${name}")"
	record "${name}" "${id}"
	say "${name} is asset ${id}"
done
