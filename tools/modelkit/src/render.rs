// Preview renderer: a small software rasterizer, so a screenshot needs no GPU,
// desktop or Blender. Orthographic 3/4 view like the old previews, the camera
// can orbit the model (turntables), and light is soft since the textures
// carry their own painted shading.

use crate::mesh::{cross, dot, normalize, scale, sub, Vec3};
use std::cell::RefCell;
use std::rc::Rc;

use crate::anim::Pose;
use crate::image::Image;
use crate::Part;

const BACKGROUND: [f32; 3] = [0.36, 0.38, 0.42];
const SUPERSAMPLE: usize = 2;
// How much of an emissive surface's glow spills around it in previews.
const BLOOM: f32 = 2.5;

#[derive(Default)]
pub struct View {
	pub size: usize,
	// Camera orbit around Z, in radians; 0 is the classic 3/4 view.
	pub spin: f64,
	// Close-up: frame a ball of this radius around this point instead of the
	// whole model. The camera is orthographic, so nothing is clipped; it sees
	// everything in frame as a player would from above.
	pub focus: Option<(Vec3, f64)>,
	// Perspective camera standing at an eye point and looking at a target,
	// for seeing the model from right beside it as a player would.
	pub eye: Option<(Vec3, Vec3)>,
	// Square-on orthographic view of one side, fitted tight to the model, so
	// lengths within it can be measured against each other.
	pub side: Option<Side>,
	// Each part in its own flat colour instead of its texture, so parts can be
	// told apart and named (see legend).
	pub parts: bool,
	// Stud lines this far apart over a side view, every fifth one stronger.
	pub grid: Option<f64>,
}

#[derive(Clone, Copy)]
pub enum Side {
	Front,
	Back,
	Left,
	Right,
	Top,
	Bottom,
}

impl Side {
	pub const ALL: [Side; 6] = [Side::Front, Side::Back, Side::Left, Side::Right, Side::Top, Side::Bottom];

	pub fn name(self) -> &'static str {
		match self {
			Side::Front => "front",
			Side::Back => "back",
			Side::Left => "left",
			Side::Right => "right",
			Side::Top => "top",
			Side::Bottom => "bottom",
		}
	}

	pub fn parse(name: &str) -> Option<Side> {
		Side::ALL.into_iter().find(|side| side.name() == name)
	}

	// The direction from the model toward the camera (the front faces -Y, as
	// the 3/4 preview shows it), and the world direction that is up on screen.
	fn axes(self) -> (Vec3, Vec3) {
		match self {
			Side::Front => ([0.0, -1.0, 0.0], [0.0, 0.0, 1.0]),
			Side::Back => ([0.0, 1.0, 0.0], [0.0, 0.0, 1.0]),
			Side::Left => ([-1.0, 0.0, 0.0], [0.0, 0.0, 1.0]),
			Side::Right => ([1.0, 0.0, 0.0], [0.0, 0.0, 1.0]),
			Side::Top => ([0.0, 0.0, 1.0], [0.0, 1.0, 0.0]),
			Side::Bottom => ([0.0, 0.0, -1.0], [0.0, 1.0, 0.0]),
		}
	}
}

// A rendered picture, and which part shows at each supersampled pixel
// (`NO_PART` where only background shows), for looking parts up by position.
pub struct Frame {
	pub pixels: Vec<u8>,
	pub owner: Vec<u32>,
	pub owner_size: usize,
}

pub const NO_PART: u32 = u32::MAX;

// Each distinct part name's flat colour, in order of first appearance, so a
// script that adds the same parts gets the same colours. Hues step by the
// golden ratio and alternate in saturation and value, so neighbours in the
// list stay far apart.
pub fn part_colours(parts: &[&Part]) -> Vec<(String, [f32; 3])> {
	let mut names: Vec<String> = Vec::new();
	for part in parts {
		if !names.contains(&part.name) {
			names.push(part.name.clone());
		}
	}
	names
		.into_iter()
		.enumerate()
		.map(|(i, name)| {
			let hue = (i as f32 * 0.618_034).fract();
			let saturation = if i % 2 == 0 { 0.75 } else { 0.45 };
			let value = if (i / 2) % 2 == 0 { 0.95 } else { 0.7 };
			(name, hsv(hue, saturation, value))
		})
		.collect()
}

