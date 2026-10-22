import math
import random

import bmesh
import bpy
import scrapkit
from mathutils import Vector, noise

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
# Scrap inside: a lumpy surface standing in for the heap of parts. Six fill
# levels, each as (height up the walls 0-1, mound in the middle, junk parts
# showing); the game shows one level's Fill_N collection at a time.
FILL_LEVELS = (
	(0.15, 0.1, 1),
	(0.3, 0.15, 2),
	(0.45, 0.2, 4),
	(0.6, 0.28, 6),
	(0.75, 0.35, 8),
	(0.9, 0.45, 11),
)
FILL_RINGS = 6
FILL_PER_SIDE = 8
FILL_LUMPS = 0.12
SCRAP = (0.6, 0.5, 0.42)

# Junk poking out of the fill, in sRGB: tire rubber and its chalky wear,
# brass cog and its rust, spring steel, cone orange (the trim's) and its band.
RUBBER = (0.2, 0.2, 0.23)
CHALK = (0.45, 0.46, 0.5)
BRASS = (0.8, 0.62, 0.26)
RUST = (0.6, 0.3, 0.13)
SPRING_STEEL = (0.7, 0.74, 0.8)
CONE_BAND = (0.95, 0.94, 0.88)
GRIME = (0.35, 0.3, 0.28)

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
	bevel.width = 0.03
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
	# extra is (point, normal, size) for bolts placed by other parts, like plates.
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
		spots.append((point, normal, BOLT_SIZE))
	for point, normal, size in spots + list(extra):
		head = bmesh.ops.create_cone(bm, segments=8, radius1=size, radius2=size * 0.8, depth=size, cap_ends=True)["verts"]
		bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=normal.to_track_quat("Z", "Y").to_matrix(), verts=head)
		bmesh.ops.translate(bm, vec=point + normal * size * 0.3, verts=head)
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
		half_w = rng.uniform(0.22, 0.85)
		half_h = rng.uniform(0.16, 0.5)
		shape = rng.choice(("rect", "trapezoid", "skew", "wedge"))
		taper = rng.uniform(0.3, 0.75) if shape == "trapezoid" else 1.0
		shear = rng.uniform(-0.5, 0.5) if shape == "skew" else 0.0
		# A wedge drops one top corner, so the plate reads as a torn-off offcut.
		drop = rng.uniform(0.4, 0.8) if shape == "wedge" else 0.0
		corners = [
			(-half_w, -half_h),
			(half_w, -half_h),
			(half_w * taper + shear, half_h - half_h * 2 * drop),
			(-half_w * taper + shear, half_h),
		]
		corners = [(x + rng.uniform(-0.12, 0.12), y + rng.uniform(-0.1, 0.1)) for x, y in corners]
		tilt = rng.uniform(-0.3, 0.3)
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
			plate_bolts.append((point + normal * (STANDOFF + PLATE_THICKNESS), normal, BOLT_SIZE * 0.5))
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


def fill_edge(level: float):
	# Inner wall ring at a fill height, and its middle.
	edge = [Vector(ring_point(side, col / FILL_PER_SIDE, level)) for side in range(4) for col in range(FILL_PER_SIDE)]
	return edge, sum(edge, Vector()) / len(edge)


def fill(name: str, level: float, mound: float) -> bpy.types.Object:
	# Loops from the inner wall in to the centre; lumps are noise on height.
	edge, middle = fill_edge(level)
	mesh = bpy.data.meshes.new(name)
	bm = bmesh.new()
	loops = []
	for ring in range(FILL_RINGS):
		t = 1 - ring / FILL_RINGS
		loop = []
		for point in edge:
			# Tuck the outer loop just inside the wall's inner face.
			flat = middle + (point - middle) * t
			flat -= (point - middle).normalized() * WALL * 1.2 * t
			height = middle.z + mound * (1 - t * t) + FILL_LUMPS * noise.noise(flat * 1.3)
			loop.append(bm.verts.new((flat.x, flat.y, height)))
		loops.append(loop)
	top = bm.verts.new((middle.x, middle.y, middle.z + mound + FILL_LUMPS * noise.noise(middle * 1.3)))
	count = len(edge)
	for outer, inner in zip(loops, loops[1:]):
		for i in range(count):
			j = (i + 1) % count
			bm.faces.new((outer[i], outer[j], inner[j], inner[i]))
	for i in range(count):
		bm.faces.new((loops[-1][i], loops[-1][(i + 1) % count], top))
	bm.to_mesh(mesh)
	bm.free()
	for polygon in mesh.polygons:
		polygon.use_smooth = True
	return bpy.data.objects.new(name, mesh)


