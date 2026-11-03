#!/usr/bin/env bash
# Builds one model, or every model, from its art/models/<Name>/model.luau
# with the prebuilt modelkit engine in tools/modelkit/bin. When Rust is
# installed and the engine source has changed since the committed binary was
# built, it rebuilds the engine and refreshes that binary, which then needs
# committing along with the engine change. The source hash is kept in
# modelkit-linux-x64.source-sha, so an unchanged engine never rebuilds.
#
#   scripts/build-model.sh StarterWeapon
#   scripts/build-model.sh            # all models
#   scripts/build-model.sh StarterWeapon -- --turntable 4   # extra modelkit flags
#   scripts/build-model.sh --engine   # only refresh the engine binary

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
modelkit="${root}/tools/modelkit/bin/modelkit-linux-x64"
stamp="${modelkit}.source-sha"
if command -v cargo >/dev/null 2>&1; then
	# Hash the engine's sources and manifests by content, so only a real source change counts.
	source_sha="$(cd "${root}/tools/modelkit" && find src Cargo.toml Cargo.lock -type f | LC_ALL=C sort | xargs sha256sum | sha256sum | cut -c1-64)"
	if [ "$(cat "${stamp}" 2>/dev/null || true)" != "${source_sha}" ]; then
		cargo build -q --release --manifest-path "${root}/tools/modelkit/Cargo.toml"
		cp "${root}/tools/modelkit/target/release/modelkit" "${modelkit}"
		echo "${source_sha}" > "${stamp}"
	fi
fi

if [ "${1:-}" = "--engine" ]; then
	exit 0
fi

# Model names come first; anything after "--" goes to modelkit for every model.
models=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do
	models+=("$1")
	shift
done
[ $# -gt 0 ] && shift
flags=("$@")
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
	"${modelkit}" "${dir}" "${flags[@]}"
done
