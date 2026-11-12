// Scene: reads a .glb that glb::write made back into the parts and bones it
// was written from, so review views render from the saved file without running
// the model script or the bake again. Textures stay packed until a view needs
// them (load_textures): a part that falls in no view never has its PNG decoded.

use std::cell::{Cell, RefCell};
use std::rc::Rc;

use crate::image::Image;
use crate::mesh::{add, cross, dot, normalize, scale, sub, Corner, Face, Mesh, Vec3};
use crate::{Bone, Part};

pub struct Scene {
	pub parts: Vec<Part>,
	// The rig at rest, as model.bone made it; empty for an unrigged model.
	pub bones: Vec<Bone>,
	// Per part: the middle of its bounds and the radius of the ball around them (Z up).
	pub bounds: Vec<(Vec3, f64)>,
	// Per part: which entry of `maps` holds its colour map.
	map_of: Vec<usize>,
	maps: Vec<ColourMap>,
	file: Vec<u8>,
}

// One stored colour map, shared by every part that points at it, as write
// stores each distinct PNG once.
struct ColourMap {
	image: Rc<RefCell<Image>>,
	// Where its PNG bytes sit in the file.
	start: usize,
	end: usize,
	decoded: Cell<bool>,
}

// glTF is Y up; glb::write turned our (x, y, z) into (x, z, -y).
fn from_y_up(p: [f32; 3]) -> Vec3 {
	[p[0] as f64, -(p[2] as f64), p[1] as f64]
}

