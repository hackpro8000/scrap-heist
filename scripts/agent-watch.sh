#!/usr/bin/env bash
# The observer's eyes: one row per subagent with what it is doing right now,
# read from its own log, and a flag where it needs a look.
#
#   scripts/agent-watch.sh [options] [<log file> ...]
#
#   --idle <secs>     STALL when a running agent has been silent this long (90)
#   --budget <tokens> BUDGET when an agent has processed more than this (150000)
#   --lane <regex>    LANE when an agent edits a file the regex doesn't match
#   --recent <mins>   with no log files: agents active in this many minutes (30)
#   --until-flag      keep watching; print and exit at the first new flag, or
#                     when every agent is done. Run it in the background.
#
# With no log files it takes this project's subagent logs. LOOP means the
# same tool call was made three times or more. LANE and files_edited see only
# the Edit and Write tools; a file changed from the shell is invisible here,
# which is why the worker definitions tell agents to use Edit.
set -euo pipefail

idle=90
budget=150000
lane=""
recent=30
until_flag=no
while [ "$#" -gt 0 ]; do
	case "$1" in
		--idle) idle="$2"; shift 2 ;;
		--budget) budget="$2"; shift 2 ;;
		--lane) lane="$2"; shift 2 ;;
		--recent) recent="$2"; shift 2 ;;
		--until-flag) until_flag=yes; shift ;;
		*) break ;;
	esac
done

root="$(cd "$(dirname "$0")/.." && pwd)"
project="${HOME}/.claude/projects/$(printf '%s' "${root}" | sd '[^A-Za-z0-9]' '-')"

logs() {
	if [ "$#" -gt 0 ]; then
		printf '%s\n' "$@"
	else
		find "${project}" -path '*/subagents/agent-*.jsonl' -mmin "-${recent}" 2> /dev/null | sort
	fi
}

rows() {
	logs "$@" | while read -r log; do
		[ -f "${log}" ] || continue
		name="$(basename "${log}" .jsonl)"
		jq -rs --arg name "${name#agent-}" --argjson idle "${idle}" --argjson budget "${budget}" --arg lane "${lane}" '
			def seconds: (.[0:19] + "Z" | fromdate) + (.[20:23] | tonumber) / 1000;
			def context: .message.usage | .input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens;
			[.[] | select(.timestamp != null)] as $events
			| ([$events[] | select(.type == "assistant")]) as $said
			| ($said | unique_by(.message.id)) as $calls
			| [$said[] | .message.content[]? | select(.type == "tool_use")] as $uses
			| ($uses | group_by([.name, .input]) | map(length) | max // 0) as $repeat
			| ([$uses[] | select(.name == "Edit" or .name == "Write") | .input.file_path] | unique) as $edited
			| $events[-1] as $last
			# An agent ends its turn by handing its report back; a follow-up
			# message after that (a user event that is not a tool result) restarts it.
			| ([$events | to_entries[] | select(.value.type == "assistant" and any(.value.message.content[]?; .type == "tool_use" and .name == "SubagentHandback")) | .key] | last) as $handed
			| ($handed != null and ([$events[$handed + 1:][] | select(.type == "assistant" or (.type == "user" and ((.message.content | type) == "string" or any(.message.content[]?; .type == "text"))))] | length) == 0) as $done
			| ((now - ($last.timestamp | seconds)) | round) as $silent
			| ([$calls[] | context] | add // 0) as $processed
			| [
				(if $done then empty elif $silent > $idle then "STALL" else empty end),
				(if $repeat >= 3 then "LOOP" else empty end),
				(if $processed > $budget then "BUDGET" else empty end),
				(if $lane != "" and ([$edited[] | select(test($lane) | not)] | length) > 0 then "LANE" else empty end)
			] as $flags
			| [
				$name,
				($calls[0].message.model // "?"),
				(if $done then "done" else "running" end),
				$silent,
				($calls | length),
				$processed,
				$repeat,
				($edited | length),
				(if ($flags | length) > 0 then $flags | join(",") else "-" end)
			] | @tsv' "${log}"
	done
}

table() {
	column -t -s $'\t' -N agent,model,state,silent,calls,tokens_processed,repeats,files_edited,flags
}

if [ "${until_flag}" = no ]; then
	rows "$@" | table
	exit 0
fi

seen=""
while true; do
	current="$(rows "$@")"
	fresh="$(printf '%s\n' "${current}" | awk -F '\t' -v seen="${seen}" '$3 == "running" && $9 != "-" && index(seen, $1 ":" $9 ";") == 0')"
	if [ -n "${fresh}" ]; then
		printf '%s\n' "${fresh}" | table
		exit 0
	fi
	if [ -n "${current}" ] && ! printf '%s\n' "${current}" | awk -F '\t' '$3 == "running" { found = 1 } END { exit !found }'; then
		echo "every agent is done"
		printf '%s\n' "${current}" | table
		exit 0
	fi
	sleep 10
done
