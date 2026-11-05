// Animation clips: keyframed bone rotations (Euler degrees, applied X then Y
// then Z) and offsets from the bone's rest head, both in model space. Keys
// ease along a curve, so a spin is just a big angle; export resamples every
// frame, since a glTF quaternion can't turn past 180 degrees in one step.

use crate::mesh::{add, sub, Vec3};
use crate::Bone;

pub const FPS: f64 = 30.0;

pub struct Key {
	pub time: f64,
	pub rotation: Vec3,
	pub offset: Vec3,
}

pub struct Clip {
	pub name: String,
	pub length: f64,
	// One key list per bone that moves, sorted by time.
	pub tracks: Vec<(usize, Vec<Key>)>,
}

// A rigid transform: rotation matrix (rows) then translation.
#[derive(Clone, Copy)]
pub struct Pose {
	pub rotation: [Vec3; 3],
	pub translation: Vec3,
}

impl Pose {
	pub const IDENTITY: Pose = Pose { rotation: [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]], translation: [0.0; 3] };

	pub fn turn(&self, v: Vec3) -> Vec3 {
		self.rotation.map(|row| row[0] * v[0] + row[1] * v[1] + row[2] * v[2])
	}

	pub fn apply(&self, p: Vec3) -> Vec3 {
		add(self.turn(p), self.translation)
	}

	fn then(&self, inner: &Pose) -> Pose {
		let columns = [0, 1, 2].map(|c| self.turn([inner.rotation[0][c], inner.rotation[1][c], inner.rotation[2][c]]));
		Pose { rotation: [0, 1, 2].map(|r| columns.map(|c| c[r])), translation: self.apply(inner.translation) }
	}
}

pub fn euler(degrees: Vec3) -> [Vec3; 3] {
	let [(sx, cx), (sy, cy), (sz, cz)] = degrees.map(|d| d.to_radians().sin_cos());
	// Rz * Ry * Rx
	[
		[cz * cy, cz * sy * sx - sz * cx, cz * sy * cx + sz * sx],
		[sz * cy, sz * sy * sx + cz * cx, sz * sy * cx - cz * sx],
		[-sy, cy * sx, cy * cx],
	]
}

// Quaternion (x, y, z, w) of a rotation matrix.
pub fn quaternion(m: &[Vec3; 3]) -> [f64; 4] {
	let trace = m[0][0] + m[1][1] + m[2][2];
	if trace > 0.0 {
		let s = (trace + 1.0).sqrt() * 2.0;
		return [(m[2][1] - m[1][2]) / s, (m[0][2] - m[2][0]) / s, (m[1][0] - m[0][1]) / s, s / 4.0];
	}
	if m[0][0] > m[1][1] && m[0][0] > m[2][2] {
		let s = (1.0 + m[0][0] - m[1][1] - m[2][2]).sqrt() * 2.0;
		return [s / 4.0, (m[0][1] + m[1][0]) / s, (m[0][2] + m[2][0]) / s, (m[2][1] - m[1][2]) / s];
	}
	if m[1][1] > m[2][2] {
		let s = (1.0 + m[1][1] - m[0][0] - m[2][2]).sqrt() * 2.0;
		return [(m[0][1] + m[1][0]) / s, s / 4.0, (m[1][2] + m[2][1]) / s, (m[0][2] - m[2][0]) / s];
	}
	let s = (1.0 + m[2][2] - m[0][0] - m[1][1]).sqrt() * 2.0;
	[(m[0][2] + m[2][0]) / s, (m[1][2] + m[2][1]) / s, s / 4.0, (m[1][0] - m[0][1]) / s]
}

impl Clip {
	pub fn frames(&self) -> usize {
		(self.length * FPS).round() as usize + 1
	}

	// A bone's (rotation degrees, offset) at `time`. Keys join with a
	// Catmull-Rom curve, so motion eases through them instead of turning
	// sharp corners. Clips loop, so the curve wraps round the ends, carrying
	// on any change from first key to last: a spin keeps its speed.
	pub fn sample(&self, bone: usize, time: f64) -> (Vec3, Vec3) {
		let Some((_, keys)) = self.tracks.iter().find(|(b, _)| *b == bone) else {
			return ([0.0; 3], [0.0; 3]);
		};
		let n = keys.len();
		let after = keys.iter().position(|k| k.time > time).unwrap_or(n);
		if after == 0 {
			return (keys[0].rotation, keys[0].offset);
		}
		if after == n {
			return (keys[n - 1].rotation, keys[n - 1].offset);
		}
		let (first, last) = (&keys[0], &keys[n - 1]);
		let shift = |k: &Key, sign: f64| {
			let by = |a: Vec3, b: Vec3, v: Vec3| [0, 1, 2].map(|i| v[i] + sign * (b[i] - a[i]));
			(k.time + sign * self.length, by(first.rotation, last.rotation, k.rotation), by(first.offset, last.offset, k.offset))
		};
		let point = |i: isize| -> (f64, Vec3, Vec3) {
			if i < 0 {
				return shift(&keys[n - 2], -1.0);
			}
			if i as usize >= n {
				return shift(&keys[1], 1.0);
			}
			let k = &keys[i as usize];
			(k.time, k.rotation, k.offset)
		};
		let i = after as isize - 1;
		let [before, a, b, beyond] = [i - 1, i, i + 1, i + 2].map(point);
		let h = b.0 - a.0;
		let u = (time - a.0) / h;
		let (u2, u3) = (u * u, u * u * u);
		let weights = [2.0 * u3 - 3.0 * u2 + 1.0, u3 - 2.0 * u2 + u, -2.0 * u3 + 3.0 * u2, u3 - u2];
		let curve = |p0: Vec3, p1: Vec3, p2: Vec3, p3: Vec3| {
			[0, 1, 2].map(|c| {
				let m1 = (p2[c] - p0[c]) / (b.0 - before.0) * h;
				let m2 = (p3[c] - p1[c]) / (beyond.0 - a.0) * h;
				weights[0] * p1[c] + weights[1] * m1 + weights[2] * p2[c] + weights[3] * m2
			})
		};
		(curve(before.1, a.1, b.1, beyond.1), curve(before.2, a.2, b.2, beyond.2))
	}

