// Cache: saved results of model.cached builds, so a layout reuses each placed
// prop's meshes and painted textures until its key changes. Files live in
// <model folder>/.cache, one per key, and a build deletes the ones it didn't
// use.

use crate::bake::CONTACT_REACH;
use std::cell::RefCell;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::path::{Path, PathBuf};
use std::rc::Rc;

use crate::image::Image;
use crate::mesh::{Face, Mesh};

// Bump when the file layout or anything baked into it changes.
const VERSION: u32 = 2;

pub struct CachedPart {
	pub name: String,
	pub preview: bool,
	pub emissive: f32,
	pub mesh: Mesh,
	pub image: Image,
}

// MODELKIT_NO_CACHE=1 builds as if nothing were cached and writes nothing,
// for timing a truly cold build without filling the disk.
pub fn disabled() -> bool {
	static DISABLED: std::sync::OnceLock<bool> = std::sync::OnceLock::new();
	*DISABLED.get_or_init(|| std::env::var("MODELKIT_NO_CACHE").is_ok_and(|v| v == "1"))
}

// --bake-only: this run only bakes paint layers for the build machines to
// swap (work.rs) and stops. Its parts are half-painted, so whole-part saves
// wait for the full run that follows.
static BAKE_ONLY: std::sync::OnceLock<()> = std::sync::OnceLock::new();

pub fn set_bake_only() {
	let _ = BAKE_ONLY.set(());
}

pub fn bake_only() -> bool {
	BAKE_ONLY.get().is_some()
}

// How many chunks a model's paints are grouped into for machines to claim.
pub const BAKE_CHUNKS: usize = 128;

// A part's chunk, decided from the part alone so identical parts land together.
pub fn bake_chunk(name: &str, mesh: &Mesh) -> usize {
	let mut hasher = DefaultHasher::new();
	name.hash(&mut hasher);
	hash_mesh(&mut hasher, mesh);
	hasher.finish() as usize % BAKE_CHUNKS
}

pub fn path(dir: &Path, key: &str) -> PathBuf {
	let mut hasher = DefaultHasher::new();
	(VERSION, key).hash(&mut hasher);
	dir.join(".cache").join(format!("{:016x}.bin", hasher.finish()))
}

pub fn save(path: &Path, parts: &[(String, bool, f32, &Mesh, &Image)]) -> std::io::Result<()> {
	if disabled() || bake_only() {
		return Ok(());
	}
	let mut out = Vec::new();
	put_u32(&mut out, VERSION);
	put_u32(&mut out, parts.len() as u32);
	for (name, preview, emissive, mesh, image) in parts {
		put_u32(&mut out, name.len() as u32);
		out.extend(name.as_bytes());
		out.push(*preview as u8);
		out.extend(emissive.to_le_bytes());
		put_f64(&mut out, mesh.smooth_angle);
		put_u32(&mut out, mesh.positions.len() as u32);
		for p in &mesh.positions {
			p.iter().for_each(|&c| put_f64(&mut out, c));
		}
		put_u32(&mut out, mesh.faces.len() as u32);
		for face in &mesh.faces {
			put_u32(&mut out, face.verts.len() as u32);
			face.verts.iter().for_each(|&v| put_u32(&mut out, v as u32));
			out.push(face.uvs.is_some() as u8);
			for uv in face.uvs.iter().flatten() {
				uv.iter().for_each(|&c| put_f64(&mut out, c));
			}
		}
		put_u32(&mut out, image.width as u32);
		put_u32(&mut out, image.height as u32);
		for pixel in &image.pixels {
			pixel.iter().for_each(|&c| out.extend(c.to_le_bytes()));
		}
	}
	// Alpha follows all the parts, and only when some part has it, so files
	// for solid parts stay as they were and older caches still load.
	if parts.iter().any(|(_, _, _, _, image)| image.alpha.is_some()) {
		for (_, _, _, _, image) in parts {
			out.push(image.alpha.is_some() as u8);
			for &a in image.alpha.iter().flatten() {
				out.extend(a.to_le_bytes());
			}
		}
	}
	std::fs::create_dir_all(path.parent().expect("cache folder"))?;
	std::fs::write(path, out)
}