pub fn read(file: Vec<u8>) -> Result<Scene, String> {
	let word = |at: usize| file.get(at..at + 4).map(|b| u32::from_le_bytes([b[0], b[1], b[2], b[3]]) as usize);
	if file.get(0..4) != Some(b"glTF".as_slice()) || file.get(16..20) != Some(b"JSON".as_slice()) {
		return Err("not a binary glTF (.glb)".into());
	}
	let json_end = 20 + word(12).ok_or("glb header cut short")?;
	let gltf = Parser { bytes: file.get(20..json_end).ok_or("glb JSON chunk runs past the file")?, at: 0 }.value()?;
	let bin_start = json_end + 8;
	let bin_end = bin_start + word(json_end).unwrap_or(0);
	let bin = file.get(bin_start..bin_end).ok_or("glb binary chunk runs past the file")?;

	let nodes = gltf.get("nodes").items();
	let joints: Vec<usize> = gltf.get("skins").at(0).get("joints").items().iter().filter_map(Json::index).collect();
	let mut parent_of: Vec<Option<usize>> = vec![None; nodes.len()];
	for (index, node) in nodes.iter().enumerate() {
		for child in node.get("children").items().iter().filter_map(Json::index) {
			if let Some(slot) = parent_of.get_mut(child) {
				*slot = Some(index);
			}
		}
	}

	let mut parts = Vec::new();
	let mut bounds = Vec::new();
	let mut map_of = Vec::new();
	let mut maps: Vec<ColourMap> = Vec::new();
	// glTF texture index -> entry in `maps`.
	let mut map_at: Vec<(usize, usize)> = Vec::new();
	for (index, node) in nodes.iter().enumerate() {
		let Some(mesh_index) = node.get("mesh").index() else {
			continue;
		};
		let name = node.get("name").text().unwrap_or("").to_string();
		// A part's parent node is its group, unless the parent is a bone.
		let group = parent_of[index].filter(|p| !joints.contains(p)).and_then(|p| nodes[p].get("name").text()).map(str::to_string);
		let preview = !matches!(node.get("extras").get("preview"), Json::Bool(false));
		let primitive = gltf.get("meshes").at(mesh_index).get("primitives").at(0);
		let attributes = primitive.get("attributes");
		let need = |key: &str| attributes.get(key).index().ok_or(format!("part {name} has no {key}"));
		let positions = floats(&gltf, bin, need("POSITION")?)?;
		let normals = floats(&gltf, bin, need("NORMAL")?)?;
		let uvs = floats(&gltf, bin, need("TEXCOORD_0")?)?;
		let triangles = indices(&gltf, bin, primitive.get("indices").index().ok_or(format!("part {name} has no indices"))?)?;
		let count = positions.len() / 3;
		if normals.len() < count * 3 || uvs.len() < count * 2 || triangles.iter().any(|&i| i as usize >= count) {
			return Err(format!("part {name}: attributes don't line up"));
		}
		let corners: Vec<Corner> = (0..count)
			.map(|i| Corner {
				position: from_y_up([positions[3 * i], positions[3 * i + 1], positions[3 * i + 2]]),
				normal: from_y_up([normals[3 * i], normals[3 * i + 1], normals[3 * i + 2]]),
				// glTF's V runs down from the top of the image; ours runs up.
				uv: [uvs[2 * i] as f64, (1.0f32 - uvs[2 * i + 1]) as f64],
			})
			.collect();
		// Rigid skin: every corner follows the same one bone.
		let bone = match attributes.get("JOINTS_0").index() {
			Some(at) => Some(first_joint(&gltf, bin, at)?),
			None => None,
		};
		let material = gltf.get("materials").at(primitive.get("material").index().unwrap_or(usize::MAX));
		let emissive = material.get("extensions").get("KHR_materials_emissive_strength").get("emissiveStrength").number().unwrap_or(0.0) as f32;
		let texture = material.get("pbrMetallicRoughness").get("baseColorTexture").get("index").index().ok_or(format!("part {name} has no colour map"))?;
		let map = match map_at.iter().find(|(t, _)| *t == texture) {
			Some(&(_, map)) => map,
			None => {
				let view = gltf.get("images").at(gltf.get("textures").at(texture).get("source").index().unwrap_or(usize::MAX)).get("bufferView").index();
				let view = gltf.get("bufferViews").at(view.ok_or(format!("part {name}: colour map has no bytes"))?);
				let start = bin_start + view.get("byteOffset").index().unwrap_or(0);
				let end = start + view.get("byteLength").index().unwrap_or(0);
				if end > bin_end {
					return Err(format!("part {name}: colour map runs past the file"));
				}
				// Stands in until load_textures decodes it; never drawn in a view it's out of.
				let image = Rc::new(RefCell::new(Image::new(1, 1, [0.5; 3])));
				maps.push(ColourMap { image, start, end, decoded: Cell::new(false) });
				map_at.push((texture, maps.len() - 1));
				maps.len() - 1
			}
		};
		bounds.push(ball(&corners));
		map_of.push(map);
		parts.push(Part {
			name,
			group,
			preview,
			emissive,
			mesh: Rc::new(RefCell::new(rebuild(&corners, &triangles))),
			image: maps[map].image.clone(),
			bone,
		});
	}

	// Bones: the skin's joints in bone order; the bind pose is each head with
	// no turn, so the inverse bind matrix's translation is minus the head.
	let inverse_binds = match gltf.get("skins").at(0).get("inverseBindMatrices").index() {
		Some(at) => floats(&gltf, bin, at)?,
		None => Vec::new(),
	};
	let mut bones = Vec::new();
	for (bone, &node) in joints.iter().enumerate() {
		let name = gltf.get("nodes").at(node).get("name").text().unwrap_or("");
		let name = name.strip_suffix("Bone").unwrap_or(name).to_string();
		let parent = parent_of.get(node).copied().flatten().and_then(|p| joints.iter().position(|&j| j == p));
		let head = match inverse_binds.get(bone * 16 + 12..bone * 16 + 15) {
			Some(m) => from_y_up([-m[0], -m[1], -m[2]]),
			None => [0.0; 3],
		};
		bones.push(Bone { name, parent, head });
	}
	Ok(Scene { parts, bones, bounds, map_of, maps, file })
}

impl Scene {
	// Decodes the colour map of every part `wanted` (by part index) picks that
	// isn't decoded yet; returns how many maps it decoded.
	pub fn load_textures(&self, wanted: impl Fn(usize) -> bool) -> Result<usize, String> {
		let mut decoded = 0;
		for (part, &map) in self.map_of.iter().enumerate() {
			let map = &self.maps[map];
			if map.decoded.get() || !wanted(part) {
				continue;
			}
			*map.image.borrow_mut() = decode_png(&self.file[map.start..map.end]).map_err(|e| format!("part {}: {e}", self.parts[part].name))?;
			map.decoded.set(true);
			decoded += 1;
		}
		Ok(decoded)
	}
}

// The middle of the corners' box and the radius of the ball around it.
fn ball(corners: &[Corner]) -> (Vec3, f64) {
	if corners.is_empty() {
		return ([0.0; 3], 0.0);
	}
	let mut low = [f64::MAX; 3];
	let mut high = [f64::MIN; 3];
	for corner in corners {
		for axis in 0..3 {
			low[axis] = low[axis].min(corner.position[axis]);
			high[axis] = high[axis].max(corner.position[axis]);
		}
	}
	let half = scale(sub(high, low), 0.5);
	(scale(add(low, high), 0.5), dot(half, half).sqrt())
}

