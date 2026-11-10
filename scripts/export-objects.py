#!/usr/bin/env python3
"""Splits a built layout into one upload per object.

  scripts/export-objects.py ServerMap

A layout build tells each placement's label, turn and cache key on a PLACED
line in its output (tellPlacement in art/src/layouts/prelude.luau), which
scripts/build-model.sh keeps in art/models/<Name>/build.out. This reads
those lines and the built art/models/<Name>/<Name>.glb, and writes
art/models/<Name>/objects/:

  <id>.glb       one object: the parts of the first placement with its key,
                 named without the placement's label. An object over the
                 upload limit is cut into several, by part name.
  manifest.json  "assets": each file's id, key, piece number, first label and
                 that placement's turn in degrees;
                 "placements": each placement of each asset, with its label,
                 turn and one or two anchor parts and where their middles
                 stand (studs, Y up).

An id is a hash of the key and the piece number, so an object keeps its id
from build to build until its source changes, and the uploader
(scripts/upload-objects.py) sends only ids it has no asset for. Copies of a
model share a key, so they share one upload; the placer
(tools/studio/PlaceMap.luau) stands a copy at each placement by its anchors.
A placement with no key ("-") gets its id from its file's contents.

Anchors are the middles of parts' bounds, which only turn with a part in
quarter turns, so copies of one object must stand at quarter turns from each
other.
"""
import hashlib
import json
import os
import shutil
import struct
import sys

# Open Cloud takes at most 20 MB per upload; stay well under, as the sizes
# here leave out the JSON.
LIMIT = 17_000_000
# Anchors closer together than this across the ground can't give a heading;
# the placer then turns the copy by the placement's turn instead.
MIN_SPREAD = 0.5


def read_glb(path):
	data = open(path, "rb").read()
	length = struct.unpack_from("<I", data, 12)[0]
	document = json.loads(data[20:20 + length])
	return document, memoryview(data)[20 + length + 8:]


def placements_in(log):
	placed = []
	for line in open(log, errors="replace"):
		fields = line.rstrip("\n").split("\t", 3)
		if len(fields) == 4 and fields[0] == "PLACED":
			placed.append({"label": fields[1], "turn": float(fields[2]), "key": fields[3]})
	return placed


class Layout:
	def __init__(self, document, binary):
		self.document, self.binary = document, binary

	def views_of(self, node):
		"""The buffer views a part needs: its mesh's and its textures'."""
		mesh = self.document["meshes"][node["mesh"]]["primitives"][0]
		accessors = list(mesh["attributes"].values()) + [mesh["indices"]]
		views = [self.document["accessors"][a]["bufferView"] for a in accessors]
		material = self.document["materials"][mesh["material"]]
		for texture in self.textures_of(material):
			views.append(self.document["images"][self.document["textures"][texture]["source"]]["bufferView"])
		return views

	@staticmethod
	def textures_of(material):
		slots = [material.get("pbrMetallicRoughness", {}).get("baseColorTexture"), material.get("emissiveTexture"), material.get("normalTexture")]
		return [slot["index"] for slot in slots if slot]

	def size_of(self, node):
		return sum(self.document["bufferViews"][view]["byteLength"] for view in set(self.views_of(node)))

	def middle_of(self, node):
		mesh = self.document["meshes"][node["mesh"]]["primitives"][0]
		position = self.document["accessors"][mesh["attributes"]["POSITION"]]
		return [(low + high) / 2 for low, high in zip(position["min"], position["max"])]

	def write(self, nodes, names):
		"""A GLB holding `nodes`, renamed to `names`, with only what they use."""
		source = self.document
		out = {key: [] for key in ("nodes", "meshes", "materials", "textures", "images", "accessors", "bufferViews")}
		binary = bytearray()
		moved = {key: {} for key in out}

		def view(index):
			if index not in moved["bufferViews"]:
				entry = dict(source["bufferViews"][index])
				start = entry["byteOffset"]
				entry["byteOffset"] = len(binary)
				binary.extend(self.binary[start:start + entry["byteLength"]])
				binary.extend(b"\0" * (-len(binary) % 4))
				moved["bufferViews"][index] = len(out["bufferViews"])
				out["bufferViews"].append(entry)
			return moved["bufferViews"][index]

		def accessor(index):
			if index not in moved["accessors"]:
				entry = dict(source["accessors"][index])
				entry["bufferView"] = view(entry["bufferView"])
				moved["accessors"][index] = len(out["accessors"])
				out["accessors"].append(entry)
			return moved["accessors"][index]

		def texture(index):
			if index not in moved["textures"]:
				image = dict(source["images"][source["textures"][index]["source"]])
				image["bufferView"] = view(image["bufferView"])
				out["images"].append(image)
				entry = dict(source["textures"][index])
				entry["source"] = len(out["images"]) - 1
				moved["textures"][index] = len(out["textures"])
				out["textures"].append(entry)
			return moved["textures"][index]

		for node, name in zip(nodes, names):
			primitive = json.loads(json.dumps(source["meshes"][node["mesh"]]["primitives"][0]))
			material = json.loads(json.dumps(source["materials"][primitive["material"]]))
			material["name"] = name
			for slot in (material.get("pbrMetallicRoughness", {}).get("baseColorTexture"), material.get("emissiveTexture"), material.get("normalTexture")):
				if slot:
					slot["index"] = texture(slot["index"])
			out["materials"].append(material)
			primitive["attributes"] = {key: accessor(index) for key, index in primitive["attributes"].items()}
			primitive["indices"] = accessor(primitive["indices"])
			primitive["material"] = len(out["materials"]) - 1
			out["meshes"].append({"name": name, "primitives": [primitive]})
			out["nodes"].append({"name": name, "mesh": len(out["meshes"]) - 1})

		document = {"asset": source["asset"], "scene": 0, "scenes": [{"nodes": list(range(len(out["nodes"])))}]}
		document.update(out)
		document["buffers"] = [{"byteLength": len(binary)}]
		if "extensionsUsed" in source:
			document["extensionsUsed"] = source["extensionsUsed"]
		text = json.dumps(document, separators=(",", ":")).encode()
		text += b" " * (-len(text) % 4)
		total = 12 + 8 + len(text) + 8 + len(binary)
		return b"".join([struct.pack("<4sII", b"glTF", 2, total), struct.pack("<I4s", len(text), b"JSON"), text, struct.pack("<I4s", len(binary), b"BIN\0"), bytes(binary)])


