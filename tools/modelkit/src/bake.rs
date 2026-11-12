// Bake: texture work done on a mesh's surface. Unwrapping lays the faces out
// in UV space; rasterizing finds the surface point behind every texel; the
// shading pass paints light-independent edge highlights and contact shadows
// on top of a script's base colors, like the old Blender paint_shading.

use std::collections::HashMap;
use std::hash::{BuildHasherDefault, Hasher};
use std::sync::Arc;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::time::Instant;

// Time spent in each shading layer this run (MODELKIT_PROFILE=1 prints them),
// to see where a model's bake goes. Cached layers count only their load.
pub static PROFILE: [AtomicU64; 8] = [AtomicU64::new(0), AtomicU64::new(0), AtomicU64::new(0), AtomicU64::new(0), AtomicU64::new(0), AtomicU64::new(0), AtomicU64::new(0), AtomicU64::new(0)];
// The last four are stages inside the first two: the shade pass's work
// before and after its per-texel paint, and the coat's per-texel paint.
pub const PROFILE_LAYERS: [&str; 8] = ["shade (creases, contact)", "coat", "wear", "combine", "shade, surfaces, grid and texels", "shade, neighbourhoods", "shade, spreading over seams", "coat, painting texels"];
fn timed(stage: usize, since: Instant) {
	PROFILE[stage].fetch_add(since.elapsed().as_micros() as u64, Ordering::Relaxed);
}
fn profiled<T>(layer: usize, work: impl FnOnce() -> T) -> T {
	let started = Instant::now();
	let result = work();
	PROFILE[layer].fetch_add(started.elapsed().as_micros() as u64, Ordering::Relaxed);
	result
}

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
	// The surface directions the texture's U and V run along, unit length, so
	// a tilt in the world turns into a tangent-space normal.
	pub tangent: Vec3,
	pub bitangent: Vec3,
}

// The directions along a triangle's surface that U and V increase in. A
// triangle without usable UVs takes any frame on its surface.
fn tangent_frame(corners: &[crate::mesh::Corner; 3], normal: Vec3) -> (Vec3, Vec3) {
	let e1 = sub(corners[1].position, corners[0].position);
	let e2 = sub(corners[2].position, corners[0].position);
	let (du1, dv1) = (corners[1].uv[0] - corners[0].uv[0], corners[1].uv[1] - corners[0].uv[1]);
	let (du2, dv2) = (corners[2].uv[0] - corners[0].uv[0], corners[2].uv[1] - corners[0].uv[1]);
	let det = du1 * dv2 - du2 * dv1;
	if det.abs() < 1e-12 {
		let side = if normal[2].abs() < 0.9 { [0.0, 0.0, 1.0] } else { [1.0, 0.0, 0.0] };
		let tangent = normalize(cross(side, normal));
		return (tangent, cross(normal, tangent));
	}
	let tangent = scale(sub(scale(e1, dv2), scale(e2, dv1)), 1.0 / det);
	let bitangent = scale(sub(scale(e2, du1), scale(e1, du2)), 1.0 / det);
	// Flat on the surface, each a unit long.
	let flatten = |v: Vec3| normalize(sub(v, scale(normal, dot(v, normal))));
	(flatten(tangent), flatten(bitangent))
}

pub fn texels(mesh: &Mesh, width: usize, height: usize) -> Vec<Texel> {
	samples(mesh, width, height, 1)
}

// Like texels, but tests a grid × grid pattern of points inside each pixel, so
// a pixel can come back several times, once per covered sample.
pub fn samples(mesh: &Mesh, width: usize, height: usize, grid: usize) -> Vec<Texel> {
	samples_in(mesh, width, height, grid, None)
}

