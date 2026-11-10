-- Main Island: the one floating island the island server map stands on
-- (layouts/IslandPreview.luau), from the shared column generator
-- (shared/ColumnIsland.luau).
local RADIUS = 278
local PEAK = 192
local SEED = 41
-- What stands on it (IslandPreview.luau): the hub's paving and ring road out
-- to HUB_ROAD from the middle, and eight yard plots YARD_HALF_WIDTH by
-- YARD_HALF_DEPTH on a ring at YARD_RADIUS, yard i at (i - 0.5) * 45
-- degrees with its gate toward the middle. A kerbed track runs from the gate
-- to the hub, so the turf wear (negative TRACK_HALF) stays inside its kerbs.
local HUB_ROAD = 101
local YARD_RADIUS = 210
local YARD_HALF_WIDTH, YARD_HALF_DEPTH = 48, 56
local TRACK_HALF = -1.5

-- How far a point lies outside the hub, the nearest plot (with rounded
-- corners) or its track.
local function wornDistance(x: number, y: number): number
	local r = math.sqrt(x * x + y * y)
	local outside = r - HUB_ROAD
	local yard = math.rad((math.floor(math.deg(math.atan2(y, x)) % 360 / 45) + 0.5) * 45)
	local c, s = math.cos(yard), math.sin(yard)
	-- In the yard's frame: across its width, and out from the hub.
	local across = (x * -s + y * c)
	local out = (x * c + y * s) - YARD_RADIUS
	local dx, dy = math.abs(across) - YARD_HALF_WIDTH, math.abs(out) - YARD_HALF_DEPTH
	outside = math.min(outside, if dx > 0 and dy > 0 then math.sqrt(dx * dx + dy * dy) else math.max(dx, dy))
	if out < 0 and r > HUB_ROAD then
		outside = math.min(outside, math.max(math.abs(across) - TRACK_HALF, 0))
	end
	return outside
end

-- The plots and the paving bury the turf under them.
local COVER_INSET = 2
local RIM_WOBBLE = 0.04
local function rimShape(_angle: number): number
	return 1
end

-- Soft turf patches and wear, for a top this big and open.
SOFT_GRASS = true

-- include: ColumnIsland
