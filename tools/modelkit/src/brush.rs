// Brushes and the canvas they paint on. Every color in a baked texture is
// laid down as a stroke: a brush dragged across the surface in 3D, so strokes
// run on across UV seams. Strokes composite in the order they were added.

use std::collections::HashMap;
use std::sync::OnceLock;

use crate::bake::hash;
use crate::mesh::{add, dot, scale, sub, Vec3};

// How far off the plane it was laid on a stroke still paints, so it bends
// with a warped panel but stops short of a bolt or lip standing off it.
const PLANE: f64 = 0.025;
// Lightness variation between bristles, per brush in the order of `Brush`.
const BRISTLE_TONE: [f64; 7] = [0.35, 0.25, 0.15, 0.2, 0.3, 0.0, 0.0];

#[derive(Clone, Copy, PartialEq)]
pub enum Brush {
	// Wide square brush for coats of paint: even width, many fine bristles.
	Flat,
	// Pointed round brush: swells in the middle and tapers to both ends.
	Round,
	// Thin rigger for lines: scratches, drips and chipped edges.
	Liner,
	// Dabbed sponge: a lobed blot full of pores, for grime, dust and rust.
	Sponge,
	// Nearly dry flat brush dragged lightly, so its bristles skip.
	Dry,
	// Pointed liner for drawn lines such as cracks: full width at its start,
	// thinning evenly to `tail` of that at its end, and never running dry.
	Taper,
	// A scanned stroke's shape, its length along the stroke (stamps/README.md).
	Stamp,
}

// The stamps' alpha, decoded once from the images built into the engine.
struct StampImage {
	width: usize,
	height: usize,
	alpha: Vec<u8>,
}

const STAMP_FILES: [&[u8]; 12] = [
	include_bytes!("stamps/00.png"),
	include_bytes!("stamps/01.png"),
	include_bytes!("stamps/02.png"),
	include_bytes!("stamps/03.png"),
	include_bytes!("stamps/04.png"),
	include_bytes!("stamps/05.png"),
	include_bytes!("stamps/06.png"),
	include_bytes!("stamps/07.png"),
	include_bytes!("stamps/08.png"),
	include_bytes!("stamps/09.png"),
	include_bytes!("stamps/10.png"),
	include_bytes!("stamps/11.png"),
];

fn stamps() -> &'static [StampImage] {
	static STAMPS: OnceLock<Vec<StampImage>> = OnceLock::new();
	STAMPS.get_or_init(|| {
		STAMP_FILES
			.iter()
			.map(|bytes| {
				let mut reader = png::Decoder::new(std::io::Cursor::new(*bytes)).read_info().expect("stamp image");
				let mut alpha = vec![0; reader.output_buffer_size()];
				let info = reader.next_frame(&mut alpha).expect("stamp image");
				StampImage { width: info.width as usize, height: info.height as usize, alpha }
			})
			.collect()
	})
}

// A stamp's alpha at (u, v); `seed` picks which stamp.
pub fn stamp_alpha(seed: u32, u: f64, v: f64) -> f64 {
	let all = stamps();
	all[seed as usize % all.len()].sample(u, v)
}

impl StampImage {
	// Alpha (0-1) at (u, v), each 0-1, blended between the four nearest texels.
	fn sample(&self, u: f64, v: f64) -> f64 {
		let (x, y) = (u * (self.width - 1) as f64, v * (self.height - 1) as f64);
		let (x0, y0) = (x.floor() as usize, y.floor() as usize);
		let (x1, y1) = ((x0 + 1).min(self.width - 1), (y0 + 1).min(self.height - 1));
		let (fx, fy) = (x - x0 as f64, y - y0 as f64);
		let at = |px: usize, py: usize| f64::from(self.alpha[py * self.width + px]) / 255.0;
		(at(x0, y0) * (1.0 - fx) + at(x1, y0) * fx) * (1.0 - fy) + (at(x0, y1) * (1.0 - fx) + at(x1, y1) * fx) * fy
	}
}

#[derive(Clone)]
pub struct Stroke {
	pub brush: Brush,
	// Where the stroke starts, and unit directions along it and across it on
	// the surface it was laid on, whose normal is `normal`.
	pub start: Vec3,
	pub along: Vec3,
	pub across: Vec3,
	pub normal: Vec3,
	pub length: f64,
	pub width: f64,
	// Linear color.
	pub color: [f64; 3],
	pub opacity: f64,
	pub seed: u32,
	// The width left at the stroke's end, as a share of `width` (Taper only).
	pub tail: f64,
	// Drawn with this motion instead of the brush's own shape.
	pub marks: Option<std::sync::Arc<crate::marks::Marks>>,
}

