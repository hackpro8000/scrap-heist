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
# Renders are 384 pixels unless the model's flags say otherwise: they travel
# through the coordinator's tunnel, which is slow, and four make a 768-pixel
# sheet. They build with modelkit's --preview, at half the texel density,
# unless the flags say --full.
#
# A name may be one machine's share of a model's renders, <Name>@<i>@<n>:
# the model is baked here as usual, but only every n-th render from the
# i-th is made (modelkit --renders i/n), into <results>/previews/<Name>@<i>@<n>/;
# the coordinator merges the shares back into one folder. So one model's
# renders spread over every machine, each claiming the next job as it comes
# free. Each machine bakes only the textures it claimed first (modelkit --share-bakes, in the same run) and takes the rest from
# the others, so no two bake the same one; scripts/standby-agent.py runs that.

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
	model="${name%%@*}"
	share=()
	if [ "${model}" != "${name}" ]; then
		part="${name#*@}"
		share=(--renders "${part%@*}/${part#*@}")
	fi
	# With the agent's work port, machines claim each next job instead.
	[ -z "${WORK_PORT:-}" ] || share=(--work-port "${WORK_PORT}" --share-bakes)
	# art/src/items/<Name>.preview-flags adds modelkit flags, say --eye views
	# from chosen spots; their renders come back too. Its own --size replaces
	# the default, --full bakes at full texel density instead of --preview's
	# half, and --max-detail (passed through) puts every texture at the cap.
	flags=()
	[ -f "art/src/items/${model}.preview-flags" ] && read -ra flags < "art/src/items/${model}.preview-flags"
	extra=()
	quality=(--preview)
	size=(--size "${PREVIEW_SIZE:-384}")
	for flag in "${flags[@]}"; do
		case "${flag}" in
			--full) quality=() ;;
			--size) size=() ;;
		esac
		[ "${flag}" = "--full" ] || extra+=("${flag}")
	done
	# Renders left from an earlier task on this machine must not go back as
	# this one's.
	rendered="art/models/${model}"
	rm -rf "${rendered}"/preview.png "${rendered}"/eye_*.png "${rendered}"/closeup_*.png "${rendered}"/parts.png "${rendered}"/face_*.png "${rendered}"/cells.txt "${rendered}"/turntable
	if scripts/build-model.sh "${model}" -- "${quality[@]}" --turntable 4 "${size[@]}" "${share[@]}" "${extra[@]}" > "${dir}/build.log" 2>&1; then
		cp "${rendered}/preview.png" "${dir}/preview.png" 2> /dev/null || true
		for turn in 0 1 2 3; do
			cp "${rendered}/turntable/000${turn}.png" "${dir}/view${turn}.png" 2> /dev/null || true
		done
		# Review renders too, when the flags ask for them (--parts, --view):
		# a review sheet, or a checkpoint (FROM=), can be made from them.
		cp "${rendered}"/eye_*.png "${rendered}"/closeup_*.png "${rendered}"/parts.png "${rendered}"/face_*.png "${rendered}"/cells.txt "${dir}/" 2> /dev/null || true
	else
		echo "FAILED" >> "${dir}/build.log"
	fi
done
