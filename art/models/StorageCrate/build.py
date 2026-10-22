import math

import bmesh
import bpy
import scrapkit

# Storage crate: the yard's open-top bin, cartoony. The body flares wider at
# the top, leans and twists as it rises, its walls bulge out like an
# overstuffed bag and the top edge wobbles. Rim, feet and decals come later.
# Sits on the ground with its base at the origin.

BOTTOM_WIDTH = 4.2
BOTTOM_DEPTH = 2.9
TOP_WIDTH = 5.8
TOP_DEPTH = 4.0
HEIGHT = 2.9
LEAN = 0.45
TWIST = math.radians(7)
BULGE = 0.28
TOP_WOBBLE = 0.12
WALL = 0.22

# Wall grid: columns per side and rows from floor to top edge.
COLUMNS = 8
ROWS = 6

# Bright cartoon green, in sRGB.
BODY = (0.44, 0.68, 0.35)


def linear(color):
	# Palette is picked in sRGB; Blender's base color wants linear.
	return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in color)


def ring_point(side: int, s: float, v: float):
	# A point on one wall: side 0-3 going round, s 0-1 along it, v 0-1 up it.
	corners = ((-1, -1), (1, -1), (1, 1), (-1, 1))
	(x0, y0), (x1, y1) = corners[side], corners[(side + 1) % 4]
	width = BOTTOM_WIDTH + (TOP_WIDTH - BOTTOM_WIDTH) * v
	depth = BOTTOM_DEPTH + (TOP_DEPTH - BOTTOM_DEPTH) * v
	x = (x0 + (x1 - x0) * s) * width / 2
	y = (y0 + (y1 - y0) * s) * depth / 2
	# Push the middle of each wall outward, most at mid-height.
	push = 1 + BULGE * math.sin(math.pi * s) * math.sin(math.pi * min(v * 1.2, 1)) / (width / 2)
	x, y = x * push, y * push
	angle = TWIST * v
	x, y = x * math.cos(angle) - y * math.sin(angle), x * math.sin(angle) + y * math.cos(angle)
	z = HEIGHT * v
	if v == 1:
		# Wobbly top edge, with one corner hitched up higher than the rest.
		around = (side + s) / 4
		z += TOP_WOBBLE * math.sin(around * 2 * math.pi * 3) + 0.25 * max(0.0, math.cos((around - 0.5) * 2 * math.pi)) ** 4
	return (x + LEAN * v * v, y, z)


def body() -> bpy.types.Object:
	# A wonky tub: bulging walls and a floor, no lid, thickened inward.
	mesh = bpy.data.meshes.new("Body")
	bm = bmesh.new()
	rings = []
	for row in range(ROWS + 1):
		v = row / ROWS
		rings.append([bm.verts.new(ring_point(side, col / COLUMNS, v)) for side in range(4) for col in range(COLUMNS)])
	bm.faces.new(list(reversed(rings[0])))
	count = len(rings[0])
	for low, high in zip(rings, rings[1:]):
		for i in range(count):
			j = (i + 1) % count
			bm.faces.new((low[i], low[j], high[j], high[i]))
	bm.to_mesh(mesh)
	bm.free()
	for polygon in mesh.polygons:
		polygon.use_smooth = True
	obj = bpy.data.objects.new("Body", mesh)
	bpy.context.scene.collection.objects.link(obj)
	bpy.context.view_layer.objects.active = obj
	solidify = obj.modifiers.new("Wall", "SOLIDIFY")
	solidify.thickness = WALL
	solidify.offset = -1.0
	# Subdivision rounds the corners and lip into soft cartoon curves.
	soften = obj.modifiers.new("Soften", "SUBSURF")
	soften.levels = 2
	for modifier in list(obj.modifiers):
		bpy.ops.object.modifier_apply(modifier=modifier.name)
	return obj


collection = scrapkit.new_scene()
green = scrapkit.material("Body", linear(BODY), roughness=0.55)

scrapkit.link(body(), collection, green)

scrapkit.finish(collection)
