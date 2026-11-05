#!/usr/bin/env bash
# Uploads the synthesised sounds (art/sounds/out/*.wav, from
# `python3 art/sounds/synth.py`) to Roblox through Open Cloud as Audio
# assets, and writes their IDs into Assets.Sounds in src/shared/Assets.luau.
#
#   ROBLOX_API_KEY=... ROBLOX_CREATOR_ID=<user id> scripts/upload-sounds.sh [Name ...]
#
# With no names, every sound not yet uploaded goes up. Uploaded sounds are
# listed in art/sounds/SoundAssetIds.txt; pass a name to upload it again.

set -euo pipefail

: "${ROBLOX_API_KEY:?set ROBLOX_API_KEY}"
: "${ROBLOX_CREATOR_ID:?set ROBLOX_CREATOR_ID (the Roblox user ID that owns the assets)}"
root="$(cd "$(dirname "$0")/.." && pwd)"
out="${root}/art/sounds/out"
ids="${root}/art/sounds/SoundAssetIds.txt"
api="https://apis.roblox.com/assets/v1"
touch "${ids}"

say() {
	echo "upload sounds: $*" >&2
}

upload() {
	local file="$1" key="$2" request response operation
	request="$(jq -cn --arg name "Scrap Heist ${key}" --arg creator "${ROBLOX_CREATOR_ID}" \
		'{assetType: "Audio", displayName: $name, description: "Scrap Heist sound effect", creationContext: {creator: {userId: $creator}}}')"
	response="$(curl -sS --retry 4 --retry-delay 2 -X POST "${api}/assets" -H "x-api-key: ${ROBLOX_API_KEY}" \
		-F "request=${request};type=application/json" -F "fileContent=@${file};type=audio/wav")"
	operation="$(jq -r '.path // empty' <<< "${response}" 2> /dev/null || true)"
	[ -n "${operation}" ] || { say "${key} rejected: ${response}"; return 1; }
	for wait in 2 2 4 4 8 8 16 16 30 30 30; do
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
	say "${key} still processing: ${operation}"
	return 1
}

if [ "$#" -gt 0 ]; then
	names=("$@")
else
	names=()
	for file in "${out}"/*.wav; do
		key="$(basename "${file}" .wav)"
		awk -v key="${key}" '$1 == key { found = 1 } END { exit !found }' "${ids}" || names+=("${key}")
	done
fi

failed=0
for key in "${names[@]}"; do
	file="${out}/${key}.wav"
	[ -f "${file}" ] || { say "no ${file}"; failed=1; continue; }
	if id="$(upload "${file}" "${key}")"; then
		awk -v key="${key}" '$1 != key' "${ids}" > "${ids}.tmp" && mv "${ids}.tmp" "${ids}"
		echo "${key} ${id}" >> "${ids}"
		say "${key} is asset ${id}"
	else
		failed=1
	fi
done

# Point each uploaded key in Assets.Sounds at its ID.
python3 - "${ids}" "${root}/src/shared/Assets.luau" << 'PY'
import re, sys
ids = dict(line.split() for line in open(sys.argv[1]) if line.strip())
path = sys.argv[2]
text = open(path).read()
start = text.index("Assets.Sounds = {")
end = text.index("}", start)
block = text[start:end]
for key, id_ in ids.items():
	block = re.sub(rf"(\n\t{key} = )[^\n]*,", rf'\g<1>"rbxassetid://{id_}",', block)
open(path, "w").write(text[:start] + block + text[end:])
PY
say "wrote $(wc -l < "${ids}") IDs to src/shared/Assets.luau"
exit "${failed}"
