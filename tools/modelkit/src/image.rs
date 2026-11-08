// Image: an RGB texture painted by a model script, in sRGB 0-1, with an
// optional alpha channel (0 clear to 1 solid) for see-through parts. Row 0 is
// the bottom so a pixel's (x, y) lines up with UV (u, v), as in Blender.

pub struct Image {
	pub width: usize,
	pub height: usize,
	pub pixels: Vec<[f32; 3]>,
	// How many times coarser than as painted: an eye preview halves far
	// textures (see detail.rs), and each half doubles this.
	pub coarse: f64,
	// Opacity per pixel, or None for a solid image.
	pub alpha: Option<Vec<f32>>,
}

impl Image {
	pub fn new(width: usize, height: usize, color: [f32; 3]) -> Self {
		Image { width, height, pixels: vec![color; width * height], coarse: 1.0, alpha: None }
	}

	fn texel(&self, u: f64, v: f64) -> usize {
		let x = ((u.rem_euclid(1.0) * self.width as f64) as usize).min(self.width - 1);
		let y = ((v.rem_euclid(1.0) * self.height as f64) as usize).min(self.height - 1);
		y * self.width + x
	}

	// Opacity at UV (u, v), nearest texel; 1 for a solid image.
	pub fn sample_alpha(&self, u: f64, v: f64) -> f32 {
		self.alpha.as_ref().map_or(1.0, |alpha| alpha[self.texel(u, v)])
	}

	// Nearest texel at UV (u, v), wrapping like a repeating texture.
	pub fn sample(&self, u: f64, v: f64) -> [f32; 3] {
		self.pixels[self.texel(u, v)]
	}

	// Half size, each texel the average of the 2×2 block it covers; an odd
	// last row or column averages what it has.
	pub fn half(&self) -> Image {
		let width = self.width.div_ceil(2);
		let height = self.height.div_ceil(2);
		let mut pixels = Vec::with_capacity(width * height);
		let mut alpha = self.alpha.as_ref().map(|_| Vec::with_capacity(width * height));
		for y in 0..height {
			for x in 0..width {
				let mut sum = [0.0f32; 3];
				let mut opacity = 0.0;
				let mut count = 0.0;
				for sy in 2 * y..(2 * y + 2).min(self.height) {
					for sx in 2 * x..(2 * x + 2).min(self.width) {
						let pixel = self.pixels[sy * self.width + sx];
						for a in 0..3 {
							sum[a] += pixel[a];
						}
						opacity += self.alpha.as_ref().map_or(1.0, |alpha| alpha[sy * self.width + sx]);
						count += 1.0;
					}
				}
				pixels.push(sum.map(|c| c / count));
				if let Some(alpha) = alpha.as_mut() {
					alpha.push(opacity / count);
				}
			}
		}
		Image { width, height, pixels, coarse: self.coarse * 2.0, alpha }
	}

	// PNG bytes, flipped so the top row comes first as the format expects;
	// RGBA when the image has alpha.
	pub fn encode_png(&self) -> Vec<u8> {
		let byte = |c: f32| (c.clamp(0.0, 1.0) * 255.0 + 0.5) as u8;
		let channels = if self.alpha.is_some() { 4 } else { 3 };
		let mut data = Vec::with_capacity(self.width * self.height * channels);
		for y in (0..self.height).rev() {
			for x in 0..self.width {
				let at = y * self.width + x;
				data.extend(self.pixels[at].map(byte));
				if let Some(alpha) = &self.alpha {
					data.push(byte(alpha[at]));
				}
			}
		}
		if self.alpha.is_some() {
			return encode(self.width, self.height, &data, png::ColorType::Rgba);
		}
		encode_rgb(self.width, self.height, &data)
	}
}

pub fn encode_rgb(width: usize, height: usize, data: &[u8]) -> Vec<u8> {
	encode(width, height, data, png::ColorType::Rgb)
}

// A render: compressed hard, since renders travel back from the build
// machines through a slow tunnel (a flat side view goes from about 2 MB to
// under 100 KB). Textures keep encode's bytes, so their assets don't change.
pub fn encode_render(width: usize, height: usize, data: &[u8]) -> Vec<u8> {
	let mut bytes = Vec::new();
	let mut encoder = png::Encoder::new(&mut bytes, width as u32, height as u32);
	encoder.set_color(png::ColorType::Rgb);
	encoder.set_depth(png::BitDepth::Eight);
	encoder.set_compression(png::Compression::Best);
	encoder.set_adaptive_filter(png::AdaptiveFilterType::Adaptive);
	let mut writer = encoder.write_header().expect("png header");
	writer.write_image_data(data).expect("png data");
	drop(writer);
	bytes
}

fn encode(width: usize, height: usize, data: &[u8], color: png::ColorType) -> Vec<u8> {
	let mut bytes = Vec::new();
	let mut encoder = png::Encoder::new(&mut bytes, width as u32, height as u32);
	encoder.set_color(color);
	encoder.set_depth(png::BitDepth::Eight);
	let mut writer = encoder.write_header().expect("png header");
	writer.write_image_data(data).expect("png data");
	drop(writer);
	bytes
}
