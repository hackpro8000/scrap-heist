import math

import bmesh
import bpy
import scrapkit

# Starter weapon: a wooden baseball bat, built along +Z with the knob at the
# origin so the tool's grip sits at the handle.
SEGMENTS = 24

# Bat profile as (radius, height, tone) from the knob up to the barrel cap.
# Tone is hand-painted shading baked into the color, so it reads the same
# under any light: positive brightens edges and bulges, negative darkens
# creases. It is painted by shape, not by where a light would sit.
PROFILE = [
	(0.0, 0.0, 0.0),
	(0.17, 0.0, 0.15),
	(0.17, 0.08, 0.45),
	(0.1, 0.16, -0.55),
	(0.1, 1.3, -0.15),
	(0.12, 2.0, -0.05),
	(0.2, 2.9, 0.1),
	(0.24, 3.5, 0.3),
	(0.24, 3.9, 0.15),
	(0.2, 4.0, 0.5),
	(0.0, 4.02, 0.1),
]

# Hand-painted palette, in sRGB: tone blends from the base toward these.
BASE = (0.78, 0.55, 0.32)
HIGHLIGHT = (0.97, 0.8, 0.55)
SHADOW = (0.4, 0.23, 0.11)
GRAIN = (0.55, 0.35, 0.18)

TEXTURE_WIDTH = 64
TEXTURE_HEIGHT = 256


def arc_lengths(profile) -> list[float]:
	# Distance along the silhouette, 0 to 1, used as the texture's V.
	lengths = [0.0]
	for (r0, h0, _), (r1, h1, _) in zip(profile, profile[1:]):
		lengths.append(lengths[-1] + math.hypot(r1 - r0, h1 - h0))
	return [length / lengths[-1] for length in lengths]


def lathe(name: str, profile) -> bpy.types.Object:
	mesh = bpy.data.meshes.new(name)
	bm = bmesh.new()
	uv_layer = bm.loops.layers.uv.new("UVMap")
	vs = arc_lengths(profile)
	rings = []
	for radius, height, _ in profile:
		ring = []
		for i in range(SEGMENTS):
			angle = 2 * math.pi * i / SEGMENTS
			ring.append(bm.verts.new((math.cos(angle) * radius, math.sin(angle) * radius, height)))
		rings.append(ring)
	for index, (low, high) in enumerate(zip(rings, rings[1:])):
		for i in range(SEGMENTS):
			j = (i + 1) % SEGMENTS
			face = bm.faces.new((low[i], low[j], high[j], high[i]))
			# The last column wraps to u = 1 so the seam doesn't smear.
			u0, u1 = i / SEGMENTS, (i + 1) / SEGMENTS
			for loop, uv in zip(face.loops, ((u0, vs[index]), (u1, vs[index]), (u1, vs[index + 1]), (u0, vs[index + 1]))):
				loop[uv_layer].uv = uv
	# The first and last rings have zero radius, so merge them into poles.
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(mesh)
	bm.free()
	for polygon in mesh.polygons:
		polygon.use_smooth = True
	return bpy.data.objects.new(name, mesh)


def mix(a, b, t: float):
	return tuple(x + (y - x) * t for x, y in zip(a, b))


def tone_at(v: float, vs: list[float], tones: list[float]) -> float:
	for (v0, t0), (v1, t1) in zip(zip(vs, tones), zip(vs[1:], tones[1:])):
		if v <= v1:
			return t0 + (t1 - t0) * ((v - v0) / (v1 - v0) if v1 > v0 else 0.0)
	return tones[-1]


def grain_at(u: float, v: float) -> float:
	# Long streaks running down the bat, wobbling a little along its length.
	wobble = 0.02 * math.sin(v * 37.0 + u * 11.0)
	streaks = math.sin((u + wobble) * 2 * math.pi * 9) * 0.5 + math.sin((u + wobble) * 2 * math.pi * 23 + 1.7) * 0.5
	return max(0.0, streaks - 0.55) * 1.4


def paint_texture(name: str, profile) -> bpy.types.Image:
	vs = arc_lengths(profile)
	tones = [tone for _, _, tone in profile]
	image = bpy.data.images.new(name, TEXTURE_WIDTH, TEXTURE_HEIGHT)
	pixels = []
	for y in range(TEXTURE_HEIGHT):
		v = (y + 0.5) / TEXTURE_HEIGHT
		tone = tone_at(v, vs, tones)
		shaded = mix(BASE, HIGHLIGHT, tone) if tone >= 0 else mix(BASE, SHADOW, -tone)
		for x in range(TEXTURE_WIDTH):
			color = mix(shaded, GRAIN, grain_at((x + 0.5) / TEXTURE_WIDTH, v) * 0.6)
			pixels.extend((*color, 1.0))
	image.pixels = pixels
	image.filepath_raw = str(scrapkit.model_dir() / f"{name}.png")
	image.file_format = "PNG"
	image.save()
	image.pack()
	return image


def painted_material(name: str, image: bpy.types.Image) -> bpy.types.Material:
	mat = scrapkit.material(name, (0.62, 0.42, 0.22), roughness=0.7)
	nodes = mat.node_tree.nodes
	texture = nodes.new("ShaderNodeTexImage")
	texture.image = image
	mat.node_tree.links.new(texture.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
	return mat


collection = scrapkit.new_scene()
wood = painted_material("Wood", paint_texture("StarterWeapon_Color", PROFILE))

scrapkit.link(lathe("StarterWeapon", PROFILE), collection, wood)

scrapkit.finish(collection)
