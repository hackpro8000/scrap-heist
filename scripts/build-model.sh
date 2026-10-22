#!/usr/bin/env bash
# Builds one model, or every model, from its art/models/<Name>/model.luau
# with the modelkit engine (rebuilt first if its source changed).
#
#   scripts/build-model.sh StarterWeapon
#   scripts/build-model.sh            # all models

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cargo build -q --release --manifest-path "${root}/tools/modelkit/Cargo.toml"
modelkit="${root}/tools/modelkit/target/release/modelkit"

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
