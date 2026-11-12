#!/usr/bin/env bash
# Writes a layout's measured paint times from a finished build's results, for
# the next build's deal of a split model's parts between shards (see the shard
# deal in art/src/layouts/prelude.luau).
#
#   scripts/paint-costs.sh <task results folder> [Layout, default ServerMap]
#
# Reads every "shaded <part> <w>×<h> in <s>s" line of the shards' build logs
# and writes art/src/layouts/<Layout>PaintCosts.txt: one line per part name,
# its seconds (the mean, where a name was painted more than once), and a
# "#rate" line, the seconds per texel over all of them, for parts not yet
# measured. Best from a cold build: a cached part is not painted, so it leaves
# no line and keeps the time it had.
set -euo pipefail

[ $# -ge 1 ] && [ -d "$1" ] || { awk 'NR >= 2 && NR <= 12' "$0" | cut -c3- >&2; exit 2; }
root="$(cd "$(dirname "$0")/.." && pwd)"
out="${root}/art/src/layouts/${2:-ServerMap}PaintCosts.txt"

python3 - "$1" "${out}" << 'PY'
import glob, os, re, sys
results, out = sys.argv[1:]
seconds, counts, texels = {}, {}, {}
# Times measured before stay for the parts this build did not paint.
if os.path.isfile(out):
	for line in open(out):
		name, _, value = line.rstrip("\n").partition("\t")
		if name and not name.startswith("#"):
			seconds[name], counts[name] = float(value), 1
painted = set()
for log in glob.glob(os.path.join(results, "S*", "build.log")):
	for name, width, height, took in re.findall(r"shaded (\S+) (\d+)×(\d+) in ([\d.]+)s", open(log, errors="replace").read()):
		if name not in painted:
			seconds[name], counts[name] = 0.0, 0
			painted.add(name)
		seconds[name] += float(took)
		counts[name] += 1
		texels[name] = int(width) * int(height)
if not painted:
	sys.exit("no painted parts in " + results)
rate = sum(seconds[name] / counts[name] for name in painted) / sum(texels[name] for name in painted)
with open(out, "w") as file:
	file.write(f"#rate\t{rate:.9f}\n")
	for name in sorted(seconds):
		file.write(f"{name}\t{seconds[name] / counts[name]:.3f}\n")
print(f"{len(painted)} parts measured, {len(seconds)} in {os.path.relpath(out)}; {rate * 1e6:.2f} s per million texels")
PY
