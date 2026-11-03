-- Yard Island: the floating island a player's yard stands on, from the
-- shared column generator (shared/ColumnIsland.luau).
local RADIUS = 42
local PEAK = 53
local SEED = 11
-- The yard (YardLayout.luau) is a YARD_HALF-stud half square on the top,
-- turned YARD_TURN degrees against the island so the island's lobes sit
-- under the fence corners, with its gate toward -y and a track TRACK_HALF
-- studs either side of the middle running from the gate to the rim.
local YARD_HALF = 24
local YARD_TURN = 305
local TRACK_HALF = 4

-- How far a point lies outside the yard's square (with rounded corners) or
-- the gate's track, in the yard's own frame.
local function wornDistance(x: number, y: number): number
	local c, s = math.cos(math.rad(YARD_TURN)), math.sin(math.rad(YARD_TURN))
	local u, v = x * c - y * s, x * s + y * c
	local du, dv = math.abs(u) - YARD_HALF, math.abs(v) - YARD_HALF
	local outside = if du > 0 and dv > 0 then math.sqrt(du * du + dv * dv) else math.max(du, dv)
	if v < 0 then
		outside = math.min(outside, math.max(math.abs(u) - TRACK_HALF, 0))
	end
	return outside
end

-- include: ColumnIsland
