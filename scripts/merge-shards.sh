#!/usr/bin/env bash
# Merges the shards of a sharded layout build into the game's tables. Each
# shard folder, named S<number>, holds that shard's parts.txt and
# manifest.json (scripts/export-objects.py). The folder they stand in holds
# uploaded.tsv when the build was uploaded (scripts/upload-objects.py): each
# new object's id, asset ID and the shard whose copy was sent.
#
#   scripts/merge-shards.sh ServerMap .standby-results/<task id>/S*
#
# It adds the shards' new uploads to the layout's ledger,
# art/src/layouts/<Name>Uploads.tsv (object id, asset ID, the turn the object
# was uploaded at, and its label), then writes every object the map uses into
# Assets.MapChunks in src/shared/Assets.luau and every placement into
# src/shared/Config/MapChunks.luau, for tools/studio/PlaceMap.luau. Commit all
# three. It prints the asset IDs that are new, which the game needs
# permission to use before Studio can load them.
#
# It refuses to write anything if two shards built the same part, a shard
# folder is missing a file, or an object the map uses has no asset.

set -euo pipefail

name="${1:?layout name required}"
shift
[ $# -gt 0 ] || { echo "usage: scripts/merge-shards.sh <Name> <shard folder>..." >&2; exit 1; }
root="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "${name}" "${root}" "$@" << 'EOF'
import json, os, re, sys

name, root, shards = sys.argv[1], sys.argv[2], sys.argv[3:]
ledger_path = os.path.join(root, "art", "src", "layouts", f"{name}Uploads.tsv")
assets_path = os.path.join(root, "src", "shared", "Assets.luau")
placements_path = os.path.join(root, "src", "shared", "Config", "MapChunks.luau")


def say(message):
	print(f"merge {name}: {message}", file=sys.stderr)


def fail(message):
	say(f"FAILED: {message}")
	say("nothing was written")
	sys.exit(1)


# Each placement belongs to exactly one shard, so no part may appear twice.
seen, twice = set(), []
for shard in shards:
	for file in ("parts.txt", "manifest.json"):
		if not os.path.isfile(os.path.join(shard, file)):
			fail(f"{shard} has no {file}")
	for part in open(os.path.join(shard, "parts.txt")).read().split():
		if part in seen:
			twice.append(part)
		seen.add(part)
if twice:
	fail(f"parts built by more than one shard: {' '.join(twice[:5])}")
say(f"{len(seen)} parts across {len(shards)} shards, none built twice")

# The ledger: object id -> (asset ID, turn it was uploaded at, label).
ledger = {}
if os.path.isfile(ledger_path):
	for line in open(ledger_path):
		fields = line.rstrip("\n").split("\t")
		if len(fields) == 4:
			ledger[fields[0]] = (fields[1], float(fields[2]), fields[3])

# What was uploaded is one shard's copy of an object, which stands as that
# shard's first placement of it does, so it joins the ledger with that
# placement's turn. An object already in the ledger keeps its asset.
placements, described, fresh = [], {}, []
for shard in shards:
	manifest = json.load(open(os.path.join(shard, "manifest.json")))
	number = os.path.basename(os.path.normpath(shard)).lstrip("S")
	described[number] = {asset["id"]: asset for asset in manifest["assets"]}
	placements.extend(manifest["placements"])
uploaded = os.path.join(os.path.dirname(os.path.normpath(shards[0])), "uploaded.tsv")
if os.path.isfile(uploaded):
	for line in open(uploaded):
		fields = line.split()
		if len(fields) != 3 or fields[0] in ledger:
			continue
		asset = described.get(fields[2], {}).get(fields[0])
		if asset is None:
			fail(f"uploaded.tsv names object {fields[0]} from shard {fields[2]}, which has no such object")
		ledger[fields[0]] = (fields[1], asset["turn"], asset["label"])
		fresh.append(fields[1])

missing = sorted({p["asset"] for p in placements} - set(ledger))
if missing:
	labels = sorted({p["label"] for p in placements if p["asset"] in missing})
	fail(f"{len(missing)} objects have no asset (not uploaded?): {' '.join(labels[:8])}")

with open(ledger_path, "w") as file:
	for identity in sorted(ledger):
		asset, turn, label = ledger[identity]
		file.write(f"{identity}\t{asset}\t{turn:g}\t{label}\n")

used = sorted({p["asset"] for p in placements})
block = "Assets.MapChunks = {\n" + "".join(f'\t["{identity}"] = "rbxassetid://{ledger[identity][0]}",\n' for identity in used) + "}"
source = open(assets_path).read()
source, count = re.subn(r"^Assets\.MapChunks = \{\n.*?^\}", lambda _: block, source, flags=re.S | re.M)
if count != 1:
	fail("src/shared/Assets.luau has no Assets.MapChunks table")
open(assets_path, "w").write(source)


def number(value):
	return f"{value:.6g}"


with open(placements_path, "w") as file:
	file.write("--!strict\n")
	file.write(f"-- Merged from {len(shards)} shards of {name} by scripts/merge-shards.sh: one entry per\n")
	file.write("-- placement of an uploaded object (Assets.MapChunks), with how far to turn\n")
	file.write("-- the object from the way it was uploaded (degrees) and one or two anchor\n")
	file.write("-- parts and where their middles stand (studs, Y up).\n")
	file.write("return {\n")
	for placement in sorted(placements, key=lambda p: (p["label"], p["asset"])):
		anchors = ", ".join(
			f'{{ name = "{a["name"]}", position = Vector3.new({", ".join(number(c) for c in a["position"])}) }}' for a in placement["anchors"]
		)
		turn = (placement["turn"] - ledger[placement["asset"]][1]) % 360
		file.write(f'\t{{ asset = "{placement["asset"]}", label = "{placement["label"]}", turn = {number(turn)}, anchors = {{ {anchors} }} }},\n')
	file.write("}\n")

say(f"{len(used)} objects in {len(placements)} placements; {len(fresh)} newly uploaded in {len(set(fresh))} assets, {len(ledger)} in the ledger")
print("\n".join(dict.fromkeys(fresh)))
EOF