fn hsv(hue: f32, saturation: f32, value: f32) -> [f32; 3] {
	let k = |n: f32| {
		let k = (n + hue * 6.0) % 6.0;
		value - value * saturation * k.min(4.0 - k).clamp(0.0, 1.0)
	};
	[k(5.0), k(3.0), k(1.0)]
}

// One line per part colour: `#rrggbb Name`.
pub fn legend(parts: &[&Part]) -> String {
	part_colours(parts)
		.iter()
		.map(|(name, c)| {
			let [r, g, b] = c.map(|v| (v * 255.0 + 0.5) as u8);
			format!("#{r:02x}{g:02x}{b:02x} {name}\n")
		})
		.collect()
}

// Splits the part of the frame the model covers (with a small margin) into a
// `count`×`count` grid, columns A, B, C... from the left and rows 1, 2, 3...
// from the top, and lists the parts showing in each cell with their share of
// it, largest first; slivers under 2% are left out. The first line gives the
// grid's bounds in picture pixels, `bounds: x0,y0,x1,y1`, for drawing it.
pub fn cells(frame: &Frame, parts: &[&Part], count: usize) -> String {
	let size = frame.owner_size;
	let (mut low, mut high) = ([size, size], [0, 0]);
	for y in 0..size {
		for x in 0..size {
			if frame.owner[y * size + x] != NO_PART {
				low = [low[0].min(x), low[1].min(y)];
				high = [high[0].max(x + 1), high[1].max(y + 1)];
			}
		}
	}
	if low[0] >= high[0] {
		return String::new();
	}
	let margin = (high[0] - low[0]).max(high[1] - low[1]) / 20;
	let (x_start, y_start) = (low[0].saturating_sub(margin), low[1].saturating_sub(margin));
	let (x_end, y_end) = ((high[0] + margin).min(size), (high[1] + margin).min(size));
	let mut out = format!(
		"bounds: {},{},{},{}\n",
		x_start / SUPERSAMPLE,
		y_start / SUPERSAMPLE,
		x_end / SUPERSAMPLE,
		y_end / SUPERSAMPLE
	);
	let split = |start: usize, end: usize, i: usize| start + (end - start) * i / count;
	for row in 0..count {
		for column in 0..count {
			let (x0, x1) = (split(x_start, x_end, column), split(x_start, x_end, column + 1));
			let (y0, y1) = (split(y_start, y_end, row), split(y_start, y_end, row + 1));
			let mut shares: Vec<(String, usize)> = Vec::new();
			for y in y0..y1 {
				for x in x0..x1 {
					let owner = frame.owner[y * size + x];
					if owner == NO_PART {
						continue;
					}
					let name = &parts[owner as usize].name;
					match shares.iter_mut().find(|(n, _)| n == name) {
						Some((_, pixels)) => *pixels += 1,
						None => shares.push((name.clone(), 1)),
					}
				}
			}
			shares.sort_by(|a, b| b.1.cmp(&a.1));
			let area = ((x1 - x0) * (y1 - y0)).max(1) as f64;
			let listed: Vec<String> = shares
				.iter()
				.filter(|(_, pixels)| *pixels as f64 / area >= 0.02)
				.map(|(name, pixels)| format!("{name} {:.0}%", *pixels as f64 / area * 100.0))
				.collect();
			let label = format!("{}{}", (b'A' + column as u8) as char, row + 1);
			out.push_str(&format!("{label}: {}\n", if listed.is_empty() { "-".to_string() } else { listed.join(", ") }));
		}
	}
	out
}

