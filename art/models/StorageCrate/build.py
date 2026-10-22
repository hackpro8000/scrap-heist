import math

import bmesh
import bpy
import scrapkit
from mathutils import Vector

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
COLUMNS = 4
ROWS = 3

# Bright cartoon green, in sRGB.
BODY = (0.44, 0.68, 0.35)

# Bolt heads: radius and a warm gunmetal, in sRGB.
BOLT_SIZE = 0.102
BOLT = (0.62, 0.58, 0.52)

# Trim capping the opening: tube radius, path samples per side, cartoon orange in sRGB.
TRIM_SIZE = 0.16
TRIM_SAMPLES = 12
TRIM = (0.95, 0.55, 0.18)


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
	# A small bevel rounds the corners and lip; only those edges get extra
	# loops. Smooth shading hides the few facets on the bulging walls.
	bevel = obj.modifiers.new("Soften", "BEVEL")
	bevel.width = 0.08
	bevel.segments = 2
	bevel.limit_method = "ANGLE"
	for modifier in list(obj.modifiers):
		bpy.ops.object.modifier_apply(modifier=modifier.name)
	return obj


def wall_frame(side: int, s: float, v: float):
	# Position and outward normal of the outer wall surface at (s, v).
	step = 0.01
	point = Vector(ring_point(side, s, v))
	along = Vector(ring_point(side, min(s + step, 1), v)) - Vector(ring_point(side, max(s - step, 0), v))
	up = Vector(ring_point(side, s, min(v + step, 0.99))) - Vector(ring_point(side, s, max(v - step, 0)))
	return point, along.cross(up).normalized()


def bolt_spots():
	# One bolt tucked into each corner of every wall panel.
	inset_s = 0.1
	inset_v = 0.12
	return [(side, s, v) for side in range(4) for s in (inset_s, 1 - inset_s) for v in (inset_v, 1 - inset_v)]


def bolts(tub: bpy.types.Object) -> bpy.types.Object:
	# Short 8-sided bolt heads; auto smooth rounds the sides, keeps the caps flat.
	mesh = bpy.data.meshes.new("Bolts")
	bm = bmesh.new()
	for side, s, v in bolt_spots():
		# Snap to the finished tub so each bolt hugs the bulge and lean there.
		guess, outward = wall_frame(side, s, v)
		if v > 0.5:
			# Ride up with the wobbly top edge, and further where a corner is
			# hitched up, so top bolts stay tucked into the corner under the lip.
			guess.z += (ring_point(side, s, 1)[2] - HEIGHT) * 1.6
		_, point, normal, _ = tub.closest_point_on_mesh(guess + outward * 0.3)
		head = bmesh.ops.create_cone(bm, segments=8, radius1=BOLT_SIZE, radius2=BOLT_SIZE * 0.8, depth=BOLT_SIZE, cap_ends=True)["verts"]
		bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=normal.to_track_quat("Z", "Y").to_matrix(), verts=head)
		bmesh.ops.translate(bm, vec=point + normal * BOLT_SIZE * 0.3, verts=head)
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new("Bolts", mesh)
	bpy.context.scene.collection.objects.link(obj)
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.object.shade_auto_smooth(angle=math.radians(40))
	obj.select_set(False)
	return obj


def trim() -> bpy.types.Object:
	# A round tube riding the wobbly top edge, centered over the wall's thickness.
	curve = bpy.data.curves.new("Trim", "CURVE")
	curve.dimensions = "3D"
	curve.bevel_depth = TRIM_SIZE
	curve.bevel_resolution = 1
	spline = curve.splines.new("POLY")
	spline.use_cyclic_u = True
	path = []
	for side in range(4):
		for i in range(TRIM_SAMPLES):
			s = i / TRIM_SAMPLES
			_, outward = wall_frame(side, max(s, 0.02), 1)
			path.append(Vector(ring_point(side, s, 1)) - outward * WALL / 2)
	spline.points.add(len(path) - 1)
	for point, position in zip(spline.points, path):
		point.co = (*position, 1)
	obj = bpy.data.objects.new("Trim", curve)
	bpy.context.scene.collection.objects.link(obj)
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.object.convert(target="MESH")
	obj = bpy.context.view_layer.objects.active
	for polygon in obj.data.polygons:
		polygon.use_smooth = True
	obj.select_set(False)
	return obj


collection = scrapkit.new_scene()
green = scrapkit.material("Body", linear(BODY), roughness=0.55)
steel = scrapkit.material("Bolt", linear(BOLT), metallic=0.6, roughness=0.45)
orange = scrapkit.material("Trim", linear(TRIM), roughness=0.5)

tub = scrapkit.link(body(), collection, green)
scrapkit.link(bolts(tub), collection, steel)
scrapkit.link(trim(), collection, orange)

scrapkit.finish(collection)
