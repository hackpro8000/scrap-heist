// A coat laid the way a hand paints: each stroke is a scanned bristle shape
// swept along its own wobbling arc, heavier where it lands and thinning as it
// lifts. Strokes follow the form, go down big to small, carry some of the paint
// they cross, and the last marks sharpen some edges while leaving others lost.

use std::collections::HashMap;
use std::hash::{BuildHasherDefault, Hasher};

use crate::bake::{hash, parallel};
use crate::brush::stamp_alpha;
use crate::coat::{self, Hand, Look, Wear};
use crate::mesh::{add, cross, dot, normalize, scale, sub, Mesh, Vec3};

// Raise this when the coat changes, so cached textures are repainted.
pub const VERSION: f64 = 4.0;
const CELL: f64 = 0.6;
// Points along a stroke's path.
const STEPS: usize = 8;
const CREAM: [f64; 3] = [0.82, 0.76, 0.62];

// Declares the coat's settings: every number it uses, with its default. Each
// can be set per part from `handTune` in a model script, so tuning the coat
// never needs the engine rebuilt. All of them key the texture cache.
macro_rules! settings {
	($($name:ident: $default:expr,)*) => {
		#[derive(Clone)]
		pub struct Tuning { $(pub $name: f64,)* }
		impl Default for Tuning {
			fn default() -> Tuning { Tuning { $($name: $default,)* } }
		}
		impl Tuning {
			fn set(&mut self, name: &str, value: f64) -> bool {
				match name {
					$(stringify!($name) => self.$name = value,)*
					_ => return false,
				}
				true
			}
			pub fn numbers(&self) -> Vec<f64> { vec![$(self.$name,)*] }
			fn names() -> &'static [&'static str] { &[$(stringify!($name),)*] }
		}
	};
}

pub(crate) use settings;

settings! {
	big_length_min: 1.1, big_length_max: 1.9, big_width_min: 0.55, big_width_max: 1.0, big_cover: 2.2,
	mid_length_min: 0.5, mid_length_max: 0.9, mid_width_min: 0.22, mid_width_max: 0.38, mid_cover: 1.4, mid_keep: 0.45,
	small_length_min: 0.18, small_length_max: 0.4, small_width_min: 0.05, small_width_max: 0.1, small_cover: 0.5, small_power: 1.2,
	curve: 0.25, wobble: 0.5, follow: 0.55, habit: -0.09, reversed: 0.2, overshoot: 0.1,
	pickup: 0.45, opacity: 0.92, tone: 0.12,
	falloff: 0.55, start_fade: 0.08, end_fade: 0.15,
	landing: 0.78, landing_length: 0.1, lift_start: 0.68, lift_amount: 0.9, lift_power: 1.6, pressure_min: 0.68,
	bristle_drift: 0.07, dry_from: 0.8, dry_speed: 0.3, dry_bristles: 0.45,
	speed_length_min: 0.8, speed_length: 0.5, speed_width_max: 1.15, speed_width: 0.3,
	shade_big: 0.22, shade_mid: 0.3, shade_small: 0.4, warm: 0.14, light_up: 0.18, light_low: 0.3, accent_light: 1.15,
	edge_angle: 0.94, edge_length_min: 0.3, edge_length_max: 0.8, edge_width_min: 0.02, edge_width_max: 0.05,
	edge_cream_min: 0.35, edge_cream_max: 0.65, edge_opacity: 0.85, edge_found: -0.2,
}

