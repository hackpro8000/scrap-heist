// Bake: texture work done on a mesh's surface. Unwrapping lays the faces out
// in UV space; rasterizing finds the surface point behind every texel; the
// shading pass paints light-independent edge highlights and contact shadows
// on top of a script's base colors, like the old Blender paint_shading.

use std::collections::HashMap;

use crate::image::Image;
use crate::mesh::{add, cross, dot, normalize, scale, sub, Mesh, Vec3};

// --- Noise ------------------------------------------------------------------

// Improved Perlin noise in roughly -1..1, with a fixed permutation so bakes
// are repeatable.
pub struct Noise {
	perm: [u8; 512],
}

impl Noise {
	pub fn new() -> Self {
		let mut table: Vec<u8> = (0..=255).collect();
		let mut state: u32 = 0x9e37_79b9;
		for i in (1..256).rev() {
			state = state.wrapping_mul(1_664_525).wrapping_add(1_013_904_223);
			table.swap(i, (state >> 8) as usize % (i + 1));
		}
		let mut perm = [0u8; 512];
		for i in 0..512 {
			perm[i] = table[i & 255];
		}
		Noise { perm }
	}

	pub fn perlin(&self, p: Vec3) -> f64 {
		let fade = |t: f64| t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
		let lerp = |t: f64, a: f64, b: f64| a + t * (b - a);
		let grad = |hash: u8, x: f64, y: f64, z: f64| {
			let h = hash & 15;
			let u = if h < 8 { x } else { y };
			let v = if h < 4 { y } else if h == 12 || h == 14 { x } else { z };
			(if h & 1 == 0 { u } else { -u }) + (if h & 2 == 0 { v } else { -v })
		};
		let floor = p.map(f64::floor);
		let [x, y, z] = [p[0] - floor[0], p[1] - floor[1], p[2] - floor[2]];
		let [xi, yi, zi] = floor.map(|f| (f as i64 & 255) as usize);
		let perm = &self.perm;
		let a = perm[xi] as usize + yi;
		let (aa, ab) = (perm[a] as usize + zi, perm[a + 1] as usize + zi);
		let b = perm[xi + 1] as usize + yi;
		let (ba, bb) = (perm[b] as usize + zi, perm[b + 1] as usize + zi);
		let (u, v, w) = (fade(x), fade(y), fade(z));
		lerp(
			w,
			lerp(v, lerp(u, grad(perm[aa], x, y, z), grad(perm[ba], x - 1.0, y, z)), lerp(u, grad(perm[ab], x, y - 1.0, z), grad(perm[bb], x - 1.0, y - 1.0, z))),
			lerp(
				v,
				lerp(u, grad(perm[aa + 1], x, y, z - 1.0), grad(perm[ba + 1], x - 1.0, y, z - 1.0)),
				lerp(u, grad(perm[ab + 1], x, y - 1.0, z - 1.0), grad(perm[bb + 1], x - 1.0, y - 1.0, z - 1.0)),
			),
		)
	}

	// Like Blender's Noise Texture factor with detail 1: two octaves, centered
	// on 0.5. `seed` stands in for its 4D W input.
	pub fn factor(&self, p: Vec3, frequency: f64, seed: f64) -> f64 {
		let q = add(scale(p, frequency), [seed * 1.7, seed * 3.1, seed * 2.3]);
		let n = (self.perlin(q) + 0.5 * self.perlin(scale(q, 2.0))) / 1.5;
		0.5 + 0.5 * n
	}
}

