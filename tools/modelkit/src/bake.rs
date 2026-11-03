// Bake: texture work done on a mesh's surface. Unwrapping lays the faces out
// in UV space; rasterizing finds the surface point behind every texel; the
// shading pass paints light-independent edge highlights and contact shadows
// on top of a script's base colors, like the old Blender paint_shading.

use std::collections::HashMap;
use std::hash::{BuildHasherDefault, Hasher};
use std::path::PathBuf;

use crate::cache;
use crate::coat;
use crate::gpu;
use crate::image::Image;
use crate::mesh::{add, cross, dot, normalize, scale, sub, Mesh, Vec3};

pub fn hash(mut x: u32) -> f64 {
	x ^= x >> 16;
	x = x.wrapping_mul(0x7feb_352d);
	x ^= x >> 15;
	x = x.wrapping_mul(0x846c_a68b);
	x ^= x >> 16;
	x as f64 / u32::MAX as f64
}

// --- Unwrap -----------------------------------------------------------------

// Shared edges between faces, keyed by their sorted vertex pair.
fn edge_faces(mesh: &Mesh) -> HashMap<(usize, usize), Vec<usize>> {
	let mut edges: HashMap<(usize, usize), Vec<usize>> = HashMap::new();
	for (index, face) in mesh.faces.iter().enumerate() {
		for (k, &a) in face.verts.iter().enumerate() {
			let b = face.verts[(k + 1) % face.verts.len()];
			edges.entry((a.min(b), a.max(b))).or_default().push(index);
		}
	}
	edges
}

// Box-projection unwrap: faces are grouped by the axis they face most, each
// connected group is projected flat onto that axis' plane, and the groups are
// packed into the unit square with `margin` between them.
// Returns the scale from studs to UV units, so callers can size textures
// for a texel density.
pub fn unwrap(mesh: &mut Mesh, margin: f64) -> f64 {
	let normals: Vec<Vec3> = mesh.faces.iter().map(|face| mesh.face_normal(face)).collect();
	let side: Vec<usize> = normals
		.iter()
		.map(|n| {
			let axis = (0..3).max_by(|&a, &b| n[a].abs().total_cmp(&n[b].abs())).unwrap();
			axis * 2 + (n[axis] < 0.0) as usize
		})
		.collect();
	let edges = edge_faces(mesh);
	let mut neighbours: Vec<Vec<usize>> = vec![Vec::new(); mesh.faces.len()];
	for faces in edges.values() {
		for &a in faces {
			for &b in faces {
				if a != b && side[a] == side[b] {
					neighbours[a].push(b);
				}
			}
		}
	}

	// Flood-fill charts, then project each one onto its plane.
	let mut chart_of = vec![usize::MAX; mesh.faces.len()];
	let mut charts: Vec<Vec<usize>> = Vec::new();
	for start in 0..mesh.faces.len() {
		if chart_of[start] != usize::MAX {
			continue;
		}
		let mut members = vec![start];
		chart_of[start] = charts.len();
		let mut next = 0;
		while next < members.len() {
			for &other in &neighbours[members[next]] {
				if chart_of[other] == usize::MAX {
					chart_of[other] = charts.len();
					members.push(other);
				}
			}
			next += 1;
		}
		charts.push(members);
	}
	let flat = |side: usize, p: Vec3| -> [f64; 2] {
		match side {
			0 => [p[1], p[2]],
			1 => [-p[1], p[2]],
			2 => [-p[0], p[2]],
			3 => [p[0], p[2]],
			4 => [p[0], p[1]],
			_ => [p[0], -p[1]],
		}
	};
	let mut boxes: Vec<([f64; 2], [f64; 2])> = Vec::new();
	for members in &charts {
		let mut low = [f64::MAX; 2];
		let mut high = [f64::MIN; 2];
		for &face in members {
			for &vert in &mesh.faces[face].verts {
				let q = flat(side[face], mesh.positions[vert]);
				for k in 0..2 {
					low[k] = low[k].min(q[k]);
					high[k] = high[k].max(q[k]);
				}
			}
		}
		boxes.push((low, [high[0] - low[0], high[1] - low[1]]));
	}

	// Shelf pack, tallest first, shrinking until everything fits.
	let mut order: Vec<usize> = (0..charts.len()).collect();
	order.sort_by(|&a, &b| boxes[b].1[1].total_cmp(&boxes[a].1[1]));
	let area: f64 = boxes.iter().map(|(_, size)| (size[0] + 1e-6) * (size[1] + 1e-6)).sum();
	let mut fit = (0.9 / area).sqrt();
	let mut offsets = vec![[0.0; 2]; charts.len()];
	loop {
		let (mut x, mut y, mut row) = (margin, margin, 0.0f64);
		let mut fits = true;
		for &chart in &order {
			let [w, h] = boxes[chart].1.map(|s| s * fit);
			if x + w + margin > 1.0 && x > margin {
				x = margin;
				y += row + margin;
				row = 0.0;
			}
			offsets[chart] = [x, y];
			x += w + margin;
			row = row.max(h);
			fits &= x <= 1.0 + 1e-9;
		}
		if fits && y + row + margin <= 1.0 {
			break;
		}
		fit *= 0.97;
	}
	for (index, face) in mesh.faces.iter_mut().enumerate() {
		let chart = chart_of[index];
		let (low, _) = boxes[chart];
		let offset = offsets[chart];
		let uvs = face
			.verts
			.iter()
			.map(|&vert| {
				let q = flat(side[index], mesh.positions[vert]);
				[offset[0] + (q[0] - low[0]) * fit, offset[1] + (q[1] - low[1]) * fit]
			})
			.collect();
		face.uvs = Some(uvs);
	}
	fit
}