impl Tuning {
	// A material's defaults with the part's own settings on top.
	pub fn new(hand: Hand, overrides: &[(String, f64)]) -> Result<Tuning, String> {
		let mut tuning = Tuning::default();
		let preset: &[(&str, f64)] = match hand {
			Hand::Rock => &[],
			Hand::Wood => &[("big_length_min", 2.2), ("big_length_max", 3.6), ("big_width_min", 0.3), ("big_width_max", 0.5), ("mid_length_min", 1.2), ("mid_length_max", 2.0), ("mid_width_min", 0.12), ("mid_width_max", 0.2), ("small_length_min", 0.5), ("small_length_max", 1.0), ("small_width_min", 0.03), ("small_width_max", 0.06), ("curve", 0.05), ("wobble", 0.25), ("follow", 1.0)],
			Hand::Metal => &[("big_length_min", 1.6), ("big_length_max", 2.8), ("big_width_min", 0.45), ("big_width_max", 0.7), ("mid_length_min", 0.9), ("mid_length_max", 1.5), ("mid_width_min", 0.16), ("mid_width_max", 0.28), ("small_length_min", 0.3), ("small_length_max", 0.6), ("small_width_min", 0.04), ("small_width_max", 0.08), ("curve", 0.08), ("wobble", 0.12), ("follow", 0.85)],
		};
		for (name, value) in preset {
			tuning.set(name, *value);
		}
		for (name, value) in overrides {
			if !tuning.set(name, *value) {
				return Err(format!("unknown handTune setting {name}; the settings are: {}", Tuning::names().join(", ")));
			}
		}
		Ok(tuning)
	}
}

struct Sweep {
	origin: Vec3,
	heading: Vec3,
	side: Vec3,
	normal: Vec3,
	half_width: f64,
	reach: f64,
	tolerance: f64,
	points: [(f64, f64); STEPS + 1],
	// The box round the path that paint can't leave: lowest and highest
	// along the heading, then along the side. Painting::add fills it in.
	limits: [f64; 4],
	// 0 slow and heavy, 1 fast and dry.
	speed: f64,
	color: [f64; 3],
	dragged: [f64; 3],
	opacity: f64,
	seed: u32,
	layer: u8,
	marks: Option<std::sync::Arc<crate::marks::Marks>>,
}

impl Sweep {
	// Whether this stroke could paint anywhere within `radius` of a point.
	fn can_reach(&self, p: Vec3, radius: f64) -> bool {
		let offset = sub(p, self.origin);
		let [low_x, high_x, low_y, high_y] = self.limits;
		let (x, y) = (dot(offset, self.heading), dot(offset, self.side));
		dot(offset, self.normal).abs() <= self.tolerance + radius && x >= low_x - radius && x <= high_x + radius && y >= low_y - radius && y <= high_y + radius
	}

