-- Yard Island: a floating yard island, from the shared rock-wall
-- generator (shared/RockIsland.luau).
local RADIUS = 36

-- The island's wobbly outline, as a radius scale per angle.
local function outlineScale(angle: number): number
	return 1 + 0.07 * math.sin(3 * angle + 0.6) + 0.05 * math.sin(5 * angle + 2.1) + 0.03 * math.sin(9 * angle)
end

-- include: IslandPaint
-- include: RockIsland