// --- Rasterize --------------------------------------------------------------

// The surface point painted by one texel.
#[derive(Clone, Copy)]
pub struct Texel {
	pub pixel: usize,
	pub position: Vec3,
	pub normal: Vec3,
	pub face_normal: Vec3,
}

pub fn texels(mesh: &Mesh, width: usize, height: usize) -> Vec<Texel> {
	samples(mesh, width, height, 1)
}

// Like texels, but tests a grid × grid pattern of points inside each pixel, so
// a pixel can come back several times, once per covered sample.
pub fn samples(mesh: &Mesh, width: usize, height: usize, grid: usize) -> Vec<Texel> {
	let mut found = Vec::new();
	for corners in mesh.triangles() {
		let face_normal = normalize(cross(sub(corners[1].position, corners[0].position), sub(corners[2].position, corners[0].position)));
		let p = corners.map(|c| [c.uv[0] * width as f64 - 0.5, c.uv[1] * height as f64 - 0.5]);
		let area = (p[1][0] - p[0][0]) * (p[2][1] - p[0][1]) - (p[2][0] - p[0][0]) * (p[1][1] - p[0][1]);
		if area.abs() < 1e-12 {
			continue;
		}
		let x0 = p.iter().map(|q| q[0]).fold(f64::MAX, f64::min).floor().max(0.0) as usize;
		let x1 = (p.iter().map(|q| q[0]).fold(f64::MIN, f64::max).ceil() as usize).min(width - 1);
		let y0 = p.iter().map(|q| q[1]).fold(f64::MAX, f64::min).floor().max(0.0) as usize;
		let y1 = (p.iter().map(|q| q[1]).fold(f64::MIN, f64::max).ceil() as usize).min(height - 1);
		for y in y0..=y1 {
			for x in x0..=x1 {
			for sample in 0..grid * grid {
				let (fx, fy) = (
					x as f64 + ((sample % grid) as f64 + 0.5) / grid as f64 - 0.5,
					y as f64 + ((sample / grid) as f64 + 0.5) / grid as f64 - 0.5,
				);
				let w0 = ((p[1][0] - fx) * (p[2][1] - fy) - (p[2][0] - fx) * (p[1][1] - fy)) / area;
				let w1 = ((p[2][0] - fx) * (p[0][1] - fy) - (p[0][0] - fx) * (p[2][1] - fy)) / area;
				let w2 = 1.0 - w0 - w1;
				if w0 < -1e-6 || w1 < -1e-6 || w2 < -1e-6 {
					continue;
				}
				let blend = |f: &dyn Fn(usize) -> Vec3| add(add(scale(f(0), w0), scale(f(1), w1)), scale(f(2), w2));
				found.push(Texel {
					pixel: y * width + x,
					position: blend(&|k| corners[k].position),
					normal: normalize(blend(&|k| corners[k].normal)),
					face_normal,
				});
			}
			}
		}
	}
	found
}

// Spreads painted texels outward into unpainted ones so UV seams and mipmaps
// don't pull in background.
pub fn dilate(pixels: &mut [[f32; 3]], covered: &mut [bool], width: usize, height: usize, passes: usize) {
	let threads = std::thread::available_parallelism().map_or(4, |n| n.get());
	let rows = height.div_ceil(threads).max(1);
	for _ in 0..passes {
		let (before, colors) = (covered.to_vec(), pixels.to_vec());
		// Each thread fills its own band of rows, reading the previous pass.
		std::thread::scope(|scope| {
			for (band, (pixels, covered)) in pixels.chunks_mut(rows * width).zip(covered.chunks_mut(rows * width)).enumerate() {
				let (before, colors) = (&before, &colors);
				scope.spawn(move || {
					for (local, (pixel, done)) in pixels.iter_mut().zip(covered.iter_mut()).enumerate() {
						let at = band * rows * width + local;
						if before[at] {
							continue;
						}
						let (x, y) = ((at % width) as i64, (at / width) as i64);
						let mut sum = [0.0f32; 3];
						let mut count = 0.0;
						for (dx, dy) in [(-1i64, 0i64), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1), (-1, 1), (1, -1)] {
							let (nx, ny) = (x + dx, y + dy);
							if nx < 0 || ny < 0 || nx >= width as i64 || ny >= height as i64 {
								continue;
							}
							let neighbour = ny as usize * width + nx as usize;
							if before[neighbour] {
								for k in 0..3 {
									sum[k] += colors[neighbour][k];
								}
								count += 1.0;
							}
						}
						if count > 0.0 {
							*pixel = sum.map(|s| s / count);
							*done = true;
						}
					}
				});
			}
		});
	}
}

