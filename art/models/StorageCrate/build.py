import math
import random

import bmesh
import bpy
import scrapkit
from mathutils import Vector

# Storage crate: the yard's open-top bin, cartoony. The body flares wider at
# the top, leans and twists as it rises, its walls bulge out like an
# overstuffed bag and the top edge wobbles. Hazard stripes run round the foot
# and scrap plates are bolted over the walls.
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

# Hazard band painted around the foot: wall heights it spans (0-1), stripes
# all the way round, their slant, and the sRGB yellow/black.
HAZARD_LOW = 0.03
HAZARD_HIGH = 0.2
HAZARD_STRIPES = 48
HAZARD_SLANT = 1.9
HAZARD_YELLOW = (0.98, 0.8, 0.12)
HAZARD_BLACK = (0.08, 0.08, 0.08)

# Patch plates bolted over the walls: how many, thickness and a dull grey.
PLATE_SEED = 7
PLATE_THICKNESS = 0.05
PLATE = (0.55, 0.57, 0.6)

# Gap kept between the wall and anything stuck onto it, so faces don't fight.
STANDOFF = 0.015


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


def snap(tub: bpy.types.Object, side: int, s: float, v: float, lift: float = 0.0):
	# Point on the finished tub's outer wall near (s, v), lifted along its normal.
	guess, outward = wall_frame(side, s, v)
	_, point, normal, _ = tub.closest_point_on_mesh(guess + outward * 0.3)
	return point + normal * lift, normal


def bolts(tub: bpy.types.Object, extra) -> bpy.types.Object:
	# Short 8-sided bolt heads; auto smooth rounds the sides, keeps the caps flat.
	# extra is (point, normal) pairs for bolts placed by other parts, like plates.
	mesh = bpy.data.meshes.new("Bolts")
	bm = bmesh.new()
	spots = []
	for side, s, v in bolt_spots():
		# Snap to the finished tub so each bolt hugs the bulge and lean there.
		guess, outward = wall_frame(side, s, v)
		if v > 0.5:
			# Ride up with the wobbly top edge, and further where a corner is
			# hitched up, so top bolts stay tucked into the corner under the lip.
			guess.z += (ring_point(side, s, 1)[2] - HEIGHT) * 1.6
		_, point, normal, _ = tub.closest_point_on_mesh(guess + outward * 0.3)
		spots.append((point, normal))
	for point, normal in spots + list(extra):
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


def hazard_band(tub: bpy.types.Object) -> bpy.types.Object:
	# A thin skin hugging the foot of the walls, UV'd round the tub so the
	# stripe texture slants evenly across every side and corner.
	columns = 16
	rows = 2
	mesh = bpy.data.meshes.new("Hazard")
	bm = bmesh.new()
	uv_layer = bm.loops.layers.uv.new("UVMap")
	for side in range(4):
		grid = []
		for row in range(rows + 1):
			band = row / rows
			v = HAZARD_LOW + (HAZARD_HIGH - HAZARD_LOW) * band
			grid.append([(bm.verts.new(snap(tub, side, col / columns, v, STANDOFF)[0]), ((side + col / columns) / 4, band)) for col in range(columns + 1)])
		for low, high in zip(grid, grid[1:]):
			for col in range(columns):
				corners = (low[col], low[col + 1], high[col + 1], high[col])
				face = bm.faces.new([vert for vert, _ in corners])
				for loop, (_, uv) in zip(face.loops, corners):
					loop[uv_layer].uv = uv
	bm.to_mesh(mesh)
	bm.free()
	for polygon in mesh.polygons:
		polygon.use_smooth = True
	obj = bpy.data.objects.new("Hazard", mesh)
	bpy.context.scene.collection.objects.link(obj)
	return obj


