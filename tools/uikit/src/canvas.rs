// Canvas: an RGBA UI texture painted by a kit script, in sRGB 0-1 with
// straight alpha. Row 0 is the top and coordinates are pixels, as in
// Roblox's ImageLabel.

pub type Color = [f32; 4];

pub struct Canvas {
	pub width: usize,
	pub height: usize,
	pub pixels: Vec<Color>,
}

// An outline the painters fill. Each gives a signed distance in pixels,
// negative inside, so edges antialias and effects can measure depth.
pub enum Shape {
	Rect { x0: f64, y0: f64, x1: f64, y1: f64, radius: f64 },
	Circle { x: f64, y: f64, radius: f64 },
	Polygon(Vec<(f64, f64)>),
}

pub struct Outline {
	pub shape: Shape,
	// How far a hand-painted edge wanders, in pixels.
	pub wobble: f64,
	pub seed: f64,
	// How far the outline is pushed out past its shape, in pixels.
	pub grow: f64,
}

impl Shape {
	fn distance(&self, x: f64, y: f64) -> f64 {
		match self {
			Shape::Rect { x0, y0, x1, y1, radius } => {
				let r = radius.min((x1 - x0) / 2.0).min((y1 - y0) / 2.0);
				let dx = (x - (x0 + x1) / 2.0).abs() - ((x1 - x0) / 2.0 - r);
				let dy = (y - (y0 + y1) / 2.0).abs() - ((y1 - y0) / 2.0 - r);
				(dx.max(0.0).hypot(dy.max(0.0))) + dx.max(dy).min(0.0) - r
			}
			Shape::Circle { x: cx, y: cy, radius } => (x - cx).hypot(y - cy) - radius,
			Shape::Polygon(points) => {
				let mut nearest = f64::MAX;
				let mut inside = false;
				for i in 0..points.len() {
					let (ax, ay) = points[i];
					let (bx, by) = points[(i + 1) % points.len()];
					let (ex, ey) = (bx - ax, by - ay);
					let t = (((x - ax) * ex + (y - ay) * ey) / (ex * ex + ey * ey).max(1e-9)).clamp(0.0, 1.0);
					nearest = nearest.min((x - ax - ex * t).hypot(y - ay - ey * t));
					if (ay > y) != (by > y) && x < ax + (y - ay) / (by - ay) * ex {
						inside = !inside;
					}
				}
				if inside {
					-nearest
				} else {
					nearest
				}
			}
		}
	}

	fn bounds(&self) -> (f64, f64, f64, f64) {
		match self {
			Shape::Rect { x0, y0, x1, y1, .. } => (*x0, *y0, *x1, *y1),
			Shape::Circle { x, y, radius } => (x - radius, y - radius, x + radius, y + radius),
			Shape::Polygon(points) => points.iter().fold((f64::MAX, f64::MAX, f64::MIN, f64::MIN), |(a, b, c, d), &(x, y)| (a.min(x), b.min(y), c.max(x), d.max(y))),
		}
	}
}

impl Outline {
	pub fn distance(&self, x: f64, y: f64) -> f64 {
		let d = self.shape.distance(x, y) - self.grow;
		if self.wobble == 0.0 {
			return d;
		}
		d + self.wobble * (noise(x * 0.09 + self.seed, y * 0.09) + 0.4 * noise(x * 0.31, y * 0.31 + self.seed))
	}

	// Which way is out at (x, y), as a unit vector.
	fn outward(&self, x: f64, y: f64) -> (f64, f64) {
		let gx = self.shape.distance(x + 0.5, y) - self.shape.distance(x - 0.5, y);
		let gy = self.shape.distance(x, y + 0.5) - self.shape.distance(x, y - 0.5);
		let length = gx.hypot(gy).max(1e-9);
		(gx / length, gy / length)
	}
}

pub fn hash(mut x: u32) -> f64 {
	x ^= x >> 16;
	x = x.wrapping_mul(0x7feb_352d);
	x ^= x >> 15;
	x = x.wrapping_mul(0x846c_a68b);
	x ^= x >> 16;
	x as f64 / u32::MAX as f64
}

fn lattice(x: i64, y: i64) -> f64 {
	hash((x as u32).wrapping_mul(73_856_093) ^ (y as u32).wrapping_mul(19_349_663)) * 2.0 - 1.0
}

