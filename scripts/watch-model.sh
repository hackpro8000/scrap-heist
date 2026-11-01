#!/usr/bin/env bash
# Quick tweaks: keeps one model building at preview density and re-renders
# art/models/<Name>/preview.png every time its source is saved. Models with
# split sources in art/src are re-assembled when any art/src file changes, and
# modelkit --watch rebuilds when the assembled model.luau changes. Nothing is
# committed; checkpoint the result with checkpoint-model.sh once it looks right.
#
#   scripts/watch-model.sh IslandStudy
#   scripts/watch-model.sh IslandStudy --eye 95,0,-8,0,0,-12   # extra modelkit flags

set -euo pipefail

name="${1:?model name required}"
shift
root="$(cd "$(dirname "$0")/.." && pwd)"
src="${root}/art/src"
dir="${root}/art/models/${name}"
modelkit="${root}/tools/modelkit/bin/modelkit-linux-x64"

"${root}/scripts/build-model.sh" --engine

split=false
if [ -e "${src}/bots/${name}" ] || [ -e "${src}/items/${name}.luau" ] || [ -e "${src}/layouts/${name}.luau" ]; then
	split=true
	"${root}/scripts/assemble-model.sh" "${name}"
fi
if [ ! -f "${dir}/model.luau" ]; then
	echo "no model script: ${dir}/model.luau" >&2
	exit 1
fi

"${modelkit}" "${dir}" --watch --preview "$@" &
watcher=$!
trap 'kill "${watcher}" 2>/dev/null' EXIT
echo "preview: ${dir}/preview.png" >&2

if ! ${split}; then
	wait "${watcher}"
	exit
fi

# Poll art/src once a second; a save there re-assembles, which modelkit sees.
stamp="$(mktemp)"
trap 'kill "${watcher}" 2>/dev/null; rm -f "${stamp}"' EXIT
while kill -0 "${watcher}" 2>/dev/null; do
	sleep 1
	if [ -n "$(find "${src}" -type f -newer "${stamp}" -print -quit)" ]; then
		touch "${stamp}"
		"${root}/scripts/assemble-model.sh" "${name}" || echo "assemble failed; fix and save again" >&2
	fi
done
