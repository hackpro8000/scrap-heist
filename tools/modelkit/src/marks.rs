// Marks drawn by a moving hand. A motion is the way the brush travels along or
// across a line, which may be an edge, a crease or a painted stroke. A model
// script picks one per brush slot and sets any of its numbers by name, so tuning
// never rebuilds the engine.

use crate::bake::hash;
use crate::brush::stamp_alpha;
use crate::hand::settings;

// Raise this when a motion changes, so cached textures are repainted.
const VERSION: f64 = 1.0;

#[derive(Clone, Copy, PartialEq)]
pub enum Motion {
	Line,
	Press,
	Worn,
	Skip,
	Feather,
	Flick,
	Zigzag,
	Retrace,
	Twist,
	DragOff,
	Scrub,
	Overshoot,
	Tremble,
	Crosshatch,
	Stipple,
	Loops,
}

const MOTIONS: [(&str, Motion); 16] = [
	("line", Motion::Line),
	("press", Motion::Press),
	("worn", Motion::Worn),
	("skip", Motion::Skip),
	("feather", Motion::Feather),
	("flick", Motion::Flick),
	("zigzag", Motion::Zigzag),
	("retrace", Motion::Retrace),
	("twist", Motion::Twist),
	("drag_off", Motion::DragOff),
	("scrub", Motion::Scrub),
	("overshoot", Motion::Overshoot),
	("tremble", Motion::Tremble),
	("crosshatch", Motion::Crosshatch),
	("stipple", Motion::Stipple),
	("loops", Motion::Loops),
];

// Studs throughout, except the shares (0 to 1), `passes`, `bristles` and
// `tremble_rate` (shakes per stud), `taper_end` (taper lengths) and `falloff` (a power). `length` is a ring or loop's radius for
// scrub and loops, and `spread` is the swing each way for zigzag.
settings! {
	length: 0.8, pitch: 0.1, width: 0.04, spread: 0.0, lean: 0.0, jitter: 0.4, vary: 0.4, vary_step: 0.7,
	min_width: 0.1, passes: 2.0, flare: 0.25, tremble: 0.0, tremble_rate: 9.0, skip: 0.0, skip_step: 0.4, bristles: 5.0,
	taper: 0.0, taper_end: 3.0, uneven: 0.0, uneven_step: 0.5, falloff: 0.0, stamp: 0.0, stamp_length: 0.5,
}

fn preset(motion: Motion) -> &'static [(&'static str, f64)] {
	match motion {
		Motion::Line => &[],
		Motion::Press => &[("length", 1.6), ("pitch", 1.0), ("width", 0.06), ("spread", 0.015), ("min_width", 0.15)],
		Motion::Worn => &[("length", 1.6), ("pitch", 1.0), ("width", 0.06), ("spread", 0.015), ("min_width", 0.15), ("skip", 0.3)],
		Motion::Skip => &[("length", 1.6), ("pitch", 1.1), ("width", 0.06), ("spread", 0.01), ("min_width", 0.3), ("skip", 0.55)],
		Motion::Feather => &[("length", 0.8), ("pitch", 0.1), ("width", 0.03), ("spread", 0.07), ("lean", 0.06), ("jitter", 0.5), ("vary", 0.6), ("min_width", 0.0)],
		Motion::Flick => &[("length", 0.32), ("pitch", 0.045), ("width", 0.05), ("lean", 0.5), ("jitter", 0.5), ("vary", 0.6)],
		Motion::Zigzag => &[("spread", 0.22), ("pitch", 0.02), ("width", 0.06), ("jitter", 0.35), ("vary", 0.6)],
		Motion::Retrace => &[("width", 0.03), ("spread", 0.05), ("vary_step", 0.9)],
		Motion::Twist => &[("width", 0.08), ("pitch", 0.7), ("min_width", 0.06)],
		Motion::DragOff => &[("length", 0.6), ("pitch", 0.03), ("width", 0.03), ("vary", 0.6), ("jitter", 0.6)],
		Motion::Scrub => &[("length", 0.07), ("pitch", 0.09), ("width", 0.02), ("spread", 0.07)],
		Motion::Overshoot => &[("length", 1.0), ("width", 0.04), ("flare", 0.25)],
		Motion::Tremble => &[("width", 0.04), ("tremble", 0.025)],
		Motion::Crosshatch => &[("length", 0.3), ("pitch", 0.09), ("width", 0.02), ("lean", 1.0), ("jitter", 0.3)],
		Motion::Stipple => &[("pitch", 0.07), ("width", 0.03), ("spread", 0.12), ("jitter", 1.0)],
		Motion::Loops => &[("length", 0.07), ("pitch", 0.12), ("width", 0.018), ("jitter", 0.3)],
	}
}