// How far a pull face's corners stand from the corner it pulls, in studs:
// small enough that no picture sample lands on one, big enough that its
// normal comes out exact to about 1e-7 at map distances.
const PULL_SIZE: f64 = 1e-5;

// A mesh whose triangles() gives back these triangles with these corner
// normals. Mesh keeps no normals, it smooths them from its faces, so: every
// triangle gets its own three vertices, smoothing is on (a vertex's normal is
// the sum of its faces' normals), and where a stored normal differs from its
// triangle's own, tiny pull faces at that vertex add what makes up the
// difference. Triangles keep their order, so ties in depth draw the same.
fn rebuild(corners: &[Corner], triangles: &[u32]) -> Mesh {
	let mut mesh = Mesh { positions: Vec::new(), faces: Vec::new(), smooth_angle: 180.0 };
	let mut pulls_wanted: Vec<(usize, Vec3, [f64; 2])> = Vec::new();
	for triangle in triangles.chunks_exact(3) {
		let picked = [0, 1, 2].map(|k| corners[triangle[k] as usize]);
		let first = mesh.positions.len();
		mesh.positions.extend(picked.map(|c| c.position));
		let face = Face { verts: vec![first, first + 1, first + 2], uvs: Some(picked.map(|c| c.uv).to_vec()) };
		let span = cross(sub(picked[1].position, picked[0].position), sub(picked[2].position, picked[0].position));
		// A triangle with no area draws nothing, so its normals don't matter.
		if dot(span, span).sqrt() > 1e-12 {
			let own = mesh.face_normal(&face);
			for (k, corner) in picked.iter().enumerate() {
				for pull in pulls(own, normalize(corner.normal)) {
					pulls_wanted.push((first + k, pull, corner.uv));
				}
			}
		}
		mesh.faces.push(face);
	}
	for (vert, pull, uv) in pulls_wanted {
		let at = mesh.positions[vert];
		// Wound so its normal (across × along) is the pull.
		let across = perpendicular(pull);
		let along = cross(pull, across);
		let first = mesh.positions.len();
		mesh.positions.push(add(at, scale(across, PULL_SIZE)));
		mesh.positions.push(add(at, scale(along, PULL_SIZE)));
		mesh.faces.push(Face { verts: vec![vert, first, first + 1], uvs: Some(vec![uv; 3]) });
	}
	mesh
}

// Unit face normals that, summed with a triangle's own normal, point along
// `target`; none when they already agree.
fn pulls(own: Vec3, target: Vec3) -> Vec<Vec3> {
	let gap = sub(target, own);
	if dot(gap, gap) < 1e-12 {
		return Vec::new();
	}
	let facing = dot(own, target);
	// One pull mirrors `own` about `target`: own + pull = 2·facing·target.
	if facing > 0.05 {
		return vec![sub(scale(target, 2.0 * facing), own)];
	}
	// Near square or facing away: two pulls that add up to the gap exactly.
	let half = scale(gap, 0.5);
	let side = scale(perpendicular(gap), (1.0 - dot(half, half)).max(0.0).sqrt());
	vec![add(half, side), sub(half, side)]
}

// Some unit direction square to `v`.
fn perpendicular(v: Vec3) -> Vec3 {
	let v = normalize(v);
	let axis = if v[0].abs() < 0.6 { [1.0, 0.0, 0.0] } else { [0.0, 1.0, 0.0] };
	normalize(cross(v, axis))
}

// A PNG as glb::write stores it: 8-bit RGB, or RGBA for a see-through part.
// Only colour and opacity come back; the renderer reads nothing else.
fn decode_png(bytes: &[u8]) -> Result<Image, String> {
	let decoder = png::Decoder::new(bytes);
	let mut reader = decoder.read_info().map_err(|e| format!("texture: {e}"))?;
	let mut data = vec![0; reader.output_buffer_size()];
	let info = reader.next_frame(&mut data).map_err(|e| format!("texture: {e}"))?;
	let channels = match (info.color_type, info.bit_depth) {
		(png::ColorType::Rgb, png::BitDepth::Eight) => 3,
		(png::ColorType::Rgba, png::BitDepth::Eight) => 4,
		(color, depth) => return Err(format!("texture is {color:?} {depth:?}; expected 8-bit RGB or RGBA")),
	};
	let (width, height) = (info.width as usize, info.height as usize);
	let mut image = Image::new(width, height, [0.0; 3]);
	let mut alpha = if channels == 4 { Some(vec![0.0f32; width * height]) } else { None };
	let value = |b: u8| b as f32 / 255.0;
	for y in 0..height {
		// PNG rows run from the top; an Image's row 0 is the bottom.
		let row = &data[(height - 1 - y) * info.line_size..][..width * channels];
		for x in 0..width {
			let texel = &row[x * channels..][..channels];
			image.pixels[y * width + x] = [value(texel[0]), value(texel[1]), value(texel[2])];
			if let Some(alpha) = alpha.as_mut() {
				alpha[y * width + x] = value(texel[3]);
			}
		}
	}
	image.alpha = alpha;
	Ok(image)
}

