#!/usr/bin/env bash
# Renders extra views the model-critic agent asked for (the VIEW lines in its
# reply) on the build machines, lays them out as one atlas for it to read in a
# single tool call, and prints the atlas's path. The item's preview flags are
# put back as they were, and nothing is committed.
#
#   scripts/critic-views.sh BuildBay "--eye 1,-6,5,1,3.8,5" "--closeup -2.5,3.8,4,1.8,0" "--view back"
#
# Items only: bots have no preview flags.

set -euo pipefail

name="${1:?model name required}"
shift
if [ "$#" -eq 0 ]; then
	echo "no views asked for" >&2
	exit 1
fi
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"

flags_file="art/src/items/${name}.preview-flags"
if [ ! -f "${flags_file}" ]; then
	echo "no ${flags_file}" >&2
	exit 1
fi
status="$(scripts/coordinator.sh status 2>&1 | tail -n 1)"
if [[ ! "${status}" =~ up=[1-9] ]]; then
	echo "no build machines up (${status}); start them with scripts/standby-start.sh 20" >&2
	exit 1
fi

current="$(cat "${flags_file}")"
count_flag() {
	local n=0 word
	for word in ${current}; do
		if [ "${word}" = "$1" ]; then
			n=$((n + 1))
		fi
	done
	echo "${n}"
}

# New renders are numbered after the ones the flags already ask for.
eyes="$(count_flag --eye)"
closeups="$(count_flag --closeup)"
files=()
for request in "$@"; do
	read -r flag value <<< "${request}"
	case "${flag}" in
		--eye)
			eyes=$((eyes + 1))
			files+=("eye_${eyes}.png")
			;;
		--closeup)
			closeups=$((closeups + 1))
			files+=("closeup_${closeups}.png")
			;;
		--view) files+=("face_${value}.png") ;;
		*)
			echo "can't render: ${request}" >&2
			exit 1
			;;
	esac
done

scripts/assemble-model.sh "${name}" > /dev/null

grid=""
if [ "$(count_flag --grid)" -eq 0 ]; then
	grid=" --grid 1"
fi
original="$(mktemp)"
log="$(mktemp)"
cp "${flags_file}" "${original}"
put_back() {
	cp "${original}" "${flags_file}"
}
trap put_back EXIT
printf '%s %s%s\n' "${current}" "$*" "${grid}" > "${flags_file}"
commit="$(scripts/push-wip.sh 2> /dev/null | tail -n 1)"
put_back

if ! CHECK=skip PREVIEW_ONLY=1 PREVIEW="${name}" scripts/watch-build.sh "${commit}" no > "${log}" 2>&1; then
	tail -n 20 "${log}" >&2
	exit 1
fi
if [[ ! "$(cat "${log}")" =~ results\ in\ ([^[:space:]]+) ]]; then
	tail -n 20 "${log}" >&2
	echo "the build reported no results folder" >&2
	exit 1
fi
results="${BASH_REMATCH[1]}"

folder="${root}/${results}/previews/${name}"
missing=0
index=0
tiles=()
for request in "$@"; do
	path="${folder}/${files[${index}]}"
	index=$((index + 1))
	if [ -f "${path}" ]; then
		tiles+=(-label "${request}" "${path}")
	else
		echo "MISSING ${request}: ${path}"
		missing=1
	fi
done
if [ "${#tiles[@]}" -gt 0 ]; then
	montage "${tiles[@]}" -tile 2x -geometry 740x740+3+3 -pointsize 18 "${folder}/atlas_views.png"
	echo "atlas: ${folder}/atlas_views.png"
fi
exit "${missing}"
