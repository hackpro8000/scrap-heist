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
	pub smooth: bool,
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
		Mesh { positions: Vec::new(), faces: Vec::new(), smooth: true }
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
		let mut vertex_normals = vec![[0.0; 3]; self.positions.len()];
		if self.smooth {
			for (face, &normal) in self.faces.iter().zip(&face_normals) {
				for &vert in &face.verts {
					vertex_normals[vert] = add(vertex_normals[vert], normal);
				}
			}
		}
		let mut triangles = Vec::new();
		for (face, &face_normal) in self.faces.iter().zip(&face_normals) {
			let corner = |k: usize| Corner {
				position: self.positions[face.verts[k]],
				uv: face.uvs.as_ref().map_or([0.0, 0.0], |uvs| uvs[k]),
				normal: if self.smooth { normalize(vertex_normals[face.verts[k]]) } else { face_normal },
			};
			for k in 1..face.verts.len() - 1 {
				triangles.push([corner(0), corner(k), corner(k + 1)]);
			}
		}
		triangles
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