// How many bristles each brush has, and how far each may run dry early.
fn bristles(brush: Brush) -> (f64, f64) {
	match brush {
		Brush::Flat => (16.0, 0.3),
		Brush::Round => (8.0, 0.4),
		Brush::Liner => (3.0, 0.15),
		Brush::Sponge => (1.0, 0.0),
		Brush::Dry => (10.0, 0.5),
		Brush::Taper => (1.0, 0.0),
		Brush::Stamp => (1.0, 0.0),
	}
}

impl Stroke {
	pub fn centre(&self) -> Vec3 {
		add(self.start, scale(self.along, self.length / 2.0))
	}

	// How far the stroke reaches from its centre.
	pub fn reach(&self) -> f64 {
		self.length / 2.0 + self.marks.as_ref().map_or(self.width, |marks| self.width.max(marks.reach_on(self.width)))
	}

	// Lightness of the bristle under p, so a stroke streaks lighter and darker
	// along its length the way a loaded brush leaves paint.
	pub fn tone(&self, p: Vec3) -> f64 {
		let offset = sub(p, self.start);
		let side = dot(offset, self.across) / (self.width / 2.0).max(1e-6);
		let (count, _) = bristles(self.brush);
		let bristle = ((side.clamp(-1.0, 0.999) + 1.0) * 0.5 * count).floor() as u32;
		let streak = BRISTLE_TONE[self.brush as usize];
		1.0 + (hash(self.seed.wrapping_mul(53).wrapping_add(bristle * 7 + 3)) - 0.5) * streak
	}

	// Paint coverage (0-1) at p on a surface with normal n.
	pub fn cover(&self, p: Vec3, n: Vec3) -> f64 {
		if dot(n, self.normal) < 0.3 {
			return 0.0;
		}
		let offset = sub(p, self.start);
		if dot(offset, self.normal).abs() > PLANE {
			return 0.0;
		}
		let r = |k: u32| hash(self.seed.wrapping_mul(16).wrapping_add(k));
		let t = dot(offset, self.along);
		let side = dot(offset, self.across);
		if let Some(marks) = &self.marks {
			return marks.paint_stroke(self.seed, t, side, self.length, self.width, side * self.across[2] <= 0.0) * self.opacity;
		}
		if self.brush == Brush::Stamp {
			let (u, v) = (t / self.length, side / self.width + 0.5);
			if !(0.0..=1.0).contains(&u) || !(0.0..=1.0).contains(&v) {
				return 0.0;
			}
			let (u, v) = (if r(2) < 0.5 { u } else { 1.0 - u }, if r(3) < 0.5 { v } else { 1.0 - v });
			let all = stamps();
			return all[self.seed as usize % all.len()].sample(u, v) * self.opacity;
		}
		if self.brush == Brush::Sponge {
			return self.sponge(p, t - self.length / 2.0, side) * self.opacity;
		}
		let u = t / self.length;
		if !(0.0..=1.0).contains(&u) {
			return 0.0;
		}
		let half = self.width / 2.0
			* match self.brush {
				Brush::Flat | Brush::Dry => 0.85 + 0.15 * (std::f64::consts::PI * u).sin(),
				Brush::Round => (std::f64::consts::PI * u.powf(0.7)).sin().max(0.0).sqrt(),
				Brush::Taper => 1.0 - (1.0 - self.tail) * u,
				_ => (1.0 - 0.6 * u) * (u * 6.0).min(1.0).sqrt(),
			};
		let s = side / half.max(1e-6);
		if s.abs() >= 1.0 {
			return 0.0;
		}
		let (count, early) = bristles(self.brush);
		let bristle = ((s + 1.0) * 0.5 * count).floor() as u32;
		let b = |k: u32| hash(self.seed.wrapping_mul(97).wrapping_add(bristle * 13 + k));
		// Each bristle runs dry at its own point toward the tail.
		let dry = 1.0 - early * b(0) - 0.1 * r(0);
		let breakup = if self.brush == Brush::Taper { 1.0 } else { ((dry - u) / 0.08).clamp(0.0, 1.0) };
		if breakup <= 0.0 {
			return 0.0;
		}
		// A dry brush skips along each bristle.
		if self.brush == Brush::Dry {
			let skip = (t / 0.035).floor() as i64 as u32;
			if hash(self.seed ^ bristle.wrapping_mul(7919) ^ skip.wrapping_mul(104_729)) < 0.45 {
				return 0.0;
			}
		}
		let rim = ((1.0 - s.abs()) / 0.2).clamp(0.0, 1.0);
		let load = 0.75 + 0.25 * b(1);
		rim * load * breakup * self.opacity
	}

