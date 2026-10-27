#!/usr/bin/env bash
# Assembles art/models/<Name>/model.luau from the split sources in art/src:
# a bot is its head, the shared helpers, then its body; an item is the
# rarity colors, the shared helpers, then its own file (after a CACHE_KEY); a layout is the
# placement prelude, the shared helpers, each model named on its "-- uses:" first line wrapped
# as build<Name>() and keyed by a hash of its source for modelkit's cache,
# then the layout itself.
#
#   scripts/assemble-model.sh Zapper

set -euo pipefail

name="${1:?model name required}"
root="$(cd "$(dirname "$0")/.." && pwd)"
src="${root}/art/src"
out="${root}/art/models/${name}/model.luau"

started=${SECONDS}
# Progress goes to stderr, so the script's output stays clean.
say() {
	echo "assemble ${name}: $*" >&2
}

mkdir -p "$(dirname "${out}")"
if [ -d "${src}/bots/${name}" ]; then
	say "bot: head, shared helpers, body"
	cat "${src}/bots/${name}/head.luau" "${src}/common.luau" "${src}/bots/${name}/body.luau" > "${out}"
elif [ -f "${src}/items/${name}.luau" ]; then
	# CACHE_KEY hashes the shared code and the item down to "-- cached
	# above", for a model.cached build of the part above that line.
	# An "-- include: <Name>" line pulls in art/src/shared/<Name>.luau.
	say "item: rarity, shared helpers, item"
	item="$(awk -v shared="${src}/shared" '/^-- include: / { file = shared "/" $3 ".luau"; while ((getline line < file) > 0) print line; close(file); next } 1' "${src}/items/${name}.luau")"
	key="$({ cat "${src}/rarity.luau" "${src}/common.luau"; printf '%s\n' "${item}" | sed '/^-- cached above$/q'; } | sha1sum | cut -c1-16)"
	{ echo "local CACHE_KEY = \"${name}-${key}\""; cat "${src}/rarity.luau" "${src}/common.luau"; printf '%s\n' "${item}"; } > "${out}"
	say "cache key ${name}-${key}"
elif [ -f "${src}/layouts/${name}.luau" ]; then
	# Skipped parts never reach the cache, so the skip rule is part of each key.
	skip="$(awk '/^skipPart = function/ { open = 1 } open { print } open && /^end/ { open = 0 }' "${src}/layouts/${name}.luau")"
	say "layout: prelude, rarity, shared helpers, used models, layout"
	{
		cat "${src}/layouts/prelude.luau" "${src}/rarity.luau" "${src}/common.luau"
		for used in $(head -n 1 "${src}/layouts/${name}.luau" | sed 's/^-- uses://'); do
			echo "local function build${used}()"
			cat "${root}/art/models/${used}/model.luau"
			echo "end"
			key="$({ cat "${src}/layouts/prelude.luau" "${root}/art/models/${used}/model.luau"; echo "${skip}"; } | sha1sum | cut -c1-16)"
			echo "buildKeys[build${used}] = \"${used}-${key}\""
			say "uses ${used} (key ${key})"
		done
	} > "${out}.head"
	layout="${src}/layouts/${name}.luau"
	# Each slab body runs from a line ending `slab(..., function()` to the
	# `end` at its indent. Its key hashes the body plus everything around
	# the bodies (prelude, helpers, used models, the layout outside slabs),
	# so editing one slab rebuilds only that slab, and editing shared code
	# rebuilds them all.
	spans="$(awk '!open && /slab\(.*function\(\)[ \t]*$/ { match($0, /^\t*/); indent = substr($0, 1, RLENGTH); start = NR; open = 1; next }
		open && index($0, indent "end") == 1 { print start, NR; open = 0 }' "${layout}")"
	outside="$(awk -v spans="${spans}" 'BEGIN { n = split(spans, s, /[ \n]/); for (i = 1; i < n; i += 2) for (l = s[i] + 1; l < s[i + 1]; l++) skip[l] = 1 }
		!skip[NR]' "${layout}" | cat "${out}.head" - | sha1sum | cut -c1-16)"
	offset=$(( $(wc -l < "${out}.head") + $(printf '%s\n' "${spans}" | grep -c . || true) ))
	{
		cat "${out}.head"
		while read -r start end; do
			[ -n "${start}" ] || continue
			body="$(sed -n "$((start + 1)),$((end - 1))p" "${layout}" | sha1sum | cut -c1-16)"
			echo "slabKeys[$((offset + start))] = \"${outside}-${body}\""
			say "slab at ${layout##*/}:${start}-${end} (key ${body})"
		done <<< "${spans}"
		cat "${layout}"
	} > "${out}"
	rm "${out}.head"
else
	echo "no source for ${name} in art/src" >&2
	exit 1
fi
say "wrote ${out#"${root}/"}, $(wc -l < "${out}") lines, in $((SECONDS - started))s"
