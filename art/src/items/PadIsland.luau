-- Pad Island: an avenue plaza's floating island, from the shared column generator
-- (shared/ColumnIsland.luau).
local RADIUS = 21
local PEAK = 27
local SEED = 37
-- The avenue plaza (ServerMap.luau): an octagon with a flat side facing
-- each axis, PLAZA studs to a flat side with its kerb.
local PLAZA = 11.5

-- How far a point lies outside the plaza's octagon.
local function wornDistance(x: number, y: number): number
	local angle = math.atan2(y, x)
	local sector = (angle + math.pi / 8) % (math.pi / 4) - math.pi / 8
	return math.sqrt(x * x + y * y) * math.cos(sector) - PLAZA
end

-- include: ColumnIsland
