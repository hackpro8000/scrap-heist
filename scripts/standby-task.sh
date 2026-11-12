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
#   build=no                          skip the build: render the previews only
#   upload-of=<build task id>         upload what that build handed over
#   hand-over=coordinator             leave the objects in <results>/handed/
#                                     for scripts/standby-agent.py to send
#   preview=<Name>,<Name>...          render these models' previews too;
#                                     scripts/standby-agent.py runs
#                                     scripts/standby-previews.sh for them
#                                     once the build's result has gone
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

# A build runs as LANES builds side by side, each of its own share: machine
# <index> of <count> builds shards (index-1)*LANES+1 to index*LANES of
# count*LANES. One build keeps about two of a machine's four cores busy.
# Measured cold on 43 cloud machines, 2026-11-12: one lane 48% of the CPU,
# two 79%, three 93% with at most 7.4 GB of the 16 GB of memory in use. Every
# machine of a task must cut the layout the same way, so the number is fixed
# here, in the task's commit, and never worked out per machine. Lane 1 is this
# checkout; each further lane is a worktree of the same commit inside the .git
# folder, with its own model folder and cache.
LANES=3
# The buffers that keep a machine alive while its lanes use the rest. Memory:
# the lanes together grow by up to about 150 MB a second and are looked at
# every 2 seconds. Disk: a full one leaves the machine's shell dead.
MEMORY_BUFFER_MB=1024
DISK_BUFFER_MB=2048
lanes_dir="$(git rev-parse --absolute-git-dir)/scrap-lanes"
declare -A lane_pid=()
running=() held=() failed=()

lane_root() {
	if [ "$1" -eq 1 ]; then pwd; else echo "${lanes_dir}/$1"; fi
}

# Brings a further lane's worktree to this commit, with the engine and the
# assembled layout this checkout already has.
prepare_lane() {
	local at commit
	at="$(lane_root "$1")"
	commit="$(git rev-parse HEAD)"
	if [ -e "${at}/.git" ]; then
		git -C "${at}" checkout -q -f --detach "${commit}" || return 1
	else
		git worktree prune
		mkdir -p "${lanes_dir}"
		git worktree add -q -f --detach "${at}" "${commit}" || return 1
	fi
	cp -p tools/modelkit/bin/modelkit-linux-x64 tools/modelkit/bin/modelkit-linux-x64.source-sha "${at}/tools/modelkit/bin/" &&
		cp "${model}/model.luau" "${at}/${model}/model.luau"
}

prepare_lanes() {
	local lane
	for lane in $(seq 2 "${LANES}"); do
		prepare_lane "${lane}" || return 1
	done
}

# Starts a lane's build in its own process group, so all of it can be stopped.
start_lane() {
	local lane="$1"
	setsid bash -c '"$1/scripts/build-model.sh" "$2" -- --shard "$3" && "$1/scripts/export-objects.py" "$2"' lane \
		"$(lane_root "${lane}")" "${layout}" "$(((index - 1) * LANES + lane))/$((count * LANES))" >> "${out}/lane-${lane}.log" 2>&1 &
	lane_pid[${lane}]=$!
	running+=("${lane}")
}

stop_lane() {
	kill -- "-${lane_pid[$1]}" 2> /dev/null
	wait "${lane_pid[$1]}" 2> /dev/null
}