	// How far along (0-1) and how far off the path p lies, with the paint's
	// coverage there.
	fn cover(&self, p: Vec3, n: Vec3, t: &Tuning) -> Option<(f64, f64)> {
		if dot(n, self.normal) < 0.35 {
			return None;
		}
		let offset = sub(p, self.origin);
		if dot(offset, self.normal).abs() > self.tolerance {
			return None;
		}
		let (x, y) = (dot(offset, self.heading), dot(offset, self.side));
		// Most strokes listed for a texel can't reach it: cheaper to say so
		// here than to walk the whole path.
		let [low_x, high_x, low_y, high_y] = self.limits;
		if x < low_x || x > high_x || y < low_y || y > high_y {
			return None;
		}
		let (mut best, mut along, mut signed) = (f64::MAX, 0.0, 0.0);
		for k in 0..STEPS {
			let ((ax, ay), (bx, by)) = (self.points[k], self.points[k + 1]);
			let (ex, ey) = (bx - ax, by - ay);
			let t = (((x - ax) * ex + (y - ay) * ey) / (ex * ex + ey * ey).max(1e-9)).clamp(0.0, 1.0);
			let (dx, dy) = (x - ax - ex * t, y - ay - ey * t);
			let d = dx * dx + dy * dy;
			if d < best {
				best = d;
				along = (k as f64 + t) / STEPS as f64;
				signed = (ex * dy - ey * dx).signum() * d.sqrt();
			}
		}
		if let Some(marks) = &self.marks {
			let paint = marks.paint_stroke(self.seed, along * self.reach, signed, self.reach, self.half_width * 2.0, signed * self.side[2] <= 0.0);
			return (paint > 0.0).then_some((along, paint * self.opacity));
		}
		// Pressure: lands heavy, swells, then thins as the brush lifts.
		let landing = t.landing + (1.12 - t.landing) * (along / t.landing_length.max(1e-3)).min(1.0);
		let lift = 1.0 - ((along - t.lift_start).max(0.0) / (1.0 - t.lift_start).max(1e-3)).powf(t.lift_power) * t.lift_amount;
		let width = self.half_width * landing * lift;
		let across = signed / width.max(1e-6);
		if across.abs() >= 1.0 {
			return None;
		}
		let r = |k: u32| hash(self.seed.wrapping_mul(29).wrapping_add(k));
		// Bristles wander across the stroke as it's dragged.
		let drift = t.bristle_drift * (along * 9.0 + r(1) * 6.3).sin();
		let v = (across * 0.5 + 0.5 + drift).clamp(0.0, 1.0);
		let (u, v) = (if r(2) < 0.5 { along } else { 1.0 - along }, if r(3) < 0.5 { v } else { 1.0 - v });
		let shape = stamp_alpha(self.seed, u * 0.92 + 0.04, v);
		// The paint runs out toward the tail, sooner on a fast stroke.
		let bristle = (v * 12.0).floor() as u32;
		let dry_from = t.dry_from - t.dry_speed * self.speed;
		let dry = if hash(self.seed ^ bristle.wrapping_mul(7919)) < t.dry_bristles { 1.0 - ((along - dry_from).max(0.0) / (1.0 - dry_from).max(0.05)).min(1.0) } else { 1.0 };
		// Brush falloff: the paint thins toward the sides and at both ends.
		let soft = |t: f64| t * t * (3.0 - 2.0 * t);
		let rim = soft(((1.0 - across.abs()) / t.falloff.max(1e-3)).min(1.0)) * soft((along / t.start_fade.max(1e-3)).min(1.0)) * soft(((1.0 - along) / t.end_fade.max(1e-3)).min(1.0));
		let pressure = t.pressure_min + (1.0 - t.pressure_min) * (std::f64::consts::PI * (along * 1.2).min(1.0)).sin();
		Some((along, shape * dry * rim * pressure * self.opacity))
	}

	fn tone(&self, across_seed: f64, t: &Tuning) -> f64 {
		1.0 + (hash(self.seed.wrapping_add(((across_seed * 12.0) as u32).wrapping_mul(13))) - 0.5) * t.tone
	}
}

// The grid is looked up once per texel per stroke added, so its hash is a
// plain multiply; nothing here reads the map's order.
#[derive(Default)]
struct CellHasher(u64);

impl Hasher for CellHasher {
	fn write(&mut self, bytes: &[u8]) {
		for &byte in bytes {
			self.0 = (self.0 ^ u64::from(byte)).wrapping_mul(0x0000_0100_0000_01b3);
		}
	}

	fn finish(&self) -> u64 {
		self.0 ^ (self.0 >> 29)
	}
}

type Cells = HashMap<[i32; 3], Vec<u32>, BuildHasherDefault<CellHasher>>;

// A first-coat stroke, for finding what shows through a gap in the paint.
struct FirstCoat {
	normal: Vec3,
	centre: Vec3,
	color: [f64; 3],
}

pub struct Painting {
	strokes: Vec<Sweep>,
	// Per cell, the strokes that can leave paint there.
	grid: Cells,
	// Per cell, the first-coat strokes around it, which needn't touch it.
	first_coats: Vec<FirstCoat>,
	first_coat_grid: Cells,
	// Grown with the strokes, so each still spans a few cells.
	cell_size: f64,
	tuning: Tuning,
}

impl Painting {
	fn cell(&self, p: Vec3) -> [i32; 3] {
		p.map(|c| (c / self.cell_size).floor() as i32)
	}