// Horizontal field of view of the perspective camera, in degrees.
const EYE_FOV: f64 = 70.0;
// Texels per stud the eye camera can tell apart at this distance, for a
// picture `size` pixels across; denser texels only blur together.
pub fn texels_resolved(distance: f64, size: usize) -> f64 {
	let spread = (EYE_FOV.to_radians() / 2.0).tan() * 2.0;
	size as f64 / (spread * distance)
}

// Whether any of a ball at `centre` with `radius` falls inside the eye
// camera's square frame, looking from `eye` toward `target`.
pub fn in_view(eye: Vec3, target: Vec3, centre: Vec3, radius: f64) -> bool {
	let offset = sub(centre, eye);
	let distance = dot(offset, offset).sqrt();
	if distance <= radius {
		return true;
	}
	// The frame's corners lie furthest off axis, so the cone through them
	// holds the whole frame.
	let corner = ((EYE_FOV.to_radians() / 2.0).tan() * 2f64.sqrt()).atan();
	let off_axis = dot(scale(offset, 1.0 / distance), normalize(sub(target, eye))).clamp(-1.0, 1.0).acos();
	off_axis - (radius / distance).asin() <= corner
}

// Steepest viewing angle the mip choice accounts for; grazing surfaces past it
// blur no further.
const MIP_MIN_FACING: f64 = 0.02;

// Mip chain: each level halves the one before by averaging 2×2 texels, so a
// far surface shows its texture's average instead of whichever texel lands
// under the pixel, and fine detail stops breaking into noise.
struct Mips(Vec<Image>);

impl Mips {
	fn new(image: &Image) -> Self {
		let mut levels = vec![image.half()];
		while levels.last().is_some_and(|l| l.width > 1 || l.height > 1) {
			let next = levels.last().unwrap().half();
			levels.push(next);
		}
		Mips(levels)
	}

	// Level 0 is the full texture; between levels the two nearest blend.
	fn sample(&self, full: &Image, u: f64, v: f64, level: f64) -> [f32; 3] {
		let at = |l: usize| if l == 0 { full.sample(u, v) } else { self.0[(l - 1).min(self.0.len() - 1)].sample(u, v) };
		let level = level.clamp(0.0, self.0.len() as f64);
		let low = level.floor() as usize;
		let t = (level - low as f64) as f32;
		let near = at(low);
		if t == 0.0 {
			return near;
		}
		let far = at(low + 1);
		[0, 1, 2].map(|a| near[a] + (far[a] - near[a]) * t)
	}

	// Opacity, blended between levels the same way.
	fn sample_alpha(&self, full: &Image, u: f64, v: f64, level: f64) -> f32 {
		let at = |l: usize| if l == 0 { full.sample_alpha(u, v) } else { self.0[(l - 1).min(self.0.len() - 1)].sample_alpha(u, v) };
		let level = level.clamp(0.0, self.0.len() as f64);
		let low = level.floor() as usize;
		let t = (level - low as f64) as f32;
		let near = at(low);
		if t == 0.0 {
			return near;
		}
		near + (at(low + 1) - near) * t
	}
}
// Corners closer than this to the eye are culled with their triangle.
const NEAR: f64 = 0.05;

pub fn render(parts: &[&Part], view: &View) -> Vec<u8> {
	draw(parts, &[], view).pixels
}

// Renders with each part moved by its bone's skinning transform from `skin`.
pub fn render_posed(parts: &[&Part], skin: &[Pose], view: &View) -> Vec<u8> {
	draw(parts, skin, view).pixels
}

// Renders and keeps which part shows at each pixel.
pub fn render_frame(parts: &[&Part], view: &View) -> Frame {
	draw(parts, &[], view)
}