// Like samples, but given which pixels are wanted, skips each triangle whose
// pixel rect holds none of them. Every texel on a wanted pixel still comes
// back, in the same order.
fn samples_in(mesh: &Mesh, width: usize, height: usize, grid: usize, wanted: Option<&[bool]>) -> Vec<Texel> {
	// One thread finds the texels: handing triangles to the other threads,
	// singly or in batches, was measured slower on the map (2026-11-11).
	let mut found = Vec::new();
	for corners in mesh.triangles() {
		let face_normal = normalize(cross(sub(corners[1].position, corners[0].position), sub(corners[2].position, corners[0].position)));
		let (tangent, bitangent) = tangent_frame(&corners, face_normal);
		let p = corners.map(|c| [c.uv[0] * width as f64 - 0.5, c.uv[1] * height as f64 - 0.5]);
		let area = (p[1][0] - p[0][0]) * (p[2][1] - p[0][1]) - (p[2][0] - p[0][0]) * (p[1][1] - p[0][1]);
		if area.abs() < 1e-12 {
			continue;
		}
		let x0 = p.iter().map(|q| q[0]).fold(f64::MAX, f64::min).floor().max(0.0) as usize;
		let x1 = (p.iter().map(|q| q[0]).fold(f64::MIN, f64::max).ceil() as usize).min(width - 1);
		let y0 = p.iter().map(|q| q[1]).fold(f64::MAX, f64::min).floor().max(0.0) as usize;
		let y1 = (p.iter().map(|q| q[1]).fold(f64::MIN, f64::max).ceil() as usize).min(height - 1);
		if wanted.is_some_and(|wanted| !(y0..=y1).any(|y| x0 <= x1 && wanted[y * width + x0..=y * width + x1].contains(&true))) {
			continue;
		}
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
					tangent,
					bitangent,
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
	dilate_within(pixels, covered, width, height, passes, None);
}

// Like dilate, but only spreads into the wanted pixels when given. A wanted
// pixel whose neighbours `passes` pixels round are all wanted comes out as
// from dilate; the rest are left as they are.
fn dilate_within(pixels: &mut [[f32; 3]], covered: &mut [bool], width: usize, height: usize, passes: usize, wanted: Option<&[bool]>) {
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
						if before[at] || wanted.is_some_and(|wanted| !wanted[at]) {
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
	// 0-1: how far the hard highlight's thickness wanders along an edge, and
	// the studs between its changes.
	pub highlight_uneven: f64,
	pub highlight_uneven_step: f64,
	// Tapers the highlight to exactly nothing `highlight_end` taper lengths from
	// a corner of its edge, instead of to TAPER_MIN.
	pub highlight_to_zero: bool,
	pub highlight_end: f64,
	// Draws the highlight, the crease shadow or the soft highlight with a moving
	// hand instead of the default strokes.
	pub edge_marks: Option<Arc<crate::marks::Marks>>,
	pub shade_marks: Option<Arc<crate::marks::Marks>>,
	pub soft_marks: Option<Arc<crate::marks::Marks>>,
	// Paints highlights as a few bold, fully loaded strokes along each edge
	// instead of dry bristly ones, for a hand-painted look.
	pub painted_highlights: bool,
	// Highlights run full width at a corner and thin toward the middle of an
	// edge, falling off over this many studs from the nearest corner. 0 keeps
	// them even along the whole edge.
	pub corner_taper: f64,
	// A second, wide and very soft highlight under the strokes: its strength
	// at an edge (0 for none) and how many studs it fades out over.
	pub soft_highlight: f64,
	pub soft_reach: f64,
	// 0-1: how far the soft highlight's width wanders along an edge, and the
	// studs it thins over away from a corner (0 keeps it even).
	pub soft_uneven: f64,
	pub soft_taper: f64,
	// Let the soft highlight thin all the way to nothing away from corners, and
	// how much steeper its fade from the edge is (1 for the plain curve).
	pub soft_to_zero: bool,
	pub soft_power: f64,
	// How many taper lengths from a corner the soft highlight reaches nothing.
	pub soft_end: f64,
	// How far highlights and contact shadows reach from an edge, in studs.
	// Bigger stones want a wider band, the way a thicker brush reads on them.
	pub reach: f64,
	// The normal map's bevel field, apart from the strokes: how far it spreads
	// from an exterior edge (0 for the strokes' reach), the gentlest fold it
	// counts (as a share of a half turn, like CONTACT_MIN_FOLD) and how far it
	// tilts the surface, times the build's --normals strength.
	pub bevel_reach: f64,
	pub bevel_fold: f64,
	pub bevel_tilt: f64,
	// The roughness map, from layers already baked: `roughness_base` for the
	// material (0 bakes no map), plus `roughness_edge` times the edge
	// highlight (negative polishes worn rims), `roughness_crease` times the
	// crease shade (grime) and `roughness_wear` times the wear's cover.
	pub roughness_base: f64,
	pub roughness_edge: f64,
	pub roughness_crease: f64,
	pub roughness_wear: f64,
	// The metalness map, the same way: `metalness_on` enables it, then the
	// material's base plus the edge highlight (worn-through coat shows bare
	// metal), the crease shade and the wear's cover (rust isn't metal).
	pub metalness_on: bool,
	pub metalness_base: f64,
	pub metalness_edge: f64,
	pub metalness_crease: f64,
	pub metalness_wear: f64,
	// The bottom and top the gradient, low wear and highlight ramp run
	// between, instead of the part's own. Chunks of one surface share it, so
	// a chunk with no height (all flat top) isn't painted as all bottom.
	pub height_range: Option<[f64; 2]>,
	// Strokes drawn over the coat, such as cracks.
	pub strokes: Vec<crate::brush::Stroke>,
	// Lays the coat on texel by texel in the exact colours `paint` returns
	// instead of as brush strokes, for machine finishes (hazard tape, a
	// ribbed belt) that strokes would smear. Strokes over the coat are skipped.
	pub crisp: bool,
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
	TAPER_MIN + (1.0 - TAPER_MIN) * (-corner_distance(p, n, q, triangle) / taper).exp()
}

type EdgeKey = ([i64; 3], [i64; 3]);

fn edge_key(a: Vec3, b: Vec3) -> EdgeKey {
	let round = |p: Vec3| p.map(|c| (c * 1e4).round() as i64);
	let (a, b) = (round(a), round(b));
	if a < b { (a, b) } else { (b, a) }
}

// Each sharp edge's whole straight run, end to end, so an edge built from many
// grid cells still counts as one edge with two real corners.
fn crease_runs(planes: &[([Vec3; 3], Vec3)], min_cos: f64) -> HashMap<EdgeKey, (Vec3, Vec3)> {
	let mut faces: HashMap<EdgeKey, (Vec3, Vec3, Vec<Vec3>)> = HashMap::new();
	for (triangle, facing) in planes {
		for k in 0..3 {
			let (a, b) = (triangle[k], triangle[(k + 1) % 3]);
			faces.entry(edge_key(a, b)).or_insert((a, b, Vec::new())).2.push(*facing);
		}
	}
	let sharp: Vec<(EdgeKey, Vec3, Vec3)> = faces
		.into_iter()
		.filter(|(_, (_, _, normals))| normals.iter().any(|n| normals.iter().any(|m| dot(*n, *m) < min_cos)))
		.map(|(key, (a, b, _))| (key, a, b))
		.collect();
	let round = |p: Vec3| p.map(|c| (c * 1e4).round() as i64);
	let mut at_vertex: HashMap<[i64; 3], Vec<usize>> = HashMap::new();
	for (index, (_, a, b)) in sharp.iter().enumerate() {
		at_vertex.entry(round(*a)).or_default().push(index);
		at_vertex.entry(round(*b)).or_default().push(index);
	}
	let mut parent: Vec<usize> = (0..sharp.len()).collect();
	fn find(parent: &mut [usize], mut i: usize) -> usize {
		while parent[i] != i {
			parent[i] = parent[parent[i]];
			i = parent[i];
		}
		i
	}
	for list in at_vertex.values() {
		if let [first, second] = list[..] {
			let direction = |i: usize| normalize(sub(sharp[i].2, sharp[i].1));
			if dot(direction(first), direction(second)).abs() > 0.999 {
				let (a, b) = (find(&mut parent, first), find(&mut parent, second));
				parent[a] = b;
			}
		}
	}
	let mut ends: HashMap<usize, (Vec3, Vec3)> = HashMap::new();
	for index in 0..sharp.len() {
		let root = find(&mut parent, index);
		let axis = normalize(sub(sharp[root].2, sharp[root].1));
		let (_, a, b) = sharp[index];
		let run = ends.entry(root).or_insert((a, a));
		for p in [a, b] {
			if dot(p, axis) < dot(run.0, axis) {
				run.0 = p;
			}
			if dot(p, axis) > dot(run.1, axis) {
				run.1 = p;
			}
		}
	}
	let mut runs = HashMap::new();
	for index in 0..sharp.len() {
		let root = find(&mut parent, index);
		runs.insert(sharp[index].0, ends[&root]);
		// Each end also keyed alone, so a point can be asked if it is on a run.
		runs.insert(edge_key(sharp[index].1, sharp[index].1), ends[&root]);
		runs.insert(edge_key(sharp[index].2, sharp[index].2), ends[&root]);
	}
	runs
}

// How far q is from the nearer end of the straight run it lies on, when q is on
// one of this triangle's own sharp edges.
fn run_distance(q: Vec3, triangle: [Vec3; 3], runs: &HashMap<EdgeKey, (Vec3, Vec3)>) -> Option<f64> {
	let mut best: Option<(f64, EdgeKey)> = None;
	for k in 0..3 {
		let (a, b) = (triangle[k], triangle[(k + 1) % 3]);
		let e = sub(b, a);
		let t = (dot(sub(q, a), e) / dot(e, e).max(1e-12)).clamp(0.0, 1.0);
		let d = sub(q, add(a, scale(e, t)));
		let distance = dot(d, d);
		if distance < 1e-10 && best.is_none_or(|(old, _)| distance < old) && runs.contains_key(&edge_key(a, b)) {
			best = Some((distance, edge_key(a, b)));
		}
	}
	let (ends_a, ends_b) = runs[&best?.1];
	let (da, db) = (sub(q, ends_a), sub(q, ends_b));
	Some(dot(da, da).sqrt().min(dot(db, db).sqrt()))
}

// What both faces of an edge agree on, so marks can cross between them: a seed,
// which side of the edge this face is on (1 or -1), and the studs along the edge.
fn edge_frame(n: Vec3, facing: Vec3, p: Vec3, on_facing: Vec3, crease: Vec3) -> (u32, f64, f64) {
	let plane = |m: Vec3, at: Vec3| [m[0] * 8.0, m[1] * 8.0, m[2] * 8.0, dot(m, at) * 20.0].map(|c| c.round() as i64 as u32);
	let rounded = |m: Vec3| m.map(|c| (c * 1000.0).round() as i64);
	let first = rounded(n) < rounded(facing);
	let sign = if first { 1.0 } else { -1.0 };
	let (one, two) = (plane(n, p), plane(facing, on_facing));
	let seed = if first { one.into_iter().chain(two) } else { two.into_iter().chain(one) }.fold(0x811c_9dc5u32, |h, c| (h ^ c).wrapping_mul(0x0100_0193));
	(seed, sign, dot(p, scale(crease, sign)) + 1000.0)
}

// A highlight's share at the edge point q, 1 at a corner and exactly nothing
// `end` taper lengths from it. None for a triangle that meets a run only at a
// vertex: the triangles lying along the run paint that edge.
fn to_zero_taper(p: Vec3, n: Vec3, q: Vec3, triangle: [Vec3; 3], runs: &HashMap<EdgeKey, (Vec3, Vec3)>, taper: f64, end: f64) -> Option<f64> {
	let along = match run_distance(q, triangle, runs) {
		Some(distance) => distance,
		None if triangle.iter().any(|v| runs.contains_key(&edge_key(*v, *v))) => return None,
		None => corner_distance(p, n, q, triangle),
	};
	let far = (-end).exp();
	Some((((-along / taper).exp() - far) / (1.0 - far)).max(0.0))
}

// How far the edge point q is from the nearest corner of its facing polygon.
fn corner_distance(p: Vec3, n: Vec3, q: Vec3, triangle: [Vec3; 3]) -> f64 {
	let mut nearest = f64::MAX;
	for v in triangle {
		if dot(n, sub(v, p)).abs() < TAPER_PLANE {
			let gap = sub(v, q);
			nearest = nearest.min(dot(gap, gap).sqrt());
		}
	}
	nearest
}

// How far a contact shadow spreads from the corner that casts it, unless the
// part asks for its own reach.
pub const CONTACT_REACH: f64 = 0.2;
// Folds gentler than this (as a fraction of a half turn) cast nothing,
// so the facets inside a rounded hollow stay clean.
pub const CONTACT_MIN_FOLD: f64 = 1.0 / 6.0;

// The soft highlight counts folds from SOFT_MIN_FOLD (a fraction of a half
// turn) and is at full strength from SOFT_FULL_FOLD, so a chamfer's gentle
// folds still glow.
const SOFT_MIN_FOLD: f64 = 0.08;
const SOFT_FULL_FOLD: f64 = 0.3;
// Studs between the soft highlight's width changes along an edge.
const SOFT_WANDER_STEP: f64 = 0.9;

// A smooth value from 0 to 1 wandering along an edge, t studs along it.
fn soft_wander(seed: u32, t: f64) -> f64 {
	let x = t / SOFT_WANDER_STEP;
	let cell = x.floor();
	let f = x - cell;
	let at = |k: i64| hash(seed.wrapping_add((k as u32).wrapping_mul(2_654_435_761)));
	at(cell as i64) + (at(cell as i64 + 1) - at(cell as i64)) * f * f * (3.0 - 2.0 * f)
}

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

// Texels a bake thread takes at a time. Threads take the next batch as they
// finish one, so a thread that drew slow texels (along creases) doesn't leave
// the others idle while it catches up.
const BATCH: usize = 1024;

pub fn parallel<I: Sync, T: Send, F: Fn(&I) -> T + Sync>(texels: &[I], work: F) -> Vec<T> {
	parallel_with(texels, || (), |_, texel| work(texel))
}

// Like parallel, with scratch state each thread keeps from texel to texel.
fn parallel_with<I: Sync, T: Send, S, N: Fn() -> S + Sync, F: Fn(&mut S, &I) -> T + Sync>(texels: &[I], new: N, work: F) -> Vec<T> {
	let threads = std::thread::available_parallelism().map_or(4, |n| n.get());
	let batches: Vec<&[I]> = texels.chunks(BATCH).collect();
	let next = AtomicUsize::new(0);
	let mut done: Vec<(usize, Vec<T>)> = std::thread::scope(|scope| {
		let handles: Vec<_> = (0..threads.min(batches.len()))
			.map(|_| {
				scope.spawn(|| {
					let mut mine = Vec::new();
					let mut state = new();
					loop {
						let at = next.fetch_add(1, Ordering::Relaxed);
						let Some(batch) = batches.get(at) else { break };
						mine.push((at, batch.iter().map(|texel| work(&mut state, texel)).collect::<Vec<T>>()));
					}
					mine
				})
			})
			.collect();
		handles.into_iter().flat_map(|h| h.join().expect("bake thread")).collect()
	});
	done.sort_unstable_by_key(|(at, _)| *at);
	done.into_iter().flat_map(|(_, values)| values).collect()
}

#[allow(clippy::too_many_arguments)]
pub fn paint_shading(mesh: &Mesh, group: &[&Mesh], group_sizes: &[(usize, usize)], group_index: usize, occluders: &[&Mesh], image: &mut Image, shading: &Shading, look: &coat::Look, base: &mut dyn FnMut(Vec3, Vec3) -> [f64; 3], source: &cache::Source) {
	let (width, height) = (image.width, image.height);
	let marks_reach = [&shading.edge_marks, &shading.shade_marks].into_iter().flatten().map(|marks| marks.reach()).fold(0.0, f64::max);
	let reach = shading.reach.max(0.02).max(marks_reach);
	let width_scale = shading.highlight_width.max(0.1);
	// The bevel field may run wider and count gentler folds than the strokes;
	// the grid gathers surfaces out to the larger reach, and each use fades
	// over its own.
	let bevel_reach = if shading.bevel_reach > 0.0 { shading.bevel_reach } else { reach };
	let bevel_fold = shading.bevel_fold.clamp(0.0, 0.49);
	let bevel_min_cos = (bevel_fold * std::f64::consts::PI).cos();
	let grid_reach = reach.max(bevel_reach);
	// Shadows and highlights both come from the corners a texel sits in: a
	// surface nearby that faces it makes an interior angle, which shades, and
	// one that faces away makes an exterior angle, which catches the light.
	// Either way the sharper the corner the stronger the paint, so rounded
	// facets stay clean. Only this part's own surfaces make exterior angles;
	// another part merely passing close by is not an edge of this one.
	// Only occluders close enough to reach this mesh can cast or catch anything.
	// The part's other chunks count as its own surfaces, so a chunk seam shades like
	// any other edge.
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

	// Each layer is cached on its own, so an edit only rebakes the layers it
	// reads. Layers hold per texel values, in the order of `full`.
	let neighbours: Vec<&Mesh> = group.iter().chain(occluders).copied().collect();
	// Each per-texel pass runs on the GPU when there is one (see gpu.rs), and
	// on the CPU threads otherwise.
	// A shared height range changes where low wear and the gradient fall, so
	// it keys the layers; without one the keys stay as they were.
	let range_key: Vec<f64> = shading.height_range.map_or_else(Vec::new, |r| r.to_vec());
	let drawn_key: Vec<f64> = if shading.strokes.is_empty() { Vec::new() } else { std::iter::once(shading.strokes.len() as f64).chain(shading.strokes.iter().flat_map(|stroke| stroke.marks.iter().flat_map(|marks| marks.numbers()))).collect() };
	// No colour goes in, so the texture size keys the layer instead, with the
	// reach and highlight width that shape the strokes.
	let shade_size = shade_key(width, height, shading, reach, width_scale, bevel_reach, bevel_fold);
	// The shade layer reads no colour, so it bakes on the other threads while
	// this one runs the coat, whose `base` calls back into Lua and so can only
	// run here. Its cache path is found here too: the paint cache is per thread.
	// Every chunk of the part: this one's edge field, and each sibling's, baked
	// once per run, so a stroke scattered on a neighbour reads the neighbour's.
	// The strokes themselves scatter over the whole part in group order, so
	// every chunk lays the same strokes and they run across chunk borders.
	let chunks: Vec<&Mesh> = if group.is_empty() { vec![mesh] } else { group.to_vec() };
	// Which chunk this is comes from the script, not a pointer: a shared bake
	// paints a copy of the mesh.
	let own_index = group_index.min(chunks.len() - 1);
	let own_box = bounds(mesh);
	let (near_low, near_high) = (own_box.0.map(|c| c - STROKE_REACH), own_box.1.map(|c| c + STROKE_REACH));
	let near = |p: Vec3| (0..3).all(|k| p[k] >= near_low[k] && p[k] <= near_high[k]);
	let (whole, tri_chunk, face_chunk) = merged_part(&chunks);
	let low_wear = |p: Vec3| 1.0 - generated(p)[2];
	// Only the new coats add to the key, so every other part keeps its cached coat.
	let style_numbers: Vec<f64> = if look.stamps || look.hand.is_some() {
		vec![f64::from(u8::from(look.stamps)), look.hand.map_or(0.0, |hand| 1.0 + hand as u8 as f64), crate::hand::VERSION, look.focus.map_or(0.0, |f| f.1), look.focus.map_or(0.0, |f| f.0[0]), look.focus.map_or(0.0, |f| f.0[1]), look.focus.map_or(0.0, |f| f.0[2])].into_iter().chain(look.tuning.iter().flat_map(|t| t.numbers())).collect()
	} else {
		Vec::new()
	};
	let coat_marks: Vec<f64> = look.brushes.coat.iter().flat_map(|marks| marks.numbers()).collect();
	// The coat and wear read the shade layer, so its key is part of theirs.
	let coat_numbers = [&[look.gradient, look.brush, f64::from(u8::from(shading.crisp))][..], &style_numbers, &coat_marks, &range_key, &drawn_key, &shade_size, &[STROKE_LAYOUT_VERSION]].concat();
	let coat_path = cache::layer_path("coat", mesh, &neighbours, false, &coat_numbers, Some(&*image), source);
	let shade_path = shade_layer_path(mesh, width, height, group, occluders, shading, source, reach, width_scale, bevel_reach, bevel_fold);
	// A stroke reads the field of the chunk its spot lies on, and only near
	// spots are drawn, so a sibling wholly outside the near box is never
	// read: it keeps an empty field and is not shaded here. A near sibling
	// shaded earlier in this run hands its field over; the rest are shaded
	// now, after this chunk's own pass.
	let mut fields: Vec<Arc<ChunkField>> = chunks.iter().map(|_| Arc::new(ChunkField { pixels: Vec::new(), width: 1, height: 1, tmp: None, tmpfull: None })).collect();
	let mut to_shade: Vec<(usize, &Mesh, usize, usize, Option<PathBuf>)> = Vec::new();
	for (k, chunk) in chunks.iter().enumerate() {
		if k == own_index {
			continue;
		}
		let (chunk_low, chunk_high) = bounds(chunk);
		if (0..3).any(|axis| chunk_high[axis] < near_low[axis] - coat::NEAR_SLACK || chunk_low[axis] > near_high[axis] + coat::NEAR_SLACK) {
			continue;
		}
		let (w, h) = group_sizes.get(k).copied().unwrap_or((width, height));
		match sibling_ready(chunk, w, h, (near_low, near_high)) {
			Some(field) => fields[k] = field,
			// The paint cache is per thread, so the path is found here.
			None => to_shade.push((k, *chunk, w, h, shade_layer_path(chunk, w, h, group, occluders, shading, source, reach, width_scale, bevel_reach, bevel_fold))),
		}
	}
	let shade_all = move || {
		let pass = shade_pass(mesh, width, height, group, occluders, shading, source, reach, width_scale, bevel_reach, bevel_fold, grid_reach, bevel_min_cos, shade_path, None);
		let siblings: Vec<(usize, Arc<ChunkField>)> = to_shade.into_iter().map(|(k, chunk, w, h, path)| (k, sibling_field(chunk, w, h, group, occluders, shading, source, reach, width_scale, bevel_reach, bevel_fold, grid_reach, bevel_min_cos, path, (near_low, near_high)))).collect();
		(pass, siblings)
	};
	// With a brushed coat to lay and none cached, the shading and the coat run
	// side by side: the shade passes fill the other threads while this one
	// lays the coat's strokes, whose colours come from the script and so can
	// only be asked here. Those strokes read nothing the shade passes make.
	let coat_early = look.hand.is_none() && !shading.crisp && coat_path.as_ref().map_or(true, |path| !path.exists());
	let ((pass, siblings), mut early_canvas) = if coat_early {
		let unread = |_: usize, _: [f64; 2]| -> f64 { unreachable!("the coat's strokes read no edge field") };
		let early_wear = coat::Wear { edge: &unread, crease: &unread, low: &low_wear, near: &near, near_box: Some((near_low, near_high)), own_box: Some(own_box), tri_chunk: &tri_chunk, face_chunk: &face_chunk };
		std::thread::scope(|scope| {
			let shade = scope.spawn(shade_all);
			let canvas = profiled(1, || coat::coat(&whole, look, &early_wear, base));
			(shade.join().expect("shade pass"), Some(canvas))
		})
	} else {
		(shade_all(), None)
	};
	let ShadePass { full, layers: shade_layer, edge_field: own_field, .. } = pass;
	fields[own_index] = Arc::new(ChunkField { pixels: own_field.clone(), width, height, tmp: None, tmpfull: None });
	for (k, field) in siblings {
		fields[k] = field;
	}
	let field_at = |chunk: usize, uv: [f64; 2], channel: usize| -> f64 {
		let field = &fields[chunk.min(fields.len() - 1)];
		assert!(!field.pixels.is_empty(), "a stroke read the edge field of a chunk out of its reach");
		let x = ((uv[0] * field.width as f64 - 0.5).round().max(0.0) as usize).min(field.width - 1);
		let y = ((uv[1] * field.height as f64 - 0.5).round().max(0.0) as usize).min(field.height - 1);
		if let Some(mask) = &field.tmp {
			for dy in -2i64..=2 {
				for dx in -2i64..=2 {
					let (nx, ny) = (x as i64 + dx, y as i64 + dy);
					if nx >= 0 && ny >= 0 && (nx as usize) < field.width && (ny as usize) < field.height && !mask[ny as usize * field.width + nx as usize] {
						eprintln!("TMPMISS chunk {chunk} own {own_index} uv {uv:?} pixel ({x},{y}) size {}x{} hole ({nx},{ny})", field.width, field.height);
					}
				}
			}
		}
		if let Some(full) = &field.tmpfull { if full[y * field.width + x] != field.pixels[y * field.width + x] { eprintln!("TMPDIFF chunk {chunk} own {own_index} pixel ({x},{y}) full {:?} partial {:?}", full[y * field.width + x], field.pixels[y * field.width + x]); } }
		f64::from(field.pixels[y * field.width + x][channel])
	};
	// Every color comes from strokes laid on a canvas, wear gathering on
	// sharp edges, in creases and low down.
	let edge_wear = |chunk: usize, uv: [f64; 2]| (field_at(chunk, uv, 1) * 2.5).min(1.0);
	let crease_wear = |chunk: usize, uv: [f64; 2]| (field_at(chunk, uv, 0) * 2.5).min(1.0);
	let wear = coat::Wear { edge: &edge_wear, crease: &crease_wear, low: &low_wear, near: &near, near_box: Some((near_low, near_high)), own_box: Some(own_box), tri_chunk: &tri_chunk, face_chunk: &face_chunk };
	let (coat_layer, wear_layer) = {
		let coat_layer = profiled(1, || cached_layer(coat_path, || {
			if let Some(hand) = look.hand {
				let tuning = look.tuning.as_ref().expect("hand coat has tuning");
				if shading.crisp {
					// Shapes stay exact: the brushwork is painted in plain grey, and only
					// its lightening and darkening reach the part's own colours.
					let painting = crate::hand::prepare(&whole, look, hand, tuning, &wear, &mut |_, _| [0.5; 3]);
					let grey = to_linear(0.5);
					let brushed = parallel(&full, |t| painting.colour(t.position, t.face_normal));
					let colours: Vec<[f32; 3]> = full.iter().zip(brushed).map(|(t, brush)| {
						let exact = base(t.position, t.face_normal).map(|c| to_linear(c as f32));
						to_f32(std::array::from_fn(|k| {
							let ratio = (brush[k] / grey).clamp(0.5, 1.7);
							exact[k] * ratio + (ratio - 1.0).max(0.0) * 0.04
						}))
					}).collect();
					return vec![layer_image(width, height, &full, &colours)];
				}
				let painting = crate::hand::prepare(&whole, look, hand, tuning, &wear, base);
				let colours: Vec<[f32; 3]> = parallel(&full, |t| to_f32(painting.colour(t.position, t.face_normal)));
				return vec![layer_image(width, height, &full, &colours)];
			}
			if shading.crisp {
				// `base` calls into Lua, so this runs on this thread alone.
				let colours: Vec<[f32; 3]> = full.iter().map(|t| to_f32(coat::base_at(look, &wear, base, t.position, t.face_normal))).collect();
				return vec![layer_image(width, height, &full, &colours)];
			}
			let mut canvas = match early_canvas.take() {
				Some(canvas) => canvas,
				None => coat::coat(&whole, look, &wear, base),
			};
			// A part's own strokes may be listed for the whole of a chunked
			// part; only those that can touch this chunk are laid.
			for stroke in &shading.strokes {
				if wear.out_of_touch(stroke.centre(), stroke.reach() + canvas.cell_size()) {
					continue;
				}
				canvas.add(stroke.clone());
			}
			let stage = Instant::now();
			let colours = match gpu::canvas(&canvas, &full, false) {
				Some(painted) => painted.into_iter().map(|(c, _)| to_f32(c)).collect(),
				None => parallel(&full, |t| to_f32(canvas.paint(t.position, t.face_normal))),
			};
			timed(7, stage);
			vec![layer_image(width, height, &full, &colours)]
		}));
		let wear_numbers = [&[look.rust, f64::from(u8::from(look.rubber)), f64::from(u8::from(look.rust_edges)), look.gradient, look.brush][..], &range_key, &look.brushes.wear_numbers(), &shade_size, &[STROKE_LAYOUT_VERSION]].concat();
		let wear_layer = profiled(2, || cached_layer(cache::layer_path("wear", mesh, &neighbours, true, &wear_numbers, Some(&*image), source), || {
			let canvas = coat::wear(&whole, look, &wear, base);
			let over = gpu::canvas(&canvas, &full, true).unwrap_or_else(|| parallel(&full, |t| canvas.over(t.position, t.face_normal)));
			let colour: Vec<[f32; 3]> = over.iter().map(|(c, _)| to_f32(*c)).collect();
			let cover: Vec<[f32; 3]> = over.iter().map(|(_, a)| [*a as f32, 0.0, 0.0]).collect();
			vec![layer_image(width, height, &full, &colour), layer_image(width, height, &full, &cover)]
		}));
		(coat_layer, wear_layer)
	};

	{
		use std::hash::{Hash, Hasher};
		let h = |px: &[[f32; 3]]| { let mut s = std::collections::hash_map::DefaultHasher::new(); for p in px { for c in p { c.to_bits().hash(&mut s); } } s.finish() };
		eprintln!("TMPL {} {:?} shade {:x} tilt {:x} coat {:x} wear {:x} cover {:x}", mesh.positions.len(), mesh.positions.first(), h(&shade_layer[0].pixels), h(&shade_layer[1].pixels), h(&coat_layer[0].pixels), h(&wear_layer[0].pixels), h(&wear_layer[1].pixels));
	}
	// The soft highlight: a smooth glow falling away from this part's exterior
	// edges, with no brush in it. It reaches further than the strokes, so it
	// has its own grid of the part's surfaces.
	let soft_reach = shading.soft_reach.max(0.02);
	let mut soft_numbers = vec![width as f64, height as f64, soft_reach, shading.soft_uneven, shading.soft_taper];
	if shading.soft_to_zero || shading.soft_power != 1.0 {
		soft_numbers.extend([f64::from(u8::from(shading.soft_to_zero)), shading.soft_power, shading.soft_end, 4.0]);
	}
	soft_numbers.extend(shading.soft_marks.iter().flat_map(|marks| marks.numbers()));
	let soft_layer = (shading.soft_highlight > 0.0).then(|| cached_layer(cache::layer_path("soft", mesh, &neighbours, true, &soft_numbers, None, source), || {
		let mut triangles = mesh_triangles(mesh);
		for other in group {
			if within_reach(mesh, other, soft_reach) {
				triangles.extend(mesh_triangles(other));
			}
		}
		let planes: Vec<([Vec3; 3], Vec3)> = triangles
			.into_iter()
			.filter_map(|t| {
				let n = cross(sub(t[1], t[0]), sub(t[2], t[0]));
				let length = dot(n, n).sqrt();
				(length > 1e-12).then(|| (t, scale(n, 1.0 / length)))
			})
			.collect();
		let key = |p: Vec3| p.map(|c| (c / soft_reach).floor() as i64);
		let cell_reach = soft_reach * 3f64.sqrt() / 2.0;
		let mut grid: CellMap<Vec<usize>> = CellMap::default();
		for (index, (t, facing)) in planes.iter().enumerate() {
			let low = key([0, 1, 2].map(|k| t[0][k].min(t[1][k]).min(t[2][k])));
			let high = key([0, 1, 2].map(|k| t[0][k].max(t[1][k]).max(t[2][k])));
			for x in low[0]..=high[0] {
				for y in low[1]..=high[1] {
					for z in low[2]..=high[2] {
						let centre = [x, y, z].map(|c| (c as f64 + 0.5) * soft_reach);
						if dot(*facing, sub(centre, t[0])).abs() <= cell_reach {
							grid.entry([x, y, z]).or_default().push(index);
						}
					}
				}
			}
		}
		let mut near: CellMap<Vec<usize>> = CellMap::default();
		for texel in &full {
			let home = key(texel.position);
			near.entry(home).or_insert_with(|| {
				let mut list = Vec::new();
				for x in -1..=1 {
					for y in -1..=1 {
						for z in -1..=1 {
							list.extend(grid.get(&[home[0] + x, home[1] + y, home[2] + z]).into_iter().flatten());
						}
					}
				}
				list.sort_unstable();
				list.dedup();
				list
			});
		}
		let min_cos = (SOFT_MIN_FOLD * std::f64::consts::PI).cos();
		let runs = if shading.soft_to_zero { crease_runs(&planes, min_cos) } else { HashMap::new() };
		let values: Vec<[f32; 3]> = parallel(&full, |texel| {
			let (p, n) = (texel.position, texel.face_normal);
			let mut glow = 0.0f64;
			for &index in &near[&key(p)] {
				let (triangle, facing) = planes[index];
				if dot(n, facing) >= min_cos || dot(facing, sub(p, triangle[0])).abs() >= soft_reach {
					continue;
				}
				let offset = sub(p, closest_on_triangle(p, triangle));
				let distance = dot(offset, offset).sqrt();
				// Only exterior angles glow: the texel sits behind the surface's plane.
				if distance < 1e-6 || distance >= soft_reach || dot(facing, offset) >= 0.0 || dot(n, offset) > 0.3 * distance {
					continue;
				}
				let fold = dot(n, facing).clamp(-1.0, 1.0).acos() / std::f64::consts::PI;
				let sharpness = ((fold - SOFT_MIN_FOLD) / (SOFT_FULL_FOLD - SOFT_MIN_FOLD)).clamp(0.0, 1.0);
				// The width wanders along the edge, the same for every triangle
				// on it, and thins away from the edge's corners.
				let crease = normalize(cross(n, facing));
				let seed = [n[0] * 8.0, n[1] * 8.0, n[2] * 8.0, facing[0] * 8.0, facing[1] * 8.0, facing[2] * 8.0, dot(facing, triangle[0]) * 20.0]
					.map(|c| c.round() as i64 as u32)
					.into_iter()
					.fold(0x811c_9dc5u32, |h, c| (h ^ c).wrapping_mul(0x0100_0193));
				let wander = 1.0 - shading.soft_uneven + shading.soft_uneven * soft_wander(seed, dot(p, crease) + 1000.0);
				let mut strength = 1.0;
				let taper = if shading.soft_to_zero && shading.soft_taper > 0.0 {
					let Some(share) = to_zero_taper(p, n, sub(p, offset), triangle, &runs, shading.soft_taper, shading.soft_end) else {
						continue;
					};
					strength = share;
					strength
				} else if shading.soft_taper > 0.0 {
					corner_taper(p, n, sub(p, offset), triangle, shading.soft_taper)
				} else {
					1.0
				};
				let fade = soft_reach * wander * taper;
				if distance >= fade {
					continue;
				}
				let t = 1.0 - distance / fade;
				// A motion masks the glow, scaled so it fills the soft reach.
				let mask = shading.soft_marks.as_ref().map_or(1.0, |marks| {
					let (shared, sign, along_edge) = edge_frame(n, facing, p, triangle[0], crease);
					let size = soft_reach / marks.reach().max(1e-6);
					marks.paint(&crate::marks::Place { seed: shared, along: along_edge / size, off: sign * distance / size, taper: 1.0, corner: None, below: n[2] <= facing[2] + 1e-6 })
				});
				glow = glow.max(sharpness * strength * mask * (t * t * (3.0 - 2.0 * t)).powf(shading.soft_power));
			}
			[glow as f32, 0.0, 0.0]
		});
		vec![layer_image(width, height, &full, &values)]
	}));

	// Combine the layers per texel: the wear over the coat, then the lit and
	// dark creases, then the bands.
	let colors = profiled(3, || parallel(&full, |texel| {
		let g = generated(texel.position);
		let coat_colour = coat_layer[0].pixels[texel.pixel].map(f64::from);
		let wear_colour = wear_layer[0].pixels[texel.pixel].map(f64::from);
		let cover = f64::from(wear_layer[1].pixels[texel.pixel][0]);
		let mut color: [f64; 3] = std::array::from_fn(|k| coat_colour[k] + (wear_colour[k] - coat_colour[k]) * cover);
		let [shade, outward, _] = shade_layer[0].pixels[texel.pixel].map(f64::from);
		let low = 1.0 - g[2];
		let ramp = 1.0 + shading.highlight_ramp * low * low * (3.0 - 2.0 * low);
		let lit = (outward * (1.0 - shade) * shading.highlight * ramp).clamp(0.0, 1.0);
		let soft = soft_layer.as_ref().map_or(0.0, |layer| f64::from(layer[0].pixels[texel.pixel][0]));
		let glow = (soft * (1.0 - shade) * shading.soft_highlight).clamp(0.0, 1.0);
		let lit = 1.0 - (1.0 - lit) * (1.0 - glow);
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
	}));
	let mut covered = vec![false; width * height];
	for (texel, color) in full.iter().zip(colors) {
		image.pixels[texel.pixel] = color;
		covered[texel.pixel] = true;
	}
	dilate(&mut image.pixels, &mut covered, width, height, 8);

	// The normal map, from what the shade layer stored: the surface tilts
	// toward the nearest sharp edge (the bevel field's direction) by as much
	// as the edge highlight is painted there, so the tilt follows the strokes'
	// width and their wander along the edge, and the edge reads as a sharp,
	// worn rim rather than a rounded one. Flat everywhere unpainted.
	if let Some(strength) = normal_strength().map(|s| s * shading.bevel_tilt) {
		let mut normals = vec![[0.5, 0.5, 1.0]; width * height];
		let mut painted = vec![false; width * height];
		for texel in &full {
			let tilt = shade_layer[1].pixels[texel.pixel].map(f64::from);
			let length = dot(tilt, tilt).sqrt();
			let stroke = rim(f64::from(shade_layer[0].pixels[texel.pixel][1]));
			let amount = if length > 1e-6 { stroke * strength / length } else { 0.0 };
			let normal = normalize([dot(tilt, texel.tangent) * amount, dot(tilt, texel.bitangent) * amount, 1.0]);
			normals[texel.pixel] = normal.map(|c| (c as f32 + 1.0) / 2.0);
			painted[texel.pixel] = true;
		}
		dilate(&mut normals, &mut painted, width, height, 8);
		image.normal = Some(normals);
	}

	// The roughness map, from the same stored layers: the material's base,
	// polished down along the painted edge highlights, roughened in the
	// crease shade and under the wear.
	if shading.roughness_base > 0.0 {
		let mut rough = vec![[shading.roughness_base as f32, 0.0, 0.0]; width * height];
		let mut painted = vec![false; width * height];
		for texel in &full {
			let [shade, outward, _] = shade_layer[0].pixels[texel.pixel].map(f64::from);
			let cover = f64::from(wear_layer[1].pixels[texel.pixel][0]);
			let value = shading.roughness_base + shading.roughness_edge * rim(outward) + shading.roughness_crease * shade + shading.roughness_wear * cover;
			rough[texel.pixel] = [value.clamp(0.0, 1.0) as f32, 0.0, 0.0];
			painted[texel.pixel] = true;
		}
		dilate(&mut rough, &mut painted, width, height, 8);
		image.roughness = Some(rough.into_iter().map(|r| r[0]).collect());
	}
	if shading.metalness_on {
		let mut metal = vec![[shading.metalness_base as f32, 0.0, 0.0]; width * height];
		let mut painted = vec![false; width * height];
		for texel in &full {
			let [shade, outward, _] = shade_layer[0].pixels[texel.pixel].map(f64::from);
			let cover = f64::from(wear_layer[1].pixels[texel.pixel][0]);
			let value = shading.metalness_base + shading.metalness_edge * rim(outward) + shading.metalness_crease * shade + shading.metalness_wear * cover;
			metal[texel.pixel] = [value.clamp(0.0, 1.0) as f32, 0.0, 0.0];
			painted[texel.pixel] = true;
		}
		dilate(&mut metal, &mut painted, width, height, 8);
		image.metalness = Some(metal.into_iter().map(|m| m[0]).collect());
	}
}


// The shade pass for one chunk of a part: its texels, its shade layers (the
// crease and highlight paint, and the bevel tilt) and its edge field, the paint
// spread two texels past the painted ones so a stroke at a triangle's border
// still reads its edge. A chunk's siblings are its own surfaces; the chunk
// itself is skipped when it stands in the group list.
pub struct ShadePass {
	pub full: Vec<Texel>,
	pub layers: Vec<Image>,
	pub edge_field: Vec<[f32; 3]>,
	pub width: usize,
	pub height: usize,
}

#[allow(clippy::too_many_arguments)]
// Where a mesh's shade layer is cached. The paint cache is per thread, so
// this is asked on the thread that runs the script, before the pass itself
// may go to another.
#[allow(clippy::too_many_arguments)]
fn shade_layer_path(target: &Mesh, width: usize, height: usize, group: &[&Mesh], occluders: &[&Mesh], shading: &Shading, source: &cache::Source, reach: f64, width_scale: f64, bevel_reach: f64, bevel_fold: f64) -> Option<PathBuf> {
	let neighbours: Vec<&Mesh> = group.iter().chain(occluders).copied().collect();
	let shade_size = shade_key(width, height, shading, reach, width_scale, bevel_reach, bevel_fold);
	cache::layer_path("shade", target, &neighbours, true, &shade_size, None, source)
}

fn shade_pass(target: &Mesh, width: usize, height: usize, group: &[&Mesh], occluders: &[&Mesh], shading: &Shading, source: &cache::Source, reach: f64, width_scale: f64, bevel_reach: f64, bevel_fold: f64, grid_reach: f64, bevel_min_cos: f64, shade_path: Option<PathBuf>, only: Option<NearBox>) -> ShadePass {
	let stage = Instant::now();
	let mut triangles = mesh_triangles(target);
	for other in group {
		if std::ptr::eq(*other, target) {
			continue;
		}
		if within_reach(target, other, reach) {
			triangles.extend(mesh_triangles(other));
		}
	}
	let own = triangles.len();
	for other in occluders {
		if within_reach(target, other, reach) {
			triangles.extend(mesh_triangles(other));
		}
	}
	// Texels only ever look within reach of this mesh, so surfaces
	// outside that box are dropped and big ones only fill the grid inside it.
	let (mesh_low, mesh_high) = bounds(target);
	let reach_low = mesh_low.map(|c| c - grid_reach);
	let reach_high = mesh_high.map(|c| c + grid_reach);
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
	// The box round each surface, grown by the reach and a hair: a texel
	// outside it is further from the surface than the reach, and is turned
	// away before the nearest point on the triangle is worked out.
	let boxes: Vec<(Vec3, Vec3)> = surfaces
		.iter()
		.map(|(t, _, _)| {
			let low: Vec3 = std::array::from_fn(|k| t[0][k].min(t[1][k]).min(t[2][k]) - grid_reach - 1e-9);
			let high: Vec3 = std::array::from_fn(|k| t[0][k].max(t[1][k]).max(t[2][k]) + grid_reach + 1e-9);
			(low, high)
		})
		.collect();
	let contact_key = |p: Vec3| p.map(|c| (c / grid_reach).floor() as i64);
	// Dot products at or above this are folds gentler than CONTACT_MIN_FOLD.
	let min_cos = (CONTACT_MIN_FOLD * std::f64::consts::PI).cos();
	let mut contact_grid: CellMap<Vec<usize>> = CellMap::default();
	let (key_low, key_high) = (contact_key(reach_low), contact_key(reach_high));
	// A cell whose centre is further than this from a plane can't touch it.
	let cell_reach = grid_reach * 3f64.sqrt() / 2.0;
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
					let centre = [x, y, z].map(|c| (c as f64 + 0.5) * grid_reach);
					if dot(*facing, sub(centre, t[0])).abs() > cell_reach {
						continue;
					}
					contact_grid.entry([x, y, z]).or_default().push(index);
				}
			}
		}
	}
	// The surfaces near a cell: those in it and its 26 neighbours, each once.
	// A surface crossing several of those cells is filed in each, so without
	// this a texel would test it once per cell. Every texel's home cell is
	// gathered up front; other points (wear strokes) gather theirs as needed.
	let neighbourhood = |home: [i64; 3]| -> Vec<usize> {
		let mut near = Vec::new();
		for x in -1..=1 {
			for y in -1..=1 {
				for z in -1..=1 {
					near.extend(contact_grid.get(&[home[0] + x, home[1] + y, home[2] + z]).into_iter().flatten());
				}
			}
		}
		near.sort_unstable();
		near.dedup();
		near
	};
	// A sibling shaded only for its edge field near another chunk paints just
	// the texels strokes there can read. Texels of triangles wholly away from
	// those are not even found, and the rest found but off them stay unpainted:
	// neither is within the field's two pixels of spreading of a read pixel,
	// so the field is exactly as before wherever it is read.
	let readable = only.map(|near| readable_pixels(target, width, height, near));
	let full = samples_in(target, width, height, 1, readable.as_deref());
	let painted = |texel: &Texel| readable.as_ref().map_or(true, |readable| readable[texel.pixel]);
	timed(4, stage);
	let stage = Instant::now();
	let mut neighbourhoods: CellMap<Vec<usize>> = CellMap::default();
	for texel in full.iter().filter(|texel| painted(texel)) {
		let home = contact_key(texel.position);
		neighbourhoods.entry(home).or_insert_with(|| neighbourhood(home));
	}
	timed(5, stage);
	let highlight_runs = if shading.highlight_to_zero || shading.edge_marks.is_some() || shading.shade_marks.is_some() {
		crease_runs(&surfaces.iter().filter(|s| s.2).map(|s| (s.0, s.1)).collect::<Vec<_>>(), min_cos)
	} else {
		HashMap::new()
	};
	// Paint laid along the corners at p, `outward` for exterior angles.
	// One pass over the surfaces near p: the strongest interior-angle paint, and
	// the strongest exterior-angle paint from this part's own surfaces.
	// Alongside the paint comes the bevel field for the normal map: the
	// surface direction toward the nearest sharp exterior edge, scaled by
	// how near and sharp it is, from the geometry alone (no strokes).
	// The surfaces near a cell that fold against one normal, with their dot
	// products, in neighbourhood order. Texels of a triangle share its cell and
	// normal and come in a row, so each thread keeps the last such list.
	type Folding = (Option<([i64; 3], [u64; 3])>, Vec<(usize, f64)>);
	let crease_paint = |folding: &mut Folding, p: Vec3, n: Vec3| -> (f64, f64, Vec3) {
		let home = contact_key(p);
		let key = (home, n.map(f64::to_bits));
		if folding.0 != Some(key) {
			let gathered;
			let near: &[usize] = match neighbourhoods.get(&home) {
				Some(near) => near,
				None => {
					gathered = neighbourhood(home);
					&gathered
				}
			};
			// A fold gentler than CONTACT_MIN_FOLD casts nothing, and one gentler
			// than the bevel's own threshold tilts nothing; a surface that does
			// neither is dropped before any distance work.
			folding.1.clear();
			for &index in near {
				let (_, facing, mine) = surfaces[index];
				let facing_dot = dot(n, facing);
				if facing_dot < min_cos || (mine && facing_dot < bevel_min_cos) {
					folding.1.push((index, facing_dot));
				}
			}
			folding.0 = Some(key);
		}
		let (mut inward, mut outward) = (0.0f64, 0.0f64);
		let (mut bevel, mut tilt) = (0.0f64, [0.0; 3]);
		for &(index, facing_dot) in &folding.1 {
			let (triangle, facing, mine) = surfaces[index];
			let paints = facing_dot < min_cos;
			let bevels = mine && facing_dot < bevel_min_cos;
			// Nor does a surface whose plane is out of reach: the triangle is
			// never nearer than its plane.
			if dot(facing, sub(p, triangle[0])).abs() >= grid_reach {
				continue;
			}
			let (box_low, box_high) = boxes[index];
			if (0..3).any(|k| p[k] < box_low[k] || p[k] > box_high[k]) {
				continue;
			}
			let offset = sub(p, closest_on_triangle(p, triangle));
			let distance = dot(offset, offset).sqrt();
			// An interior angle's surface faces the texel, so the texel sits in
			// front of its plane; an exterior angle's faces away, so behind it.
			let side = dot(facing, offset);
			let front = side > 0.0;
			let behind = side < 0.0 && mine;
			if distance < 1e-6 || distance >= grid_reach || !(front || behind) || dot(n, offset) > 0.3 * distance {
				continue;
			}
			// 0 for a flat continuation, 1 for a right angle or anything sharper.
			let fold = facing_dot.clamp(-1.0, 1.0).acos() / std::f64::consts::PI;
			if behind && bevels && distance < bevel_reach {
				let proximity = ((fold - bevel_fold) / (0.5 - bevel_fold)).clamp(0.0, 1.0) * (1.0 - distance / bevel_reach);
				if proximity > bevel {
					let toward = sub(scale(n, dot(n, offset)), offset);
					let length = dot(toward, toward).sqrt();
					if length > 1e-9 {
						bevel = proximity;
						tilt = scale(toward, proximity / length);
					}
				}
			}
			if !paints || distance >= reach {
				continue;
			}
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
			let mut taper = if behind && shading.corner_taper > 0.0 && shading.highlight_to_zero {
				let Some(share) = to_zero_taper(p, n, sub(p, offset), triangle, &highlight_runs, shading.corner_taper, shading.highlight_end) else {
					continue;
				};
				share
			} else if behind && shading.corner_taper > 0.0 {
				corner_taper(p, n, sub(p, offset), triangle, shading.corner_taper)
			} else {
				1.0
			};
			if behind && shading.highlight_uneven > 0.0 {
				taper *= 1.0 - shading.highlight_uneven + shading.highlight_uneven * soft_wander(seed, along * SOFT_WANDER_STEP / shading.highlight_uneven_step.max(0.01));
			}
			let marks = if behind { shading.edge_marks.as_ref() } else { shading.shade_marks.as_ref() };
			if let Some(marks) = marks {
				let (shared, sign, along_edge) = edge_frame(n, facing, p, triangle[0], crease);
				let place = crate::marks::Place {
					seed: shared,
					along: along_edge,
					off: sign * distance,
					taper,
					corner: run_distance(sub(p, offset), triangle, &highlight_runs),
					below: n[2] <= facing[2] + 1e-6,
				};
				let paint = sharpness * marks.paint(&place);
				if behind {
					outward = outward.max(paint);
				} else {
					inward = inward.max(paint);
				}
				continue;
			}
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
		(inward, outward, tilt)
	};
	let bake_shade = || {
		// Uneven, to-nothing and hand-moved highlights are CPU only.
		let on_gpu = if shading.highlight_uneven > 0.0 || shading.highlight_to_zero || shading.edge_marks.is_some() || shading.shade_marks.is_some() { None } else { gpu::crease(&full, &surfaces, &contact_grid, min_cos, reach, grid_reach, bevel_reach, bevel_fold, width_scale, shading.painted_highlights, shading.corner_taper) };
		let creases = on_gpu.unwrap_or_else(|| parallel_with(&full, || (None, Vec::new()), |folding, t| if painted(t) { crease_paint(folding, t.position, t.face_normal) } else { (0.0, 0.0, [0.0; 3]) }));
		let values: Vec<[f32; 3]> = creases.iter().map(|(shade, outward, _)| [*shade as f32, *outward as f32, 0.0]).collect();
		let tilts: Vec<[f32; 3]> = creases.iter().map(|(_, _, tilt)| tilt.map(|c| c as f32)).collect();
		vec![layer_image(width, height, &full, &values), layer_image(width, height, &full, &tilts)]
	};
	// A partly painted layer may read a whole cached one but is never cached itself.
	let layers = profiled(0, || if readable.is_some() { shade_path.as_deref().and_then(cache::load_layers).unwrap_or_else(bake_shade) } else { cached_layer(shade_path, bake_shade) });
	let mut edge_field = layers[0].pixels.clone();
	let mut covered = vec![false; width * height];
	for texel in &full {
		covered[texel.pixel] = true;
	}
	let stage = Instant::now();
	// Read pixels lie well inside the readable ones, so spreading only there is exact.
	dilate_within(&mut edge_field, &mut covered, width, height, 2, readable.as_deref());
	timed(6, stage);
	ShadePass { full, layers, edge_field, width, height }
}

