#!/usr/bin/env bash
# Checkpoints a model after every Blender change: rebuilds it (saving the
# .blend, .fbx and preview), screenshots the desktop, then commits and pushes
# the models branch. Send the printed screenshot to the user.
#
#   scripts/checkpoint-model.sh StarterWeapon "phase 1: StarterWeapon - shape the grip"

set -euo pipefail

name="${1:?model name required}"
message="${2:?commit message required}"
root="$(cd "$(dirname "$0")/.." && pwd)"
dir="${root}/art/models/${name}"
shot="${dir}/screenshot.png"

branch="$(git -C "${root}" branch --show-current)"
if [ "${branch}" != "models" ]; then
	echo "checkpoint must run on the models branch (on ${branch})" >&2
	exit 1
fi

"${root}/scripts/build-model.sh" "${name}"
"${root}/scripts/desktop.sh" screenshot "${shot}"

git -C "${root}" add "${dir}"
git -C "${root}" commit -q -m "${message}"
for delay in 0 2 4 8 16; do
	sleep "${delay}"
	git -C "${root}" push -q -u origin models && break
done

echo "screenshot: ${shot}"
