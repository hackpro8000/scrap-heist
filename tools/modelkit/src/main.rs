// modelkit: builds a Scrap Heist model from its Luau script.
//
//   modelkit art/models/StarterWeapon            build <Name>.glb and preview.png
//   modelkit art/models/StarterWeapon --turntable 48
//                                                also write turntable frames
//   modelkit art/models/StarterWeapon --size 2048
//                                                render previews at 2048px square
//
// The script (model.luau) builds meshes and paints textures through the API
// below; this engine does the heavy, generic work (triangulating, export,
// rendering) so scripts change without a recompile.

mod bake;
mod cache;
mod glb;
mod image;
mod mesh;
mod render;

use std::cell::RefCell;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::rc::Rc;
use std::time::Instant;

use mlua::{AnyUserData, Lua, Table, UserData, UserDataMethods, Value};

use image::Image;
use mesh::{Face, Mesh};

const DEFAULT_PREVIEW_SIZE: usize = 768;

#[derive(Clone)]
struct MeshHandle(Rc<RefCell<Mesh>>);

#[derive(Clone)]
struct ImageHandle(Rc<RefCell<Image>>);

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
		// Lays every face out in UV space, packed with a margin between charts.
		methods.add_method("unwrap", |_, this, margin: Option<f64>| {
			Ok(bake::unwrap(&mut this.0.borrow_mut(), margin.unwrap_or(0.01)))
		});
		// Paints each texel the color fn(x, y, z, nx, ny, nz) returns for the
		// surface point behind it, averaged over a 2×2 grid of points per texel
		// so stripes and edges come out anti-aliased.
		methods.add_method("paint", |_, this, (image, color): (AnyUserData, mlua::Function)| {
			let image = image.borrow::<ImageHandle>()?.0.clone();
			let (width, height) = {
				let image = image.borrow();
				(image.width, image.height)
			};
			let samples = bake::samples(&this.0.borrow(), width, height, 2);
			let mut sums = vec![[0.0f32; 4]; width * height];
			for t in &samples {
				let [x, y, z] = t.position;
				let [nx, ny, nz] = t.normal;
				let (r, g, b) = color.call::<(f32, f32, f32)>((x, y, z, nx, ny, nz))?;
				let sum = &mut sums[t.pixel];
				*sum = [sum[0] + r, sum[1] + g, sum[2] + b, sum[3] + 1.0];
			}
			let mut image = image.borrow_mut();
			let mut covered = vec![false; width * height];
			for (pixel, [r, g, b, n]) in sums.into_iter().enumerate() {
				if n > 0.0 {
					image.pixels[pixel] = [r / n, g / n, b / n];
					covered[pixel] = true;
				}
			}
			bake::dilate(&mut image.pixels, &mut covered, width, height, 8);
			Ok(())
		});
		// Paints edge highlights and contact shadows over the base colors.
		methods.add_method("paintShading", |_, this, (image, options): (AnyUserData, Option<Table>)| {
			let get = |key: &str, default: f64| -> mlua::Result<f64> {
				Ok(options.as_ref().map(|o| o.get::<Option<f64>>(key)).transpose()?.flatten().unwrap_or(default))
			};
			let shading = bake::Shading {
				highlight: get("highlight", 0.7)?,
				shadow: get("shadow", 0.75)?,
				bands: get("bands", 0.0)? as usize,
				sharp: get("sharp", 30.0)?,
				blend: get("blend", 0.0)?.clamp(0.0, 1.0),
				gradient: get("gradient", 0.0)?.clamp(0.0, 1.0),
			};
			let mut occluders = Vec::new();
			if let Some(list) = options.as_ref().map(|o| o.get::<Option<Vec<AnyUserData>>>("occluders")).transpose()?.flatten() {
				for handle in list {
					occluders.push(handle.borrow::<MeshHandle>()?.0.clone());
				}
			}
			let borrowed: Vec<_> = occluders.iter().map(|m| m.borrow()).collect();
			let refs: Vec<&Mesh> = borrowed.iter().map(|m| &**m).collect();
			let image = image.borrow::<ImageHandle>()?.0.clone();
			bake::paint_shading(&this.0.borrow(), &refs, &mut image.borrow_mut(), &shading);
			Ok(())
		});
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

