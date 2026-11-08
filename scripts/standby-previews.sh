#!/usr/bin/env bash
# Renders this shard's share of a task's previews with modelkit's own
# renderer, no Studio or upload needed (scripts/standby-agent.py runs it once
# the shard's build result has gone, so renders never hold a build back).
#
#   scripts/standby-previews.sh <Name,Name,...> <index> <count> <results folder>
#
# The shard takes every count-th name from its index and renders each from
# its committed model.luau (assembling here would rewrite the file a layout
# build reads) into <results>/previews/<Name>/: preview.png and four turns,
# view0-3.png. A model that fails leaves its build.log ending in FAILED.
# Renders are 384 pixels: they travel through the coordinator's tunnel, which
# is slow, and four make a 768-pixel sheet. They build with modelkit's
# --preview, at half the texel density, which is quicker and plenty at that
# size.

set -uo pipefail

names="${1:?model names required}"
index="${2:?shard index required}"
count="${3:?shard count required}"
out="${4:?results folder required}"

IFS=, read -ra list <<< "${names}"
n=0
for name in "${list[@]}"; do
	n=$((n + 1))
	[ $(((n - 1) % count + 1)) -eq "${index}" ] || continue
	dir="${out}/previews/${name}"
	mkdir -p "${dir}"
	# art/src/items/<Name>.preview-flags adds modelkit flags, say --eye views
	# from chosen spots; their renders come back too.
	extra=()
	[ -f "art/src/items/${name}.preview-flags" ] && read -ra extra < "art/src/items/${name}.preview-flags"
	if scripts/build-model.sh "${name}" -- --preview --turntable 4 --size "${PREVIEW_SIZE:-384}" "${extra[@]}" > "${dir}/build.log" 2>&1; then
		cp "art/models/${name}/preview.png" "${dir}/preview.png"
		for turn in 0 1 2 3; do
			cp "art/models/${name}/turntable/000${turn}.png" "${dir}/view${turn}.png"
		done
		# Review renders too, when the flags ask for them (--parts, --view):
		# a review sheet, or a checkpoint (FROM=), can be made from them.
		cp art/models/"${name}"/eye_*.png art/models/"${name}"/closeup_*.png art/models/"${name}"/parts.png art/models/"${name}"/face_*.png art/models/"${name}"/cells.txt "${dir}/" 2> /dev/null || true
	else
		echo "FAILED" >> "${dir}/build.log"
	fi
done
