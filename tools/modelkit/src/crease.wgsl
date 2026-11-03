// Contact creases on the GPU: bake.rs's crease_paint for one texel per
// invocation. Every step follows the CPU code in bake.rs line for line, in
// f32, so a texel's paint matches the CPU bake up to rounding. Keep the two in
// step: a change to crease_paint or brush_strokes needs the same change here.

struct Params {
	first: u32,
	count: u32,
	// Hash table size minus one (the size is a power of two).
	mask: u32,
	min_cos: f32,
	// How far a contact shadow reaches from its corner, in studs.
	reach: f32,
	// How much wider the highlight brush is than the shadow brush.
	highlight_width: f32,
	// 1 paints highlights as bold painted strokes instead of dry ones.
	painted: f32,
	// Studs a highlight thins over away from a corner; 0 keeps it even.
	corner_taper: f32,
}

struct Texel {
	position: vec3<f32>,
	_pad0: f32,
	normal: vec3<f32>,
	_pad1: f32,
}

struct Surface {
	a: vec3<f32>,
	// 1 for this part's own surfaces, which alone make exterior angles.
	mine: u32,
	b: vec3<f32>,
	_pad0: f32,
	c: vec3<f32>,
	_pad1: f32,
	facing: vec3<f32>,
	_pad2: f32,
}

// One contact grid cell: its surfaces are items[start .. start + count].
struct Slot {
	key: vec3<i32>,
	used: u32,
	start: u32,
	count: u32,
	_pad0: u32,
	_pad1: u32,
}

@group(0) @binding(0) var<uniform> params: Params;
@group(0) @binding(1) var<storage, read> texels: array<Texel>;
@group(0) @binding(2) var<storage, read> surfaces: array<Surface>;
@group(0) @binding(3) var<storage, read> slots: array<Slot>;
@group(0) @binding(4) var<storage, read> items: array<u32>;
@group(0) @binding(5) var<storage, read_write> paint: array<vec2<f32>>;

const PI: f32 = 3.14159265358979;
const CONTACT_MIN_FOLD: f32 = 1.0 / 6.0;
const BRISTLES: f32 = 14.0;
const TAPER_MIN: f32 = 0.15;
const TAPER_PLANE: f32 = 0.05;

// bake.rs hash().
fn hash(seed: u32) -> f32 {
	var x = seed;
	x ^= x >> 16u;
	x *= 0x7feb352du;
	x ^= x >> 15u;
	x *= 0x846ca68bu;
	x ^= x >> 16u;
	return f32(x) / 4294967295.0;
}

// Rust's f64::round rounds halves away from zero; WGSL's round goes to even.
fn round_away(x: f32) -> i32 {
	return i32(sign(x) * floor(abs(x) + 0.5));
}

fn normalize_or_up(a: vec3<f32>) -> vec3<f32> {
	let length = sqrt(dot(a, a));
	if length > 1e-12 {
		return a / length;
	}
	return vec3<f32>(0.0, 0.0, 1.0);
}

// u^0.7 for u in 0-1. pow(0, y) is undefined in WGSL.
fn taper_pow(u: f32) -> f32 {
	if u <= 0.0 {
		return 0.0;
	}
	return pow(u, 0.7);
}

fn find_slot(key: vec3<i32>) -> i32 {
	var at = (bitcast<u32>(key.x) * 73856093u ^ bitcast<u32>(key.y) * 19349663u ^ bitcast<u32>(key.z) * 83492791u) & params.mask;
	loop {
		let slot = slots[at];
		if slot.used == 0u {
			return -1;
		}
		if all(slot.key == key) {
			return i32(at);
		}
		at = (at + 1u) & params.mask;
	}
	return -1;
}

