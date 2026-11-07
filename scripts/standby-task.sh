#!/usr/bin/env bash
# Runs one standby task on this shard machine (scripts/standby.sh calls it
# with the task's commit checked out, so this is always the task's own copy).
#
#   scripts/standby-task.sh <Layout> <index> <count> <results folder>
#
# The task is <results folder>/task.txt, as scripts/send-build.sh posted it:
#
#   ref=<commit>                      build this shard of the layout
#   upload=no                         ... without handing its objects over
#   upload-of=<build task id>         upload what that build handed over
#   hand-over=coordinator             leave the objects in <results>/handed/
#                                     for scripts/standby-agent.py to send
#   preview=<Name>,<Name>...          also render these models' previews
#                                     with modelkit, shared out between the
#                                     shards, into <results>/previews/<Name>/
#                                     (preview.png and four turns, view0-3.png)
#   hand-over=branch                  push them to build-objects/s<index> as
#                                     before, list them in <results>/handed/
#                                     names.tsv and the commit in
#                                     <results>/handed-commit.txt (machine 1
#                                     fetches them from GitHub, so they never
#                                     cross the coordinator's connection)
#
# A build writes build.log, parts.txt, the objects' manifest.json, costs.txt
# and summary.txt, and hands over the objects that have no asset yet: it
# pushes them to the branch build-objects/s<index>, replacing what was there.
#
# An upload is the uploader's job alone, shard 1. Sending everything from one
# machine, once every build is in, lets one throttle see every rate limit;
# sixteen machines each backing off blindly only fight over the limit. It
# gathers what every shard handed over for that build and sends it with
# scripts/upload-objects.py, writing uploaded.tsv and summary.txt. The other
# shards leave no summary, so nothing of theirs is pushed.

set -uo pipefail

layout="${1:?layout required}"
index="${2:?shard index required}"
count="${3:?shard count required}"
out="${4:?results folder required}"
task="${out}/task.txt"
UPLOADER=1
model="art/models/${layout}"
pushed_commit_file="$(mktemp)"
ledger="art/src/layouts/${layout}Uploads.tsv"

field() {
	sed -n "s/^$1=//p" "${task}"
}

# Pushes a folder as the only commit on a branch, replacing its history, so
# handed-over objects don't pile up in the repository.
push_alone() {
	local dir="$1" branch="$2" message="$3" index_file tree commit
	index_file="$(mktemp -u)"
	GIT_INDEX_FILE="${index_file}" git --work-tree="$(cd "${dir}" && pwd)" add -A --sparse
	tree="$(GIT_INDEX_FILE="${index_file}" git write-tree)"
	rm -f "${index_file}"
	commit="$(git commit-tree "${tree}" -m "${message}")"
	git push -q -f origin "${commit}:refs/heads/${branch}" || return 1
	echo "${commit}" > "${pushed_commit_file}"
}

# Hands over the objects of this build that the ledger has no asset for,
# with the build's task id and each object's label. Prints how many.
hand_over() {
	local id="$1" handed
	if [ "$(field hand-over)" = "coordinator" ]; then
		handed="${out}/handed"
		mkdir -p "${handed}"
	else
		handed="$(mktemp -d)"
	fi
	echo "${id}" > "${handed}/task.txt"
	python3 - "${model}/objects" "${ledger}" "${handed}" << 'EOF' || return 1
import json, os, shutil, sys
objects, ledger, handed = sys.argv[1:]
known = {line.split("\t")[0] for line in open(ledger)} if os.path.isfile(ledger) else set()
with open(os.path.join(handed, "names.tsv"), "w") as names:
	for asset in json.load(open(os.path.join(objects, "manifest.json")))["assets"]:
		if asset["id"] not in known:
			shutil.copy(os.path.join(objects, asset["id"] + ".glb"), handed)
			names.write(f"{asset['id']}\t{asset['label']}\n")
EOF
	if [ "$(field hand-over)" = "coordinator" ]; then
		rm -f "${handed}/task.txt"
		wc -l < "${handed}/names.tsv"
		return 0
	fi
	push_alone "${handed}" "build-objects/s${index}" "objects of task ${id} S${index}/${count}" || return 1
	if [ "$(field hand-over)" = "branch" ]; then
		mkdir -p "${out}/handed"
		cp "${handed}/names.tsv" "${out}/handed/names.tsv"
		cp "${pushed_commit_file}" "${out}/handed-commit.txt"
	fi
	wc -l < "${handed}/names.tsv"
	rm -rf "${handed}"
}

