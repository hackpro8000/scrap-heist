// modelkit: builds a Scrap Heist model from its Luau script.
//
//   modelkit art/models/StarterWeapon            build <Name>.glb and preview.png
//   modelkit art/models/StarterWeapon --turntable 48
//                                                also write turntable frames
//   modelkit art/models/StarterWeapon --size 2048
//                                                render previews at 2048px square
//   modelkit art/models/Scrapper --clip Idle
//                                                also write the clip's frames
//   modelkit art/models/StarterWeapon --parts
//                                                also write parts.png (each part in its
//                                                own flat colour), parts.txt (the colour
//                                                legend, also on stdout) and cells.txt
//                                                (the parts in each cell of a 6×6 grid
//                                                over the preview, A1 at the top left)
//   modelkit art/models/StarterWeapon --view front --view top --grid 1
//                                                also write square-on side views,
//                                                face_front.png ... (and face_front_parts.png
//                                                with --parts), with stud lines every
//                                                --grid studs
//   modelkit art/models/StarterWeapon --eye ... --renders 3/8
//                                                render only this machine's share of the
//                                                renders (every 8th, from the 3rd, in a
//                                                fixed order), under their usual names
//   modelkit art/models/ServerMap --chunks
//                                                also split the GLB into uploadable
//                                                chunks (see write_chunks)
//   modelkit art/models/ServerMap --chunks --shard 3/8
//                                                build only this machine's share of
//                                                a layout's placements (SHARD_INDEX
//                                                and SHARD_COUNT in the script), with
//                                                chunks tagged S3 so shards don't clash
//
// The script (model.luau) builds meshes and paints textures through the API
// below; this engine does the heavy, generic work (triangulating, export,
// rendering) so scripts change without a recompile.

mod anim;
mod bake;
mod brush;
mod cache;
mod coat;
mod detail;
mod glb;
mod hand;
mod gpu;
mod image;
mod marks;
mod mesh;
mod progress;
mod work;
mod render;

use std::cell::{Cell, RefCell};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::rc::Rc;
use std::sync::Arc;
use std::time::Instant;

use mlua::{AnyUserData, Lua, Table, UserData, UserDataMethods, Value};

use image::Image;
use mesh::{dot, scale, sub, Face, Mesh};

// The numbers set by name in a `tune` table.
fn tune_numbers(tune: Option<Table>) -> mlua::Result<Vec<(String, f64)>> {
	match tune {
		Some(table) => table.pairs::<String, f64>().collect(),
		None => Ok(Vec::new()),
	}
}

// One brush: {motion = "press", tune = {name = value, ...}}.
fn brush_spec(spec: &Table) -> mlua::Result<Arc<marks::Marks>> {
	let motion: String = spec.get("motion")?;
	let overrides = tune_numbers(spec.get("tune")?)?;
	marks::Marks::new(&motion, &overrides).map(Arc::new).map_err(mlua::Error::RuntimeError)
}

// The brush a part names for one of its layers in its `brushes` table.
fn brush_slot(options: Option<&Table>, slot: &str) -> mlua::Result<Option<Arc<marks::Marks>>> {
	let Some(brushes) = options.map(|o| o.get::<Option<Table>>("brushes")).transpose()?.flatten() else {
		return Ok(None);
	};
	brushes.get::<Option<Table>>(slot)?.map(|spec| brush_spec(&spec)).transpose()
}

// The edge highlight's shorthand: `litMotion` and `litTune`.
fn edge_shorthand(options: &Table) -> mlua::Result<Option<Arc<marks::Marks>>> {
	let Some(motion) = options.get::<Option<String>>("highlightMotion")? else {
		return Ok(None);
	};
	let overrides = tune_numbers(options.get("highlightMotionTune")?)?;
	marks::Marks::new(&motion, &overrides).map(|marks| Some(Arc::new(marks))).map_err(mlua::Error::RuntimeError)
}

const DEFAULT_PREVIEW_SIZE: usize = 768;

#[derive(Clone)]
struct MeshHandle(Rc<RefCell<Mesh>>);

#[derive(Clone)]
struct ImageHandle(Rc<RefCell<Image>>);

#[derive(Clone)]
pub struct Part {
	pub name: String,
	pub group: Option<String>,
	pub preview: bool,
	// Glow strength, like SurfaceAppearance.EmissiveStrength; 0 doesn't glow.
	pub emissive: f32,
	pub mesh: Rc<RefCell<Mesh>>,
	pub image: Rc<RefCell<Image>>,
	pub bone: Option<usize>,
}

// A rig joint. Parts follow exactly one bone each (rigid skin), so moving a
// bone in Studio moves its parts whole.
pub struct Bone {
	pub name: String,
	pub parent: Option<usize>,
	pub head: [f64; 3],
}