fn closest_on_triangle(p: vec3<f32>, a: vec3<f32>, b: vec3<f32>, c: vec3<f32>) -> vec3<f32> {
	let ab = b - a;
	let ac = c - a;
	let ap = p - a;
	let d1 = dot(ab, ap);
	let d2 = dot(ac, ap);
	if d1 <= 0.0 && d2 <= 0.0 {
		return a;
	}
	let bp = p - b;
	let d3 = dot(ab, bp);
	let d4 = dot(ac, bp);
	if d3 >= 0.0 && d4 <= d3 {
		return b;
	}
	let vc = d1 * d4 - d3 * d2;
	if vc <= 0.0 && d1 >= 0.0 && d3 <= 0.0 {
		return a + ab * (d1 / (d1 - d3));
	}
	let cp = p - c;
	let d5 = dot(ab, cp);
	let d6 = dot(ac, cp);
	if d6 >= 0.0 && d5 <= d6 {
		return c;
	}
	let vb = d5 * d2 - d1 * d6;
	if vb <= 0.0 && d2 >= 0.0 && d6 <= 0.0 {
		return a + ac * (d2 / (d2 - d6));
	}
	let va = d3 * d6 - d5 * d4;
	if va <= 0.0 && d4 - d3 >= 0.0 && d5 - d6 >= 0.0 {
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)));
	}
	let denom = 1.0 / (va + vb + vc);
	return a + ab * (vb * denom) + ac * (vc * denom);
}

// bake.rs brush_strokes(), with the length unbounded as crease_paint calls it.
// bake.rs painted_strokes: bold, fully loaded highlight strokes.
fn painted_strokes(edge: u32, t: f32, d: f32, wide: f32) -> f32 {
	let width = 0.16 * wide;
	let stroke = 1.4;
	let step = 0.8;
	var paint = 0.0;
	let first = i32(floor(t / step));
	for (var i = first - i32(ceil(stroke / step)) - 1; i <= first; i++) {
		let seed = edge * 7919u + bitcast<u32>(i) * 131u + 4111u;
		let start = f32(i) * step + (hash(seed * 16u + 0u) - 0.5) * step;
		let span = stroke * (0.7 + 0.6 * hash(seed * 16u + 1u));
		let u = (t - start) / span;
		if u < 0.0 || u > 1.0 {
			continue;
		}
		let taper = pow(max(sin(PI * u), 0.0), 0.3);
		let wobble = 1.0 + 0.18 * sin(t * 6.0 + hash(seed * 16u + 4u) * 6.283);
		let half = width * (0.45 + 0.75 * hash(seed * 16u + 2u)) * taper * wobble;
		let centre = width * 0.25 * hash(seed * 16u + 3u);
		let s = (d - centre) / max(half, 1e-6);
		if abs(s) >= 1.0 {
			continue;
		}
		let rim = clamp((1.0 - abs(s)) / 0.12, 0.0, 1.0);
		paint = max(paint, rim * (0.8 + 0.2 * hash(seed * 16u + 5u)));
	}
	return paint;
}

fn brush_strokes(edge: u32, t: f32, d: f32, wide: f32) -> f32 {
	var paint = 0.0;
	// The two BRUSH_PASSES; `pass` is a reserved word in WGSL.
	for (var layer = 0u; layer < 2u; layer++) {
		let width = select(0.08, 0.16, layer == 0u);
		let stroke = select(0.35, 0.6, layer == 0u);
		let step = select(0.22, 0.4, layer == 0u);
		let strength = select(1.0, 0.75, layer == 0u);
		let first = i32(floor(t / step));
		for (var i = first - i32(ceil(stroke / step)) - 1; i <= first; i++) {
			let seed = edge * 7919u + bitcast<u32>(i) * 131u + layer * 977u;
			let start = f32(i) * step + (hash(seed * 16u + 0u) - 0.5) * step;
			let span = stroke * (0.6 + 0.8 * hash(seed * 16u + 1u));
			let u = (t - start) / span;
			if u < 0.0 || u > 1.0 || start + span < 0.0 {
				continue;
			}
			let taper = sqrt(max(sin(PI * taper_pow(u)), 0.0));
			let half = width * wide * (0.5 + 0.6 * hash(seed * 16u + 2u)) * taper;
			let centre = width * 0.5 * hash(seed * 16u + 3u);
			let s = (d - centre) / max(half, 1e-6);
			if abs(s) >= 1.0 {
				continue;
			}
			let rim = clamp((1.0 - abs(s)) / 0.25, 0.0, 1.0);
			let bristle = u32(floor((s + 1.0) * 0.5 * BRISTLES));
			let load = 0.55 + 0.45 * hash(seed * 97u + bristle * 13u + 0u);
			let dry = 0.55 + 0.45 * hash(seed * 97u + bristle * 13u + 1u) - 0.25 * (1.0 - hash(seed * 16u + 4u));
			let breakup = clamp((dry - u) / 0.12, 0.0, 1.0);
			let pressure = strength * (0.6 + 0.4 * hash(seed * 16u + 5u)) * (1.0 - 0.4 * u);
			let alpha = rim * load * breakup * pressure;
			paint = 1.0 - (1.0 - paint) * (1.0 - alpha);
		}
	}
	return paint;
}

