// Mesh: the shape a model script builds. Vertices are positions in studs
// (Z up, like the old Blender pipeline); faces are polygons of vertex indices
// with optional per-corner UVs. Export and preview triangulate on demand.

use std::collections::HashMap;

pub type Vec3 = [f64; 3];

#[derive(Clone)]
pub struct Face {
	pub verts: Vec<usize>,
	pub uvs: Option<Vec<[f64; 2]>>,
}

pub struct Mesh {
	pub positions: Vec<Vec3>,
	pub faces: Vec<Face>,
	// Faces meeting at less than this many degrees share smoothed normals:
	// 0 is flat shading, 180 smooths everything.
	pub smooth_angle: f64,
}

pub fn sub(a: Vec3, b: Vec3) -> Vec3 {
	[a[0] - b[0], a[1] - b[1], a[2] - b[2]]
}

pub fn add(a: Vec3, b: Vec3) -> Vec3 {
	[a[0] + b[0], a[1] + b[1], a[2] + b[2]]
}

pub fn scale(a: Vec3, s: f64) -> Vec3 {
	[a[0] * s, a[1] * s, a[2] * s]
}

pub fn dot(a: Vec3, b: Vec3) -> f64 {
	a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}

pub fn cross(a: Vec3, b: Vec3) -> Vec3 {
	[a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
}

pub fn normalize(a: Vec3) -> Vec3 {
	let length = dot(a, a).sqrt();
	if length > 1e-12 { scale(a, 1.0 / length) } else { [0.0, 0.0, 1.0] }
}

// One triangle corner after triangulation: where it sits, its UV, its normal.
#[derive(Clone, Copy)]
pub struct Corner {
	pub position: Vec3,
	pub uv: [f64; 2],
	pub normal: Vec3,
}

impl Mesh {
	pub fn new() -> Self {
		Mesh { positions: Vec::new(), faces: Vec::new(), smooth_angle: 180.0 }
	}

	// Merges vertices closer than `distance`, like Blender's merge by distance.
	// Faces that collapse below three distinct corners are dropped.
	pub fn weld(&mut self, distance: f64) {
		let mut remap = vec![0usize; self.positions.len()];
		let mut kept: Vec<Vec3> = Vec::new();
		for (index, &point) in self.positions.iter().enumerate() {
			let found = kept.iter().position(|&other| dot(sub(point, other), sub(point, other)) <= distance * distance);
			remap[index] = match found {
				Some(existing) => existing,
				None => {
					kept.push(point);
					kept.len() - 1
				}
			};
		}
		self.positions = kept;
		let faces = std::mem::take(&mut self.faces);
		for face in faces {
			let mut verts = Vec::new();
			let mut uvs = Vec::new();
			for (corner, &vert) in face.verts.iter().enumerate() {
				let mapped = remap[vert];
				if verts.last() == Some(&mapped) {
					continue;
				}
				verts.push(mapped);
				if let Some(face_uvs) = &face.uvs {
					uvs.push(face_uvs[corner]);
				}
			}
			while verts.len() > 1 && verts.first() == verts.last() {
				verts.pop();
				uvs.pop();
			}
			if verts.len() < 3 {
				continue;
			}
			self.faces.push(Face { verts, uvs: face.uvs.as_ref().map(|_| uvs) });
		}
	}

	pub fn face_normal(&self, face: &Face) -> Vec3 {
		// Newell's method: robust for any planar-ish polygon.
		let mut normal = [0.0; 3];
		for (i, &a) in face.verts.iter().enumerate() {
			let p = self.positions[a];
			let q = self.positions[face.verts[(i + 1) % face.verts.len()]];
			normal[0] += (p[1] - q[1]) * (p[2] + q[2]);
			normal[1] += (p[2] - q[2]) * (p[0] + q[0]);
			normal[2] += (p[0] - q[0]) * (p[1] + q[1]);
		}
		normalize(normal)
	}

	// Triangles as corner triples, fanned from each face's first corner.
	pub fn triangles(&self) -> Vec<[Corner; 3]> {
		let face_normals: Vec<Vec3> = self.faces.iter().map(|face| self.face_normal(face)).collect();
		let mut vertex_faces = vec![Vec::new(); self.positions.len()];
		for (index, face) in self.faces.iter().enumerate() {
			for &vert in &face.verts {
				vertex_faces[vert].push(index);
			}
		}
		let limit = self.smooth_angle.to_radians().cos();
		let mut triangles = Vec::new();
		for (face, &face_normal) in self.faces.iter().zip(&face_normals) {
			// Smooth each corner over the neighbouring faces within the angle.
			let normal = |vert: usize| {
				if self.smooth_angle <= 0.0 {
					return face_normal;
				}
				let mut sum = [0.0; 3];
				for &other in &vertex_faces[vert] {
					let other_normal = face_normals[other];
					if self.smooth_angle >= 180.0 || dot(other_normal, face_normal) >= limit - 1e-9 {
						sum = add(sum, other_normal);
					}
				}
				normalize(sum)
			};
			let corner = |k: usize| Corner {
				position: self.positions[face.verts[k]],
				uv: face.uvs.as_ref().map_or([0.0, 0.0], |uvs| uvs[k]),
				normal: normal(face.verts[k]),
			};
			for k in 1..face.verts.len() - 1 {
				triangles.push([corner(0), corner(k), corner(k + 1)]);
			}
		}
		triangles
	}

	// Gives an open surface thickness, like Blender's solidify: a copy offset
	// along the vertex normals (negative goes inward), facing the other way,
	// with the open edges bridged by a rim. Existing UVs are dropped.
	pub fn solidify(&mut self, thickness: f64) {
		let mut normals = vec![[0.0; 3]; self.positions.len()];
		for face in &self.faces {
			let normal = self.face_normal(face);
			for &vert in &face.verts {
				normals[vert] = add(normals[vert], normal);
			}
		}
		let count = self.positions.len();
		for vert in 0..count {
			let offset = scale(normalize(normals[vert]), thickness);
			self.positions.push(add(self.positions[vert], offset));
		}
		let mut edge_uses: HashMap<(usize, usize), usize> = HashMap::new();
		for face in &self.faces {
			for (i, &a) in face.verts.iter().enumerate() {
				let b = face.verts[(i + 1) % face.verts.len()];
				*edge_uses.entry((a.min(b), a.max(b))).or_insert(0) += 1;
			}
		}
		// Offsetting inward keeps the original as the outside; outward makes
		// the copy the outside. The inside skin is wound the other way.
		let inward = thickness < 0.0;
		let faces = std::mem::take(&mut self.faces);
		for face in &faces {
			let len = face.verts.len();
			for (i, &a) in face.verts.iter().enumerate() {
				let b = face.verts[(i + 1) % len];
				if edge_uses[&(a.min(b), a.max(b))] > 1 {
					continue;
				}
				let rim = if inward { vec![b, a, a + count, b + count] } else { vec![a, b, b + count, a + count] };
				self.faces.push(Face { verts: rim, uvs: None });
			}
		}
		for face in faces {
			let copy: Vec<usize> = face.verts.iter().map(|v| v + count).collect();
			let (outside, mut inside) = if inward { (face.verts, copy) } else { (copy, face.verts) };
			inside.reverse();
			self.faces.push(Face { verts: outside, uvs: None });
			self.faces.push(Face { verts: inside, uvs: None });
		}
	}

	// Corners deduplicated into an indexed vertex list for export.
	pub fn indexed(&self) -> (Vec<Corner>, Vec<u32>) {
		let mut lookup: HashMap<[u64; 8], u32> = HashMap::new();
		let mut corners = Vec::new();
		let mut indices = Vec::new();
		for triangle in self.triangles() {
			for corner in triangle {
				let p = corner.position;
				let n = corner.normal;
				let key = [p[0], p[1], p[2], corner.uv[0], corner.uv[1], n[0], n[1], n[2]].map(|x| (x as f32).to_bits() as u64);
				let index = *lookup.entry(key).or_insert_with(|| {
					corners.push(corner);
					(corners.len() - 1) as u32
				});
				indices.push(index);
			}
		}
		(corners, indices)
	}
}
