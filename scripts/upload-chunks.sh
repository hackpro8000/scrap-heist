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
#
# Each run throttles itself, so several machines can upload at once with no
# coordination: it waits a random moment before starting, keeps UPLOAD_JOBS
# uploads in flight, and waits out rate limits on every request.
#
#   UPLOAD_JOBS=4             uploads in flight at once
#   UPLOAD_STAGGER=5          most seconds to wait before the first upload
#   UPLOAD_TRIES=8            attempts per request before giving up
#   UPLOAD_MAX_BACKOFF=60     longest backoff between attempts, in seconds
#   UPLOAD_PROCESS_TIMEOUT=360  seconds to wait for Roblox to process a chunk

set -euo pipefail

name="${1:?layout name required}"
: "${ROBLOX_API_KEY:?set ROBLOX_API_KEY}"
: "${ROBLOX_CREATOR_ID:?set ROBLOX_CREATOR_ID (the Roblox user ID that owns the assets)}"
root="$(cd "$(dirname "$0")/.." && pwd)"
chunks="${root}/art/models/${name}/chunks"
ids="${chunks}/${name}AssetIds.txt"
assets="${root}/src/shared/Assets.luau"
# Overridable so the throttling can be tested against a fake server.
api="${ROBLOX_ASSETS_API:-https://apis.roblox.com/assets/v1}"
jobs_max="${UPLOAD_JOBS:-4}"
stagger="${UPLOAD_STAGGER:-5}"
tries_max="${UPLOAD_TRIES:-8}"
backoff_max="${UPLOAD_MAX_BACKOFF:-60}"
process_timeout="${UPLOAD_PROCESS_TIMEOUT:-360}"

[ -d "${chunks}" ] || { echo "no chunks in ${chunks}; build with: scripts/build-model.sh ${name} -- --chunks" >&2; exit 1; }
touch "${ids}"

say() {
	echo "upload ${name}: $*" >&2
}

# A random number of seconds from 0.5 to 1.5 times $1, so runs turned away
# together don't all come back at the same moment.
jitter() {
	awk -v base="$1" -v r="${RANDOM}" 'BEGIN { printf "%.1f", base * (0.5 + r / 32767) }'
}

# Seconds the server asked us to wait in a Retry-After header (in seconds or
# as an HTTP date), or nothing if it didn't say.
retry_after() {
	local value until
	value="$(awk 'tolower($1) == "retry-after:" { sub(/^[^:]*:[ \t]*/, ""); sub(/\r$/, ""); print; exit }' "$1")"
	[ -n "${value}" ] || return 0
	if [[ "${value}" =~ ^[0-9]+$ ]]; then
		echo "${value}"
	elif until="$(date -d "${value}" +%s 2>/dev/null)"; then
		echo $((until > $(date +%s) ? until - $(date +%s) : 1))
	fi
}

# Sends one Open Cloud request (curl arguments after the key header) and
# prints the response body. A rate limit (429) or a transient failure (5xx,
# no connection) is retried after the server's Retry-After, or else after a
# doubling backoff with jitter, up to UPLOAD_TRIES attempts. Any other error
# fails at once.
request() {
	local body headers status pause try=1 backoff=1
	body="$(mktemp)"
	headers="$(mktemp)"
	while true; do
		status="$(curl -sS -o "${body}" -D "${headers}" -w '%{http_code}' -H "x-api-key: ${ROBLOX_API_KEY}" "$@")" || status=000
		case "${status}" in
			2??)
				cat "${body}"
				rm -f "${body}" "${headers}"
				return 0
				;;
			429 | 5?? | 000) ;;
			*)
				say "request failed (HTTP ${status}): $(cat "${body}")"
				rm -f "${body}" "${headers}"
				return 1
				;;
		esac
		if [ "${try}" -ge "${tries_max}" ]; then
			say "gave up after ${try} tries (last HTTP ${status})"
			rm -f "${body}" "${headers}"
			return 1
		fi
		pause="$(retry_after "${headers}")"
		[ -n "${pause}" ] || pause="$(jitter "${backoff}")"
		say "HTTP ${status}, retrying in ${pause}s (try ${try} of ${tries_max})"
		sleep "${pause}"
		try=$((try + 1))
		backoff=$((backoff * 2 > backoff_max ? backoff_max : backoff * 2))
	done
}