impl UserData for MeshHandle {
	fn add_methods<M: UserDataMethods<Self>>(methods: &mut M) {
		// Adds a vertex and returns its 1-based index.
		methods.add_method("vertex", |_, this, (x, y, z): (f64, f64, f64)| {
			let mut mesh = this.0.borrow_mut();
			mesh.positions.push([x, y, z]);
			Ok(mesh.positions.len())
		});
		// Adds a polygon from 1-based vertex indices, with optional UVs given
		// flat as {u1, v1, u2, v2, ...}.
		methods.add_method("face", |_, this, (verts, uvs): (Vec<usize>, Option<Vec<f64>>)| {
			let mut mesh = this.0.borrow_mut();
			let count = mesh.positions.len();
			if verts.len() < 3 || verts.iter().any(|&v| v == 0 || v > count) {
				return Err(mlua::Error::runtime(format!("face needs 3+ valid vertex indices (mesh has {count})")));
			}
			let uvs = match uvs {
				None => None,
				Some(flat) if flat.len() == verts.len() * 2 => Some(flat.chunks(2).map(|c| [c[0], c[1]]).collect()),
				Some(_) => return Err(mlua::Error::runtime("face uvs need one (u, v) pair per vertex")),
			};
			mesh.faces.push(Face { verts: verts.iter().map(|v| v - 1).collect(), uvs });
			Ok(())
		});
		methods.add_method("weld", |_, this, distance: Option<f64>| {
			this.0.borrow_mut().weld(distance.unwrap_or(1e-5));
			Ok(())
		});
		// true smooths everything, false is flat, a number smooths only across
		// edges sharper than that many degrees (auto smooth).
		methods.add_method("setSmooth", |_, this, smooth: mlua::Value| {
			let angle = match smooth {
				mlua::Value::Boolean(on) => if on { 180.0 } else { 0.0 },
				mlua::Value::Number(n) => n,
				mlua::Value::Integer(n) => n as f64,
				_ => return Err(mlua::Error::runtime("setSmooth takes a bool or an angle in degrees")),
			};
			this.0.borrow_mut().smooth_angle = angle;
			Ok(())
		});
		// Thickens an open surface; negative thickness grows inward.
		methods.add_method("solidify", |_, this, thickness: f64| {
			this.0.borrow_mut().solidify(thickness);
			Ok(())
		});
		// Returns a copy turned about z by `turn` radians, then moved by (x, y, z),
		// so a cached build can be placed anywhere without rebuilding it.
		methods.add_method("moved", |_, this, (turn, x, y, z): (f64, f64, f64, f64)| {
			let mesh = this.0.borrow();
			let (c, s) = (turn.cos(), turn.sin());
			let positions = mesh.positions.iter().map(|p| [p[0] * c - p[1] * s + x, p[0] * s + p[1] * c + y, p[2] + z]).collect();
			let moved = Mesh { positions, faces: mesh.faces.clone(), smooth_angle: mesh.smooth_angle };
			Ok(MeshHandle(Rc::new(RefCell::new(moved))))
		});
		methods.add_method("vertexCount", |_, this, ()| Ok(this.0.borrow().positions.len()));
		// The centre of the box around every vertex, and the radius of the
		// ball around that box: cx, cy, cz, radius.
		methods.add_method("bounds", |_, this, ()| {
			let mesh = this.0.borrow();
			let mut low = [f64::MAX; 3];
			let mut high = [f64::MIN; 3];
			for p in &mesh.positions {
				for axis in 0..3 {
					low[axis] = low[axis].min(p[axis]);
					high[axis] = high[axis].max(p[axis]);
				}
			}
			if mesh.positions.is_empty() {
				return Ok((0.0, 0.0, 0.0, 0.0));
			}
			let half = scale(sub(high, low), 0.5);
			let centre = scale([low[0] + high[0], low[1] + high[1], low[2] + high[2]], 0.5);
			Ok((centre[0], centre[1], centre[2], dot(half, half).sqrt()))
		});
		// Lays every face out in UV space, packed with a margin between charts.
		methods.add_method("unwrap", |_, this, margin: Option<f64>| {
			Ok(bake::unwrap(&mut this.0.borrow_mut(), margin.unwrap_or(0.01)))
		});
		// Paints each texel the color fn(x, y, z, nx, ny, nz) returns for the
		// surface point behind it, averaged over a 2×2 grid of points per texel
		// so stripes and edges come out anti-aliased.
		methods.add_method("paint", |lua, this, (image, color): (AnyUserData, mlua::Function)| {
			let image = image.borrow::<ImageHandle>()?.0.clone();
			// Shrunk before painting too, so a far part calls `color` less.
			if let Some(detail) = lua.app_data_ref::<detail::PreviewDetail>() {
				detail.shrink(&this.0.borrow(), &mut image.borrow_mut());
			}
			let (width, height) = {
				let image = image.borrow();
				(image.width, image.height)
			};
			let samples = bake::samples(&this.0.borrow(), width, height, 2);
			// `color` may return a fourth value, an opacity, which gives the
			// image an alpha channel for a see-through part.
			let mut sums = vec![[0.0f32; 5]; width * height];
			let mut has_alpha = false;
			for t in &samples {
				let [x, y, z] = t.position;
				let [nx, ny, nz] = t.normal;
				let (r, g, b, a) = color.call::<(f32, f32, f32, Option<f32>)>((x, y, z, nx, ny, nz))?;
				has_alpha |= a.is_some();
				let sum = &mut sums[t.pixel];
				*sum = [sum[0] + r, sum[1] + g, sum[2] + b, sum[3] + a.unwrap_or(1.0), sum[4] + 1.0];
			}
			let mut image = image.borrow_mut();
			let mut covered = vec![false; width * height];
			let mut opacity = vec![[1.0f32; 3]; width * height];
			for (pixel, [r, g, b, a, n]) in sums.into_iter().enumerate() {
				if n > 0.0 {
					image.pixels[pixel] = [r / n, g / n, b / n];
					opacity[pixel] = [a / n; 3];
					covered[pixel] = true;
				}
			}
			let mut alpha_covered = covered.clone();
			bake::dilate(&mut image.pixels, &mut covered, width, height, 8);
			if has_alpha {
				bake::dilate(&mut opacity, &mut alpha_covered, width, height, 8);
				image.alpha = Some(opacity.into_iter().map(|a| a[0]).collect());
			}
			Ok(())
		});
		// Paints the part stroke by stroke (a coat in the colors `paint`
		// returns, then grime, rust or dust, and scratches), then edge
		// highlights and contact shadows over it. Without `paint` the coat takes
		// the colors already in the image.
		methods.add_method("paintShading", |lua, this, (image, options): (AnyUserData, Option<Table>)| {
			let get = |key: &str, default: f64| -> mlua::Result<f64> {
				Ok(options.as_ref().map(|o| o.get::<Option<f64>>(key)).transpose()?.flatten().unwrap_or(default))
			};
			let shading = bake::Shading {
				highlight: get("highlight", 0.7)?,
				shadow: get("shadow", 0.75)?,
				bands: get("bands", 0.0)? as usize,
				blend: get("blend", 0.0)?.clamp(0.0, 1.0),
				highlight_ramp: get("highlightRamp", 0.0)?.max(0.0),
				reach: get("reach", bake::CONTACT_REACH)?.clamp(0.02, 4.0),
				highlight_width: get("highlightWidth", 1.0)?.clamp(0.1, 8.0),
				highlight_uneven: get("highlightUneven", 0.0)?.clamp(0.0, 1.0),
				highlight_uneven_step: get("highlightUnevenStep", 0.5)?.clamp(0.01, 16.0),
				edge_marks: match brush_slot(options.as_ref(), "edge")? {
					Some(marks) => Some(marks),
					None => options.as_ref().map(edge_shorthand).transpose()?.flatten(),
				},
				shade_marks: brush_slot(options.as_ref(), "shade")?,
				soft_marks: brush_slot(options.as_ref(), "soft")?,
				highlight_to_zero: options.as_ref().map(|o| o.get::<Option<bool>>("highlightToZero")).transpose()?.flatten().unwrap_or(false),
				highlight_end: get("highlightEnd", 3.0)?.clamp(0.1, 16.0),
				painted_highlights: options.as_ref().map(|o| o.get::<Option<bool>>("paintedHighlights")).transpose()?.flatten().unwrap_or(false),
				crisp: options.as_ref().map(|o| o.get::<Option<bool>>("crisp")).transpose()?.flatten().unwrap_or(false),
				corner_taper: get("cornerTaper", 0.0)?.clamp(0.0, 16.0),
				soft_highlight: get("softHighlight", 0.0)?.clamp(0.0, 1.0),
				soft_reach: get("softReach", 1.0)?.clamp(0.02, 8.0),
				soft_uneven: get("softUneven", 0.0)?.clamp(0.0, 1.0),
				soft_taper: get("softTaper", 0.0)?.clamp(0.0, 16.0),
				soft_to_zero: options.as_ref().map(|o| o.get::<Option<bool>>("softToZero")).transpose()?.flatten().unwrap_or(false),
				soft_power: get("softPower", 1.0)?.clamp(0.25, 8.0),
				soft_end: get("softEnd", 3.0)?.clamp(0.1, 16.0),
				// heightRange = {bottom, top}: share one gradient across chunks.
				height_range: match options.as_ref().map(|o| o.get::<Option<Vec<f64>>>("heightRange")).transpose()?.flatten().as_deref() {
					Some(&[bottom, top]) if top > bottom => Some([bottom, top]),
					_ => None,
				},
				// strokes = {{start, along, normal, length, width, tail, color, brush}, ...}:
				// lines drawn over the coat, color in sRGB. brush is "taper"
				// (the default, crisp lines), "round" (a bristly mark pointed at
				// both ends) or "sponge" (a lobed dab).
				strokes: match options.as_ref().map(|o| o.get::<Option<Vec<Table>>>("strokes")).transpose()?.flatten() {
					Some(list) => list
						.iter()
						.enumerate()
						.map(|(index, stroke)| -> mlua::Result<brush::Stroke> {
							let along: mesh::Vec3 = stroke.get::<[f64; 3]>("along")?;
							let normal: mesh::Vec3 = stroke.get::<[f64; 3]>("normal")?;
							let across = mesh::cross(normal, along);
							let length = dot(across, across).sqrt().max(1e-9);
							Ok(brush::Stroke {
								brush: match stroke.get::<Option<String>>("brush")?.as_deref() {
									None | Some("taper") => brush::Brush::Taper,
									Some("round") => brush::Brush::Round,
									Some("sponge") => brush::Brush::Sponge,
									Some(other) => return Err(mlua::Error::RuntimeError(format!("unknown stroke brush {other}"))),
								},
								start: stroke.get::<[f64; 3]>("start")?,
								along,
								across: scale(across, 1.0 / length),
								normal,
								length: stroke.get("length")?,
								width: stroke.get("width")?,
								color: stroke.get::<[f32; 3]>("color")?.map(bake::to_linear),
								opacity: 1.0,
								seed: index as u32,
								tail: stroke.get::<Option<f64>>("tail")?.unwrap_or(0.0).clamp(0.0, 1.0),
								marks: if stroke.contains_key("motion")? { Some(brush_spec(stroke)?) } else { None },
							})
						})
						.collect::<mlua::Result<Vec<_>>>()?,
					None => Vec::new(),
				},
			};
			let image = image.borrow::<ImageHandle>()?.0.clone();
			let mesh = this.0.borrow();
			let brush = match lua.app_data_ref::<detail::PreviewDetail>() {
				Some(detail) => detail.shrink(&mesh, &mut image.borrow_mut()),
				None => 1.0,
			};
			let hand = match options.as_ref().map(|o| o.get::<Option<String>>("hand")).transpose()?.flatten().as_deref() {
				None => None,
				Some("rock") => Some(coat::Hand::Rock),
				Some("wood") => Some(coat::Hand::Wood),
				Some("metal") => Some(coat::Hand::Metal),
				Some(other) => return Err(mlua::Error::RuntimeError(format!("unknown hand style {other}"))),
			};
			let overrides: Vec<(String, f64)> = match options.as_ref().map(|o| o.get::<Option<Table>>("handTune")).transpose()?.flatten() {
				Some(table) => table.pairs::<String, f64>().collect::<mlua::Result<_>>()?,
				None => Vec::new(),
			};
			let tuning = hand.map(|h| hand::Tuning::new(h, &overrides)).transpose().map_err(mlua::Error::RuntimeError)?;
			let look = coat::Look {
				rust: get("rust", 0.0)?.clamp(0.0, 1.0),
				rubber: options.as_ref().map(|o| o.get::<Option<bool>>("rubber")).transpose()?.flatten().unwrap_or(false),
				gradient: get("gradient", 0.0)?.clamp(0.0, 1.0),
				brush,
				stamps: options.as_ref().map(|o| o.get::<Option<bool>>("stamps")).transpose()?.flatten().unwrap_or(false),
				hand,
				tuning,
				focus: options.as_ref().map(|o| o.get::<Option<Vec<f64>>>("handFocus")).transpose()?.flatten().filter(|f| f.len() == 4).map(|f| ([f[0], f[1], f[2]], f[3])),
				brushes: coat::Brushes {
					coat: brush_slot(options.as_ref(), "coat")?,
					grime: brush_slot(options.as_ref(), "grime")?,
					rust: brush_slot(options.as_ref(), "rust")?,
					drip: brush_slot(options.as_ref(), "drip")?,
					scratch: brush_slot(options.as_ref(), "scratch")?,
				},
			};
			let paint = options.as_ref().map(|o| o.get::<Option<mlua::Function>>("paint")).transpose()?.flatten();
			// A custom paint fn is keyed by `salt`, the item's source key, since its code can't be hashed.
			let custom = options.as_ref().map(|o| o.get::<Option<bool>>("custom")).transpose()?.flatten().unwrap_or(false);
			let salt = options.as_ref().map(|o| o.get::<Option<String>>("salt")).transpose()?.flatten();
			let mut occluders = Vec::new();
			if let Some(list) = options.as_ref().map(|o| o.get::<Option<Vec<AnyUserData>>>("occluders")).transpose()?.flatten() {
				for handle in list {
					occluders.push(handle.borrow::<MeshHandle>()?.0.clone());
				}
			}
			// Other chunks of this part: their edges count as this part's own.
			let mut group = Vec::new();
			if let Some(list) = options.as_ref().map(|o| o.get::<Option<Vec<AnyUserData>>>("group")).transpose()?.flatten() {
				for handle in list {
					group.push(handle.borrow::<MeshHandle>()?.0.clone());
				}
			}
			let name = options.as_ref().map(|o| o.get::<Option<String>>("name")).transpose()?.flatten().unwrap_or_default();
			let source = cache::Source { custom, salt };
			if cache::sharing() {
				let chunk = cache::bake_chunk(&name, &mesh);
				let mesh = (*mesh).clone();
				work::defer(chunk, Box::new(move || paint_part(&name, &mesh, &group, &occluders, &image, &shading, &look, paint.as_ref(), &source).map_err(|e| e.to_string())));
				return Ok(());
			}
			paint_part(&name, &mesh, &group, &occluders, &image, &shading, &look, paint.as_ref(), &source)
		});
	}
}