fn draw(parts: &[&Part], skin: &[Pose], view: &View) -> Frame {
	let triangles: Vec<_> = parts
		.iter()
		.enumerate()
		.map(|(index, part)| {
			let mut list = part.mesh.borrow().triangles();
			if let Some(pose) = part.bone.and_then(|b| skin.get(b)) {
				for corner in list.iter_mut().flatten() {
					corner.position = pose.apply(corner.position);
					corner.normal = pose.turn(corner.normal);
				}
			}
			(list, index as u32, part)
		})
		.collect();

	let mut low = [f64::MAX; 3];
	let mut high = [f64::MIN; 3];
	for (list, _, _) in &triangles {
		for corner in list.iter().flatten() {
			for axis in 0..3 {
				low[axis] = low[axis].min(corner.position[axis]);
				high[axis] = high[axis].max(corner.position[axis]);
			}
		}
	}
	let (center, extent) = match view.focus {
		Some((point, radius)) => (point, radius * 2.0),
		None => (
			scale([low[0] + high[0], low[1] + high[1], low[2] + high[2]], 0.5),
			(0..3).map(|a| high[a] - low[a]).fold(0.0, f64::max).max(1e-6),
		),
	};

	let (sin, cos) = view.spin.sin_cos();
	let (toward, screen_up) = match (view.side, view.eye) {
		(Some(side), _) => side.axes(),
		(None, Some((eye, target))) => (sub(eye, target), [0.0, 0.0, 1.0]),
		(None, None) => ([cos + sin, sin - cos, 0.8], [0.0, 0.0, 1.0]),
	};
	let forward = normalize(scale(toward, -1.0));
	let right = normalize(cross(forward, screen_up));
	let up = cross(right, forward);
	// `toward` is a length when an eye is given and roughly unit otherwise, so
	// it is normalized before it tilts the light: an unnormalized one swings
	// the light toward horizontal at eye distance and flat tops go dark.
	let tilt = normalize(toward);
	let light = normalize([tilt[0] * 0.3 - right[0], tilt[1] * 0.3 - right[1], 1.5]);
	// A side view fits the model's box tightly, with a small margin.
	let span = |axis: Vec3| (0..3).map(|a| (high[a] - low[a]) * axis[a].abs()).sum::<f64>();
	let width = match view.side {
		Some(_) => span(right).max(span(up)).max(1e-6) * 1.1,
		None => extent * 2.2 / 1.4,
	};
	let colours = if view.parts { part_colours(parts) } else { Vec::new() };

	let size = view.size * SUPERSAMPLE;
	let mut color = vec![BACKGROUND; size * size];
	let mut depth = vec![f64::MAX; size * size];
	let mut glow = vec![[0.0f32; 3]; size * size];
	let mut owner = vec![NO_PART; size * size];
	let spread = (EYE_FOV.to_radians() / 2.0).tan() * 2.0;
	let to_screen = |p: Vec3| -> [f64; 3] {
		if let Some((eye, _)) = view.eye {
			let d = sub(p, eye);
			let ahead = dot(d, forward);
			return [
				(dot(d, right) / (ahead * spread) + 0.5) * size as f64,
				(0.5 - dot(d, up) / (ahead * spread)) * size as f64,
				ahead,
			];
		}
		let d = sub(p, center);
		[
			(dot(d, right) / width + 0.5) * size as f64,
			(0.5 - dot(d, up) / width) * size as f64,
			dot(d, forward),
		]
	};

	// Parts can share an image, so each chain is built once.
	let mut chains: Vec<(*const RefCell<Image>, Mips)> = Vec::new();
	for (_, _, part) in &triangles {
		let key = Rc::as_ptr(&part.image);
		if !chains.iter().any(|(k, _)| *k == key) {
			chains.push((key, Mips::new(&part.image.borrow())));
		}
	}
	// Studs one screen pixel spans, before foreshortening; the eye camera
	// multiplies it by the distance ahead.
	let pixel_studs = if view.eye.is_some() { spread / size as f64 } else { width / size as f64 };

	// Solid parts first; see-through parts then blend over them, tested
	// against the depth but not writing it.
	let layered = [false, true].map(|see_through| triangles.iter().filter(move |(_, _, part)| part.image.borrow().alpha.is_some() == see_through));
	for (list, index, part) in layered.into_iter().flatten() {
		let image = part.image.borrow();
		let see_through = image.alpha.is_some();
		let flat = colours.iter().find(|(name, _)| *name == part.name).map(|(_, c)| *c);
		let key = Rc::as_ptr(&part.image);
		let mips = &chains.iter().find(|(k, _)| *k == key).unwrap().1;
		for triangle in list {
			let s = triangle.map(|corner| to_screen(corner.position));
			if view.eye.is_some() && s.iter().any(|p| p[2] < NEAR) {
				continue;
			}
			// Texels per stud on this triangle, and how squarely it faces us.
			let edge = |k: usize| sub(triangle[k].position, triangle[0].position);
			let face = cross(edge(1), edge(2));
			let world_area = dot(face, face).sqrt();
			let uv_edge = |k: usize, a: usize| (triangle[k].uv[a] - triangle[0].uv[a]) * if a == 0 { image.width } else { image.height } as f64;
			let texel_area = (uv_edge(1, 0) * uv_edge(2, 1) - uv_edge(2, 0) * uv_edge(1, 1)).abs();
			let density = if world_area > 1e-12 { (texel_area / world_area).sqrt() } else { 0.0 };
			let facing = if world_area > 1e-12 { (dot(face, forward).abs() / world_area).max(MIP_MIN_FACING) } else { 1.0 };
			// A tilted surface stretches the footprint along one axis only, so
			// the root of the facing splits the difference between the axes.
			let texels_per_pixel = density * pixel_studs / facing.sqrt();
			let area = (s[1][0] - s[0][0]) * (s[2][1] - s[0][1]) - (s[2][0] - s[0][0]) * (s[1][1] - s[0][1]);
			if area.abs() < 1e-12 {
				continue;
			}
			let x0 = s.iter().map(|p| p[0]).fold(f64::MAX, f64::min).floor().max(0.0) as usize;
			let x1 = (s.iter().map(|p| p[0]).fold(f64::MIN, f64::max).ceil() as usize).min(size);
			let y0 = s.iter().map(|p| p[1]).fold(f64::MAX, f64::min).floor().max(0.0) as usize;
			let y1 = (s.iter().map(|p| p[1]).fold(f64::MIN, f64::max).ceil() as usize).min(size);
			for y in y0..y1 {
				for x in x0..x1 {
					let px = x as f64 + 0.5;
					let py = y as f64 + 0.5;
					let w0 = ((s[1][0] - px) * (s[2][1] - py) - (s[2][0] - px) * (s[1][1] - py)) / area;
					let w1 = ((s[2][0] - px) * (s[0][1] - py) - (s[0][0] - px) * (s[2][1] - py)) / area;
					let w2 = 1.0 - w0 - w1;
					if w0 < 0.0 || w1 < 0.0 || w2 < 0.0 {
						continue;
					}
					// Perspective: weights interpolate linearly in 1/depth.
					let (w0, w1, w2, z) = if view.eye.is_some() {
						let p = [w0 / s[0][2], w1 / s[1][2], w2 / s[2][2]];
						let sum = p[0] + p[1] + p[2];
						(p[0] / sum, p[1] / sum, p[2] / sum, 1.0 / sum)
					} else {
						(w0, w1, w2, w0 * s[0][2] + w1 * s[1][2] + w2 * s[2][2])
					};
					let at = y * size + x;
					if z >= depth[at] {
						continue;
					}
					if !see_through {
						depth[at] = z;
						owner[at] = *index;
					}
					let blend = |f: &dyn Fn(usize) -> f64| w0 * f(0) + w1 * f(1) + w2 * f(2);
					let u = blend(&|k| triangle[k].uv[0]);
					let v = blend(&|k| triangle[k].uv[1]);
					let mut normal = normalize([0, 1, 2].map(|a| blend(&|k| triangle[k].normal[a])));
					// Back faces seen through holes still light as if facing us.
					if dot(normal, forward) > 0.0 {
						normal = scale(normal, -1.0);
					}
					let shade = (0.72 + 0.38 * dot(normal, light).max(0.0)) as f32;
					// Flat part colours carry no painted shading, so the light
					// does more of the work of showing the form.
					if let Some(tone) = flat {
						let shade = (0.45 + 0.6 * dot(normal, light).max(0.0)) as f32;
						let opacity = if see_through { 0.4 } else { 1.0 };
						let under = color[at];
						color[at] = [0, 1, 2].map(|a| under[a] + (tone[a] * shade - under[a]) * opacity);
						continue;
					}
					// Emission adds to the lighting before the albedo, as
					// SurfaceAppearance does, and spills into a bloom.
					let footprint = if view.eye.is_some() { texels_per_pixel * z } else { texels_per_pixel };
					let albedo = mips.sample(&image, u, v, footprint.max(1.0).log2());
					if see_through {
						let opacity = mips.sample_alpha(&image, u, v, footprint.max(1.0).log2());
						let under = color[at];
						color[at] = [0, 1, 2].map(|a| under[a] + (albedo[a] * shade - under[a]) * opacity);
						continue;
					}
					color[at] = albedo.map(|c| c * (shade + part.emissive));
					glow[at] = albedo.map(|c| c * part.emissive);
				}
			}
		}
	}

	if let (Some(_), Some(step)) = (view.side, view.grid) {
		draw_grid(&mut color, size, width, [dot(center, right), dot(center, up)], step);
	}

	let bloom = blur(&glow, size, size / 150);

	let mut data = Vec::with_capacity(view.size * view.size * 3);
	for y in 0..view.size {
		for x in 0..view.size {
			let mut sum = [0.0f32; 3];
			for dy in 0..SUPERSAMPLE {
				for dx in 0..SUPERSAMPLE {
					let at = (y * SUPERSAMPLE + dy) * size + x * SUPERSAMPLE + dx;
					for a in 0..3 {
						sum[a] += color[at][a] + bloom[at][a] * BLOOM;
					}
				}
			}
			let samples = (SUPERSAMPLE * SUPERSAMPLE) as f32;
			data.extend(sum.map(|c| ((c / samples).clamp(0.0, 1.0) * 255.0 + 0.5) as u8));
		}
	}
	fxaa(&mut data, view.size, view.size);
	Frame { pixels: data, owner, owner_size: size }
}

