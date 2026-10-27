// What gets painted on a part, stroke by stroke, the way a painter works:
// a flat-brushed coat in the part's colors, sponged grime low down and in
// creases, rust patches where water sits and paint wears (sponged dark cores,
// round-brushed orange, dry-brushed flakes, chipped edges lined in, drips
// pulled down the walls), then scratches lined in along worn edges.

use crate::bake::{hash, mesh_triangles, to_linear};
use crate::brush::{Brush, Canvas, Stroke};
use crate::mesh::{add, cross, dot, normalize, scale, sub, Mesh, Vec3};

// Colors in sRGB.
const RUST_DARK: [f64; 3] = [0.3, 0.2, 0.12];
const RUST_ORANGE: [f64; 3] = [0.62, 0.36, 0.15];
const RUST_FLAKE: [f64; 3] = [0.78, 0.52, 0.3];
const BARE_METAL: [f64; 3] = [0.74, 0.73, 0.7];
const DUST: [f64; 3] = [0.55, 0.5, 0.42];
const GRIME_TINT: [f64; 3] = [0.45, 0.42, 0.5];

// Coat strokes per square stud, so each spot gets several.
const COAT_DENSITY: f64 = 24.0;
// Rust patches started per square stud where rust is certain, at full rust.
const PATCH_DENSITY: f64 = 5.0;
// Patch radius at full rust.
const PATCH_RADIUS: f64 = 0.26;
// Surfaces steeper than this (as the normal's z) are walls: coats run
// sideways round them and drips run down them.
const WALL: f64 = 0.7;

pub struct Look {
	// 0 clean to 1 eaten through.
	pub rust: f64,
	// Rubber gathers dust and scuffs instead of rust and scratches.
	pub rubber: bool,
	// 0-1: how much the coat darkens toward the bottom of the part.
	pub gradient: f64,
}

// Where wear gathers, each 0-1: near sharp edges, in creases, low down.
pub struct Wear<'a> {
	pub edge: &'a dyn Fn(Vec3, Vec3) -> f64,
	pub crease: &'a dyn Fn(Vec3, Vec3) -> f64,
	pub low: &'a dyn Fn(Vec3) -> f64,
}

fn linear(c: [f64; 3]) -> [f64; 3] {
	c.map(|x| to_linear(x as f32))
}

// Which way is up across a surface with normal n. Flat tops take a fixed
// direction so they still have an upper side.
fn uphill(n: Vec3) -> Vec3 {
	let up = sub([0.0, 0.0, 1.0], scale(n, n[2]));
	if dot(up, up) > 0.04 {
		return normalize(up);
	}
	let side = [-0.7, -0.7, 0.0];
	normalize(sub(side, scale(n, dot(side, n))))
}

// A spot on the surface with its normal and the directions up and sideways on it.
#[derive(Clone, Copy)]
struct Spot {
	at: Vec3,
	normal: Vec3,
	up: Vec3,
	side: Vec3,
}

impl Spot {
	fn new(at: Vec3, normal: Vec3) -> Spot {
		let up = uphill(normal);
		Spot { at, normal, up, side: cross(up, normal) }
	}

	// A direction on the surface, turned `angle` from sideways toward up.
	fn heading(&self, angle: f64) -> Vec3 {
		add(scale(self.side, angle.cos()), scale(self.up, angle.sin()))
	}

	fn moved(&self, side: f64, up: f64) -> Vec3 {
		add(self.at, add(scale(self.side, side), scale(self.up, up)))
	}

	// A stroke whose middle sits at `centre`, running along `along`.
	fn stroke(&self, brush: Brush, centre: Vec3, along: Vec3, length: f64, width: f64, color: [f64; 3], opacity: f64, seed: u32) -> Stroke {
		Stroke {
			brush,
			start: sub(centre, scale(along, length / 2.0)),
			along,
			across: cross(self.normal, along),
			normal: self.normal,
			length,
			width,
			color,
			opacity,
			seed,
		}
	}
}

