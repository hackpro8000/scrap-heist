// Preview renderer: a small software rasterizer, so a screenshot needs no GPU,
// desktop or Blender. Orthographic 3/4 view like the old previews, the camera
// can orbit the model (turntables), and light is soft since the textures
// carry their own painted shading.

use crate::mesh::{add, cross, dot, normalize, scale, sub, Corner, Mesh, Vec3};
use std::cell::{Ref, RefCell};
use std::rc::Rc;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::collections::HashMap;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Instant;

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
	// Skip triangles facing away from the camera, as Roblox does; off draws
	// both sides, as the reference renderer always has.
	pub cull_back: bool,
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

// Draws with the fast renderer. With MODELKIT_RENDER_CHECK=1 the reference
// renderer draws the same view too, and the largest channel difference
// between the two pictures and both times go to stderr.
fn draw(parts: &[&Part], skin: &[Pose], view: &View) -> Frame {
	let check = std::env::var("MODELKIT_RENDER_CHECK").is_ok_and(|value| value == "1");
	if !check {
		return draw_fast(parts, skin, view).0;
	}
	let start = Instant::now();
	let (frame, stages) = draw_fast(parts, skin, view);
	let new = start.elapsed().as_secs_f64();
	let start = Instant::now();
	let reference = draw_reference(parts, skin, view);
	let old = start.elapsed().as_secs_f64();
	let max = if frame.pixels.len() != reference.pixels.len() {
		255
	} else {
		frame.pixels.iter().zip(&reference.pixels).map(|(a, b)| a.abs_diff(*b)).max().unwrap_or(0)
	};
	let owners = frame.owner.iter().zip(&reference.owner).filter(|(a, b)| a != b).count() + frame.owner.len().abs_diff(reference.owner.len());
	eprintln!(
		"RENDER_CHECK size={} max={max} reference={old:.3} new={new:.3} owner_mismatch={owners} {}",
		view.size,
		stages.line()
	);
	frame
}

// Seconds each stage of the fast renderer took, for the check line.
#[derive(Default)]
struct Stages {
	// Part boxes, culling and triangle gathering.
	setup: f64,
	// Mip chains (only the ones missing from the cache are built).
	mips: f64,
	// Projecting triangles to the screen.
	prepare: f64,
	bin: f64,
	// The visibility pass, or the whole forward pass for part colours.
	raster: f64,
	shade: f64,
	// See-through parts blending over.
	glass: f64,
	bloom: f64,
	// Grid, downsample and fxaa.
	finish: f64,
}

impl Stages {
	fn line(&self) -> String {
		format!(
			"setup={:.3} mips={:.3} prepare={:.3} bin={:.3} raster={:.3} shade={:.3} glass={:.3} bloom={:.3} finish={:.3}",
			self.setup, self.mips, self.prepare, self.bin, self.raster, self.shade, self.glass, self.bloom, self.finish
		)
	}
}

// Seconds since `start`, restarting it.
fn lap(start: &mut Instant) -> f64 {
	let seconds = start.elapsed().as_secs_f64();
	*start = Instant::now();
	seconds
}

// Supersampled rows per band: the screen is cut into bands this tall, and
// each core takes the next undrawn band until none are left.
const BAND_ROWS: usize = 16;
// Marks a sample no solid triangle covers in the visibility buffer.
const NO_TRIANGLE: u32 = u32::MAX;
// Triangles per setup job.
const SETUP_CHUNK: usize = 4096;
// Below this many samples a row-parallel stage runs on the calling thread,
// since starting threads would cost more than the work.
const INLINE_SAMPLES: usize = 64 * 1024;

fn threads() -> usize {
	std::thread::available_parallelism().map_or(4, |n| n.get())
}

// Splits `data`, `rows` rows of `row_len` items, into one run of whole rows
// per core and calls `work(first_row, run)` on each; small data stays on
// this thread.
fn for_row_runs<T: Send>(data: &mut [T], row_len: usize, rows: usize, work: impl Fn(usize, &mut [T]) + Sync) {
	if rows == 0 || row_len == 0 {
		return;
	}
	let cores = threads().min(rows);
	if cores <= 1 || rows * row_len < INLINE_SAMPLES {
		work(0, &mut data[..rows * row_len]);
		return;
	}
	let rows_each = rows.div_ceil(cores);
	let work = &work;
	std::thread::scope(|scope| {
		for (i, run) in data[..rows * row_len].chunks_mut(rows_each * row_len).enumerate() {
			scope.spawn(move || work(i * rows_each, run));
		}
	});
}