// None when the file is missing, from another version or damaged.
pub fn load(path: &Path) -> Option<Vec<CachedPart>> {
	if disabled() {
		return None;
	}
	let bytes = std::fs::read(path).ok()?;
	let mut r = Reader { bytes: &bytes, at: 0 };
	if r.u32()? != VERSION {
		return None;
	}
	let mut parts = Vec::new();
	for _ in 0..r.u32()? {
		let length = r.u32()? as usize;
		let name = String::from_utf8(r.take(length)?.to_vec()).ok()?;
		let preview = r.take(1)?[0] != 0;
		let emissive = r.f32()?;
		let mut mesh = Mesh::new();
		mesh.smooth_angle = r.f64()?;
		for _ in 0..r.u32()? {
			mesh.positions.push([r.f64()?, r.f64()?, r.f64()?]);
		}
		for _ in 0..r.u32()? {
			let count = r.u32()? as usize;
			let verts = (0..count).map(|_| r.u32().map(|v| v as usize)).collect::<Option<Vec<_>>>()?;
			let uvs = if r.take(1)?[0] != 0 { Some((0..count).map(|_| Some([r.f64()?, r.f64()?])).collect::<Option<Vec<_>>>()?) } else { None };
			mesh.faces.push(Face { verts, uvs });
		}
		let (width, height) = (r.u32()? as usize, r.u32()? as usize);
		let mut image = Image::new(width, height, [0.0; 3]);
		let raw = r.take(width * height * 12)?;
		for (pixel, bytes) in image.pixels.iter_mut().zip(raw.chunks_exact(12)) {
			*pixel = std::array::from_fn(|k| f32::from_le_bytes(bytes[k * 4..k * 4 + 4].try_into().unwrap()));
		}
		parts.push(CachedPart { name, preview, emissive, mesh, image });
	}
	if r.at < bytes.len() {
		for part in &mut parts {
			if r.take(1)?[0] != 0 {
				let count = part.image.width * part.image.height;
				let raw = r.take(count * 4)?;
				part.image.alpha = Some(raw.chunks_exact(4).map(|b| f32::from_le_bytes(b.try_into().unwrap())).collect());
			}
		}
	}
	(r.at == bytes.len()).then_some(parts)
}

// Deletes cache files this build didn't use.
pub fn prune(dir: &Path, used: &[PathBuf]) {
	// Nothing was read, so nothing counts as used: keep the cache as it is.
	if disabled() {
		return;
	}
	let Ok(entries) = std::fs::read_dir(dir.join(".cache")) else { return };
	for entry in entries.flatten() {
		if !used.contains(&entry.path()) {
			let _ = std::fs::remove_file(entry.path());
		}
	}
}

fn put_u32(out: &mut Vec<u8>, value: u32) {
	out.extend(value.to_le_bytes());
}

fn put_f64(out: &mut Vec<u8>, value: f64) {
	out.extend(value.to_le_bytes());
}

struct Reader<'a> {
	bytes: &'a [u8],
	at: usize,
}

impl Reader<'_> {
	fn take(&mut self, count: usize) -> Option<&[u8]> {
		let slice = self.bytes.get(self.at..self.at + count)?;
		self.at += count;
		Some(slice)
	}

	fn u32(&mut self) -> Option<u32> {
		Some(u32::from_le_bytes(self.take(4)?.try_into().ok()?))
	}

	fn f32(&mut self) -> Option<f32> {
		Some(f32::from_le_bytes(self.take(4)?.try_into().ok()?))
	}

	fn f64(&mut self) -> Option<f64> {
		Some(f64::from_le_bytes(self.take(8)?.try_into().ok()?))
	}
}

thread_local! {
	// While a build runs, each part's painted texture is cached in the model's
	// folder: where the cache lives, and the build's list of used files.
	static PAINT_CACHE: RefCell<Option<(PathBuf, Rc<RefCell<Vec<PathBuf>>>)>> = const { RefCell::new(None) };
}

