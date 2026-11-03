// Canvas on the GPU: brush.rs's Canvas::paint and Canvas::over for one texel
// per invocation, compositing the strokes listed under the texel's grid cell
// in the order they were added. Every step follows brush.rs in f32, so keep
// the two in step: a change to a brush there needs the same change here.

struct Params {
	first: u32,
	count: u32,
	// Hash table size minus one (the size is a power of two).
	mask: u32,
	cell_size: f32,
	// Unused here, kept so both shaders share one uniform layout.
	reach: f32,
	highlight_width: f32,
	painted: f32,
	_pad: f32,
}

struct Texel {
	position: vec3<f32>,
	_pad0: f32,
	normal: vec3<f32>,
	_pad1: f32,
}

struct Stroke {
	start: vec3<f32>,
	length: f32,
	along: vec3<f32>,
	width: f32,
	across: vec3<f32>,
	opacity: f32,
	normal: vec3<f32>,
	// Index into brush.rs's Brush enum.
	brush: u32,
	color: vec3<f32>,
	seed: u32,
	// brush.rs Stroke::tail.
	tail: f32,
	_pad0: f32,
	_pad1: f32,
	_pad2: f32,
}

// One canvas grid cell: its strokes are items[start .. start + count].
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
@group(0) @binding(2) var<storage, read> strokes: array<Stroke>;
@group(0) @binding(3) var<storage, read> slots: array<Slot>;
@group(0) @binding(4) var<storage, read> items: array<u32>;
// Linear color, and for `over` how much of the texel the strokes cover.
@group(0) @binding(5) var<storage, read_write> paint: array<vec4<f32>>;

const PI: f32 = 3.14159265358979;
const PLANE: f32 = 0.025;
const FLAT: u32 = 0u;
const ROUND: u32 = 1u;
const SPONGE: u32 = 3u;
const DRY: u32 = 4u;
const TAPER: u32 = 5u;

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

// brush.rs bristles(): (bristle count, how far each may run dry early).
fn bristles(brush: u32) -> vec2<f32> {
	switch brush {
		case 0u: { return vec2<f32>(16.0, 0.3); }
		case 1u: { return vec2<f32>(8.0, 0.4); }
		case 2u: { return vec2<f32>(3.0, 0.15); }
		case 3u: { return vec2<f32>(1.0, 0.0); }
		case 5u: { return vec2<f32>(1.0, 0.0); }
		default: { return vec2<f32>(10.0, 0.5); }
	}
}

// brush.rs BRISTLE_TONE.
fn bristle_tone(brush: u32) -> f32 {
	switch brush {
		case 0u: { return 0.35; }
		case 1u: { return 0.25; }
		case 2u: { return 0.15; }
		case 3u: { return 0.2; }
		case 5u: { return 0.0; }
		default: { return 0.3; }
	}
}

fn tone(stroke: Stroke, p: vec3<f32>) -> f32 {
	let offset = p - stroke.start;
	let side = dot(offset, stroke.across) / max(stroke.width / 2.0, 1e-6);
	let count = bristles(stroke.brush).x;
	let bristle = u32(floor((clamp(side, -1.0, 0.999) + 1.0) * 0.5 * count));
	return 1.0 + (hash(stroke.seed * 53u + bristle * 7u + 3u) - 0.5) * bristle_tone(stroke.brush);
}

fn sponge(stroke: Stroke, p: vec3<f32>, t: f32, side: f32) -> f32 {
	let radius = stroke.width / 2.0;
	let distance = length(vec2<f32>(t, side)) / radius;
	let angle = atan2(side, t);
	let edge = 1.0 + 0.22 * sin(3.0 * angle + hash(stroke.seed * 16u + 1u) * 6.3) + 0.12 * sin(5.0 * angle + hash(stroke.seed * 16u + 2u) * 6.3);
	if distance >= edge {
		return 0.0;
	}
	let pore = bitcast<vec3<u32>>(vec3<i32>(floor(p / 0.022)));
	let open = hash(stroke.seed ^ pore.x * 73856093u ^ pore.y * 19349663u ^ pore.z * 83492791u);
	if open < 0.2 + 0.4 * distance / edge {
		return 0.0;
	}
	return 1.0;
}