// The numbers that key a shade layer: no colour goes in, so the texture size
// keys it, with the reach and highlight width that shape the strokes.
fn shade_key(width: usize, height: usize, shading: &Shading, reach: f64, width_scale: f64, bevel_reach: f64, bevel_fold: f64) -> Vec<f64> {
	[width as f64, height as f64, reach, width_scale, SHADE_LAYER_VERSION, bevel_reach, bevel_fold]
		.into_iter()
		.chain(shading.painted_highlights.then_some(2.0))
		.chain((shading.corner_taper > 0.0).then_some(shading.corner_taper + 4.0))
		.chain((shading.highlight_uneven > 0.0).then_some(shading.highlight_uneven + 8.0))
		.chain((shading.highlight_uneven > 0.0).then_some(shading.highlight_uneven_step + 16.0))
		.chain(shading.highlight_to_zero.then_some(shading.highlight_end + 40.0))
		.chain([&shading.edge_marks, &shading.shade_marks].into_iter().flat_map(|motion| motion.iter().flat_map(|marks| marks.numbers()).chain([-1.0])))
		.collect()
}

// One chunk's edge field, read by strokes that lie on it: a sibling's is baked
// once per run and kept, keyed by the mesh and its texture size.
pub struct ChunkField {
	pub tmp: Option<Vec<bool>>,
	pub tmpfull: Option<Vec<[f32; 3]>>,
	pub pixels: Vec<[f32; 3]>,
	pub width: usize,
	pub height: usize,
}

