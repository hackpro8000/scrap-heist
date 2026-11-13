#!/usr/bin/env bash
# One maintenance try of the build pipeline, in seconds rather than minutes
# (docs/plans/multi-machine.md, "Maintenance tries"): pushes the working
# tree, hot-updates the hub and machines if their code changed, compiles the
# engine on one machine if asked or if its source changed, and runs a small
# preview build. Prints one last line: TRY OK in Ns (update As, engine Bs,
# build Cs), or TRY FAILED at <step> after that step's output.
#
#   scripts/pipeline-try.sh                       # ProofKettle, 2 units
#   scripts/pipeline-try.sh --engine              # compile the engine even if unchanged
#   scripts/pipeline-try.sh --models A,B

set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}" || exit 1
force_engine=""
models="ProofKettle"
while [ $# -gt 0 ]; do
	case "$1" in
		--engine) force_engine=1 ;;
		--models) models="${2:?--models wants A,B}"; shift ;;
		*) echo "usage: scripts/pipeline-try.sh [--engine] [--models A,B]" >&2; exit 2 ;;
	esac
	shift
done
client=(python3 tools/coordinator/client.py)
logs="$(mktemp -d)"
trap 'rm -rf "${logs}"' EXIT
began="$(date +%s)"
update_seconds=0
engine_seconds=0
build_seconds=0

failed() {
	echo "TRY FAILED at $1"
	tail -n 200 "${logs}/$1.log"
	exit 1
}

# step <name> <command...>: its output shown as it comes (on stderr) and kept for the failure report.
step() {
	local name="$1"
	shift
	"$@" 2>&1 | tee "${logs}/${name}.log" >&2
	return "${PIPESTATUS[0]}"
}

step push scripts/push-wip.sh || failed push
sha="$(git rev-parse --verify "$(tail -n 1 "${logs}/push.log")^{commit}" 2> /dev/null)" || failed push

step status "${client[@]}" status || failed status
hub_code="$(rg -o -m 1 -r '$1' 'code=([0-9a-f]{40})' "${logs}/status.log" || true)"
needs_update=1
if [ -n "${hub_code}" ]; then
	git cat-file -e "${hub_code}^{commit}" 2> /dev/null || git fetch -q --depth=1 origin "${hub_code}" 2> /dev/null || true
	if git cat-file -e "${hub_code}^{commit}" 2> /dev/null \
		&& git diff --quiet "${hub_code}" "${sha}" -- tools/coordinator scripts/standby-agent.py scripts/standby_agent; then
		needs_update=""
	fi
fi
if [ -n "${needs_update}" ]; then
	started="$(date +%s)"
	step update "${client[@]}" update "${sha}" --wait 180 || failed update
	update_seconds=$(( $(date +%s) - started ))
else
	echo "pipeline-try: hub and agent code unchanged since the hub's ${hub_code:0:12}; no update" >&2
fi

needs_engine="${force_engine}"
if [ -z "${needs_engine}" ]; then
	# The same hash scripts/build-model.sh keeps; the build-engine branch holds the last one a machine compiled.
	source_sha="$(cd tools/modelkit && find src Cargo.toml Cargo.lock -type f | LC_ALL=C sort | xargs sha256sum | sha256sum | cut -c1-64)"
	shared=""
	git fetch -q --depth=1 origin refs/heads/build-engine 2> /dev/null && shared="$(git show FETCH_HEAD:source-sha 2> /dev/null || true)"
	[ "${shared}" = "${source_sha}" ] || needs_engine=1
fi
if [ -n "${needs_engine}" ]; then
	started="$(date +%s)"
	step engine "${client[@]}" engine "${sha}" --wait 900 || failed engine
	engine_seconds=$(( $(date +%s) - started ))
fi

started="$(date +%s)"
step build "${client[@]}" build "${sha}" --units 2 --no-upload --preview "${models}" --preview-only --wait 600 || failed build
build_seconds=$(( $(date +%s) - started ))

echo "TRY OK in $(( $(date +%s) - began ))s (update ${update_seconds}s, engine ${engine_seconds}s, build ${build_seconds}s)"
