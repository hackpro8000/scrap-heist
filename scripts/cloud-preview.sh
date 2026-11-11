#!/usr/bin/env bash
# Renders this machine's share of a set of model previews on a machine that
# is not on standby, such as a Claude cloud session machine, and sends them
# home by itself. No coordinator, no token, no upload.
#
#   scripts/cloud-preview.sh <task> <index> <count> <Name,Name,...>
#
# It prepares the machine (scripts/machine-setup/map-build.sh), renders every
# count-th name from its index with scripts/standby-previews.sh (preview.png
# and four turns per model, from the model's committed model.luau), then
# commits cloud-results/P<index>/ and pushes it to the branch
# cloud-previews/<task>/s<index>, where scripts/cloud-previews.sh collects
# it. Renders are 768 pixels (PREVIEW_SIZE changes that): they travel by git,
# so the 384 the tunnel needed does not apply.
#
# So the whole job is this one command. It pushes even when a render failed,
# so the log comes home either way.
set -uo pipefail

task="${1:?task name required}"
index="${2:?machine index required}"
count="${3:?machine count required}"
names="${4:?model names required}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"

scripts/machine-setup/map-build.sh || exit 1
export PATH="${HOME}/.local/bin:${PATH}"
[ -f "${HOME}/.cargo/env" ] && . "${HOME}/.cargo/env"
# As the workflow sets for every machine.
export MODELKIT_PRUNE=1
export PREVIEW_SIZE="${PREVIEW_SIZE:-768}"

out="${root}/cloud-results/P${index}"
rm -rf "${out}"
mkdir -p "${out}"
started="${SECONDS}"
scripts/standby-previews.sh "${names}" "${index}" "${count}" "${out}" > "${out}/previews.out" 2>&1
failed=0
for dir in "${out}"/previews/*/; do
	[ -d "${dir}" ] || continue
	name="$(basename "${dir}")"
	if [ -f "${dir}/preview.png" ]; then
		echo "preview ${name}: rendered"
	else
		echo "preview ${name}: FAILED: $(tail -n 3 "${dir}/build.log" 2> /dev/null | tr '\n' ' ' | cut -c1-200)"
		failed=1
	fi
done
echo "seconds=$((SECONDS - started))" > "${out}/machine.txt"
echo "machine ${index} of ${count}: previews done in $((SECONDS - started))s"

git add -f "${out}"
git -c user.name="scrap-heist cloud shard" -c user.email="cloud-shard@users.noreply.github.com" \
	commit -q -m "${task} previews ${index} of ${count}" || echo "cloud-preview: nothing to commit"
for attempt in 1 2 3 4; do
	if git push -q -f origin "HEAD:refs/heads/cloud-previews/${task}/s${index}"; then
		echo "cloud-preview: pushed cloud-previews/${task}/s${index}"
		break
	fi
	echo "cloud-preview: push attempt ${attempt} failed"
	sleep $((attempt * 2))
done
exit "${failed}"
