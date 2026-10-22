import bpy
import scrapkit

# Starter weapon: a scrap pipe club, built along +Z with the grip end at the
# origin so the tool's grip sits at the handle.
LENGTH = 4.0
RADIUS = 0.12
GRIP_LENGTH = 1.2

collection = scrapkit.new_scene()
rust = scrapkit.material("Rust", (0.45, 0.22, 0.1), metallic=0.6, roughness=0.8)
tape = scrapkit.material("Tape", (0.08, 0.08, 0.08), roughness=0.9)
steel = scrapkit.material("Steel", (0.5, 0.5, 0.52), metallic=0.9, roughness=0.45)

bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=RADIUS, depth=LENGTH, location=(0, 0, LENGTH / 2))
pipe = scrapkit.link(bpy.context.object, collection, rust)
pipe.name = "StarterWeapon"

# Grip: black tape wrapped around the bottom of the pipe.
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=RADIUS * 1.25, depth=GRIP_LENGTH, location=(0, 0, GRIP_LENGTH / 2 + 0.1))
grip = scrapkit.link(bpy.context.object, collection, tape)
grip.name = "Grip"

# Head: a T-joint fitting screwed onto the top of the pipe.
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=RADIUS * 1.6, depth=0.5, location=(0, 0, LENGTH - 0.15))
collar = scrapkit.link(bpy.context.object, collection, steel)
collar.name = "Collar"
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=RADIUS * 1.8, depth=1.0, location=(0, 0, LENGTH + 0.2), rotation=(0, 1.5708, 0))
head = scrapkit.link(bpy.context.object, collection, steel)
head.name = "Head"

scrapkit.finish(collection)