	fn add(&mut self, mut stroke: Sweep) {
		let t = &self.tuning;
		let off_path = match &stroke.marks {
			Some(marks) => marks.limit_on(stroke.half_width * 2.0),
			// The widest cover() can make the stroke: landing and lift at their most.
			None => stroke.half_width * t.landing.max(1.12) * (1.0 - t.lift_amount).max(1.0),
		};
		let along_path = |pick: fn(&(f64, f64)) -> f64| stroke.points.iter().map(pick).fold((f64::MAX, f64::MIN), |(low, high), v| (low.min(v), high.max(v)));
		let (low_x, high_x) = along_path(|p| p.0);
		let (low_y, high_y) = along_path(|p| p.1);
		stroke.limits = [low_x - off_path, high_x + off_path, low_y - off_path, high_y + off_path];
		let centre = add(stroke.origin, scale(stroke.heading, stroke.reach * 0.5));
		let reach = stroke.marks.as_ref().map_or(stroke.half_width, |marks| stroke.half_width.max(marks.reach_on(stroke.half_width * 2.0)));
		let spread = stroke.reach * 0.75 + reach + stroke.tolerance;
		let (low, high) = (self.cell(centre.map(|c| c - spread)), self.cell(centre.map(|c| c + spread)));
		let index = self.strokes.len() as u32;
		let first_coat = (stroke.layer == 0).then(|| {
			self.first_coats.push(FirstCoat { normal: stroke.normal, centre, color: stroke.color });
			self.first_coats.len() as u32 - 1
		});
		// A hair over the distance from a cell's middle to its corner.
		let cell_radius = self.cell_size * 0.5 * 3f64.sqrt() * 1.01;
		for x in low[0]..=high[0] {
			for y in low[1]..=high[1] {
				for z in low[2]..=high[2] {
					if let Some(first_coat) = first_coat {
						self.first_coat_grid.entry([x, y, z]).or_default().push(first_coat);
					}
					// A stroke is flat, so most of this cube is out of its reach.
					if stroke.can_reach([x, y, z].map(|c| (f64::from(c) + 0.5) * self.cell_size), cell_radius) {
						self.grid.entry([x, y, z]).or_default().push(index);
					}
				}
			}
		}
		self.strokes.push(stroke);
	}

	// The paint already at p: the latest stroke that crosses it.
	fn beneath(&self, p: Vec3, n: Vec3, fallback: [f64; 3]) -> [f64; 3] {
		let Some(list) = self.grid.get(&self.cell(p)) else { return fallback };
		for &index in list.iter().rev() {
			let stroke = &self.strokes[index as usize];
			if stroke.cover(p, n, &self.tuning).is_some_and(|(_, a)| a > 0.2) {
				return stroke.color;
			}
		}
		fallback
	}

	pub fn colour(&self, p: Vec3, n: Vec3) -> [f64; 3] {
		let cell = self.cell(p);
		let list = self.grid.get(&cell).map(Vec::as_slice).unwrap_or(&[]);
		// Where the big strokes left a gap, the nearest one's paint shows through.
		let mut under = (f64::MAX, self.strokes.first().map_or([0.5; 3], |s| s.color));
		for &index in self.first_coat_grid.get(&cell).map(Vec::as_slice).unwrap_or(&[]) {
			let first_coat = &self.first_coats[index as usize];
			if dot(n, first_coat.normal) > 0.35 {
				let d = sub(p, first_coat.centre);
				let distance = dot(d, d);
				if distance < under.0 {
					under = (distance, first_coat.color);
				}
			}
		}
		let mut color = under.1;
		for &index in list {
			let stroke = &self.strokes[index as usize];
			if let Some((along, alpha)) = stroke.cover(p, n, &self.tuning) {
				if alpha > 0.0 {
					let tone = stroke.tone((dot(sub(p, stroke.origin), stroke.side) / stroke.half_width + 1.0) * 0.5, &self.tuning);
					let carried = self.tuning.pickup * along;
					color = std::array::from_fn(|k| {
						let paint = (stroke.color[k] + (stroke.dragged[k] - stroke.color[k]) * carried) * tone;
						color[k] + (paint - color[k]) * alpha
					});
				}
			}
		}
		color
	}
}

fn lerp(range: (f64, f64), t: f64) -> f64 {
	range.0 + (range.1 - range.0) * t
}