// Each sibling field with the near box it was shaded for: a field is only
// right where strokes inside that box can read it (see shade_pass).
type NearBox = (Vec3, Vec3);
static SIBLING_FIELDS: std::sync::Mutex<Option<HashMap<(usize, usize, usize), (Arc<ChunkField>, NearBox)>>> = std::sync::Mutex::new(None);

// A sibling's field, if an earlier chunk of this run already had it shaded
// for a near box holding this one.
fn sibling_ready(chunk: &Mesh, width: usize, height: usize, near: NearBox) -> Option<Arc<ChunkField>> {
	let key = (chunk as *const Mesh as usize, width, height);
	let mut fields = SIBLING_FIELDS.lock().expect("sibling fields");
	let (field, (low, high)) = fields.get_or_insert_with(HashMap::new).get(&key)?;
	let inside = (0..3).all(|k| low[k] <= near.0[k] && high[k] >= near.1[k]);
	let same = field.tmp.as_ref().is_some_and(|m| *m == readable_pixels(chunk, width, height, (*low, *high)));
	eprintln!("TMPSIB found contained={inside} same_mesh_mask={same}");
	inside.then(|| field.clone())
}

#[allow(clippy::too_many_arguments)]
fn sibling_field(chunk: &Mesh, width: usize, height: usize, group: &[&Mesh], occluders: &[&Mesh], shading: &Shading, source: &cache::Source, reach: f64, width_scale: f64, bevel_reach: f64, bevel_fold: f64, grid_reach: f64, bevel_min_cos: f64, shade_path: Option<PathBuf>, near: NearBox) -> Arc<ChunkField> {
	let key = (chunk as *const Mesh as usize, width, height);
	let pass = shade_pass(chunk, width, height, group, occluders, shading, source, reach, width_scale, bevel_reach, bevel_fold, grid_reach, bevel_min_cos, shade_path, Some(near));
	let field = Arc::new(ChunkField { pixels: pass.edge_field, width, height, tmp: Some(readable_pixels(chunk, width, height, near)), tmpfull: Some(shade_pass(chunk, width, height, group, occluders, shading, source, reach, width_scale, bevel_reach, bevel_fold, grid_reach, bevel_min_cos, None, None).edge_field) });
	if let Some((old, _)) = SIBLING_FIELDS.lock().expect("sibling fields").get_or_insert_with(HashMap::new).get(&key) {
		let (a, b) = (old.tmpfull.as_ref().unwrap(), field.tmpfull.as_ref().unwrap());
		let differ = a.iter().zip(b).filter(|(x, y)| x != y).count();
		eprintln!("TMPREPL full fields differ at {differ} of {} pixels; group {} occluders {} positions {} faces {}", a.len(), group.len(), occluders.len(), chunk.positions.len(), chunk.faces.len());
	}
	SIBLING_FIELDS.lock().expect("sibling fields").get_or_insert_with(HashMap::new).insert(key, (field.clone(), near));
	field
}

