#!/usr/bin/env bash
# Builds one model, or every model, from its art/models/<Name>/model.luau
# with the prebuilt modelkit engine in tools/modelkit/bin. When Rust is
# installed it rebuilds the engine first and refreshes that binary, which
# then needs committing along with the engine change.
#
#   scripts/build-model.sh StarterWeapon
#   scripts/build-model.sh            # all models

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
modelkit="${root}/tools/modelkit/bin/modelkit-linux-x64"
if command -v cargo >/dev/null 2>&1; then
	cargo build -q --release --manifest-path "${root}/tools/modelkit/Cargo.toml"
	built="${root}/tools/modelkit/target/release/modelkit"
	cmp -s "${built}" "${modelkit}" || cp "${built}" "${modelkit}"
fi

models=("$@")
if [ ${#models[@]} -eq 0 ]; then
	for dir in "${root}"/art/models/*/; do
		models+=("$(basename "${dir}")")
	done
fi

for name in "${models[@]}"; do
	dir="${root}/art/models/${name}"
	if [ ! -f "${dir}/model.luau" ]; then
		echo "no model script: ${dir}/model.luau" >&2
		exit 1
	fi
	"${modelkit}" "${dir}"
done
