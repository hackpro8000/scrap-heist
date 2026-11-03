// GPU bake: the shading bake's per-texel passes (contact creases, the coat
// and the wear over it) run as compute shaders when the machine has a real
// GPU. Each pass returns None when there is none, or when the work doesn't
// fit, and the caller bakes on the CPU instead, so a build never needs a GPU.
// MODELKIT_GPU=off forces the CPU bake. Software adapters (llvmpipe) don't
// count as a GPU: the threaded CPU bake beats them.
//
// The shaders (crease.wgsl, canvas.wgsl) port the CPU code in f32, so a GPU
// texel matches the CPU one up to rounding, and the build cache can mix both.

use std::collections::HashMap;
use std::hash::BuildHasher;
use std::sync::{Mutex, OnceLock};

use bytemuck::{Pod, Zeroable};
use wgpu::util::DeviceExt;

use crate::bake::Texel;
use crate::brush::{Brush, Canvas};
use crate::mesh::Vec3;
use crate::progress;

// Texels per submission. A GPU driver resets a job that runs too long, so big
// textures go up in slices rather than one dispatch.
const SLICE: usize = 1 << 17;
const WORKGROUP: usize = 64;

struct Gpu {
	device: wgpu::Device,
	queue: wgpu::Queue,
	crease: wgpu::ComputePipeline,
	paint: wgpu::ComputePipeline,
	over: wgpu::ComputePipeline,
	// Largest buffer the device binds as storage.
	max_binding: u64,
}

static GPU: OnceLock<Option<Mutex<Gpu>>> = OnceLock::new();

fn gpu() -> Option<&'static Mutex<Gpu>> {
	GPU.get_or_init(|| {
		let gpu = start();
		match &gpu {
			Some((_, name)) => progress::say(&format!("baking on GPU: {name}")),
			None => progress::say("baking on CPU (no GPU)"),
		}
		gpu.map(|(gpu, _)| Mutex::new(gpu))
	})
	.as_ref()
}

fn start() -> Option<(Gpu, String)> {
	if std::env::var("MODELKIT_GPU").is_ok_and(|v| v == "off" || v == "0") {
		return None;
	}
	let instance = wgpu::Instance::new(wgpu::InstanceDescriptor::new_without_display_handle());
	let options = wgpu::RequestAdapterOptions { power_preference: wgpu::PowerPreference::HighPerformance, ..Default::default() };
	let adapter = pollster::block_on(instance.request_adapter(&options)).ok()?;
	let info = adapter.get_info();
	if info.device_type == wgpu::DeviceType::Cpu {
		return None;
	}
	let limits = adapter.limits();
	let descriptor = wgpu::DeviceDescriptor { label: Some("modelkit"), required_limits: limits.clone(), ..Default::default() };
	let (device, queue) = pollster::block_on(adapter.request_device(&descriptor)).ok()?;
	// A shader the driver rejects means a CPU bake, not a crashed build.
	let scope = device.push_error_scope(wgpu::ErrorFilter::Validation);
	let module = |label: &str, source: &'static str| device.create_shader_module(wgpu::ShaderModuleDescriptor { label: Some(label), source: wgpu::ShaderSource::Wgsl(source.into()) });
	let crease_module = module("crease", include_str!("crease.wgsl"));
	let canvas_module = module("canvas", include_str!("canvas.wgsl"));
	let pipeline = |module: &wgpu::ShaderModule, entry: &str| {
		device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
			label: Some(entry),
			layout: None,
			module,
			entry_point: Some(entry),
			compilation_options: Default::default(),
			cache: None,
		})
	};
	let (crease, paint, over) = (pipeline(&crease_module, "main"), pipeline(&canvas_module, "paint_main"), pipeline(&canvas_module, "over_main"));
	if let Some(error) = pollster::block_on(scope.pop()) {
		eprintln!("GPU shaders failed, baking on the CPU: {error}");
		return None;
	}
	let max_binding = u64::from(limits.max_storage_buffer_binding_size).min(limits.max_buffer_size);
	Some((Gpu { device, queue, crease, paint, over, max_binding }, info.name))
}