// Runs `work` for every index on all cores, results in index order.
fn parallel_map<T: Send>(count: usize, work: impl Fn(usize) -> T + Sync) -> Vec<T> {
	if count <= 1 {
		return (0..count).map(work).collect();
	}
	let next = AtomicUsize::new(0);
	let (next, work) = (&next, &work);
	let mut done: Vec<(usize, T)> = std::thread::scope(|scope| {
		let mut handles = Vec::new();
		for _ in 0..threads().min(count.max(1)) {
			handles.push(scope.spawn(move || {
				let mut out = Vec::new();
				loop {
					let i = next.fetch_add(1, Ordering::Relaxed);
					if i >= count {
						break;
					}
					out.push((i, work(i)));
				}
				out
			}));
		}
		handles.into_iter().flat_map(|handle| handle.join().unwrap()).collect()
	});
	done.sort_by_key(|(i, _)| *i);
	done.into_iter().map(|(_, value)| value).collect()
}

// Where the camera stands and how the world maps onto the supersampled
// screen; the same numbers, worked out the same way, as the reference.
struct Camera {
	eye: Option<Vec3>,
	forward: Vec3,
	right: Vec3,
	up: Vec3,
	center: Vec3,
	width: f64,
	spread: f64,
	size: usize,
	light: Vec3,
	pixel_studs: f64,
	cull_back: bool,
}

impl Camera {
	fn to_screen(&self, p: Vec3) -> [f64; 3] {
		let (forward, right, up, spread, size) = (self.forward, self.right, self.up, self.spread, self.size);
		if let Some(eye) = self.eye {
			let d = sub(p, eye);
			let ahead = dot(d, forward);
			return [
				(dot(d, right) / (ahead * spread) + 0.5) * size as f64,
				(0.5 - dot(d, up) / (ahead * spread)) * size as f64,
				ahead,
			];
		}
		let d = sub(p, self.center);
		[
			(dot(d, right) / self.width + 0.5) * size as f64,
			(0.5 - dot(d, up) / self.width) * size as f64,
			dot(d, forward),
		]
	}

	// Whether a ball could put any triangle inside it on screen. False only
	// when the ball lies wholly beyond a frame edge (with a two-sample margin
	// against rounding) or, for an eye, wholly nearer than NEAR, where the
	// reference skips every triangle too.
	fn may_show(&self, centre: Vec3, radius: f64) -> bool {
		const MARGIN: f64 = 2.0;
		let size = self.size as f64;
		let Some(eye) = self.eye else {
			let p = self.to_screen(centre);
			let r = radius / self.width * size;
			let outside = p[0] + r < -MARGIN || p[0] - r > size + MARGIN || p[1] + r < -MARGIN || p[1] - r > size + MARGIN;
			return !outside;
		};
		let d = sub(centre, eye);
		if dot(d, self.forward) + radius < NEAR {
			return false;
		}
		// Each frame edge, pushed out by the margin, is a plane through the
		// eye; a corner past one lands off screen on that side.
		let k = self.spread * (0.5 + MARGIN / size);
		for side in [self.right, scale(self.right, -1.0), self.up, scale(self.up, -1.0)] {
			let normal = add(side, scale(self.forward, k));
			let length = dot(normal, normal).sqrt();
			if dot(d, normal) / length < -radius {
				return false;
			}
		}
		true
	}
}

// A part that survived culling, as plain data the drawing threads can share.
struct Drawn<'a> {
	// Its place in `parts`, which the owner buffer records.
	index: u32,
	image: &'a Image,
	mips: &'a Mips,
	see_through: bool,
	flat: Option<[f32; 3]>,
	emissive: f32,
	triangles: Vec<[Corner; 3]>,
}

// One triangle ready to draw: its corners on screen, its texture footprint,
// and the box of samples it may cover (already clipped to the screen).
struct Prepared {
	s: [[f64; 3]; 3],
	area: f64,
	texels_per_pixel: f64,
	slot: u32,
	triangle: u32,
	x0: u32,
	x1: u32,
	y0: u32,
	y1: u32,
}

// A band of whole screen rows starting at row `top`, with its own slices of
// the frame's buffers and the triangles that reach it, in drawing order.
struct Band<'a> {
	top: usize,
	depth: &'a mut [f64],
	color: &'a mut [[f32; 3]],
	glow: &'a mut [[f32; 3]],
	owner: &'a mut [u32],
	list: Vec<u32>,
	// The visibility buffer: the nearest solid triangle at each sample.
	nearest: Vec<u32>,
}

// Runs `work` on every band on all cores. Each band has its own lock, taken
// once by whichever core claims its number, so no lock is ever contended;
// bands are whole rows far apart, so cores never share cache lines either.
fn run_bands(bands: &mut [Band], work: impl Fn(&mut Band) + Sync) {
	let cores = threads().min(bands.len());
	if cores <= 1 {
		bands.iter_mut().for_each(|band| work(band));
		return;
	}
	let slots: Vec<Mutex<&mut Band>> = bands.iter_mut().map(Mutex::new).collect();
	let next = AtomicUsize::new(0);
	let (slots, next, work) = (&slots, &next, &work);
	std::thread::scope(|scope| {
		for _ in 0..cores {
			scope.spawn(move || loop {
				let i = next.fetch_add(1, Ordering::Relaxed);
				let Some(slot) = slots.get(i) else {
					break;
				};
				let mut band = slot.lock().unwrap();
				work(&mut **band);
			});
		}
	});
}