// Smooth value noise in about -1..1.
pub fn noise(x: f64, y: f64) -> f64 {
	let (fx, fy) = (x.floor(), y.floor());
	let (ix, iy) = (fx as i64, fy as i64);
	let smooth = |t: f64| t * t * (3.0 - 2.0 * t);
	let (u, v) = (smooth(x - fx), smooth(y - fy));
	let top = lattice(ix, iy) * (1.0 - u) + lattice(ix + 1, iy) * u;
	let bottom = lattice(ix, iy + 1) * (1.0 - u) + lattice(ix + 1, iy + 1) * u;
	top * (1.0 - v) + bottom * v
}

fn mix(a: [f32; 3], b: [f32; 3], t: f64) -> [f32; 3] {
	let t = t.clamp(0.0, 1.0) as f32;
	[0, 1, 2].map(|k| a[k] + (b[k] - a[k]) * t)
}

// Surface brushwork: dabs scattered on a grid of this many pixels.
const DAB_CELL: f64 = 22.0;

// Colour multiplier from the topmost dab covering a point, so flat colour
// reads as overlapping dabs of slightly different paint. A 2D take on
// modelkit's brushwork; `angle` is the way the strokes mostly run.
fn brushwork(x: f64, y: f64, scale: f64, angle: f64) -> [f32; 3] {
	let cell = DAB_CELL * scale;
	let (hx, hy) = ((x / cell).floor() as i64, (y / cell).floor() as i64);
	let (mut top, mut tint) = (-1.0f64, [1.0f32; 3]);
	for cx in hx - 2..=hx + 2 {
		for cy in hy - 2..=hy + 2 {
			let seed = (cx as u32).wrapping_mul(73_856_093) ^ (cy as u32).wrapping_mul(19_349_663);
			let r = |k: u32| hash(seed.wrapping_add(k.wrapping_mul(0x9e37_79b9)));
			let order = r(0);
			if order <= top {
				continue;
			}
			let (px, py) = ((cx as f64 + r(1)) * cell, (cy as f64 + r(2)) * cell);
			let a = angle + (r(3) - 0.5) * 0.5;
			let (ox, oy) = (x - px, y - py);
			let length = cell * 1.8 * (0.7 + 0.6 * r(4));
			let u = (ox * a.cos() + oy * a.sin()) / length + 0.5;
			if !(0.0..=1.0).contains(&u) {
				continue;
			}
			let half = cell * 0.45 * (0.7 + 0.6 * r(5)) * (std::f64::consts::PI * u).sin().sqrt();
			let s = (oy * a.cos() - ox * a.sin()) / half.max(1e-6);
			if s.abs() >= 1.0 {
				continue;
			}
			// Bristles thin out toward the stroke's tail.
			let bristle = ((s + 1.0) * 6.0).floor() as u32;
			let dry = 0.6 + 0.4 * hash(seed.wrapping_mul(31).wrapping_add(bristle));
			if u > dry {
				continue;
			}
			top = order;
			let streak = (hash(seed.wrapping_mul(17).wrapping_add(bristle)) - 0.5) * 0.08;
			let shift = 1.0 + (r(6) - 0.5) * 0.3 + streak;
			let warm = (r(7) - 0.5) * 0.12;
			let green = (r(8) - 0.5) * 0.06;
			tint = [shift * (1.0 + warm), shift * (1.0 + green), shift * (1.0 - warm)].map(|c| c as f32);
		}
	}
	tint
}

// The other brush types. Each returns a tint to multiply the paint by.
#[derive(Clone, Copy)]
pub enum Brush {
	// Leaf-shaped dabs that thin out toward the tail.
	Dab,
	// Long straight drags with streaky bristles, like a wide brush pulled across.
	Drag,
	// Drags with the paint running out: broken bristles, gaps show darker.
	Dry,
	// Short inked hatching lines, crossed where the noise runs dark.
	Hatch,
	// Stippled blotches from a sponge dabbed on.
	Sponge,
}

impl Brush {
	pub fn named(name: &str) -> Option<Brush> {
		Some(match name {
			"dab" => Brush::Dab,
			"drag" => Brush::Drag,
			"dry" => Brush::Dry,
			"hatch" => Brush::Hatch,
			"sponge" => Brush::Sponge,
			_ => return None,
		})
	}
}