// The pixels of a sibling's field a stroke inside the near box can come to:
// a stroke reads the pixel nearest its spot's UV, and spots lie on triangles
// touching the box (coat::scatter, hand::candidates), so the pixels whose
// centres lie within half a pixel of such a triangle in UV, and those within
// two more of them for the edge field's spreading, which mixes in neighbours
// two pixels off: all within 2.5 pixels each way, so within MARGIN.
fn readable_pixels(mesh: &Mesh, width: usize, height: usize, (low, high): NearBox) -> Vec<bool> {
	const MARGIN: f64 = 4.0;
	let mut readable = vec![false; width * height];
	let slack = coat::NEAR_SLACK * 1000.0;
	for face in &mesh.faces {
		let uv_at = |k: usize| face.uvs.as_ref().map_or([0.0, 0.0], |uvs| uvs[k]);
		for tri in 1..face.verts.len().saturating_sub(1) {
			let corners = [0, tri, tri + 1];
			let t = corners.map(|k| mesh.positions[face.verts[k]]);
			if (0..3).any(|k| t[0][k].max(t[1][k]).max(t[2][k]) < low[k] - slack || t[0][k].min(t[1][k]).min(t[2][k]) > high[k] + slack) {
				continue;
			}
			// Only the part of the triangle inside the box holds spots: clip it
			// there, as a polygon over the spot's two barycentric weights.
			let mut weights: Vec<[f64; 2]> = vec![[0.0, 0.0], [1.0, 0.0], [0.0, 1.0]];
			for axis in 0..3 {
				let along = |w: [f64; 2]| t[0][axis] + (t[1][axis] - t[0][axis]) * w[0] + (t[2][axis] - t[0][axis]) * w[1];
				weights = clip_polygon(&weights, |w| along(w) - (low[axis] - slack));
				weights = clip_polygon(&weights, |w| (high[axis] + slack) - along(w));
			}
			if weights.is_empty() {
				continue;
			}
			// In pixel units, where pixel (x, y) has its centre at (x, y).
			let corner_uv = corners.map(|k| [uv_at(k)[0] * width as f64 - 0.5, uv_at(k)[1] * height as f64 - 0.5]);
			let at: Vec<[f64; 2]> = weights.iter().map(|w| [0, 1].map(|axis| corner_uv[0][axis] + (corner_uv[1][axis] - corner_uv[0][axis]) * w[0] + (corner_uv[2][axis] - corner_uv[0][axis]) * w[1])).collect();
			let span = |axis: usize, size: usize| {
				let least = (at.iter().map(|q| q[axis]).fold(f64::MAX, f64::min) - MARGIN).floor() as i64;
				let most = (at.iter().map(|q| q[axis]).fold(f64::MIN, f64::max) + MARGIN).ceil() as i64;
				(least.clamp(0, size as i64 - 1) as usize, most.clamp(0, size as i64 - 1) as usize)
			};
			let ((x0, x1), (y0, y1)) = (span(0, width), span(1, height));
			// A UV past the texture's outer pixel centres is clamped onto the
			// edge when read, so such a triangle takes its whole rect.
			let inside = corner_uv.iter().all(|q| q[0] >= 0.0 && q[1] >= 0.0 && q[0] <= (width - 1) as f64 && q[1] <= (height - 1) as f64);
			for y in y0..=y1 {
				for x in x0..=x1 {
					if !readable[y * width + x] && (!inside || polygon_distance([x as f64, y as f64], &at) <= MARGIN) {
						readable[y * width + x] = true;
					}
				}
			}
		}
	}
	readable
}

