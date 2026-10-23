// Cache: saved results of model.cached builds, so a layout reuses each placed
// prop's meshes and painted textures until its key changes. Files live in
// <model folder>/.cache, one per key, and a build deletes the ones it didn't
// use.

use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::path::{Path, PathBuf};

use crate::image::Image;
use crate::mesh::{Face, Mesh};

// Bump when the file layout or anything baked into it changes.
const VERSION: u32 = 1;

pub struct CachedPart {
	pub name: String,
	pub preview: bool,
	pub mesh: Mesh,
	pub image: Image,
}

pub fn path(dir: &Path, key: &str) -> PathBuf {
	let mut hasher = DefaultHasher::new();
	(VERSION, key).hash(&mut hasher);
	dir.join(".cache").join(format!("{:016x}.bin", hasher.finish()))
}

pub fn save(path: &Path, parts: &[(String, bool, &Mesh, &Image)]) -> std::io::Result<()> {
	let mut out = Vec::new();
	put_u32(&mut out, VERSION);
	put_u32(&mut out, parts.len() as u32);
	for (name, preview, mesh, image) in parts {
		put_u32(&mut out, name.len() as u32);
		out.extend(name.as_bytes());
		out.push(*preview as u8);
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
	std::fs::create_dir_all(path.parent().expect("cache folder"))?;
	std::fs::write(path, out)
}

// None when the file is missing, from another version or damaged.
pub fn load(path: &Path) -> Option<Vec<CachedPart>> {
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
		for pixel in image.pixels.iter_mut() {
			*pixel = [r.f32()?, r.f32()?, r.f32()?];
		}
		parts.push(CachedPart { name, preview, mesh, image });
	}
	(r.at == bytes.len()).then_some(parts)
}

// Deletes cache files this build didn't use.
pub fn prune(dir: &Path, used: &[PathBuf]) {
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