// A stroke's path: an arc from the arm's pivot, with hand wobble and a small
// overshoot past where it was aimed. Slow strokes shake more; fast ones run straighter.
fn path(id: u32, length: f64, curve: f64, wobble: f64, speed: f64, overshoot: f64) -> [(f64, f64); STEPS + 1] {
	let r = |k: u32| hash(id.wrapping_add(k.wrapping_mul(0x9e37)));
	let bend = curve * length * (if r(10) < 0.75 { 1.0 } else { -1.0 }) * (0.6 + 0.4 * r(11)) * (1.2 - 0.6 * speed);
	let shake = wobble * length * (1.4 - speed) * 0.05;
	let overshoot = 1.0 + overshoot * r(12);
	let (f1, p1, f2, p2) = (1.0 + r(13), r(14) * 6.3, 2.5 + 2.0 * r(15), r(16) * 6.3);
	std::array::from_fn(|k| {
		let s = k as f64 / STEPS as f64;
		let arc = bend * 4.0 * s * (1.0 - s);
		let waver = shake * ((s * 6.3 * f1 + p1).sin() + 0.5 * (s * 6.3 * f2 + p2).sin());
		(length * overshoot * s, arc + waver)
	})
}

// Which way the form runs across a face: a wood's grain along the part's
// longest axis, otherwise the face's longest edge.
fn form_direction(mesh: &Mesh, verts: &[usize], normal: Vec3, grain: Option<Vec3>) -> Vec3 {
	let mut direction = grain.unwrap_or([0.0, 0.0, 0.0]);
	if grain.is_none() {
		let mut longest = 0.0;
		for (k, &a) in verts.iter().enumerate() {
			let e = sub(mesh.positions[verts[(k + 1) % verts.len()]], mesh.positions[a]);
			if dot(e, e) > longest {
				longest = dot(e, e);
				direction = e;
			}
		}
	}
	let flat = sub(direction, scale(normal, dot(direction, normal)));
	if dot(flat, flat) > 1e-6 {
		return normalize(flat);
	}
	let other = if normal[2].abs() < 0.9 { [0.0, 0.0, 1.0] } else { [1.0, 0.0, 0.0] };
	normalize(cross(normal, other))
}

fn grain_axis(mesh: &Mesh) -> Vec3 {
	let mut low = [f64::MAX; 3];
	let mut high = [f64::MIN; 3];
	for p in &mesh.positions {
		for k in 0..3 {
			low[k] = low[k].min(p[k]);
			high[k] = high[k].max(p[k]);
		}
	}
	let longest = (0..3).max_by(|&a, &b| (high[a] - low[a]).total_cmp(&(high[b] - low[b]))).unwrap_or(0);
	std::array::from_fn(|k| if k == longest { 1.0 } else { 0.0 })
}

// Where one layer's strokes might start, in a fixed order, each with its seed.
#[derive(Clone, Copy)]
struct Candidate {
	at: Vec3,
	normal: Vec3,
	form: Vec3,
	id: u32,
}

fn candidates(mesh: &Mesh, layer: usize, density: f64, grain: Option<Vec3>) -> Vec<Candidate> {
	let mut spots = Vec::new();
	for (face_index, face) in mesh.faces.iter().enumerate() {
		let normal = mesh.face_normal(face);
		let form = form_direction(mesh, &face.verts, normal, grain);
		for tri in 1..face.verts.len().saturating_sub(1) {
			let (a, b, c) = (mesh.positions[face.verts[0]], mesh.positions[face.verts[tri]], mesh.positions[face.verts[tri + 1]]);
			let n = cross(sub(b, a), sub(c, a));
			let expected = dot(n, n).sqrt() / 2.0 * density;
			let seed = (face_index as u32).wrapping_mul(2_654_435_761) ^ (tri as u32).wrapping_mul(40_503) ^ ((layer as u32 + 1).wrapping_mul(0x9e37_79b9));
			let count = (expected.floor() as u32 + u32::from(hash(seed) < expected.fract())).max(u32::from(layer == 0));
			for k in 0..count {
				let id = (seed ^ k.wrapping_mul(0x85eb_ca6b)).wrapping_mul(0xc2b2_ae35);
				let r = |j: u32| hash(id.wrapping_add(j));
				let (mut across_ab, mut across_ac) = (r(0), r(1));
				if across_ab + across_ac > 1.0 {
					(across_ab, across_ac) = (1.0 - across_ab, 1.0 - across_ac);
				}
				spots.push(Candidate { at: add(a, add(scale(sub(b, a), across_ab), scale(sub(c, a), across_ac))), normal, form, id });
			}
		}
	}
	spots
}

