"""Joins several built objects (.glb) into one, so they upload as one Roblox
Model. Each object's nodes go under a new top node named by the object's id,
which comes into Studio as a child of the bundle named the same; PlaceMap
takes each object out by that name.

Roblox's importer makes names unique across the whole file, so two objects'
parts both called "Pupils" would come in as "Pupils" and "Pupils6". Each
object's node and mesh names therefore get the object's place in the bundle
as a suffix ("Pupils__3"), which PlaceMap strips off again.

Everything indexed (nodes, meshes, materials, textures, images, samplers,
accessors, buffer views, skins) is appended with its indices moved past what
came before, and the binary chunks are laid end to end in one buffer.
"""
import json
import struct

GLB, JSON_CHUNK, BIN_CHUNK = 0x46546C67, 0x4E4F534A, 0x004E4942

# Lists that are joined, and in each kind of entry the fields that point
# into another list.
LISTS = ("nodes", "meshes", "materials", "textures", "images", "samplers", "accessors", "bufferViews", "skins")


def read(data):
	length = struct.unpack_from("<I", data, 12)[0]
	doc = json.loads(data[20:20 + length])
	at = 20 + length
	binary = b""
	if at < len(data):
		size, kind = struct.unpack_from("<II", data, at)
		if kind == BIN_CHUNK:
			binary = data[at + 8:at + 8 + size]
	return doc, binary


def padded(data, fill):
	return data + fill * (-len(data) % 4)


def shift_texture_refs(value, textures):
	# Material texture references are {"index": n, ...} anywhere inside a material.
	if isinstance(value, dict):
		return {k: (v + textures if k == "index" else shift_texture_refs(v, textures)) for k, v in value.items()}
	if isinstance(value, list):
		return [shift_texture_refs(v, textures) for v in value]
	return value


def join(objects):
	"""objects: [(identity, glb bytes)]. Returns the joined glb's bytes."""
	out = {name: [] for name in LISTS}
	tops, used = [], set()
	binary = bytearray()
	for number, (identity, data) in enumerate(objects):
		doc, chunk = read(data)
		suffix = f"__{number}"
		at = {name: len(out[name]) for name in LISTS}
		base = len(binary)
		binary += padded(chunk, b"\0")
		for view in doc.get("bufferViews", []):
			view = dict(view, buffer=0, byteOffset=view.get("byteOffset", 0) + base)
			out["bufferViews"].append(view)
		for accessor in doc.get("accessors", []):
			accessor = dict(accessor)
			if "bufferView" in accessor:
				accessor["bufferView"] += at["bufferViews"]
			out["accessors"].append(accessor)
		for image in doc.get("images", []):
			image = dict(image)
			if "bufferView" in image:
				image["bufferView"] += at["bufferViews"]
			out["images"].append(image)
		out["samplers"].extend(doc.get("samplers", []))
		for texture in doc.get("textures", []):
			texture = dict(texture)
			for field, list_name in (("source", "images"), ("sampler", "samplers")):
				if field in texture:
					texture[field] += at[list_name]
			out["textures"].append(texture)
		for material in doc.get("materials", []):
			out["materials"].append(shift_texture_refs(material, at["textures"]))
		for mesh in doc.get("meshes", []):
			mesh = dict(mesh)
			primitives = []
			for primitive in mesh["primitives"]:
				primitive = dict(primitive)
				primitive["attributes"] = {k: v + at["accessors"] for k, v in primitive["attributes"].items()}
				for field, list_name in (("indices", "accessors"), ("material", "materials")):
					if field in primitive:
						primitive[field] += at[list_name]
				if "targets" in primitive:
					primitive["targets"] = [{k: v + at["accessors"] for k, v in t.items()} for t in primitive["targets"]]
				primitives.append(primitive)
			mesh["primitives"] = primitives
			if "name" in mesh:
				mesh["name"] += suffix
			out["meshes"].append(mesh)
		for skin in doc.get("skins", []):
			skin = dict(skin)
			skin["joints"] = [j + at["nodes"] for j in skin["joints"]]
			for field, list_name in (("skeleton", "nodes"), ("inverseBindMatrices", "accessors")):
				if field in skin:
					skin[field] += at[list_name]
			out["skins"].append(skin)
		for node in doc.get("nodes", []):
			node = dict(node)
			for field, list_name in (("mesh", "meshes"), ("skin", "skins")):
				if field in node:
					node[field] += at[list_name]
			if "children" in node:
				node["children"] = [c + at["nodes"] for c in node["children"]]
			if "name" in node:
				node["name"] += suffix
			out["nodes"].append(node)
		roots = doc["scenes"][doc.get("scene", 0)]["nodes"]
		out["nodes"].append({"name": identity, "children": [r + at["nodes"] for r in roots]})
		tops.append(len(out["nodes"]) - 1)
		used.update(doc.get("extensionsUsed", []))

	doc = {"asset": {"version": "2.0", "generator": "scrap-heist bundle"}, "scene": 0, "scenes": [{"nodes": tops}]}
	doc.update({name: items for name, items in out.items() if items})
	doc["buffers"] = [{"byteLength": len(binary)}]
	if used:
		doc["extensionsUsed"] = sorted(used)
	text = padded(json.dumps(doc, separators=(",", ":")).encode(), b" ")
	total = 12 + 8 + len(text) + 8 + len(binary)
	return b"".join([
		struct.pack("<III", GLB, 2, total),
		struct.pack("<II", len(text), JSON_CHUNK), text,
		struct.pack("<II", len(binary), BIN_CHUNK), bytes(binary),
	])
