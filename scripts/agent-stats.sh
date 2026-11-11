#!/usr/bin/env bash
# Prints one row per subagent run: seconds, model calls and tokens, read from
# the agent's own log so the caller's reaction time is not in the numbers.
#
#   scripts/agent-stats.sh [--since <UTC timestamp>] <label>=<log file> ...
#
# A log file is the `output_file` path the Agent tool prints at launch.
# --since counts only events at or after that time (2026-11-11T01:00:11), for
# a follow-up sent to an agent that already ran.
set -euo pipefail

since=""
if [ "${1:-}" = "--since" ]; then
	since="$2"
	shift 2
fi
if [ "$#" -eq 0 ]; then
	echo "usage: scripts/agent-stats.sh [--since <UTC timestamp>] <label>=<log file> ..." >&2
	exit 2
fi

for pair in "$@"; do
	label="${pair%%=*}"
	log="${pair#*=}"
	if [ ! -f "$log" ]; then
		echo "agent-stats: no log at $log" >&2
		exit 1
	fi
	jq -rs --arg label "$label" --arg since "$since" '
		def seconds: (.[0:19] + "Z" | fromdate) + (.[20:23] | tonumber) / 1000;
		def usage: .message.usage;
		def context: usage | .input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens;
		[.[] | select(.timestamp != null and .timestamp >= $since)] as $events
		| ([$events[] | select(.type == "assistant")] | unique_by(.message.id)) as $calls
		| [
			$label,
			($calls[0].message.model // "?"),
			((($events[-1].timestamp | seconds) - ($events[0].timestamp | seconds)) * 10 | round / 10),
			($calls | length),
			($calls[0] | context),
			([$calls[] | context] | add),
			([$calls[] | usage.cache_read_input_tokens] | add),
			([$calls[] | usage.output_tokens] | add)
		] | @tsv' "$log"
done | column -t -s $'\t' -N run,model,secs,calls,start_ctx,tokens_processed,from_cache,out
