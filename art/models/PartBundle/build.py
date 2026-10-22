import math

import bmesh
import bpy
import scrapkit
from mathutils import Vector, noise

# Part bundle: a sealed tarp sack of salvaged parts, cinched shut at the neck
# with a rope and a tufted knot. Six fill levels; each one bloats the sack
# more, from a flat, wrinkly slump to a tight ball with parts pressing lumps
# out through the tarp. The game shows one level's Sack_N collection at a time.
# Sits on the ground with its base at the origin.

# Per level: (width, height, fullness 0-1). Fullness drives how round the
# body gets, how hard the parts push lumps out and how much the slack
# tarp wrinkles.
FILL_LEVELS = (
	(1.7, 0.75, 0.0),
	(1.8, 1.0, 0.2),
	(1.9, 1.25, 0.4),
	(2.0, 1.5, 0.6),
	(2.1, 1.75, 0.8),
	(2.2, 2.0, 1.0),
)

# Mesh resolution: segments around, rings from floor to neck.
SEGMENTS = 40
RINGS = 24

# Cinched neck: radius at the tie, its height above the body, and the
# frilled tuft of gathered tarp above the knot.
NECK = 0.13
NECK_HEIGHT = 0.12
TUFT_RADIUS = 0.3
TUFT_HEIGHT = 0.3
TUFT_POINTS = 7

# Lumps where parts press out, and folds of slack tarp.
LUMP_SCALE = 1.6
LUMP_AMOUNT = 0.16
WRINKLES = 11
WRINKLE_AMOUNT = 0.07

# Rope round the neck: tube radius, strands twisted together.
ROPE_SIZE = 0.05
ROPE_STRANDS = 3

# Grey-green tarp with darker patches, and a hemp rope, in sRGB.
TARP = (0.45, 0.55, 0.42)
PATCH = (0.33, 0.4, 0.34)
ROPE = (0.78, 0.62, 0.38)


def linear(color):
	# Palette is picked in sRGB; Blender's base color wants linear.
	return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in color)


def profile(v: float, fullness: float) -> float:
	# Body radius 0-1 from floor (v=0) to the top of the body (v=1). A slack
	# sack slumps into a squat, flat-sided pile; a full one rounds into a ball.
	# Squareness above 2 flattens the floor and bulges the sides out.
	n = 3.2 - 1.0 * fullness
	t = abs(2 * v - 1)
	r = max(0.0, 1 - t ** n) ** (1 / n)
	# Weight sags low: slack sacks spread at the bottom.
	return r * (1 + (1 - fullness) * 0.25 * (1 - v))


def body_point(angle: float, v: float, width: float, height: float, fullness: float, seed: float) -> Vector:
	radius = width / 2
	r = profile(v, fullness) * radius
	# Pinch in toward the neck near the top.
	gather = max(0.0, (v - 0.7) / 0.3) ** 2
	r = r * (1 - gather) + NECK * gather if r > NECK else NECK
	direction = Vector((math.cos(angle), math.sin(angle), 0))
	point = Vector((direction.x * r, direction.y * r, v * height))
	# Parts pushing out: big soft lumps, stronger as the sack fills.
	sample = Vector((direction.x, direction.y, v * 2 - 1)) * LUMP_SCALE + Vector((seed, 0, 0))
	lump = noise.noise(sample) * LUMP_AMOUNT * (0.3 + fullness) * radius
	# Slack folds running up the sides, and folds always gathered at the neck.
	fold = math.sin(angle * WRINKLES + noise.noise(sample * 2) * 2) * WRINKLE_AMOUNT
	fold *= (1 - fullness) * math.sin(math.pi * v) + gather * 0.6
	return point + direction * (lump + fold) * (1 - gather * 0.5) if v > 0 else point


