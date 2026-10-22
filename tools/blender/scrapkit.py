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
# 0.02 is the scale Tristen's hand-made exports used in Studio.
# Verify with ReferenceCube (2 x 2 x 2) in Studio before changing this.
FBX_GLOBAL_SCALE = 0.02


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


def paint_shading(obj: bpy.types.Object, size: int = 512, height: int | None = None, highlight: float = 0.7, shadow: float = 0.75, bands: int = 0) -> None:
	"""Bake hand-painted, light-independent shading into obj's base color.

	Edges that stick out get a pale highlight, creases and contact spots get a
	cool shadow, judged from shape alone (bevel normals and ambient occlusion),
	so it reads the same under any light. Bands above zero also darken it
	in that many flat steps over the bottom half, fading to nothing midway up,
	each step nudged by its own bit of noise. The result is a texture saved next
	to the model, which replaces the material's base color.
	"""
	mat = obj.data.materials[0]
	nodes, links = mat.node_tree.nodes, mat.node_tree.links
	bsdf = nodes["Principled BSDF"]
	output = nodes["Material Output"]
	base_input = bsdf.inputs["Base Color"]
	base = base_input.links[0].from_socket if base_input.is_linked else None

	if not obj.data.uv_layers:
		bpy.ops.object.select_all(action="DESELECT")
		obj.select_set(True)
		bpy.context.view_layer.objects.active = obj
		bpy.ops.object.mode_set(mode="EDIT")
		bpy.ops.mesh.select_all(action="SELECT")
		bpy.ops.uv.smart_project(island_margin=0.02)
		bpy.ops.object.mode_set(mode="OBJECT")

	def mix(factor, a, b, blend="MIX"):
		node = nodes.new("ShaderNodeMix")
		node.data_type = "RGBA"
		node.blend_type = blend
		node.clamp_result = True
		for socket, value in ((node.inputs[0], factor), (node.inputs[6], a), (node.inputs[7], b)):
			if isinstance(value, bpy.types.NodeSocket):
				links.new(value, socket)
			else:
				socket.default_value = value
		return node.outputs[2]

	def math_node(operation, a, b=0.0, clamp=True):
		node = nodes.new("ShaderNodeMath")
		node.operation = operation
		node.use_clamp = clamp
		for socket, value in zip(node.inputs, (a, b)):
			if isinstance(value, bpy.types.NodeSocket):
				links.new(value, socket)
			else:
				socket.default_value = value
		return node.outputs[0]

	# Edge mask: where a rounded normal turns away from the real one.
	radius = 0.1
	geometry = nodes.new("ShaderNodeNewGeometry")
	# Several overlapping brush strokes rather than one even line: each has
	# its own width wobble and breaks off in places, and where strokes
	# cross the paint builds up brighter.
	edge = None
	for seed, (reach, scale, thin, wide, strength) in enumerate(((1.0, 3.0, 6.0, 24.0, 0.8), (2.2, 5.0, 3.0, 14.0, 0.6), (0.5, 9.0, 8.0, 36.0, 0.7))):
		# Each stroke reaches its own distance off the edge, so they fan out.
		probe = nodes.new("ShaderNodeBevel")
		probe.inputs["Radius"].default_value = radius * reach
		probe.samples = 8
		facing = nodes.new("ShaderNodeVectorMath")
		facing.operation = "DOT_PRODUCT"
		links.new(probe.outputs["Normal"], facing.inputs[0])
		links.new(geometry.outputs["Normal"], facing.inputs[1])
		bend = math_node("SUBTRACT", 1.0, facing.outputs["Value"])
		width = nodes.new("ShaderNodeTexNoise")
		width.noise_dimensions = "4D"
		width.inputs["W"].default_value = seed * 3.1
		width.inputs["Scale"].default_value = scale
		width.inputs["Detail"].default_value = 1.0
		gain = nodes.new("ShaderNodeMapRange")
		gain.inputs["From Min"].default_value = 0.3
		gain.inputs["From Max"].default_value = 0.7
		gain.inputs["To Min"].default_value = thin
		gain.inputs["To Max"].default_value = wide
		links.new(width.outputs["Fac"], gain.inputs["Value"])
		# Where this noise dips low the stroke lifts off, leaving a gap.
		lift = nodes.new("ShaderNodeTexNoise")
		lift.noise_dimensions = "4D"
		lift.inputs["W"].default_value = seed * 5.7 + 1.3
		lift.inputs["Scale"].default_value = scale * 0.8
		lift.inputs["Detail"].default_value = 0.0
		painted = nodes.new("ShaderNodeMapRange")
		painted.inputs["From Min"].default_value = 0.42
		painted.inputs["From Max"].default_value = 0.5
		links.new(lift.outputs["Fac"], painted.inputs["Value"])
		stroke = math_node("MULTIPLY", math_node("MULTIPLY", bend, gain.outputs["Result"]), painted.outputs["Result"])
		# Pen pressure: the hand presses and eases off along the stroke, so its
		# brightness swells and fades rather than staying even.
		push = nodes.new("ShaderNodeTexNoise")
		push.noise_dimensions = "4D"
		push.inputs["W"].default_value = seed * 2.3 + 7.9
		push.inputs["Scale"].default_value = scale * 0.5
		push.inputs["Detail"].default_value = 0.0
		pressure = nodes.new("ShaderNodeMapRange")
		pressure.inputs["From Min"].default_value = 0.35
		pressure.inputs["From Max"].default_value = 0.65
		pressure.inputs["To Min"].default_value = 0.35 * strength
		pressure.inputs["To Max"].default_value = strength
		links.new(push.outputs["Fac"], pressure.inputs["Value"])
		stroke = math_node("MULTIPLY", stroke, pressure.outputs["Result"])
		edge = stroke if edge is None else math_node("ADD", edge, stroke)

	# Openness: dark in creases and where other parts crowd in.
	ao = nodes.new("ShaderNodeAmbientOcclusion")
	ao.inputs["Distance"].default_value = 0.8
	ao.samples = 16
	openness = ao.outputs["AO"]

	# Highlight only convex edges (open ones); shadow where it's closed in.
	lit = math_node("MULTIPLY", math_node("MULTIPLY", edge, openness), highlight)
	dark = math_node("MULTIPLY", math_node("MULTIPLY", math_node("SUBTRACT", 1.0, openness), 1.6), shadow)
	color = base if base is not None else tuple(base_input.default_value)
	color = mix(lit, color, (1.0, 0.97, 0.85, 1.0), "SCREEN")
	color = mix(dark, color, (0.32, 0.3, 0.5, 1.0), "MULTIPLY")
	if bands > 0:
		# Height through the bounding box, 0 at the bottom to 1 at the top,
		# snapped into flat bands that only cover the bottom half.
		coords = nodes.new("ShaderNodeTexCoord")
		rise = nodes.new("ShaderNodeSeparateXYZ")
		links.new(coords.outputs["Generated"], rise.inputs[0])
		band = math_node("FLOOR", math_node("MULTIPLY", rise.outputs["Z"], bands * 2, clamp=False), clamp=False)
		# Each band gets its own random nudge so the steps aren't even.
		noise = nodes.new("ShaderNodeTexWhiteNoise")
		noise.noise_dimensions = "1D"
		links.new(band, noise.inputs["W"])
		jitter = math_node("MULTIPLY", math_node("SUBTRACT", noise.outputs["Value"], 0.5, clamp=False), 0.6, clamp=False)
		darkness = math_node("SUBTRACT", 1.0, math_node("DIVIDE", math_node("ADD", band, jitter, clamp=False), bands))
		color = mix(math_node("MULTIPLY", darkness, 0.9), color, (0.25, 0.22, 0.4, 1.0), "MULTIPLY")

	image = bpy.data.images.new(f"{obj.name}_Shaded", size, height or size)
	texture = nodes.new("ShaderNodeTexImage")
	texture.image = image
	nodes.active = texture

	# Bake the painted color straight out through an emission shader.
	emission = nodes.new("ShaderNodeEmission")
	links.new(color, emission.inputs["Color"])
	links.new(emission.outputs[0], output.inputs["Surface"])
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = 16
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	bpy.ops.object.bake(type="EMIT", margin=4)

	# Swap the baked image in and drop the painting nodes.
	links.new(bsdf.outputs[0], output.inputs["Surface"])
	for node in list(nodes):
		if node not in (bsdf, output, texture):
			nodes.remove(node)
	links.new(texture.outputs["Color"], base_input)
	image.filepath_raw = str(model_dir() / f"{image.name}.png")
	image.file_format = "PNG"
	image.save()
	image.pack()
	obj.select_set(False)


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