// brush.rs Stroke::cover().
fn cover(stroke: Stroke, p: vec3<f32>, n: vec3<f32>) -> f32 {
	if dot(n, stroke.normal) < 0.3 {
		return 0.0;
	}
	let offset = p - stroke.start;
	if abs(dot(offset, stroke.normal)) > PLANE {
		return 0.0;
	}
	let t = dot(offset, stroke.along);
	let side = dot(offset, stroke.across);
	if stroke.brush == SPONGE {
		return sponge(stroke, p, t - stroke.length / 2.0, side) * stroke.opacity;
	}
	let u = t / stroke.length;
	if u < 0.0 || u > 1.0 {
		return 0.0;
	}
	var shape: f32;
	if stroke.brush == FLAT || stroke.brush == DRY {
		shape = 0.85 + 0.15 * sin(PI * u);
	} else if stroke.brush == ROUND {
		shape = sqrt(max(sin(PI * select(pow(u, 0.7), 0.0, u <= 0.0)), 0.0));
	} else if stroke.brush == TAPER {
		shape = 1.0 - (1.0 - stroke.tail) * u;
	} else {
		shape = (1.0 - 0.6 * u) * sqrt(min(u * 6.0, 1.0));
	}
	let half = stroke.width / 2.0 * shape;
	let s = side / max(half, 1e-6);
	if abs(s) >= 1.0 {
		return 0.0;
	}
	let kind = bristles(stroke.brush);
	let bristle = u32(floor((s + 1.0) * 0.5 * kind.x));
	let dry = 1.0 - kind.y * hash(stroke.seed * 97u + bristle * 13u + 0u) - 0.1 * hash(stroke.seed * 16u + 0u);
	let breakup = select(clamp((dry - u) / 0.08, 0.0, 1.0), 1.0, stroke.brush == TAPER);
	if breakup <= 0.0 {
		return 0.0;
	}
	if stroke.brush == DRY {
		let skip = bitcast<u32>(i32(floor(t / 0.035)));
		if hash(stroke.seed ^ bristle * 7919u ^ skip * 104729u) < 0.45 {
			return 0.0;
		}
	}
	let rim = clamp((1.0 - abs(s)) / 0.2, 0.0, 1.0);
	let load = 0.75 + 0.25 * hash(stroke.seed * 97u + bristle * 13u + 1u);
	return rim * load * breakup * stroke.opacity;
}

// The texel's cell in the canvas grid, or no strokes.
fn home_slot(p: vec3<f32>) -> Slot {
	let found = find_slot(vec3<i32>(floor(p / params.cell_size)));
	if found < 0 {
		return Slot(vec3<i32>(0), 0u, 0u, 0u, 0u, 0u);
	}
	return slots[found];
}

// brush.rs Canvas::paint().
@compute @workgroup_size(64)
fn paint_main(@builtin(global_invocation_id) id: vec3<u32>) {
	if id.x >= params.count {
		return;
	}
	let index = params.first + id.x;
	let p = texels[index].position;
	let n = texels[index].normal;
	let slot = home_slot(p);
	var nearest = 3.4e38;
	var color = vec3<f32>(0.5);
	for (var k = slot.start; k < slot.start + slot.count; k++) {
		let stroke = strokes[items[k]];
		if stroke.brush != FLAT || dot(n, stroke.normal) < 0.3 {
			continue;
		}
		let offset = p - (stroke.start + stroke.along * (stroke.length / 2.0));
		let off_plane = dot(offset, stroke.normal);
		let d = dot(offset, offset) + off_plane * off_plane * 50.0;
		if d < nearest {
			nearest = d;
			color = stroke.color;
		}
	}
	for (var k = slot.start; k < slot.start + slot.count; k++) {
		let stroke = strokes[items[k]];
		let alpha = cover(stroke, p, n);
		if alpha > 0.0 {
			color += (stroke.color * tone(stroke, p) - color) * alpha;
		}
	}
	paint[index] = vec4<f32>(color, 1.0);
}

// brush.rs Canvas::over().
@compute @workgroup_size(64)
fn over_main(@builtin(global_invocation_id) id: vec3<u32>) {
	if id.x >= params.count {
		return;
	}
	let index = params.first + id.x;
	let p = texels[index].position;
	let n = texels[index].normal;
	let slot = home_slot(p);
	var color = vec3<f32>(0.0);
	var covered = 0.0;
	for (var k = slot.start; k < slot.start + slot.count; k++) {
		let stroke = strokes[items[k]];
		let alpha = cover(stroke, p, n);
		if alpha > 0.0 {
			let laid = stroke.color * tone(stroke, p);
			color = select(color + (laid - color) * alpha, laid, covered == 0.0);
			covered = 1.0 - (1.0 - covered) * (1.0 - alpha);
		}
	}
	paint[index] = vec4<f32>(color, covered);
}
