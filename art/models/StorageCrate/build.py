import bmesh
import bpy
import scrapkit

# Storage crate: the yard's open-top bin, cartoony. The body flares wider at
# the top and leans a little to one side. Rim, feet and decals come later.
# Sits on the ground with its base at the origin.
BOTTOM_WIDTH = 4.4
BOTTOM_DEPTH = 3.0
TOP_WIDTH = 5.4
TOP_DEPTH = 3.8
HEIGHT = 2.8
LEAN = 0.25
WALL = 0.22

# Bright cartoon green, in sRGB.
BODY = (0.44, 0.68, 0.35)


def linear(color):
	# Palette is picked in sRGB; Blender's base color wants linear.
	return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in color)


def body() -> bpy.types.Object:
	# A tapered tub: four walls and a floor, no lid, thickened inward.
	mesh = bpy.data.meshes.new("Body")
	bm = bmesh.new()
	bottom = [bm.verts.new((x * BOTTOM_WIDTH / 2, y * BOTTOM_DEPTH / 2, 0)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
	top = [bm.verts.new((x * TOP_WIDTH / 2 + LEAN, y * TOP_DEPTH / 2, HEIGHT)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
	bm.faces.new(list(reversed(bottom)))
	for i in range(4):
		j = (i + 1) % 4
		bm.faces.new((bottom[i], bottom[j], top[j], top[i]))
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new("Body", mesh)
	bpy.context.scene.collection.objects.link(obj)
	bpy.context.view_layer.objects.active = obj
	solidify = obj.modifiers.new("Wall", "SOLIDIFY")
	solidify.thickness = WALL
	solidify.offset = -1.0
	bevel = obj.modifiers.new("Soften", "BEVEL")
	bevel.width = 0.08
	bevel.segments = 3
	for modifier in list(obj.modifiers):
		bpy.ops.object.modifier_apply(modifier=modifier.name)
	return obj


collection = scrapkit.new_scene()
green = scrapkit.material("Body", linear(BODY), roughness=0.55)

scrapkit.link(body(), collection, green)

scrapkit.finish(collection)