// Mip chains kept between renders, so a model rendered for many views builds
// each chain once. An image is known by its Rc and its buffers' addresses and
// sizes, plus a hash of a spread of its texels, so a reused address or a
// repainted image gets a fresh chain.
#[derive(Clone, Copy, PartialEq, Eq, Hash)]
struct ImageStamp {
	owner: usize,
	pixels: usize,
	alpha: usize,
	width: usize,
	height: usize,
	coarse: u64,
	texels: u64,
}

// Texels the stamp hashes, evenly spread over the image.
const STAMP_TEXELS: usize = 4096;
// Renders a chain may go unused before it is dropped.
const MIP_CACHE_RENDERS: u64 = 8;
// Most bytes of chains kept; the least recently used go first past it.
const MIP_CACHE_BYTES: usize = 1 << 30;

fn image_stamp(owner: usize, image: &Image) -> ImageStamp {
	let mut hash: u64 = 0xcbf2_9ce4_8422_2325;
	let mut mix = |bits: u32| hash = (hash ^ bits as u64).wrapping_mul(0x0000_0100_0000_01b3);
	let count = image.pixels.len();
	let step = (count / STAMP_TEXELS).max(1);
	for at in (0..count).step_by(step) {
		for channel in image.pixels[at] {
			mix(channel.to_bits());
		}
		if let Some(alpha) = &image.alpha {
			mix(alpha[at].to_bits());
		}
	}
	ImageStamp {
		owner,
		pixels: image.pixels.as_ptr() as usize,
		alpha: image.alpha.as_ref().map_or(0, |alpha| alpha.as_ptr() as usize),
		width: image.width,
		height: image.height,
		coarse: image.coarse.to_bits(),
		texels: hash,
	}
}

struct CachedChain {
	chain: Arc<Mips>,
	bytes: usize,
	last_used: u64,
}

#[derive(Default)]
struct MipCache {
	chains: HashMap<ImageStamp, CachedChain>,
	renders: u64,
}

fn mip_cache() -> &'static Mutex<MipCache> {
	static CACHE: OnceLock<Mutex<MipCache>> = OnceLock::new();
	CACHE.get_or_init(|| Mutex::new(MipCache::default()))
}

// The chain for each image, from the cache or built on all cores.
fn mip_chains(images: &[&Image], keys: &[usize]) -> Vec<Arc<Mips>> {
	let stamps = parallel_map(images.len(), |k| image_stamp(keys[k], images[k]));
	let mut cache = mip_cache().lock().unwrap();
	cache.renders += 1;
	let renders = cache.renders;
	let missing: Vec<usize> = (0..images.len()).filter(|&k| !cache.chains.contains_key(&stamps[k])).collect();
	let built = parallel_map(missing.len(), |m| Mips::new(images[missing[m]]));
	for (m, chain) in missing.iter().zip(built) {
		let bytes = chain.0.iter().map(|level| level.pixels.len() * 12 + level.alpha.as_ref().map_or(0, |alpha| alpha.len() * 4)).sum();
		cache.chains.insert(stamps[*m], CachedChain { chain: Arc::new(chain), bytes, last_used: renders });
	}
	let chains: Vec<Arc<Mips>> = stamps
		.iter()
		.map(|stamp| {
			let entry = cache.chains.get_mut(stamp).unwrap();
			entry.last_used = renders;
			entry.chain.clone()
		})
		.collect();
	cache.chains.retain(|_, entry| entry.last_used + MIP_CACHE_RENDERS > renders);
	let mut total: usize = cache.chains.values().map(|entry| entry.bytes).sum();
	while total > MIP_CACHE_BYTES {
		let Some((&oldest, _)) = cache.chains.iter().filter(|(_, entry)| entry.last_used < renders).min_by_key(|(_, entry)| entry.last_used) else {
			break;
		};
		total -= cache.chains.remove(&oldest).map_or(0, |entry| entry.bytes);
	}
	chains
}

// The posed box around the corners a mesh's triangles use, or None when it
// makes no triangles.
fn part_box(mesh: &Mesh, pose: Option<&Pose>) -> Option<(Vec3, Vec3)> {
	let mut low = [f64::MAX; 3];
	let mut high = [f64::MIN; 3];
	let mut any = false;
	for face in mesh.faces.iter().filter(|face| face.verts.len() >= 3) {
		for &vert in &face.verts {
			let p = match pose {
				Some(pose) => pose.apply(mesh.positions[vert]),
				None => mesh.positions[vert],
			};
			for axis in 0..3 {
				low[axis] = low[axis].min(p[axis]);
				high[axis] = high[axis].max(p[axis]);
			}
			any = true;
		}
	}
	if any { Some((low, high)) } else { None }
}