pub struct Marks {
	motion: Motion,
	tuning: Tuning,
}

// Where a texel sits against the edge being drawn.
pub struct Place {
	pub seed: u32,
	// Studs along the edge, the same on both of its faces.
	pub along: f64,
	// Studs off the edge, positive on one face and negative on the other.
	pub off: f64,
	// The highlight's taper here, 1 at full strength and 0 at nothing.
	pub taper: f64,
	// Studs to the nearest end of the edge, when known.
	pub corner: Option<f64>,
	// This face is the lower of the two.
	pub below: bool,
}

fn random(seed: u32, k: i64, salt: u32) -> f64 {
	hash(seed.wrapping_add((k as u32).wrapping_mul(131)).wrapping_add(salt.wrapping_mul(4111)))
}

// A smooth value from 0 to 1 that changes once per unit of x.
fn wander(seed: u32, x: f64) -> f64 {
	let cell = x.floor();
	let f = x - cell;
	let at = |k: i64| hash(seed.wrapping_add((k as u32).wrapping_mul(2_654_435_761)));
	at(cell as i64) + (at(cell as i64 + 1) - at(cell as i64)) * f * f * (3.0 - 2.0 * f)
}

fn rim(across: f64, soft: f64) -> f64 {
	((1.0 - across) / soft).clamp(0.0, 1.0)
}

fn lay(clear: &mut f64, alpha: f64) {
	*clear *= 1.0 - alpha.clamp(0.0, 1.0);
}

fn near_segment(px: f64, py: f64, (ax, ay): (f64, f64), (bx, by): (f64, f64)) -> f64 {
	let (ex, ey) = (bx - ax, by - ay);
	let u = (((px - ax) * ex + (py - ay) * ey) / (ex * ex + ey * ey).max(1e-12)).clamp(0.0, 1.0);
	(px - ax - ex * u).hypot(py - ay - ey * u)
}

impl Marks {
	pub fn new(name: &str, overrides: &[(String, f64)]) -> Result<Marks, String> {
		let Some((_, motion)) = MOTIONS.iter().find(|(known, _)| *known == name) else {
			return Err(format!("unknown litMotion {name}; the motions are: {}", MOTIONS.map(|(known, _)| known).join(", ")));
		};
		let mut tuning = Tuning::default();
		for (key, value) in preset(*motion) {
			tuning.set(key, *value);
		}
		for (key, value) in overrides {
			if !tuning.set(key, *value) {
				return Err(format!("unknown litTune setting {key}; the settings are: {}", Tuning::names().join(", ")));
			}
		}
		tuning.pitch = tuning.pitch.max(0.005);
		tuning.vary_step = tuning.vary_step.max(0.01);
		tuning.skip_step = tuning.skip_step.max(0.01);
		Ok(Marks { motion: *motion, tuning })
	}

	// The numbers that key the texture cache.
	pub fn numbers(&self) -> Vec<f64> {
		let motion = MOTIONS.iter().position(|(_, known)| *known == self.motion).unwrap_or(0) as f64;
		[VERSION + 512.0, motion].into_iter().chain(self.tuning.numbers()).collect()
	}