// Calls `place` for points scattered over the mesh, `density` per square
// stud, at least `least` on every triangle, each with its own seed.
fn scatter(mesh: &Mesh, density: f64, least: u32, salt: u32, mut place: impl FnMut(Spot, u32)) {
	for (index, t) in mesh_triangles(mesh).iter().enumerate() {
		let n = cross(sub(t[1], t[0]), sub(t[2], t[0]));
		let length = dot(n, n).sqrt();
		if length < 1e-12 {
			continue;
		}
		let normal = scale(n, 1.0 / length);
		let expected = length / 2.0 * density;
		let seed = (index as u32).wrapping_mul(2_654_435_761) ^ salt.wrapping_mul(0x9e37_79b9);
		let count = (expected.floor() as u32 + u32::from(hash(seed) < expected.fract())).max(least);
		for k in 0..count {
			let id = (seed ^ k.wrapping_mul(0x85eb_ca6b)).wrapping_mul(0xc2b2_ae35);
			let r = |j: u32| hash(id.wrapping_add(j));
			let (mut a, mut b) = (r(0), r(1));
			if a + b > 1.0 {
				(a, b) = (1.0 - a, 1.0 - b);
			}
			let at = add(t[0], add(scale(sub(t[1], t[0]), a), scale(sub(t[2], t[0]), b)));
			place(Spot::new(at, normal), id);
		}
	}
}

