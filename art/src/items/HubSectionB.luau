-- Hub Section B: the middle stretch of the Scrap Line's hub, a rounded slab of
-- floating island from the shared column generator (shared/ColumnIsland.luau).
-- The hub is five of these in a row along x, overlapping at their ends.
local RADIUS = 56
local PEAK = 64
local SEED = 29
-- The rim is a rounded rectangle: at least HALF_LENGTH along the Line (x) and
-- HALF_WIDTH across it once the rim's wobble is taken off.
local RIM_WOBBLE = 0.05
local HALF_LENGTH, HALF_WIDTH = 58.5, 64.5
local function rimShape(angle: number): number
	local c, s = math.abs(math.cos(angle)) / HALF_LENGTH, math.abs(math.sin(angle)) / HALF_WIDTH
	return (c ^ 8 + s ^ 8) ^ (-1 / 8) / HALF_LENGTH
end
-- What stands on it (ServerMap.luau): the Line's paved deck, DECK_HALF either
-- side of the middle, running the section's whole length.
local DECK_HALF = 56.5
-- The deck buries the turf under it.
local COVER_INSET = 2
-- How far a point lies outside the deck.
local function wornDistance(x: number, y: number): number
	return math.abs(y) - DECK_HALF
end

-- include: ColumnIsland
