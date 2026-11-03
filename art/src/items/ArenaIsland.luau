-- Arena Island: the arena's octagonal floating island, from the shared
-- rock generator (shared/RockIsland.luau) with the yard islands' rocks. The
-- top carries the Server Map's ring road and
-- arena: rim at z = 0.7, sinking into the arena bowl inside the road.
-- Sized so the rim stands just outside the ring road, whose outer edge is 58
-- studs out on a flat side.
local RADIUS = 72
-- The yard islands' rock size (4.7 times the base), so the big arena wall
-- shows many rocks rather than a few broad panels.
local ROCK_SCALE = 4.7
-- Four times the base bulge, a little short of the yards' (which scale it
-- with their rocks), so the rocks stand clearly proud of the big body.
local ROCK_BULGE = 4

-- The Server Map's octagon: a flat side facing each spoke (1 there), the
-- corners between them, so the ring road and arena on top share the outline.
local function octagon(angle: number): number
	local sector = ((angle + math.pi / 8) % (math.pi / 4)) - math.pi / 8
	return 1 / math.cos(sector)
end

-- The island's outline, as a radius scale per angle: the octagon with only
-- a slight wobble, so the rim keeps clear of the ring road all the way round.
local function outlineScale(angle: number): number
	return octagon(angle) + 0.012 * math.sin(3 * angle + 0.6) + 0.008 * math.sin(5 * angle + 2.1)
end

-- The top, matching the Server Map's arena (its heightAt and the ring road
-- laid over it), in octagon radii: flat at the rim, sunk a little under the
-- road so the two never z-fight, then a straight bank down to the fight
-- floor. The bowl is the deck height (2) plus the arena's depth (3.5) deep.
local CAP_TOP = 0.7
local ARENA_FLOOR, ROAD_INNER, ROAD_OUTER = 36, 50, 58
local BOWL_DEPTH, ROAD_SINK = 5.5, 0.15
local function bowlAt(radius: number): number
	if radius > ROAD_INNER and radius < ROAD_OUTER then
		return CAP_TOP - ROAD_SINK
	end
	return CAP_TOP - BOWL_DEPTH * (1 - math.clamp((radius - ARENA_FLOOR) / (ROAD_INNER - ARENA_FLOOR), 0, 1))
end
-- Rings of the top, from just inside the rim to the centre: either side of
-- each road edge, every 2 studs down the bank, then wider across the floor.
local islandTop = {
	radii = { ROAD_OUTER + 0.4, ROAD_OUTER - 0.1, ROAD_INNER + 0.2, ROAD_INNER - 0.2, 48, 46, 44, 42, 40, 38, ARENA_FLOOR, 30, 24, 18, 12, 6 },
	height = bowlAt,
	octagon = octagon,
}

-- include: IslandPaint
-- include: RockIsland
