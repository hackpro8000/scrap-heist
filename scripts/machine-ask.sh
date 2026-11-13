#!/usr/bin/env bash
# Posts a cloud build machine's open question where the owner's session sees
# it at once: the branch machine-questions/m<n>, watched by
# scripts/machine-questions.sh. A machine runs this right before it ends a
# turn with a question for the owner, then asks the question as usual.
#
#   scripts/machine-ask.sh "<the question, as it will be asked>"
#
# The machine's number comes from the seat `cloud-worker.sh join` saved;
# without one it is posted as m0.

set -euo pipefail

question="${1:?the question is required}"
cd "$(dirname "$0")/.."
seat="$(git rev-parse --absolute-git-dir)/scrap-worker"
number="$(awk '{print $1}' "${seat}" 2> /dev/null || true)"
number="${number:-0}"
folder="$(mktemp -d)"
trap 'rm -rf "${folder}"' EXIT
{
	echo "machine: m${number}"
	echo "asked: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
	echo "worker: $(tail -n 2 /tmp/cloud-worker.log 2> /dev/null | tr '\n' ' ' | cut -c1-300)"
	echo
	echo "${question}"
} > "${folder}/question.txt"
scripts/push-folder.sh "${folder}" "machine-questions/m${number}" "m${number} asks" > /dev/null
echo "machine-ask: posted to machine-questions/m${number}"
