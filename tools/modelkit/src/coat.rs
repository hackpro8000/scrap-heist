// What gets painted on a part, stroke by stroke, the way a painter works:
// a flat-brushed coat in the part's colors, sponged grime low down and in
// creases, rust patches where water sits and paint wears (sponged dark cores,
// round-brushed orange, dry-brushed flakes, chipped edges lined in, drips
// pulled down the walls), then scratches lined in along worn edges.

use crate::bake::{hash, to_linear};
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
// Studs across the stretches seam rust clusters into or skips.
const RUST_CLUSTER: f64 = 2.5;
// Surfaces steeper than this (as the normal's z) are walls: coats run
// sideways round them and drips run down them.
const WALL: f64 = 0.7;

pub struct Look {
	// 0 clean to 1 eaten through.
	pub rust: f64,
	// Rubber gathers dust and scuffs instead of rust and scratches.
	pub rubber: bool,
	// Rust only on seams and edges, in clusters and run-down streaks.
	pub rust_edges: bool,
	// 0-1: how much the coat darkens toward the bottom of the part.
	pub gradient: f64,
	// Strokes are this many times larger, and fewer to match, where an eye
	// preview shrank the texture: a far part can't show fine strokes.
	pub brush: f64,
	// Lay the coat with scanned stroke stamps instead of the flat brush.
	pub stamps: bool,
	// Paint the coat the way a hand would, in this material's marks.
	pub hand: Option<Hand>,
	pub tuning: Option<crate::hand::Tuning>,
	// Where a hand-painted coat gathers its finest strokes: a point and radius.
	pub focus: Option<(Vec3, f64)>,
	pub brushes: Brushes,
	// Paint the plain brushed coat's strokes once on a seamless square tile
	// and lay it over the part by world position, instead of stroking every
	// chunk's own surface (see `tile_lookup`).
	pub tiled: Option<TiledCoat>,
}

#[derive(Clone, Copy)]
pub struct TiledCoat {
	// The tile's side in studs, and how many differently stroked tiles there are.
	pub tile: f64,
	pub variants: u32,
}

impl TiledCoat {
	// What a tiled coat adds to the coat layer's key.
	pub fn numbers(&self) -> [f64; 4] {
		[-7.0, self.tile, f64::from(self.variants), TILE_VERSION]
	}
}

// Bumped when the tile's strokes or how a texel finds its place on a tile change.
const TILE_VERSION: f64 = 1.0;

type Motion = Option<std::sync::Arc<crate::marks::Marks>>;

// The motions a part's coat and wear are drawn with, if not the brushes' own.
#[derive(Default)]
pub struct Brushes {
	pub coat: Motion,
	pub grime: Motion,
	pub rust: Motion,
	pub drip: Motion,
	pub scratch: Motion,
}

impl Brushes {
	pub fn wear_numbers(&self) -> Vec<f64> {
		[&self.grime, &self.rust, &self.drip, &self.scratch].into_iter().flat_map(|motion| motion.iter().flat_map(|marks| marks.numbers()).chain([-1.0])).collect()
	}
}

#[derive(Clone, Copy)]
pub enum Hand {
	Rock,
	Wood,
	Metal,
}

// Where wear gathers, each 0-1: near sharp edges, in creases, low down.
// Edge and crease read the shade layer the highlights and contact shadows
// were painted from, at the spot's UV, so that geometry is walked once per
// texel and never again.
pub struct Wear<'a> {
	pub edge: &'a (dyn Fn(usize, [f64; 2]) -> f64 + Sync),
	pub crease: &'a (dyn Fn(usize, [f64; 2]) -> f64 + Sync),
	pub low: &'a (dyn Fn(Vec3) -> f64 + Sync),
	// Strokes scatter over a part's whole mesh (every chunk of it), so each
	// spot carries its chunk, and spots too far from the chunk being painted
	// to reach it are skipped.
	pub near: &'a (dyn Fn(Vec3) -> bool + Sync),
	// The box `near` tests against, when it is one: a triangle wholly outside
	// it holds no near spot, so its spots are never drawn.
	pub near_box: Option<(Vec3, Vec3)>,
	// The box round the chunk being painted itself, when there is one: a
	// stroke that cannot touch it is dropped before its colour is asked for.
	pub own_box: Option<(Vec3, Vec3)>,
	pub tri_chunk: &'a [usize],
	pub face_chunk: &'a [usize],
}

