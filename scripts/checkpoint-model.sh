#!/usr/bin/env bash
# Checkpoints a model after every change: rebuilds it (saving the .glb,
# textures and preview), copies the preview to screenshot.png, then commits
# and pushes the model source on the current branch (outputs are gitignored). It also
# writes views.png, four turns round the model on one sheet. Send the printed
# screenshot and views to the user.
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
# separate preview pass to show its sides.
"${root}/scripts/build-model.sh" "${name}" -- --turntable 4
cp "${dir}/preview.png" "${shot}"
views="${dir}/views.png"
montage "${dir}"/turntable/000[0-3].png -tile 2x2 -geometry +4+4 "${views}"

git -C "${root}" add "${dir}"
git -C "${root}" diff --cached --quiet || git -C "${root}" commit -q -m "${message}"
for delay in 0 2 4 8 16; do
	sleep "${delay}"
	git -C "${root}" push -q -u origin "${branch}" && break
done

echo "screenshot: ${shot}"
echo "views: ${views}"
