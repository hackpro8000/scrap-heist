#!/usr/bin/env bash
# Uploads a layout's chunks (from `scripts/build-model.sh <Name> -- --chunks`)
# to Roblox through Open Cloud, one Model asset per chunk, and writes their
# IDs into Assets.MapChunks in src/shared/Assets.luau and the chunks' anchors
# into src/shared/Config/MapChunks.luau, where tools/studio/PlaceMap.luau
# reads them.
#
#   ROBLOX_API_KEY=... ROBLOX_CREATOR_ID=<user id> scripts/upload-chunks.sh ServerMap
#
# The key needs the Assets API's asset:write permission. Chunks already
# uploaded (listed in chunks/<Name>AssetIds.txt) are skipped, so a failed run
# can simply be run again.

set -euo pipefail

name="${1:?layout name required}"
: "${ROBLOX_API_KEY:?set ROBLOX_API_KEY}"
: "${ROBLOX_CREATOR_ID:?set ROBLOX_CREATOR_ID (the Roblox user ID that owns the assets)}"
root="$(cd "$(dirname "$0")/.." && pwd)"
chunks="${root}/art/models/${name}/chunks"
ids="${chunks}/${name}AssetIds.txt"
assets="${root}/src/shared/Assets.luau"
api="https://apis.roblox.com/assets/v1"

[ -d "${chunks}" ] || { echo "no chunks in ${chunks}; build with: scripts/build-model.sh ${name} -- --chunks" >&2; exit 1; }
touch "${ids}"

say() {
	echo "upload ${name}: $*" >&2
}

# Uploads one file and prints its asset ID once Roblox has processed it.
upload() {
	local file="$1" key="$2" response operation
	local request
	request="$(jq -cn --arg name "Scrap Heist ${key}" --arg creator "${ROBLOX_CREATOR_ID}" \
		'{assetType: "Model", displayName: $name, description: "Scrap Heist map chunk", creationContext: {creator: {userId: $creator}}}')"
	response="$(curl -sS --retry 4 --retry-delay 2 -X POST "${api}/assets" -H "x-api-key: ${ROBLOX_API_KEY}" \
		-F "request=${request};type=application/json" -F "fileContent=@${file};type=model/gltf-binary")"
	operation="$(jq -r '.path // empty' <<< "${response}")"
	[ -n "${operation}" ] || { say "${key} rejected: ${response}"; return 1; }
	for wait in 2 2 4 4 8 8 16 16 30 30 30 30 30 30; do
		sleep "${wait}"
		response="$(curl -sS --retry 4 "${api}/${operation}" -H "x-api-key: ${ROBLOX_API_KEY}")"
		if [ "$(jq -r '.done // false' <<< "${response}")" = "true" ]; then
			local id
			id="$(jq -r '.response.assetId // empty' <<< "${response}")"
			[ -n "${id}" ] || { say "${key} failed: ${response}"; return 1; }
			echo "${id}"
			return 0
		fi
	done
	say "${key} still processing after several minutes: ${operation}"
	return 1
}

for file in "${chunks}/${name}"_[0-9][0-9].glb; do
	number="$(basename "${file}" .glb)"
	key="${name}${number##*_}"
	if awk -v key="${key}" '$1 == key { found = 1 } END { exit !found }' "${ids}"; then
		say "${key} already uploaded"
		continue
	fi
	say "uploading ${key} ($(du -h "${file}" | cut -f1))"
	id="$(upload "${file}" "${key}")"
	echo "${key} ${id}" >> "${ids}"
	say "${key} is asset ${id}"
done

# Rewrite the Assets.MapChunks table from the IDs file.
block="$(sort "${ids}" | awk 'BEGIN { print "Assets.MapChunks = {" } { printf "\t%s = \"rbxassetid://%s\",\n", $1, $2 } END { print "}" }')"
block="${block}" awk '
	/^Assets\.MapChunks = \{/ { print ENVIRON["block"]; skipping = 1; next }
	skipping && /^\}/ { skipping = 0; next }
	!skipping { print }
' "${assets}" > "${assets}.new"
mv "${assets}.new" "${assets}"
say "wrote $(wc -l < "${ids}") IDs to src/shared/Assets.luau"
# The placer needs the anchors of exactly these chunks.
cp "${chunks}/${name}Chunks.luau" "${root}/src/shared/Config/MapChunks.luau"
say "copied the chunk anchors to src/shared/Config/MapChunks.luau"
