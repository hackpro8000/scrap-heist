-- Market Island: the market plaza's octagonal floating island, from the
-- shared rock-column generator (shared/RockIsland.luau).
local RADIUS = 38

-- The island's wobbly outline, as a radius scale per angle.
local function outlineScale(angle: number): number
	-- An octagon, faces at 0 and 45 degrees, its corners softened, with a
	-- gentle wobble.
	local sector = (angle + math.pi / 8) % (math.pi / 4) - math.pi / 8
	local wobble = 0.07 * math.sin(3 * angle + 0.6) + 0.05 * math.sin(5 * angle + 2.1) + 0.03 * math.sin(9 * angle)
	return 1 / math.cos(sector * 0.85) + 0.2 * wobble
end

-- include: RockIsland
