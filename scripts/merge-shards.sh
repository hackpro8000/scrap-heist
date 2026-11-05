#!/usr/bin/env bash
# Merges the shards of a sharded layout build (modelkit --shard) into the
# game's tables: every shard's chunk IDs into Assets.MapChunks in
# src/shared/Assets.luau and every shard's anchors into
# src/shared/Config/MapChunks.luau. Each shard folder holds that shard's
# parts.txt, <Name>Chunks.luau and <Name>AssetIds.txt.
#
#   scripts/merge-shards.sh ServerMap shards/S1 shards/S2 ... shards/S8
#
# It refuses to write anything if two shards built the same part, a shard
# folder is missing a file, or a chunk has no ID or more than one.

set -euo pipefail

name="${1:?layout name required}"
shift
[ $# -gt 0 ] || { echo "usage: scripts/merge-shards.sh <Name> <shard folder>..." >&2; exit 1; }
root="$(cd "$(dirname "$0")/.." && pwd)"
assets="${root}/src/shared/Assets.luau"
manifest="${root}/src/shared/Config/MapChunks.luau"

say() {
	echo "merge ${name}: $*" >&2
}
fail() {
	say "FAILED: $*"
	say "nothing was written to src/shared"
	exit 1
}

for dir in "$@"; do
	for file in parts.txt "${name}Chunks.luau" "${name}AssetIds.txt"; do
		[ -f "${dir}/${file}" ] || fail "${dir} has no ${file}"
	done
done

# Each placement belongs to exactly one shard, so no part may appear twice.
twice="$(cat "${@/%//parts.txt}" | sort | uniq -d)"
[ -z "${twice}" ] || fail "parts built by more than one shard: $(echo "${twice}" | head -5 | tr '\n' ' ')"
say "$(cat "${@/%//parts.txt}" | wc -l) parts across $# shards, none built twice"

ids="$(cat "${@/%//${name}AssetIds.txt}" | sort)"
entries="$(cat "${@/%//${name}Chunks.luau}" | awk '/^\t\{ key = /')"
keys="$(echo "${entries}" | awk -F'"' '{ print $2 }')"
[ -n "${keys}" ] || fail "no chunk entries in the shards' manifests"
for key in ${keys}; do
	count="$(echo "${ids}" | awk -v key="${key}" '$1 == key { n++ } END { print n + 0 }')"
	[ "${count}" -eq 1 ] || fail "chunk ${key} has ${count} IDs"
done
extra="$(echo "${ids}" | awk '{ print $1 }' | sort | comm -23 - <(echo "${keys}" | sort))"
[ -z "${extra}" ] || fail "IDs for chunks no manifest lists: $(echo "${extra}" | tr '\n' ' ')"

block="$(echo "${ids}" | awk 'BEGIN { print "Assets.MapChunks = {" } { printf "\t%s = \"rbxassetid://%s\",\n", $1, $2 } END { print "}" }')"
block="${block}" awk '
	/^Assets\.MapChunks = \{/ { print ENVIRON["block"]; skipping = 1; next }
	skipping && /^\}/ { skipping = 0; next }
	!skipping { print }
' "${assets}" > "${assets}.new"
mv "${assets}.new" "${assets}"
{
	echo "--!strict"
	echo "-- Merged from $# shards of ${name} by scripts/merge-shards.sh: one entry per uploaded"
	echo "-- chunk, with two anchor parts and where their middles stand (studs, Y up)."
	echo "return {"
	echo "${entries}"
	echo "}"
} > "${manifest}"
say "wrote $(echo "${keys}" | wc -w) chunk IDs to src/shared/Assets.luau and their anchors to src/shared/Config/MapChunks.luau"