fn shade(shift: f64, warm: f64) -> [f32; 3] {
	[shift * (1.0 + warm), shift, shift * (1.0 - warm)].map(|c| c as f32)
}

// Long strokes in lanes along `angle`; `dry` breaks the bristles up.
fn drag(x: f64, y: f64, scale: f64, angle: f64, dry: bool) -> [f32; 3] {
	let cell = DAB_CELL * scale;
	let (u, v) = (x * angle.cos() + y * angle.sin(), y * angle.cos() - x * angle.sin());
	let lane_width = cell * 0.6;
	let v = v + noise(u / (cell * 4.0), 7.0) * lane_width * 0.5;
	let lane = (v / lane_width).floor() as i64;
	let lane_seed = (lane as u32).wrapping_mul(2_654_435_761);
	let length = cell * 7.0;
	let u = u + hash(lane_seed) * length;
	let stroke = (u / length).floor() as i64;
	let seed = lane_seed ^ (stroke as u32).wrapping_mul(40_503);
	let along = u / length - stroke as f64;
	let bristle = ((v / lane_width - lane as f64) * 9.0).floor() as u32;
	let streak = (hash(seed.wrapping_add(bristle.wrapping_mul(977))) - 0.5) * 0.12;
	let shift = 1.0 + (hash(seed ^ 0x51) - 0.5) * 0.3 + streak;
	if dry {
		// Paint runs out along the stroke, unevenly per bristle.
		let reach = 0.35 + 0.6 * hash(seed.wrapping_mul(13).wrapping_add(bristle));
		if along > reach || noise(u * 0.4, v * 1.5) > 0.72 {
			return shade(0.78, 0.0);
		}
		return shade(shift + 0.06, (hash(seed ^ 0x77) - 0.5) * 0.1);
	}
	shade(shift, (hash(seed ^ 0x77) - 0.5) * 0.1)
}

fn hatch(x: f64, y: f64, scale: f64, angle: f64) -> [f32; 3] {
	let spacing = 5.0 * scale;
	let line = |a: f64, k: f64| {
		let (u, v) = (x * a.cos() + y * a.sin(), y * a.cos() - x * a.sin());
		let v = v + noise(u * 0.05 + k, k) * 2.0;
		let row = (v / spacing).floor();
		let seed = (row as i64 as u32).wrapping_mul(2_246_822_519) ^ (k as u32);
		// Each line is broken into short strokes.
		let dash = spacing * 6.0;
		let u = u + hash(seed) * dash;
		let gap = (u / dash).rem_euclid(1.0) > 0.8;
		let width = 0.35 + 0.15 * hash(seed ^ 9);
		!gap && ((v / spacing).rem_euclid(1.0) - 0.5).abs() < width * 0.5
	};
	let dark = noise(x * 0.02, y * 0.02);
	let mut tint = 1.03;
	if line(angle, 1.0) {
		tint = 0.8;
	}
	if dark > 0.55 && line(angle + 1.3, 2.0) {
		tint = 0.74;
	}
	shade(tint, 0.0)
}

fn sponge(x: f64, y: f64, scale: f64) -> [f32; 3] {
	let cell = 4.0 * scale;
	let (hx, hy) = ((x / cell).floor() as i64, (y / cell).floor() as i64);
	let mut tint = 1.0;
	for cx in hx - 1..=hx + 1 {
		for cy in hy - 1..=hy + 1 {
			let seed = (cx as u32).wrapping_mul(73_856_093) ^ (cy as u32).wrapping_mul(19_349_663);
			let (px, py) = ((cx as f64 + hash(seed)) * cell, (cy as f64 + hash(seed ^ 1)) * cell);
			let r = cell * (0.3 + 0.5 * hash(seed ^ 2));
			// Pores cluster where the sponge pressed hard.
			let pressed = noise(px * 0.03, py * 0.03);
			if hash(seed ^ 3) > pressed + 0.15 {
				continue;
			}
			if (x - px).hypot(y - py) < r {
				tint = if hash(seed ^ 4) > 0.5 { 1.15 } else { 0.85 };
			}
		}
	}
	shade(tint, 0.0)
}

