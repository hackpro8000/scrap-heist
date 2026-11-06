--!strict
--[[
	YardGrid

	Pure maths for a yard's plot: turning grid cells (Config/Yard) into
	studs and back, and yard space into the world and back. No instances,
	so the server, the client's build mode and the tests all share it.

	Yard space: the origin is the middle of the plot's floor, +X runs
	across the plot and +Z points at the gate. A yard's `origin` is where
	that stands in the world and `yaw` is how far it is turned about Y.

	A thing in a yard (YardGrid.Object) covers a rectangle of cells from its
	corner cell (x, z); `turn` counts quarter turns, and an odd turn swaps
	its width and depth.

	Public API:
		YardGrid.footprint(kind, turn): (width, depth)        -- in cells
		YardGrid.centre(object): Vector3                       -- yard space, on the floor
		YardGrid.cellAt(localPoint): (x, z)                    -- the cell under a point
		YardGrid.parcelOf(x, z): number
		YardGrid.toWorld(origin, yaw, offset): Vector3
		YardGrid.toLocal(origin, yaw, point): Vector3
		YardGrid.contains(origin, yaw, point): boolean
		YardGrid.GATE_OFFSET, YardGrid.SPAWN_OFFSET: Vector3   -- yard space
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Yard = require(ReplicatedStorage.Shared.Config.Yard)

local YardGrid = {}

export type Object = {
	id: number,
	kind: string,
	-- Pads only: the family whose junkrots earn more on it.
	family: string?,
	x: number,
	z: number,
	turn: number,
	-- Pads only: the junkrot standing on it.
	junkrot: { id: string, stars: number, limited: boolean? }?,
	-- Bays only: the capsule hatching in it, and seconds of whacking done.
	capsule: { junkrot: string, limited: boolean?, progress: number }?,
}

YardGrid.WIDTH = Yard.COLUMNS * Yard.CELL
YardGrid.DEPTH = Yard.ROWS * Yard.CELL

-- The middle of the gate, and where a character lands in the yard: on
-- the doorstep, 3 studs up.
YardGrid.GATE_OFFSET = Vector3.new(0, 0, YardGrid.DEPTH / 2)
YardGrid.SPAWN_OFFSET = Vector3.new(0, 3, YardGrid.DEPTH / 2 - 4)

function YardGrid.footprint(kind: string, turn: number): (number, number)
	local size = Yard.FOOTPRINTS[kind]
	assert(size, `YardGrid: nothing is called {kind}`)
	if turn % 2 == 1 then
		return size.depth, size.width
	end

	return size.width, size.depth
end

function YardGrid.centre(object: { kind: string, x: number, z: number, turn: number }): Vector3
	local width, depth = YardGrid.footprint(object.kind, object.turn)
	return Vector3.new(
		(object.x + width / 2 - Yard.COLUMNS / 2) * Yard.CELL,
		0,
		(object.z + depth / 2 - Yard.ROWS / 2) * Yard.CELL
	)
end

function YardGrid.cellAt(localPoint: Vector3): (number, number)
	return math.floor(localPoint.X / Yard.CELL + Yard.COLUMNS / 2), math.floor(localPoint.Z / Yard.CELL + Yard.ROWS / 2)
end

function YardGrid.parcelOf(x: number, z: number): number
	local column = math.floor(x / Yard.PARCEL_WIDTH)
	local row = math.floor(z / Yard.PARCEL_DEPTH)
	return row * Yard.PARCEL_COLUMNS + column + 1
end

local function rotateY(vector: Vector3, yaw: number): Vector3
	local cos, sin = math.cos(yaw), math.sin(yaw)
	return Vector3.new(vector.X * cos + vector.Z * sin, vector.Y, -vector.X * sin + vector.Z * cos)
end

function YardGrid.toWorld(origin: Vector3, yaw: number, offset: Vector3): Vector3
	return origin + rotateY(offset, yaw)
end

function YardGrid.toLocal(origin: Vector3, yaw: number, point: Vector3): Vector3
	return rotateY(point - origin, -yaw)
end

function YardGrid.contains(origin: Vector3, yaw: number, point: Vector3): boolean
	local localPoint = YardGrid.toLocal(origin, yaw, point)

	return math.abs(localPoint.X) <= YardGrid.WIDTH / 2
		and math.abs(localPoint.Z) <= YardGrid.DEPTH / 2
		and localPoint.Y >= -Yard.DEPTH
		and localPoint.Y <= Yard.HEIGHT
end

return YardGrid