// Paints one part's shading onto its image.
#[allow(clippy::too_many_arguments)]
fn paint_part(name: &str, mesh: &Mesh, group: &[Rc<RefCell<Mesh>>], occluders: &[Rc<RefCell<Mesh>>], image: &Rc<RefCell<Image>>, shading: &bake::Shading, look: &coat::Look, paint: Option<&mlua::Function>, source: &cache::Source) -> mlua::Result<()> {
	let borrowed: Vec<_> = occluders.iter().map(|m| m.borrow()).collect();
	let refs: Vec<&Mesh> = borrowed.iter().map(|m| &**m).collect();
	let borrowed_group: Vec<_> = group.iter().map(|m| m.borrow()).collect();
	let group_refs: Vec<&Mesh> = borrowed_group.iter().map(|m| &**m).collect();
	let painted = bake::ImageSampler::new(mesh, &image.borrow());
	let mut failed = None;
	let mut base = |p: mesh::Vec3, n: mesh::Vec3| -> [f64; 3] {
		let Some(paint) = paint else {
			return painted.color(p, n);
		};
		match paint.call::<(f64, f64, f64)>((p[0], p[1], p[2], n[0], n[1], n[2])) {
			Ok((r, g, b)) => [r, g, b],
			Err(error) => {
				failed.get_or_insert(error);
				[1.0, 0.0, 1.0]
			}
		}
	};
	let started = Instant::now();
	bake::paint_shading(mesh, &group_refs, &refs, &mut image.borrow_mut(), shading, look, &mut base, source);
	let (width, height) = (image.borrow().width, image.borrow().height);
	progress::say(&format!("shaded {name} {width}×{height} in {:.2}s", started.elapsed().as_secs_f64()));
	match failed {
		Some(error) => Err(error),
		None => Ok(()),
	}
}