// Paint coverage of streaky strokes laid along an edge: `along` runs with
// the edge and `depth` measures in from it, both in pixels.
fn edge_strokes(along: f64, depth: f64, width: f64) -> f64 {
	let lane = (depth / width * 3.0).floor();
	let streak = 0.55 + 0.45 * noise(along * 0.05 + lane * 7.3, lane * 3.1);
	let breakup = (noise(along * 0.02 + 11.0, depth * 0.15) * 2.5 + 0.9).clamp(0.0, 1.0);
	let fade = (1.0 - depth / width).clamp(0.0, 1.0);
	streak * breakup * fade.sqrt()
}

impl Canvas {
	pub fn new(width: usize, height: usize, color: Color) -> Self {
		Canvas { width, height, pixels: vec![color; width * height] }
	}

	// Pixels the outline may touch, with room for its wobble and `margin`.
	fn area(&self, outline: &Outline, margin: f64) -> impl Iterator<Item = (usize, usize)> {
		let (x0, y0, x1, y1) = outline.shape.bounds();
		let pad = outline.wobble * 1.5 + outline.grow + margin + 2.0;
		let clampx = |v: f64| (v.max(0.0) as usize).min(self.width);
		let clampy = |v: f64| (v.max(0.0) as usize).min(self.height);
		let (ax, bx, ay, by) = (clampx(x0 - pad), clampx(x1 + pad + 1.0), clampy(y0 - pad), clampy(y1 + pad + 1.0));
		(ay..by).flat_map(move |y| (ax..bx).map(move |x| (x, y)))
	}

	// Lays `color` over a pixel with `alpha` coverage.
	fn blend(&mut self, x: usize, y: usize, color: [f32; 3], alpha: f64) {
		let alpha = alpha.clamp(0.0, 1.0) as f32;
		if alpha <= 0.0 {
			return;
		}
		let p = &mut self.pixels[y * self.width + x];
		let out = alpha + p[3] * (1.0 - alpha);
		for k in 0..3 {
			p[k] = (color[k] * alpha + p[k] * p[3] * (1.0 - alpha)) / out.max(1e-6);
		}
		p[3] = out;
	}

	// Changes the colour already painted, inside the outline only.
	fn retint(&mut self, outline: &Outline, margin: f64, mut paint: impl FnMut(f64, f64, f64, [f32; 3]) -> Option<([f32; 3], f64)>) {
		for (x, y) in self.area(outline, margin).collect::<Vec<_>>() {
			let (px, py) = (x as f64 + 0.5, y as f64 + 0.5);
			let d = outline.distance(px, py);
			let cover = (0.5 - d).clamp(0.0, 1.0);
			if cover <= 0.0 || self.pixels[y * self.width + x][3] <= 0.0 {
				continue;
			}
			let p = self.pixels[y * self.width + x];
			if let Some((color, alpha)) = paint(px, py, d, [p[0], p[1], p[2]]) {
				let p = &mut self.pixels[y * self.width + x];
				let t = (alpha * cover).clamp(0.0, 1.0) as f32;
				for k in 0..3 {
					p[k] += (color[k] - p[k]) * t;
				}
			}
		}
	}

	pub fn fill(&mut self, outline: &Outline, color: [f32; 3], alpha: f64) {
		for (x, y) in self.area(outline, 0.0).collect::<Vec<_>>() {
			let d = outline.distance(x as f64 + 0.5, y as f64 + 0.5);
			self.blend(x, y, color, (0.5 - d).clamp(0.0, 1.0) * alpha);
		}
	}

	// A soft shadow cast by the outline, offset by (dx, dy).
	pub fn shadow(&mut self, outline: &Outline, dx: f64, dy: f64, blur: f64, alpha: f64) {
		let moved = Outline { shape: offset(&outline.shape, dx, dy), wobble: outline.wobble, seed: outline.seed, grow: outline.grow };
		for (x, y) in self.area(&moved, blur).collect::<Vec<_>>() {
			let d = moved.distance(x as f64 + 0.5, y as f64 + 0.5);
			let t = (0.5 - d / blur.max(1.0)).clamp(0.0, 1.0);
			self.blend(x, y, [0.04, 0.03, 0.03], t * t * alpha);
		}
	}