pub fn prepare(mesh: &Mesh, look: &Look, hand: Hand, tuning: &Tuning, wear: &Wear, base: &mut dyn FnMut(Vec3, Vec3) -> [f64; 3]) -> Painting {
	let t = tuning;
	let layers = [((t.big_length_min, t.big_length_max), (t.big_width_min, t.big_width_max), t.big_cover), ((t.mid_length_min, t.mid_length_max), (t.mid_width_min, t.mid_width_max), t.mid_cover), ((t.small_length_min, t.small_length_max), (t.small_width_min, t.small_width_max), t.small_cover)];
	let grain = matches!(hand, Hand::Wood).then(|| grain_axis(mesh));
	let mut painting = Painting { strokes: Vec::new(), grid: Cells::default(), first_coats: Vec::new(), first_coat_grid: Cells::default(), cell_size: CELL * look.brush, tuning: tuning.clone() };
	let tolerance = |length: f64| 0.05 + 0.06 * length;
	// Big strokes first, then smaller ones, each on top of the last.
	for (layer, &(mark_length, mark_width, cover)) in layers.iter().enumerate() {
		let area = lerp(mark_length, 0.5) * lerp(mark_width, 0.5);
		let density = cover / area / (look.brush * look.brush);
		let spots = candidates(mesh, layer, density, grain);
		// How near an edge each spot sits is the slow part of setting up, so it
		// runs on every core; the first coat keeps all its strokes and never asks.
		let edges = if layer == 0 { vec![0.0; spots.len()] } else { parallel(&spots, |spot| (wear.edge)(spot.at, spot.normal)) };
		for (&Candidate { at, normal, form, id }, edge) in spots.iter().zip(edges) {
			let r = |j: u32| hash(id.wrapping_add(j));
			// Mark economy: fine strokes gather at edges and the focus.
			let near_focus = look.focus.map_or(0.0, |(centre, radius)| {
				let d = sub(at, centre);
				(1.0 - dot(d, d).sqrt() / radius.max(1e-3)).max(0.0)
			});
			let interest = edge.max(near_focus).min(1.0);
			let keep = match layer {
				0 => 1.0,
				1 => t.mid_keep + (1.0 - t.mid_keep) * interest,
				_ => interest.powf(t.small_power),
			};
			if r(2) > keep {
				continue;
			}
			let speed = r(3);
			let length = lerp(mark_length, r(4)) * (t.speed_length_min + t.speed_length * speed) * look.brush;
			let half_width = lerp(mark_width, r(5)) * (t.speed_width_max - t.speed_width * speed) * look.brush / 2.0;
			// Along the form, leaning the painter's way, some reversed.
			let up = cross(normal, form);
			let angle = t.habit + (r(6) - 0.5) * std::f64::consts::PI * (1.0 - t.follow);
			let mut heading = add(scale(form, angle.cos()), scale(up, angle.sin()));
			if r(7) < t.reversed {
				heading = scale(heading, -1.0);
			}
			let side = cross(normal, heading);
			// Lit from above, darker low down.
			let mut color = coat::base_at(look, wear, base, at, normal);
			let light = (1.0 + t.light_up * normal[2]) * (1.0 - t.light_low * (wear.low)(at)) * (1.0 + (r(8) - 0.5) * [t.shade_big, t.shade_mid, t.shade_small][layer]) * (if layer == 2 { t.accent_light } else { 1.0 });
			let warm = (r(9) - 0.5) * t.warm;
			color = [color[0] * light * (1.0 + warm), color[1] * light, color[2] * light * (1.0 - warm)];
			let origin = sub(at, scale(heading, length / 2.0));
			let dragged = painting.beneath(origin, normal, color);
			painting.add(Sweep {
				origin,
				heading,
				side,
				normal,
				half_width,
				reach: length,
				tolerance: tolerance(length),
				points: path(id, length, t.curve, t.wobble, speed, t.overshoot),
				limits: [0.0; 4],
				speed,
				color,
				dragged,
				opacity: t.opacity,
				seed: id,
				layer: layer as u8,
				marks: look.brushes.coat.clone(),
			});
		}
	}
	lost_and_found(mesh, look, t, wear, base, &mut painting);
	painting
}