	// How far from an edge this motion can leave paint.
	pub fn reach(&self) -> f64 {
		let t = &self.tuning;
		let brush = 1.6 * t.width + 1.5 * t.tremble;
		brush + match self.motion {
			Motion::Flick | Motion::DragOff | Motion::Crosshatch => t.length,
			Motion::Scrub | Motion::Loops => t.spread + 1.4 * t.length,
			Motion::Overshoot => t.spread + t.flare,
			_ => t.spread + t.lean * t.length,
		}
	}

	// How much a stroke of this motion covers, `along` studs down a painted
	// stroke of the given length and width and `side` off its centre. The motion
	// is scaled so its own width matches the stroke's.
	pub fn paint_stroke(&self, seed: u32, along: f64, side: f64, length: f64, width: f64, below: bool) -> f64 {
		let u = along / length.max(1e-6);
		if !(0.0..=1.0).contains(&u) {
			return 0.0;
		}
		let size = self.size_on(width);
		self.paint(&Place { seed, along: along / size, off: side / size, taper: (std::f64::consts::PI * u).sin().max(0.0).powf(0.3), corner: Some(along.min(length - along) / size), below })
	}

	fn size_on(&self, width: f64) -> f64 {
		width / 2.0 / self.tuning.width.max(1e-6)
	}

	// How far from a painted stroke's centre this motion can reach.
	pub fn reach_on(&self, width: f64) -> f64 {
		self.reach() * self.size_on(width)
	}

	// How much is painted at this place, 0 to 1.
	pub fn paint(&self, place: &Place) -> f64 {
		let t = &self.tuning;
		let seed = place.seed;
		let mut taper = place.taper;
		if t.uneven > 0.0 {
			taper *= 1.0 - t.uneven + t.uneven * wander(seed.wrapping_add(600), place.along / t.uneven_step.max(0.01));
		}
		if let (true, Some(corner)) = (t.taper > 0.0, place.corner) {
			let far = (-t.taper_end).exp();
			taper *= (((-corner / t.taper).exp() - far) / (1.0 - far)).max(0.0);
		}
		let tone = 1.0 - t.vary + t.vary * wander(seed.wrapping_add(17), place.along / t.vary_step);
		let width = t.width * taper.sqrt() * tone;
		if width <= 0.0 {
			return 0.0;
		}
		let shake = t.tremble * ((place.along * t.tremble_rate * 6.283).sin() + 0.5 * (place.along * t.tremble_rate * 10.1 + 1.7).sin());
		let (x, y) = (place.along, place.off - shake);
		let cover = match self.motion {
			Motion::Press | Motion::Worn | Motion::Skip | Motion::Feather => self.along_strokes(seed, x, y, taper, width),
			Motion::Flick => self.flicks(seed, x, y.abs(), taper, width),
			Motion::Zigzag => self.zigzag(seed, x, y, taper, width),
			Motion::Retrace => self.retrace(seed, x, y, taper, width),
			Motion::Twist => self.twist(seed, x, y, width),
			Motion::DragOff if place.below => self.drag_off(seed, x, y.abs(), taper, width),
			Motion::DragOff => 0.0,
			Motion::Scrub => self.scrub(seed, x, y, taper, width),
			Motion::Overshoot => self.overshoot(seed, y, width, place.corner),
			Motion::Line | Motion::Tremble => rim(y.abs() / width, 0.4),
			Motion::Crosshatch => self.crosshatch(seed, x, y, taper, width),
			Motion::Stipple => self.stipple(seed, x, y, taper, width),
			Motion::Loops => self.loops(seed, x, y, taper, width),
		};
		let mut cover = cover;
		if t.falloff > 0.0 {
			cover *= (1.0 - (place.off.abs() / self.reach().max(1e-6)).min(1.0)).powf(t.falloff);
		}
		if t.stamp > 0.0 {
			let run = x / t.stamp_length.max(0.01);
			let shape = stamp_alpha(seed.wrapping_add((run.floor() as i64 as u32).wrapping_mul(977)), run - run.floor(), (y / (2.0 * self.reach().max(1e-6)) + 0.5).clamp(0.0, 1.0));
			cover *= 1.0 - t.stamp + t.stamp * shape;
		}
		if t.skip <= 0.0 {
			return cover;
		}
		// The brush runs dry: bristle by bristle, paint only catches in places.
		let bristle = (y / (2.0 * t.width.max(1e-3)) * t.bristles).floor() as i64;
		let caught = wander(seed.wrapping_add(200).wrapping_add((bristle as u32).wrapping_mul(37)), x / t.skip_step);
		cover * ((caught - t.skip) / 0.08).clamp(0.0, 1.0)
	}