// bake.rs corner_taper.
fn corner_taper(p: vec3<f32>, n: vec3<f32>, q: vec3<f32>, a: vec3<f32>, b: vec3<f32>, c: vec3<f32>, taper: f32) -> f32 {
	var nearest = 3.4e38;
	let corners = array<vec3<f32>, 3>(a, b, c);
	for (var i = 0; i < 3; i++) {
		let v = corners[i];
		if abs(dot(n, v - p)) < TAPER_PLANE {
			let gap = v - q;
			nearest = min(nearest, sqrt(dot(gap, gap)));
		}
	}
	return TAPER_MIN + (1.0 - TAPER_MIN) * exp(-nearest / taper);
}

// FNV-1a over one plane's rounded normal and offset, as crease_paint seeds a crease.
fn fold_plane(h: u32, m: vec3<f32>, at: vec3<f32>) -> u32 {
	var out = h;
	out = (out ^ bitcast<u32>(round_away(m.x * 8.0))) * 0x01000193u;
	out = (out ^ bitcast<u32>(round_away(m.y * 8.0))) * 0x01000193u;
	out = (out ^ bitcast<u32>(round_away(m.z * 8.0))) * 0x01000193u;
	out = (out ^ bitcast<u32>(round_away(dot(m, at) * 20.0))) * 0x01000193u;
	return out;
}

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) id: vec3<u32>) {
	if id.x >= params.count {
		return;
	}
	let index = params.first + id.x;
	let p = texels[index].position;
	let n = texels[index].normal;
	let home = vec3<i32>(floor(p / params.reach));
	var inward = 0.0;
	var outward = 0.0;
	for (var x = -1; x <= 1; x++) {
		for (var y = -1; y <= 1; y++) {
			for (var z = -1; z <= 1; z++) {
				let found = find_slot(home + vec3<i32>(x, y, z));
				if found < 0 {
					continue;
				}
				let slot = slots[found];
				for (var k = slot.start; k < slot.start + slot.count; k++) {
					let surface = surfaces[items[k]];
					let facing = surface.facing;
					if dot(n, facing) >= params.min_cos {
						continue;
					}
					let offset = p - closest_on_triangle(p, surface.a, surface.b, surface.c);
					let distance = sqrt(dot(offset, offset));
					let side = dot(facing, offset);
					let front = side > 0.0;
					let behind = side < 0.0 && surface.mine != 0u;
					if distance < 1e-6 || distance >= params.reach || !(front || behind) || dot(n, offset) > 0.3 * distance {
						continue;
					}
					let fold = acos(clamp(dot(n, facing), -1.0, 1.0)) / PI;
					let sharpness = clamp((fold - CONTACT_MIN_FOLD) / (0.5 - CONTACT_MIN_FOLD), 0.0, 1.0);
					let crease = normalize_or_up(cross(n, facing));
					let along = dot(p, crease) + 1000.0;
					let seed = fold_plane(fold_plane(0x811c9dc5u, n, p), facing, surface.a);
					var taper = 1.0;
					if behind && params.corner_taper > 0.0 {
						taper = corner_taper(p, n, p - offset, surface.a, surface.b, surface.c, params.corner_taper);
					}
					let fade = params.reach * taper;
					if distance >= fade {
						continue;
					}
					let wide = select(1.0, params.highlight_width * taper, behind);
					var value = 0.0;
					if behind && params.painted != 0.0 {
						value = sharpness * painted_strokes(seed, along, distance, wide);
					} else {
						value = sharpness * brush_strokes(seed, along, distance, wide) * (1.0 - distance / fade);
					}
					if front {
						inward = max(inward, value);
					}
					if behind {
						outward = max(outward, value);
					}
				}
			}
		}
	}
	paint[index] = vec2<f32>(inward, outward);
}