	pub fn brushwork(&mut self, outline: &Outline, strength: f64, scale: f64, angle: f64, brush: Brush) {
		self.retint(outline, 0.0, |x, y, _, c| {
			let tint = match brush {
				Brush::Dab => brushwork(x, y, scale, angle),
				Brush::Drag => drag(x, y, scale, angle, false),
				Brush::Dry => drag(x, y, scale, angle, true),
				Brush::Hatch => hatch(x, y, scale, angle),
				Brush::Sponge => sponge(x, y, scale),
			};
			let lit = [0, 1, 2].map(|k| c[k] * (1.0 + (tint[k] - 1.0) * strength as f32));
			Some((lit, 1.0))
		});
	}

	// Hand-painted vertical gradient: shades the paint from `top` at the top
	// edge to `bottom` at the bottom (1 keeps it), laid down in `bands`
	// overlapping horizontal strokes with ragged edges, the way a painter
	// blends by hand instead of an airbrushed ramp.
	pub fn gradient(&mut self, outline: &Outline, top: f64, bottom: f64, bands: f64) {
		let rows: Vec<usize> = self.area(outline, 0.0).map(|(_, y)| y).collect();
		let Some((&y0, &y1)) = rows.iter().min().zip(rows.iter().max()) else {
			return;
		};
		let span = (y1 - y0).max(1) as f64;
		self.retint(outline, 0.0, |x, y, _, c| {
			// Stroke lanes push the band edges up and down so no line is straight.
			let ragged = (drag(x, y, 1.4, 0.0, true)[0] as f64 - 1.0) * 1.6 + noise(x / 18.0, y / 6.0) * 0.35;
			let t = ((y - y0 as f64) / span + ragged / bands).clamp(0.0, 1.0) * bands;
			let blend = t.floor() + smoothstep(0.3, 0.7, t.fract());
			let shade = (top + (bottom - top) * blend / bands) as f32;
			Some((c.map(|k| k * shade), 1.0))
		});
	}

	// Hand-painted bevel: light strokes along edges facing the light (up-left),
	// dark ones along edges turned away, `width` pixels deep.
	pub fn bevel(&mut self, outline: &Outline, width: f64, light: [f32; 3], dark: [f32; 3], strength: f64) {
		let (lx, ly) = (-0.6f64, -0.8f64);
		self.retint(outline, 0.0, |x, y, d, _| {
			let depth = -d;
			if depth > width {
				return None;
			}
			let (nx, ny) = outline.outward(x, y);
			let facing = nx * lx + ny * ly;
			// Along the edge: the tangent's projection, so strokes follow it.
			let along = x * -ny + y * nx;
			let paint = edge_strokes(along, depth, width) * facing.abs().powf(0.6) * strength;
			Some((if facing > 0.0 { light } else { dark }, paint))
		});
	}

	// Printed halftone shading: a grid of ink dots, `spacing` pixels apart and
	// turned by `angle`, that swell toward edges facing away from the light
	// (up-left) over `reach` pixels. `tone` adds an even base of dots.
	pub fn halftone(&mut self, outline: &Outline, color: [f32; 3], spacing: f64, angle: f64, reach: f64, tone: f64, lit: bool, strength: f64) {
		// Lit dots gather on edges facing the light instead of away from it.
		let (lx, ly) = if lit { (0.6f64, 0.8f64) } else { (-0.6f64, -0.8f64) };
		let (c, s) = (angle.cos(), angle.sin());
		self.retint(outline, 0.0, |x, y, d, _| {
			let (nx, ny) = outline.outward(x, y);
			let away = (-(nx * lx + ny * ly)).max(0.0);
			let falloff = (1.0 - -d / reach).clamp(0.0, 1.0);
			let shade = (tone + away * falloff.powf(1.5)).min(1.0);
			// Distance to the nearest grid dot centre, in grid cells.
			let (u, v) = ((x * c + y * s) / spacing, (y * c - x * s) / spacing);
			let (fu, fv) = (u.rem_euclid(1.0) - 0.5, v.rem_euclid(1.0) - 0.5);
			let dot = fu.hypot(fv) * spacing;
			// Dot area tracks shade, so radius grows with its square root.
			let radius = shade.sqrt() * spacing * 0.62;
			let ink = (radius - dot + 0.5).clamp(0.0, 1.0);
			(ink > 0.0).then_some((color, ink * strength))
		});
	}