// Point of the triangle nearest p (Ericson, Real-Time Collision Detection 5.1.5).
fn closest_on_triangle(p: Vec3, [a, b, c]: [Vec3; 3]) -> Vec3 {
	let (ab, ac) = (sub(b, a), sub(c, a));
	let ap = sub(p, a);
	let (d1, d2) = (dot(ab, ap), dot(ac, ap));
	if d1 <= 0.0 && d2 <= 0.0 {
		return a;
	}
	let bp = sub(p, b);
	let (d3, d4) = (dot(ab, bp), dot(ac, bp));
	if d3 >= 0.0 && d4 <= d3 {
		return b;
	}
	let vc = d1 * d4 - d3 * d2;
	if vc <= 0.0 && d1 >= 0.0 && d3 <= 0.0 {
		return add(a, scale(ab, d1 / (d1 - d3)));
	}
	let cp = sub(p, c);
	let (d5, d6) = (dot(ab, cp), dot(ac, cp));
	if d6 >= 0.0 && d5 <= d6 {
		return c;
	}
	let vb = d5 * d2 - d1 * d6;
	if vb <= 0.0 && d2 >= 0.0 && d6 <= 0.0 {
		return add(a, scale(ac, d2 / (d2 - d6)));
	}
	let va = d3 * d6 - d5 * d4;
	if va <= 0.0 && d4 - d3 >= 0.0 && d5 - d6 >= 0.0 {
		return add(b, scale(sub(c, b), (d4 - d3) / ((d4 - d3) + (d5 - d6))));
	}
	let denom = 1.0 / (va + vb + vc);
	add(a, add(scale(ab, vb * denom), scale(ac, vc * denom)))
}

// The contact grid hashes millions of small integer cell keys; std's default
// hasher guards against crafted keys, which only slows that down.
#[derive(Default)]
struct CellHasher(u64);

impl Hasher for CellHasher {
	fn write(&mut self, bytes: &[u8]) {
		for chunk in bytes.chunks(8) {
			let mut word = [0u8; 8];
			word[..chunk.len()].copy_from_slice(chunk);
			self.0 = (self.0.rotate_left(5) ^ u64::from_le_bytes(word)).wrapping_mul(0x517c_c1b7_2722_0a95);
		}
	}

	fn finish(&self) -> u64 {
		self.0
	}
}

type CellMap<V> = HashMap<[i64; 3], V, BuildHasherDefault<CellHasher>>;

// Corner positions only, fanned the way Mesh::triangles fans each face, but
// without working out the smoothed normals nobody here reads.
pub fn mesh_triangles(mesh: &Mesh) -> Vec<[Vec3; 3]> {
	let at = |vert: usize| mesh.positions[vert];
	mesh.faces
		.iter()
		.flat_map(|face| (1..face.verts.len() - 1).map(move |k| [at(face.verts[0]), at(face.verts[k]), at(face.verts[k + 1])]))
		.collect()
}

// --- Shading ----------------------------------------------------------------

pub struct Shading {
	pub highlight: f64,
	pub shadow: f64,
	pub bands: usize,
	// 0-1: feathers highlight strokes and tints them toward a lighter base
	// color instead of cream, so they melt into the paint. 0 keeps the classic look.
	pub blend: f64,
	// Extra highlight strength reached at the bottom of each part, ramping
	// smoothly from none at the top (0.3 = 30% stronger at the bottom).
	pub highlight_ramp: f64,
	// How much wider the highlight brush is than the shadow brush, per stroke.
	pub highlight_width: f64,
	// Paints highlights as a few bold, fully loaded strokes along each edge
	// instead of dry bristly ones, for a hand-painted look.
	pub painted_highlights: bool,
	// Highlights run full width at a corner and thin toward the middle of an
	// edge, falling off over this many studs from the nearest corner. 0 keeps
	// them even along the whole edge.
	pub corner_taper: f64,
	// How far highlights and contact shadows reach from an edge, in studs.
	// Bigger stones want a wider band, the way a thicker brush reads on them.
	pub reach: f64,
	// The bottom and top the gradient, low wear and highlight ramp run
	// between, instead of the part's own. Chunks of one surface share it, so
	// a chunk with no height (all flat top) isn't painted as all bottom.
	pub height_range: Option<[f64; 2]>,
	// Strokes drawn over the coat, such as cracks.
	pub strokes: Vec<crate::brush::Stroke>,
}