	// Short strokes laid along the edge, overlapping end to end.
	fn along_strokes(&self, seed: u32, x: f64, y: f64, taper: f64, width: f64) -> f64 {
		let t = &self.tuning;
		let spread = t.spread * taper;
		let first = (x / t.pitch).floor() as i64;
		let longest = t.length * 1.3;
		let mut clear = 1.0;
		for k in first - (longest / t.pitch).ceil() as i64 - 1..=first + 1 {
			let start = (k as f64 + (random(seed, k, 1) - 0.5) * t.jitter) * t.pitch;
			let length = t.length * (1.0 + (random(seed, k, 2) - 0.5) * 0.6);
			let u = (x - start) / length;
			if !(0.0..=1.0).contains(&u) {
				continue;
			}
			let tilt = (random(seed, k, 4) * 2.0 - 1.0) * t.lean * taper;
			let centre = (random(seed, k, 3) * 2.0 - 1.0) * spread + (u - 0.5) * length * tilt;
			let swell = t.min_width + (1.0 - t.min_width) * (std::f64::consts::PI * u).sin().max(0.0).powf(0.7);
			let half = width * (0.6 + 0.8 * random(seed, k, 5)) * swell;
			lay(&mut clear, rim((y - centre).abs() / half.max(1e-6), 0.4) * (0.7 + 0.3 * random(seed, k, 6)));
		}
		1.0 - clear
	}

	// Strokes thrown off the edge, each lifting to a point.
	fn flicks(&self, seed: u32, x: f64, d: f64, taper: f64, width: f64) -> f64 {
		let t = &self.tuning;
		let length = t.length * taper;
		let lean_most = t.lean.abs() + t.jitter * 0.5;
		let first = (x / t.pitch).floor() as i64;
		let search = ((length * lean_most + 1.3 * width) / t.pitch).ceil() as i64 + 1;
		let mut clear = 1.0;
		for k in first - search..=first + search {
			let start = (k as f64 + (random(seed, k, 1) - 0.5) * t.jitter) * t.pitch;
			let reach = length * (1.0 - 0.6 * t.jitter * random(seed, k, 2));
			let u = d / reach.max(1e-6);
			if u >= 1.0 {
				continue;
			}
			let lean = t.lean + (random(seed, k, 3) - 0.5) * t.jitter;
			let half = width * (0.7 + 0.6 * random(seed, k, 4)) * (1.0 - u).powf(0.7);
			lay(&mut clear, rim((x - start - d * lean).abs() / half.max(1e-6), 0.3) * (0.75 + 0.25 * random(seed, k, 5)) * (1.0 - u * u));
		}
		1.0 - clear
	}

