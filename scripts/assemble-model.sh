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
	# An "-- include: <Name>" line pulls in art/src/shared/<Name>.luau, whose
	# own includes are pulled in too; each file comes in once, the first time.
	say "item: rarity, shared helpers, item"
	item="$(awk -v shared="${src}/shared" '
		function pull(file,    line, name) {
			while ((getline line < file) > 0) {
				if (line ~ /^-- include: /) {
					split(line, words, " ")
					name = words[3]
					if (!(name in seen)) { seen[name] = 1; pull(shared "/" name ".luau") }
				} else {
					print line
				}
			}
			close(file)
		}
		BEGIN { pull(ARGV[1]); exit }' "${src}/items/${name}.luau")"
	key="$({ cat "${src}/rarity.luau" "${src}/common.luau"; printf '%s\n' "${item}" | sed '/^-- cached above$/q'; } | sha1sum | cut -c1-16)"
	{ echo "local CACHE_KEY = \"${name}-${key}\""; cat "${src}/rarity.luau" "${src}/common.luau"; printf '%s\n' "${item}"; } > "${out}"
	say "cache key ${name}-${key}"
elif [ -f "${src}/layouts/${name}.luau" ]; then
	# Skipped parts never reach the cache, so the skip rule is part of each key.
	skip="$(awk '/^skipPart = function/ { open = 1 } open { print } open && /^end/ { open = 0 }' "${src}/layouts/${name}.luau")"
	# The prelude as the keys see it: without its "--#unkeyed" to "--#keyed"
	# blocks, which only tell or skip placements and never change a build.
	keyed_prelude="${out}.prelude"
	awk '/^\t*--#unkeyed$/ { s = 1; next } /^\t*--#keyed$/ { s = 0; next } !s' "${src}/layouts/prelude.luau" > "${keyed_prelude}"
	say "layout: prelude, rarity, shared helpers, used models, layout"
	{
		cat "${src}/layouts/prelude.luau" "${src}/rarity.luau" "${src}/common.luau"
		# Shared helpers the layout itself calls.
		for included in $(awk '/^-- include: / { print $3 }' "${src}/layouts/${name}.luau"); do
			cat "${src}/shared/${included}.luau"
		done
		# Builders are globals, not locals: a layout that uses many models
		# (the map's kit has one per junkrot) would run past Luau's limit
		# of 200 locals in one function.
		for used in $(head -n 1 "${src}/layouts/${name}.luau" | sed 's/^-- uses://'); do
			echo "function build${used}()"
			cat "${root}/art/models/${used}/model.luau"
			echo "end"
			key="$({ cat "${keyed_prelude}" "${root}/art/models/${used}/model.luau"; echo "${skip}"; } | sha1sum | cut -c1-16)"
			echo "buildKeys[build${used}] = \"${used}-${key}\""
			say "uses ${used} (key ${key})"
		done
	} > "${out}.head"
	layout="${src}/layouts/${name}.luau"
	# Each slab body runs from a line ending `slab(..., function()` to the
	# `end` at its indent. Its key hashes the body plus the code it can
	# reach: the prelude, the shared helpers and the layout outside slabs.
	# Not the models the layout uses (a slab can't place one: prelude.luau
	# refuses), nor the `-- uses:` line, nor lines between `-- slab keys
	# skip` and `-- slab keys resume` (the kit), so adding or editing a model
	# leaves every slab cached. Editing one slab rebuilds only that slab;
	# editing shared code rebuilds them all.
	shared_files=()
	while read -r included; do
		shared_files+=("${src}/shared/${included}.luau")
	done < <(awk '/^-- include: / { print $3 }' "${layout}")
	spans="$(awk '!open && /slab\(.*function\(\)[ \t]*$/ { match($0, /^\t*/); indent = substr($0, 1, RLENGTH); start = NR; open = 1; next }
		open && index($0, indent "end") == 1 { print start, NR; open = 0 }' "${layout}")"
	outside="$(awk -v spans="${spans}" 'BEGIN { n = split(spans, s, /[ \n]/); for (i = 1; i < n; i += 2) for (l = s[i] + 1; l < s[i + 1]; l++) skip[l] = 1 }
		NR == 1 && /^-- uses:/ { next }
		/^-- slab keys skip/ { skipping = 1; next }
		/^-- slab keys resume/ { skipping = 0; next }
		!skip[NR] && !skipping' "${layout}" | cat "${keyed_prelude}" "${src}/rarity.luau" "${src}/common.luau" "${shared_files[@]}" - | sha1sum | cut -c1-16)"
	# Measured build times for dealing placements to shards (see prelude.luau),
	# written by the build-map-shards workflow. They go on one line ahead of
	# everything and into no key, so new timings never invalidate the cache.
	costs="${src}/layouts/${name}Costs.txt"
	costs_line="local SHARD_COSTS = { $(if [ -f "${costs}" ]; then awk -F'\t' 'NF == 2 { printf "[\"%s\"] = %s, ", $1, $2 }' "${costs}"; fi) }"
	# Measured paint times for dealing a split model's parts (scripts/paint-costs.sh
	# writes them). Unlike the costs above they change which shard keeps which
	# part, so PAINT_DEAL, a hash of them, goes into each split part's key
	# (prelude.luau). On the same line, so the line numbers below stay put.
	paint_costs="${src}/layouts/${name}PaintCosts.txt"
	costs_line="${costs_line} local PAINT_COSTS: { [string]: number } = { $(if [ -f "${paint_costs}" ]; then awk -F'\t' 'NF == 2 { printf "[\"%s\"] = %s, ", $1, $2 }' "${paint_costs}"; fi) } local PAINT_DEAL = \"$(if [ -f "${paint_costs}" ]; then sha1sum < "${paint_costs}" | cut -c1-12; fi)\""
	# The objects a sharded build skips (prelude.luau, skipsBuilt): each keyed
	# object in <Name>Objects.tsv (scripts/merge-shards.sh writes it) whose
	# every piece has an asset in <Name>Uploads.tsv, with the turns modulo 90
	# it has stood at. From files in the commit, so every machine skips alike;
	# on the first line, so no line number or key moves. MAP_FULL_BUILD=1
	# leaves it empty: everything builds.
	skip_built="$(python3 - "${src}/layouts/${name}Objects.tsv" "${src}/layouts/${name}Uploads.tsv" "${MAP_FULL_BUILD:-0}" << 'EOF'
