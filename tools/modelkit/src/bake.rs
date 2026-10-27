// Bake: texture work done on a mesh's surface. Unwrapping lays the faces out
// in UV space; rasterizing finds the surface point behind every texel; the
// shading pass paints light-independent edge highlights and contact shadows
// on top of a script's base colors, like the old Blender paint_shading.

use std::collections::HashMap;

use crate::coat;
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

pub fn mesh_triangles(mesh: &Mesh) -> Vec<[Vec3; 3]> {
	mesh.triangles().iter().map(|t| t.map(|c| c.position)).collect()
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
}

// How far a contact shadow spreads from the corner that casts it.
const CONTACT_REACH: f64 = 0.2;
// Folds gentler than this (as a fraction of a half turn) cast nothing,
// so the facets inside a rounded hollow stay clean.
const CONTACT_MIN_FOLD: f64 = 1.0 / 6.0;

// Brush passes: (width, length, step, pressure).
const BRUSH_PASSES: [(f64, f64, f64, f64); 2] = [(0.16, 0.6, 0.4, 0.75), (0.08, 0.35, 0.22, 1.0)];
const BRISTLES: f64 = 14.0;

// Coverage of overlapping brush strokes laid along one edge, at distance d
// from it and t studs along it.
fn brush_strokes(edge: usize, t: f64, length: f64, d: f64) -> f64 {
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
			let half = width * (0.5 + 0.6 * r(2)) * taper;
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

pub fn paint_shading(mesh: &Mesh, occluders: &[&Mesh], image: &mut Image, shading: &Shading, look: &coat::Look, base: &mut dyn FnMut(Vec3, Vec3) -> [f64; 3]) {
	let (width, height) = (image.width, image.height);
	// Shadows and highlights both come from the corners a texel sits in: a
	// surface nearby that faces it makes an interior angle, which shades, and
	// one that faces away makes an exterior angle, which catches the light.
	// Either way the sharper the corner the stronger the paint, so rounded
	// facets stay clean. Only this part's own surfaces make exterior angles;
	// another part merely passing close by is not an edge of this one.
	let own = mesh_triangles(mesh).len();
	// Only occluders close enough to reach this mesh can cast or catch anything.
	let (own_low, own_high) = bounds(mesh);
	let mut triangles = mesh_triangles(mesh);
	for other in occluders {
		let (low, high) = bounds(other);
		let gap = (0..3).map(|k| (low[k] - own_high[k]).max(own_low[k] - high[k]).max(0.0)).fold(0.0, |sum, g| sum + g * g);
		if gap <= CONTACT_REACH * CONTACT_REACH {
			triangles.extend(mesh_triangles(other));
		}
	}
	let surfaces: Vec<([Vec3; 3], Vec3, bool)> = triangles
		.into_iter()
		.enumerate()
		.filter_map(|(index, t)| {
			let n = cross(sub(t[1], t[0]), sub(t[2], t[0]));
			let length = dot(n, n).sqrt();
			(length > 1e-12).then(|| (t, scale(n, 1.0 / length), index < own))
		})
		.collect();
	let contact_key = |p: Vec3| p.map(|c| (c / CONTACT_REACH).floor() as i64);
	let mut contact_grid: HashMap<[i64; 3], Vec<usize>> = HashMap::new();
	for (index, (t, _, _)) in surfaces.iter().enumerate() {
		let low = contact_key([0, 1, 2].map(|k| t[0][k].min(t[1][k]).min(t[2][k])));
		let high = contact_key([0, 1, 2].map(|k| t[0][k].max(t[1][k]).max(t[2][k])));
		for x in low[0]..=high[0] {
			for y in low[1]..=high[1] {
				for z in low[2]..=high[2] {
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
						let offset = sub(p, closest_on_triangle(p, triangle));
						let distance = dot(offset, offset).sqrt();
						// An interior angle's surface faces the texel, so the texel sits in
						// front of its plane; an exterior angle's faces away, so behind it.
						let side = dot(facing, offset);
						let front = side > 0.0;
						let behind = side < 0.0 && mine;
						if distance < 1e-6 || distance >= CONTACT_REACH || !(front || behind) || dot(n, offset) > 0.3 * distance {
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
						let paint = brush_strokes(seed as usize, along, f64::MAX, distance);
						let value = sharpness * paint * (1.0 - distance / CONTACT_REACH);
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
	let generated = |p: Vec3| -> Vec3 { [0, 1, 2].map(|k| (p[k] - low[k]) / (high[k] - low[k]).max(1e-9)) };

	// Every color comes from strokes laid on a canvas, wear gathering on
	// sharp edges, in creases and low down.
	let edge_wear = |p: Vec3, n: Vec3| (crease_paint(p, n).1 * 2.5).min(1.0);
	let crease_wear = |p: Vec3, n: Vec3| (crease_paint(p, n).0 * 2.5).min(1.0);
	let low_wear = |p: Vec3| 1.0 - generated(p)[2];
	let wear = coat::Wear { edge: &edge_wear, crease: &crease_wear, low: &low_wear };
	let canvas = coat::paint(mesh, look, &wear, base);

	let full = texels(mesh, width, height);
	let colors = parallel(&full, |texel| {
		let g = generated(texel.position);
		let (p, n) = (texel.position, texel.face_normal);
		let (shade, outward) = crease_paint(p, n);
		let low = 1.0 - g[2];
		let ramp = 1.0 + shading.highlight_ramp * low * low * (3.0 - 2.0 * low);
		let lit = (outward * (1.0 - shade) * shading.highlight * ramp).clamp(0.0, 1.0);
		let dark = (shade * 1.6 * shading.shadow).clamp(0.0, 1.0);
		let mut color = canvas.paint(texel.position, texel.face_normal);
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
