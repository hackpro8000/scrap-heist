#!/usr/bin/env bash
# Lists source files over the size rule in CLAUDE.md (aim under 300 lines,
# never over 500), largest first. Data files are left out.
#
#   scripts/file-sizes.sh          # files over 300 lines
#   scripts/file-sizes.sh 500      # files over 500 lines

set -euo pipefail

limit="${1:-300}"
cd "$(dirname "$0")/.."

git ls-files -co --exclude-standard |
	rg '\.(rs|py|sh|luau|yml)$' |
	rg -v '^(art/models|previews|Packages|src/shared/Animations)/|^src/shared/(Assets|Config/MapChunks)\.luau$' |
	while read -r file; do
		[ -f "${file}" ] || continue
		lines="$(wc -l < "${file}")"
		[ "${lines}" -gt "${limit}" ] && printf '%6d %s\n' "${lines}" "${file}"
	done | sort -rn || true