// Slack on the near box when whole triangles or chunks are ruled out, far
// wider than the rounding of a spot placed inside a triangle.
pub const NEAR_SLACK: f64 = 1e-6;

impl Wear<'_> {
	// Whether a triangle lies wholly outside the near box, so that no spot
	// on it can pass `near`.
	pub fn far(&self, triangle: [Vec3; 3]) -> bool {
		let Some((low, high)) = self.near_box else { return false };
		(0..3).any(|k| {
			let most = triangle[0][k].max(triangle[1][k]).max(triangle[2][k]);
			let least = triangle[0][k].min(triangle[1][k]).min(triangle[2][k]);
			most < low[k] - NEAR_SLACK || least > high[k] + NEAR_SLACK
		})
	}
}

impl Wear<'_> {
	// Whether a stroke centred at `centre` lies too far from the chunk being
	// painted to touch any of its texels. A canvas files a stroke under the
	// cells its reach overlaps, and a texel reads only its own cell, so
	// `range` is the stroke's reach plus one cell.
	pub fn out_of_touch(&self, centre: Vec3, range: f64) -> bool {
		let Some((low, high)) = self.own_box else { return false };
		(0..3).any(|k| centre[k] < low[k] - range - NEAR_SLACK || centre[k] > high[k] + range + NEAR_SLACK)
	}
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
	// Which chunk of the part the spot lies on, and where in that chunk's
	// texture, for reading baked layers.
	chunk: usize,
	uv: [f64; 2],
	// Stroke size multiplier, from Look::brush.
	brush: f64,
	normal: Vec3,
	up: Vec3,
	side: Vec3,
}

impl Spot {
	fn new(at: Vec3, chunk: usize, uv: [f64; 2], normal: Vec3, brush: f64) -> Spot {
		let up = uphill(normal);
		Spot { at, chunk, uv, brush, normal, up, side: cross(up, normal) }
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
			length: length * self.brush,
			width: width * self.brush,
			color,
			opacity,
			seed,
			tail: 1.0,
			marks: None,
		}
	}
}

impl Stroke {
	fn marked(mut self, motion: &Motion) -> Stroke {
		self.marks.clone_from(motion);
		self
	}
}

// Calls `place` for points scattered over the mesh, `density` per square
// stud, at least `least` on every triangle, each with its own seed. Bigger
// brushes (see Look::brush) cover more each, so fewer are placed.
fn scatter(mesh: &Mesh, look: &Look, wear: &Wear, density: f64, least: u32, salt: u32, mut place: impl FnMut(Spot, u32)) {
	let density = density / (look.brush * look.brush);
	// The same triangles in the same order as mesh_triangles, with their UVs.
	for (index, corners) in mesh.triangles().iter().enumerate() {
		let t = corners.map(|c| c.position);
		if wear.far(t) {
			continue;
		}
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
			if !(wear.near)(at) {
				continue;
			}
			let uv = [0, 1].map(|axis| corners[0].uv[axis] + (corners[1].uv[axis] - corners[0].uv[axis]) * a + (corners[2].uv[axis] - corners[0].uv[axis]) * b);
			place(Spot::new(at, wear.tri_chunk.get(index).copied().unwrap_or(0), uv, normal, look.brush), id);
		}
	}
}

// Paints the part. `base` gives the sRGB coat color at a point and normal.
// The base colour at a spot, darkened toward the bottom of the part.
fn coat_at(look: &Look, wear: &Wear, base: &mut dyn FnMut(Vec3, Vec3) -> [f64; 3], spot: &Spot) -> [f64; 3] {
	base_at(look, wear, base, spot.at, spot.normal)
}

// The coat colour at one point, for a part painted crisply texel by texel
// (machine finishes such as hazard tape or a ribbed belt, which brush
// strokes would smear): the base colour, darkened toward the bottom.
pub fn base_at(look: &Look, wear: &Wear, base: &mut dyn FnMut(Vec3, Vec3) -> [f64; 3], at: Vec3, normal: Vec3) -> [f64; 3] {
	let color = linear(base(at, normal));
	let low = (wear.low)(at);
	let fade = low * low * (3.0 - 2.0 * low) * look.gradient;
	let tint = linear([0.45, 0.42, 0.6]);
	std::array::from_fn::<f64, 3, _>(|k| color[k] + (color[k] * tint[k] - color[k]) * fade)
}

