#!/usr/bin/env bash
# Collects previews rendered by cloud session machines
# (scripts/cloud-preview.sh): each pushed its share to the branch
# cloud-previews/<task>/s<index>. Waits until every branch is there, then
# puts each model's renders beside the model, as the coordinator does:
# art/models/<Name>/preview.png, the four turns as views.png, and the model
# script's hash in previewed.txt. Prints one line per model with the image
# to look at.
#
#   scripts/cloud-previews.sh <task> <count> [seconds to wait, default 600]
set -euo pipefail

task="${1:?task name required}"
count="${2:?machine count required}"
wait_seconds="${3:-600}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"
started="${SECONDS}"

while true; do
	found="$(git ls-remote origin "refs/heads/cloud-previews/${task}/s*" | wc -l)"
	[ "${found}" -ge "${count}" ] && break
	if [ $((SECONDS - started)) -ge "${wait_seconds}" ]; then
		echo "only ${found} of ${count} machines pushed in ${wait_seconds}s" >&2
		break
	fi
	sleep 5
done
echo "${found} of ${count} machines pushed after $((SECONDS - started))s"

failed=0
scratch="$(mktemp -d)"
trap 'rm -rf "${scratch}"' EXIT
for index in $(seq 1 "${count}"); do
	if ! git fetch -q origin "cloud-previews/${task}/s${index}" 2> /dev/null; then
		echo "machine ${index}: missing"
		failed=1
		continue
	fi
	mkdir -p "${scratch}/${index}"
	git archive FETCH_HEAD "cloud-results/P${index}" | tar -x -C "${scratch}/${index}" --strip-components=2
	for source in "${scratch}/${index}"/previews/*/; do
		[ -d "${source}" ] || continue
		name="$(basename "${source}")"
		model="art/models/${name}"
		if [ ! -f "${source}/preview.png" ] || [ ! -d "${model}" ]; then
			echo "${name}: FAILED on machine ${index}: $(tail -n 2 "${source}/build.log" 2> /dev/null | tr '\n' ' ' | cut -c1-160)"
			failed=1
			continue
		fi
		cp "${source}/preview.png" "${model}/preview.png"
		shown="${model}/preview.png"
		if command -v montage > /dev/null && [ -f "${source}/view0.png" ] && [ -f "${source}/view3.png" ]; then
			montage "${source}"/view{0,1,2,3}.png -tile 2x2 -geometry +4+4 "${model}/views.png"
			shown="${model}/views.png"
		fi
		[ -f "${model}/model.luau" ] && sha1sum "${model}/model.luau" | cut -c1-16 > "${model}/previewed.txt"
		echo "${name}: ${shown}"
	done
done
exit "${failed}"