impl UserData for ImageHandle {
	fn add_methods<M: UserDataMethods<Self>>(methods: &mut M) {
		// Pixels are 0-based with y = 0 at the bottom, matching UV v.
		methods.add_method("set", |_, this, (x, y, r, g, b): (usize, usize, f32, f32, f32)| {
			let mut image = this.0.borrow_mut();
			if x >= image.width || y >= image.height {
				return Err(mlua::Error::runtime(format!("pixel ({x}, {y}) outside {}x{}", image.width, image.height)));
			}
			let width = image.width;
			image.pixels[y * width + x] = [r, g, b];
			Ok(())
		});
		methods.add_method("get", |_, this, (x, y): (usize, usize)| {
			let image = this.0.borrow();
			let [r, g, b] = image.pixels[y.min(image.height - 1) * image.width + x.min(image.width - 1)];
			Ok((r, g, b))
		});
		methods.add_method("size", |_, this, ()| {
			let image = this.0.borrow();
			Ok((image.width, image.height))
		});
	}
}

fn install_api(lua: &Lua, dir: &Path, parts: Rc<RefCell<Vec<Part>>>, bones: Rc<RefCell<Vec<Bone>>>, clips: Rc<RefCell<Vec<anim::Clip>>>, used: Rc<RefCell<Vec<PathBuf>>>, search: Vec<PathBuf>, texel_scale: f64, detail_eyes: &[(mesh::Vec3, mesh::Vec3)], size: usize) -> mlua::Result<()> {
	let globals = lua.globals();
	// Scales every texel density a layout asks for: 1 for final builds, less for previews.
	globals.set("TEXEL_SCALE", texel_scale)?;
	// Eye previews shrink each texture before shading it (see detail.rs).
	// previewBand(x, y, z) names a placement's distance band, and
	// previewPlacing(x, y, z, turn) tells the shrinking where place() puts the
	// model it is building at the origin; previewPlacing() clears it. Both are
	// absent outside eye previews.
	if !detail_eyes.is_empty() {
		lua.set_app_data(detail::PreviewDetail { eyes: detail_eyes.to_vec(), size, placing: Cell::new(None) });
		globals.set(
			"previewBand",
			lua.create_function(|lua, (x, y, z): (f64, f64, f64)| {
				Ok(lua.app_data_ref::<detail::PreviewDetail>().map(|detail| detail.band([x, y, z])))
			})?,
		)?;
		globals.set(
			"previewPlacing",
			lua.create_function(|lua, (x, y, z, turn): (Option<f64>, Option<f64>, Option<f64>, Option<f64>)| {
				if let Some(detail) = lua.app_data_ref::<detail::PreviewDetail>() {
					let placing = x.map(|x| ([x, y.unwrap_or(0.0), z.unwrap_or(0.0)], turn.unwrap_or(0.0)));
					detail.placing.set(placing);
				}
				Ok(())
			})?,
		)?;
	}
	// Eye previews size textures by where the eyes stand, so the eyes key the cache.
	let eye_key: String = detail_eyes.iter().map(|(e, t)| format!(" {},{},{}>{},{},{}", e[0], e[1], e[2], t[0], t[1], t[2])).collect();
	let eye_key = if detail_eyes.is_empty() { String::new() } else { format!(" eyes{eye_key} {size}") };

	let mesh_api = lua.create_table()?;
	mesh_api.set("new", lua.create_function(|_, ()| Ok(MeshHandle(Rc::new(RefCell::new(Mesh::new())))))?)?;
	globals.set("Mesh", mesh_api)?;

	let image_api = lua.create_table()?;
	image_api.set(
		"new",
		lua.create_function(|_, (width, height, r, g, b): (usize, usize, Option<f32>, Option<f32>, Option<f32>)| {
			if width == 0 || height == 0 {
				return Err(mlua::Error::runtime("image needs a nonzero size"));
			}
			let color = [r.unwrap_or(1.0), g.unwrap_or(1.0), b.unwrap_or(1.0)];
			Ok(ImageHandle(Rc::new(RefCell::new(Image::new(width, height, color)))))
		})?,
	)?;
	globals.set("Image", image_api)?;

	let model_api = lua.create_table()?;
	// model.bone(name, {at = {x, y, z}, parent = "Name"?}) adds a joint whose
	// pivot sits at `at`; bones without a parent are roots.
	// model.clip(name, {length = seconds, keys = {Bone = {{t = 0, rot = {x, y, z}?,
	// pos = {x, y, z}?}, ...}}}) adds an animation; see anim.rs.
	let rig = bones.clone();
	model_api.set(
		"clip",
		lua.create_function(move |_, (name, options): (String, Table)| {
			let length: f64 = options.get("length")?;
			let rig = rig.borrow();
			let mut tracks = Vec::new();
			for pair in options.get::<Table>("keys")?.pairs::<String, Table>() {
				let (bone, list) = pair?;
				let index = rig.iter().position(|b| b.name == bone).ok_or_else(|| mlua::Error::runtime(format!("clip {name}: no bone {bone}")))?;
				let mut keys = Vec::new();
				for key in list.sequence_values::<Table>() {
					let key = key?;
					let vector = |field: &str| -> mlua::Result<[f64; 3]> {
						Ok(match key.get::<Option<Vec<f64>>>(field)? {
							None => [0.0; 3],
							Some(v) if v.len() == 3 => [v[0], v[1], v[2]],
							Some(_) => return Err(mlua::Error::runtime(format!("clip {name}: {field} needs {{x, y, z}}"))),
						})
					};
					keys.push(anim::Key { time: key.get("t")?, rotation: vector("rot")?, offset: vector("pos")? });
				}
				keys.sort_by(|a, b| a.time.total_cmp(&b.time));
				tracks.push((index, keys));
			}
			clips.borrow_mut().push(anim::Clip { name: name.clone(), length, tracks });
			Ok(name)
		})?,
	)?;
	let rig = bones.clone();
	model_api.set(
		"bone",
		lua.create_function(move |_, (name, options): (String, Table)| {
			let at: Vec<f64> = options.get("at")?;
			if at.len() != 3 {
				return Err(mlua::Error::runtime("bone at needs {x, y, z}"));
			}
			let mut rig = rig.borrow_mut();
			if rig.iter().any(|b| b.name == name) {
				return Err(mlua::Error::runtime(format!("bone {name} already exists")));
			}
			let parent = match options.get::<Option<String>>("parent")? {
				None => None,
				Some(p) => Some(rig.iter().position(|b| b.name == p).ok_or_else(|| mlua::Error::runtime(format!("no bone {p}")))?),
			};
			rig.push(Bone { name: name.clone(), parent, head: [at[0], at[1], at[2]] });
			Ok(name)
		})?,
	)?;
	model_api.set(
		"part",
		lua.create_function(move |_, (name, mesh, image, options): (String, AnyUserData, AnyUserData, Option<Table>)| {
			let group = options.as_ref().map(|o| o.get::<Option<String>>("group")).transpose()?.flatten();
			let preview = options.as_ref().map(|o| o.get::<Option<bool>>("preview")).transpose()?.flatten().unwrap_or(true);
			let emissive = options.as_ref().map(|o| o.get::<Option<f32>>("emissive")).transpose()?.flatten().unwrap_or(0.0);
			let bone = match options.as_ref().map(|o| o.get::<Option<String>>("bone")).transpose()?.flatten() {
				None => None,
				Some(b) => Some(bones.borrow().iter().position(|x| x.name == b).ok_or_else(|| mlua::Error::runtime(format!("no bone {b} (add it before its parts)")))?),
			};
			parts.borrow_mut().push(Part {
				bone,
				name,
				group,
				preview,
				emissive,
				mesh: mesh.borrow::<MeshHandle>()?.0.clone(),
				image: image.borrow::<ImageHandle>()?.0.clone(),
			});
			Ok(())
		})?,
	)?;
	// model.cached(key, build) returns the parts build() returns, as a list of
	// {name, mesh, image, preview, emissive}, loading them from the cache when this key
	// was built before. The key must change whenever the result would.
	let folder = dir.to_path_buf();
	// With --share-bakes a part's save waits for its paint, so a later placement
	// of the same key takes the first one's parts from here, not from the file.
	let built_this_run: RefCell<HashMap<PathBuf, Table>> = RefCell::new(HashMap::new());
	model_api.set(
		"cached",
		lua.create_function(move |lua, (key, build): (String, mlua::Function)| {
			// A preview build is kept apart from the final one, which it differs from.
			let key = if texel_scale == 1.0 { key } else { format!("{key} @{texel_scale}{eye_key}") };
			let path = cache::path(&folder, &key);
			used.borrow_mut().push(path.clone());
			if let Some(list) = built_this_run.borrow().get(&path) {
				return Ok(list.clone());
			}
			if let Some(saved) = cache::load(&path) {
				progress::say(&format!("cached {}", progress::label(&key)));
				let list = lua.create_table()?;
				for part in saved {
					let entry = lua.create_table()?;
					entry.set("name", part.name)?;
					entry.set("mesh", MeshHandle(Rc::new(RefCell::new(part.mesh))))?;
					entry.set("image", ImageHandle(Rc::new(RefCell::new(part.image))))?;
					entry.set("preview", part.preview)?;
					entry.set("emissive", part.emissive)?;
					list.push(entry)?;
				}
				return Ok(list);
			}
			let label = progress::label(&key);
			progress::say(&format!("building {label}"));
			let started = Instant::now();
			let list: Table = progress::nested(|| build.call(()))?;
			progress::say(&format!("built {label}: {} parts in {:.1}s", list.raw_len(), started.elapsed().as_secs_f64()));
			let mut built = Vec::new();
			for entry in list.sequence_values::<Table>() {
				let entry = entry?;
				let mesh = entry.get::<AnyUserData>("mesh")?.borrow::<MeshHandle>()?.0.clone();
				let image = entry.get::<AnyUserData>("image")?.borrow::<ImageHandle>()?.0.clone();
				built.push((entry.get::<String>("name")?, entry.get::<Option<bool>>("preview")?.unwrap_or(true), entry.get::<Option<f32>>("emissive")?.unwrap_or(0.0), mesh, image));
			}
			let saved_at = path.clone();
			let save = move || {
				let borrowed: Vec<_> = built.iter().map(|(n, p, e, m, i)| (n.clone(), *p, *e, m.borrow(), i.borrow())).collect();
				let refs: Vec<_> = borrowed.iter().map(|(n, p, e, m, i)| (n.clone(), *p, *e, &**m, &**i)).collect();
				cache::save(&path, &refs).map_err(|e| e.to_string())
			};
			if cache::sharing() {
				built_this_run.borrow_mut().insert(saved_at, list.clone());
				work::defer_save(Box::new(save));
			} else {
				save().map_err(mlua::Error::external)?;
			}
			Ok(list)
		})?,
	)?;
	globals.set("model", model_api)?;

	// require("Name") loads Name.luau from the model's folder, then the shared
	// library, once per build.
	let cache: Rc<RefCell<HashMap<String, Value>>> = Rc::new(RefCell::new(HashMap::new()));
	globals.set(
		"require",
		lua.create_function(move |lua, name: String| {
			if let Some(value) = cache.borrow().get(&name) {
				return Ok(value.clone());
			}
			let path = search
				.iter()
				.map(|dir| dir.join(format!("{name}.luau")))
				.find(|p| p.exists())
				.ok_or_else(|| mlua::Error::runtime(format!("no module {name}.luau")))?;
			let source = std::fs::read_to_string(&path).map_err(mlua::Error::external)?;
			let value: Value = lua.load(source).set_name(format!("@{}", path.display())).eval()?;
			cache.borrow_mut().insert(name, value.clone());
			Ok(value)
		})?,
	)?;
	Ok(())
}