// The part of a convex polygon where `inside` is at least zero, `inside`
// being linear over the plane.
fn clip_polygon(polygon: &[[f64; 2]], inside: impl Fn([f64; 2]) -> f64) -> Vec<[f64; 2]> {
	let mut kept = Vec::new();
	for (k, &from) in polygon.iter().enumerate() {
		let to = polygon[(k + 1) % polygon.len()];
		let (a, b) = (inside(from), inside(to));
		if a >= 0.0 {
			kept.push(from);
		}
		if (a >= 0.0) != (b >= 0.0) {
			let s = a / (a - b);
			kept.push([from[0] + (to[0] - from[0]) * s, from[1] + (to[1] - from[1]) * s]);
		}
	}
	kept
}

// How far a point is from a convex polygon in the UV plane, 0 inside it. A
// polygon flattened to a line counts its whole line as inside, which only
// marks more pixels than needed.
fn polygon_distance(p: [f64; 2], polygon: &[[f64; 2]]) -> f64 {
	let edges = || polygon.iter().zip(polygon.iter().cycle().skip(1));
	let side = |u: &[f64; 2], v: &[f64; 2]| (v[0] - u[0]) * (p[1] - u[1]) - (v[1] - u[1]) * (p[0] - u[0]);
	if edges().all(|(u, v)| side(u, v) >= 0.0) || edges().all(|(u, v)| side(u, v) <= 0.0) {
		return 0.0;
	}
	let to_segment = |u: &[f64; 2], v: &[f64; 2]| {
		let e = [v[0] - u[0], v[1] - u[1]];
		let t = (((p[0] - u[0]) * e[0] + (p[1] - u[1]) * e[1]) / (e[0] * e[0] + e[1] * e[1]).max(1e-18)).clamp(0.0, 1.0);
		let d = [p[0] - u[0] - e[0] * t, p[1] - u[1] - e[1] * t];
		(d[0] * d[0] + d[1] * d[1]).sqrt()
	};
	edges().map(|(u, v)| to_segment(u, v)).fold(f64::MAX, f64::min)
}