# Waits for the running lanes, keeping the buffers free. Short of memory, the
# last lane started is stopped and held for later (what it painted stays in
# its cache); a lane short of memory on its own has failed. Short of disk,
# every lane stops and the caches go.
watch_lanes() {
	local lane still last
	while [ ${#running[@]} -gt 0 ]; do
		sleep 2
		still=()
		for lane in "${running[@]}"; do
			if kill -0 "${lane_pid[${lane}]}" 2> /dev/null; then
				still+=("${lane}")
			elif ! wait "${lane_pid[${lane}]}"; then
				failed+=("${lane}")
			fi
		done
		running=("${still[@]}")
		[ ${#running[@]} -gt 0 ] || break
		if [ "$(df --output=avail -BM . | tail -n 1 | tr -dc 0-9)" -lt "${DISK_BUFFER_MB}" ]; then
			echo "under ${DISK_BUFFER_MB} MB of disk left: stopping the build and emptying the model caches" >> "${out}/build.log"
			for lane in "${running[@]}"; do stop_lane "${lane}"; done
			rm -rf art/models/*/.cache "${lanes_dir}"/*/art/models/*/.cache
			failed+=("${running[@]}")
			running=() held=()
			break
		fi
		if [ "$(awk '/^MemAvailable:/ { print int($2 / 1024) }' /proc/meminfo)" -lt "${MEMORY_BUFFER_MB}" ]; then
			last="${running[-1]}"
			stop_lane "${last}"
			unset 'running[-1]'
			if [ ${#running[@]} -gt 0 ]; then
				echo "under ${MEMORY_BUFFER_MB} MB of memory left: lane ${last} stopped, to build once the others are done" >> "${out}/build.log"
				held+=("${last}")
			else
				echo "under ${MEMORY_BUFFER_MB} MB of memory left with lane ${last} alone: it cannot build on this machine" >> "${out}/build.log"
				failed+=("${last}")
			fi
		fi
	done
}

build() {
	local id started=${SECONDS} status="DONE" build_seconds="-" upload="skipped" handed
	id="$(basename "${out}")"
	# With the engine from before a change shipped beside the new one
	# (tools/modelkit/proof-base, put there for the proof and never committed),
	# this machine proves one sample model unchanged instead of building the
	# layout (scripts/bake-proof.sh).
	if [ -f tools/modelkit/proof-base/Cargo.toml ]; then
		local samples=(ProofChunks BrushRock BrushCanvas PlotMarker ScrapCrate YardFence BeltCrossing RoughRocks)
		local sample="${samples[$(((index - 1) % ${#samples[@]}))]}"
		local proved="DONE"
		scripts/bake-proof.sh tools/modelkit/proof-base "${sample}" > "${out}/proof.txt" 2>> "${out}/build.log" || proved="FAILED"
		{
			echo "status=${proved}"
			echo "build=-"
			echo "upload=skipped"
			echo "total=$((SECONDS - started))"
			echo "parts=0"
			cat "${out}/proof.txt"
		} > "${out}/summary.txt"
		tail -n 30 "${out}/build.log" > "${out}/error.txt"
		echo "${proved} in $((SECONDS - started))s: $(cat "${out}/proof.txt")"
		return
	fi
	# TEMP-COLD: a marker in the task's commit empties this machine's cache first,
	# to time a cold build on machines that are already warm.
	[ ! -f tools/modelkit/cold-build ] || rm -rf "${model}/.cache" "${lanes_dir}"/*/"${model}/.cache"
	# A build that was killed (out of memory, a paused machine) never pruned
	# what it cached, and a machine kept for many tasks fills up. With under
	# 8 GB free, every model's cache goes: a cold build beats a failed one.
	if [ "$(df --output=avail -BG . | tail -n 1 | tr -dc 0-9)" -lt 8 ]; then
		echo "low on disk ($(df --output=avail -h . | tail -n 1 | tr -d ' ') free): emptying the model caches"
		rm -rf art/models/*/.cache "${lanes_dir}"/*/art/models/*/.cache
	fi
	# What the last build left here, in the build log: the model caches' size and the disk's free space.
	echo "DISK before: cache $(du -scm art/models/*/.cache "${lanes_dir}"/*/art/models/*/.cache 2> /dev/null | tail -n 1 | cut -f1) MB, free $(df --output=avail -BM . | tail -n 1 | tr -dc 0-9) MB of $(df --output=size -BM . | tail -n 1 | tr -dc 0-9) MB" >> "${out}/build.log"
	echo "CPUS: nproc $(nproc), online $(getconf _NPROCESSORS_ONLN), cgroup cpu.max $(cat /sys/fs/cgroup/cpu.max 2> /dev/null || echo none)" >> "${out}/build.log"
	# A reading in the log every 10s while the build runs: memory in use, the
	# largest process, and how much of the machine's CPU was busy since the
	# last reading (100% is every core).
	(
		busy_before=0 total_before=0
		while sleep 10; do
			read -r _ user nice system idle wait irq soft steal _ < /proc/stat
			busy=$((user + nice + system + irq + soft + steal)) total=$((user + nice + system + irq + soft + steal + idle + wait))
			echo "MEM $(free -m | awk 'NR==2{print $3"/"$2" avail "$7}') top $(ps -eo rss,comm --sort=-rss | awk 'NR==2{print int($1/1024)"MB "$2}') cpu $(((busy - busy_before) * 100 / (total - total_before + 1)))% of $(nproc)"
			busy_before=${busy} total_before=${total}
		done >> "${out}/build.log"
	) &
	local probe=$!
	# The first two machines share the engine they compile, for the rest and for later runs.
	[ "${index}" -gt 2 ] || export MODELKIT_SHARE_ENGINE=1
	export MODELKIT_PROFILE=1
	local build_started=${SECONDS} lane
	{
		scripts/assemble-model.sh "${layout}" && scripts/build-model.sh --engine && prepare_lanes
	} >> "${out}/build.log" 2>&1 || status="FAILED"
	if [ "${status}" = "DONE" ]; then
		for lane in $(seq 1 "${LANES}"); do start_lane "${lane}"; done
		watch_lanes
		# A lane stopped to keep memory free builds again, alone, once the rest are done.
		for lane in "${held[@]}"; do
			echo "lane ${lane}: building again, alone" >> "${out}/build.log"
			start_lane "${lane}"
			watch_lanes
		done
		[ ${#failed[@]} -eq 0 ] || status="FAILED"
		for lane in $(seq 1 "${LANES}"); do
			{
				echo "LANE ${lane}: shard $(((index - 1) * LANES + lane))/$((count * LANES))"
				cat "${out}/lane-${lane}.log"
			} >> "${out}/build.log" 2> /dev/null
			rm -f "${out}/lane-${lane}.log"
		done
	fi
	kill "${probe}" 2> /dev/null
	if [ "${status}" = "DONE" ]; then
		build_seconds=$((SECONDS - build_started))
		# The lanes' results become one: every part, every cost, and the objects
		# with one manifest, in the first lane's folder, where a hand-over looks.
		local roots=()
		for lane in $(seq 1 "${LANES}"); do roots+=("$(lane_root "${lane}")/${model}"); done
		python3 - "${layout}" "${out}" "${roots[@]}" << 'EOF' || status="FAILED"
import json, os, shutil, struct, sys
layout, out, roots = sys.argv[1], sys.argv[2], sys.argv[3:]
names, costs, assets, placements, seen = [], [], [], [], set()
for root in roots:
	data = open(os.path.join(root, layout + ".glb"), "rb").read()
	length = struct.unpack_from("<I", data, 12)[0]
	names += [node["name"] for node in json.loads(data[20:20 + length])["nodes"] if "mesh" in node]
	for line in open(os.path.join(root, "build.out")):
		fields = line.rstrip("\n").split("\t")
		if fields[0] == "SHARD_COST":
			costs.append(fields[1] + "\t" + fields[2])
	manifest = json.load(open(os.path.join(root, "objects", "manifest.json")))
	for asset in manifest["assets"]:
		# Two lanes may each hold a copy of one object; the first one's stays.
		if asset["id"] in seen:
			continue
		seen.add(asset["id"])
		assets.append(asset)
		if root != roots[0]:
			shutil.copy(os.path.join(root, "objects", asset["id"] + ".glb"), os.path.join(roots[0], "objects"))
	placements += manifest["placements"]
with open(os.path.join(roots[0], "objects", "manifest.json"), "w") as file:
	json.dump({"assets": assets, "placements": placements}, file, indent="\t")
shutil.copy(os.path.join(roots[0], "objects", "manifest.json"), out)
with open(os.path.join(out, "parts.txt"), "w") as file:
	file.write("\n".join(sorted(names)) + "\n")
with open(os.path.join(out, "costs.txt"), "w") as file:
	file.write("".join(cost + "\n" for cost in costs))
EOF
	fi
	if [ "${status}" = "DONE" ] && [ "$(field upload)" != "no" ]; then
		if handed="$(hand_over "${id}" 2>> "${out}/build.log")"; then
			upload="handed ${handed}"
		else
			status="FAILED"
		fi
	fi
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
if [ "$(field build)" = "no" ]; then
	# Previews only: they render once this result has gone.
	printf 'status=DONE\nbuild=-\nupload=skipped\ntotal=0\nparts=0\n' > "${out}/summary.txt"
	# TEMP-DIAG: what the worker said lately, to see why previews failed here.
	{ find / -path /proc -prune -o -name build.log -path '*IslandPreview*' -newermt '-30 min' -print 2> /dev/null | head -n 5 | while read -r log; do echo "== ${log}"; wc -l "${log}"; rg -v "^PLACED|^SHARD_COST|^STANDS|^MEM" "${log}" | rg -v "shaded" | head -n 40; echo "-- tail"; tail -c 600 "${log}"; done; } >> "${out}/build.log" 2>&1
	echo "DONE: no build, previews only"
elif [ -z "${of}" ]; then
	build
elif [ "${index}" = "${UPLOADER}" ]; then
	upload "${of}"
else
	echo "left to shard ${UPLOADER}"
fi