	// A crisp highlight line `inset` pixels inside edges facing the light
	// (up-left), fading out as the edge turns away. Brightest at the top-left.
	pub fn highlight(&mut self, outline: &Outline, color: [f32; 3], inset: f64, width: f64) {
		let (lx, ly) = (-0.6f64, -0.8f64);
		self.retint(outline, 0.0, |x, y, d, _| {
			let depth = -d;
			let line = (width * 0.5 + 0.5 - (depth - inset).abs()).clamp(0.0, 1.0);
			if line <= 0.0 {
				return None;
			}
			let (nx, ny) = outline.outward(x, y);
			let facing = (nx * lx + ny * ly).max(0.0);
			// Broken here and there, like a worn painted edge.
			let worn = (noise(x * 0.12, y * 0.12) * 1.6).min(1.0);
			Some((color, line * facing.powf(0.8) * worn))
		});
	}

	// A dark painted rim just inside the outline, like an inked border.
	pub fn rim(&mut self, outline: &Outline, width: f64, color: [f32; 3]) {
		self.retint(outline, 0.0, |x, y, d, _| {
			let depth = -d;
			let jitter = width * (0.75 + 0.5 * noise(x * 0.07 + 3.0, y * 0.07));
			(depth < jitter).then_some((color, (jitter - depth).min(1.0)))
		});
	}

	// A crisp border of even width just inside the outline, with no hand
	// jitter, for kits that want clean shapes under painted colour.
	pub fn outline(&mut self, outline: &Outline, width: f64, color: [f32; 3]) {
		self.retint(outline, 0.0, |_, _, d, _| {
			let depth = -d;
			(depth < width).then_some((color, (width - depth).min(1.0)))
		});
	}

	// An even ink border just inside the edge of everything painted so far, so a
	// model of many parts gets one outer outline. Soft pixels (shadows) don't count.
	pub fn ink_edge(&mut self, width: f64, color: [f32; 3]) {
		let solid = |c: &Canvas, x: i64, y: i64| x >= 0 && y >= 0 && (x as usize) < c.width && (y as usize) < c.height && c.pixels[y as usize * c.width + x as usize][3] >= 0.9;
		let reach = width.ceil() as i64 + 1;
		let mut coverage = vec![0.0; self.width * self.height];
		for y in 0..self.height as i64 {
			for x in 0..self.width as i64 {
				if !solid(self, x, y) {
					continue;
				}
				let mut nearest = f64::MAX;
				for dy in -reach..=reach {
					for dx in -reach..=reach {
						if !solid(self, x + dx, y + dy) {
							nearest = nearest.min(((dx * dx + dy * dy) as f64).sqrt());
						}
					}
				}
				coverage[y as usize * self.width + x as usize] = (width + 0.5 - nearest).clamp(0.0, 1.0);
			}
		}
		for (i, t) in coverage.into_iter().enumerate() {
			let p = &mut self.pixels[i];
			for k in 0..3 {
				p[k] += (color[k] - p[k]) * t as f32;
			}
		}
	}

	// A light line `inset` in from the edge of everything painted so far,
	// brightest where the edge faces up-left toward the light, gone facing away.
	pub fn edge_highlight(&mut self, inset: f64, width: f64, strength: f64) {
		let solid = |c: &Canvas, x: i64, y: i64| x >= 0 && y >= 0 && (x as usize) < c.width && (y as usize) < c.height && c.pixels[y as usize * c.width + x as usize][3] >= 0.9;
		let reach = (inset + width).ceil() as i64 + 1;
		let mut light = vec![0.0; self.width * self.height];
		for y in 0..self.height as i64 {
			for x in 0..self.width as i64 {
				if !solid(self, x, y) {
					continue;
				}
				let (mut nearest, mut nx, mut ny) = (f64::MAX, 0.0, 0.0);
				for dy in -reach..=reach {
					for dx in -reach..=reach {
						let d = ((dx * dx + dy * dy) as f64).sqrt();
						if d < nearest && !solid(self, x + dx, y + dy) {
							(nearest, nx, ny) = (d, dx as f64, dy as f64);
						}
					}
				}
				if nearest == f64::MAX {
					continue;
				}
				// How much the edge faces the light, from straight up-left.
				let facing = ((-0.6 * nx - ny) / nearest + 0.2).clamp(0.0, 1.0);
				let band = (1.0 - ((nearest - inset - width / 2.0).abs() / (width / 2.0 + 0.5))).clamp(0.0, 1.0);
				light[y as usize * self.width + x as usize] = facing * band * strength;
			}
		}
		for (i, t) in light.into_iter().enumerate() {
			let p = &mut self.pixels[i];
			for k in 0..3 {
				p[k] += (1.0 - p[k]) * t as f32;
			}
		}
	}

