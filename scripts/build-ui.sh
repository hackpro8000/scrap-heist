#!/usr/bin/env bash
# Paints one UI kit, or every kit, from its art/ui/<Kit>/ui.luau with the
# prebuilt uikit engine in tools/uikit/bin. When Rust is installed it
# rebuilds the engine first and refreshes that binary, which then needs
# committing along with the engine change.
#
#   scripts/build-ui.sh ScrapKit
#   scripts/build-ui.sh           # all kits

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
uikit="${root}/tools/uikit/bin/uikit-linux-x64"
if command -v cargo >/dev/null 2>&1; then
	cargo build -q --release --manifest-path "${root}/tools/uikit/Cargo.toml"
	built="${root}/tools/uikit/target/release/uikit"
	cmp -s "${built}" "${uikit}" || cp "${built}" "${uikit}"
fi

kits=("$@")
if [ ${#kits[@]} -eq 0 ]; then
	for dir in "${root}"/art/ui/*/; do
		kits+=("$(basename "${dir}")")
	done
fi

for name in "${kits[@]}"; do
	dir="${root}/art/ui/${name}"
	if [ ! -f "${dir}/ui.luau" ]; then
		echo "no kit script: ${dir}/ui.luau" >&2
		exit 1
	fi
	"${uikit}" "${dir}"
done
