#!/usr/bin/env bash
# Checkpoints a model after every change: rebuilds it (saving the .glb,
# textures and preview), copies the preview to screenshot.png, then commits
# and pushes the model source on the current branch (outputs are gitignored),
# with its art/src files (source, plan, notes, preview flags). It also writes
# views.png, four turns round the model on one sheet, and screenshot-grid.png,
# the screenshot with a labelled 6x6 grid (A1 top left) beside the model's
# sketch, so the user can point at a cell instead of describing a spot;
# cells.txt names the parts in each cell. Each screenshot is also kept as
# history/<commit>.png for scripts/model-history.sh. Send the printed
# screenshot-grid and views to the user.
#
#   scripts/checkpoint-model.sh StarterWeapon "phase 1: StarterWeapon - shape the grip"

set -euo pipefail

name="${1:?model name required}"
message="${2:?commit message required}"
root="$(cd "$(dirname "$0")/.." && pwd)"
dir="${root}/art/models/${name}"
shot="${dir}/screenshot.png"

branch="$(git -C "${root}" branch --show-current)"
if [ -z "${branch}" ]; then
	echo "checkpoint must run on a branch, not a detached HEAD" >&2
	exit 1
fi

# Four turns round the model in the same build, so a checkpoint needs no
# separate preview pass to show its sides; --parts writes cells.txt.
"${root}/scripts/build-model.sh" "${name}" -- --turntable 4 --parts >/dev/null
cp "${dir}/preview.png" "${shot}"
views="${dir}/views.png"
montage "${dir}"/turntable/000[0-3].png -tile 2x2 -geometry +4+4 "${views}"

# The labelled grid matches the 6x6 cells in cells.txt, which cover the
# model's part of the picture.
size="$(identify -format '%w' "${shot}")"
IFS=, read -r x0 y0 x1 y1 < <(sed -n 's/^bounds: //p' "${dir}/cells.txt")
draw=()
for i in 0 1 2 3 4 5 6; do
	x=$(( x0 + (x1 - x0) * i / 6 ))
	y=$(( y0 + (y1 - y0) * i / 6 ))
	draw+=(-draw "line ${x},${y0} ${x},${y1}" -draw "line ${x0},${y} ${x1},${y}")
done
labels=()
for row in 1 2 3 4 5 6; do
	for column in A B C D E F; do
		index=$(( $(printf '%d' "'${column}") - 65 ))
		labels+=(-draw "text $(( x0 + (x1 - x0) * index / 6 + 4 )),$(( y0 + (y1 - y0) * (row - 1) / 6 + 16 )) '${column}${row}'")
	done
done
grid="${dir}/screenshot-grid.png"
convert "${shot}" -stroke 'rgba(255,255,255,0.5)' -strokewidth 1 "${draw[@]}" -stroke none -fill 'rgba(255,255,255,0.8)' -pointsize 14 "${labels[@]}" "${grid}"
sketch="${dir}/sketch.png"
kebab="$(echo "${name}" | sed -E 's/([a-z0-9])([A-Z])/\1-\2/g' | tr '[:upper:]' '[:lower:]')"
[ -f "${sketch}" ] || sketch="${root}/art/concepts/${kebab}-sketch.png"
if [ -f "${sketch}" ]; then
	montage -label sketch "${sketch}" -label "${name}" "${grid}" -tile 2x1 -geometry "${size}x${size}+4+4" -pointsize 18 "${grid}"
fi

git -C "${root}" add "${dir}"
for source in "${root}/art/src/items/${name}".* "${root}/art/src/bots/${name}"; do
	[ -e "${source}" ] && git -C "${root}" add "${source}"
done
if ! git -C "${root}" diff --cached --quiet; then
	git -C "${root}" commit -q -m "${message}"
	mkdir -p "${dir}/history"
	cp "${shot}" "${dir}/history/$(git -C "${root}" rev-parse --short HEAD).png"
fi
for delay in 0 2 4 8 16; do
	sleep "${delay}"
	git -C "${root}" push -q -u origin "${branch}" && break
done

echo "screenshot: ${shot}"
echo "screenshot with grid: ${grid}"
echo "views: ${views}"