def hazard_material() -> bpy.types.Material:
	# Slanted yellow/black stripes with a black edge line top and bottom.
	width, height = 1024, 32
	yellow, black = linear(HAZARD_YELLOW), linear(HAZARD_BLACK)
	pixels = []
	for y in range(height):
		band = (y + 0.5) / height
		for x in range(width):
			stripe = math.floor((x + 0.5) / width * HAZARD_STRIPES + band * HAZARD_SLANT) % 2
			edge = band < 0.08 or band > 0.92
			pixels.extend((*(black if edge or stripe else yellow), 1.0))
	image = bpy.data.images.new("StorageCrate_Hazard", width, height)
	image.pixels = pixels
	image.filepath_raw = str(scrapkit.model_dir() / "StorageCrate_Hazard.png")
	image.file_format = "PNG"
	image.save()
	image.pack()
	mat = scrapkit.material("Hazard", yellow, roughness=0.6)
	nodes = mat.node_tree.nodes
	texture = nodes.new("ShaderNodeTexImage")
	texture.image = image
	mat.node_tree.links.new(texture.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
	return mat


def plate_spots():
	# Where patch plates go: (side, s range). Kept clear of the corner bolts,
	# the hazard band and the rim.
	return [(0, (0.22, 0.38)), (0, (0.62, 0.75)), (1, (0.4, 0.6)), (2, (0.25, 0.45)), (2, (0.6, 0.72)), (3, (0.4, 0.6))]


def plates(tub: bpy.types.Object):
	# Odd-sized scrap plates slapped onto the walls: each is a jittered
	# rectangle, trapezoid or skewed quad bent to the wall, with a bolt near
	# each corner. Returns the plates and their bolt spots.
	rng = random.Random(PLATE_SEED)
	steps = 3
	mesh = bpy.data.meshes.new("Plates")
	bm = bmesh.new()
	plate_bolts = []
	for side, (s_low, s_high) in plate_spots():
		s = rng.uniform(s_low, s_high)
		v = rng.uniform(0.42, 0.62)
		center, outward = wall_frame(side, s, v)
		along = (Vector(ring_point(side, min(s + 0.01, 1), v)) - Vector(ring_point(side, s - 0.01, v))).normalized()
		up = outward.cross(along).normalized()
		half_w = rng.uniform(0.35, 0.7)
		half_h = rng.uniform(0.25, 0.45)
		shape = rng.choice(("rect", "trapezoid", "skew"))
		taper = rng.uniform(0.5, 0.8) if shape == "trapezoid" else 1.0
		shear = rng.uniform(-0.3, 0.3) if shape == "skew" else 0.0
		corners = [
			(-half_w, -half_h),
			(half_w, -half_h),
			(half_w * taper + shear, half_h),
			(-half_w * taper + shear, half_h),
		]
		corners = [(x + rng.uniform(-0.06, 0.06), y + rng.uniform(-0.06, 0.06)) for x, y in corners]
		tilt = rng.uniform(-0.15, 0.15)
		corners = [(x * math.cos(tilt) - y * math.sin(tilt), x * math.sin(tilt) + y * math.cos(tilt)) for x, y in corners]

		def at(a: float, b: float):
			# Bilinear spot inside the plate, snapped onto the wall.
			(x0, y0), (x1, y1), (x2, y2), (x3, y3) = corners
			x = (x0 * (1 - a) + x1 * a) * (1 - b) + (x3 * (1 - a) + x2 * a) * b
			y = (y0 * (1 - a) + y1 * a) * (1 - b) + (y3 * (1 - a) + y2 * a) * b
			_, point, normal, _ = tub.closest_point_on_mesh(center + along * x + up * y + outward * 0.3)
			return point, normal

		grid = [[bm.verts.new(at(i / steps, j / steps)[0] + at(i / steps, j / steps)[1] * (STANDOFF + PLATE_THICKNESS)) for i in range(steps + 1)] for j in range(steps + 1)]
		for j in range(steps):
			for i in range(steps):
				bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
		for a, b in ((0.15, 0.18), (0.85, 0.18), (0.85, 0.82), (0.15, 0.82)):
			point, normal = at(a, b)
			plate_bolts.append((point + normal * (STANDOFF + PLATE_THICKNESS), normal))
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new("Plates", mesh)
	bpy.context.scene.collection.objects.link(obj)
	bpy.context.view_layer.objects.active = obj
	# Thickness grows back toward the wall; a small bevel softens the edges.
	solidify = obj.modifiers.new("Thickness", "SOLIDIFY")
	solidify.thickness = PLATE_THICKNESS
	solidify.offset = -1.0
	bevel = obj.modifiers.new("Soften", "BEVEL")
	bevel.width = 0.015
	bevel.segments = 1
	bevel.limit_method = "ANGLE"
	for modifier in list(obj.modifiers):
		bpy.ops.object.modifier_apply(modifier=modifier.name)
	obj.select_set(True)
	bpy.ops.object.shade_auto_smooth(angle=math.radians(40))
	obj.select_set(False)
	return obj, plate_bolts


collection = scrapkit.new_scene()
green = scrapkit.material("Body", linear(BODY), roughness=0.55)
steel = scrapkit.material("Bolt", linear(BOLT), metallic=0.6, roughness=0.45)
orange = scrapkit.material("Trim", linear(TRIM), roughness=0.5)
grey = scrapkit.material("Plate", linear(PLATE), metallic=0.5, roughness=0.5)

tub = scrapkit.link(body(), collection, green)
scrapkit.link(hazard_band(tub), collection, hazard_material())
patches, plate_bolts = plates(tub)
scrapkit.link(patches, collection, grey)
studs = scrapkit.link(bolts(tub, plate_bolts), collection, steel)
rim = scrapkit.link(trim(), collection, orange)

# Hand-painted edge highlights and crease shadows, baked per part.
for part, size in ((tub, 1024), (patches, 512), (rim, 512), (studs, 256)):
	scrapkit.paint_shading(part, size)

scrapkit.finish(collection)