// How far a stroke scattered on a neighbouring chunk can reach into this one, in studs.
const STROKE_REACH: f64 = 6.0;

// Bumped when how strokes are laid over a part changes, so cached coat and
// wear layers bake again.
const STROKE_LAYOUT_VERSION: f64 = 2.0;

// A part's chunks as one mesh, in group order, with each triangle's and each
// face's chunk, so strokes scatter over the whole part identically for every
// chunk and each spot knows whose edge field to read.
pub fn merged_part(chunks: &[&Mesh]) -> (Mesh, Vec<usize>, Vec<usize>) {
	let mut whole = Mesh::new();
	let mut tri_chunk = Vec::new();
	let mut face_chunk = Vec::new();
	if let Some(first) = chunks.first() {
		whole.smooth_angle = first.smooth_angle;
	}
	for (k, chunk) in chunks.iter().enumerate() {
		let offset = whole.positions.len();
		whole.positions.extend(chunk.positions.iter().copied());
		for face in &chunk.faces {
			whole.faces.push(crate::mesh::Face { verts: face.verts.iter().map(|v| v + offset).collect(), uvs: face.uvs.clone() });
			face_chunk.push(k);
			for _ in 1..face.verts.len().saturating_sub(1) {
				tri_chunk.push(k);
			}
		}
	}
	(whole, tri_chunk, face_chunk)
}

