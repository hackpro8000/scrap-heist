"""Shared helpers for Scrap Heist model build scripts.

Every model lives in art/models/<Name>/build.py and is built headless by
scripts/build-model.sh. A build script calls new_scene(), adds geometry
to the "Export" collection, then calls finish(). That writes:

    art/models/<Name>/<Name>.blend   source file, editable by hand
    art/models/<Name>/<Name>.fbx     what gets imported into Roblox Studio
    art/models/<Name>/preview.png    a render to review without opening Blender

Units: 1 Blender unit = 1 Roblox stud. The FBX export scales for that.
"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

EXPORT_COLLECTION = "Export"

# Roblox's FBX importer reads centimetres; our scene unit is one stud.
# Verify with ReferenceCube (2 x 2 x 2) in Studio before changing this.
FBX_GLOBAL_SCALE = 1.0


def model_dir() -> Path:
	return Path(sys.argv[sys.argv.index("--") + 1]).resolve()


def new_scene() -> bpy.types.Collection:
	"""Empty the file and return the collection whose contents get exported."""
	bpy.ops.wm.read_factory_settings(use_empty=True)

	scene = bpy.context.scene
	scene.unit_settings.system = "NONE"

	collection = bpy.data.collections.new(EXPORT_COLLECTION)
	scene.collection.children.link(collection)
	return collection


def material(name: str, color: tuple[float, float, float], metallic: float = 0.0, roughness: float = 0.6) -> bpy.types.Material:
	"""A plain Principled material. Roblox reads the base color on import."""
	mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	mat.use_nodes = True
	bsdf = mat.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Metallic"].default_value = metallic
	bsdf.inputs["Roughness"].default_value = roughness
	mat.diffuse_color = (*color, 1.0)
	return mat


def link(obj: bpy.types.Object, collection: bpy.types.Collection, mat: bpy.types.Material | None = None) -> bpy.types.Object:
	for owner in list(obj.users_collection):
		owner.objects.unlink(obj)
	collection.objects.link(obj)
	if mat is not None:
		obj.data.materials.clear()
		obj.data.materials.append(mat)
	return obj


def _export_objects(collection: bpy.types.Collection) -> list[bpy.types.Object]:
	return [obj for obj in collection.all_objects if obj.type == "MESH"]


def _render_preview(collection: bpy.types.Collection, path: Path) -> None:
	scene = bpy.context.scene
	objects = _export_objects(collection)

	# Frame the model: a camera on a 3/4 view, distance from its bounding size.
	points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
	low = [min(p[i] for p in points) for i in range(3)]
	high = [max(p[i] for p in points) for i in range(3)]
	center = [(low[i] + high[i]) / 2 for i in range(3)]
	size = max(high[i] - low[i] for i in range(3)) or 1.0

	camera_data = bpy.data.cameras.new("PreviewCamera")
	camera_data.type = "ORTHO"
	camera_data.ortho_scale = size * 2.2
	camera = bpy.data.objects.new("PreviewCamera", camera_data)
	scene.collection.objects.link(camera)
	direction = Vector((1.0, -1.0, 0.8)).normalized()
	camera.location = [center[i] + direction[i] * size * 3 for i in range(3)]
	camera.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
	scene.camera = camera

	sun_data = bpy.data.lights.new("PreviewSun", "SUN")
	sun_data.energy = 3.0
	sun = bpy.data.objects.new("PreviewSun", sun_data)
	sun.rotation_euler = (math.radians(50), 0, math.radians(30))
	scene.collection.objects.link(sun)

	world = bpy.data.worlds.new("PreviewWorld")
	world.use_nodes = True
	world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.37, 0.4, 1)
	scene.world = world

	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = 32
	scene.render.resolution_x = 768
	scene.render.resolution_y = 768
	scene.render.filepath = str(path)
	bpy.ops.render.render(write_still=True)

	# Preview helpers stay out of the saved .blend.
	for obj in (camera, sun):
		bpy.data.objects.remove(obj)


def finish(collection: bpy.types.Collection) -> None:
	"""Save the .blend, export the FBX and render preview.png."""
	directory = model_dir()
	name = directory.name

	_render_preview(collection, directory / "preview.png")

	bpy.ops.wm.save_as_mainfile(filepath=str(directory / f"{name}.blend"), compress=True)

	bpy.ops.object.select_all(action="DESELECT")
	for obj in _export_objects(collection):
		obj.select_set(True)
	bpy.ops.export_scene.fbx(
		filepath=str(directory / f"{name}.fbx"),
		use_selection=True,
		object_types={"MESH"},
		global_scale=FBX_GLOBAL_SCALE,
		apply_scale_options="FBX_SCALE_UNITS",
		axis_forward="-Z",
		axis_up="Y",
		apply_unit_scale=True,
		bake_space_transform=True,
		mesh_smooth_type="FACE",
		add_leaf_bones=False,
		# Embed textures so Studio picks them up with the mesh.
		path_mode="COPY",
		embed_textures=True,
	)
	print(f"built {name}")
