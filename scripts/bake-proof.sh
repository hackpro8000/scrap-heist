#!/usr/bin/env bash
# Proves a change to the engine (tools/modelkit) leaves models as they were,
# and times it: each model is built cold by the engine before the change and
# by the engine after it, and the two results are compared byte for byte.
# Run it on a build machine, never on the user's computer.
#
#   scripts/bake-proof.sh <folder of the engine before the change> <Model>...
#
# The folder holds that engine's src, Cargo.toml and Cargo.lock. One line per
# model goes to stdout:
#
#   proof <Model> before=<seconds>s/<peak MB> after=<seconds>s/<peak MB> <same|DIFFERENT|FAILED>
#
# Exits 1 when any model differs or fails to build.

set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"
before_src="${1:?folder of the engine before the change}"
shift

# Both engines compile side by side.
cargo build -q --release --manifest-path "${before_src}/Cargo.toml" >&2 &
before_build=$!
cargo build -q --release --manifest-path tools/modelkit/Cargo.toml >&2 &
after_build=$!
wait "${before_build}" || { echo "proof - the engine before the change did not compile FAILED"; exit 1; }
wait "${after_build}" || { echo "proof - the engine after the change did not compile FAILED"; exit 1; }
before="${before_src}/target/release/modelkit"
after="tools/modelkit/target/release/modelkit"

# Builds one model cold; prints "<seconds> <peak MB> <sha256 of the model>".
cold() {
	local engine="$1" name="$2" dir="art/models/$2" started ended peak="-"
	rm -f "${dir}/${name}.glb"
	started="$(date +%s.%N)"
	if [ -x /usr/bin/time ]; then
		MODELKIT_NO_CACHE=1 /usr/bin/time -f '%M' -o "${dir}/peak.txt" "${engine}" "${dir}" > "${dir}/build.out" 2>> "${dir}/proof.log" || return 1
		peak="$(($(tail -n 1 "${dir}/peak.txt") / 1024))"
	else
		MODELKIT_NO_CACHE=1 "${engine}" "${dir}" > "${dir}/build.out" 2>> "${dir}/proof.log" || return 1
	fi
	ended="$(date +%s.%N)"
	[ -f "${dir}/${name}.glb" ] || return 1
	echo "$(awk -v a="${started}" -v b="${ended}" 'BEGIN { printf "%.1f", b - a }') ${peak} $(sha256sum "${dir}/${name}.glb" | cut -c1-64)"
}

status=0
for name in "$@"; do
	scripts/assemble-model.sh "${name}" >&2 || { echo "proof ${name} did not assemble FAILED"; status=1; continue; }
	old="$(cold "${before}" "${name}")" || { echo "proof ${name} did not build before the change FAILED"; status=1; continue; }
	new="$(cold "${after}" "${name}")" || { echo "proof ${name} did not build after the change FAILED"; status=1; continue; }
	read -r old_seconds old_peak old_sha <<< "${old}"
	read -r new_seconds new_peak new_sha <<< "${new}"
	verdict="same"
	[ "${old_sha}" = "${new_sha}" ] || { verdict="DIFFERENT"; status=1; }
	echo "proof ${name} before=${old_seconds}s/${old_peak}MB after=${new_seconds}s/${new_peak}MB sha=${new_sha:0:12} ${verdict}"
done
exit "${status}"
