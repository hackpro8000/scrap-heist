// Preview renderer: a small software rasterizer, so a screenshot needs no GPU,
// desktop or Blender. Orthographic 3/4 view like the old previews, the camera
// can orbit the model (turntables), and light is soft since the textures
// carry their own painted shading.

use crate::mesh::{cross, dot, normalize, scale, sub, Vec3};
use crate::anim::Pose;
use crate::Part;

const BACKGROUND: [f32; 3] = [0.36, 0.38, 0.42];
const SUPERSAMPLE: usize = 2;
// How much of an emissive surface's glow spills around it in previews.
const BLOOM: f32 = 2.5;

pub struct View {
	pub size: usize,
	// Camera orbit around Z, in radians; 0 is the classic 3/4 view.
	pub spin: f64,
	// Close-up: frame a ball of this radius around this point instead of the
	// whole model. The camera is orthographic, so nothing is clipped; it sees
	// everything in frame as a player would from above.
	pub focus: Option<(Vec3, f64)>,
}

pub fn render(parts: &[&Part], view: &View) -> Vec<u8> {
	render_posed(parts, &[], view)
}

// Renders with each part moved by its bone's skinning transform from `skin`.
pub fn render_posed(parts: &[&Part], skin: &[Pose], view: &View) -> Vec<u8> {
	let triangles: Vec<_> = parts
		.iter()
		.map(|part| {
			let mut list = part.mesh.borrow().triangles();
			if let Some(pose) = part.bone.and_then(|b| skin.get(b)) {
				for corner in list.iter_mut().flatten() {
					corner.position = pose.apply(corner.position);
					corner.normal = pose.turn(corner.normal);
				}
			}
			(list, part)
		})
		.collect();

	let mut low = [f64::MAX; 3];
	let mut high = [f64::MIN; 3];
	for (list, _) in &triangles {
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
	let toward = [cos + sin, sin - cos, 0.8];
	let forward = normalize(scale(toward, -1.0));
	let right = normalize(cross(forward, [0.0, 0.0, 1.0]));
	let up = cross(right, forward);
	let light = normalize([toward[0] * 0.3 - right[0], toward[1] * 0.3 - right[1], 1.5]);
	let width = extent * 2.2 / 1.4;

	let size = view.size * SUPERSAMPLE;
	let mut color = vec![BACKGROUND; size * size];
	let mut depth = vec![f64::MAX; size * size];
	let mut glow = vec![[0.0f32; 3]; size * size];
	let to_screen = |p: Vec3| -> [f64; 3] {
		let d = sub(p, center);
		[
			(dot(d, right) / width + 0.5) * size as f64,
			(0.5 - dot(d, up) / width) * size as f64,
			dot(d, forward),
		]
	};

	for (list, part) in &triangles {
		let image = part.image.borrow();
		for triangle in list {
			let s = triangle.map(|corner| to_screen(corner.position));
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
					let z = w0 * s[0][2] + w1 * s[1][2] + w2 * s[2][2];
					let at = y * size + x;
					if z >= depth[at] {
						continue;
					}
					depth[at] = z;
					let blend = |f: &dyn Fn(usize) -> f64| w0 * f(0) + w1 * f(1) + w2 * f(2);
					let u = blend(&|k| triangle[k].uv[0]);
					let v = blend(&|k| triangle[k].uv[1]);
					let mut normal = normalize([0, 1, 2].map(|a| blend(&|k| triangle[k].normal[a])));
					// Back faces seen through holes still light as if facing us.
					if dot(normal, forward) > 0.0 {
						normal = scale(normal, -1.0);
					}
					let shade = (0.72 + 0.38 * dot(normal, light).max(0.0)) as f32;
					// Emission adds to the lighting before the albedo, as
					// SurfaceAppearance does, and spills into a bloom.
					let albedo = image.sample(u, v);
					color[at] = albedo.map(|c| c * (shade + part.emissive));
					glow[at] = albedo.map(|c| c * part.emissive);
				}
			}
		}
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
	data
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