fn install_api(lua: &Lua, dir: &Path, parts: Rc<RefCell<Vec<Part>>>, bones: Rc<RefCell<Vec<Bone>>>, used: Rc<RefCell<Vec<PathBuf>>>, search: Vec<PathBuf>) -> mlua::Result<()> {
	let globals = lua.globals();

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
	model_api.set(
		"cached",
		lua.create_function(move |lua, (key, build): (String, mlua::Function)| {
			let path = cache::path(&folder, &key);
			used.borrow_mut().push(path.clone());
			if let Some(saved) = cache::load(&path) {
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
			let list: Table = build.call(())?;
			let mut built = Vec::new();
			for entry in list.sequence_values::<Table>() {
				let entry = entry?;
				let mesh = entry.get::<AnyUserData>("mesh")?.borrow::<MeshHandle>()?.0.clone();
				let image = entry.get::<AnyUserData>("image")?.borrow::<ImageHandle>()?.0.clone();
				built.push((entry.get::<String>("name")?, entry.get::<Option<bool>>("preview")?.unwrap_or(true), entry.get::<Option<f32>>("emissive")?.unwrap_or(0.0), mesh, image));
			}
			let borrowed: Vec<_> = built.iter().map(|(n, p, e, m, i)| (n.clone(), *p, *e, m.borrow(), i.borrow())).collect();
			let refs: Vec<_> = borrowed.iter().map(|(n, p, e, m, i)| (n.clone(), *p, *e, &**m, &**i)).collect();
			cache::save(&path, &refs).map_err(mlua::Error::external)?;
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
	std::fs::write(path, image::encode_rgb(size, size, data))
}

// A close-up: focus point x, y, z, framing radius, and camera spin in degrees.
type Closeup = (f64, f64, f64, f64, f64);

fn run(dir: &Path, turntable: usize, size: usize, closeups: &[Closeup]) -> Result<(), String> {
	let started = Instant::now();
	let name = dir.file_name().and_then(|n| n.to_str()).ok_or("bad model folder")?.to_string();
	let script = dir.join("model.luau");
	let source = std::fs::read_to_string(&script).map_err(|e| format!("{}: {e}", script.display()))?;
	let library = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("lib");

	let lua = Lua::new();
	lua.enable_jit(true);
	let parts = Rc::new(RefCell::new(Vec::new()));
	let bones = Rc::new(RefCell::new(Vec::new()));
	let used = Rc::new(RefCell::new(Vec::new()));
	install_api(&lua, dir, parts.clone(), bones.clone(), used.clone(), vec![dir.to_path_buf(), library]).map_err(|e| e.to_string())?;
	lua.load(source).set_name(format!("@{}", script.display())).exec().map_err(|e| e.to_string())?;
	cache::prune(dir, &used.borrow());
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
	let glb = dir.join(format!("{name}.glb"));
	std::fs::write(&glb, glb::write(&parts, &bones)).map_err(|e| e.to_string())?;
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
	let preview = render::render(&shown, &render::View { size, spin: 0.0, focus: None });
	write_png(&dir.join("preview.png"), size, &preview).map_err(|e| e.to_string())?;

	if turntable > 0 {
		let frames = dir.join("turntable");
		std::fs::create_dir_all(&frames).map_err(|e| e.to_string())?;
		for frame in 0..turntable {
			let spin = frame as f64 / turntable as f64 * std::f64::consts::TAU;
			let data = render::render(&shown, &render::View { size, spin, focus: None });
			write_png(&frames.join(format!("{frame:04}.png")), size, &data).map_err(|e| e.to_string())?;
		}
	}
	for (n, &(x, y, z, radius, degrees)) in closeups.iter().enumerate() {
		let focus = Some(([x, y, z], radius));
		let data = render::render(&shown, &render::View { size, spin: degrees.to_radians(), focus });
		write_png(&dir.join(format!("closeup_{}.png", n + 1)), size, &data).map_err(|e| e.to_string())?;
	}
	eprintln!("{name}: {} parts, script {:.2?}, total {:.2?}", parts.len(), scripted, started.elapsed());
	Ok(())
}

fn main() {
	let args: Vec<String> = std::env::args().skip(1).collect();
	let Some(dir) = args.first() else {
		eprintln!("usage: modelkit <model folder> [--turntable FRAMES] [--size PIXELS] [--closeup X,Y,Z,RADIUS,SPIN]...");
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
	if let Err(error) = run(Path::new(dir), turntable, size, &closeups) {
		eprintln!("error: {error}");
		std::process::exit(1);
	}
}