// An accessor's bytes (from its buffer view, past its own offset), its count
// and its values per element.
fn accessor<'a>(gltf: &Json, bin: &'a [u8], index: usize) -> Result<(&'a [u8], usize, usize, usize), String> {
	let accessor = gltf.get("accessors").at(index);
	let count = accessor.get("count").index().ok_or(format!("accessor {index} has no count"))?;
	let view = gltf.get("bufferViews").at(accessor.get("bufferView").index().ok_or(format!("accessor {index} has no buffer view"))?);
	let view_start = view.get("byteOffset").index().unwrap_or(0);
	let start = view_start + accessor.get("byteOffset").index().unwrap_or(0);
	let end = view_start + view.get("byteLength").index().unwrap_or(0);
	let width = match accessor.get("type").text() {
		Some("VEC2") => 2,
		Some("VEC3") => 3,
		Some("VEC4") => 4,
		Some("MAT4") => 16,
		_ => 1,
	};
	let component = accessor.get("componentType").index().unwrap_or(0);
	let bytes = bin.get(start..end).ok_or(format!("accessor {index} runs past the file"))?;
	Ok((bytes, count, width, component))
}

fn floats(gltf: &Json, bin: &[u8], index: usize) -> Result<Vec<f32>, String> {
	let (bytes, count, width, component) = accessor(gltf, bin, index)?;
	if component != 5126 {
		return Err(format!("accessor {index} isn't floats"));
	}
	let bytes = bytes.get(..count * width * 4).ok_or(format!("accessor {index} is cut short"))?;
	Ok(bytes.chunks_exact(4).map(|b| f32::from_le_bytes([b[0], b[1], b[2], b[3]])).collect())
}

fn indices(gltf: &Json, bin: &[u8], index: usize) -> Result<Vec<u32>, String> {
	let (bytes, count, _, component) = accessor(gltf, bin, index)?;
	let size = match component {
		5125 => 4,
		5123 => 2,
		5121 => 1,
		_ => return Err(format!("accessor {index} isn't indices")),
	};
	let bytes = bytes.get(..count * size).ok_or(format!("accessor {index} is cut short"))?;
	Ok(bytes
		.chunks_exact(size)
		.map(|b| match size {
			4 => u32::from_le_bytes([b[0], b[1], b[2], b[3]]),
			2 => u16::from_le_bytes([b[0], b[1]]) as u32,
			_ => b[0] as u32,
		})
		.collect())
}

// The bone a rigidly skinned part follows: its first corner's first joint.
fn first_joint(gltf: &Json, bin: &[u8], index: usize) -> Result<usize, String> {
	let (bytes, _, _, component) = accessor(gltf, bin, index)?;
	match (component, bytes) {
		(5121, [joint, ..]) => Ok(*joint as usize),
		(5123, [low, high, ..]) => Ok(u16::from_le_bytes([*low, *high]) as usize),
		_ => Err(format!("accessor {index} isn't joints")),
	}
}

// Just enough JSON for glTF: what glb::write emits, plus escapes in strings.
enum Json {
	Null,
	Bool(bool),
	Number(f64),
	Text(String),
	List(Vec<Json>),
	Object(Vec<(String, Json)>),
}

static NULL: Json = Json::Null;

impl Json {
	// A field, or null when absent (so lookups chain).
	fn get(&self, key: &str) -> &Json {
		match self {
			Json::Object(fields) => fields.iter().find(|(k, _)| k == key).map_or(&NULL, |(_, v)| v),
			_ => &NULL,
		}
	}

	fn at(&self, index: usize) -> &Json {
		match self {
			Json::List(items) => items.get(index).unwrap_or(&NULL),
			_ => &NULL,
		}
	}

	fn items(&self) -> &[Json] {
		match self {
			Json::List(items) => items,
			_ => &[],
		}
	}