// The thinnest a corner-tapered highlight gets, as a share of its full width.
const TAPER_MIN: f64 = 0.15;
// How far off a texel's plane a corner of the facing surface may sit and still
// count as a corner on the edge between them.
const TAPER_PLANE: f64 = 0.05;

// How wide a corner-tapered highlight runs at a texel: full at a corner of
// the edge, thinning toward TAPER_MIN as the nearest corner falls away. The
// corners are those of the facing triangle lying in the texel's plane, which
// for a polygon's edge are its two ends. `q` is the edge point nearest p.
fn corner_taper(p: Vec3, n: Vec3, q: Vec3, triangle: [Vec3; 3], taper: f64) -> f64 {
	let mut nearest = f64::MAX;
	for v in triangle {
		if dot(n, sub(v, p)).abs() < TAPER_PLANE {
			let gap = sub(v, q);
			nearest = nearest.min(dot(gap, gap).sqrt());
		}
	}
	TAPER_MIN + (1.0 - TAPER_MIN) * (-nearest / taper).exp()
}

// How far a contact shadow spreads from the corner that casts it, unless the
// part asks for its own reach.
pub const CONTACT_REACH: f64 = 0.2;
// Folds gentler than this (as a fraction of a half turn) cast nothing,
// so the facets inside a rounded hollow stay clean.
const CONTACT_MIN_FOLD: f64 = 1.0 / 6.0;

// Brush passes: (width, length, step, pressure).
const BRUSH_PASSES: [(f64, f64, f64, f64); 2] = [(0.16, 0.6, 0.4, 0.75), (0.08, 0.35, 0.22, 1.0)];
const BRISTLES: f64 = 14.0;

// Coverage of bold painted strokes along one edge, at distance d from it and
// t studs along it: long, fully loaded strokes with blunt ends, a wobbling
// rim and their own widths, overlapping like a hand-painted highlight.
fn painted_strokes(edge: usize, t: f64, d: f64, wide: f64) -> f64 {
	let (width, stroke, step) = (BRUSH_PASSES[0].0 * wide, 1.4, 0.8);
	let mut paint = 0.0f64;
	let first = (t / step).floor() as i64;
	for i in first - (stroke / step).ceil() as i64 - 1..=first {
		let seed = (edge as u32).wrapping_mul(7919).wrapping_add((i as u32).wrapping_mul(131)).wrapping_add(4111);
		let r = |k: u32| hash(seed.wrapping_mul(16).wrapping_add(k));
		let start = i as f64 * step + (r(0) - 0.5) * step;
		let span = stroke * (0.7 + 0.6 * r(1));
		let u = (t - start) / span;
		if !(0.0..=1.0).contains(&u) {
			continue;
		}
		let taper = (std::f64::consts::PI * u).sin().max(0.0).powf(0.3);
		let wobble = 1.0 + 0.18 * (t * 6.0 + r(4) * 6.283).sin();
		let half = width * (0.45 + 0.75 * r(2)) * taper * wobble;
		let centre = width * 0.25 * r(3);
		let s = (d - centre) / half.max(1e-6);
		if s.abs() >= 1.0 {
			continue;
		}
		let rim = ((1.0 - s.abs()) / 0.12).clamp(0.0, 1.0);
		let alpha = rim * (0.8 + 0.2 * r(5));
		paint = paint.max(alpha);
	}
	paint
}

// Coverage of overlapping brush strokes laid along one edge, at distance d
// from it and t studs along it.
fn brush_strokes(edge: usize, t: f64, length: f64, d: f64, wide: f64) -> f64 {
	let mut paint = 0.0f64;
	for (pass, &(width, stroke, step, strength)) in BRUSH_PASSES.iter().enumerate() {
		let first = (t / step).floor() as i64;
		for i in first - (stroke / step).ceil() as i64 - 1..=first {
			let seed = (edge as u32).wrapping_mul(7919).wrapping_add((i as u32).wrapping_mul(131)).wrapping_add(pass as u32 * 977);
			let r = |k: u32| hash(seed.wrapping_mul(16).wrapping_add(k));
			let start = i as f64 * step + (r(0) - 0.5) * step;
			let span = stroke * (0.6 + 0.8 * r(1));
			let u = (t - start) / span;
			if !(0.0..=1.0).contains(&u) || start + span < 0.0 || start > length {
				continue;
			}
			// Loaded at the start, tapering and running dry toward the end.
			let taper = (std::f64::consts::PI * u.powf(0.7)).sin().max(0.0).sqrt();
			let half = width * wide * (0.5 + 0.6 * r(2)) * taper;
			let centre = width * 0.5 * r(3);
			let s = (d - centre) / half.max(1e-6);
			if s.abs() >= 1.0 {
				continue;
			}
			let rim = ((1.0 - s.abs()) / 0.25).clamp(0.0, 1.0);
			// Bristle streaks across the stroke, each drying out at its own point.
			let bristle = ((s + 1.0) * 0.5 * BRISTLES).floor() as u32;
			let b = |k: u32| hash(seed.wrapping_mul(97).wrapping_add(bristle * 13 + k));
			let load = 0.55 + 0.45 * b(0);
			let dry = 0.55 + 0.45 * b(1) - 0.25 * (1.0 - r(4));
			let breakup = ((dry - u) / 0.12).clamp(0.0, 1.0);
			let pressure = strength * (0.6 + 0.4 * r(5)) * (1.0 - 0.4 * u);
			let alpha = rim * load * breakup * pressure;
			paint = 1.0 - (1.0 - paint) * (1.0 - alpha);
		}
	}
	paint
}