	// Rust blooming in from the edges, flaking at its rim; `amount` from 0
	// (clean) to 1 (eaten through), as modelkit's weathered().
	pub fn rust(&mut self, outline: &Outline, amount: f64, reach: f64, seed: f64) {
		const RUST_DARK: [f32; 3] = [0.3, 0.2, 0.12];
		const RUST_ORANGE: [f32; 3] = [0.62, 0.36, 0.15];
		const RUST_FLAKE: [f32; 3] = [0.78, 0.52, 0.3];
		self.retint(outline, 0.0, |x, y, d, c| {
			let edge = (1.0 + d / reach).clamp(0.0, 1.0);
			let patch = noise(x * 0.035 + seed, y * 0.035) * 0.6 + noise(x * 0.12, y * 0.12 + seed) * 0.3 + edge * 0.9 - 0.5;
			let level = 0.75 - amount * 0.75;
			let color = if patch > level + 0.22 {
				let pit = if noise(x * 0.6, y * 0.6 + seed) > 0.3 { 0.7 } else { 1.0 };
				RUST_DARK.map(|k| k * pit)
			} else if patch > level + 0.08 {
				RUST_ORANGE
			} else if patch > level {
				RUST_FLAKE
			} else if patch > level - 0.12 && noise(x * 0.25 + seed, y * 0.03) > 0.35 {
				// Stains running down below a patch.
				mix(c, RUST_ORANGE, 0.45)
			} else {
				return None;
			};
			Some((color, 1.0))
		});
	}

	// Two-colour diagonal stripes, hazard tape style; edges between stripes
	// wander a little, as if masked by hand.
	pub fn stripes(&mut self, outline: &Outline, a: [f32; 3], b: [f32; 3], width: f64, angle: f64) {
		let (ca, sa) = (angle.cos(), angle.sin());
		self.retint(outline, 0.0, |x, y, _, _| {
			let u = (x * ca + y * sa) / width + noise(x * 0.05, y * 0.05) * 0.06;
			Some((if u.rem_euclid(2.0) < 1.0 { a } else { b }, 1.0))
		});
	}

	// Grime collecting toward the bottom and into the outline's edges.
	pub fn grime(&mut self, outline: &Outline, amount: f64) {
		let (_, y0, _, y1) = outline.shape.bounds();
		self.retint(outline, 0.0, |x, y, d, c| {
			let low = ((y - y0) / (y1 - y0).max(1.0)).powf(2.0) * 0.6;
			let edge = (1.0 + d / 12.0).clamp(0.0, 1.0) * 0.4;
			let blotch = 0.5 + 0.5 * noise(x * 0.05 + 40.0, y * 0.05);
			let k = 1.0 - ((low + edge) * blotch * amount).min(0.7);
			Some((c.map(|v| v * k as f32), 1.0))
		});
	}

	// Copies `source` scaled into the rectangle (x, y, w, h), bilinear.
	pub fn draw(&mut self, source: &Canvas, x: f64, y: f64, w: f64, h: f64) {
		self.draw_region(source, (0.0, 0.0, source.width as f64, source.height as f64), (x, y, w, h));
	}