def pieces_of(layout, parts):
	"""Cuts an object's parts (name, node), in name order, into upload-sized pieces."""
	pieces, piece, used = [], [], 0
	for name, node in sorted(parts, key=lambda part: part[0]):
		size = layout.size_of(node)
		if piece and used + size > LIMIT:
			pieces.append(piece)
			piece, used = [], 0
		piece.append((name, node))
		used += size
	if piece:
		pieces.append(piece)
	return pieces


def anchors_of(layout, piece):
	"""The two parts farthest apart across the ground, or one if none are apart."""
	middles = [(name, layout.middle_of(node)) for name, node in piece]
	best, spread = (middles[0],), 0.0
	for i, (_, a) in enumerate(middles):
		for b_name, b in middles[i + 1:]:
			distance = ((a[0] - b[0]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5
			if distance > spread:
				best, spread = (middles[i], (b_name, b)), distance
	return [name for name, _ in best] if spread >= MIN_SPREAD else [middles[0][0]]


def main():
	name = sys.argv[1]
	root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "models", name)
	log = os.path.join(root, "build.out")
	document, binary = read_glb(os.path.join(root, f"{name}.glb"))
	layout = Layout(document, binary)
	out = os.path.join(root, "objects")
	shutil.rmtree(out, ignore_errors=True)
	os.makedirs(out)

	placed = placements_in(log)
	# Each part belongs to the placement with the longest label its name starts with.
	labels = sorted({p["label"] for p in placed}, key=len, reverse=True)
	parts = {label: [] for label in labels}
	for node in document["nodes"]:
		if "mesh" not in node:
			continue
		label = next((label for label in labels if node["name"].startswith(label + "_")), None)
		if label is None:
			sys.exit(f"export {name}: part {node['name']} belongs to no placement in {log}")
		parts[label].append((node["name"][len(label) + 1:], node))

	assets, placements, first = [], [], {}
	for placement in placed:
		label, key = placement["label"], placement["key"]
		if not parts[label]:
			# This shard built none of its parts (a split model's other shares).
			continue
		own = {suffix: node for suffix, node in parts[label]}
		if key == "-" or key not in first:
			pieces = pieces_of(layout, parts[label])
			entries = []
			for number, piece in enumerate(pieces, 1):
				glb = layout.write([node for _, node in piece], [suffix for suffix, _ in piece])
				seed = glb if key == "-" else f"{key}#{number}".encode()
				identity = hashlib.sha1(seed).hexdigest()[:16]
				with open(os.path.join(out, f"{identity}.glb"), "wb") as file:
					file.write(glb)
				assets.append({"id": identity, "key": key, "piece": number, "label": label, "turn": placement["turn"], "bytes": len(glb), "parts": len(piece)})
				entries.append((identity, [suffix for suffix, _ in piece], anchors_of(layout, piece)))
			if key != "-":
				first[key] = entries
		else:
			entries = first[key]
		for identity, suffixes, anchors in entries:
			missing = [suffix for suffix in suffixes if suffix not in own]
			if missing:
				sys.exit(f"export {name}: {label} lacks part {missing[0]} of its object {key}")
			placements.append({
				"asset": identity,
				"label": label,
				"turn": placement["turn"],
				"anchors": [{"name": suffix, "position": layout.middle_of(own[suffix])} for suffix in anchors],
			})

	with open(os.path.join(out, "manifest.json"), "w") as file:
		json.dump({"assets": assets, "placements": placements}, file, indent="\t")
	total = sum(asset["bytes"] for asset in assets)
	print(f"export {name}: {len(assets)} objects ({total / 1e6:.1f} MB) for {len(placements)} placements", file=sys.stderr)


if __name__ == "__main__":
	main()
