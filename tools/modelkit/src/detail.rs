// Eye-preview detail: before a part is shaded, its texture shrinks to what
// the nearest eye that sees it can resolve, so far and hidden parts bake in a
// fraction of the time. Only previews with --eye use it.

use std::cell::Cell;

use crate::image::Image;
use crate::mesh::{add, cross, dot, scale, sub, Mesh, Vec3};
use crate::render;

// Least share of a texture's width an eye preview keeps, however far it is.
const MIN_SHARE: f64 = 1.0 / 16.0;
// A part keeps at most this many texels per pixel it covers in the eye
// that sees most of it, so a big part near one eye isn't baked sharp all over.
const TEXELS_PER_PIXEL: f64 = 2.0;
// A shrunk texture keeps at least this many texels on its shorter side.
const MIN_SIDE: usize = 4;

pub struct PreviewDetail {
	// Eye and target of each preview camera.
	pub eyes: Vec<(Vec3, Vec3)>,
	// Preview picture size in pixels.
	pub size: usize,
	// While place() builds a model at the origin: where the layout puts it,
	// as an offset and a turn about z.
	pub placing: Cell<Option<(Vec3, f64)>>,
}

impl PreviewDetail {
	// Distance from the nearest eye that sees the ball, or None.
	fn nearest(&self, centre: Vec3, radius: f64) -> Option<f64> {
		let distance = |(eye, _): &(Vec3, Vec3)| {
			let offset = sub(centre, *eye);
			(dot(offset, offset).sqrt() - radius).max(1.0)
		};
		let seen = self.eyes.iter().filter(|(eye, target)| render::in_view(*eye, *target, centre, radius));
		seen.map(distance).reduce(f64::min)
	}

	// How far the nearest eye that sees the point stands, rounded down to a
	// power of two, or "unseen": props placed in one band can share a build.
	pub fn band(&self, point: Vec3) -> String {
		match self.nearest(point, 0.0) {
			Some(distance) => format!("{}", 2f64.powf(distance.log2().floor())),
			None => "unseen".to_string(),
		}
	}

	// Shrinks `image` by halves to what the nearest eye that sees `mesh` can
	// resolve, and returns how many times coarser than painted its texels are.
	// Shrinking again does nothing, so painting and shading can both call it.
	pub fn shrink(&self, mesh: &Mesh, image: &mut Image) -> f64 {
		// Texels per stud and in all as painted, before any earlier shrink.
		let painted = texel_density(mesh, image) * image.coarse;
		let painted_texels = painted * painted * surface_area(mesh);
		let share = match self.view(mesh) {
			Some(_) if painted <= 0.0 => 1.0,
			Some(view) => {
				let resolved = render::texels_resolved(view.nearest, self.size) / painted;
				let budget = (TEXELS_PER_PIXEL * view.pixels / painted_texels).sqrt();
				resolved.min(budget)
			}
			None => MIN_SHARE,
		};
		while 0.5 / image.coarse >= share.max(MIN_SHARE) && image.width.min(image.height) >= MIN_SIDE * 2 {
			*image = image.half();
		}
		image.coarse
	}

	// How the eyes see the mesh, or None when none does. Per triangle, so a
	// big floor chunk that runs up to one eye but is mostly far or off frame
	// isn't judged by its bounding ball alone.
	fn view(&self, mesh: &Mesh) -> Option<View> {
		let mut nearest: Option<f64> = None;
		let mut pixels = vec![0.0; self.eyes.len()];
		for face in &mesh.faces {
			for k in 1..face.verts.len() - 1 {
				let p = [0, k, k + 1].map(|i| self.placed(mesh.positions[face.verts[i]]));
				let centre = scale(add(add(p[0], p[1]), p[2]), 1.0 / 3.0);
				let radius = p.iter().map(|q| length(sub(*q, centre))).fold(0.0, f64::max);
				let n = cross(sub(p[1], p[0]), sub(p[2], p[0]));
				let area = length(n) / 2.0;
				for (index, (eye, target)) in self.eyes.iter().enumerate() {
					if !render::in_view(*eye, *target, centre, radius) {
						continue;
					}
					let offset = sub(*eye, centre);
					let distance = (length(offset) - radius).max(1.0);
					nearest = Some(nearest.map_or(distance, |d| d.min(distance)));
					// Its area as the eye sees it, in pixels.
					let facing = if area > 0.0 { (dot(n, offset) / (2.0 * area * length(offset))).abs() } else { 0.0 };
					// Measured from its middle, so a big triangle's far side isn't
					// counted as close as its nearest corner.
					let middle = length(offset).max(1.0);
					pixels[index] += area * facing * render::texels_resolved(middle, self.size).powi(2);
				}
			}
		}
		// No part covers more than the whole picture.
		let frame = (self.size * self.size) as f64;
		let pixels = pixels.into_iter().map(|p| p.min(frame)).fold(0.0, f64::max);
		nearest.map(|nearest| View { nearest, pixels })
	}

	// Where the layout puts a point of the model being placed.
	fn placed(&self, p: Vec3) -> Vec3 {
		let Some((offset, turn)) = self.placing.get() else {
			return p;
		};
		let (sin, cos) = turn.sin_cos();
		[p[0] * cos - p[1] * sin + offset[0], p[0] * sin + p[1] * cos + offset[1], p[2] + offset[2]]
	}
}

// What the eyes make of a mesh: the nearest any of them stands to a triangle
// it sees, and the most pixels it covers in any one picture.
struct View {
	nearest: f64,
	pixels: f64,
}

fn length(v: Vec3) -> f64 {
	dot(v, v).sqrt()
}

// Area of the mesh's unwrapped faces, in square studs.
fn surface_area(mesh: &Mesh) -> f64 {
	let mut area = 0.0;
	for face in mesh.faces.iter().filter(|face| face.uvs.is_some()) {
		for k in 1..face.verts.len() - 1 {
			let p = [0, k, k + 1].map(|i| mesh.positions[face.verts[i]]);
			area += length(cross(sub(p[1], p[0]), sub(p[2], p[0]))) / 2.0;
		}
	}
	area
}

// Texels per stud across the mesh's unwrapped faces; 0 when it has no UVs.
fn texel_density(mesh: &Mesh, image: &Image) -> f64 {
	let (mut texel_area, mut world_area) = (0.0, 0.0);
	for face in &mesh.faces {
		let Some(uvs) = &face.uvs else {
			continue;
		};
		for k in 1..face.verts.len() - 1 {
			let p = [0, k, k + 1].map(|i| mesh.positions[face.verts[i]]);
			let n = cross(sub(p[1], p[0]), sub(p[2], p[0]));
			world_area += dot(n, n).sqrt();
			let t = [0, k, k + 1].map(|i| [uvs[i][0] * image.width as f64, uvs[i][1] * image.height as f64]);
			texel_area += ((t[1][0] - t[0][0]) * (t[2][1] - t[0][1]) - (t[2][0] - t[0][0]) * (t[1][1] - t[0][1])).abs();
		}
	}
	if world_area > 1e-12 { (texel_area / world_area).sqrt() } else { 0.0 }
}