# Uploads one file and prints its asset ID once Roblox has processed it,
# checking the operation at gaps that widen from 2 to 30 seconds.
upload() {
	local file="$1" key="$2" response operation id
	local metadata
	metadata="$(jq -cn --arg name "Scrap Heist ${key}" --arg creator "${ROBLOX_CREATOR_ID}" \
		'{assetType: "Model", displayName: $name, description: "Scrap Heist map chunk", creationContext: {creator: {userId: $creator}}}')"
	response="$(request -X POST "${api}/assets" \
		-F "request=${metadata};type=application/json" -F "fileContent=@${file};type=model/gltf-binary")" || return 1
	operation="$(jq -r '.path // empty' <<< "${response}")"
	[ -n "${operation}" ] || { say "${key} rejected: ${response}"; return 1; }
	local gap=2 waited=0
	while [ "${waited}" -lt "${process_timeout}" ]; do
		sleep "${gap}"
		waited=$((waited + gap))
		response="$(request "${api}/${operation}")" || return 1
		if [ "$(jq -r '.done // false' <<< "${response}")" = "true" ]; then
			id="$(jq -r '.response.assetId // empty' <<< "${response}")"
			[ -n "${id}" ] || { say "${key} failed: ${response}"; return 1; }
			echo "${id}"
			return 0
		fi
		gap=$((gap * 3 / 2 > 30 ? 30 : gap * 3 / 2))
	done
	say "${key} still processing after ${waited}s: ${operation}"
	return 1
}

# Uploads one chunk and records its ID; each record is one short append, so
# parallel uploads don't interleave in the IDs file.
upload_chunk() {
	local file="$1" key="$2" id
	say "uploading ${key} ($(du -h "${file}" | cut -f1))"
	if ! id="$(upload "${file}" "${key}")"; then
		echo "${key}" >> "${failures}"
		return 1
	fi
	echo "${key} ${id}" >> "${ids}"
	say "${key} is asset ${id}"
}

# Start at a random moment, so machines launched together don't all upload
# their first chunk at once.
pause="$(awk -v most="${stagger}" -v r="${RANDOM}" 'BEGIN { printf "%.1f", most * r / 32767 }')"
say "starting in ${pause}s"
sleep "${pause}"

shopt -s nullglob
# A whole build writes <Name>_NN.glb; a modelkit --shard build writes
# <Name>_S<i>_NN.glb, keyed <Name>S<i>_NN.
files=("${chunks}/${name}"_[0-9][0-9].glb "${chunks}/${name}"_S[0-9]*_[0-9][0-9].glb)
shopt -u nullglob
[ ${#files[@]} -gt 0 ] || { say "FAILED: no ${name}_NN.glb or ${name}_S<i>_NN.glb chunks in ${chunks}"; exit 1; }

# Failed chunks are recorded here rather than read from exit statuses, so a
# failure can't be lost while waiting for a free upload slot.
failures="$(mktemp)"
trap 'rm -f "${failures}"' EXIT
keys=()
for file in "${files[@]}"; do
	base="$(basename "${file}" .glb)"
	key="${name}${base#"${name}"_}"
	keys+=("${key}")
	if awk -v key="${key}" '$1 == key { found = 1 } END { exit !found }' "${ids}"; then
		say "${key} already uploaded"
		continue
	fi
	while [ "$(jobs -rp | wc -l)" -ge "${jobs_max}" ]; do
		wait -n || true
	done
	upload_chunk "${file}" "${key}" &
done
wait || true

# Every chunk must have exactly one ID before anything is written, so the
# game never gets a table with a chunk missing or listed twice.
for key in "${keys[@]}"; do
	count="$(awk -v key="${key}" '$1 == key { n++ } END { print n + 0 }' "${ids}")"
	if [ "${count}" -eq 0 ] && ! awk -v key="${key}" '$1 == key { found = 1 } END { exit !found }' "${failures}"; then
		echo "${key}" >> "${failures}"
	elif [ "${count}" -gt 1 ]; then
		say "${key} has ${count} IDs in ${ids}"
		echo "${key}" >> "${failures}"
	fi
done
if [ -s "${failures}" ]; then
	say "FAILED: $(sort -u "${failures}" | wc -l) of ${#keys[@]} chunks have no usable ID: $(sort -u "${failures}" | tr '\n' ' ')"
	say "nothing was written to src/shared; see the errors above, then run again to retry just these"
	exit 1
fi

# A shard holds only part of the map, so writing the game's tables from it
# would drop the other shards' chunks. Its IDs file and manifest stay in
# the chunks folder to be merged with the rest.
if [[ "${keys[0]}" =~ ^${name}S[0-9]+_ ]]; then
	say "shard upload done: ${#keys[@]} chunks; IDs in ${ids}, anchors in ${chunks}/${name}Chunks.luau (src/shared not touched)"
	exit 0
fi

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
