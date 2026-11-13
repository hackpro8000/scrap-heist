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

# Machines build each model from its assembled art/models/<Name>/model.luau,
# so a source edited since its models were assembled would ship stale. Any
# model whose assembled script names an art/src file changed in the working
# tree, and is older than it, is assembled again first.
changed_sources="$(git status --porcelain -- art/src | awk '{print $NF}' | rg '\.luau$' || true)"
for source in ${changed_sources}; do
	name="$(basename "${source}" .luau)"
	for script in $(rg -l --fixed-strings -e "${name}" art/models/*/model.luau 2> /dev/null || true); do
		[ "${script}" -nt "${source}" ] && continue
		model="$(basename "$(dirname "${script}")")"
		[ -f "art/src/items/${model}.luau" ] || [ -f "art/src/layouts/${model}.luau" ] || [ -d "art/src/bots/${model}" ] || continue
		echo "push-wip: ${model} was assembled before ${source} changed; assembling it again" >&2
		scripts/assemble-model.sh "${model}" > /dev/null || { echo "ALERT STALE_ASSEMBLY: ${model} would not assemble | fix it before building" >&2; exit 1; }
	done
done

# A layout's assembled script has each model on its "-- uses:" line pasted
# in as that model's own assembled script, so a layout assembled before one
# of them ships that model's old code. This runs after the pass above, which
# may just have renewed some of them.
for layout_source in art/src/layouts/*.luau; do
	layout="$(basename "${layout_source}" .luau)"
	script="art/models/${layout}/model.luau"
	[ -f "${script}" ] || continue
	for used in $(head -n 1 "${layout_source}" | rg '^-- uses:' | cut -d: -f2-); do
		if [ "art/models/${used}/model.luau" -nt "${script}" ] || [ "${layout_source}" -nt "${script}" ]; then
			echo "push-wip: ${layout} was assembled before ${used} (or its own source) changed; assembling it again" >&2
			scripts/assemble-model.sh "${layout}" > /dev/null || { echo "ALERT STALE_ASSEMBLY: ${layout} would not assemble | fix it before building" >&2; exit 1; }
			break
		fi
	done
done

# The machines run the engine binary in tools/modelkit/bin. When its source
# changed, a copy a machine already compiled is taken from the build-engine
# branch; otherwise the snapshot ships the source alone and machine 1
# compiles and shares it on the next build. Nothing compiles on this computer.
MODELKIT_NO_COMPILE=1 scripts/build-model.sh --engine || { echo "ALERT ENGINE_STALE: the engine would not refresh | fix the compile before building" >&2; exit 1; }

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
