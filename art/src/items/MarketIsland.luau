-- Market Island: the market plaza's floating island, from the shared column generator
-- (shared/ColumnIsland.luau).
local RADIUS = 50
local PEAK = 63
local SEED = 23
-- The market plaza (ServerMap.luau): an octagon with a flat side facing
-- each axis, PLAZA studs to a flat side with its kerb.
local PLAZA = 30.5

-- How far a point lies outside the plaza's octagon.
local function wornDistance(x: number, y: number): number
	local angle = math.atan2(y, x)
	local sector = (angle + math.pi / 8) % (math.pi / 4) - math.pi / 8
	return math.sqrt(x * x + y * y) * math.cos(sector) - PLAZA
end

-- include: ColumnIsland