// Projects one triangle and works out its footprint, as the reference does
// before its sample loop; None when it would draw nothing.
fn prepare(camera: &Camera, drawn: &[Drawn], slot: usize, index: usize) -> Option<Prepared> {
	let part = &drawn[slot];
	let triangle = &part.triangles[index];
	let image = part.image;
	let size = camera.size;
	let s = triangle.map(|corner| camera.to_screen(corner.position));
	if camera.eye.is_some() && s.iter().any(|p| p[2] < NEAR) {
		return None;
	}
	let edge = |k: usize| sub(triangle[k].position, triangle[0].position);
	let face = cross(edge(1), edge(2));
	if camera.cull_back {
		let look = match camera.eye {
			Some(eye) => sub(triangle[0].position, eye),
			None => camera.forward,
		};
		if dot(face, look) >= 0.0 {
			return None;
		}
	}
	let world_area = dot(face, face).sqrt();
	let uv_edge = |k: usize, a: usize| (triangle[k].uv[a] - triangle[0].uv[a]) * if a == 0 { image.width } else { image.height } as f64;
	let texel_area = (uv_edge(1, 0) * uv_edge(2, 1) - uv_edge(2, 0) * uv_edge(1, 1)).abs();
	let density = if world_area > 1e-12 { (texel_area / world_area).sqrt() } else { 0.0 };
	let facing = if world_area > 1e-12 { (dot(face, camera.forward).abs() / world_area).max(MIP_MIN_FACING) } else { 1.0 };
	let texels_per_pixel = density * camera.pixel_studs / facing.sqrt();
	let area = (s[1][0] - s[0][0]) * (s[2][1] - s[0][1]) - (s[2][0] - s[0][0]) * (s[1][1] - s[0][1]);
	if area.abs() < 1e-12 {
		return None;
	}
	let x0 = s.iter().map(|p| p[0]).fold(f64::MAX, f64::min).floor().max(0.0) as usize;
	let x1 = (s.iter().map(|p| p[0]).fold(f64::MIN, f64::max).ceil() as usize).min(size);
	let y0 = s.iter().map(|p| p[1]).fold(f64::MAX, f64::min).floor().max(0.0) as usize;
	let y1 = (s.iter().map(|p| p[1]).fold(f64::MIN, f64::max).ceil() as usize).min(size);
	if x0 >= x1 || y0 >= y1 {
		return None;
	}
	Some(Prepared {
		s,
		area,
		texels_per_pixel,
		slot: slot as u32,
		triangle: index as u32,
		x0: x0 as u32,
		x1: x1 as u32,
		y0: y0 as u32,
		y1: y1 as u32,
	})
}

// The corner weights and depth at sample (x, y), or None outside the
// triangle; the reference's arithmetic in the reference's order.
fn weights(p: &Prepared, x: usize, y: usize, eye: bool) -> Option<(f64, f64, f64, f64)> {
	let (s, area) = (&p.s, p.area);
	let px = x as f64 + 0.5;
	let py = y as f64 + 0.5;
	let w0 = ((s[1][0] - px) * (s[2][1] - py) - (s[2][0] - px) * (s[1][1] - py)) / area;
	let w1 = ((s[2][0] - px) * (s[0][1] - py) - (s[0][0] - px) * (s[2][1] - py)) / area;
	let w2 = 1.0 - w0 - w1;
	if w0 < 0.0 || w1 < 0.0 || w2 < 0.0 {
		return None;
	}
	// Perspective: weights interpolate linearly in 1/depth.
	Some(if eye {
		let p = [w0 / s[0][2], w1 / s[1][2], w2 / s[2][2]];
		let sum = p[0] + p[1] + p[2];
		(p[0] / sum, p[1] / sum, p[2] / sum, 1.0 / sum)
	} else {
		(w0, w1, w2, w0 * s[0][2] + w1 * s[1][2] + w2 * s[2][2])
	})
}