	// One brush swung back and forth across the edge, each swing over the last.
	fn zigzag(&self, seed: u32, x: f64, y: f64, taper: f64, width: f64) -> f64 {
		let t = &self.tuning;
		let swing = t.spread * taper;
		let node = |k: i64| {
			let upper = k.rem_euclid(2) == 0;
			let along = (k as f64 + (random(seed, k, 1) - 0.5) * t.jitter) * t.pitch;
			let drift = 1.0 - t.vary + t.vary * wander(seed.wrapping_add(if upper { 53 } else { 71 }), along / t.vary_step);
			let reach = swing * (1.0 - 0.5 * t.jitter * random(seed, k, 2)) * drift;
			(along, if upper { reach } else { -reach })
		};
		let first = (x / t.pitch).floor() as i64;
		let search = (1.4 * width / t.pitch).ceil() as i64 + 2;
		let (mut nearest, mut mark) = (f64::MAX, first);
		for k in first - search..=first + search {
			let distance = near_segment(x, y, node(k), node(k + 1));
			if distance < nearest {
				(nearest, mark) = (distance, k);
			}
		}
		let half = width * (0.75 + 0.5 * random(seed, mark, 3));
		rim(nearest / half, 0.25) * (0.85 + 0.15 * random(seed, mark, 4))
	}

	// The same line drawn over again, each pass missing the last a little.
	fn retrace(&self, seed: u32, x: f64, y: f64, taper: f64, width: f64) -> f64 {
		let t = &self.tuning;
		let mut clear = 1.0;
		for pass in 0..t.passes.round().max(1.0) as u32 {
			let path = wander(seed.wrapping_add(300 + pass * 7), x / t.vary_step);
			let weight = wander(seed.wrapping_add(400 + pass * 7), x / t.vary_step);
			let centre = (path * 2.0 - 1.0) * t.spread * taper;
			lay(&mut clear, rim((y - centre).abs() / (width * (0.7 + 0.6 * weight)), 0.4) * 0.92);
		}
		1.0 - clear
	}

	// A flat brush rolled as it moves, flipping between its face and its edge.
	fn twist(&self, seed: u32, x: f64, y: f64, width: f64) -> f64 {
		let t = &self.tuning;
		let roll = std::f64::consts::PI * x / t.pitch + 3.0 * t.jitter * wander(seed.wrapping_add(5), x / (3.0 * t.pitch));
		let half = width * (t.min_width + (1.0 - t.min_width) * roll.cos().abs());
		rim(y.abs() / half.max(1e-6), 0.35)
	}

	// Paint pulled off the edge, down the lower face.
	fn drag_off(&self, seed: u32, x: f64, d: f64, taper: f64, width: f64) -> f64 {
		let t = &self.tuning;
		let first = (x / t.pitch).floor() as i64;
		let search = (1.6 * width / t.pitch).ceil() as i64 + 1;
		let mut clear = 1.0;
		for k in first - search..=first + search {
			let start = (k as f64 + (random(seed, k, 1) - 0.5) * t.jitter) * t.pitch;
			let reach = t.length * taper * (1.0 - 0.7 * t.jitter * random(seed, k, 2));
			let u = d / reach.max(1e-6);
			if u >= 1.0 {
				continue;
			}
			let half = width * (0.7 + 0.6 * random(seed, k, 3)) * (1.0 - 0.7 * u);
			lay(&mut clear, rim((x - start).abs() / half.max(1e-6), 0.5) * (1.0 - u).powf(1.5));
		}
		1.0 - clear
	}

	// Small tight circles worked along the edge.
	fn scrub(&self, seed: u32, x: f64, y: f64, taper: f64, width: f64) -> f64 {
		let t = &self.tuning;
		let radius = t.length * taper.sqrt();
		let first = (x / t.pitch).floor() as i64;
		let search = ((1.3 * radius + 1.6 * width) / t.pitch).ceil() as i64 + 1;
		let mut clear = 1.0;
		for k in first - search..=first + search {
			let cx = (k as f64 + (random(seed, k, 1) - 0.5) * t.jitter) * t.pitch;
			let cy = (random(seed, k, 2) * 2.0 - 1.0) * t.spread * taper;
			let ring = radius * (0.7 + 0.6 * random(seed, k, 3));
			lay(&mut clear, rim(((x - cx).hypot(y - cy) - ring).abs() / width, 0.4) * 0.9);
		}
		1.0 - clear
	}