def smooth(obj: bpy.types.Object, angle: float = 40) -> None:
	# Auto smooth: rounds curved faces, keeps hard edges crisp.
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))
	obj.select_set(False)


def blotches(mat: bpy.types.Material, color, scale: float, amount: float) -> None:
	# Hard-edged noise blobs of color over the base, like painted-on wear.
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
	base = bsdf.inputs["Base Color"]
	if base.is_linked:
		links.new(base.links[0].from_socket, blend.inputs["A"])
	else:
		blend.inputs["A"].default_value = base.default_value
	blend.inputs["B"].default_value = (*linear(color), 1.0)
	links.new(blend.outputs["Result"], base)


def tire() -> bpy.types.Object:
	# Fat squashed donut; every other pair of outer columns bulges out as a tread block.
	segments, sides = 24, 8
	major, minor, squash = 0.62, 0.3, 0.75
	mesh = bpy.data.meshes.new("Tire")
	bm = bmesh.new()
	rings = []
	for i in range(segments):
		angle = 2 * math.pi * i / segments
		tread = 0.07 if i // 2 % 2 == 0 else 0.0
		ring = []
		for j in range(sides):
			around = 2 * math.pi * j / sides
			out = math.cos(around)
			radius = major + minor * out + (tread if out > 0.5 else 0.0)
			ring.append(bm.verts.new((math.cos(angle) * radius, math.sin(angle) * radius, minor * squash * math.sin(around))))
		rings.append(ring)
	for i in range(segments):
		a, b = rings[i], rings[(i + 1) % segments]
		for j in range(sides):
			k = (j + 1) % sides
			bm.faces.new((a[j], b[j], b[k], a[k]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(mesh)
	bm.free()
	return bpy.data.objects.new("Tire", mesh)


def cog() -> bpy.types.Object:
	# Flat gear: 8 chunky teeth round a hole, thickened and bevelled round.
	teeth, thickness = 8, 0.2
	outer = [0.62 if i % 4 in (1, 2) else 0.46 for i in range(teeth * 4)]
	mesh = bpy.data.meshes.new("Cog")
	bm = bmesh.new()
	count = len(outer)
	rim = [bm.verts.new((math.cos(2 * math.pi * (i - 0.5) / count) * r, math.sin(2 * math.pi * (i - 0.5) / count) * r, 0)) for i, r in enumerate(outer)]
	hole = [bm.verts.new((math.cos(2 * math.pi * (i - 0.5) / count) * 0.16, math.sin(2 * math.pi * (i - 0.5) / count) * 0.16, 0)) for i in range(count)]
	for i in range(count):
		j = (i + 1) % count
		bm.faces.new((hole[i], hole[j], rim[j], rim[i]))
	bmesh.ops.translate(bm, vec=(0, 0, -thickness / 2), verts=bm.verts)
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new("Cog", mesh)
	bpy.context.scene.collection.objects.link(obj)
	bpy.context.view_layer.objects.active = obj
	solidify = obj.modifiers.new("Thickness", "SOLIDIFY")
	solidify.thickness = thickness
	solidify.offset = 1.0
	bevel = obj.modifiers.new("Soften", "BEVEL")
	bevel.width = 0.05
	bevel.segments = 2
	bevel.limit_method = "ANGLE"
	for modifier in list(obj.modifiers):
		bpy.ops.object.modifier_apply(modifier=modifier.name)
	return obj


def spring() -> bpy.types.Object:
	# Fat wire coiled 5 times, leaning and wobbling as it rises.
	coils, radius, height, steps = 5, 0.3, 1.1, 10
	curve = bpy.data.curves.new("Spring", "CURVE")
	curve.dimensions = "3D"
	curve.bevel_depth = 0.075
	curve.bevel_resolution = 1
	spline = curve.splines.new("POLY")
	total = coils * steps
	spline.points.add(total)
	for i, point in enumerate(spline.points):
		t = i / total
		angle = 2 * math.pi * coils * t
		lean = 0.25 * t * t + 0.05 * math.sin(t * 9)
		point.co = (math.cos(angle) * radius + lean, math.sin(angle) * radius, height * t, 1)
	obj = bpy.data.objects.new("Spring", curve)
	bpy.context.scene.collection.objects.link(obj)
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.object.convert(target="MESH")
	obj = bpy.context.view_layer.objects.active
	obj.select_set(False)
	return obj


def cone() -> bpy.types.Object:
	# Squat lathed cone that bends over near the tip, on a chunky square foot.
	segments = 12
	profile = [(0.42, 0.12), (0.36, 0.4), (0.27, 0.75), (0.17, 1.05), (0.09, 1.25), (0.0, 1.3)]
	mesh = bpy.data.meshes.new("Cone")
	bm = bmesh.new()
	rings = []
	for radius, z in profile:
		bend = 0.18 * (z / 1.3) ** 2
		rings.append([bm.verts.new((math.cos(2 * math.pi * i / segments) * radius + bend, math.sin(2 * math.pi * i / segments) * radius, z)) for i in range(segments)])
	for low, high in zip(rings, rings[1:]):
		for i in range(segments):
			j = (i + 1) % segments
			bm.faces.new((low[i], low[j], high[j], high[i]))
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
	foot = bmesh.ops.create_cube(bm, size=1.0)["verts"]
	bmesh.ops.scale(bm, vec=(1.0, 1.0, 0.12), verts=foot)
	bmesh.ops.translate(bm, vec=(0, 0, 0.06), verts=foot)
	bmesh.ops.bevel(bm, geom=[e for e in bm.edges if all(v in foot for v in e.verts)], offset=0.08, segments=2, affect="EDGES")
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(mesh)
	bm.free()
	return bpy.data.objects.new("Cone", mesh)


def cone_material() -> bpy.types.Material:
	# Orange with one white band partway up, and grime darkening the foot.
	mat = scrapkit.material("Cone", linear(TRIM), roughness=0.4)
	nodes, links = mat.node_tree.nodes, mat.node_tree.links
	coords = nodes.new("ShaderNodeTexCoord")
	height = nodes.new("ShaderNodeSeparateXYZ")
	links.new(coords.outputs["Object"], height.inputs["Vector"])
	ramp = nodes.new("ShaderNodeValToRGB")
	ramp.color_ramp.interpolation = "CONSTANT"
	stops = ramp.color_ramp.elements
	stops[0].color = (*linear(GRIME), 1)
	stops[1].position = 0.15 / 1.3
	stops[1].color = (*linear(TRIM), 1)
	for position, color in ((0.55, CONE_BAND), (0.75, TRIM)):
		stop = stops.new(position / 1.3)
		stop.color = (*linear(color), 1)
	scale = nodes.new("ShaderNodeMath")
	scale.operation = "DIVIDE"
	scale.inputs[1].default_value = 1.3
	links.new(height.outputs["Z"], scale.inputs[0])
	links.new(scale.outputs["Value"], ramp.inputs["Fac"])
	links.new(ramp.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
	return mat


# Junk in the heap, in the order it shows up as the crate fills: kind,
# where on the heap (x/y as -1 to 1 across the fill), how far sunk, tilt in
# degrees and scale. A part with "on" set to an earlier part's index is
# stacked on top of it instead, offset by x/y in metres.
JUNK = (
	{"kind": "tire", "at": (-0.45, -0.2), "sink": 0.12, "tilt": (25, -10, 23)},
	{"kind": "cog", "at": (0.2, 0.45), "sink": 0.05, "tilt": (70, 15, 17)},
	{"kind": "spring", "at": (0.45, -0.35), "sink": 0.3, "tilt": (-12, 8, 0)},
	{"kind": "cone", "at": (0.75, 0.3), "sink": 0.35, "tilt": (10, -35, 46)},
	{"kind": "cog", "at": (-0.7, 0.5), "sink": 0.08, "tilt": (60, -20, 70), "scale": 0.8},
	{"kind": "spring", "at": (-0.1, -0.6), "sink": 0.25, "tilt": (55, 10, 30), "scale": 0.9},
	{"kind": "tire", "at": (0.35, 0.0), "sink": 0.15, "tilt": (-12, 15, 60), "scale": 0.8},
	{"kind": "cone", "at": (-0.35, 0.4), "sink": 0.3, "tilt": (-30, 10, 110)},
	{"kind": "spring", "at": (0.8, -0.55), "sink": 0.2, "tilt": (-40, -20, 0), "scale": 0.8},
	{"kind": "tire", "on": 6, "at": (0.1, -0.05), "sink": 0.05, "tilt": (-6, 8, 15), "scale": 0.7},
	{"kind": "cog", "on": 0, "at": (0.15, 0.1), "sink": 0.1, "tilt": (35, 5, 80), "scale": 0.9},
)


def top_of(obj: bpy.types.Object) -> float:
	bpy.context.view_layer.update()
	return max((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)


def place_junk(collection, prototypes, heap, level: float, count: int, prefix: str) -> None:
	# Copies the first count JUNK parts onto heap, sharing the prototypes' meshes.
	edge, middle = fill_edge(level)
	half_x = max(abs(p.x - middle.x) for p in edge) * 0.75
	half_y = max(abs(p.y - middle.y) for p in edge) * 0.75
	placed = []
	for index, spec in enumerate(JUNK[:count]):
		part = prototypes[spec["kind"]].copy()
		part.name = f"{prefix}_{spec['kind'].capitalize()}{index + 1}"
		collection.objects.link(part)
		part.scale = (spec.get("scale", 1.0),) * 3
		part.rotation_euler = tuple(math.radians(angle) for angle in spec["tilt"])
		if "on" in spec:
			base = placed[spec["on"]]
			x, y = base.location.x + spec["at"][0], base.location.y + spec["at"][1]
			part.location = (x, y, 0)
			# Rest the part's bottom on the base's top.
			bpy.context.view_layer.update()
			bottom = min((part.matrix_world @ Vector(corner)).z for corner in part.bound_box)
			part.location.z = top_of(base) - bottom - spec["sink"]
		else:
			x, y = middle.x + spec["at"][0] * half_x, middle.y + spec["at"][1] * half_y
			_, hit, _, _ = heap.ray_cast((x, y, HEIGHT * 2), (0, 0, -1))
			part.location = (x, y, hit.z - spec["sink"])
		placed.append(part)


collection = scrapkit.new_scene()
green = scrapkit.material("Body", linear(BODY), roughness=0.55)
steel = scrapkit.material("Bolt", linear(BOLT), metallic=0.6, roughness=0.45)
orange = scrapkit.material("Trim", linear(TRIM), roughness=0.5)
grey = scrapkit.material("Plate", linear(PLATE), metallic=0.5, roughness=0.5)

tub = scrapkit.link(body(), collection, green)
band = scrapkit.link(hazard_band(tub), collection, hazard_material())
patches, plate_bolts = plates(tub)
scrapkit.link(patches, collection, grey)
studs = scrapkit.link(bolts(tub, plate_bolts), collection, steel)
rim = scrapkit.link(trim(), collection, orange)
scrap = scrapkit.material("Scrap", linear(SCRAP), metallic=0.3, roughness=0.6)

rubber = scrapkit.material("Tire", linear(RUBBER), roughness=0.9)
blotches(rubber, CHALK, 1.5, 0.1)
brass = scrapkit.material("Cog", linear(BRASS), metallic=0.5, roughness=0.5)
blotches(brass, RUST, 2.5, 0.35)
coil = scrapkit.material("Spring", linear(SPRING_STEEL), metallic=0.7, roughness=0.35)
blotches(coil, RUST, 4.0, 0.12)
prototypes = {
	"tire": scrapkit.link(tire(), collection, rubber),
	"cog": scrapkit.link(cog(), collection, brass),
	"spring": scrapkit.link(spring(), collection, coil),
	"cone": scrapkit.link(cone(), collection, cone_material()),
}
for part in prototypes.values():
	smooth(part)

# Hand-painted edge highlights and crease shadows, baked per part.
scrapkit.paint_shading(tub, 2048, bands=6)
for part, size in ((patches, 512), (rim, 512), (studs, 256), *((part, 256) for part in prototypes.values())):
	scrapkit.paint_shading(part, size)
# The band keeps its round-the-tub UVs, so a long strip fits it best.
scrapkit.paint_shading(band, 1024, 64)

for number, (level, mound, count) in enumerate(FILL_LEVELS, 1):
	name = f"Fill_{number}"
	group = bpy.data.collections.new(name)
	collection.children.link(group)
	heap = scrapkit.link(fill(name, level, mound), group, scrap)
	place_junk(group, prototypes, heap, level, count, name)
	# The preview shows the fullest crate only.
	if number < len(FILL_LEVELS):
		for obj in group.objects:
			obj.hide_render = True

# Prototypes only lend their meshes to the copies.
for part in prototypes.values():
	bpy.data.objects.remove(part)

scrapkit.finish(collection)