// The base coat: flat strokes sideways round walls and any way across tops.
pub fn coat(mesh: &Mesh, look: &Look, wear: &Wear, base: &mut dyn FnMut(Vec3, Vec3) -> [f64; 3]) -> Canvas {
	let mut canvas = Canvas::new(look.brush);
	scatter(mesh, look, wear, COAT_DENSITY, 1, 1, |spot, id| {
		// The stroke is shaped before it is coloured: its colour comes from the
		// model script, one call at a time, and most strokes scattered on the
		// neighbouring chunks can never touch this one.
		let (mut stroke, shade, warm) = coat_stroke(look, &spot, id, spot.normal[2].abs() > WALL);
		if wear.out_of_touch(stroke.centre(), stroke.reach() + canvas.cell_size()) {
			return;
		}
		let coat = coat_at(look, wear, base, &spot);
		stroke.color = [coat[0] * shade * (1.0 + warm), coat[1] * shade, coat[2] * shade * (1.0 - warm)];
		canvas.add(stroke);
	});
	canvas
}

// One coat stroke at a spot, still uncoloured, with how much lighter or
// darker (`shade`) and warmer or cooler (`warm`) its paint is mixed. Tops
// take strokes any way, walls sideways.
fn coat_stroke(look: &Look, spot: &Spot, id: u32, top: bool) -> (Stroke, f64, f64) {
	let r = |j: u32| hash(id.wrapping_add(j));
	let angle = (r(2) - 0.5) * 0.5 + if top { r(3) * std::f64::consts::TAU } else { 0.0 };
	// Each stroke is mixed a little lighter or darker, warmer or cooler.
	let shade = 1.0 + (r(4) - 0.5) * 0.3;
	let warm = (r(7) - 0.5) * 0.14;
	let (kind, length, width) = if look.stamps { (Brush::Stamp, 0.7 + 0.9 * r(5), 0.3 + 0.35 * r(6)) } else { (Brush::Flat, 0.35 + 0.35 * r(5), 0.16 + 0.08 * r(6)) };
	(spot.stroke(kind, spot.at, spot.heading(angle), length, width, [0.0; 3], 1.0, id).marked(&look.brushes.coat), shade, warm)
}

// A tiled coat's square of strokes, wrapping at its edges. Each texel holds
// what the strokes multiply the base colour by (linear), the coat as a
// canvas paints it on a white base, so a chunk's coat is its own base colour
// times the tile.
pub struct Tile {
	size: usize,
	per_stud: f64,
	texels: Vec<[f32; 3]>,
}

impl Tile {
	// The factor at (u, v) studs into the tile, blended between the four
	// nearest texels, wrapping round the edges.
	pub fn sample(&self, u: f64, v: f64) -> [f64; 3] {
		let (x, y) = (u * self.per_stud - 0.5, v * self.per_stud - 0.5);
		let (x0, y0) = (x.floor(), y.floor());
		let (fx, fy) = (x - x0, y - y0);
		let n = self.size as i64;
		let at = |i: i64, j: i64| self.texels[(j.rem_euclid(n) * n + i.rem_euclid(n)) as usize];
		let (i, j) = (x0 as i64, y0 as i64);
		let (a, b, c, d) = (at(i, j), at(i + 1, j), at(i, j + 1), at(i + 1, j + 1));
		std::array::from_fn(|k| {
			let low = f64::from(a[k]) + (f64::from(b[k]) - f64::from(a[k])) * fx;
			let high = f64::from(c[k]) + (f64::from(d[k]) - f64::from(c[k])) * fx;
			low + (high - low) * fy
		})
	}
}

type TileKey = Vec<u64>;

// Tiles painted this run, shared by every chunk with the same coat strokes.
fn tiles() -> &'static std::sync::Mutex<std::collections::HashMap<TileKey, std::sync::Arc<Tile>>> {
	static TILES: std::sync::OnceLock<std::sync::Mutex<std::collections::HashMap<TileKey, std::sync::Arc<Tile>>>> = std::sync::OnceLock::new();
	TILES.get_or_init(Default::default)
}

