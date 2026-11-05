#!/usr/bin/env bash
# Pushes the working tree as it is, committed or not, to a scratch branch so
# build workers can build it (see docs/builds/workers.md), and prints the
# commit to name in a job line (@<commit>). The current branch, index and
# files are left alone; the snapshot sits on top of HEAD in a temporary index.
# Ignored files stay out, as with git add -A.
#
#   scripts/push-wip.sh                  # to wip/coordinator
#   scripts/push-wip.sh wip/crane        # to another scratch branch

set -euo pipefail

branch="${1:-wip/coordinator}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"

index="$(mktemp)"
trap 'rm -f "${index}"' EXIT
GIT_INDEX_FILE="${index}" git read-tree HEAD
GIT_INDEX_FILE="${index}" git add -A
tree="$(GIT_INDEX_FILE="${index}" git write-tree)"
commit="$(git commit-tree "${tree}" -p HEAD -m "wip snapshot of $(git rev-parse --short HEAD) for build workers")"
git push -q -f origin "${commit}:refs/heads/${branch}"
short="$(git rev-parse --short "${commit}")"
echo "pushed ${short} to ${branch}; build it with @${short}" >&2
echo "${short}"
