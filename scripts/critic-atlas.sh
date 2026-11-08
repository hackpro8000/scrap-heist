#!/usr/bin/env bash
# Lays a model's finished renders out as atlases for the model-critic agent,
# so it reads them in two tool calls instead of one per image. Each atlas stays
# under about 1560 pixels a side so it isn't scaled down when read, and each
# camera's tile is labelled with its position. Prints the atlases' paths and
# the part colour legend.
#
#   scripts/critic-atlas.sh BuildBay                                # its newest render
#   scripts/critic-atlas.sh BuildBay .standby-results/t1794171326-1544496-0
#   SKETCH=art/concepts/other-sketch.png scripts/critic-atlas.sh BuildBay
#
# Needs the renders a review asks for: --parts and --view in the preview flags.

set -euo pipefail

name="${1:?model name required}"
results="${2:-}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"

if [ -z "${results}" ]; then
	for candidate in $(ls -t .standby-results); do
		if [ -f ".standby-results/${candidate}/previews/${name}/preview.png" ]; then
			results=".standby-results/${candidate}"
			break
		fi
	done
fi
folder="${root}/${results}/previews/${name}"
if [ -z "${results}" ] || [ ! -f "${folder}/preview.png" ]; then
	echo "no finished render of ${name}" >&2
	exit 1
fi

kebab=""
for ((i = 0; i < ${#name}; i++)); do
	letter="${name:i:1}"
	if [[ "${letter}" =~ [A-Z] ]] && [ "${i}" -gt 0 ]; then
		kebab+="-"
	fi
	kebab+="${letter,,}"
done
sketch="${SKETCH:-}"
if [ -z "${sketch}" ]; then
	for candidate in "art/models/${name}/sketch.png" "art/concepts/${kebab}-sketch.png"; do
		if [ -f "${candidate}" ]; then
			sketch="${candidate}"
			break
		fi
	done
fi

tiles=()
add_tile() {
	if [ -n "$2" ] && [ -f "$2" ]; then
		tiles+=(-label "$1" "$2")
	fi
}
lay_out() {
	montage "${tiles[@]}" -tile "$1" -geometry 488x488+3+3 -pointsize 16 "$2"
	tiles=()
}

add_tile sketch "${sketch}"
add_tile preview "${folder}/preview.png"
add_tile parts "${folder}/parts.png"
add_tile "front, 1 stud grid" "${folder}/face_front_parts.png"
add_tile "right, 1 stud grid" "${folder}/face_right_parts.png"
add_tile "top, 1 stud grid" "${folder}/face_top_parts.png"
lay_out 3x "${folder}/atlas_overview.png"

# Where each camera is, from the flags these renders asked for.
flags=()
flags_file="art/src/items/${name}.preview-flags"
if [ -f "${flags_file}" ]; then
	read -ra flags < "${flags_file}"
fi
cameras=()
for ((i = 0; i + 1 < ${#flags[@]}; i++)); do
	if [ "${flags[i]}" = "--eye" ]; then
		cameras+=("${flags[i + 1]}")
	fi
done

for ((n = 1; ; n++)); do
	if [ ! -f "${folder}/eye_${n}.png" ]; then
		break
	fi
	add_tile "eye ${n}: ${cameras[n - 1]:-}" "${folder}/eye_${n}.png"
done
for ((n = 1; ; n++)); do
	if [ ! -f "${folder}/closeup_${n}.png" ]; then
		break
	fi
	add_tile "closeup ${n}" "${folder}/closeup_${n}.png"
done

echo "atlas: ${folder}/atlas_overview.png"
rm -f "${folder}"/atlas_eyes*.png
if [ "${#tiles[@]}" -gt 0 ]; then
	# Past nine tiles, montage makes atlas_eyes-0.png, atlas_eyes-1.png and so on.
	lay_out 3x3 "${folder}/atlas_eyes.png"
	for atlas in "${folder}"/atlas_eyes*.png; do
		echo "atlas: ${atlas}"
	done
fi

echo "legend:"
awk '/^#[0-9a-f]+ / && !seen[$0]++' "${folder}"/build*.log
