#!/usr/bin/env bash
# Builds one model, or every model, from its art/models/<Name>/build.py.
#
#   scripts/build-model.sh StarterWeapon
#   scripts/build-model.sh            # all models

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
models=("$@")
if [ ${#models[@]} -eq 0 ]; then
	for dir in "${root}"/art/models/*/; do
		models+=("$(basename "${dir}")")
	done
fi

for name in "${models[@]}"; do
	dir="${root}/art/models/${name}"
	if [ ! -f "${dir}/build.py" ]; then
		echo "no build script: ${dir}/build.py" >&2
		exit 1
	fi

	PYTHONPATH="${root}/tools/blender" blender -b --factory-startup --python-use-system-env \
		--python-exit-code 1 --python "${dir}/build.py" -- "${dir}" \
		| grep -E '^(built|Error|Traceback)' || true

	test -f "${dir}/${name}.fbx" || { echo "build failed: ${name}" >&2; exit 1; }
done