// Paints the part. `base` gives the sRGB coat color at a point and normal.
pub fn paint(mesh: &Mesh, look: &Look, wear: &Wear, base: &mut dyn FnMut(Vec3, Vec3) -> [f64; 3]) -> Canvas {
	let mut canvas = Canvas::default();
	let coat_at = |base: &mut dyn FnMut(Vec3, Vec3) -> [f64; 3], spot: &Spot| {
		let color = linear(base(spot.at, spot.normal));
		let low = (wear.low)(spot.at);
		let fade = low * low * (3.0 - 2.0 * low) * look.gradient;
		let tint = linear([0.45, 0.42, 0.6]);
		std::array::from_fn::<f64, 3, _>(|k| color[k] + (color[k] * tint[k] - color[k]) * fade)
	};

	// The coat: flat strokes sideways round walls and any way across tops.
	scatter(mesh, COAT_DENSITY, 1, 1, |spot, id| {
		let r = |j: u32| hash(id.wrapping_add(j));
		let angle = (r(2) - 0.5) * 0.5 + if spot.normal[2].abs() > WALL { r(3) * std::f64::consts::TAU } else { 0.0 };
		// Each stroke is mixed a little lighter or darker, warmer or cooler.
		let shade = 1.0 + (r(4) - 0.5) * 0.3;
		let warm = (r(7) - 0.5) * 0.14;
		let coat = coat_at(base, &spot);
		let color = [coat[0] * shade * (1.0 + warm), coat[1] * shade, coat[2] * shade * (1.0 - warm)];
		canvas.add(spot.stroke(Brush::Flat, spot.at, spot.heading(angle), 0.35 + 0.35 * r(5), 0.16 + 0.08 * r(6), color, 1.0, id));
	});
	if look.rust <= 0.0 && !look.rubber {
		return canvas;
	}

	// Grime sponged on low down and into creases; rubber gathers pale dust,
	// on top surfaces too.
	scatter(mesh, 5.0, 0, 2, |spot, id| {
		let r = |j: u32| hash(id.wrapping_add(j));
		let mut chance = ((wear.low)(spot.at) * 0.8).max((wear.crease)(spot.at, spot.normal));
		if look.rubber {
			chance = chance.max(spot.normal[2] * 0.5);
		}
		if r(2) >= chance {
			return;
		}
		let color = if look.rubber {
			linear(DUST)
		} else {
			let coat = coat_at(base, &spot);
			let tint = linear(GRIME_TINT);
			std::array::from_fn(|k| coat[k] * tint[k])
		};
		let width = 0.12 + 0.2 * r(3);
		canvas.add(spot.stroke(Brush::Sponge, spot.at, spot.heading(r(4) * 6.3), width, width, color, 0.25 + 0.2 * r(5), id));
	});

	if look.rubber {
		// Pale scuffs where it has rubbed.
		scatter(mesh, 1.5, 0, 3, |spot, id| {
			let r = |j: u32| hash(id.wrapping_add(j));
			if r(2) >= 0.2 + 0.8 * (wear.edge)(spot.at, spot.normal) {
				return;
			}
			let color = coat_at(base, &spot).map(|c| (c * 1.8).min(1.0));
			canvas.add(spot.stroke(Brush::Liner, spot.at, spot.heading(r(3) * 6.3), 0.1 + 0.2 * r(4), 0.02, color, 0.5, id));
		});
		return canvas;
	}

	// Rust patches.
	let amount = look.rust;
	scatter(mesh, PATCH_DENSITY * amount, 0, 4, |spot, id| {
		let r = |j: u32| hash(id.wrapping_add(j));
		let chance = (wear.edge)(spot.at, spot.normal).max((wear.crease)(spot.at, spot.normal)).max((wear.low)(spot.at) * 0.6).max(0.05);
		if r(2) >= chance {
			return;
		}
		let size = PATCH_RADIUS * (0.4 + 0.6 * amount) * (0.5 + r(3));
		let mut j = 10;
		let mut next = || {
			j += 1;
			r(j)
		};
		let mut around = |reach: f64| {
			let (angle, spread) = (next() * std::f64::consts::TAU, reach * next().sqrt());
			spot.moved(angle.cos() * spread, angle.sin() * spread)
		};
		let dabs = 3 + (amount * 5.0) as u32;
		let mut lowest = 0.0f64;
		for k in 0..dabs {
			let centre = around(size * 0.7);
			let width = size * (0.7 + 0.7 * r(100 + k));
			lowest = lowest.min(dot(sub(centre, spot.at), spot.up) - width / 2.0);
			canvas.add(spot.stroke(Brush::Sponge, centre, spot.heading(r(120 + k) * 6.3), width, width, linear(RUST_DARK), 1.0, id ^ k));
		}
		for k in 0..dabs {
			let centre = around(size * 0.5);
			let along = spot.heading(r(140 + k) * 6.3);
			canvas.add(spot.stroke(Brush::Round, centre, along, size * (0.6 + 0.6 * r(160 + k)), size * (0.3 + 0.25 * r(180 + k)), linear(RUST_ORANGE), 0.9, id ^ (k + 50)));
		}
		for k in 0..2 + (r(4) * 2.0) as u32 {
			let centre = add(around(size * 0.4), scale(spot.up, size * 0.35));
			canvas.add(spot.stroke(Brush::Dry, centre, spot.heading((r(200 + k) - 0.5) * 0.6), size * 0.8, size * 0.35, linear(RUST_FLAKE), 0.9, id ^ (k + 90)));
		}
		// Chipped paint: a shadow lined in under the top edge, and a lit lip
		// lined along under the bottom edge.
		let lip = coat_at(base, &spot).map(|c| (c * 1.45 + 0.03).min(1.0));
		let dark = linear(RUST_DARK).map(|c| c * 0.45);
		canvas.add(spot.stroke(Brush::Liner, spot.moved((r(5) - 0.5) * size * 0.4, size * 0.7), spot.side, size * 1.3, 0.02, dark, 0.9, id ^ 7));
		canvas.add(spot.stroke(Brush::Liner, spot.moved((r(6) - 0.5) * size * 0.4, lowest - 0.012), spot.side, size * 1.4, 0.02, lip, 0.9, id ^ 8));
		// Drips pulled down the wall, each ending in a bead.
		if spot.normal[2].abs() > WALL {
			return;
		}
		let down = scale(spot.up, -1.0);
		for k in 0..(r(7) * 3.5 * amount) as u32 {
			let top = spot.moved((r(220 + k) - 0.5) * size, lowest + size * 0.2);
			let length = size * (1.5 + 3.0 * r(240 + k)) * (0.5 + amount);
			let width = size * (0.14 + 0.08 * r(260 + k));
			let orange = linear(RUST_ORANGE);
			canvas.add(spot.stroke(Brush::Liner, add(top, scale(down, length / 2.0)), down, length, width, orange, 0.85, id ^ (k + 300)));
			canvas.add(spot.stroke(Brush::Round, add(top, scale(down, length)), down, width * 2.2, width * 1.8, orange, 0.85, id ^ (k + 400)));
		}
	});

	// Scratches lined in clusters, each cluster one way, mostly along worn edges.
	scatter(mesh, 2.0, 0, 5, |spot, id| {
		let r = |j: u32| hash(id.wrapping_add(j));
		if r(2) >= 0.15 + 0.85 * (wear.edge)(spot.at, spot.normal) {
			return;
		}
		let along = spot.heading(r(3) * 6.3);
		let across = cross(spot.normal, along);
		let coat = coat_at(base, &spot);
		let metal = linear(BARE_METAL);
		let color = std::array::from_fn(|k| (coat[k] + metal[k] * 2.0) / 3.0);
		for k in 0..3 + (r(4) * 4.0) as u32 {
			let offset = add(scale(across, (r(10 + k) - 0.5) * 0.12), scale(along, (r(20 + k) - 0.5) * 0.15));
			let centre = add(spot.at, offset);
			canvas.add(spot.stroke(Brush::Liner, centre, along, 0.1 + 0.25 * r(30 + k), 0.01 + 0.008 * r(40 + k), color, 0.9, id ^ (k + 500)));
		}
	});
	canvas
}