// Colours one sample of a triangle that passed the depth test, exactly as
// the reference's sample loop does after its depth write.
fn shade_sample(camera: &Camera, part: &Drawn, p: &Prepared, (w0, w1, w2, z): (f64, f64, f64, f64), color: &mut [f32; 3], glow: &mut [f32; 3]) {
	let triangle = &part.triangles[p.triangle as usize];
	let blend = |f: &dyn Fn(usize) -> f64| w0 * f(0) + w1 * f(1) + w2 * f(2);
	let u = blend(&|k| triangle[k].uv[0]);
	let v = blend(&|k| triangle[k].uv[1]);
	let mut normal = normalize([0, 1, 2].map(|a| blend(&|k| triangle[k].normal[a])));
	// Back faces seen through holes still light as if facing us.
	if dot(normal, camera.forward) > 0.0 {
		normal = scale(normal, -1.0);
	}
	let shade = (0.72 + 0.38 * dot(normal, camera.light).max(0.0)) as f32;
	if let Some(tone) = part.flat {
		let shade = (0.45 + 0.6 * dot(normal, camera.light).max(0.0)) as f32;
		let opacity = if part.see_through { 0.4 } else { 1.0 };
		let under = *color;
		*color = [0, 1, 2].map(|a| under[a] + (tone[a] * shade - under[a]) * opacity);
		return;
	}
	let footprint = if camera.eye.is_some() { p.texels_per_pixel * z } else { p.texels_per_pixel };
	let albedo = part.mips.sample(part.image, u, v, footprint.max(1.0).log2());
	if part.see_through {
		let opacity = part.mips.sample_alpha(part.image, u, v, footprint.max(1.0).log2());
		let under = *color;
		*color = [0, 1, 2].map(|a| under[a] + (albedo[a] * shade - under[a]) * opacity);
		return;
	}
	*color = albedo.map(|c| c * (shade + part.emissive));
	*glow = albedo.map(|c| c * part.emissive);
}

// Draws one triangle sample by sample into a band, depth test and shading
// together, as the reference does: used for flat part colours, whose blend
// depends on what lay under, and for see-through parts.
fn draw_forward(camera: &Camera, part: &Drawn, p: &Prepared, band: &mut Band) {
	let size = camera.size;
	let eye = camera.eye.is_some();
	let rows = band.depth.len() / size;
	let (y_start, y_end) = ((p.y0 as usize).max(band.top), (p.y1 as usize).min(band.top + rows));
	for y in y_start..y_end {
		for x in p.x0 as usize..p.x1 as usize {
			let Some(w) = weights(p, x, y, eye) else {
				continue;
			};
			let at = (y - band.top) * size + x;
			if w.3 >= band.depth[at] {
				continue;
			}
			if !part.see_through {
				band.depth[at] = w.3;
				band.owner[at] = part.index;
			}
			shade_sample(camera, part, p, w, &mut band.color[at], &mut band.glow[at]);
		}
	}
}

// Band drawing runs in three phases, each over all bands before the next.
// Textured solid parts go through the visibility buffer: the nearest triangle
// per sample is found first (the first drawn wins a tie, as `z >= depth`
// skips in the reference), then each sample is shaded once. See-through
// parts then blend over in order. Flat part colours draw forward instead.

// Phase one: the visibility pass, or the whole forward pass for part colours.
fn band_raster(camera: &Camera, drawn: &[Drawn], prepared: &[Prepared], deferred: bool, band: &mut Band) {
	let size = camera.size;
	let eye = camera.eye.is_some();
	let list = std::mem::take(&mut band.list);
	if !deferred {
		for &t in &list {
			let p = &prepared[t as usize];
			draw_forward(camera, &drawn[p.slot as usize], p, band);
		}
		band.list = list;
		return;
	}
	let rows = band.depth.len() / size;
	let mut nearest = vec![NO_TRIANGLE; rows * size];
	for &t in &list {
		let p = &prepared[t as usize];
		if drawn[p.slot as usize].see_through {
			continue;
		}
		let (y_start, y_end) = ((p.y0 as usize).max(band.top), (p.y1 as usize).min(band.top + rows));
		for y in y_start..y_end {
			for x in p.x0 as usize..p.x1 as usize {
				let Some((_, _, _, z)) = weights(p, x, y, eye) else {
					continue;
				};
				let at = (y - band.top) * size + x;
				if z >= band.depth[at] {
					continue;
				}
				band.depth[at] = z;
				nearest[at] = t;
			}
		}
	}
	band.list = list;
	band.nearest = nearest;
}

// Phase two: each sample shaded once from its nearest triangle.
fn band_shade(camera: &Camera, drawn: &[Drawn], prepared: &[Prepared], band: &mut Band) {
	let size = camera.size;
	let eye = camera.eye.is_some();
	let nearest = std::mem::take(&mut band.nearest);
	for (at, &t) in nearest.iter().enumerate() {
		if t == NO_TRIANGLE {
			continue;
		}
		let p = &prepared[t as usize];
		let part = &drawn[p.slot as usize];
		band.owner[at] = part.index;
		let Some(w) = weights(p, at % size, band.top + at / size, eye) else {
			continue;
		};
		shade_sample(camera, part, p, w, &mut band.color[at], &mut band.glow[at]);
	}
}

// Phase three: see-through parts blend over, in drawing order.
fn band_glass(camera: &Camera, drawn: &[Drawn], prepared: &[Prepared], band: &mut Band) {
	let list = std::mem::take(&mut band.list);
	for &t in &list {
		let p = &prepared[t as usize];
		let part = &drawn[p.slot as usize];
		if part.see_through {
			draw_forward(camera, part, p, band);
		}
	}
}