pub fn to_linear(c: f32) -> f64 {
	let c = c as f64;
	if c <= 0.04045 { c / 12.92 } else { ((c + 0.055) / 1.055).powf(2.4) }
}

fn to_srgb(c: f64) -> f32 {
	let c = c.clamp(0.0, 1.0);
	(if c <= 0.003_130_8 { c * 12.92 } else { 1.055 * c.powf(1.0 / 2.4) - 0.055 }) as f32
}

fn parallel<T: Send, F: Fn(&Texel) -> T + Sync>(texels: &[Texel], work: F) -> Vec<T> {
	let threads = std::thread::available_parallelism().map_or(4, |n| n.get());
	let chunk = texels.len().div_ceil(threads).max(1);
	std::thread::scope(|scope| {
		let handles: Vec<_> = texels.chunks(chunk).map(|part| scope.spawn(|| part.iter().map(&work).collect::<Vec<T>>())).collect();
		handles.into_iter().flat_map(|h| h.join().expect("bake thread")).collect()
	})
}

pub fn paint_shading(mesh: &Mesh, group: &[&Mesh], occluders: &[&Mesh], image: &mut Image, shading: &Shading, look: &coat::Look, base: &mut dyn FnMut(Vec3, Vec3) -> [f64; 3], source: &cache::Source) {
	let (width, height) = (image.width, image.height);
	let reach = shading.reach.max(0.02);
	let width_scale = shading.highlight_width.max(0.1);
	// Shadows and highlights both come from the corners a texel sits in: a
	// surface nearby that faces it makes an interior angle, which shades, and
	// one that faces away makes an exterior angle, which catches the light.
	// Either way the sharper the corner the stronger the paint, so rounded
	// facets stay clean. Only this part's own surfaces make exterior angles;
	// another part merely passing close by is not an edge of this one.
	// Only occluders close enough to reach this mesh can cast or catch anything.
	// The part's other chunks count as its own surfaces, so a chunk seam shades like
	// any other edge.
	let mut triangles = mesh_triangles(mesh);
	for other in group {
		if within_reach(mesh, other, reach) {
			triangles.extend(mesh_triangles(other));
		}
	}
	let own = triangles.len();
	for other in occluders {
		if within_reach(mesh, other, reach) {
			triangles.extend(mesh_triangles(other));
		}
	}
	// Texels only ever look within reach of this mesh, so surfaces
	// outside that box are dropped and big ones only fill the grid inside it.
	let (mesh_low, mesh_high) = bounds(mesh);
	let reach_low = mesh_low.map(|c| c - reach);
	let reach_high = mesh_high.map(|c| c + reach);
	let surfaces: Vec<([Vec3; 3], Vec3, bool)> = triangles
		.into_iter()
		.enumerate()
		.filter(|(_, t)| (0..3).all(|k| t[0][k].max(t[1][k]).max(t[2][k]) >= reach_low[k] && t[0][k].min(t[1][k]).min(t[2][k]) <= reach_high[k]))
		.filter_map(|(index, t)| {
			let n = cross(sub(t[1], t[0]), sub(t[2], t[0]));
			let length = dot(n, n).sqrt();
			(length > 1e-12).then(|| (t, scale(n, 1.0 / length), index < own))
		})
		.collect();
	let contact_key = |p: Vec3| p.map(|c| (c / reach).floor() as i64);
	// Dot products at or above this are folds gentler than CONTACT_MIN_FOLD.
	let min_cos = (CONTACT_MIN_FOLD * std::f64::consts::PI).cos();
	let mut contact_grid: CellMap<Vec<usize>> = CellMap::default();
	let (key_low, key_high) = (contact_key(reach_low), contact_key(reach_high));
	// A cell whose centre is further than this from a plane can't touch it.
	let cell_reach = reach * 3f64.sqrt() / 2.0;
	for (index, (t, facing, _)) in surfaces.iter().enumerate() {
		let low = contact_key([0, 1, 2].map(|k| t[0][k].min(t[1][k]).min(t[2][k])));
		let high = contact_key([0, 1, 2].map(|k| t[0][k].max(t[1][k]).max(t[2][k])));
		let low: [i64; 3] = std::array::from_fn(|k| low[k].max(key_low[k]));
		let high: [i64; 3] = std::array::from_fn(|k| high[k].min(key_high[k]));
		for x in low[0]..=high[0] {
			for y in low[1]..=high[1] {
				for z in low[2]..=high[2] {
					// A tilted triangle's box is mostly empty space; only the
					// cells its plane passes through can hold it.
					let centre = [x, y, z].map(|c| (c as f64 + 0.5) * reach);
					if dot(*facing, sub(centre, t[0])).abs() > cell_reach {
						continue;
					}
					contact_grid.entry([x, y, z]).or_default().push(index);
				}
			}
		}
	}
	// Paint laid along the corners at p, `outward` for exterior angles.
	// One pass over the surfaces near p: the strongest interior-angle paint, and
	// the strongest exterior-angle paint from this part's own surfaces.
	let crease_paint = |p: Vec3, n: Vec3| -> (f64, f64) {
		let home = contact_key(p);
		let (mut inward, mut outward) = (0.0f64, 0.0f64);
		for x in -1..=1 {
			for y in -1..=1 {
				for z in -1..=1 {
					for &index in contact_grid.get(&[home[0] + x, home[1] + y, home[2] + z]).into_iter().flatten() {
						let (triangle, facing, mine) = surfaces[index];
						// A fold gentler than CONTACT_MIN_FOLD casts nothing, so drop it before
						// any distance work.
						if dot(n, facing) >= min_cos {
							continue;
						}
						let offset = sub(p, closest_on_triangle(p, triangle));
						let distance = dot(offset, offset).sqrt();
						// An interior angle's surface faces the texel, so the texel sits in
						// front of its plane; an exterior angle's faces away, so behind it.
						let side = dot(facing, offset);
						let front = side > 0.0;
						let behind = side < 0.0 && mine;
						if distance < 1e-6 || distance >= reach || !(front || behind) || dot(n, offset) > 0.3 * distance {
							continue;
						}
						// 0 for a flat continuation, 1 for a right angle or anything sharper.
						let fold = dot(n, facing).clamp(-1.0, 1.0).acos() / std::f64::consts::PI;
						let sharpness = ((fold - CONTACT_MIN_FOLD) / (0.5 - CONTACT_MIN_FOLD)).clamp(0.0, 1.0);
						// Painted as brush strokes dragged along the crease. The crease is
						// seeded by both planes, so every triangle along it agrees on the strokes.
						let crease = normalize(cross(n, facing));
						let along = dot(p, crease) + 1000.0;
						let plane = |m: Vec3, at: Vec3| [m[0] * 8.0, m[1] * 8.0, m[2] * 8.0, dot(m, at) * 20.0].map(|c| c.round() as i64 as u32);
						let seed = plane(n, p).into_iter().chain(plane(facing, triangle[0])).fold(0x811c_9dc5u32, |h, c| (h ^ c).wrapping_mul(0x0100_0193));
						// Highlights are drawn with a wider brush than shadows: they
						// are the lit side of the corner, and read better as a broad
						// stroke than as a hairline.
						// A tapered highlight narrows both its strokes and the reach it
						// fades out over, so it really thins away from a corner.
						let taper = if behind && shading.corner_taper > 0.0 { corner_taper(p, n, sub(p, offset), triangle, shading.corner_taper) } else { 1.0 };
						let fade = reach * taper;
						if distance >= fade {
							continue;
						}
						let wide = if behind { width_scale * taper } else { 1.0 };
						let value = if behind && shading.painted_highlights {
							sharpness * painted_strokes(seed as usize, along, distance, wide)
						} else {
							sharpness * brush_strokes(seed as usize, along, f64::MAX, distance, wide) * (1.0 - distance / fade)
						};
						if front {
							inward = inward.max(value);
						}
						if behind {
							outward = outward.max(value);
						}
					}
				}
			}
		}
		(inward, outward)
	};

	let mut low = [f64::MAX; 3];
	let mut high = [f64::MIN; 3];
	for p in &mesh.positions {
		for k in 0..3 {
			low[k] = low[k].min(p[k]);
			high[k] = high[k].max(p[k]);
		}
	}
	if let Some([bottom, top]) = shading.height_range {
		(low[2], high[2]) = (bottom, top);
	}
	let generated = |p: Vec3| -> Vec3 { [0, 1, 2].map(|k| (p[k] - low[k]) / (high[k] - low[k]).max(1e-9)) };

	// Every color comes from strokes laid on a canvas, wear gathering on
	// sharp edges, in creases and low down.
	let edge_wear = |p: Vec3, n: Vec3| (crease_paint(p, n).1 * 2.5).min(1.0);
	let crease_wear = |p: Vec3, n: Vec3| (crease_paint(p, n).0 * 2.5).min(1.0);
	let low_wear = |p: Vec3| 1.0 - generated(p)[2];
	let wear = coat::Wear { edge: &edge_wear, crease: &crease_wear, low: &low_wear };
	let full = texels(mesh, width, height);
	// Each layer is cached on its own, so an edit only rebakes the layers it
	// reads. Layers hold per texel values, in the order of `full`.
	let neighbours: Vec<&Mesh> = group.iter().chain(occluders).copied().collect();
	// Each per-texel pass runs on the GPU when there is one (see gpu.rs), and
	// on the CPU threads otherwise.
	// A shared height range changes where low wear and the gradient fall, so
	// it keys the layers; without one the keys stay as they were.
	let range_key: Vec<f64> = shading.height_range.map_or_else(Vec::new, |r| r.to_vec());
	let drawn_key: Vec<f64> = if shading.strokes.is_empty() { Vec::new() } else { vec![shading.strokes.len() as f64] };
	let coat_numbers = [&[look.gradient, look.brush][..], &range_key, &drawn_key].concat();
	let coat_layer = cached_layer(cache::layer_path("coat", mesh, &neighbours, false, &coat_numbers, Some(&*image), source), || {
		let mut canvas = coat::coat(mesh, look, &wear, base);
		for stroke in &shading.strokes {
			canvas.add(stroke.clone());
		}
		let colours = match gpu::canvas(&canvas, &full, false) {
			Some(painted) => painted.into_iter().map(|(c, _)| to_f32(c)).collect(),
			None => parallel(&full, |t| to_f32(canvas.paint(t.position, t.face_normal))),
		};
		vec![layer_image(width, height, &full, &colours)]
	});
	let wear_numbers = [&[look.rust, f64::from(u8::from(look.rubber)), look.gradient, look.brush][..], &range_key].concat();
	let wear_layer = cached_layer(cache::layer_path("wear", mesh, &neighbours, true, &wear_numbers, Some(&*image), source), || {
		let canvas = coat::wear(mesh, look, &wear, base);
		let over = gpu::canvas(&canvas, &full, true).unwrap_or_else(|| parallel(&full, |t| canvas.over(t.position, t.face_normal)));
		let colour: Vec<[f32; 3]> = over.iter().map(|(c, _)| to_f32(*c)).collect();
		let cover: Vec<[f32; 3]> = over.iter().map(|(_, a)| [*a as f32, 0.0, 0.0]).collect();
		vec![layer_image(width, height, &full, &colour), layer_image(width, height, &full, &cover)]
	});
	// No colour goes in, so the texture size keys the layer instead, with the
	// reach and highlight width that shape the strokes.
	let shade_size: Vec<f64> = [width as f64, height as f64, reach, width_scale]
		.into_iter()
		.chain(shading.painted_highlights.then_some(2.0))
		.chain((shading.corner_taper > 0.0).then_some(shading.corner_taper + 4.0))
		.collect();
	let shade_layer = cached_layer(cache::layer_path("shade", mesh, &neighbours, true, &shade_size, None, source), || {
		let creases = gpu::crease(&full, &surfaces, &contact_grid, min_cos, reach, width_scale, shading.painted_highlights, shading.corner_taper).unwrap_or_else(|| parallel(&full, |t| crease_paint(t.position, t.face_normal)));
		let values: Vec<[f32; 3]> = creases.into_iter().map(|(shade, outward)| [shade as f32, outward as f32, 0.0]).collect();
		vec![layer_image(width, height, &full, &values)]
	});

	// Combine the layers per texel: the wear over the coat, then the lit and
	// dark creases, then the bands.
	let colors = parallel(&full, |texel| {
		let g = generated(texel.position);
		let coat_colour = coat_layer[0].pixels[texel.pixel].map(f64::from);
		let wear_colour = wear_layer[0].pixels[texel.pixel].map(f64::from);
		let cover = f64::from(wear_layer[1].pixels[texel.pixel][0]);
		let mut color: [f64; 3] = std::array::from_fn(|k| coat_colour[k] + (wear_colour[k] - coat_colour[k]) * cover);
		let [shade, outward, _] = shade_layer[0].pixels[texel.pixel].map(f64::from);
		let low = 1.0 - g[2];
		let ramp = 1.0 + shading.highlight_ramp * low * low * (3.0 - 2.0 * low);
		let lit = (outward * (1.0 - shade) * shading.highlight * ramp).clamp(0.0, 1.0);
		let dark = (shade * 1.6 * shading.shadow).clamp(0.0, 1.0);
		let cream = [1.0, 0.97, 0.85].map(to_linear_f64);
		let screen: [f64; 3] = std::array::from_fn(|k| {
			let lighter = (color[k] * 1.8 + 0.08).min(1.0);
			cream[k] + (lighter - cream[k]) * shading.blend
		});
		let multiply = [0.32, 0.3, 0.5].map(to_linear_f64);
		for k in 0..3 {
			let screened = 1.0 - (1.0 - color[k]) * (1.0 - screen[k]);
			color[k] += (screened - color[k]) * lit;
			color[k] += (color[k] * multiply[k] - color[k]) * dark;
		}
		if shading.bands > 0 {
			let bands = shading.bands as f64;
			let band = (g[2] * bands * 2.0).floor();
			let jitter = (hash(band as i64 as u32 ^ 0x5bd1_e995) - 0.5) * 0.6;
			let darkness = (1.0 - (band + jitter) / bands).clamp(0.0, 1.0);
			let factor = (darkness * 0.9).clamp(0.0, 1.0);
			let tint = [0.25, 0.22, 0.4].map(to_linear_f64);
			for k in 0..3 {
				color[k] += (color[k] * tint[k] - color[k]) * factor;
			}
		}
		color.map(to_srgb)
	});
	let mut covered = vec![false; width * height];
	for (texel, color) in full.iter().zip(colors) {
		image.pixels[texel.pixel] = color;
		covered[texel.pixel] = true;
	}
	dilate(&mut image.pixels, &mut covered, width, height, 8);
}