fn write_png(path: &Path, size: usize, data: &[u8]) -> std::io::Result<()> {
	std::fs::write(path, image::encode_render(size, size, data))
}

// A close-up: focus point x, y, z, framing radius, and camera spin in degrees.
type Closeup = (f64, f64, f64, f64, f64);

// Review renders: part colours, side views and their stud grid, and which
// share of all the renders this machine makes (--renders INDEX/COUNT).
struct Review {
	parts: bool,
	sides: Vec<render::Side>,
	grid: Option<f64>,
	share: Option<(usize, usize)>,
	work_port: Option<u16>,
}

fn run(dir: &Path, turntable: usize, size: usize, closeups: &[Closeup], eyes: &[(mesh::Vec3, mesh::Vec3)], shown_clip: Option<&str>, texel_scale: f64, detail_eyes: &[(mesh::Vec3, mesh::Vec3)], chunks: bool, shard: Option<(usize, usize)>, review: &Review) -> Result<(), String> {
	let started = Instant::now();
	let name = dir.file_name().and_then(|n| n.to_str()).ok_or("bad model folder")?.to_string();
	let script = dir.join("model.luau");
	let source = std::fs::read_to_string(&script).map_err(|e| format!("{}: {e}", script.display()))?;
	let library = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("lib");

	let lua = Lua::new();
	lua.enable_jit(true);
	let parts = Rc::new(RefCell::new(Vec::new()));
	let bones = Rc::new(RefCell::new(Vec::new()));
	let clips = Rc::new(RefCell::new(Vec::new()));
	let used = Rc::new(RefCell::new(Vec::new()));
	cache::enable_paint_cache(dir, used.clone());
	install_api(&lua, dir, parts.clone(), bones.clone(), clips.clone(), used.clone(), vec![dir.to_path_buf(), library], texel_scale, detail_eyes, size).map_err(|e| e.to_string())?;
	// The layout prelude reads these to build only this shard's placements.
	if let Some((index, count)) = shard {
		lua.globals().set("SHARD_INDEX", index).map_err(|e| e.to_string())?;
		lua.globals().set("SHARD_COUNT", count).map_err(|e| e.to_string())?;
	}
	// Marks the globals safe once the API is in: Luau then caches lookups like
	// math.noise, takes its fast paths for builtins and runs the JIT's native
	// code. Without it a paint fn runs several times slower. A safe chunk
	// resolves a path like model.part once, as it loads, so the API tables
	// scripts write into (prelude and IslandStudy swap model.part) are
	// declared mutable and looked up each time instead.
	lua.set_compiler(mlua::chunk::Compiler::new().set_mutable_globals(["model", "Mesh", "Image"]));
	// SAFETY: only sets the safe flag on the globals table.
	unsafe { lua.exec_raw::<()>((), |state| mlua::ffi::lua_setsafeenv(state, mlua::ffi::LUA_GLOBALSINDEX, 1)) }.map_err(|e| e.to_string())?;
	progress::say(&format!("running {name}/model.luau"));
	lua.load(source).set_name(format!("@{}", script.display())).exec().map_err(|e| e.to_string())?;
	// A shard uses only part of the cache, so pruning would throw away the
	// other shards' entries, unless the cache is the shard's own
	// (MODELKIT_PRUNE=1, as the build-map-shards workflow sets).
	if cache::sharing() {
		work::bake_and_swap(review.work_port.ok_or("--share-bakes needs --work-port")?)?;
	}
	if shard.is_none() || std::env::var("MODELKIT_PRUNE").is_ok_and(|v| v == "1") {
		cache::prune(dir, &used.borrow());
	}
	let scripted = started.elapsed();

	let parts = parts.borrow();
	if parts.is_empty() {
		return Err("model.luau added no parts (call model.part)".into());
	}
	let bones = bones.borrow();
	if !bones.is_empty() {
		if let Some(loose) = parts.iter().find(|p| p.bone.is_none()) {
			return Err(format!("part {} has no bone; a rigged model needs one on every part", loose.name));
		}
	}
	progress::say(&format!("writing {name}.glb and {} textures", parts.len()));
	let glb = dir.join(format!("{name}.glb"));
	std::fs::write(&glb, glb::write(&parts, &bones, &clips.borrow())).map_err(|e| e.to_string())?;
	if !clips.borrow().is_empty() {
		std::fs::write(dir.join(format!("{name}Clips.luau")), anim::write_luau(&name, &bones, &clips.borrow())).map_err(|e| e.to_string())?;
	}
	if chunks {
		let tag = shard.map_or(String::new(), |(index, _)| format!("S{index}_"));
		write_chunks(dir, &name, &tag, &parts, !bones.is_empty())?;
	}
	for part in parts.iter() {
		let png = dir.join(format!("{}.png", part.name));
		std::fs::write(png, part.image.borrow().encode_png()).map_err(|e| e.to_string())?;
		// Flat maps for the SurfaceAppearance: no metal, fully rough, so
		// Roblox adds no highlights over the painted shading.
		for (map, value) in [("Metalness", 0.0), ("Roughness", 1.0)] {
			let flat = Image::new(4, 4, [value; 3]).encode_png();
			std::fs::write(dir.join(format!("{}_{map}.png", part.name)), flat).map_err(|e| e.to_string())?;
		}
		// Glowing parts glow all over: a white EmissiveMaskContent, with the
		// strength set on the SurfaceAppearance's EmissiveStrength.
		if part.emissive > 0.0 {
			let mask = Image::new(4, 4, [1.0; 3]).encode_png();
			std::fs::write(dir.join(format!("{}_Emissive.png", part.name)), mask).map_err(|e| e.to_string())?;
		}
	}
	let shown: Vec<&Part> = parts.iter().filter(|p| p.preview).collect();
	// Every render below counts as one job, in a fixed order; with a share
	// this machine makes only its jobs, so machines split one model's renders,
	// and with a work port it claims each next job as it comes free.
	let total = shard.is_none() as usize + (review.parts && shard.is_none()) as usize + review.sides.len() + turntable + closeups.len() + eyes.len();
	let claims = RefCell::new(review.work_port.map(|port| work::RenderClaims::connect(port, total)).transpose()?);
	let job = std::cell::Cell::new(0usize);
	let mine = || {
		let at = job.get();
		job.set(at + 1);
		match claims.borrow_mut().as_mut() {
			Some(claims) => claims.mine(at),
			None => review.share.map_or(true, |(index, count)| at % count == index - 1),
		}
	};
	// A shard holds a scattered share of a layout, so nobody looks at its
	// preview; skip the render. Asked-for views (turntable, closeups, eyes) still run.
	if shard.is_none() && mine() {
		progress::say(&format!("rendering preview of {} parts", shown.len()));
		let preview = render::render(&shown, &render::View { size, spin: 0.0, focus: None, eye: None, ..Default::default() });
		write_png(&dir.join("preview.png"), size, &preview).map_err(|e| e.to_string())?;
	}
	if review.parts && shard.is_none() && mine() {
		let frame = render::render_frame(&shown, &render::View { size, parts: true, ..Default::default() });
		write_png(&dir.join("parts.png"), size, &frame.pixels).map_err(|e| e.to_string())?;
		let legend = render::legend(&shown);
		print!("{legend}");
		std::fs::write(dir.join("parts.txt"), legend).map_err(|e| e.to_string())?;
		std::fs::write(dir.join("cells.txt"), render::cells(&frame, &shown, 6)).map_err(|e| e.to_string())?;
	}
	for &side in &review.sides {
		if !mine() {
			continue;
		}
		let view = |parts| render::View { size, side: Some(side), parts, grid: review.grid, ..Default::default() };
		write_png(&dir.join(format!("face_{}.png", side.name())), size, &render::render(&shown, &view(false))).map_err(|e| e.to_string())?;
		if review.parts {
			write_png(&dir.join(format!("face_{}_parts.png", side.name())), size, &render::render(&shown, &view(true))).map_err(|e| e.to_string())?;
		}
	}

	if turntable > 0 {
		let frames = dir.join("turntable");
		std::fs::create_dir_all(&frames).map_err(|e| e.to_string())?;
		for frame in 0..turntable {
			if !mine() {
				continue;
			}
			let spin = frame as f64 / turntable as f64 * std::f64::consts::TAU;
			let data = render::render(&shown, &render::View { size, spin, focus: None, eye: None, ..Default::default() });
			write_png(&frames.join(format!("{frame:04}.png")), size, &data).map_err(|e| e.to_string())?;
		}
	}
	for (n, &(x, y, z, radius, degrees)) in closeups.iter().enumerate() {
		if !mine() {
			continue;
		}
		let focus = Some(([x, y, z], radius));
		let data = render::render(&shown, &render::View { size, spin: degrees.to_radians(), focus, eye: None, ..Default::default() });
		write_png(&dir.join(format!("closeup_{}.png", n + 1)), size, &data).map_err(|e| e.to_string())?;
	}
	for (n, &(eye, target)) in eyes.iter().enumerate() {
		if !mine() {
			continue;
		}
		progress::say(&format!("rendering eye {}/{}", n + 1, eyes.len()));
		let data = render::render(&shown, &render::View { size, spin: 0.0, focus: None, eye: Some((eye, target)), ..Default::default() });
		write_png(&dir.join(format!("eye_{}.png", n + 1)), size, &data).map_err(|e| e.to_string())?;
	}
	if let Some(wanted) = shown_clip {
		let clips = clips.borrow();
		let clip = clips.iter().find(|c| c.name == wanted).ok_or(format!("no clip {wanted}"))?;
		// Frame the rest pose once, so the camera holds still while it moves.
		let mut low = [f64::MAX; 3];
		let mut high = [f64::MIN; 3];
		for part in &shown {
			for corner in part.mesh.borrow().triangles().iter().flatten() {
				for axis in 0..3 {
					low[axis] = low[axis].min(corner.position[axis]);
					high[axis] = high[axis].max(corner.position[axis]);
				}
			}
		}
		let center = [0, 1, 2].map(|a| (low[a] + high[a]) / 2.0);
		let radius = (0..3).map(|a| high[a] - low[a]).fold(0.0, f64::max) * 0.6;
		let frames = dir.join(format!("clip_{wanted}"));
		std::fs::create_dir_all(&frames).map_err(|e| e.to_string())?;
		for frame in 0..clip.frames() {
			let skin = clip.skin(&bones, frame as f64 / anim::FPS);
			let data = render::render_posed(&shown, &skin, &render::View { size, spin: 0.0, focus: Some((center, radius)), eye: None, ..Default::default() });
			write_png(&frames.join(format!("{frame:04}.png")), size, &data).map_err(|e| e.to_string())?;
		}
	}
	eprintln!("{name}: {} parts, script {:.2?}, total {:.2?}", parts.len(), scripted, started.elapsed());
	if std::env::var("MODELKIT_PROFILE").is_ok_and(|v| v == "1") {
		for (layer, label) in bake::PROFILE_LAYERS.iter().enumerate() {
			let seconds = bake::PROFILE[layer].load(std::sync::atomic::Ordering::Relaxed) as f64 / 1e6;
			eprintln!("  {label}: {seconds:.2}s");
		}
	}
	Ok(())
}

