#!/usr/bin/env bash
# Pushes a folder's files as the only commit on a branch, replacing what was
# there, and prints the commit. Build machines use it to hand files to each
# other and to this session through GitHub, not the coordinator's tunnel.
#
#   scripts/push-folder.sh <folder> <branch> <commit message>

set -euo pipefail

folder="${1:?folder required}"
branch="${2:?branch required}"
message="${3:?commit message required}"

index_file="$(mktemp -u)"
trap 'rm -f "${index_file}"' EXIT
GIT_INDEX_FILE="${index_file}" git --work-tree="${folder}" add -A -f --sparse
tree="$(GIT_INDEX_FILE="${index_file}" git write-tree)"
commit="$(git commit-tree "${tree}" -m "${message}")"
git push -q -f origin "${commit}:refs/heads/${branch}"
echo "${commit}"