// The tile for a top (strokes any way) or a wall (strokes sideways, along
// the tile's u), painted at `per_stud` texels a stud the first time it is asked for.
pub fn tile(look: &Look, tiled: TiledCoat, top: bool, variant: u32, per_stud: usize) -> std::sync::Arc<Tile> {
	let key: TileKey = [tiled.tile, look.brush, f64::from(u8::from(look.stamps)), f64::from(u8::from(top)), f64::from(variant), per_stud as f64].into_iter().chain(look.brushes.coat.iter().flat_map(|marks| marks.numbers())).map(f64::to_bits).collect();
	if let Some(found) = tiles().lock().expect("tile store").get(&key) {
		return found.clone();
	}
	let painted = std::sync::Arc::new(paint_tile(look, tiled.tile, top, variant, per_stud));
	tiles().lock().expect("tile store").entry(key).or_insert(painted).clone()
}

// The tiles a chunk reads, each painted on its own thread if not yet painted.
pub fn tiles_for(look: &Look, tiled: TiledCoat, wanted: &[(bool, u32)], per_stud: usize) -> Vec<std::sync::Arc<Tile>> {
	std::thread::scope(|scope| {
		let handles: Vec<_> = wanted.iter().map(|&(top, variant)| scope.spawn(move || tile(look, tiled, top, variant, per_stud))).collect();
		handles.into_iter().map(|h| h.join().expect("tile painting")).collect()
	})
}

// The tile is painted stroke by stroke over each stroke's own footprint,
// which gives what `Canvas::paint` gives texel by texel (each texel starts
// from the nearest stroke's colour, then takes every stroke over it in the
// order laid) while testing far fewer strokes per texel. A stroke running
// over an edge carries on over the opposite one, so the edges meet seamlessly.
fn paint_tile(look: &Look, side: f64, top: bool, variant: u32, per_stud: usize) -> Tile {
	let size = ((side * per_stud as f64).round() as usize).max(1);
	let normal = [0.0, 0.0, 1.0];
	// As many strokes as `scatter` lays on that much surface.
	let count = (side * side * COAT_DENSITY / (look.brush * look.brush)).round() as u32;
	let salt = 0x7a11_e5u32 ^ (variant * 2 + u32::from(top)).wrapping_mul(0x9e37_79b9);
	let strokes: Vec<Stroke> = (0..count)
		.map(|k| {
			let id = (salt ^ k.wrapping_mul(0x85eb_ca6b)).wrapping_mul(0xc2b2_ae35);
			let at = [hash(id) * side, hash(id.wrapping_add(1)) * side, 0.0];
			let spot = Spot { at, chunk: 0, uv: [0.0; 2], brush: look.brush, normal, up: [0.0, 1.0, 0.0], side: [1.0, 0.0, 0.0] };
			let (mut stroke, shade, warm) = coat_stroke(look, &spot, id, top);
			stroke.color = [shade * (1.0 + warm), shade, shade * (1.0 - warm)];
			stroke
		})
		.collect();
	let step = side / size as f64;
	let n = size as i64;
	// The texels a stroke may touch, unwrapped: round its painted rectangle,
	// or round its whole reach when a motion draws it.
	let span = |stroke: &Stroke, reach_only: bool| -> [i64; 4] {
		let (low, high) = if reach_only || stroke.marks.is_some() {
			let (c, r) = (stroke.centre(), stroke.reach());
			([c[0] - r, c[1] - r], [c[0] + r, c[1] + r])
		} else {
			let half = scale(stroke.across, stroke.width / 2.0);
			let end = add(stroke.start, scale(stroke.along, stroke.length));
			let corners = [add(stroke.start, half), sub(stroke.start, half), add(end, half), sub(end, half)];
			let low = [0, 1].map(|k| corners.iter().map(|c| c[k]).fold(f64::MAX, f64::min) - step);
			let high = [0, 1].map(|k| corners.iter().map(|c| c[k]).fold(f64::MIN, f64::max) + step);
			(low, high)
		};
		[(low[0] / step - 0.5).floor() as i64, (high[0] / step - 0.5).ceil() as i64, (low[1] / step - 0.5).floor() as i64, (high[1] / step - 0.5).ceil() as i64]
	};
	let at = |i: i64, j: i64| -> (usize, Vec3) { ((j.rem_euclid(n) * n + i.rem_euclid(n)) as usize, [(i as f64 + 0.5) * step, (j as f64 + 0.5) * step, 0.0]) };
	// The nearest coat stroke's colour under every texel, as `Canvas::paint` starts.
	let mut under = vec![(f64::MAX, [0.5; 3]); size * size];
	for stroke in &strokes {
		let [x0, x1, y0, y1] = span(stroke, true);
		let centre = stroke.centre();
		for j in y0..=y1 {
			for i in x0..=x1 {
				let (index, p) = at(i, j);
				let offset = sub(p, centre);
				let d = dot(offset, offset);
				if d < under[index].0 {
					under[index] = (d, stroke.color);
				}
			}
		}
	}
	let mut colours: Vec<[f64; 3]> = under.into_iter().map(|(_, c)| c).collect();
	for stroke in &strokes {
		let [x0, x1, y0, y1] = span(stroke, false);
		for j in y0..=y1 {
			for i in x0..=x1 {
				let (index, p) = at(i, j);
				let alpha = stroke.cover(p, normal);
				if alpha > 0.0 {
					let paint = stroke.color.map(|c| c * stroke.tone(p));
					let color = &mut colours[index];
					*color = std::array::from_fn(|k| color[k] + (paint[k] - color[k]) * alpha);
				}
			}
		}
	}
	if std::env::var_os("MODELKIT_PROFILE").is_some() {
		eprintln!("tiled coat: painted a {} tile, variant {variant}, {size} x {size} texels", if top { "top" } else { "wall" });
	}
	Tile { size, per_stud: size as f64 / side, texels: colours.into_iter().map(|c| c.map(|x| x as f32)).collect() }
}