	// A sponge dab: a lobed outline, and pores where the sponge left no paint.
	fn sponge(&self, p: Vec3, t: f64, side: f64) -> f64 {
		let r = |k: u32| hash(self.seed.wrapping_mul(16).wrapping_add(k));
		let radius = self.width / 2.0;
		let distance = t.hypot(side) / radius;
		let angle = side.atan2(t);
		let edge = 1.0 + 0.22 * (3.0 * angle + r(1) * 6.3).sin() + 0.12 * (5.0 * angle + r(2) * 6.3).sin();
		if distance >= edge {
			return 0.0;
		}
		let pore = p.map(|c| (c / 0.022).floor() as i64 as u32);
		let open = hash(self.seed ^ pore[0].wrapping_mul(73_856_093) ^ pore[1].wrapping_mul(19_349_663) ^ pore[2].wrapping_mul(83_492_791));
		// Pores open up toward the dab's edge.
		if open < 0.2 + 0.4 * distance / edge {
			return 0.0;
		}
		1.0
	}
}

// Grid cell size for strokes at their usual size.
const CELL: f64 = 0.3;

pub struct Canvas {
	// Grid cell size, grown with the strokes so each still spans a few cells.
	cell_size: f64,
	strokes: Vec<Stroke>,
	grid: HashMap<[i64; 3], Vec<usize>>,
}

impl Canvas {
	// A canvas for strokes `brush` times their usual size.
	pub fn new(brush: f64) -> Canvas {
		Canvas { cell_size: CELL * brush, strokes: Vec::new(), grid: HashMap::new() }
	}

	// What the GPU bake uploads: the cell size, the strokes in the order they
	// were added, and the strokes listed under each cell.
	pub fn cell_size(&self) -> f64 {
		self.cell_size
	}

	pub fn strokes(&self) -> &[Stroke] {
		&self.strokes
	}

	pub fn grid(&self) -> &HashMap<[i64; 3], Vec<usize>> {
		&self.grid
	}

	fn cell(&self, p: Vec3) -> [i64; 3] {
		p.map(|c| (c / self.cell_size).floor() as i64)
	}

	pub fn add(&mut self, stroke: Stroke) {
		let (centre, reach) = (stroke.centre(), stroke.reach());
		let (low, high) = (self.cell(centre.map(|c| c - reach)), self.cell(centre.map(|c| c + reach)));
		for x in low[0]..=high[0] {
			for y in low[1]..=high[1] {
				for z in low[2]..=high[2] {
					self.grid.entry([x, y, z]).or_default().push(self.strokes.len());
				}
			}
		}
		self.strokes.push(stroke);
	}

	// The color the strokes leave at p, laid over the color of the nearest
	// coat stroke, so a spot the coat's bristles skipped shows the same paint.
	// The colour the strokes lay at p, and how much of p they cover (0-1).
	pub fn over(&self, p: Vec3, n: Vec3) -> ([f64; 3], f64) {
		let nearby = self.grid.get(&self.cell(p)).map(Vec::as_slice).unwrap_or(&[]);
		let (mut color, mut covered) = ([0.0; 3], 0.0f64);
		for &index in nearby {
			let stroke = &self.strokes[index];
			let alpha = stroke.cover(p, n);
			if alpha > 0.0 {
				let paint = stroke.color.map(|c| c * stroke.tone(p));
				color = if covered == 0.0 { paint } else { std::array::from_fn(|k| color[k] + (paint[k] - color[k]) * alpha) };
				covered = 1.0 - (1.0 - covered) * (1.0 - alpha);
			}
		}
		(color, covered)
	}

	pub fn paint(&self, p: Vec3, n: Vec3) -> [f64; 3] {
		let nearby = self.grid.get(&self.cell(p)).map(Vec::as_slice).unwrap_or(&[]);
		let mut under = (f64::MAX, [0.5; 3]);
		for &index in nearby {
			let stroke = &self.strokes[index];
			if !matches!(stroke.brush, Brush::Flat | Brush::Stamp) || dot(n, stroke.normal) < 0.3 {
				continue;
			}
			let offset = sub(p, stroke.centre());
			let d = dot(offset, offset) + dot(offset, stroke.normal).powi(2) * 50.0;
			if d < under.0 {
				under = (d, stroke.color);
			}
		}
		let mut color = under.1;
		for &index in nearby {
			let stroke = &self.strokes[index];
			let alpha = stroke.cover(p, n);
			if alpha > 0.0 {
				let paint = stroke.color.map(|c| c * stroke.tone(p));
				color = std::array::from_fn(|k| color[k] + (paint[k] - color[k]) * alpha);
			}
		}
		color
	}
}