	fn number(&self) -> Option<f64> {
		if let Json::Number(n) = self { Some(*n) } else { None }
	}

	fn index(&self) -> Option<usize> {
		self.number().filter(|n| *n >= 0.0).map(|n| n as usize)
	}

	fn text(&self) -> Option<&str> {
		if let Json::Text(s) = self { Some(s.as_str()) } else { None }
	}
}

struct Parser<'a> {
	bytes: &'a [u8],
	at: usize,
}

impl Parser<'_> {
	// The next byte past any whitespace, without taking it.
	fn peek(&mut self) -> Option<u8> {
		while self.bytes.get(self.at).is_some_and(|b| b.is_ascii_whitespace()) {
			self.at += 1;
		}
		self.bytes.get(self.at).copied()
	}

	fn expect(&mut self, byte: u8) -> Result<(), String> {
		if self.peek() != Some(byte) {
			return Err(format!("JSON: expected '{}' at byte {}", byte as char, self.at));
		}
		self.at += 1;
		Ok(())
	}

	fn value(&mut self) -> Result<Json, String> {
		match self.peek().ok_or("JSON ended early")? {
			b'{' => {
				self.at += 1;
				let mut fields = Vec::new();
				if self.peek() == Some(b'}') {
					self.at += 1;
					return Ok(Json::Object(fields));
				}
				loop {
					let key = self.text()?;
					self.expect(b':')?;
					fields.push((key, self.value()?));
					match self.peek() {
						Some(b',') => self.at += 1,
						Some(b'}') => {
							self.at += 1;
							return Ok(Json::Object(fields));
						}
						_ => return Err(format!("JSON: expected ',' or '}}' at byte {}", self.at)),
					}
				}
			}
			b'[' => {
				self.at += 1;
				let mut items = Vec::new();
				if self.peek() == Some(b']') {
					self.at += 1;
					return Ok(Json::List(items));
				}
				loop {
					items.push(self.value()?);
					match self.peek() {
						Some(b',') => self.at += 1,
						Some(b']') => {
							self.at += 1;
							return Ok(Json::List(items));
						}
						_ => return Err(format!("JSON: expected ',' or ']' at byte {}", self.at)),
					}
				}
			}
			b'"' => Ok(Json::Text(self.text()?)),
			b't' => self.word("true", Json::Bool(true)),
			b'f' => self.word("false", Json::Bool(false)),
			b'n' => self.word("null", Json::Null),
			_ => self.number(),
		}
	}

	fn word(&mut self, word: &str, value: Json) -> Result<Json, String> {
		if !self.bytes[self.at..].starts_with(word.as_bytes()) {
			return Err(format!("JSON: unexpected text at byte {}", self.at));
		}
		self.at += word.len();
		Ok(value)
	}

	fn number(&mut self) -> Result<Json, String> {
		let start = self.at;
		while self.bytes.get(self.at).is_some_and(|&b| matches!(b, b'-' | b'+' | b'.' | b'e' | b'E' | b'0'..=b'9')) {
			self.at += 1;
		}
		std::str::from_utf8(&self.bytes[start..self.at])
			.ok()
			.and_then(|s| s.parse().ok())
			.map(Json::Number)
			.ok_or_else(|| format!("JSON: bad number at byte {start}"))
	}

	fn text(&mut self) -> Result<String, String> {
		self.expect(b'"')?;
		let mut out = Vec::new();
		loop {
			let byte = *self.bytes.get(self.at).ok_or("JSON: string never ends")?;
			self.at += 1;
			match byte {
				b'"' => break,
				b'\\' => {
					let escape = *self.bytes.get(self.at).ok_or("JSON: string never ends")?;
					self.at += 1;
					match escape {
						b'n' => out.push(b'\n'),
						b't' => out.push(b'\t'),
						b'r' => out.push(b'\r'),
						b'b' => out.push(8),
						b'f' => out.push(12),
						b'u' => {
							let code = self.bytes.get(self.at..self.at + 4).and_then(|h| std::str::from_utf8(h).ok()).and_then(|h| u32::from_str_radix(h, 16).ok());
							let code = code.ok_or(format!("JSON: bad \\u escape at byte {}", self.at))?;
							self.at += 4;
							let mut buffer = [0; 4];
							out.extend(char::from_u32(code).unwrap_or('\u{fffd}').encode_utf8(&mut buffer).as_bytes());
						}
						other => out.push(other),
					}
				}
				_ => out.push(byte),
			}
		}
		String::from_utf8(out).map_err(|_| "JSON: string isn't UTF-8".to_string())
	}
}