	// A line whose ends run on past the corner, flaring off onto a face.
	fn overshoot(&self, seed: u32, y: f64, width: f64, corner: Option<f64>) -> f64 {
		let t = &self.tuning;
		let base = rim(y.abs() / width, 0.4);
		let Some(corner) = corner.filter(|c| *c < t.length) else {
			return base;
		};
		let side = if random(seed, 0, 1) < 0.5 { 1.0 } else { -1.0 };
		let open = 1.0 - corner / t.length;
		base.max(rim((y - side * t.flare * open * open).abs() / width, 0.4))
	}

	// Two sets of short strokes crossing the edge at opposing angles.
	fn crosshatch(&self, seed: u32, x: f64, y: f64, taper: f64, width: f64) -> f64 {
		let t = &self.tuning;
		let length = t.length * taper;
		let first = (x / t.pitch).floor() as i64;
		let search = ((length * t.lean.abs() + 1.3 * width) / t.pitch).ceil() as i64 + 1;
		let mut clear = 1.0;
		for (set, lean) in [(11u32, t.lean), (29u32, -t.lean)] {
			let set_seed = seed.wrapping_add(set);
			for k in first - search..=first + search {
				let reach = length * (1.0 - 0.5 * t.jitter * random(set_seed, k, 2));
				let u = y.abs() / reach.max(1e-6);
				if u >= 1.0 {
					continue;
				}
				let start = (k as f64 + (random(set_seed, k, 1) - 0.5) * t.jitter) * t.pitch;
				let half = width * (0.7 + 0.6 * random(set_seed, k, 3)) * (1.0 - u).sqrt();
				lay(&mut clear, rim((x - start - y * lean).abs() / half.max(1e-6), 0.4) * 0.9);
			}
		}
		1.0 - clear
	}

	// Dabs of the tip, dense at the edge and thinning away from it.
	fn stipple(&self, seed: u32, x: f64, y: f64, taper: f64, width: f64) -> f64 {
		let t = &self.tuning;
		let spread = (t.spread * taper).max(1e-4);
		let (column, row) = ((x / t.pitch).floor() as i64, (y / t.pitch).floor() as i64);
		let search = (1.4 * width / t.pitch).ceil() as i64 + 1;
		let mut clear = 1.0;
		for k in column - search..=column + search {
			for j in row - search..=row + search {
				let cell = k.wrapping_mul(7919).wrapping_add(j);
				let cx = (k as f64 + 0.5 + (random(seed, cell, 1) - 0.5) * t.jitter) * t.pitch;
				let cy = (j as f64 + 0.5 + (random(seed, cell, 2) - 0.5) * t.jitter) * t.pitch;
				if random(seed, cell, 3) > (-cy.abs() / spread).exp() {
					continue;
				}
				let radius = width * (0.6 + 0.8 * random(seed, cell, 4));
				lay(&mut clear, rim((x - cx).hypot(y - cy) / radius, 0.4));
			}
		}
		1.0 - clear
	}

	// Cursive loops running along the edge.
	fn loops(&self, seed: u32, x: f64, y: f64, taper: f64, width: f64) -> f64 {
		const SAMPLES: usize = 16;
		let t = &self.tuning;
		let radius = t.length * taper.sqrt();
		let point = |turn: f64| {
			let angle = turn * 6.283;
			let r = radius * (1.0 - 0.5 * t.jitter * wander(seed.wrapping_add(9), turn));
			(turn * t.pitch + r * angle.sin(), r * angle.cos())
		};
		let first = (x / t.pitch).floor() as i64;
		let search = (1.4 * radius / t.pitch).ceil() as i64 + 1;
		let mut nearest = f64::MAX;
		for k in first - search..=first + search {
			for step in 0..SAMPLES {
				let turn = k as f64 + step as f64 / SAMPLES as f64;
				nearest = nearest.min(near_segment(x, y, point(turn), point(turn + 1.0 / SAMPLES as f64)));
			}
		}
		rim(nearest / width, 0.4)
	}
}