// Returns a layer's images from the cache when present, else builds them and
// saves them there.
fn cached_layer(path: Option<PathBuf>, build: impl FnOnce() -> Vec<Image>) -> Vec<Image> {
	if let Some(images) = path.as_deref().and_then(cache::load_layers) {
		return images;
	}
	let images = build();
	if let Some(path) = &path {
		let refs: Vec<&Image> = images.iter().collect();
		if let Err(error) = cache::save_layers(path, &refs) {
			eprintln!("could not cache paint: {error}");
		}
	}
	images
}

// A layer image holding one value per texel, placed at the texel's pixel.
fn layer_image(width: usize, height: usize, texels: &[Texel], values: &[[f32; 3]]) -> Image {
	let mut image = Image::new(width, height, [0.0; 3]);
	for (texel, value) in texels.iter().zip(values) {
		image.pixels[texel.pixel] = *value;
	}
	image
}

fn to_f32(c: [f64; 3]) -> [f32; 3] {
	c.map(|x| x as f32)
}

fn to_linear_f64(c: f64) -> f64 {
	to_linear(c as f32)
}

// Looks up the color an image already holds at a surface point, from the
// nearest texel facing the same way, for coats painted over existing colors.
pub struct ImageSampler {
	texels: Vec<(Vec3, Vec3, [f32; 3])>,
	grid: HashMap<[i64; 3], Vec<usize>>,
}

