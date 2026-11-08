#!/usr/bin/env bash
# One self-review round of a model's first build (docs/art/pipeline.md, "First
# build"): assembles and checks the model, renders its preview, its parts in
# flat colours and square-on front, right and top views with a 1-stud grid,
# and lays them out on one sheet beside its sketch for the model-critic agent.
# Prints the sheet's path, the part colour legend and the check result, and
# exits 1 when the check finds a problem. Commits nothing.
#
#   scripts/review-model.sh MinePortal
#   SKETCH=art/concepts/mine-portal-sketch.png scripts/review-model.sh MinePortal
#
# Without SKETCH, the sketch is art/models/<Name>/sketch.png, or else
# art/concepts/<name-in-kebab-case>-sketch.png.

set -uo pipefail

name="${1:?model name required}"
root="$(cd "$(dirname "$0")/.." && pwd)"
src="${root}/art/src"
dir="${root}/art/models/${name}"
modelkit="${root}/tools/modelkit/bin/modelkit-linux-x64"
cd "${root}"

"${root}/scripts/build-model.sh" --engine || exit 1
if [ -e "${src}/bots/${name}" ] || [ -e "${src}/items/${name}.luau" ]; then
	"${root}/scripts/assemble-model.sh" "${name}" || exit 1
fi

check="$(lune run tools/modelcheck/check "${name}" 2>&1)"
check_status=$?

log="$(mktemp)"
trap 'rm -f "${log}"' EXIT
if ! legend="$("${modelkit}" "${dir}" --preview --parts --view front --view right --view top --grid 1 2>"${log}")"; then
	tail -n 20 "${log}" >&2
	exit 1
fi

sketch="${SKETCH:-}"
if [ -z "${sketch}" ]; then
	kebab="$(echo "${name}" | sed -E 's/([a-z0-9])([A-Z])/\1-\2/g' | tr '[:upper:]' '[:lower:]')"
	for candidate in "${dir}/sketch.png" "${root}/art/concepts/${kebab}-sketch.png"; do
		if [ -f "${candidate}" ]; then
			sketch="${candidate}"
			break
		fi
	done
fi

tiles=()
if [ -n "${sketch}" ]; then
	tiles+=(-label sketch "${sketch}")
fi
tiles+=(
	-label preview "${dir}/preview.png"
	-label parts "${dir}/parts.png"
	-label "front (1 stud grid)" "${dir}/face_front_parts.png"
	-label "right (1 stud grid)" "${dir}/face_right_parts.png"
	-label "top (1 stud grid)" "${dir}/face_top_parts.png"
)
review="${dir}/review.png"
montage "${tiles[@]}" -tile 3x -geometry 400x400+4+4 -pointsize 18 "${review}"

echo "review: ${review}"
echo "sketch: ${sketch:-none found}"
echo "parts:"
echo "${legend}"
echo "check:"
echo "${check}"
exit "${check_status}"