// Open Cloud takes at most 20 MB per upload; stay a little under.
const CHUNK_LIMIT: usize = 19_000_000;

// Writes chunks/<Name>_<tag>NN.glb, each small enough to upload, and
// chunks/<Name>Chunks.luau listing them with their anchor parts, in Roblox
// coordinates (Y up), for the Studio placer (tools/studio/PlaceMap.luau).
// A shard's tag (S3_) keeps its files and keys apart from the other shards'.
fn write_chunks(dir: &Path, name: &str, tag: &str, parts: &[Part], rigged: bool) -> Result<(), String> {
	if rigged {
		return Err("--chunks is for layouts; a rigged model can't be split".into());
	}
	let out = dir.join("chunks");
	if out.exists() {
		std::fs::remove_dir_all(&out).map_err(|e| e.to_string())?;
	}
	std::fs::create_dir_all(&out).map_err(|e| e.to_string())?;
	let chunks = glb::write_chunks(parts, CHUNK_LIMIT);
	let mut manifest = format!("--!strict\n-- Generated by modelkit --chunks for {name}: one entry per uploaded chunk,\n-- with two anchor parts and where their middles stand (studs, Y up).\nreturn {{\n");
	for (n, chunk) in chunks.iter().enumerate() {
		if chunk.glb.len() > CHUNK_LIMIT {
			return Err(format!("chunk {} is {} bytes even alone; a single part is over the upload limit", n + 1, chunk.glb.len()));
		}
		let file = format!("{name}_{tag}{:02}.glb", n + 1);
		std::fs::write(out.join(&file), &chunk.glb).map_err(|e| e.to_string())?;
		let anchors: Vec<String> = chunk
			.anchors
			.iter()
			.map(|(part, p)| format!("{{ name = \"{part}\", position = Vector3.new({}, {}, {}) }}", p[0], p[1], p[2]))
			.collect();
		manifest.push_str(&format!(
			"\t{{ key = \"{name}{tag}{:02}\", file = \"{file}\", parts = {}, anchors = {{ {} }} }},\n",
			n + 1,
			chunk.parts,
			anchors.join(", ")
		));
		progress::say(&format!("chunk {file}: {} parts, {:.1} MB", chunk.parts, chunk.glb.len() as f64 / 1e6));
	}
	manifest.push_str("}\n");
	std::fs::write(out.join(format!("{name}Chunks.luau")), manifest).map_err(|e| e.to_string())?;
	Ok(())
}

