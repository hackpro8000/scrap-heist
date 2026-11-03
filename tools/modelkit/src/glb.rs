// GLB export: one binary glTF holding every part with its texture embedded.
// One unit is one stud; in Studio's 3D Importer, set the file's scale unit to
// Stud. glTF is Y up, so our Z-up positions turn (x, y, z) into (x, z, -y).
// Parts sharing a group sit under one parent node, so the game can show one
// group (like a fill level) at a time. With bones, every part is skinned
// rigidly to its one bone and the joints come in as Studio Bones.

use crate::anim::{self, Clip};
use crate::{Bone, Part};

fn to_y_up(p: [f64; 3]) -> [f32; 3] {
	[p[0] as f32, p[2] as f32, -p[1] as f32]
}

fn pad(bytes: &mut Vec<u8>, fill: u8) {
	while bytes.len() % 4 != 0 {
		bytes.push(fill);
	}
}

pub fn write(parts: &[Part], bones: &[Bone], clips: &[Clip]) -> Vec<u8> {
	let mut bin: Vec<u8> = Vec::new();
	let mut views = Vec::new();
	let mut accessors = Vec::new();
	let mut meshes = Vec::new();
	let mut materials = Vec::new();
	let mut images = Vec::new();
	let mut textures = Vec::new();
	let mut nodes: Vec<String> = Vec::new();
	let mut roots: Vec<usize> = Vec::new();
	let mut groups: Vec<(String, Vec<usize>)> = Vec::new();
	// Placed copies of a model bake identical textures, so each distinct PNG
	// is stored once and every part using it points at that one texture.
	let mut stored: std::collections::HashMap<Vec<u8>, usize> = std::collections::HashMap::new();

	let mut push_view = |bin: &mut Vec<u8>, data: &[u8], target: Option<u32>| -> usize {
		let offset = bin.len();
		bin.extend_from_slice(data);
		pad(bin, 0);
		let target = target.map_or(String::new(), |t| format!(",\"target\":{t}"));
		views.push(format!("{{\"buffer\":0,\"byteOffset\":{offset},\"byteLength\":{}{target}}}", data.len()));
		views.len() - 1
	};

	for (index, part) in parts.iter().enumerate() {
		let mesh = part.mesh.borrow();
		let (corners, indices) = mesh.indexed();
		let mut positions = Vec::new();
		let mut normals = Vec::new();
		let mut uvs = Vec::new();
		let mut low = [f32::MAX; 3];
		let mut high = [f32::MIN; 3];
		for corner in &corners {
			let p = to_y_up(corner.position);
			for axis in 0..3 {
				low[axis] = low[axis].min(p[axis]);
				high[axis] = high[axis].max(p[axis]);
			}
			positions.extend(p.iter().flat_map(|x| x.to_le_bytes()));
			normals.extend(to_y_up(corner.normal).iter().flat_map(|x| x.to_le_bytes()));
			// glTF's V runs down from the top of the image.
			let uv = [corner.uv[0] as f32, 1.0 - corner.uv[1] as f32];
			uvs.extend(uv.iter().flat_map(|x| x.to_le_bytes()));
		}
		let mut skinning = String::new();
		if let Some(bone) = part.bone {
			let joints: Vec<u8> = (0..corners.len()).flat_map(|_| [bone as u8, 0, 0, 0]).collect();
			let weights: Vec<u8> = (0..corners.len()).flat_map(|_| [1f32, 0.0, 0.0, 0.0]).flat_map(|w| w.to_le_bytes()).collect();
			let view = push_view(&mut bin, &joints, Some(34962));
			accessors.push(format!("{{\"bufferView\":{view},\"componentType\":5121,\"count\":{},\"type\":\"VEC4\"}}", corners.len()));
			let joints_at = accessors.len() - 1;
			let view = push_view(&mut bin, &weights, Some(34962));
			accessors.push(format!("{{\"bufferView\":{view},\"componentType\":5126,\"count\":{},\"type\":\"VEC4\"}}", corners.len()));
			skinning = format!(",\"JOINTS_0\":{joints_at},\"WEIGHTS_0\":{}", accessors.len() - 1);
		}
		let index_bytes: Vec<u8> = indices.iter().flat_map(|i| i.to_le_bytes()).collect();
		let count = corners.len();
		let base = accessors.len();
		let view = push_view(&mut bin, &positions, Some(34962));
		accessors.push(format!(
			"{{\"bufferView\":{view},\"componentType\":5126,\"count\":{count},\"type\":\"VEC3\",\"min\":[{},{},{}],\"max\":[{},{},{}]}}",
			low[0], low[1], low[2], high[0], high[1], high[2]
		));
		let view = push_view(&mut bin, &normals, Some(34962));
		accessors.push(format!("{{\"bufferView\":{view},\"componentType\":5126,\"count\":{count},\"type\":\"VEC3\"}}"));
		let view = push_view(&mut bin, &uvs, Some(34962));
		accessors.push(format!("{{\"bufferView\":{view},\"componentType\":5126,\"count\":{count},\"type\":\"VEC2\"}}"));
		let view = push_view(&mut bin, &index_bytes, Some(34963));
		accessors.push(format!("{{\"bufferView\":{view},\"componentType\":5125,\"count\":{},\"type\":\"SCALAR\"}}", indices.len()));

		let png = part.image.borrow().encode_png();
		let texture = match stored.get(&png) {
			Some(&texture) => texture,
			None => {
				let view = push_view(&mut bin, &png, None);
				images.push(format!("{{\"bufferView\":{view},\"mimeType\":\"image/png\"}}"));
				textures.push(format!("{{\"source\":{}}}", images.len() - 1));
				stored.insert(png, textures.len() - 1);
				textures.len() - 1
			}
		};
		let glow = if part.emissive > 0.0 {
			format!(",\"emissiveTexture\":{{\"index\":{texture}}},\"emissiveFactor\":[1,1,1],\"extensions\":{{\"KHR_materials_emissive_strength\":{{\"emissiveStrength\":{}}}}}", part.emissive)
		} else { String::new() };
		materials.push(format!(
			"{{\"name\":\"{}\",\"pbrMetallicRoughness\":{{\"baseColorTexture\":{{\"index\":{texture}}},\"metallicFactor\":0,\"roughnessFactor\":1}}{glow}}}",
			part.name
		));
		meshes.push(format!(
			"{{\"name\":\"{}\",\"primitives\":[{{\"attributes\":{{\"POSITION\":{},\"NORMAL\":{},\"TEXCOORD_0\":{}{skinning}}},\"indices\":{},\"material\":{index}}}]}}",
			part.name,
			base,
			base + 1,
			base + 2,
			base + 3
		));
		let skin = if part.bone.is_some() { ",\"skin\":0" } else { "" };
		nodes.push(format!("{{\"name\":\"{}\",\"mesh\":{index}{skin}}}", part.name));
		match &part.group {
			None => roots.push(index),
			Some(group) => match groups.iter_mut().find(|(name, _)| name == group) {
				Some((_, children)) => children.push(index),
				None => groups.push((group.clone(), vec![index])),
			},
		}
	}
	for (name, children) in &groups {
		let list: Vec<String> = children.iter().map(|c| c.to_string()).collect();
		nodes.push(format!("{{\"name\":\"{name}\",\"children\":[{}]}}", list.join(",")));
		roots.push(nodes.len() - 1);
	}
	let mut skins = String::new();
	let mut animation_list = String::new();
	if !bones.is_empty() {
		let first = nodes.len();
		let mut inverse_binds = Vec::new();
		for (index, bone) in bones.iter().enumerate() {
			let parent_head = bone.parent.map_or([0.0; 3], |p| bones[p].head);
			let local = to_y_up([bone.head[0] - parent_head[0], bone.head[1] - parent_head[1], bone.head[2] - parent_head[2]]);
			let children: Vec<String> = (0..bones.len()).filter(|&c| bones[c].parent == Some(index)).map(|c| (first + c).to_string()).collect();
			let children = if children.is_empty() { String::new() } else { format!(",\"children\":[{}]", children.join(",")) };
			nodes.push(format!("{{\"name\":\"{}\",\"translation\":[{},{},{}]{children}}}", bone.name, local[0], local[1], local[2]));
			if bone.parent.is_none() {
				roots.push(first + index);
			}
			// Column-major; bind pose is the bone's head with no rotation.
			let head = to_y_up(bone.head);
			let matrix = [1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, -head[0], -head[1], -head[2], 1.0f32];
			inverse_binds.extend(matrix.iter().flat_map(|x| x.to_le_bytes()));
		}
		let view = push_view(&mut bin, &inverse_binds, None);
		accessors.push(format!("{{\"bufferView\":{view},\"componentType\":5126,\"count\":{},\"type\":\"MAT4\"}}", bones.len()));
		let joints: Vec<String> = (0..bones.len()).map(|b| (first + b).to_string()).collect();
		let skeleton = first + bones.iter().position(|b| b.parent.is_none()).unwrap_or(0);
		// Clips sample every frame: a time accessor shared by each clip's
		// channels, then a rotation and translation track per moving bone.
		let mut animations = Vec::new();
		for clip in clips {
			let count = clip.frames();
			let times: Vec<f32> = (0..count).map(|f| (f as f64 / anim::FPS) as f32).collect();
			let bytes: Vec<u8> = times.iter().flat_map(|t| t.to_le_bytes()).collect();
			let view = push_view(&mut bin, &bytes, None);
			accessors.push(format!("{{\"bufferView\":{view},\"componentType\":5126,\"count\":{count},\"type\":\"SCALAR\",\"min\":[0],\"max\":[{}]}}", times[count - 1]));
			let input = accessors.len() - 1;
			let poses: Vec<Vec<anim::Pose>> = times.iter().map(|&t| clip.local(bones, t as f64)).collect();
			let mut samplers = Vec::new();
			let mut channels = Vec::new();
			for &(bone, _) in &clip.tracks {
				let mut rotations = Vec::new();
				let mut previous = [0.0, 0.0, 0.0, 1.0];
				let mut translations = Vec::new();
				for pose in &poses {
					let q = anim::quaternion(&pose[bone].rotation);
					let mut q = [q[0], q[2], -q[1], q[3]];
					// Stay on the near side so frames blend the short way.
					if q.iter().zip(previous).map(|(a, b)| a * b).sum::<f64>() < 0.0 {
						q = q.map(|c| -c);
					}
					previous = q;
					rotations.extend(q.iter().flat_map(|c| (*c as f32).to_le_bytes()));
					translations.extend(to_y_up(pose[bone].translation).iter().flat_map(|c| c.to_le_bytes()));
				}
				for (path, data, kind) in [("rotation", rotations, "VEC4"), ("translation", translations, "VEC3")] {
					let view = push_view(&mut bin, &data, None);
					accessors.push(format!("{{\"bufferView\":{view},\"componentType\":5126,\"count\":{count},\"type\":\"{kind}\"}}"));
					samplers.push(format!("{{\"input\":{input},\"output\":{},\"interpolation\":\"LINEAR\"}}", accessors.len() - 1));
					channels.push(format!("{{\"sampler\":{},\"target\":{{\"node\":{},\"path\":\"{path}\"}}}}", samplers.len() - 1, first + bone));
				}
			}
			animations.push(format!("{{\"name\":\"{}\",\"samplers\":[{}],\"channels\":[{}]}}", clip.name, samplers.join(","), channels.join(",")));
		}
		if !animations.is_empty() {
			animation_list = format!(",\"animations\":[{}]", animations.join(","));
		}
		skins = format!(",\"skins\":[{{\"inverseBindMatrices\":{},\"skeleton\":{skeleton},\"joints\":[{}]}}]", accessors.len() - 1, joints.join(","));
	}
	let extensions = if parts.iter().any(|p| p.emissive > 0.0) { ",\"extensionsUsed\":[\"KHR_materials_emissive_strength\"]" } else { "" };
	let root_list: Vec<String> = roots.iter().map(|r| r.to_string()).collect();

	let mut json = format!(
		"{{\"asset\":{{\"version\":\"2.0\",\"generator\":\"modelkit\"}},\"scene\":0,\"scenes\":[{{\"nodes\":[{}]}}],\"nodes\":[{}],\"meshes\":[{}],\"materials\":[{}],\"textures\":[{}],\"images\":[{}],\"accessors\":[{}],\"bufferViews\":[{}],\"buffers\":[{{\"byteLength\":{}}}]{skins}{animation_list}{extensions}}}",
		root_list.join(","),
		nodes.join(","),
		meshes.join(","),
		materials.join(","),
		textures.join(","),
		images.join(","),
		accessors.join(","),
		views.join(","),
		bin.len()
	)
	.into_bytes();
	pad(&mut json, b' ');

	let total = 12 + 8 + json.len() + 8 + bin.len();
	let mut out = Vec::with_capacity(total);
	out.extend_from_slice(b"glTF");
	out.extend_from_slice(&2u32.to_le_bytes());
	out.extend_from_slice(&(total as u32).to_le_bytes());
	out.extend_from_slice(&(json.len() as u32).to_le_bytes());
	out.extend_from_slice(b"JSON");
	out.extend_from_slice(&json);
	out.extend_from_slice(&(bin.len() as u32).to_le_bytes());
	out.extend_from_slice(b"BIN\0");
	out.extend_from_slice(&bin);
	out
}