fn draw_fast(parts: &[&Part], skin: &[Pose], view: &View) -> (Frame, Stages) {
	let mut stages = Stages::default();
	let mut clock = Instant::now();
	// Meshes and poses as plain shared references, so threads can read them.
	let mesh_borrows: Vec<Ref<Mesh>> = parts.iter().map(|part| part.mesh.borrow()).collect();
	let meshes: Vec<&Mesh> = mesh_borrows.iter().map(|mesh| &**mesh).collect();
	let poses: Vec<Option<&Pose>> = parts.iter().map(|part| part.bone.and_then(|b| skin.get(b))).collect();
	let boxes = parallel_map(parts.len(), |i| part_box(meshes[i], poses[i]));

	// The model's bounds are the bounds of every part's corners, as the
	// reference finds them over all triangles.
	let mut low = [f64::MAX; 3];
	let mut high = [f64::MIN; 3];
	for (part_low, part_high) in boxes.iter().flatten() {
		for axis in 0..3 {
			low[axis] = low[axis].min(part_low[axis]);
			high[axis] = high[axis].max(part_high[axis]);
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
	let tilt = normalize(toward);
	let light = normalize([tilt[0] * 0.3 - right[0], tilt[1] * 0.3 - right[1], 1.5]);
	let span = |axis: Vec3| (0..3).map(|a| (high[a] - low[a]) * axis[a].abs()).sum::<f64>();
	let width = match view.side {
		Some(_) => span(right).max(span(up)).max(1e-6) * 1.1,
		None => extent * 2.2 / 1.4,
	};
	let colours = if view.parts { part_colours(parts) } else { Vec::new() };
	let size = view.size * SUPERSAMPLE;
	let spread = (EYE_FOV.to_radians() / 2.0).tan() * 2.0;
	let pixel_studs = if view.eye.is_some() { spread / size as f64 } else { width / size as f64 };
	let camera = Camera { eye: view.eye.map(|(eye, _)| eye), forward, right, up, center, width, spread, size, light, pixel_studs, cull_back: view.cull_back };

	// Frustum culling: a part whose bounding ball lies wholly off screen is
	// never triangulated, textured or walked. The ball is padded a little so
	// rounding can never cull a part the reference would draw.
	let kept: Vec<usize> = (0..parts.len())
		.filter(|&i| {
			let Some((part_low, part_high)) = boxes[i] else {
				return false;
			};
			let centre = scale(add(part_low, part_high), 0.5);
			let half = scale(sub(part_high, part_low), 0.5);
			let radius = dot(half, half).sqrt();
			let reach = dot(centre, centre).sqrt() + dot(camera.eye.unwrap_or(center), camera.eye.unwrap_or(center)).sqrt();
			camera.may_show(centre, radius + 1e-6 * (1.0 + radius + reach))
		})
		.collect();

	// Textures of the kept parts, each borrowed and mip-chained once (parts
	// can share an image).
	let mut keys: Vec<*const RefCell<Image>> = Vec::new();
	let mut image_of = vec![0usize; parts.len()];
	for &i in &kept {
		let key = Rc::as_ptr(&parts[i].image);
		image_of[i] = match keys.iter().position(|k| *k == key) {
			Some(found) => found,
			None => {
				keys.push(key);
				keys.len() - 1
			}
		};
	}
	let mut first_user = vec![usize::MAX; keys.len()];
	for &i in kept.iter().rev() {
		first_user[image_of[i]] = i;
	}
	let image_borrows: Vec<Ref<Image>> = first_user.iter().map(|&i| parts[i].image.borrow()).collect();
	let images: Vec<&Image> = image_borrows.iter().map(|image| &**image).collect();
	stages.setup += lap(&mut clock);
	let key_numbers: Vec<usize> = keys.iter().map(|key| *key as usize).collect();
	let chains = mip_chains(&images, &key_numbers);
	stages.mips = lap(&mut clock);

	// Triangles of the kept parts, posed, on all cores; then solid parts
	// first and see-through after, each group in part order, as drawn.
	let lists = parallel_map(kept.len(), |k| {
		let i = kept[k];
		let mut list = meshes[i].triangles();
		if let Some(pose) = poses[i] {
			for corner in list.iter_mut().flatten() {
				corner.position = pose.apply(corner.position);
				corner.normal = pose.turn(corner.normal);
			}
		}
		list
	});
	let all: Vec<Drawn> = kept
		.iter()
		.zip(lists)
		.map(|(&i, triangles)| {
			let part = parts[i];
			let image = images[image_of[i]];
			Drawn {
				index: i as u32,
				image,
				mips: &*chains[image_of[i]],
				see_through: image.alpha.is_some(),
				flat: colours.iter().find(|(name, _)| *name == part.name).map(|(_, c)| *c),
				emissive: part.emissive,
				triangles,
			}
		})
		.collect();
	let (mut drawn, glass): (Vec<Drawn>, Vec<Drawn>) = all.into_iter().partition(|part| !part.see_through);
	let any_glass = !glass.is_empty();
	drawn.extend(glass);
	stages.setup += lap(&mut clock);

	// Setup on all cores in fixed chunks of the drawing order, joined back in
	// that order.
	let mut starts = Vec::with_capacity(drawn.len());
	let mut total = 0;
	for part in &drawn {
		starts.push(total);
		total += part.triangles.len();
	}
	let chunks = parallel_map(total.div_ceil(SETUP_CHUNK), |c| {
		let (begin, end) = (c * SETUP_CHUNK, ((c + 1) * SETUP_CHUNK).min(total));
		let mut slot = starts.partition_point(|&start| start <= begin) - 1;
		let mut index = begin - starts[slot];
		let mut out = Vec::new();
		for _ in begin..end {
			while index >= drawn[slot].triangles.len() {
				slot += 1;
				index = 0;
			}
			if let Some(p) = prepare(&camera, &drawn, slot, index) {
				out.push(p);
			}
			index += 1;
		}
		out
	});
	let prepared: Vec<Prepared> = chunks.into_iter().flatten().collect();
	stages.prepare = lap(&mut clock);

	// Zeroed buffers come from the system untouched; each band fills its own
	// slice with the starting values on its core (see `band_raster`).
	let mut color = vec![[0.0f32; 3]; size * size];
	let mut depth = vec![0.0f64; size * size];
	let mut glow = vec![[0.0f32; 3]; size * size];
	let mut owner = vec![0u32; size * size];

	// Binning: each triangle joins the list of every band its box reaches,
	// in drawing order.
	let band_count = size.div_ceil(BAND_ROWS);
	let mut lists: Vec<Vec<u32>> = vec![Vec::new(); band_count];
	for (t, p) in prepared.iter().enumerate() {
		for band in p.y0 as usize / BAND_ROWS..=(p.y1 as usize - 1) / BAND_ROWS {
			lists[band].push(t as u32);
		}
	}
	let chunk = (BAND_ROWS * size).max(1);
	let bands: Vec<Band> = depth
		.chunks_mut(chunk)
		.zip(color.chunks_mut(chunk))
		.zip(glow.chunks_mut(chunk))
		.zip(owner.chunks_mut(chunk))
		.zip(lists)
		.enumerate()
		.map(|(b, ((((depth, color), glow), owner), list))| Band { top: b * BAND_ROWS, depth, color, glow, owner, list, nearest: Vec::new() })
		.collect();
	let mut bands = bands;
	stages.bin = lap(&mut clock);

	// Flat part colours blend over what lay under, so they keep the
	// reference's draw-and-shade order; textures go through the visibility
	// buffer.
	let deferred = !view.parts;
	let (camera_ref, drawn_ref, prepared_ref) = (&camera, &drawn[..], &prepared[..]);
	run_bands(&mut bands, |band| {
		band.color.fill(BACKGROUND);
		band.depth.fill(f64::MAX);
		band.owner.fill(NO_PART);
		band_raster(camera_ref, drawn_ref, prepared_ref, deferred, band);
	});
	stages.raster = lap(&mut clock);
	if deferred {
		run_bands(&mut bands, |band| band_shade(camera_ref, drawn_ref, prepared_ref, band));
	}
	stages.shade = lap(&mut clock);
	if deferred && any_glass {
		run_bands(&mut bands, |band| band_glass(camera_ref, drawn_ref, prepared_ref, band));
	}
	drop(bands);
	stages.glass = lap(&mut clock);

	if let (Some(_), Some(step)) = (view.side, view.grid) {
		draw_grid(&mut color, size, width, [dot(center, right), dot(center, up)], step);
	}

	let bloom = blur_fast(&glow, size, size / 150);
	stages.bloom = lap(&mut clock);

	// Each picture row averages its supersampled block, rows on all cores.
	let mut data = vec![0u8; view.size * view.size * 3];
	let (color, bloom) = (&color, &bloom);
	for_row_runs(&mut data, view.size * 3, view.size, |first, run| {
		for (row, line) in run.chunks_mut(view.size * 3).enumerate() {
			let y = first + row;
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
				let pixel = sum.map(|c| ((c / samples).clamp(0.0, 1.0) * 255.0 + 0.5) as u8);
				line[x * 3..x * 3 + 3].copy_from_slice(&pixel);
			}
		}
	});
	fxaa_fast(&mut data, view.size, view.size);
	stages.finish = lap(&mut clock);
	(Frame { pixels: data, owner, owner_size: size }, stages)
}

// The reference renderer, kept unchanged: every part, every triangle, each
// sample shaded as it is drawn. MODELKIT_RENDER_CHECK compares against it.
fn draw_reference(parts: &[&Part], skin: &[Pose], view: &View) -> Frame {
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

// The same fxaa with rows on all cores; every pixel reads the untouched copy,
// so rows are independent and the arithmetic is unchanged.
fn fxaa_fast(data: &mut [u8], width: usize, height: usize) {
	if width < 3 || height < 3 {
		return;
	}
	let source = data.to_vec();
	let luma: Vec<f32> = source.chunks(3).map(|c| (0.299 * c[0] as f32 + 0.587 * c[1] as f32 + 0.114 * c[2] as f32) / 255.0).collect();
	let (source, luma) = (&source, &luma);
	let at = |x: usize, y: usize| y * width + x;
	for_row_runs(data, width * 3, height, |first, run| {
		for (row, line) in run.chunks_mut(width * 3).enumerate() {
			let y = first + row;
			if y == 0 || y == height - 1 {
				continue;
			}
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
				let horizontal = (n + s - 2.0 * l).abs() >= (w + e - 2.0 * l).abs();
				let (a, b) = if horizontal { (at(x, y - 1), at(x, y + 1)) } else { (at(x - 1, y), at(x + 1, y)) };
				let weight = ((sum / 9.0 - l).abs() / range).clamp(0.0, 1.0).powi(2) * 0.5;
				let p = at(x, y) * 3;
				for k in 0..3 {
					let blended = source[a * 3 + k] as f32 * 0.5 + source[b * 3 + k] as f32 * 0.5;
					line[x * 3 + k] = (source[p + k] as f32 * (1.0 - weight) + blended * weight + 0.5) as u8;
				}
			}
		}
	});
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

// The same blur on all cores, every sum in the same order as in `blur`: rows
// split into runs of whole rows, columns into blocks of whole columns that
// sweep down the picture together (no transposes, reads stay in rows).
fn blur_fast(pixels: &[[f32; 3]], size: usize, radius: usize) -> Vec<[f32; 3]> {
	let mut out = pixels.to_vec();
	if radius == 0 || out.iter().all(|p| *p == [0.0; 3]) {
		return out;
	}
	for _ in 0..3 {
		for_row_runs(&mut out, size, size, |_, run| {
			let mut line = vec![[0.0f32; 3]; size];
			for row in run.chunks_mut(size) {
				blur_line(row, &mut line, radius);
			}
		});
		blur_columns(&mut out, size, radius);
	}
	out
}

// One box-blur pass down every column. Each block of columns is blurred into
// its own buffer from the untouched picture, then copied back row by row.
fn blur_columns(pixels: &mut [[f32; 3]], size: usize, radius: usize) {
	let width_each = size.div_ceil(threads().min(size).max(1)).max(1);
	let source: &[[f32; 3]] = pixels;
	let blocks: Vec<Vec<[f32; 3]>> = parallel_map(size.div_ceil(width_each), |b| {
		let (x0, x1) = (b * width_each, ((b + 1) * width_each).min(size));
		let w = x1 - x0;
		let row = |y: usize| &source[y * size + x0..y * size + x1];
		let divisor = (2 * radius + 1) as f32;
		let mut out = vec![[0.0f32; 3]; size * w];
		let mut sums = vec![[0.0f32; 3]; w];
		for i in 0..=radius.min(size - 1) {
			for (sum, p) in sums.iter_mut().zip(row(i)) {
				for a in 0..3 {
					sum[a] += p[a];
				}
			}
		}
		for i in 0..size {
			for (target, sum) in out[i * w..(i + 1) * w].iter_mut().zip(&sums) {
				*target = sum.map(|c| c / divisor);
			}
			if i + radius + 1 < size {
				for (sum, p) in sums.iter_mut().zip(row(i + radius + 1)) {
					for a in 0..3 {
						sum[a] += p[a];
					}
				}
			}
			if i >= radius {
				for (sum, p) in sums.iter_mut().zip(row(i - radius)) {
					for a in 0..3 {
						sum[a] -= p[a];
					}
				}
			}
		}
		out
	});
	let blocks = &blocks;
	for_row_runs(pixels, size, size, |first, run| {
		for (r, line) in run.chunks_mut(size).enumerate() {
			let y = first + r;
			for (b, block) in blocks.iter().enumerate() {
				let (x0, w) = (b * width_each, block.len() / size);
				line[x0..x0 + w].copy_from_slice(&block[y * w..(y + 1) * w]);
			}
		}
	});
}

// One box-blur pass along a row, the arithmetic of `blur` with a step of 1.
fn blur_line(row: &mut [[f32; 3]], line: &mut [[f32; 3]], radius: usize) {
	let size = row.len();
	let mut sum = [0.0f32; 3];
	for i in 0..=radius.min(size - 1) {
		for a in 0..3 {
			sum[a] += row[i][a];
		}
	}
	for i in 0..size {
		line[i] = sum.map(|c| c / (2 * radius + 1) as f32);
		if i + radius + 1 < size {
			for a in 0..3 {
				sum[a] += row[i + radius + 1][a];
			}
		}
		if i >= radius {
			for a in 0..3 {
				sum[a] -= row[i - radius][a];
			}
		}
	}
	row.copy_from_slice(line);
}
