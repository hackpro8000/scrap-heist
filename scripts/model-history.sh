#!/usr/bin/env bash
# Lays the screenshots of a model's last checkpoints side by side, oldest on
# the left, each labelled with its commit, so a lost direction can be picked
# up from the one that felt right. checkpoint-model.sh keeps each screenshot in
# art/models/<Name>/history/<commit>.png (gitignored, so only checkpoints made
# on this machine are there).
#
#   scripts/model-history.sh MinePortal       # last 8
#   scripts/model-history.sh MinePortal 12

set -euo pipefail

name="${1:?model name required}"
count="${2:-8}"
root="$(cd "$(dirname "$0")/.." && pwd)"
dir="${root}/art/models/${name}"

tiles=()
while read -r commit subject; do
	shot="${dir}/history/${commit}.png"
	[ -f "${shot}" ] || continue
	tiles=(-label "${commit} ${subject:0:40}" "${shot}" "${tiles[@]}")
	[ $(( ${#tiles[@]} / 3 )) -ge "${count}" ] && break
done < <(git -C "${root}" log --format='%h %s' -- "art/models/${name}")

if [ ${#tiles[@]} -eq 0 ]; then
	echo "no checkpoint screenshots for ${name} in ${dir}/history" >&2
	exit 1
fi
strip="${dir}/history.png"
montage "${tiles[@]}" -tile 4x -geometry 320x320+4+4 -pointsize 14 "${strip}"
echo "history: ${strip}"