fn hash(mut x: u32) -> f64 {
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
	pub uv: [f64; 2],
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
					uv: [(fx + 0.5) / width as f64, (fy + 0.5) / height as f64],
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

// --- Ray queries ------------------------------------------------------------

struct Node {
	low: Vec3,
	high: Vec3,
	// Leaf: first triangle and count. Inner: left child at `first`, right
	// child right after this node's subtree; count is 0.
	first: usize,
	count: usize,
	right: usize,
}

pub struct Bvh {
	triangles: Vec<[Vec3; 3]>,
	nodes: Vec<Node>,
}

impl Bvh {
	pub fn new(mut triangles: Vec<[Vec3; 3]>) -> Self {
		let mut nodes = Vec::new();
		let count = triangles.len();
		build(&mut triangles, 0, count, &mut nodes);
		Bvh { triangles, nodes }
	}

	// True when the ray hits any triangle closer than `reach`.
	pub fn blocked(&self, origin: Vec3, direction: Vec3, reach: f64) -> bool {
		if self.nodes.is_empty() {
			return false;
		}
		let inverse = direction.map(|d| 1.0 / d);
		let mut stack = vec![0usize];
		while let Some(index) = stack.pop() {
			let node = &self.nodes[index];
			let (mut near, mut far) = (0.0f64, reach);
			for k in 0..3 {
				let a = (node.low[k] - origin[k]) * inverse[k];
				let b = (node.high[k] - origin[k]) * inverse[k];
				near = near.max(a.min(b));
				far = far.min(a.max(b));
			}
			if near > far {
				continue;
			}
			if node.count == 0 {
				stack.push(index + 1);
				stack.push(node.right);
				continue;
			}
			for triangle in &self.triangles[node.first..node.first + node.count] {
				if hit(triangle, origin, direction, reach) {
					return true;
				}
			}
		}
		false
	}
}

fn build(triangles: &mut [[Vec3; 3]], first: usize, count: usize, nodes: &mut Vec<Node>) -> usize {
	let slice = &mut triangles[first..first + count];
	let mut low = [f64::MAX; 3];
	let mut high = [f64::MIN; 3];
	for triangle in slice.iter() {
		for p in triangle {
			for k in 0..3 {
				low[k] = low[k].min(p[k]);
				high[k] = high[k].max(p[k]);
			}
		}
	}
	let index = nodes.len();
	nodes.push(Node { low, high, first, count, right: 0 });
	if count <= 4 {
		return index;
	}
	let axis = (0..3).max_by(|&a, &b| (high[a] - low[a]).total_cmp(&(high[b] - low[b]))).unwrap();
	let centre = |t: &[Vec3; 3]| t[0][axis] + t[1][axis] + t[2][axis];
	slice.select_nth_unstable_by(count / 2, |a, b| centre(a).total_cmp(&centre(b)));
	nodes[index].count = 0;
	build(triangles, first, count / 2, nodes);
	let right = build(triangles, first + count / 2, count - count / 2, nodes);
	nodes[index].right = right;
	index
}

fn hit(triangle: &[Vec3; 3], origin: Vec3, direction: Vec3, reach: f64) -> bool {
	let e1 = sub(triangle[1], triangle[0]);
	let e2 = sub(triangle[2], triangle[0]);
	let p = cross(direction, e2);
	let det = dot(e1, p);
	if det.abs() < 1e-12 {
		return false;
	}
	let t0 = sub(origin, triangle[0]);
	let u = dot(t0, p) / det;
	if !(0.0..=1.0).contains(&u) {
		return false;
	}
	let q = cross(t0, e1);
	let v = dot(direction, q) / det;
	if v < 0.0 || u + v > 1.0 {
		return false;
	}
	let t = dot(e2, q) / det;
	t > 1e-6 && t < reach
}

pub fn mesh_triangles(mesh: &Mesh) -> Vec<[Vec3; 3]> {
	mesh.triangles().iter().map(|t| t.map(|c| c.position)).collect()
}

// --- Shading ----------------------------------------------------------------

pub struct Shading {
	pub highlight: f64,
	pub shadow: f64,
	pub bands: usize,
	// Edges folding more than this many degrees get highlighted.
	pub sharp: f64,
	// 0-1: feathers highlight strokes and tints them toward a lighter base
	// color instead of cream, so they melt into the paint. 0 keeps the classic look.
	pub blend: f64,
	// 0-1: smooth top-to-bottom darkening across each part, cool in the low end.
	pub gradient: f64,
	// Extra highlight strength reached at the bottom of each part, ramping
	// smoothly from none at the top (0.3 = 30% stronger at the bottom).
	pub highlight_ramp: f64,
	// Studs: when above 0, highlights follow surface curvature measured over
	// this radius instead of strokes along sharp mesh edges.
	pub curvature: f64,
}

const AO_DISTANCE: f64 = 0.8;
const AO_SAMPLES: u32 = 16;
// AO is soft, so it's baked at a fraction of the texture's resolution.
const AO_DIVISOR: usize = 4;
const EDGE_RADIUS: f64 = 0.1;
const CURVATURE_GAIN: f64 = 0.15;
// Brush strokes: (reach, frequency, thin gain, wide gain, strength).
const STROKES: [(f64, f64, f64, f64, f64); 3] = [(1.0, 3.0, 6.0, 24.0, 0.8), (2.2, 5.0, 3.0, 14.0, 0.6), (0.5, 9.0, 8.0, 36.0, 0.7)];

fn openness(bvh: &Bvh, texel: &Texel) -> f64 {
	let n = texel.face_normal;
	let helper = if n[0].abs() < 0.9 { [1.0, 0.0, 0.0] } else { [0.0, 1.0, 0.0] };
	let t = normalize(cross(n, helper));
	let b = cross(n, t);
	let origin = add(texel.position, scale(n, 1e-3));
	let seed = (texel.position[0] * 7919.0 + texel.position[1] * 104_729.0 + texel.position[2] * 1_299_709.0) as i64 as u32;
	let mut open = 0;
	for sample in 0..AO_SAMPLES {
		// Cosine-weighted direction over the hemisphere.
		let r1 = (sample as f64 + hash(seed.wrapping_add(sample * 2))) / AO_SAMPLES as f64;
		let r2 = hash(seed.wrapping_add(sample * 2 + 1).wrapping_mul(31));
		let (radius, angle) = (r1.sqrt(), r2 * std::f64::consts::TAU);
		let direction = add(add(scale(t, radius * angle.cos()), scale(b, radius * angle.sin())), scale(n, (1.0 - r1).sqrt()));
		if !bvh.blocked(origin, direction, AO_DISTANCE) {
			open += 1;
		}
	}
	open as f64 / AO_SAMPLES as f64
}

// Convex edges sharper than the threshold, as segments with how hard they fold.
fn sharp_edges(mesh: &Mesh, degrees: f64) -> Vec<(Vec3, Vec3, f64)> {
	let normals: Vec<Vec3> = mesh.faces.iter().map(|face| mesh.face_normal(face)).collect();
	let centre = |face: usize| {
		let verts = &mesh.faces[face].verts;
		scale(verts.iter().fold([0.0; 3], |sum, &v| add(sum, mesh.positions[v])), 1.0 / verts.len() as f64)
	};
	let limit = degrees.to_radians().cos();
	let mut found = Vec::new();
	for ((a, b), faces) in edge_faces(mesh) {
		if faces.len() != 2 {
			continue;
		}
		let (f, g) = (faces[0], faces[1]);
		let fold = dot(normals[f], normals[g]).clamp(-1.0, 1.0);
		if fold > limit || dot(normals[f], sub(centre(g), centre(f))) > 1e-9 {
			continue;
		}
		// A rounded normal halfway between the faces turns half the fold.
		let bend = 1.0 - (fold.acos() / 2.0).cos();
		found.push((mesh.positions[a], mesh.positions[b], bend));
	}
	found
}

// Surface points about `spacing` apart, each with its face normal.
fn surface_points(mesh: &Mesh, spacing: f64) -> Vec<(Vec3, Vec3)> {
	let mut found = Vec::new();
	for [a, b, c] in mesh_triangles(mesh) {
		let normal = normalize(cross(sub(b, a), sub(c, a)));
		let longest = dot(sub(b, a), sub(b, a)).max(dot(sub(c, b), sub(c, b))).max(dot(sub(a, c), sub(a, c))).sqrt();
		let steps = (longest / spacing).ceil().max(1.0) as usize;
		for i in 0..steps {
			for j in 0..steps - i {
				let (u, v) = ((i as f64 + 1.0 / 3.0) / steps as f64, (j as f64 + 1.0 / 3.0) / steps as f64);
				found.push((add(a, add(scale(sub(b, a), u), scale(sub(c, a), v))), normal));
			}
		}
	}
	found
}

// How convex the surface is around a point: the average turn of nearby normals
// away from this one, per stud of distance (1/radius on a sphere).
fn convexity(points: &[(Vec3, Vec3)], nearby: &[usize], p: Vec3, n: Vec3, radius: f64) -> f64 {
	let (mut sum, mut weight) = (0.0, 0.0);
	for &index in nearby {
		let (q, m) = points[index];
		let d = sub(q, p);
		let length = dot(d, d).sqrt();
		// Skip the far side of thin walls, which faces away.
		if length < 1e-6 || length > radius || dot(m, n) < -0.2 {
			continue;
		}
		let w = 1.0 - length / radius;
		sum += w * dot(sub(n, m), d) / (length * length);
		weight += w;
	}
	if weight > 0.0 { sum / weight } else { 0.0 }
}

fn segment_distance(p: Vec3, a: Vec3, b: Vec3) -> f64 {
	let ab = sub(b, a);
	let t = (dot(sub(p, a), ab) / dot(ab, ab).max(1e-12)).clamp(0.0, 1.0);
	let d = sub(p, add(a, scale(ab, t)));
	dot(d, d).sqrt()
}

fn to_linear(c: f32) -> f64 {
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

pub fn paint_shading(mesh: &Mesh, occluders: &[&Mesh], image: &mut Image, shading: &Shading) {
	let (width, height) = (image.width, image.height);
	let mut triangles = mesh_triangles(mesh);
	for other in occluders {
		triangles.extend(mesh_triangles(other));
	}
	let bvh = Bvh::new(triangles);

	// Openness at low resolution, sampled bilinearly below.
	let (aw, ah) = ((width / AO_DIVISOR).max(8), (height / AO_DIVISOR).max(8));
	let coarse = texels(mesh, aw, ah);
	let values = parallel(&coarse, |texel| openness(&bvh, texel));
	let mut ao = vec![[1.0f32; 3]; aw * ah];
	let mut covered = vec![false; aw * ah];
	for (texel, value) in coarse.iter().zip(values) {
		ao[texel.pixel] = [value as f32; 3];
		covered[texel.pixel] = true;
	}
	dilate(&mut ao, &mut covered, aw, ah, 4);
	let sample_ao = |uv: [f64; 2]| -> f64 {
		let x = (uv[0] * aw as f64 - 0.5).clamp(0.0, (aw - 1) as f64);
		let y = (uv[1] * ah as f64 - 0.5).clamp(0.0, (ah - 1) as f64);
		let (x0, y0) = (x as usize, y as usize);
		let (x1, y1) = ((x0 + 1).min(aw - 1), (y0 + 1).min(ah - 1));
		let (fx, fy) = (x - x0 as f64, y - y0 as f64);
		let at = |x: usize, y: usize| ao[y * aw + x][0] as f64;
		let low = at(x0, y0) * (1.0 - fx) + at(x1, y0) * fx;
		let high = at(x0, y1) * (1.0 - fx) + at(x1, y1) * fx;
		low * (1.0 - fy) + high * fy
	};

	// Sharp edges bucketed in a grid as wide as the longest stroke reaches.
	let edges = sharp_edges(mesh, shading.sharp);
	let cell = EDGE_RADIUS * 2.2;
	let key = |p: Vec3| p.map(|c| (c / cell).floor() as i64);
	let mut grid: HashMap<[i64; 3], Vec<usize>> = HashMap::new();
	for (index, &(a, b, _)) in edges.iter().enumerate() {
		let (ka, kb) = (key(a), key(b));
		for x in ka[0].min(kb[0]) - 1..=ka[0].max(kb[0]) + 1 {
			for y in ka[1].min(kb[1]) - 1..=ka[1].max(kb[1]) + 1 {
				for z in ka[2].min(kb[2]) - 1..=ka[2].max(kb[2]) + 1 {
					grid.entry([x, y, z]).or_default().push(index);
				}
			}
		}
	}

	// Surface samples bucketed by the widest curvature reach.
	let reach = STROKES.iter().map(|s| s.0).fold(0.0, f64::max) * shading.curvature;
	let points = if shading.curvature > 0.0 { surface_points(mesh, shading.curvature / 4.0) } else { Vec::new() };
	let point_key = |p: Vec3| p.map(|c| (c / reach).floor() as i64);
	let mut point_grid: HashMap<[i64; 3], Vec<usize>> = HashMap::new();
	for (index, &(p, _)) in points.iter().enumerate() {
		point_grid.entry(point_key(p)).or_default().push(index);
	}

	let mut low = [f64::MAX; 3];
	let mut high = [f64::MIN; 3];
	for p in &mesh.positions {
		for k in 0..3 {
			low[k] = low[k].min(p[k]);
			high[k] = high[k].max(p[k]);
		}
	}
	let generated = |p: Vec3| -> Vec3 { [0, 1, 2].map(|k| (p[k] - low[k]) / (high[k] - low[k]).max(1e-9)) };

	let noise = Noise::new();
	let full = texels(mesh, width, height);
	let base = &image.pixels;
	let colors = parallel(&full, |texel| {
		let g = generated(texel.position);
		let nearby = grid.get(&key(texel.position));
		let mut close = Vec::new();
		if shading.curvature > 0.0 {
			let k = point_key(texel.position);
			for x in -1..=1 {
				for y in -1..=1 {
					for z in -1..=1 {
						close.extend(point_grid.get(&[k[0] + x, k[1] + y, k[2] + z]).into_iter().flatten());
					}
				}
			}
		}
		let mut edge = 0.0f64;
		for (seed, &(reach, frequency, thin, wide, strength)) in STROKES.iter().enumerate() {
			let mut bend = 0.0f64;
			if shading.curvature > 0.0 {
				// Scaled so a right-angle edge peaks near the same bend as below.
				let radius = shading.curvature * reach;
				bend = (convexity(&points, &close, texel.position, texel.face_normal, radius) * radius * CURVATURE_GAIN).clamp(0.0, 0.5);
			} else {
				let radius = EDGE_RADIUS * reach;
				for &index in nearby.into_iter().flatten() {
					let (a, b, fold) = edges[index];
					let d = segment_distance(texel.position, a, b);
					if d < radius {
						bend = bend.max(fold * (1.0 - d / radius));
					}
				}
			}
			if bend <= 0.0 {
				continue;
			}
			let s = seed as f64;
			let width = ((noise.factor(g, frequency, s * 3.1) - 0.3) / 0.4).clamp(0.0, 1.0);
			let gain = thin + (wide - thin) * width;
			let feather = 0.08 + 0.22 * shading.blend;
			let painted = ((noise.factor(g, frequency * 0.8, s * 5.7 + 1.3) - 0.42) / feather).clamp(0.0, 1.0);
			let push = ((noise.factor(g, frequency * 0.5, s * 2.3 + 7.9) - 0.35) / 0.3).clamp(0.0, 1.0);
			let pressure = 0.35 * strength + (strength - 0.35 * strength) * push;
			edge = (edge + (bend * gain).min(1.0) * painted * pressure).min(1.0);
		}
		let open = sample_ao(texel.uv);
		let low = 1.0 - g[2];
		let ramp = 1.0 + shading.highlight_ramp * low * low * (3.0 - 2.0 * low);
		let lit = (edge * open * shading.highlight * ramp).clamp(0.0, 1.0);
		let dark = ((1.0 - open) * 1.6 * shading.shadow).clamp(0.0, 1.0);
		let mut color = base[texel.pixel].map(to_linear);
		let cream = [1.0, 0.97, 0.85].map(to_linear_f64);
		let screen: [f64; 3] = std::array::from_fn(|k| {
			let lighter = (color[k] as f64 * 1.8 + 0.08).min(1.0);
			cream[k] + (lighter - cream[k]) * shading.blend
		});
		let multiply = [0.32, 0.3, 0.5].map(to_linear_f64);
		for k in 0..3 {
			let screened = 1.0 - (1.0 - color[k]) * (1.0 - screen[k]);
			color[k] += (screened - color[k]) * lit;
			color[k] += (color[k] * multiply[k] - color[k]) * dark;
		}
		if shading.gradient > 0.0 {
			let t = 1.0 - g[2];
			let factor = t * t * (3.0 - 2.0 * t) * shading.gradient;
			let tint = [0.45, 0.42, 0.6].map(to_linear_f64);
			for k in 0..3 {
				color[k] += (color[k] * tint[k] - color[k]) * factor;
			}
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
