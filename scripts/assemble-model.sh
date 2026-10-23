#!/usr/bin/env bash
# Assembles art/models/<Name>/model.luau from the split sources in art/src:
# a bot is its head, the shared helpers, then its body; an item is the
# rarity colors, the shared helpers, then its own file; a layout is the
# placement prelude, each model named on its "-- uses:" first line wrapped
# as build<Name>(), then the layout itself.
#
#   scripts/assemble-model.sh Zapper

set -euo pipefail

name="${1:?model name required}"
root="$(cd "$(dirname "$0")/.." && pwd)"
src="${root}/art/src"
out="${root}/art/models/${name}/model.luau"

mkdir -p "$(dirname "${out}")"
if [ -d "${src}/bots/${name}" ]; then
	cat "${src}/bots/${name}/head.luau" "${src}/common.luau" "${src}/bots/${name}/body.luau" > "${out}"
elif [ -f "${src}/items/${name}.luau" ]; then
	cat "${src}/rarity.luau" "${src}/common.luau" "${src}/items/${name}.luau" > "${out}"
elif [ -f "${src}/layouts/${name}.luau" ]; then
	{
		cat "${src}/layouts/prelude.luau"
		for used in $(head -n 1 "${src}/layouts/${name}.luau" | sed 's/^-- uses://'); do
			echo "local function build${used}()"
			cat "${root}/art/models/${used}/model.luau"
			echo "end"
		done
		cat "${src}/layouts/${name}.luau"
	} > "${out}"
else
	echo "no source for ${name} in art/src" >&2
	exit 1
fi
