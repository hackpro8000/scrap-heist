#!/usr/bin/env bash
# Prints each cloud build machine's open question as it arrives, one line per
# question, for the owner's session to watch (run it under Monitor, or in a
# terminal). Machines post them with scripts/machine-ask.sh. Questions
# already there when it starts are printed first, unless --new.
#
#   scripts/machine-questions.sh [--new] [poll seconds, default 30]

set -uo pipefail

only_new=no
if [ "${1:-}" = "--new" ]; then
	only_new=yes
	shift
fi
every="${1:-30}"
cd "$(dirname "$0")/.."
seen=""
first=yes
while true; do
	current="$(git ls-remote origin 'refs/heads/machine-questions/*' 2> /dev/null || true)"
	while read -r sha ref; do
		[ -n "${sha}" ] || continue
		case " ${seen} " in *" ${sha} "*) continue ;; esac
		seen="${seen} ${sha}"
		[ "${first}" = yes ] && [ "${only_new}" = yes ] && continue
		if git fetch -q --depth=1 origin "${ref}" 2> /dev/null; then
			text="$(git show FETCH_HEAD:question.txt 2> /dev/null | awk 'NR == 1 || NR > 4' | tr '\n' ' ' | cut -c1-400)"
			echo "QUESTION ${ref#refs/heads/machine-questions/}: ${text}"
		else
			echo "QUESTION ${ref#refs/heads/machine-questions/}: (could not fetch ${ref})"
		fi
	done <<< "${current}"
	first=no
	sleep "${every}"
done
