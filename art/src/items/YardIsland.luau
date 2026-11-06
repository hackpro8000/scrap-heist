-- Yard Island: the floating island a player's yard stands on, from the
-- shared column generator (shared/ColumnIsland.luau).
local RADIUS = 51.7
local PEAK = 65
local SEED = 11
-- The yard (YardLayout.luau) is a plot YARD_HALF_WIDTH by YARD_HALF_DEPTH
-- studs either side of the middle, with its gate toward -y and a track
-- TRACK_HALF studs either side of the middle running from the gate to the
-- rim.
local YARD_HALF_WIDTH, YARD_HALF_DEPTH = 48, 56
local TRACK_HALF = 4.5
-- The rim is a rounded rectangle that leaves at least 6 studs of grass
-- outside the fence along each side and 10 at the front and back, once the
-- rim's wobble is taken off. The sides are kept narrow so neighbouring yard
-- islands stand too far apart to jump between.
local RIM_WOBBLE = 0.05
local HALF_WIDTH, HALF_DEPTH = 54, 66
local function rimShape(angle: number): number
	local c, s = math.abs(math.cos(angle)) / HALF_WIDTH, math.abs(math.sin(angle)) / HALF_DEPTH
	return (c ^ 8 + s ^ 8) ^ (-1 / 8) / HALF_WIDTH
end

-- The plot's ground buries the turf under it.
local COVER_INSET = 2
-- How far a point lies outside the plot (with rounded corners) or the
-- gate's track.
local function wornDistance(x: number, y: number): number
	local dx, dy = math.abs(x) - YARD_HALF_WIDTH, math.abs(y) - YARD_HALF_DEPTH
	local outside = if dx > 0 and dy > 0 then math.sqrt(dx * dx + dy * dy) else math.max(dx, dy)
	if y < 0 then
		outside = math.min(outside, math.max(math.abs(x) - TRACK_HALF, 0))
	end
	return outside
end

-- include: ColumnIsland