	// Copies the `from` rectangle of `source` into the `to` rectangle.
	fn draw_region(&mut self, source: &Canvas, from: (f64, f64, f64, f64), to: (f64, f64, f64, f64)) {
		let (fx, fy, fw, fh) = from;
		let (tx, ty, tw, th) = to;
		if tw <= 0.0 || th <= 0.0 || fw <= 0.0 || fh <= 0.0 {
			return;
		}
		let (ax, ay) = (tx.max(0.0) as usize, ty.max(0.0) as usize);
		let (bx, by) = (((tx + tw).ceil().max(0.0) as usize).min(self.width), ((ty + th).ceil().max(0.0) as usize).min(self.height));
		for py in ay..by {
			for px in ax..bx {
				let u = fx + ((px as f64 + 0.5 - tx) / tw) * fw;
				let v = fy + ((py as f64 + 0.5 - ty) / th) * fh;
				if u < fx || v < fy || u > fx + fw || v > fy + fh {
					continue;
				}
				let p = source.sample(u.clamp(fx + 0.5, fx + fw - 0.5), v.clamp(fy + 0.5, fy + fh - 0.5));
				self.blend(px, py, [p[0], p[1], p[2]], p[3] as f64);
			}
		}
	}

	// Draws `source` stretched to (x, y, w, h) as a 9-slice, keeping the
	// corners `left`, `top`, `right`, `bottom` pixels deep at full size, as
	// Roblox's ScaleType.Slice does.
	pub fn draw_sliced(&mut self, source: &Canvas, slice: [f64; 4], x: f64, y: f64, w: f64, h: f64) {
		let [l, t, r, b] = slice;
		let (sw, sh) = (source.width as f64, source.height as f64);
		let columns = [(0.0, l, x, l), (l, sw - l - r, x + l, w - l - r), (sw - r, r, x + w - r, r)];
		let rows = [(0.0, t, y, t), (t, sh - t - b, y + t, h - t - b), (sh - b, b, y + h - b, b)];
		for &(sy, shh, dy, dh) in &rows {
			for &(sx, sww, dx, dw) in &columns {
				self.draw_region(source, (sx, sy, sww, shh), (dx, dy, dw, dh));
			}
		}
	}

	fn sample(&self, u: f64, v: f64) -> Color {
		let (x, y) = (u - 0.5, v - 0.5);
		let (x0, y0) = (x.floor().max(0.0) as usize, y.floor().max(0.0) as usize);
		let (x1, y1) = ((x0 + 1).min(self.width - 1), (y0 + 1).min(self.height - 1));
		let (fx, fy) = ((x - x0 as f64).clamp(0.0, 1.0) as f32, (y - y0 as f64).clamp(0.0, 1.0) as f32);
		let at = |x: usize, y: usize| self.pixels[y * self.width + x];
		let mut out = [0.0f32; 4];
		// Weight colour by alpha so transparent texels don't bleed black.
		let taps = [(at(x0, y0), (1.0 - fx) * (1.0 - fy)), (at(x1, y0), fx * (1.0 - fy)), (at(x0, y1), (1.0 - fx) * fy), (at(x1, y1), fx * fy)];
		for (p, w) in taps {
			for k in 0..3 {
				out[k] += p[k] * p[3] * w;
			}
			out[3] += p[3] * w;
		}
		if out[3] > 0.0 {
			for k in 0..3 {
				out[k] /= out[3];
			}
		}
		out
	}

	pub fn encode_png(&self) -> Vec<u8> {
		let mut data = Vec::with_capacity(self.width * self.height * 4);
		for p in &self.pixels {
			data.extend(p.map(|c| (c.clamp(0.0, 1.0) * 255.0 + 0.5) as u8));
		}
		let mut bytes = Vec::new();
		let mut encoder = png::Encoder::new(&mut bytes, self.width as u32, self.height as u32);
		encoder.set_color(png::ColorType::Rgba);
		encoder.set_depth(png::BitDepth::Eight);
		let mut writer = encoder.write_header().expect("png header");
		writer.write_image_data(&data).expect("png data");
		drop(writer);
		bytes
	}
}

fn offset(shape: &Shape, dx: f64, dy: f64) -> Shape {
	match shape {
		Shape::Rect { x0, y0, x1, y1, radius } => Shape::Rect { x0: x0 + dx, y0: y0 + dy, x1: x1 + dx, y1: y1 + dy, radius: *radius },
		Shape::Circle { x, y, radius } => Shape::Circle { x: x + dx, y: y + dy, radius: *radius },
		Shape::Polygon(points) => Shape::Polygon(points.iter().map(|&(x, y)| (x + dx, y + dy)).collect()),
	}
}

fn smoothstep(a: f64, b: f64, x: f64) -> f64 {
	let t = ((x - a) / (b - a)).clamp(0.0, 1.0);
	t * t * (3.0 - 2.0 * t)
}