// --- Uploaded data ----------------------------------------------------------
// Layouts match the structs in the shaders, padded to vec4 alignment.

#[repr(C)]
#[derive(Clone, Copy, Pod, Zeroable)]
struct Params {
	first: u32,
	count: u32,
	mask: u32,
	value: f32,
	// How far a contact shadow reaches from its corner, in studs.
	reach: f32,
	// How much wider the highlight brush is than the shadow brush.
	highlight_width: f32,
	// 1 paints highlights as bold painted strokes instead of dry ones.
	painted: f32,
	// Studs a highlight thins over away from a corner; 0 keeps it even.
	corner_taper: f32,
}

#[repr(C)]
#[derive(Clone, Copy, Pod, Zeroable)]
struct GpuTexel {
	position: [f32; 3],
	_pad0: f32,
	normal: [f32; 3],
	_pad1: f32,
}

#[repr(C)]
#[derive(Clone, Copy, Pod, Zeroable)]
struct GpuSurface {
	a: [f32; 3],
	mine: u32,
	b: [f32; 3],
	_pad0: f32,
	c: [f32; 3],
	_pad1: f32,
	facing: [f32; 3],
	_pad2: f32,
}

#[repr(C)]
#[derive(Clone, Copy, Pod, Zeroable)]
struct GpuStroke {
	start: [f32; 3],
	length: f32,
	along: [f32; 3],
	width: f32,
	across: [f32; 3],
	opacity: f32,
	normal: [f32; 3],
	brush: u32,
	color: [f32; 3],
	seed: u32,
	tail: f32,
	_pad: [f32; 3],
}

#[repr(C)]
#[derive(Clone, Copy, Pod, Zeroable)]
struct Slot {
	key: [i32; 3],
	used: u32,
	start: u32,
	count: u32,
	_pad: [u32; 2],
}

fn f32s(v: Vec3) -> [f32; 3] {
	v.map(|c| c as f32)
}

fn gpu_texels(texels: &[Texel]) -> Vec<GpuTexel> {
	texels.iter().map(|t| GpuTexel { position: f32s(t.position), normal: f32s(t.face_normal), ..Zeroable::zeroed() }).collect()
}

// A grid of index lists as an open-addressed hash table the shaders probe
// (find_slot), plus every list laid end to end. None if a cell key doesn't
// fit in an i32, which only a model thousands of kilometres across reaches.
fn hash_table<S: BuildHasher>(grid: &HashMap<[i64; 3], Vec<usize>, S>) -> Option<(Vec<Slot>, Vec<u32>, u32)> {
	let size = (grid.len() * 2).next_power_of_two().max(2);
	let mask = size - 1;
	let mut slots = vec![Slot::zeroed(); size];
	let mut items = Vec::with_capacity(grid.values().map(Vec::len).sum());
	for (key, list) in grid {
		let key: [i32; 3] = [i32::try_from(key[0]).ok()?, i32::try_from(key[1]).ok()?, i32::try_from(key[2]).ok()?];
		let k = key.map(|c| c as u32);
		let mut at = (k[0].wrapping_mul(73_856_093) ^ k[1].wrapping_mul(19_349_663) ^ k[2].wrapping_mul(83_492_791)) as usize & mask;
		while slots[at].used != 0 {
			at = (at + 1) & mask;
		}
		slots[at] = Slot { key, used: 1, start: items.len() as u32, count: list.len() as u32, _pad: [0; 2] };
		items.extend(list.iter().map(|&i| i as u32));
	}
	Some((slots, items, mask as u32))
}

