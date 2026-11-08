#!/usr/bin/env bash
# Sends a build task (scripts/send-build.sh) and reports on it as it goes,
# for a session to run under its Monitor tool: every line printed here is
# one event. Two sources feed it, so a result is never missed:
#   - events: send-build's own lines as the coordinator streams them back
#     (each shard's result, each preview, failures, timeouts);
#   - polling: every POLL seconds it looks in .standby-results for preview
#     folders that have landed since the last look, says when send-build has
#     gone quiet for STALL seconds, and says when it exits, with its status.
#
#   scripts/watch-build.sh <commit> [upload: yes|no]
#   PREVIEW=MinePortal,IslandPreview scripts/watch-build.sh "$(scripts/push-wip.sh)" no
#   PREVIEW_ONLY=1 PREVIEW=MineLoop scripts/watch-build.sh <commit> no   # no layout build

set -uo pipefail

commit="${1:?commit required}"
upload="${2:-no}"
poll="${POLL:-1}"
stall="${STALL:-180}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"

log="$(mktemp -t watch-build.XXXXXX)"
started=${SECONDS}
before="$(ls -t .standby-results 2> /dev/null | head -n 1)"

PYTHONUNBUFFERED=1 scripts/send-build.sh "${commit}" auto 1800 "${upload}" > "${log}" 2>&1 &
client=$!

# Events: send-build's lines worth acting on, the moment they're written;
# tail stops once send-build has exited.
tail -n +1 -F --pid="${client}" "${log}" 2> /dev/null | grep --line-buffered -E "preview |built in|FAILED|[Ee]rror|timed out|stops|no machines|refused" &
events=$!

# Polling: what has landed on disk, and whether send-build is still alive.
seen=""
quiet_since=${SECONDS}
size=0
while kill -0 "${client}" 2> /dev/null; do
	sleep "${poll}"
	task="$(ls -t .standby-results 2> /dev/null | head -n 1)"
	if [ -n "${task}" ] && [ "${task}" != "${before}" ]; then
		for folder in .standby-results/"${task}"/S*/previews/*/; do
			[ -f "${folder}preview.png" ] || [ -f "${folder}build.log" ] || continue
			name="$(basename "${folder}")"
			case " ${seen} " in *" ${name} "*) continue ;; esac
			# A share of a model's renders (<Name>@<i>@<n>) only counts when it
			# fails; the coordinator says when all of a model's shares are in.
			if [ "${name}" != "${name%%@*}" ]; then
				if grep -q FAILED "${folder}build.log" 2> /dev/null; then
					echo "poll: preview share ${name} FAILED ($(tail -n 3 "${folder}build.log" | tr '\n' ' '))"
					seen="${seen} ${name}"
				fi
				continue
			fi
			if [ -f "${folder}preview.png" ]; then
				echo "poll: preview ${name} is on disk (${folder})"
				seen="${seen} ${name}"
			elif grep -q FAILED "${folder}build.log" 2> /dev/null; then
				echo "poll: preview ${name} FAILED ($(tail -n 3 "${folder}build.log" | tr '\n' ' '))"
				seen="${seen} ${name}"
			fi
		done
	fi
	now="$(stat -c %s "${log}" 2> /dev/null || echo 0)"
	if [ "${now}" != "${size}" ]; then
		size="${now}"
		quiet_since=${SECONDS}
	elif [ $((SECONDS - quiet_since)) -ge "${stall}" ]; then
		echo "poll: send-build quiet for $((SECONDS - quiet_since))s, last line: $(tail -n 1 "${log}")"
		quiet_since=${SECONDS}
	fi
done
wait "${client}"
status=$?
wait "${events}" 2> /dev/null
echo "done: send-build exited ${status} after $((SECONDS - started))s; log ${log}"
