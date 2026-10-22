import bpy
import scrapkit

# Starter weapon: a scrap pipe club, built along +Z with the grip end at the
# origin so the tool's grip sits at the handle.
LENGTH = 4.0
RADIUS = 0.12

collection = scrapkit.new_scene()
rust = scrapkit.material("Rust", (0.45, 0.22, 0.1), metallic=0.6, roughness=0.8)

bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=RADIUS, depth=LENGTH, location=(0, 0, LENGTH / 2))
pipe = scrapkit.link(bpy.context.object, collection, rust)
pipe.name = "StarterWeapon"

scrapkit.finish(collection)
