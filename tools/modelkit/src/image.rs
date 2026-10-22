// Image: an RGB texture painted by a model script, in sRGB 0-1. Row 0 is the
// bottom so a pixel's (x, y) lines up with UV (u, v), as in Blender.

pub struct Image {
	pub width: usize,
	pub height: usize,
	pub pixels: Vec<[f32; 3]>,
}

impl Image {
	pub fn new(width: usize, height: usize, color: [f32; 3]) -> Self {
		Image { width, height, pixels: vec![color; width * height] }
	}

	// Nearest texel at UV (u, v), wrapping like a repeating texture.
	pub fn sample(&self, u: f64, v: f64) -> [f32; 3] {
		let x = ((u.rem_euclid(1.0) * self.width as f64) as usize).min(self.width - 1);
		let y = ((v.rem_euclid(1.0) * self.height as f64) as usize).min(self.height - 1);
		self.pixels[y * self.width + x]
	}

	// PNG bytes, flipped so the top row comes first as the format expects.
	pub fn encode_png(&self) -> Vec<u8> {
		let mut data = Vec::with_capacity(self.width * self.height * 3);
		for y in (0..self.height).rev() {
			for pixel in &self.pixels[y * self.width..(y + 1) * self.width] {
				data.extend(pixel.map(|c| (c.clamp(0.0, 1.0) * 255.0 + 0.5) as u8));
			}
		}
		encode_rgb(self.width, self.height, &data)
	}
}

pub fn encode_rgb(width: usize, height: usize, data: &[u8]) -> Vec<u8> {
	let mut bytes = Vec::new();
	let mut encoder = png::Encoder::new(&mut bytes, width as u32, height as u32);
	encoder.set_color(png::ColorType::Rgb);
	encoder.set_depth(png::BitDepth::Eight);
	let mut writer = encoder.write_header().expect("png header");
	writer.write_image_data(data).expect("png data");
	drop(writer);
	bytes
}
