"""A 2 x 2 x 2 cube. Import it into Studio to check the export scale:
it must come in as exactly 2 studs on every side, same as a default Part."""

import bpy
import scrapkit

collection = scrapkit.new_scene()

bpy.ops.mesh.primitive_cube_add(size=2.0)
scrapkit.link(bpy.context.object, collection, scrapkit.material("Gray", (0.6, 0.6, 0.6)))
bpy.context.object.name = "ReferenceCube"

scrapkit.finish(collection)
