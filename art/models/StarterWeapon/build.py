import math

import bmesh
import bpy
import scrapkit

# Starter weapon: a wooden baseball bat, built along +Z with the knob at the
# origin so the tool's grip sits at the handle.
SEGMENTS = 24
GRIP_LENGTH = 1.1

# Bat profile as (radius, height) pairs from the knob up to the barrel cap.
PROFILE = [
	(0.0, 0.0),
	(0.17, 0.0),
	(0.17, 0.08),
	(0.1, 0.16),
	(0.1, 1.3),
	(0.12, 2.0),
	(0.2, 2.9),
	(0.24, 3.5),
	(0.24, 3.9),
	(0.2, 4.0),
	(0.0, 4.02),
]


def lathe(name: str, profile: list[tuple[float, float]]) -> bpy.types.Object:
	mesh = bpy.data.meshes.new(name)
	bm = bmesh.new()
	rings = []
	for radius, height in profile:
		ring = []
		for i in range(SEGMENTS):
			angle = 2 * math.pi * i / SEGMENTS
			ring.append(bm.verts.new((math.cos(angle) * radius, math.sin(angle) * radius, height)))
		rings.append(ring)
	for low, high in zip(rings, rings[1:]):
		for i in range(SEGMENTS):
			j = (i + 1) % SEGMENTS
			bm.faces.new((low[i], low[j], high[j], high[i]))
	# The first and last rings have zero radius, so merge them into poles.
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(mesh)
	bm.free()
	for polygon in mesh.polygons:
		polygon.use_smooth = True
	return bpy.data.objects.new(name, mesh)


collection = scrapkit.new_scene()
wood = scrapkit.material("Wood", (0.62, 0.42, 0.22), roughness=0.55)
tape = scrapkit.material("Tape", (0.08, 0.08, 0.08), roughness=0.9)

scrapkit.link(lathe("StarterWeapon", PROFILE), collection, wood)

# Grip: black tape wrapped around the handle above the knob.
bpy.ops.mesh.primitive_cylinder_add(vertices=SEGMENTS, radius=0.115, depth=GRIP_LENGTH, location=(0, 0, 0.18 + GRIP_LENGTH / 2))
grip = scrapkit.link(bpy.context.object, collection, tape)
grip.name = "Grip"

scrapkit.finish(collection)