impl Gpu {
	fn storage<T: Pod>(&self, label: &str, data: &[T]) -> wgpu::Buffer {
		// Storage bindings can't be empty, so an empty list uploads one zeroed
		// element the shaders never read.
		let padding = [T::zeroed()];
		let bytes: &[u8] = bytemuck::cast_slice(if data.is_empty() { &padding[..] } else { data });
		self.device.create_buffer_init(&wgpu::util::BufferInitDescriptor { label: Some(label), contents: bytes, usage: wgpu::BufferUsages::STORAGE })
	}

	// Runs `pipeline` over `count` texels, slice by slice, with bindings 1-4
	// as given and binding 5 the output, `Out` per texel.
	fn run<Out: Pod>(&self, pipeline: &wgpu::ComputePipeline, inputs: [&wgpu::Buffer; 4], count: usize, mask: u32, value: f32, reach: f32, highlight_width: f32, painted: f32, corner_taper: f32) -> Option<Vec<Out>> {
		let size = (count.max(1) * size_of::<Out>()) as u64;
		if size > self.max_binding {
			return None;
		}
		let output = self.device.create_buffer(&wgpu::BufferDescriptor { label: Some("paint"), size, usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_SRC, mapped_at_creation: false });
		let readback = self.device.create_buffer(&wgpu::BufferDescriptor { label: Some("readback"), size, usage: wgpu::BufferUsages::MAP_READ | wgpu::BufferUsages::COPY_DST, mapped_at_creation: false });
		// Any error in the passes sends this mesh back to the CPU bake.
		let scope = self.device.push_error_scope(wgpu::ErrorFilter::Validation);
		let layout = pipeline.get_bind_group_layout(0);
		for first in (0..count).step_by(SLICE) {
			let slice = SLICE.min(count - first);
			let params = Params { first: first as u32, count: slice as u32, mask, value, reach, highlight_width, painted, corner_taper };
			let uniform = self.device.create_buffer_init(&wgpu::util::BufferInitDescriptor { label: Some("params"), contents: bytemuck::bytes_of(&params), usage: wgpu::BufferUsages::UNIFORM });
			let buffers = [&uniform, inputs[0], inputs[1], inputs[2], inputs[3], &output];
			let entries: Vec<wgpu::BindGroupEntry> = buffers.iter().enumerate().map(|(binding, buffer)| wgpu::BindGroupEntry { binding: binding as u32, resource: buffer.as_entire_binding() }).collect();
			let group = self.device.create_bind_group(&wgpu::BindGroupDescriptor { label: None, layout: &layout, entries: &entries });
			let mut encoder = self.device.create_command_encoder(&wgpu::CommandEncoderDescriptor { label: None });
			{
				let mut pass = encoder.begin_compute_pass(&wgpu::ComputePassDescriptor { label: None, timestamp_writes: None });
				pass.set_pipeline(pipeline);
				pass.set_bind_group(0, &group, &[]);
				pass.dispatch_workgroups(slice.div_ceil(WORKGROUP) as u32, 1, 1);
			}
			self.queue.submit([encoder.finish()]);
			self.device.poll(wgpu::PollType::wait_indefinitely()).ok()?;
		}
		let mut encoder = self.device.create_command_encoder(&wgpu::CommandEncoderDescriptor { label: None });
		encoder.copy_buffer_to_buffer(&output, 0, &readback, 0, size);
		self.queue.submit([encoder.finish()]);
		if let Some(error) = pollster::block_on(scope.pop()) {
			eprintln!("GPU bake failed, baking on the CPU: {error:?}");
			return None;
		}
		let (sender, receiver) = std::sync::mpsc::channel();
		readback.map_async(wgpu::MapMode::Read, .., move |result| {
			let _ = sender.send(result);
		});
		self.device.poll(wgpu::PollType::wait_indefinitely()).ok()?;
		receiver.recv().ok()?.ok()?;
		let values = bytemuck::cast_slice::<u8, Out>(&readback.get_mapped_range(..))[..count].to_vec();
		readback.unmap();
		Some(values)
	}