const SAMPLER_CELL: f64 = 0.1;

impl ImageSampler {
	pub fn new(mesh: &Mesh, image: &Image) -> ImageSampler {
		let key = |p: Vec3| p.map(|c| (c / SAMPLER_CELL).floor() as i64);
		let mut sampler = ImageSampler { texels: Vec::new(), grid: HashMap::new() };
		for texel in texels(mesh, image.width, image.height) {
			sampler.grid.entry(key(texel.position)).or_default().push(sampler.texels.len());
			sampler.texels.push((texel.position, texel.face_normal, image.pixels[texel.pixel]));
		}
		sampler
	}

	// sRGB color at p on a surface with normal n.
	pub fn color(&self, p: Vec3, n: Vec3) -> [f64; 3] {
		let home = p.map(|c| (c / SAMPLER_CELL).floor() as i64);
		let mut best = (f64::MAX, [0.5f32; 3]);
		for x in -1..=1 {
			for y in -1..=1 {
				for z in -1..=1 {
					for &index in self.grid.get(&[home[0] + x, home[1] + y, home[2] + z]).into_iter().flatten() {
						let (at, normal, color) = self.texels[index];
						let offset = sub(p, at);
						let d = dot(offset, offset) + if dot(n, normal) < 0.5 { 1.0 } else { 0.0 };
						if d < best.0 {
							best = (d, color);
						}
					}
				}
			}
		}
		best.1.map(f64::from)
	}
}

// Whether another mesh is close enough to a mesh's surfaces to shade or be
// shaded by them. The paint only reads occluders this close.
pub fn within_reach(own: &Mesh, other: &Mesh, reach: f64) -> bool {
	let (own_low, own_high) = bounds(own);
	let (low, high) = bounds(other);
	let gap = (0..3).map(|k| (low[k] - own_high[k]).max(own_low[k] - high[k]).max(0.0)).fold(0.0, |sum, g| sum + g * g);
	gap <= reach * reach
}

// Corners of the box round a mesh's positions.
fn bounds(mesh: &Mesh) -> (Vec3, Vec3) {
	let mut low = [f64::MAX; 3];
	let mut high = [f64::MIN; 3];
	for p in &mesh.positions {
		for k in 0..3 {
			low[k] = low[k].min(p[k]);
			high[k] = high[k].max(p[k]);
		}
	}
	(low, high)
}