// A flag's INDEX/COUNT value, or None when the flag isn't given.
fn share_flag(args: &[String], flag: &str) -> Option<(usize, usize)> {
	let at = args.iter().position(|a| a == flag)?;
	let parsed = args.get(at + 1).and_then(|s| s.split_once('/')).and_then(|(i, n)| Some((i.parse::<usize>().ok()?, n.parse::<usize>().ok()?)));
	match parsed {
		Some((index, count)) if index >= 1 && index <= count => Some((index, count)),
		_ => {
			eprintln!("error: {flag} needs INDEX/COUNT with 1 <= INDEX <= COUNT, like 3/8");
			std::process::exit(2);
		}
	}
}

fn main() {
	let args: Vec<String> = std::env::args().skip(1).collect();
	let Some(dir) = args.first() else {
		eprintln!("usage: modelkit <model folder> [--turntable FRAMES] [--size PIXELS] [--closeup X,Y,Z,RADIUS,SPIN]... [--eye EX,EY,EZ,TX,TY,TZ]... [--clip NAME] [--parts] [--view SIDE]... [--grid STUDS] [--chunks] [--shard INDEX/COUNT] [--renders INDEX/COUNT] [--share-bakes] [--work-port PORT]");
		std::process::exit(2);
	};
	let turntable = match args.iter().position(|a| a == "--turntable") {
		Some(at) => args.get(at + 1).and_then(|n| n.parse().ok()).unwrap_or(48),
		None => 0,
	};
	let size = match args.iter().position(|a| a == "--size") {
		Some(at) => args.get(at + 1).and_then(|n| n.parse().ok()).unwrap_or(DEFAULT_PREVIEW_SIZE),
		None => DEFAULT_PREVIEW_SIZE,
	};
	let mut closeups = Vec::new();
	for (at, _) in args.iter().enumerate().filter(|(_, a)| *a == "--closeup") {
		let numbers: Vec<f64> = args.get(at + 1).map_or(vec![], |list| list.split(',').filter_map(|n| n.parse().ok()).collect());
		let [x, y, z, radius, spin] = numbers[..] else {
			eprintln!("--closeup takes X,Y,Z,RADIUS,SPIN");
			std::process::exit(2);
		};
		closeups.push((x, y, z, radius, spin));
	}
	let mut eyes = Vec::new();
	for (at, _) in args.iter().enumerate().filter(|(_, a)| *a == "--eye") {
		let numbers: Vec<f64> = args.get(at + 1).map_or(vec![], |list| list.split(',').filter_map(|n| n.parse().ok()).collect());
		let [ex, ey, ez, tx, ty, tz] = numbers[..] else {
			eprintln!("--eye takes EX,EY,EZ,TX,TY,TZ");
			std::process::exit(2);
		};
		eyes.push(([ex, ey, ez], [tx, ty, tz]));
	}
	let clip = args.iter().position(|a| a == "--clip").and_then(|at| args.get(at + 1));
	// --preview builds texels at half the density, for quick looks, and with
	// --eye bakes far parts at less detail still.
	let preview = args.iter().any(|a| a == "--preview");
	// --max-detail raises the density so far that every part's texture hits
	// the 1024 cap, for previews judged up close on the build machines.
	let max_detail = args.iter().any(|a| a == "--max-detail");
	let texel_scale = if max_detail { 64.0 } else if preview { 0.5 } else { 1.0 };
	let detail_eyes = if preview { eyes.clone() } else { Vec::new() };
	let chunks = args.iter().any(|a| a == "--chunks");
	let shard = share_flag(&args, "--shard");
	let mut sides = Vec::new();
	for (at, _) in args.iter().enumerate().filter(|(_, a)| *a == "--view") {
		let Some(side) = args.get(at + 1).and_then(|name| render::Side::parse(name)) else {
			eprintln!("--view takes front, back, left, right, top or bottom");
			std::process::exit(2);
		};
		sides.push(side);
	}
	let grid = args.iter().position(|a| a == "--grid").and_then(|at| args.get(at + 1)).and_then(|n| n.parse().ok()).filter(|&n: &f64| n > 0.0);
	let share = share_flag(&args, "--renders");
	if args.iter().any(|a| a == "--share-bakes") {
		cache::set_sharing();
	}
	let work_port = args.iter().position(|a| a == "--work-port").and_then(|at| args.get(at + 1)).and_then(|p| p.parse().ok());
	let review = Review { parts: args.iter().any(|a| a == "--parts"), sides, grid, share, work_port };
	if let Err(error) = run(Path::new(dir), turntable, size, &closeups, &eyes, clip.map(|c| c.as_str()), texel_scale, &detail_eyes, chunks, shard, &review) {
		eprintln!("error: {error}");
		std::process::exit(1);
	}
}