pub fn enable_paint_cache(dir: &Path, used: Rc<RefCell<Vec<PathBuf>>>) {
	PAINT_CACHE.with(|cell| *cell.borrow_mut() = Some((dir.to_path_buf(), used)));
}

// What a paint is keyed by beyond its geometry: a custom Lua paint fn has no
// code to hash, so it is keyed by `salt`, the item's source key. Without a salt
// a custom paint is not cached.
pub struct Source {
	pub custom: bool,
	pub salt: Option<String>,
}

// Where one layer of a part's paint is cached, keyed by what that layer reads:
// the part's geometry, the parts in reach when `reach`, the layer's settings in
// `numbers`, the colour it starts from when `colour`, and the paint source.
// None when caching is off, or a custom paint has no salt.
pub fn layer_path(kind: &str, mesh: &Mesh, occluders: &[&Mesh], reach: bool, numbers: &[f64], colour: Option<&Image>, source: &Source) -> Option<PathBuf> {
	PAINT_CACHE.with(|cell| {
		let state = cell.borrow();
		let (dir, used) = state.as_ref()?;
		if source.custom && source.salt.is_none() {
			return None;
		}
		let mut hasher = DefaultHasher::new();
		kind.hash(&mut hasher);
		hash_mesh(&mut hasher, mesh);
		if reach {
			for other in occluders.iter().filter(|other| crate::bake::within_reach(mesh, other, CONTACT_REACH)) {
				hash_mesh(&mut hasher, other);
			}
		}
		numbers.iter().for_each(|n| n.to_bits().hash(&mut hasher));
		if let Some(image) = colour {
			(image.width, image.height).hash(&mut hasher);
			for pixel in &image.pixels {
				pixel.iter().for_each(|c| c.to_bits().hash(&mut hasher));
			}
		}
		(source.custom, &source.salt).hash(&mut hasher);
		let path = path(dir, &format!("{kind} {:016x}", hasher.finish()));
		used.borrow_mut().push(path.clone());
		Some(path)
	})
}

fn hash_mesh(hasher: &mut DefaultHasher, mesh: &Mesh) {
	mesh.smooth_angle.to_bits().hash(hasher);
	for p in &mesh.positions {
		p.iter().for_each(|c| c.to_bits().hash(hasher));
	}
	for face in &mesh.faces {
		face.verts.hash(hasher);
		face.uvs.is_some().hash(hasher);
		for uv in face.uvs.iter().flatten() {
			uv.iter().for_each(|c| c.to_bits().hash(hasher));
		}
	}
}

// Saves a layer's images, one after another.
pub fn save_layers(path: &Path, images: &[&Image]) -> std::io::Result<()> {
	if disabled() {
		return Ok(());
	}
	let mut out = Vec::new();
	put_u32(&mut out, VERSION);
	put_u32(&mut out, images.len() as u32);
	for image in images {
		put_u32(&mut out, image.width as u32);
		put_u32(&mut out, image.height as u32);
		for pixel in &image.pixels {
			pixel.iter().for_each(|&c| out.extend(c.to_le_bytes()));
		}
	}
	std::fs::create_dir_all(path.parent().expect("cache folder"))?;
	std::fs::write(path, out)
}

// None when the file is missing, from another version or damaged.
pub fn load_layers(path: &Path) -> Option<Vec<Image>> {
	if disabled() {
		return None;
	}
	let bytes = std::fs::read(path).ok()?;
	let mut r = Reader { bytes: &bytes, at: 0 };
	if r.u32()? != VERSION {
		return None;
	}
	let mut images = Vec::new();
	for _ in 0..r.u32()? {
		let (width, height) = (r.u32()? as usize, r.u32()? as usize);
		let mut image = Image::new(width, height, [0.0; 3]);
		let raw = r.take(width * height * 12)?;
		for (pixel, bytes) in image.pixels.iter_mut().zip(raw.chunks_exact(12)) {
			*pixel = std::array::from_fn(|k| f32::from_le_bytes(bytes[k * 4..k * 4 + 4].try_into().unwrap()));
		}
		images.push(image);
	}
	(r.at == bytes.len()).then_some(images)
}
