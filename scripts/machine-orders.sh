#!/usr/bin/env bash
# Prints the build messages for a task on the reserved cloud build machines,
# one "<session id> <message>" line per shard, split into groups so several
# senders can deliver them at once. Machine m<i> builds shard i, from the
# registry ~/.cache/scrap-heist/machines.tsv (machine, session id).
#
#   scripts/machine-orders.sh <task> <count> <commit> [groups, default 1]
#
# With groups > 1 each group starts with a "# group <n>" line.
set -euo pipefail

task="${1:?task name required}"
count="${2:?shard count required}"
commit="${3:?commit required}"
groups="${4:-1}"
registry="${HOME}/.cache/scrap-heist/machines.tsv"
[ -f "${registry}" ] || { echo "no machine registry at ${registry}" >&2; exit 1; }

awk -F '\t' -v task="${task}" -v count="${count}" -v commit="${commit}" -v groups="${groups}" '
	{ session[substr($1, 2) + 0] = $2 }
	END {
		per = int((count + groups - 1) / groups)
		for (i = 1; i <= count; i++) {
			if (!(i in session)) { print "no machine m" i " in the registry" > "/dev/stderr"; exit 1 }
			if (groups > 1 && (i - 1) % per == 0) print "# group " int((i - 1) / per) + 1
			print session[i] " build " task " " i " " count " " commit
		}
	}' "${registry}"