	// Every bone's local transform (relative to its parent) at `time`.
	pub fn local(&self, bones: &[Bone], time: f64) -> Vec<Pose> {
		bones
			.iter()
			.enumerate()
			.map(|(index, bone)| {
				let (rotation, offset) = self.sample(index, time);
				let parent_head = bone.parent.map_or([0.0; 3], |p| bones[p].head);
				Pose { rotation: euler(rotation), translation: add(sub(bone.head, parent_head), offset) }
			})
			.collect()
	}

	// Every bone's skinning transform at `time`: rest-pose model space to
	// posed model space. Parents always come before their children.
	pub fn skin(&self, bones: &[Bone], time: f64) -> Vec<Pose> {
		let local = self.local(bones, time);
		let mut world: Vec<Pose> = Vec::with_capacity(bones.len());
		for (index, bone) in bones.iter().enumerate() {
			let parent = bone.parent.map_or(Pose::IDENTITY, |p| world[p]);
			world.push(parent.then(&local[index]));
		}
		world
			.iter()
			.zip(bones)
			.map(|(pose, bone)| Pose { rotation: pose.rotation, translation: sub(pose.translation, pose.turn(bone.head)) })
			.collect()
	}
}

// Trims a sample to 4 decimals without trailing zeros, so the module stays
// small and diffs read cleanly.
fn number(value: f64) -> String {
	let text = format!("{value:.4}");
	let text = text.trim_end_matches('0').trim_end_matches('.');
	if text == "-0" { "0".to_string() } else { text.to_string() }
}

// The clips as a Luau module for the game to play without uploading
// Animation assets: every frame of each moving bone's Bone.Transform (the
// pose relative to the bone's rest offset, Y up like the GLB), as x, y, z,
// qx, qy, qz, qw runs. Bones are named <Name>Bone, as in the GLB.
pub fn write_luau(model: &str, bones: &[Bone], clips: &[Clip]) -> String {
	let to_y_up = |p: Vec3| [p[0], p[2], -p[1]];
	let mut out = format!(
		"--!strict\n-- Generated by modelkit from {model}'s model.luau; rebuild the model rather than\n-- editing this. Each track is one bone's Bone.Transform per frame at `fps`, as\n-- x, y, z, qx, qy, qz, qw runs.\n\nreturn {{\n\tfps = {},\n\tclips = {{\n",
		FPS
	);
	for clip in clips {
		out.push_str(&format!("\t\t{} = {{\n\t\t\tlength = {},\n\t\t\ttracks = {{\n", clip.name, number(clip.length)));
		let poses: Vec<Vec<Pose>> = (0..clip.frames()).map(|f| clip.local(bones, f as f64 / FPS)).collect();
		for &(bone, _) in &clip.tracks {
			let parent_head = bones[bone].parent.map_or([0.0; 3], |p| bones[p].head);
			let rest = to_y_up(sub(bones[bone].head, parent_head));
			out.push_str(&format!("\t\t\t\t{}Bone = {{\n", bones[bone].name));
			let mut previous = [0.0, 0.0, 0.0, 1.0];
			for pose in &poses {
				let t = to_y_up(pose[bone].translation);
				let q = quaternion(&pose[bone].rotation);
				let mut q = [q[0], q[2], -q[1], q[3]];
				// Stay on the near side so frames blend the short way.
				if q.iter().zip(previous).map(|(a, b)| a * b).sum::<f64>() < 0.0 {
					q = q.map(|c| -c);
				}
				previous = q;
				let run: Vec<String> = [t[0] - rest[0], t[1] - rest[1], t[2] - rest[2], q[0], q[1], q[2], q[3]].iter().map(|&v| number(v)).collect();
				out.push_str(&format!("\t\t\t\t\t{},\n", run.join(", ")));
			}
			out.push_str("\t\t\t\t},\n");
		}
		out.push_str("\t\t\t},\n\t\t},\n");
	}
	out.push_str("\t},\n}\n");
	out
}