import os, sys
record, ledger, full = sys.argv[1:]
if full == "1" or not os.path.isfile(record):
	sys.exit()
uploaded = {line.split("\t")[0] for line in open(ledger)} if os.path.isfile(ledger) else set()
pieces, turns = {}, {}
for line in open(record):
	fields = line.rstrip("\n").split("\t")
	if fields[0] == "object":
		pieces.setdefault(fields[3], []).append(fields[1])
	elif fields[0] == "placed":
		residue = f"{float(fields[4]) % 90:.6f}"
		turns.setdefault(fields[1], set()).add("0.000000" if residue == "90.000000" else residue)
for key in sorted(pieces):
	ids = pieces[key]
	if '"' in key or "\\" in key or not all(i in uploaded and i in turns for i in ids):
		continue
	shared = set.intersection(*(turns[i] for i in ids))
	if shared:
		print(f'["{key}"] = " {" ".join(sorted(shared))} ", ', end="")
EOF
)" || exit 1
	costs_line="${costs_line} local SKIP_BUILT: { [string]: string } = { ${skip_built}}"
	offset=$(( 1 + $(wc -l < "${out}.head") + $(printf '%s\n' "${spans}" | grep -c . || true) ))
	{
		echo "${costs_line}"
		cat "${out}.head"
		while read -r start end; do
			[ -n "${start}" ] || continue
			body="$(sed -n "$((start + 1)),$((end - 1))p" "${layout}" | sha1sum | cut -c1-16)"
			echo "slabKeys[$((offset + start))] = \"${outside}-${body}\""
			say "slab at ${layout##*/}:${start}-${end} (key ${body})"
		done <<< "${spans}"
		cat "${layout}"
	} > "${out}"
	rm "${out}.head" "${keyed_prelude}"
	say "$(printf '%s' "${skip_built}" | tr -cd ']' | wc -c) built objects to skip"
else
	echo "no source for ${name} in art/src" >&2
	exit 1
fi
say "wrote ${out#"${root}/"}, $(wc -l < "${out}") lines, in $((SECONDS - started))s"