# Renders this shard's share of the task's previews (every count-th name,
# from this shard's index), each model in its own folder with its own cache,
# so it runs beside the layout build. A model that fails leaves its log.
render_previews() {
	local names name n=0 dir
	IFS=, read -ra names <<< "$(field preview)"
	for name in "${names[@]}"; do
		n=$((n + 1))
		[ $(((n - 1) % count + 1)) -eq "${index}" ] || continue
		dir="${out}/previews/${name}"
		mkdir -p "${dir}"
		if scripts/assemble-model.sh "${name}" > "${dir}/build.log" 2>&1 &&
			scripts/build-model.sh "${name}" -- --turntable 4 >> "${dir}/build.log" 2>&1; then
			cp "art/models/${name}/preview.png" "${dir}/preview.png"
			for turn in 0 1 2 3; do
				cp "art/models/${name}/turntable/000${turn}.png" "${dir}/view${turn}.png"
			done
		else
			echo "FAILED" >> "${dir}/build.log"
		fi
	done
}

build() {
	local id started=${SECONDS} status="DONE" build_seconds="-" upload="skipped" handed previews
	id="$(basename "${out}")"
	render_previews &
	previews=$!
	{
		scripts/assemble-model.sh "${layout}" &&
			{
				local build_started=${SECONDS}
				scripts/build-model.sh "${layout}" -- --shard "${index}/${count}" &&
					build_seconds=$((SECONDS - build_started))
			} &&
			scripts/export-objects.py "${layout}" &&
			cp "${model}/objects/manifest.json" "${out}/"
	} >> "${out}/build.log" 2>&1 || status="FAILED"
	if [ "${status}" = "DONE" ]; then
		python3 - "${model}/${layout}.glb" > "${out}/parts.txt" << 'EOF' || status="FAILED"
import json, struct, sys
data = open(sys.argv[1], "rb").read()
length = struct.unpack_from("<I", data, 12)[0]
names = [node["name"] for node in json.loads(data[20:20 + length])["nodes"] if "mesh" in node]
print("\n".join(sorted(names)))
EOF
		awk -F'\t' '$1 == "SHARD_COST" { print $2 "\t" $3 }' "${model}/build.out" > "${out}/costs.txt"
	fi
	if [ "${status}" = "DONE" ] && [ "$(field upload)" != "no" ]; then
		if handed="$(hand_over "${id}" 2>> "${out}/build.log")"; then
			upload="handed ${handed}"
		else
			status="FAILED"
		fi
	fi
	wait "${previews}"
	{
		echo "status=${status}"
		echo "build=${build_seconds}"
		echo "upload=${upload}"
		echo "total=$((SECONDS - started))"
		echo "parts=$(wc -l < "${out}/parts.txt" 2> /dev/null || echo 0)"
	} > "${out}/summary.txt"
	[ "${status}" = "DONE" ] || tail -n 30 "${out}/build.log" > "${out}/error.txt"
	echo "${status} in $((SECONDS - started))s (build ${build_seconds}s)"
}

upload() {
	local of="$1" started=${SECONDS} status="DONE" gathered sent=0
	gathered="$(mktemp -d)"
	{
		# Only what each shard handed over for this build: a branch left from an
		# earlier build names another task.
		for shard in $(seq 1 "${count}"); do
			git fetch -q --depth=1 origin "refs/heads/build-objects/s${shard}" || continue
			[ "$(git show FETCH_HEAD:task.txt 2> /dev/null)" = "${of}" ] || continue
			mkdir -p "${gathered}/${shard}"
			git archive FETCH_HEAD | tar -x -C "${gathered}/${shard}"
		done
		scripts/upload-objects.py "${layout}" "${gathered}"
	} >> "${out}/build.log" 2>&1 || status="FAILED"
	# What did upload is kept even when something failed, so nothing is sent twice.
	cp "${gathered}/uploaded.tsv" "${out}/" 2> /dev/null && sent="$(wc -l < "${out}/uploaded.tsv")"
	rm -rf "${gathered}"
	{
		echo "status=${status}"
		echo "uploaded=${sent}"
		echo "total=$((SECONDS - started))"
	} > "${out}/summary.txt"
	[ "${status}" = "DONE" ] || tail -n 30 "${out}/build.log" > "${out}/error.txt"
	echo "${status}: ${sent} objects have assets after $((SECONDS - started))s"
}

of="$(field upload-of)"
if [ -z "${of}" ]; then
	build
elif [ "${index}" = "${UPLOADER}" ]; then
	upload "${of}"
else
	echo "left to shard ${UPLOADER}"
fi