// Where a texel finds its coat on the tiles: whether it is a top, which
// variant, and the spot (u, v) in studs on that tile. The texel's position is
// projected along the axis its face normal most faces (triplanar, unblended)
// and wrapped by the tile's side. Each tile-sized cell picks its variant and
// turn from a hash, and cells meet along wavy lines so no grid shows. Tops
// turn by quarters; walls only mirror, so their strokes stay sideways.
pub fn tile_place(tiled: TiledCoat, p: Vec3, n: Vec3) -> (bool, u32, f64, f64) {
	let a = n.map(f64::abs);
	let axis = if a[0] >= a[1] && a[0] >= a[2] { 0 } else if a[1] >= a[2] { 1 } else { 2 };
	let (u, v) = match axis {
		0 => (p[1], p[2]),
		1 => (p[0], p[2]),
		_ => (p[0], p[1]),
	};
	let top = a[2] > WALL;
	let side = tiled.tile;
	let cell = [(u + wobble(u, v, side, 11)) / side, (v + wobble(u, v, side, 23)) / side].map(|c| c.floor() as i64 as u32);
	let seed = cell[0].wrapping_mul(73_856_093) ^ cell[1].wrapping_mul(19_349_663) ^ (axis as u32 * 2 + u32::from(top)).wrapping_mul(83_492_791);
	let variant = ((hash(seed) * f64::from(tiled.variants)) as u32).min(tiled.variants - 1);
	let turn = (hash(seed ^ 0x5bd1_e995) * 4.0) as u32;
	let (s, t) = (u.rem_euclid(side), v.rem_euclid(side));
	let (s, t) = match (top, turn) {
		(_, 0) => (s, t),
		(true, 1) => (side - t, s),
		(true, 2) => (side - s, side - t),
		(true, _) => (t, side - s),
		(false, 1) => (side - s, t),
		(false, 2) => (s, side - t),
		(false, _) => (side - s, side - t),
	};
	(top, variant, s, t)
}