// The last marks: light strokes along sharp edges in some stretches, none in
// others, so an edge sharpens and dissolves as it runs.
fn lost_and_found(mesh: &Mesh, look: &Look, t: &Tuning, wear: &Wear, base: &mut dyn FnMut(Vec3, Vec3) -> [f64; 3], painting: &mut Painting) {
	let mut edges: HashMap<(usize, usize), Vec<usize>> = HashMap::new();
	for (index, face) in mesh.faces.iter().enumerate() {
		for (k, &a) in face.verts.iter().enumerate() {
			let b = face.verts[(k + 1) % face.verts.len()];
			edges.entry((a.min(b), a.max(b))).or_default().push(index);
		}
	}
	let mut sorted: Vec<_> = edges.into_iter().collect();
	sorted.sort_by_key(|(key, _)| *key);
	for ((a, b), faces) in sorted {
		if faces.len() != 2 {
			continue;
		}
		let (na, nb) = (mesh.face_normal(&mesh.faces[faces[0]]), mesh.face_normal(&mesh.faces[faces[1]]));
		if dot(na, nb) > t.edge_angle {
			continue;
		}
		let (pa, pb) = (mesh.positions[a], mesh.positions[b]);
		let run = sub(pb, pa);
		let total = dot(run, run).sqrt();
		if total < 0.05 {
			continue;
		}
		let along = scale(run, 1.0 / total);
		let seed = (a as u32).wrapping_mul(7919) ^ (b as u32).wrapping_mul(104_729);
		let mut at = 0.0;
		let mut k = 0u32;
		while at < total {
			let id = seed.wrapping_add(k.wrapping_mul(0x85eb_ca6b));
			let r = |j: u32| hash(id.wrapping_add(j));
			let length = lerp((t.edge_length_min, t.edge_length_max), r(0)) * look.brush;
			// A slow wave decides which stretches are found.
			let found = (at * 0.9 + (seed % 628) as f64 / 100.0).sin() + 0.5 * (at * 2.3 + r(9) * 0.4).sin() > t.edge_found;
			if found {
				let normal = if r(1) < 0.5 { na } else { nb };
				let inward = {
					let side = cross(normal, along);
					let middle = mesh.faces[if normal == na { faces[0] } else { faces[1] }].verts.iter().fold([0.0; 3], |sum, &v| add(sum, mesh.positions[v]));
					let count = mesh.faces[if normal == na { faces[0] } else { faces[1] }].verts.len() as f64;
					if dot(side, sub(scale(middle, 1.0 / count), pa)) >= 0.0 { side } else { scale(side, -1.0) }
				};
				let half_width = lerp((t.edge_width_min, t.edge_width_max), r(2)) * look.brush;
				let origin = add(add(pa, scale(along, at)), scale(inward, half_width));
				let middle = add(origin, scale(along, length / 2.0));
				let paint = coat::base_at(look, wear, base, middle, normal);
				let color = std::array::from_fn(|c| paint[c] + (CREAM[c] - paint[c]) * lerp((t.edge_cream_min, t.edge_cream_max), r(3)));
				painting.add(Sweep {
					origin,
					heading: along,
					side: cross(normal, along),
					normal,
					half_width,
					reach: length,
					tolerance: 0.04,
					points: path(id, length, 0.03, 0.2, 0.5, t.overshoot),
					limits: [0.0; 4],
					speed: 0.5,
					color,
					dragged: color,
					opacity: t.edge_opacity,
					seed: id,
					layer: 3,
					marks: None,
				});
			}
			at += length * (0.7 + 0.5 * r(4));
			k += 1;
		}
	}
}