// Light lines every `step` studs across and up a side view, every fifth one
// stronger, so sizes can be read off in studs. `offset` is the view centre's
// position along the screen's right and up directions. Too fine a step to see
// keeps only the strong lines.
fn draw_grid(color: &mut [[f32; 3]], size: usize, width: f64, offset: [f64; 2], step: f64) {
	let pixels_per_step = step / width * size as f64;
	let at = |pixel: usize, axis: usize| {
		let studs = ((pixel as f64 + 0.5) / size as f64 - 0.5) * width;
		offset[axis] + if axis == 0 { studs } else { -studs }
	};
	// The line index a pixel falls in and whether a line runs along its edge.
	let line = |pixel: usize, axis: usize| -> Option<bool> {
		if pixel + 1 >= size {
			return None;
		}
		let (a, b) = ((at(pixel, axis) / step).floor(), (at(pixel + 1, axis) / step).floor());
		if a == b {
			return None;
		}
		let index = a.max(b) as i64;
		Some(index % 5 == 0)
	};
	let columns: Vec<Option<bool>> = (0..size).map(|x| line(x, 0).or(if x > 0 { line(x - 1, 0) } else { None })).collect();
	let rows: Vec<Option<bool>> = (0..size).map(|y| line(y, 1).or(if y > 0 { line(y - 1, 1) } else { None })).collect();
	for y in 0..size {
		for x in 0..size {
			let strong = match (columns[x], rows[y]) {
				(None, None) => continue,
				(c, r) => c.unwrap_or(false) || r.unwrap_or(false),
			};
			if !strong && pixels_per_step < 6.0 {
				continue;
			}
			let alpha = if strong { 0.55 } else { 0.25 };
			let pixel = &mut color[y * size + x];
			*pixel = pixel.map(|c| c + (1.0 - c) * alpha);
		}
	}
}