// Bumped when what the shade layer holds changes, so older cached layers
// are baked again instead of read short.
const SHADE_LAYER_VERSION: f64 = 2.0;

// The edge highlight paint, saturated for the material maps: any stroke a
// third strong or more counts as a full worn rim, so the normal tilt and the
// polish follow where the strokes are, not how hard each was laid, while the
// breaks between strokes stay.
const RIM_SATURATION: f64 = 3.0;

fn rim(stroke: f64) -> f64 {
	(stroke * RIM_SATURATION).min(1.0)
}

// How far the normal map tilts at a full bevel (--normals STRENGTH); 0 bakes
// no normal map. 1 tilts a sharp edge's rim 45 degrees.
static NORMAL_STRENGTH: AtomicU64 = AtomicU64::new(0);

pub fn set_normal_strength(strength: f64) {
	NORMAL_STRENGTH.store(strength.to_bits(), Ordering::Relaxed);
}

pub fn normal_strength() -> Option<f64> {
	let strength = f64::from_bits(NORMAL_STRENGTH.load(Ordering::Relaxed));
	(strength > 0.0).then_some(strength)
}

// The roughness every part exports with (--roughness), 1 (fully rough, the
// game's deliberate flat look) unless set. A test knob: a real roughness map
// would derive from the wear and gradient layers already baked.
static ROUGHNESS: AtomicU64 = AtomicU64::new(0);

pub fn set_roughness(roughness: f64) {
	ROUGHNESS.store(roughness.clamp(0.0, 1.0).to_bits(), Ordering::Relaxed);
}

pub fn roughness() -> f64 {
	let value = f64::from_bits(ROUGHNESS.load(Ordering::Relaxed));
	if value > 0.0 { value } else { 1.0 }
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

