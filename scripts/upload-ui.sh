#!/usr/bin/env bash
# Uploads UI kit elements (painted by `scripts/build-ui.sh <Kit>`) to Roblox
# through Open Cloud, one Image asset each, and writes their IDs into
# Assets.UI in src/shared/Assets.luau.
#
#   ROBLOX_API_KEY=... ROBLOX_CREATOR_ID=<user id> scripts/upload-ui.sh ToyKit PanelTrade SlotRare ...
#
# The key needs the Assets API's asset:write permission. Each kit keeps
# art/ui/<Kit>/uploads.tsv (name, PNG hash, asset ID), so an element whose
# PNG hasn't changed since its last upload is skipped and keeps its ID.
set -euo pipefail

[ $# -gt 1 ] || { echo "usage: scripts/upload-ui.sh <Kit> <Element>..." >&2; exit 1; }
: "${ROBLOX_API_KEY:?set ROBLOX_API_KEY}"
: "${ROBLOX_CREATOR_ID:?set ROBLOX_CREATOR_ID (the Roblox user ID that owns the assets)}"

root="$(cd "$(dirname "$0")/.." && pwd)"
kit="$1"
shift
dir="${root}/art/ui/${kit}"
manifest="${dir}/uploads.tsv"
assets="${root}/src/shared/Assets.luau"
api="https://apis.roblox.com/assets/v1"
touch "${manifest}"

say() {
	echo "upload-ui: $*" >&2
}

# Uploads one PNG and prints its image asset ID once Roblox has processed it.
upload() {
	local file="$1" name="$2" response operation request
	request="$(jq -cn --arg name "Scrap Heist ${name}" --arg creator "${ROBLOX_CREATOR_ID}" \
		'{assetType: "Image", displayName: $name, description: "Scrap Heist UI", creationContext: {creator: {userId: $creator}}}')"
	response="$(curl -sS --retry 4 --retry-delay 2 -X POST "${api}/assets" -H "x-api-key: ${ROBLOX_API_KEY}" \
		-F "request=${request};type=application/json" -F "fileContent=@${file};type=image/png")"
	operation="$(jq -r '.path // empty' <<< "${response}")"
	[ -n "${operation}" ] || { say "${name} rejected: ${response}"; return 1; }
	for wait in 1 2 2 4 4 8 8 16 16 30; do
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
	say "${name} still processing after a minute and a half: ${operation}"
	return 1
}

# Sets Assets.UI.<name> to the ID, adding the entry if it's new.
record() {
	local name="$1" id="$2"
	name="${name}" id="${id}" awk '
		/^Assets\.UI = \{/ { inside = 1 }
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
	file="${dir}/${name}.png"
	[ -f "${file}" ] || { say "no ${file}; paint it with: scripts/build-ui.sh ${kit}"; exit 1; }
	hash="$(sha256sum "${file}" | cut -d' ' -f1)"
	previous="$(awk -F'\t' -v n="${name}" '$1 == n { print $2 "\t" $3 }' "${manifest}")"
	if [ "${previous%%$'\t'*}" = "${hash}" ]; then
		record "${name}" "${previous##*$'\t'}"
		continue
	fi
	id="$(upload "${file}" "${name}")"
	awk -F'\t' -v n="${name}" '$1 != n' "${manifest}" > "${manifest}.new"
	printf '%s\t%s\t%s\n' "${name}" "${hash}" "${id}" >> "${manifest}.new"
	mv "${manifest}.new" "${manifest}"
	record "${name}" "${id}"
	say "${name} is image ${id}"
done