// Fast approximate anti-aliasing: where the picture changes sharply, each
// pixel blends toward its neighbours across the edge, so stair-steps soften.
const FXAA_EDGE_MIN: f32 = 0.0312;
const FXAA_EDGE_RELATIVE: f32 = 0.125;

fn fxaa(data: &mut [u8], width: usize, height: usize) {
	let source = data.to_vec();
	let luma: Vec<f32> = source.chunks(3).map(|c| (0.299 * c[0] as f32 + 0.587 * c[1] as f32 + 0.114 * c[2] as f32) / 255.0).collect();
	let at = |x: usize, y: usize| y * width + x;
	for y in 1..height - 1 {
		for x in 1..width - 1 {
			let l = luma[at(x, y)];
			let (n, s, w, e) = (luma[at(x, y - 1)], luma[at(x, y + 1)], luma[at(x - 1, y)], luma[at(x + 1, y)]);
			let corners = [luma[at(x - 1, y - 1)], luma[at(x + 1, y - 1)], luma[at(x - 1, y + 1)], luma[at(x + 1, y + 1)]];
			let (mut low, mut high, mut sum) = (l.min(n).min(s).min(w).min(e), l.max(n).max(s).max(w).max(e), l + n + s + w + e);
			for &c in &corners {
				low = low.min(c);
				high = high.max(c);
				sum += c;
			}
			let range = high - low;
			if range < FXAA_EDGE_MIN.max(high * FXAA_EDGE_RELATIVE) {
				continue;
			}
			// A horizontal edge changes from one row to the next, so blend up and down.
			let horizontal = (n + s - 2.0 * l).abs() >= (w + e - 2.0 * l).abs();
			let (a, b) = if horizontal { (at(x, y - 1), at(x, y + 1)) } else { (at(x - 1, y), at(x + 1, y)) };
			let weight = ((sum / 9.0 - l).abs() / range).clamp(0.0, 1.0).powi(2) * 0.5;
			let p = at(x, y) * 3;
			for k in 0..3 {
				let blended = source[a * 3 + k] as f32 * 0.5 + source[b * 3 + k] as f32 * 0.5;
				data[p + k] = (source[p + k] as f32 * (1.0 - weight) + blended * weight + 0.5) as u8;
			}
		}
	}
}

// Box blur run three times each way, which is close to a gaussian.
fn blur(pixels: &[[f32; 3]], size: usize, radius: usize) -> Vec<[f32; 3]> {
	let mut out = pixels.to_vec();
	if radius == 0 || out.iter().all(|p| *p == [0.0; 3]) {
		return out;
	}
	let mut line = vec![[0.0f32; 3]; size];
	for _ in 0..3 {
		for (step, stride) in [(1, size), (size, 1)] {
			for row in 0..size {
				let at = |i: usize| row * stride + i * step;
				let mut sum = [0.0f32; 3];
				for i in 0..=radius.min(size - 1) {
					for a in 0..3 {
						sum[a] += out[at(i)][a];
					}
				}
				for i in 0..size {
					line[i] = sum.map(|c| c / (2 * radius + 1) as f32);
					if i + radius + 1 < size {
						for a in 0..3 {
							sum[a] += out[at(i + radius + 1)][a];
						}
					}
					if i >= radius {
						for a in 0..3 {
							sum[a] -= out[at(i - radius)][a];
						}
					}
				}
				for i in 0..size {
					out[at(i)] = line[i];
				}
			}
		}
	}
	out
}