	fn fits(&self, buffers: &[usize]) -> bool {
		buffers.iter().all(|&bytes| bytes as u64 <= self.max_binding)
	}
}

// --- Passes -----------------------------------------------------------------

// bake.rs crease_paint at every texel: (interior, exterior) paint.
// `surfaces` and `grid` are paint_shading's contact surfaces and grid.
pub fn crease<S: BuildHasher>(texels: &[Texel], surfaces: &[([Vec3; 3], Vec3, bool)], grid: &HashMap<[i64; 3], Vec<usize>, S>, min_cos: f64, reach: f64, highlight_width: f64, painted: bool, corner_taper: f64) -> Option<Vec<(f64, f64)>> {
	let gpu = gpu()?.lock().ok()?;
	let (slots, items, mask) = hash_table(grid)?;
	let surfaces: Vec<GpuSurface> = surfaces
		.iter()
		.map(|(t, facing, mine)| GpuSurface { a: f32s(t[0]), b: f32s(t[1]), c: f32s(t[2]), facing: f32s(*facing), mine: u32::from(*mine), ..Zeroable::zeroed() })
		.collect();
	let points = gpu_texels(texels);
	if !gpu.fits(&[size_of_val(&points[..]), size_of_val(&surfaces[..]), size_of_val(&slots[..]), size_of_val(&items[..])]) {
		return None;
	}
	let inputs = [&gpu.storage("texels", &points), &gpu.storage("surfaces", &surfaces), &gpu.storage("slots", &slots), &gpu.storage("items", &items)];
	let paint: Vec<[f32; 2]> = gpu.run(&gpu.crease, inputs, texels.len(), mask, min_cos as f32, reach as f32, highlight_width as f32, f32::from(u8::from(painted)), corner_taper as f32)?;
	Some(paint.into_iter().map(|[inward, outward]| (f64::from(inward), f64::from(outward))).collect())
}

// Canvas::paint (`over` false) or Canvas::over (`over` true) at every texel:
// the linear color, and how much the strokes cover (1 for paint).
pub fn canvas(canvas: &Canvas, texels: &[Texel], over: bool) -> Option<Vec<([f64; 3], f64)>> {
	let gpu = gpu()?.lock().ok()?;
	let (slots, items, mask) = hash_table(canvas.grid())?;
	let strokes: Vec<GpuStroke> = canvas
		.strokes()
		.iter()
		.map(|s| GpuStroke {
			start: f32s(s.start),
			length: s.length as f32,
			along: f32s(s.along),
			width: s.width as f32,
			across: f32s(s.across),
			opacity: s.opacity as f32,
			normal: f32s(s.normal),
			brush: brush_index(s.brush),
			color: f32s(s.color),
			seed: s.seed,
			tail: s.tail as f32,
			_pad: [0.0; 3],
		})
		.collect();
	let points = gpu_texels(texels);
	if !gpu.fits(&[size_of_val(&points[..]), size_of_val(&strokes[..]), size_of_val(&slots[..]), size_of_val(&items[..])]) {
		return None;
	}
	let inputs = [&gpu.storage("texels", &points), &gpu.storage("strokes", &strokes), &gpu.storage("slots", &slots), &gpu.storage("items", &items)];
	let pipeline = if over { &gpu.over } else { &gpu.paint };
	let paint: Vec<[f32; 4]> = gpu.run(pipeline, inputs, texels.len(), mask, canvas.cell_size() as f32, 0.0, 1.0, 0.0, 0.0)?;
	Some(paint.into_iter().map(|[r, g, b, a]| ([r, g, b].map(f64::from), f64::from(a))).collect())
}

// The brush's number in canvas.wgsl, which follows the order of `Brush`.
fn brush_index(brush: Brush) -> u32 {
	match brush {
		Brush::Flat => 0,
		Brush::Round => 1,
		Brush::Liner => 2,
		Brush::Sponge => 3,
		Brush::Dry => 4,
		Brush::Taper => 5,
	}
}