def sack(name: str, width: float, height: float, fullness: float, seed: float) -> tuple[bpy.types.Object, float]:
	# One closed shell: floor, bulging body, cinched neck, then a frilled tuft.
	bm = bmesh.new()
	rings = []
	for row in range(1, RINGS + 1):
		v = row / RINGS
		rings.append([bm.verts.new(body_point(i / SEGMENTS * math.tau, v, width, height, fullness, seed)) for i in range(SEGMENTS)])
	tie = height + NECK_HEIGHT
	rings.append([bm.verts.new((math.cos(a) * NECK, math.sin(a) * NECK, tie)) for a in (i / SEGMENTS * math.tau for i in range(SEGMENTS))])
	# Tuft: gathered tarp fanning out above the knot, edge cut in points.
	for lift, spread in ((0.35, 0.55), (0.75, 1.0)):
		ring = []
		for i in range(SEGMENTS):
			a = i / SEGMENTS * math.tau
			point = 0.6 + 0.4 * abs(math.cos(a * TUFT_POINTS / 2))
			r = NECK + (TUFT_RADIUS * point - NECK) * spread
			z = tie + TUFT_HEIGHT * lift * (0.8 + 0.4 * point)
			ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
		rings.append(ring)
	floor = bm.verts.new((0, 0, 0))
	top = bm.verts.new((0, 0, tie + TUFT_HEIGHT * 0.55))
	for i in range(SEGMENTS):
		j = (i + 1) % SEGMENTS
		bm.faces.new((floor, rings[0][j], rings[0][i]))
		bm.faces.new((top, rings[-1][i], rings[-1][j]))
	for low, high in zip(rings, rings[1:]):
		for i in range(SEGMENTS):
			j = (i + 1) % SEGMENTS
			bm.faces.new((low[i], low[j], high[j], high[i]))
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	for polygon in mesh.polygons:
		polygon.use_smooth = True
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	return obj, tie


def rope(name: str, height: float) -> bpy.types.Object:
	# Twisted rope looped round the neck: a torus whose tube ripples in strands.
	bm = bmesh.new()
	around, tube = 32, 10
	ring_radius = NECK + ROPE_SIZE * 0.6
	rings = []
	for i in range(around):
		a = i / around * math.tau
		center = Vector((math.cos(a) * ring_radius, math.sin(a) * ring_radius, height))
		out = Vector((math.cos(a), math.sin(a), 0))
		ring = []
		for k in range(tube):
			b = k / tube * math.tau
			r = ROPE_SIZE * (1 + 0.18 * math.cos(b * ROPE_STRANDS + a * 9))
			ring.append(bm.verts.new(center + out * math.cos(b) * r + Vector((0, 0, math.sin(b) * r))))
		rings.append(ring)
	for i in range(around):
		low, high = rings[i], rings[(i + 1) % around]
		for k in range(tube):
			m = (k + 1) % tube
			bm.faces.new((low[k], high[k], high[m], low[m]))
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	for polygon in mesh.polygons:
		polygon.use_smooth = True
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	return obj


def blotches(mat: bpy.types.Material, color, scale: float, amount: float) -> None:
	# Hard-edged noise blobs of color over the base, like patched-up tarp.
	# amount 0-1 is roughly how much of the surface they cover.
	nodes, links = mat.node_tree.nodes, mat.node_tree.links
	bsdf = nodes["Principled BSDF"]
	coords = nodes.new("ShaderNodeTexCoord")
	texture = nodes.new("ShaderNodeTexNoise")
	texture.inputs["Scale"].default_value = scale
	texture.inputs["Detail"].default_value = 1.0
	links.new(coords.outputs["Object"], texture.inputs["Vector"])
	edge = nodes.new("ShaderNodeMapRange")
	edge.inputs["From Min"].default_value = 0.62 - amount * 0.25
	edge.inputs["From Max"].default_value = 0.65 - amount * 0.25
	links.new(texture.outputs["Fac"], edge.inputs["Value"])
	blend = nodes.new("ShaderNodeMix")
	blend.data_type = "RGBA"
	links.new(edge.outputs["Result"], blend.inputs["Factor"])
	blend.inputs["A"].default_value = bsdf.inputs["Base Color"].default_value
	blend.inputs["B"].default_value = (*linear(color), 1.0)
	links.new(blend.outputs["Result"], bsdf.inputs["Base Color"])


collection = scrapkit.new_scene()
tarp = scrapkit.material("Tarp", linear(TARP), roughness=0.8)
blotches(tarp, PATCH, 1.8, 0.3)
hemp = scrapkit.material("Rope", linear(ROPE), roughness=0.9)

for number, (width, height, fullness) in enumerate(FILL_LEVELS, 1):
	name = f"Sack_{number}"
	group = bpy.data.collections.new(name)
	collection.children.link(group)
	body, tie = sack(name, width, height, fullness, number * 3.7)
	scrapkit.link(body, group, tarp.copy())
	knot = scrapkit.link(rope(f"{name}_Rope", tie), group, hemp.copy())
	scrapkit.paint_shading(body, 1024)
	scrapkit.paint_shading(knot, 256)
	# The preview shows the fullest sack only.
	if number < len(FILL_LEVELS):
		for obj in group.objects:
			obj.hide_render = True

scrapkit.finish(collection)