// A smooth offset of up to an eighth of a tile either way, for bending the
// lines where tile cells meet.
fn wobble(u: f64, v: f64, side: f64, salt: u32) -> f64 {
	let step = side / 4.0;
	let (x, y) = (u / step, v / step);
	let (x0, y0) = (x.floor(), y.floor());
	let smooth = |t: f64| t * t * (3.0 - 2.0 * t);
	let (sx, sy) = (smooth(x - x0), smooth(y - y0));
	let at = |i: f64, j: f64| hash((i as i64 as u32).wrapping_mul(73_856_093) ^ (j as i64 as u32).wrapping_mul(19_349_663) ^ salt.wrapping_mul(0x9e37_79b9)) - 0.5;
	let low = at(x0, y0) + (at(x0 + 1.0, y0) - at(x0, y0)) * sx;
	let high = at(x0, y0 + 1.0) + (at(x0 + 1.0, y0 + 1.0) - at(x0, y0 + 1.0)) * sx;
	(low + (high - low) * sy) * step
}

// Wear over the base coat: grime, rust, drips, scuffs and scratches.
pub fn wear(mesh: &Mesh, look: &Look, wear: &Wear, base: &mut dyn FnMut(Vec3, Vec3) -> [f64; 3]) -> Canvas {
	let mut canvas = Canvas::new(look.brush);
	if look.rust <= 0.0 && !look.rubber {
		return canvas;
	}

	// Grime sponged on low down and into creases; rubber gathers pale dust,
	// on top surfaces too.
	scatter(mesh, look, wear, 5.0, 0, 2, |spot, id| {
		let r = |j: u32| hash(id.wrapping_add(j));
		let mut chance = ((wear.low)(spot.at) * 0.8).max((wear.crease)(spot.chunk, spot.uv));
		if look.rubber {
			chance = chance.max(spot.normal[2] * 0.5);
		}
		if r(2) >= chance {
			return;
		}
		let color = if look.rubber {
			linear(DUST)
		} else {
			let coat = coat_at(look, wear, base, &spot);
			let tint = linear(GRIME_TINT);
			std::array::from_fn(|k| coat[k] * tint[k])
		};
		let width = 0.12 + 0.2 * r(3);
		canvas.add(spot.stroke(Brush::Sponge, spot.at, spot.heading(r(4) * 6.3), width, width, color, 0.25 + 0.2 * r(5), id).marked(&look.brushes.grime));
	});

	if look.rubber {
		// Pale scuffs where it has rubbed.
		scatter(mesh, look, wear, 1.5, 0, 3, |spot, id| {
			let r = |j: u32| hash(id.wrapping_add(j));
			if r(2) >= 0.2 + 0.8 * (wear.edge)(spot.chunk, spot.uv) {
				return;
			}
			let color = coat_at(look, wear, base, &spot).map(|c| (c * 1.8).min(1.0));
			canvas.add(spot.stroke(Brush::Liner, spot.at, spot.heading(r(3) * 6.3), 0.1 + 0.2 * r(4), 0.02, color, 0.5, id).marked(&look.brushes.scratch));
		});
		return canvas;
	}

	// Rust patches.
	let amount = look.rust;
	scatter(mesh, look, wear, PATCH_DENSITY * amount, 0, 4, |spot, id| {
		let r = |j: u32| hash(id.wrapping_add(j));
		let chance = if look.rust_edges {
			let seam = (wear.edge)(spot.chunk, spot.uv).max((wear.crease)(spot.chunk, spot.uv));
			let low = (wear.low)(spot.at);
			// Whole stretches stay clean, so what rust there is clusters.
			let cell = [spot.at[0] / RUST_CLUSTER, spot.at[1] / RUST_CLUSTER, spot.at[2] / (RUST_CLUSTER * 0.45)].map(|c| c.floor() as i64 as u32);
			let clean = hash(cell[0].wrapping_mul(73_856_093) ^ cell[1].wrapping_mul(19_349_663) ^ cell[2].wrapping_mul(83_492_791)) < 0.4;
			(if seam > 0.12 { seam } else { 0.0 }).max(low * low * low * 0.22) * if clean { 0.12 } else { 1.0 }
		} else {
			(wear.edge)(spot.chunk, spot.uv).max((wear.crease)(spot.chunk, spot.uv)).max((wear.low)(spot.at) * 0.6).max(0.05)
		};
		if r(2) >= chance {
			return;
		}
		let size = PATCH_RADIUS * (0.4 + 0.6 * amount) * (0.5 + r(3)) * if look.rust_edges { 0.55 + 1.5 * r(9) * r(9) } else { 1.0 };
		let stretch = if look.rust_edges { 1.0 + 2.2 * r(8) } else { 1.0 };
		let mut j = 10;
		let mut next = || {
			j += 1;
			r(j)
		};
		let mut around = |reach: f64| {
			let (angle, spread) = (next() * std::f64::consts::TAU, reach * next().sqrt());
			spot.moved(angle.cos() * spread / stretch.sqrt(), angle.sin() * spread * stretch)
		};
		let dabs = 3 + (amount * 5.0) as u32;
		let mut lowest = 0.0f64;
		for k in 0..dabs {
			let centre = around(size * 0.7);
			let width = size * (0.7 + 0.7 * r(100 + k));
			lowest = lowest.min(dot(sub(centre, spot.at), spot.up) - width / 2.0);
			canvas.add(spot.stroke(Brush::Sponge, centre, spot.heading(r(120 + k) * 6.3), width, width, linear(RUST_DARK), 1.0, id ^ k).marked(&look.brushes.rust));
		}
		for k in 0..dabs {
			let centre = around(size * 0.5);
			let along = spot.heading(r(140 + k) * 6.3);
			canvas.add(spot.stroke(Brush::Round, centre, along, size * (0.6 + 0.6 * r(160 + k)), size * (0.3 + 0.25 * r(180 + k)), linear(RUST_ORANGE), 0.9, id ^ (k + 50)).marked(&look.brushes.rust));
		}
		for k in 0..2 + (r(4) * 2.0) as u32 {
			let centre = add(around(size * 0.4), scale(spot.up, size * 0.35));
			canvas.add(spot.stroke(Brush::Dry, centre, spot.heading((r(200 + k) - 0.5) * 0.6), size * 0.8, size * 0.35, linear(RUST_FLAKE), 0.9, id ^ (k + 90)).marked(&look.brushes.rust));
		}
		// Chipped paint: a shadow lined in under the top edge, and a lit lip
		// lined along under the bottom edge.
		let lip = coat_at(look, wear, base, &spot).map(|c| (c * 1.45 + 0.03).min(1.0));
		let dark = linear(RUST_DARK).map(|c| c * 0.45);
		canvas.add(spot.stroke(Brush::Liner, spot.moved((r(5) - 0.5) * size * 0.4, size * 0.7), spot.side, size * 1.3, 0.02, dark, 0.9, id ^ 7).marked(&look.brushes.rust));
		canvas.add(spot.stroke(Brush::Liner, spot.moved((r(6) - 0.5) * size * 0.4, lowest - 0.012), spot.side, size * 1.4, 0.02, lip, 0.9, id ^ 8).marked(&look.brushes.rust));
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
			canvas.add(spot.stroke(Brush::Liner, add(top, scale(down, length / 2.0)), down, length, width, orange, 0.85, id ^ (k + 300)).marked(&look.brushes.drip));
			canvas.add(spot.stroke(Brush::Round, add(top, scale(down, length)), down, width * 2.2, width * 1.8, orange, 0.85, id ^ (k + 400)).marked(&look.brushes.drip));
		}
	});

	// Scratches lined in clusters, each cluster one way, mostly along worn edges.
	scatter(mesh, look, wear, 2.0, 0, 5, |spot, id| {
		let r = |j: u32| hash(id.wrapping_add(j));
		if r(2) >= 0.15 + 0.85 * (wear.edge)(spot.chunk, spot.uv) {
			return;
		}
		let along = spot.heading(r(3) * 6.3);
		let across = cross(spot.normal, along);
		let coat = coat_at(look, wear, base, &spot);
		let metal = linear(BARE_METAL);
		let color = std::array::from_fn(|k| (coat[k] + metal[k] * 2.0) / 3.0);
		for k in 0..3 + (r(4) * 4.0) as u32 {
			let offset = add(scale(across, (r(10 + k) - 0.5) * 0.12), scale(along, (r(20 + k) - 0.5) * 0.15));
			let centre = add(spot.at, offset);
			canvas.add(spot.stroke(Brush::Liner, centre, along, 0.1 + 0.25 * r(30 + k), 0.01 + 0.008 * r(40 + k), color, 0.9, id ^ (k + 500)).marked(&look.brushes.scratch));
		}
	});
	canvas
}
