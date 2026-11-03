--!strict
--[[
	YardLayout

	Where yards sit in the world and where things sit inside a yard. A yard
	is placed by an origin (the centre of its floor's top surface) and a yaw
	(turn around the vertical axis). Offsets inside a yard are in yard
	space: +X right, +Z toward the gate, matching the Yard Layout art
	(48 x 48 studs, gate at the front, crate at the back, two pads a side).

	Placeholder yards stand in a ring around the arena at the map centre,
	gates facing in. Rotation maths is done on Vector3s here, so it's the
	same in Studio and in unit tests.

	Public API:
		YardLayout.SIZE, YardLayout.HEIGHT
		YardLayout.PAD_OFFSETS, CRATE_OFFSET, GATE_OFFSET, SPAWN_OFFSET, MARKER_OFFSET
		YardLayout.ringPlacement(index, count): (origin, yaw)
		YardLayout.toWorld(origin, yaw, offset): Vector3
		YardLayout.toLocal(origin, yaw, point): Vector3
		YardLayout.contains(origin, yaw, point): boolean
]]

local YardLayout = {}

-- The art lays a yard out on a 32-stud plan and builds every piece SCALE
-- times its own size; offsets here are given on that plan and scaled.
local SCALE = 1.5
YardLayout.SIZE = 32 * SCALE
-- How high above the floor still counts as "in the yard" (jumping, ladders).
YardLayout.HEIGHT = 30
-- How far below the floor still counts (standing on the floor puts the
-- character's root a little above it, but allow some slack for slopes).
YardLayout.DEPTH = 5

YardLayout.PAD_OFFSETS = {
	Pad1 = Vector3.new(-9, 0, -2) * SCALE,
	Pad2 = Vector3.new(-9, 0, -10) * SCALE,
	Pad3 = Vector3.new(9, 0, -2) * SCALE,
	Pad4 = Vector3.new(9, 0, -10) * SCALE,
} :: { [string]: Vector3 }
YardLayout.CRATE_OFFSET = Vector3.new(0, 0, -12.95) * SCALE
YardLayout.GATE_OFFSET = Vector3.new(0, 0, 16) * SCALE
-- Spawn height stays 3 studs above the floor whatever the yard's scale.
YardLayout.SPAWN_OFFSET = Vector3.new(0, 3, 8 * SCALE)
YardLayout.MARKER_OFFSET = Vector3.new(6, 0, 17.5) * SCALE

-- Ring of placeholder yards around the arena, floors raised a stud so they
-- sit just above a default baseplate.
local RING_RADIUS = 120
local RING_HEIGHT = 1

local function rotateY(vector: Vector3, yaw: number): Vector3
	local cos, sin = math.cos(yaw), math.sin(yaw)
	return Vector3.new(vector.X * cos + vector.Z * sin, vector.Y, -vector.X * sin + vector.Z * cos)
end

-- Yard `index` of `count`, evenly spaced on a circle, turned so the gate
-- (+Z in yard space) faces the centre.
function YardLayout.ringPlacement(index: number, count: number): (Vector3, number)
	local angle = (index - 1) / count * math.pi * 2
	local origin = Vector3.new(math.sin(angle) * RING_RADIUS, RING_HEIGHT, math.cos(angle) * RING_RADIUS)
	-- Yard +Z must point from the yard toward the centre (flat, ignoring height).
	local yaw = math.atan2(-origin.X, -origin.Z)

	return origin, yaw
end

function YardLayout.toWorld(origin: Vector3, yaw: number, offset: Vector3): Vector3
	return origin + rotateY(offset, yaw)
end

function YardLayout.toLocal(origin: Vector3, yaw: number, point: Vector3): Vector3
	return rotateY(point - origin, -yaw)
end

function YardLayout.contains(origin: Vector3, yaw: number, point: Vector3): boolean
	local localPoint = YardLayout.toLocal(origin, yaw, point)
	local half = YardLayout.SIZE / 2

	return math.abs(localPoint.X) <= half
		and math.abs(localPoint.Z) <= half
		and localPoint.Y >= -YardLayout.DEPTH
		and localPoint.Y <= YardLayout.HEIGHT
end

return YardLayout
