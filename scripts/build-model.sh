#!/usr/bin/env bash
# Builds one model, or every model, from its art/models/<Name>/model.luau
# with the prebuilt modelkit engine in tools/modelkit/bin. When Rust is
# installed and the engine source has changed since the committed binary was
# built, it rebuilds the engine and refreshes that binary, which then needs
# committing along with the engine change. The source hash is kept in
# modelkit-linux-x64.source-sha, so an unchanged engine never rebuilds. An
# engine a build machine has already compiled from the same source is taken
# from the build-engine branch instead of being compiled again.
#
#   scripts/build-model.sh StarterWeapon
#   scripts/build-model.sh            # all models
#   scripts/build-model.sh StarterWeapon -- --turntable 4   # extra modelkit flags
#   scripts/build-model.sh --engine   # only refresh the engine binary

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
modelkit="${root}/tools/modelkit/bin/modelkit-linux-x64"
stamp="${modelkit}.source-sha"
# Hash the engine's sources and manifests by content, so only a real source change counts.
source_sha="$(cd "${root}/tools/modelkit" && find src Cargo.toml Cargo.lock -type f | LC_ALL=C sort | xargs sha256sum | sha256sum | cut -c1-64)"
if [ "$(cat "${stamp}" 2>/dev/null || true)" != "${source_sha}" ]; then
	# The first build machine to compile an engine leaves it on the
	# build-engine branch with its source hash (MODELKIT_SHARE_ENGINE=1), so
	# every machine after it takes that one instead of compiling for minutes.
	fetched="$(mktemp)"
	shared_engine() {
		git -C "${root}" fetch -q --depth=1 origin refs/heads/build-engine 2> /dev/null &&
			[ "$(git -C "${root}" show FETCH_HEAD:source-sha 2> /dev/null)" = "${source_sha}" ] &&
			git -C "${root}" show FETCH_HEAD:modelkit-linux-x64 > "${fetched}" 2> /dev/null
	}
	# On the standby machines only machine 1 compiles (and shares) a new
	# engine; the rest wait for its copy rather than all compiling the same
	# source for minutes at once, and compile themselves only if it never comes.
	if [ -n "${SHARD:-}" ] && [ "${SHARD}" != "1" ] && command -v cargo > /dev/null 2>&1; then
		waited=0
		until shared_engine || [ "${waited}" -ge "${ENGINE_WAIT_SECONDS:-480}" ]; do
			[ "${waited}" -eq 0 ] && echo "engine: waiting for machine 1's build of ${source_sha:0:12}" >&2
			sleep 10
			waited=$((waited + 10))
		done
		[ "${waited}" -ge "${ENGINE_WAIT_SECONDS:-480}" ] && echo "ALERT ENGINE_WAIT: machine 1 shared no engine in ${waited}s; compiling here" >&2
	fi
	[ "${SHARD:-}" = "1" ] && export MODELKIT_SHARE_ENGINE=1
	if [ -s "${fetched}" ] || shared_engine; then
		install -m 755 "${fetched}" "${modelkit}"
		echo "engine: taken from the build-engine branch" >&2
	elif [ "${MODELKIT_NO_COMPILE:-}" = "1" ]; then
		# The user's computer never compiles: the snapshot ships the engine
		# source, and machine 1 compiles it and shares it on build-engine.
		rm -f "${fetched}"
		echo "engine: source changed and no machine has compiled it yet; machine 1 compiles it on the next build" >&2
		exit 0
	elif command -v cargo >/dev/null 2>&1; then
		cargo build -q --release --manifest-path "${root}/tools/modelkit/Cargo.toml"
		cp "${root}/tools/modelkit/target/release/modelkit" "${modelkit}"
		if [ "${MODELKIT_SHARE_ENGINE:-}" = "1" ]; then
			shared="$(mktemp -d)"
			cp "${modelkit}" "${shared}/modelkit-linux-x64"
			echo "${source_sha}" > "${shared}/source-sha"
			(cd "${root}" && scripts/push-folder.sh "${shared}" build-engine "engine ${source_sha:0:12}" > /dev/null) || echo "engine: could not share it on the build-engine branch" >&2
			rm -rf "${shared}"
		fi
	else
		rm -f "${fetched}"
		echo "the engine in tools/modelkit/bin is older than its source, and there is no cargo to rebuild it" >&2
		exit 1
	fi
	rm -f "${fetched}"
	echo "${source_sha}" > "${stamp}"
fi

if [ "${1:-}" = "--engine" ]; then
	exit 0
fi

# Model names come first; anything after "--" goes to modelkit for every model.
models=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do
	models+=("$1")
	shift
done
[ $# -gt 0 ] && shift
flags=("$@")
if [ ${#models[@]} -eq 0 ]; then
	for dir in "${root}"/art/models/*/; do
		models+=("$(basename "${dir}")")
	done
fi

for name in "${models[@]}"; do
	dir="${root}/art/models/${name}"
	if [ ! -f "${dir}/model.luau" ]; then
		echo "no model script: ${dir}/model.luau" >&2
		exit 1
	fi
	# What the model's script prints (a layout's placements and build times)
	# is kept whole in build.out and shown once the build ends. Sent straight
	# to a log that the engine's progress also goes to, its lines get cut
	# where a progress message lands.
	status=0
	# On a standby machine the build is the out-of-memory killer's first
	# choice, so a runaway bake fails alone instead of taking down the agent,
	# the runner or (on machine 1) the hub that every machine depends on.
	oom=()
	[ -n "${SHARD:-}" ] && command -v choom > /dev/null && oom=(choom -n 1000 --)
	"${oom[@]}" "${modelkit}" "${dir}" "${flags[@]}" > "${dir}/build.out" || status=$?
	cat "${dir}/build.out"
	[ "${status}" -eq 0 ] || exit "${status}"
	# A rigged model's clips go to the game as a module the client plays
	# (src/client/Controllers/BotAnimationController.luau).
	if [ -f "${dir}/${name}Clips.luau" ]; then
		mkdir -p "${root}/src/shared/Animations"
		cp "${dir}/${name}Clips.luau" "${root}/src/shared/Animations/${name}.luau"
	fi
done
