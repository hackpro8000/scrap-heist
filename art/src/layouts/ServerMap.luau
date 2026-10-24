-- uses: ShippingContainer CarStack CrushedCar Barrels TyreStack JunkWall Dumpster Pallets StreetlightBroken TrafficCones GroundTile MachinePad YardFence YardFenceHalf YardGate PlotMarker StorageCrate YardPath YardPathStub
-- Server Map: one server's whole map, centered on the origin, built as
-- floating islands. The arena island sits in the middle with a ring road
-- around its bowl; eight yard islands float a tier higher in a ring with their gates
-- facing it, each joined to the road by a steel bridge climbing to it. The arena is the storm fight
-- ground. The ring road is a deck raised on pillars over the bowl's rim, and
-- on the east side a market terrace sits under it, where new players spawn.
-- Each plot slab carries the Yard Layout template, placed piece by piece the
-- same way YardLayout.luau places it, so the map shows every yard set up.
-- Labels: ArenaIsland, Road, Market, Arena, ArenaEdge, Ramps, RampMouths, Spawn, Beacon, Island1-Island8, Plot1-Plot8, Yard1_<piece>-Yard8_<piece>, Spoke1-Spoke8, Bridge1-Bridge8,
-- Cover1-Cover8, Hatch1-Hatch4, Light1-Light4 and Cones1-Cones8.
-- Yard crates show empty, as in the Yard Layout template.
skipPart = function(name)
	return name:match("^Fill_") ~= nil
end

-- Every map part is textured at one density so nothing reads sharper or
-- blurrier than its neighbours. Props keep their own texture sizes.
useTexelDensity(16)

local YARD_RADIUS = 110
local ROAD_INNER, ROAD_OUTER = 50, 58
local ARENA_FLOOR, ARENA_DEPTH = 36, 3.5
-- Width of the hazard stripes inlaid round the floor edge and up each ramp.
local HAZARD_WIDTH = 1.8
local ARENA_ISLAND, YARD_ISLAND = 61, 26
-- The ring road runs on a raised deck; the market sits under it on the east.
local DECK, MARKET = 12, 4
-- The yards float a tier above the deck.
local YARD_TIER = 18
local MARKET_FROM, MARKET_TO = -60, 60

local GROUND = { 0.3, 0.27, 0.22 }
local ROAD = { 0.42, 0.41, 0.4 }
local CONCRETE = { 0.55, 0.54, 0.5 }
local MARK = { 0.85, 0.65, 0.15 }
local PLOT = { 0.36, 0.33, 0.28 }
local ROCK = { 0.42, 0.37, 0.31 }

-- Places one flat piece built here rather than from a model.
local function slab(label: string, build: () -> (), x: number, y: number, turn: number?)
	placeSlab(label, build, x, y, turn, function()
		finishParts()
		table.clear(parts)
	end)
end

-- Half width of the gap a ramp lane leaves through the market terrace.
local RAMP_HALF_MARKET = 5.4

local function polar(radius: number, degrees: number): (number, number)
	local angle = math.rad(degrees)
	return math.cos(angle) * radius, math.sin(angle) * radius
end

-- Arena island height: flat, except the arena sinks into a bowl whose
-- sloped rim meets the ring road, so the storm fight can be watched from it.
local function smoothstep(low: number, high: number, value: number): number
	local t = math.clamp((value - low) / (high - low), 0, 1)
	return t * t * (3 - 2 * t)
end

-- The arena island is an octagon with a flat side facing each spoke, so
-- everything built on it (floor, bowl, road, wall) shares its outline.
-- octagonScale is how far the edge reaches at an angle, as a fraction of
-- the radius at the middle of a side; corners sit between the spokes.
local function octagonScale(degrees: number): number
	return 1 / math.cos(math.rad((degrees + 22.5) % 45 - 22.5))
end

-- Distance measured so every point on an octagon of side radius R reads R.
local function octagonRadius(x: number, y: number): number
	return math.sqrt(x * x + y * y) / octagonScale(math.deg(math.atan2(y, x)))
end

local function heightAt(x: number, y: number): number
	local radius = octagonRadius(x, y)
	return -ARENA_DEPTH * (1 - math.clamp((radius - ARENA_FLOOR) / (ROAD_INNER - 2 - ARENA_FLOOR), 0, 1))
end

-- A floating island: a dirt top following `top`, over a rock underside that
-- tapers to a ragged point `depth` below. Rings run outward across the top,
-- then inward down the underside, so every face keeps the same winding.
local ISLAND_SIDES = 48
local UNDERSIDE_RINGS = 10
-- outline(angle) scales the radius around the edge; nil keeps it round.
local function floatingIsland(mesh, radius: number, depth: number, seed: number, top: (number, number) -> number, outline: ((number) -> number)?, creases: { number }?)
	local rows = {}
	local function edge(angle: number): number
		return if outline then radius * outline(angle) else radius
	end
	local function addRing(fraction: number, z: (number, number, number) -> number)
		local row = {}
		for j = 0, ISLAND_SIDES - 1 do
			local angle = 2 * math.pi * j / ISLAND_SIDES
			local r = math.max(0.5, edge(angle) * fraction)
			local x, y = math.cos(angle) * r, math.sin(angle) * r
			row[j] = { x, y, z(x, y, angle) }
		end
		table.insert(rows, row)
	end
	-- Extra rings on every crease of `top`, so the surface bends there
	-- instead of cutting across the bend.
	local topRings = math.max(4, math.ceil(radius / 3))
	local fractions = {}
	for s = 0, topRings do
		table.insert(fractions, s / topRings)
	end
	for _, crease in creases or {} do
		table.insert(fractions, crease / radius)
	end
	table.sort(fractions)
	for _, fraction in fractions do
		addRing(fraction, function(x, y) return top(x, y) end)
	end
	for k = 1, UNDERSIDE_RINGS do
		local t = k / UNDERSIDE_RINGS
		local row = {}
		for j = 0, ISLAND_SIDES - 1 do
			local angle = 2 * math.pi * j / ISLAND_SIDES
			local c, n = math.cos(angle), math.sin(angle)
			local wobble = math.noise(c * 2, n * 2, seed + t * 3) * math.min(1, t * 3)
			local r = math.max(edge(angle) * (1 - t) ^ 0.55 * (1 + 0.3 * wobble), radius * 0.03)
			local z = -depth * t ^ 1.3 + 1.5 * t * math.noise(c * 3, n * 3, seed + 9)
			row[j] = { c * r, n * r, z }
		end
		table.insert(rows, row)
	end
	local verts = {}
	for i, row in rows do
		verts[i] = {}
		for j = 0, ISLAND_SIDES - 1 do
			verts[i][j] = mesh:vertex(row[j][1], row[j][2], row[j][3])
		end
	end
	for i = 1, #verts - 1 do
		for j = 0, ISLAND_SIDES - 1 do
			local l = (j + 1) % ISLAND_SIDES
			mesh:face({ verts[i][j], verts[i + 1][j], verts[i + 1][l], verts[i][l] })
		end
	end
	local topCap, bottomCap = {}, {}
	for j = 0, ISLAND_SIDES - 1 do
		table.insert(topCap, verts[1][j])
		table.insert(bottomCap, 1, verts[#verts][j])
	end
	mesh:face(topCap)
	mesh:face(bottomCap)
end

-- Dirt on top; underneath, rock in uneven strata with darker seams.
local function islandPaint(top: (number, number) -> number)
	return function(x: number, y: number, z: number)
		if z > top(x, y) - 0.3 then
			local k = 1 + 0.12 * math.noise(x / 4, y / 4, 31) + 0.05 * math.noise(x * 3, y * 3, 37)
			return GROUND[1] * k, GROUND[2] * k, GROUND[3] * k
		end
		local band = math.noise(x / 9, y / 9, z / 2) * 0.6 + z * 0.9
		local k = 1 + 0.12 * math.sin(band * 2.4) + 0.06 * math.noise(x * 2, y * 2, z * 2)
		if math.sin(band * 2.4) > 0.93 then k -= 0.25 end
		return ROCK[1] * k, ROCK[2] * k, ROCK[3] * k
	end
end

local function flat(_x: number, _y: number): number
	return 0
end
local function yardLevel(_x: number, _y: number): number
	return YARD_TIER
end

-- Under the ring road the dirt dips out of sight, since the road is thinner
-- than the surface wobble and the dirt would otherwise poke through it. It
-- comes back up under the kerb.
local ROAD_SINK = 0.15
local function islandTop(x: number, y: number): number
	local radius = octagonRadius(x, y)
	local into = math.clamp((radius - ROAD_INNER) / 0.5, 0, 1)
	local out = math.clamp((radius - ROAD_OUTER) / 0.4, 0, 1)
	return heightAt(x, y) - ROAD_SINK * (into - out)
end

slab("ArenaIsland", function()
	chunkedPart("Island", nil, GROUND, function(mesh)
		floatingIsland(mesh, ARENA_ISLAND, 42, 1, islandTop, function(angle)
			return octagonScale(math.deg(angle))
		end, { ARENA_FLOOR, ROAD_INNER - 2, ROAD_INNER, ROAD_INNER + 0.5, ROAD_OUTER, ROAD_OUTER + 0.4 })
	end, nil, islandPaint(islandTop))
end, 0, 0)
-- Fractal noise: octaves of math.noise, each twice as fine and half as strong.
local function fbm(x: number, y: number, z: number): number
	local total, amplitude = 0, 0.5
	for _ = 1, 4 do
		total += math.noise(x, y, z) * amplitude
		x, y, z, amplitude = x * 2, y * 2, z * 2, amplitude / 2
	end
	return total
end
-- fBm sampled through another fBm, so the wear twists into blotches and
-- streaks instead of even waves.
local function warpedFbm(x: number, y: number, z: number): number
	return fbm(x + 1.8 * fbm(x + 5.2, y + 1.3, z), y + 1.8 * fbm(x + 1.7, y + 9.2, z), z)
end
-- A solid band following a circle between two angles, used for the kerb,
-- floor stripes and rim wall. With `octagon` it follows the arena octagon
-- instead, with a row on every corner it passes so the corners stay sharp.
local function arc(mesh, inner: number, outer: number, bottom: number, top: number, from: number, to: number, octagon: boolean?)
	local angles = {}
	local steps = math.max(1, math.ceil((to - from) / 4))
	for s = 0, steps do
		table.insert(angles, from + (to - from) * s / steps)
	end
	if octagon then
		for corner = math.floor((from - 22.5) / 45 + 1) * 45 + 22.5, to - 0.01, 45 do
			if math.abs((corner - from) % ((to - from) / steps)) > 0.01 then
				table.insert(angles, corner)
			end
		end
		table.sort(angles)
	end
	steps = #angles - 1
	local rows = {}
	for s = 0, steps do
		local scale = if octagon then octagonScale(angles[s + 1]) else 1
		local angle = math.rad(angles[s + 1])
		local c, n = math.cos(angle) * scale, math.sin(angle) * scale
		rows[s] = {
			mesh:vertex(c * outer, n * outer, bottom),
			mesh:vertex(c * outer, n * outer, top),
			mesh:vertex(c * inner, n * inner, top),
			mesh:vertex(c * inner, n * inner, bottom),
		}
	end
	for s = 0, steps - 1 do
		local a, b = rows[s], rows[s + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
	mesh:face({ rows[0][4], rows[0][3], rows[0][2], rows[0][1] })
	mesh:face(rows[steps])
end

-- Arena concrete: broad warped stains from oil and fights, mottled patches
-- of differing cure, fine aggregate showing through the worn top, and
-- scuffs: short streaks scraped by bots, running one way per patch of floor.
local function scuff(x: number, y: number): number
	local angle = math.noise(x / 12, y / 12, 17) * math.pi * 2
	local u = x * math.cos(angle) + y * math.sin(angle)
	local v = y * math.cos(angle) - x * math.sin(angle)
	local streak = math.noise(u / 1.6, v * 7, 19)
	local patch = fbm(x / 6, y / 6, 23) + 0.02
	if patch <= 0 then return 0 end
	return math.clamp(math.abs(streak) - 0.12, 0, 1) * math.sign(streak) * math.min(1, patch * 8)
end
local function arenaConcrete(x: number, y: number, _z: number)
	local stain = warpedFbm(x / 14, y / 14, 3)
	local mottle = fbm(x / 3, y / 3, 7)
	local grain = math.noise(x * 6, y * 6, 11) * 0.5 + math.noise(x * 19, y * 19, 13) * 0.5
	local k = 1 + mottle * 0.12 + grain * 0.05 - math.max(0, stain) * 0.35
	if grain > 0.42 then
		k += 0.1
	elseif grain < -0.45 then
		k -= 0.08
	end
	local mark = scuff(x, y)
	k += if mark > 0 then mark * 0.4 else mark * 0.5
	return CONCRETE[1] * k, CONCRETE[2] * k, CONCRETE[3] * (k - math.max(0, stain) * 0.04)
end
-- Bridge deck: riveted steel tread plates laid across the span, with dark
-- seams, raised diamond treads worn smooth down the two wheel paths, hazard
-- chevrons painted along both outer plates, and grime and rust bleeding in
-- from the edges. Painted in the bridge's own frame so every bridge wears
-- the same way along its length.
local function bridgeDeck(degrees: number, cx: number, cy: number)
	local angle = math.rad(degrees - 90)
	local c, s = math.cos(angle), math.sin(angle)
	return function(x: number, y: number, _z: number)
		local u = (x - cx) * c + (y - cy) * s
		local v = (y - cy) * c - (x - cx) * s
		local edge = 3 - math.abs(u)
		local wheel = math.exp(-((math.abs(u) - 1.4) / 0.5) ^ 2)
		local k = 0.72 + fbm(u / 2, v / 2, 31) * 0.1
		-- Diamond treads alternate direction, flattened where tyres run.
		local du, dv = (u * 5) % 1 - 0.5, (v * 2.5) % 1 - 0.5
		local flip = if math.floor(u * 5) % 2 == math.floor(v * 2.5) % 2 then 1 else -1
		local tread = math.abs(du * 2 + flip * dv * 1.2) < 0.18 and math.abs(du) < 0.38
		if tread then
			k += 0.14 * (1 - wheel * 0.8)
		end
		k += wheel * (0.08 + fbm(u * 3, v / 4, 37) * 0.08)
		-- Plate seams every 2 studs, with a bolt pair near each edge.
		local seam = math.abs((v % 2) - 1)
		if seam > 0.96 then
			k -= 0.35
		elseif seam > 0.86 and math.abs(edge - 0.35) < 0.1 then
			k += 0.25
		end
		-- Edge grime and rust runs.
		local grime = math.clamp(1 - edge / 0.9, 0, 1) * (0.6 + fbm(v / 1.5, u, 41) * 0.8)
		k -= grime * 0.3 + math.max(0, warpedFbm(u / 3, v / 3, 43)) * 0.25
		local rust = math.clamp(grime + math.max(0, fbm(u, v / 1.2, 47)) - 0.35, 0, 1)
		local r, g, b = STEEL[1], STEEL[2], STEEL[3]
		-- Hazard chevrons painted onto the outer plates, leaning toward the
		-- arena and worn through to bare steel on the raised treads.
		if math.abs(math.abs(u) - 2.45) < 0.25 then
			local paint = if math.floor((v + math.abs(u) * 1.2) / 0.45) % 2 == 0 then MARK else { 0.1, 0.1, 0.1 }
			local wear = math.clamp(fbm(u * 4, v, 53) * 0.8 + (if tread then 0.35 else 0), 0, 1)
			r, g, b = paint[1] + (r - paint[1]) * wear, paint[2] + (g - paint[2]) * wear, paint[3] + (b - paint[3]) * wear
			k = 0.75 + (k - 0.75) * 0.5
		end
		return r * k + rust * 0.12, g * k + rust * 0.02, b * k - rust * 0.06
	end
end
-- Bridge girders: dark paint flaking off in patches to bare rust, with
-- rivet rows along both flanges.
local function bridgeGirders(degrees: number, cx: number, cy: number)
	local angle = math.rad(degrees - 90)
	local c, s = math.cos(angle), math.sin(angle)
	return function(x: number, y: number, z: number)
		local u = (x - cx) * c + (y - cy) * s
		local v = (y - cy) * c - (x - cx) * s
		local k = 1 + fbm(u + v / 2, z * 2, 51) * 0.12
		local flake = warpedFbm(v / 2.5, z * 1.5 + u, 53)
		local rust = math.clamp((flake - 0.1) * 4, 0, 1)
		local flange = math.abs(z + 0.35) < 0.05 or math.abs(z + 1.25) < 0.05
		local rivet = flange and math.abs(((v * 2) % 1) - 0.5) < 0.04
		if rivet then k += 0.45 end
		local r = DARK_STEEL[1] * k * (1 - rust) + 0.42 * rust * k
		local g = DARK_STEEL[2] * k * (1 - rust) + 0.2 * rust * k
		local b = DARK_STEEL[3] * k * (1 - rust) + 0.1 * rust * k
		return r, g, b
	end
end
slab("Arena", function()
	chunkedPart("Floor", nil, CONCRETE, function(mesh)
		arc(mesh, 0, ARENA_FLOOR - HAZARD_WIDTH, -ARENA_DEPTH - 0.1, 0.1 - ARENA_DEPTH, 0, 360, true)
	end, nil, arenaConcrete)
end, 0, 0)
-- The market terrace under the east side of the deck, broken where each
-- ramp lane runs out under the deck.
slab("Market", function()
	local lane = math.deg(math.asin(RAMP_HALF_MARKET / (ROAD_INNER - 2)))
	chunkedPart("Floor", nil, CONCRETE, function(mesh)
		local from = MARKET_FROM
		for spoke = -45, 45, 45 do
			arc(mesh, ROAD_INNER - 2, ROAD_OUTER, -0.2, MARKET, from, spoke - lane, true)
			from = spoke + lane
		end
		arc(mesh, ROAD_INNER - 2, ROAD_OUTER, -0.2, MARKET, from, MARKET_TO, true)
	end, nil, arenaConcrete)
end, 0, 0)
-- New players start on a pad on the market terrace.
slab("Spawn", function()
	local x, y = polar((ROAD_INNER + ROAD_OUTER) / 2 * octagonScale(22.5), 22.5)
	part("Pad", nil, MARK, function(mesh)
		ring(mesh, x, y, MARKET, 2.5, 3.5, 0.1, "z", 32)
	end, nil, 0)
end, 0, 0)

-- The crusher, the arena's centrepiece: a hydraulic press over a sunken
-- bed, four pillars carrying a crossbeam, and a press head held up over a
-- half-flattened car.
-- A square beam with flat ends running from one point up to another, for
-- legs that lean.
local function leg(mesh, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, width: number)
	local h = width / 2
	local corners = { { -h, -h }, { h, -h }, { h, h }, { -h, h } }
	local base, cap = {}, {}
	for k, c in corners do
		base[k] = mesh:vertex(x0 + c[1], y0 + c[2], z0)
		cap[k] = mesh:vertex(x1 + c[1], y1 + c[2], z1)
	end
	for k = 1, 4 do
		local l = k % 4 + 1
		mesh:face({ base[k], base[l], cap[l], cap[k] })
	end
	mesh:face(cap)
	mesh:face({ base[4], base[3], base[2], base[1] })
end

-- The storm beacon: a mast with a glowing core that lights up when a storm
-- round starts, visible from every yard.
local MAST_TOP = 24
local STORM_GLOW = { 0.35, 0.85, 1 }
slab("Beacon", function()
	local floor = 0.1 - ARENA_DEPTH
	part("Plinth", nil, CONCRETE, function(mesh)
		cylinder(mesh, 0, 0, floor + 0.6, 4.5, 1.2, "z", 8)
		cylinder(mesh, 0, 0, floor + 1.5, 3.4, 0.6, "z", 8)
	end, nil, 0.5)
	part("PlinthStripe", nil, MARK, function(mesh)
		ring(mesh, 0, 0, floor + 1.15, 4.4, 4.55, 0.25, "z", 8)
	end, nil, 0.3)
	-- Four straight legs leaning in towards the top, tied together with braces.
	part("Mast", nil, DARK_STEEL, function(mesh)
		local bottom, top = floor + 1.8, floor + MAST_TOP
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				leg(mesh, sx * 2.2, sy * 2.2, bottom, sx * 0.8, sy * 0.8, top, 0.45)
			end
		end
		local braces = 6
		for i = 1, braces do
			local t = i / braces
			local z = bottom + t * (top - bottom) - 0.25
			local half = 2.2 - t * 1.4
			box(mesh, 0, half, z, half * 2, 0.25, 0.25)
			box(mesh, 0, -half, z, half * 2, 0.25, 0.25)
			box(mesh, half, 0, z, 0.25, half * 2, 0.25)
			box(mesh, -half, 0, z, 0.25, half * 2, 0.25)
		end
	end, nil, 0.6)
	part("CoreMount", nil, STEEL, function(mesh)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 0.3, 1.9, 0.6, "z", 16)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 4.25, 1.9, 0.5, "z", 16)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 6.5, 0.15, 4, "z", 8)
	end, nil, 0.2)
	-- The core sits on top of the mast and is the part that glows during a storm.
	part("Core", nil, STORM_GLOW, function(mesh)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 2.3, 1.4, 3.4, "z", 16)
	end, nil, 0, nil, 1)
	part("CoreCage", nil, DARK_STEEL, function(mesh)
		for k = 0, 5 do
			local angle = math.rad(k * 60)
			box(mesh, math.cos(angle) * 1.65, math.sin(angle) * 1.65, floor + MAST_TOP + 0.6, 0.2, 0.2, 3.4)
		end
	end, nil, 0.3)
end, 0, 0)


-- The arena edge stands out from the yards around it: hazard stripes ring the
-- fight floor, and a low concrete wall with yellow caps tops the bowl,
-- broken where each spoke comes in.
-- The arena wall runs along each octagon side in two halves, one each side
-- of the spoke. A half starts square at `near` across the spoke, where it
-- meets the ramp edge, and ends mitred at the octagon corner.
local WALL_INNER, WALL_OUTER = ROAD_INNER - 1.2, ROAD_INNER - 0.4
local WALL_TOP = 1.25
-- The ramp lane, with a hazard strip outside it on each side.
local LANE_HALF = 3.6
local RAMP_HALF = LANE_HALF + HAZARD_WIDTH
local function wallRun(mesh, degrees: number, side: number, inner: number, outer: number, near: number, bottom: number, top: number)
	local angle = math.rad(degrees)
	local c, n = math.cos(angle), math.sin(angle)
	local corner = math.tan(math.rad(22.5))
	-- Footprint counter-clockwise seen from above.
	local footprint = { { inner, near }, { outer, near }, { outer, outer * corner }, { inner, inner * corner } }
	if side < 0 then
		footprint = { { inner, -inner * corner }, { outer, -outer * corner }, { outer, -near }, { inner, -near } }
	end
	local low, high = {}, {}
	for k, p in footprint do
		local x, y = c * p[1] - n * p[2], n * p[1] + c * p[2]
		low[k] = mesh:vertex(x, y, bottom)
		high[k] = mesh:vertex(x, y, top)
	end
	mesh:face({ high[1], high[2], high[3], high[4] })
	mesh:face({ low[4], low[3], low[2], low[1] })
	for k = 1, 4 do
		local l = k % 4 + 1
		mesh:face({ low[k], low[l], high[l], high[k] })
	end
end
slab("ArenaEdge", function()
	part("Wall", nil, CONCRETE, function(mesh)
		for i = 1, 8 do
			for _, side in { -1, 1 } do
				wallRun(mesh, (i - 1) * 45, side, WALL_INNER, WALL_OUTER, RAMP_HALF, -0.5, WALL_TOP)
			end
		end
	end, nil, 0.4)
	part("WallCap", nil, MARK, function(mesh)
		for i = 1, 8 do
			for _, side in { -1, 1 } do
				wallRun(mesh, (i - 1) * 45, side, WALL_INNER - 0.1, WALL_OUTER + 0.1, RAMP_HALF - 0.1, WALL_TOP, WALL_TOP + 0.15)
			end
		end
	end, nil, 0.3)
end, 0, 0)
-- Asphalt at u studs across and v along a road: fine aggregate, darker
-- repair patches, polished tyre lanes, oil drips between them, a web of
-- cracks, and worn paint: white edge lines and a dashed yellow centre line.
local function asphalt(u: number, v: number, half: number, seed: number): (number, number, number)
	local k = 1 + fbm(u * 3, v * 3, seed) * 0.12
	k += (math.noise(u * 9.1, v * 9.1, seed + 1) > 0.35 and 0.1 or 0)
	local patch = warpedFbm(u / 6, v / 6, seed + 2)
	if patch > 0.22 then
		k -= 0.16
	end
	local lane = math.exp(-((math.abs(u) - half / 2) / 0.6) ^ 2)
	k += lane * (0.07 + fbm(u, v / 5, seed + 3) * 0.05)
	local oil = math.max(0, fbm(u / 1.5, v / 3, seed + 4) - 0.15) * (1 - lane)
	k -= oil * 0.9
	local crack = math.abs(warpedFbm(u / 3, v / 3, seed + 5))
	if crack < 0.012 then
		k -= 0.35
	end
	local r, g, b = ROAD[1] * k, ROAD[2] * k, ROAD[3] * k * 1.02
	local fade = math.clamp(0.75 + fbm(u * 2, v / 2, seed + 6) * 1.2 - lane * 0.3, 0, 1)
	local edgeLine = math.abs(math.abs(u) - (half - 0.5)) < 0.1
	if edgeLine then
		return r + (0.82 - r) * fade, g + (0.8 - g) * fade, b + (0.74 - b) * fade
	end
	return r, g, b
end

-- The ring road, with a concrete kerb along its outer edge broken where each
-- spoke road joins it. The inner edge stays open onto the arena rim.
slab("Road", function()
	local middle = (ROAD_INNER + ROAD_OUTER) / 2
	chunkedPart("Ring", nil, ROAD, function(mesh)
		arc(mesh, ROAD_INNER, ROAD_OUTER, DECK - 0.6, DECK, 0, 360, true)
	end, nil, function(x, y)
		local radius = octagonRadius(x, y)
		return asphalt(radius - middle, math.atan2(y, x) * middle, (ROAD_OUTER - ROAD_INNER) / 2, 61)
	end)
	-- Each kerb run stops against the outer face of a bridge abutment's wing wall.
	local bridgeGap = math.deg(math.asin(3.65 / ROAD_OUTER))
	part("Kerb", nil, CONCRETE, function(mesh)
		for i = 1, 8 do
			local from = (i - 1) * 45
			arc(mesh, ROAD_OUTER - 0.1, ROAD_OUTER + 0.5, DECK - 0.6, DECK + 0.3, from + bridgeGap, from + 45 - bridgeGap, true)
		end
	end, nil, 0.5)
	-- Square pillars under both deck edges, standing on the market terrace
	-- where it runs under them.
	part("Pillars", nil, CONCRETE, function(mesh)
		for n = 0, 31 do
			local degrees = n * 11.25 + 5.625
			local inMarket = degrees > 360 + MARKET_FROM or degrees < MARKET_TO
			local foot = if inMarket then MARKET else 0
			for _, radius in { ROAD_INNER + 0.8, ROAD_OUTER - 0.8 } do
				local x, y = polar(radius * octagonScale(degrees), degrees)
				box(mesh, x, y, foot - 0.2, 1, 1, DECK - 0.6 - foot + 0.2)
			end
		end
	end, nil, 0.5)
end, 0, 0)

-- Entry ramps: a concrete deck at each spoke, from the wall gap down to the
-- fight floor. The deck is one straight slope, flush with the floor where it
-- meets the arena's hazard ring and level across the wall gap. It is a touch
-- steeper than the bowl, so it never dips into the terrain.
local RAMP_FLOOR = 0.1 - ARENA_DEPTH
local RAMP_CREST = 0.35
local function rampTop(radius: number): number
	return RAMP_FLOOR + (RAMP_CREST - RAMP_FLOOR) * math.clamp((radius - ARENA_FLOOR) / (WALL_INNER - ARENA_FLOOR), 0, 1)
end
-- A block on spoke `degrees` between `from` and `to` across it and over
-- `radii` along it, its top `lift` above the deck and its bottom at the
-- arena floor or `depth` below its top.
local function rampBlock(mesh, degrees: number, radii: { number }, from: number, to: number, lift: number, depth: number?)
	local angle = math.rad(degrees)
	local c, n = math.cos(angle), math.sin(angle)
	local rows = {}
	for s, radius in radii do
		local top = rampTop(radius) + lift
		local bottom = if depth then top - depth else RAMP_FLOOR - 0.1
		rows[s] = {}
		local miter = radius * math.tan(math.rad(22.5))
		for k, side in { from, to } do
			side = math.clamp(side, -miter, miter)
			local x, y = c * radius - n * side, n * radius + c * side
			rows[s][k] = mesh:vertex(x, y, top)
			rows[s][k + 2] = mesh:vertex(x, y, bottom)
		end
	end
	for s = 1, #radii - 1 do
		local a, b = rows[s], rows[s + 1]
		mesh:face({ b[1], b[2], a[2], a[1] })
		mesh:face({ a[4], b[4], b[3], a[3] })
		mesh:face({ a[3], b[3], b[1], a[1] })
		mesh:face({ b[2], b[4], a[4], a[2] })
	end
	local first, last = rows[1], rows[#radii]
	mesh:face({ first[2], first[4], first[3], first[1] })
	mesh:face({ last[3], last[4], last[2], last[1] })
end
-- Hazard strips inlaid outside both lane edges, as wide as the arena's ring
-- and flush with the deck. They run from the wall line, ending yellow, across
-- the ring, which is cut at each ramp mouth and runs from strip to strip
-- along each octagon side, mitred at the corners. Blocks are clamped to the
-- octagon miters, so the last ring piece on each side runs into the corner.
local STRIP_BREAKS = { ARENA_FLOOR - HAZARD_WIDTH }
for k = 0, 6 do
	table.insert(STRIP_BREAKS, ARENA_FLOOR + k * (WALL_INNER - ARENA_FLOOR) / 6)
end
slab("Ramps", function()
	part("Deck", nil, CONCRETE, function(mesh)
		for i = 1, 8 do
			rampBlock(mesh, (i - 1) * 45, { ARENA_FLOOR - HAZARD_WIDTH, ARENA_FLOOR, WALL_INNER }, -LANE_HALF, LANE_HALF, 0)
		end
	end, nil, 0.25)
	for k, color in { MARK, { 0.08, 0.08, 0.08 } } do
		part(if k == 1 then "RampStripeYellow" else "RampStripeBlack", nil, color, function(mesh)
			for i = 1, 8 do
				for s = k, #STRIP_BREAKS - 1, 2 do
					local radii = { STRIP_BREAKS[s], STRIP_BREAKS[s + 1] }
					rampBlock(mesh, (i - 1) * 45, radii, -RAMP_HALF, -LANE_HALF, 0)
					rampBlock(mesh, (i - 1) * 45, radii, LANE_HALF, RAMP_HALF, 0)
				end
				-- Ring pieces, black-yellow-black from the mouth to the corner.
				local ring = { ARENA_FLOOR - HAZARD_WIDTH, ARENA_FLOOR }
				local cuts = { RAMP_HALF, RAMP_HALF + 3.2, RAMP_HALF + 6.4, 99 }
				for s = 3 - k, 3, 2 do
					rampBlock(mesh, (i - 1) * 45, ring, cuts[s], cuts[s + 1], 0)
					rampBlock(mesh, (i - 1) * 45, ring, -cuts[s + 1], -cuts[s], 0)
				end
			end
		end, nil, 0.2)
	end
end, 0, 0)
-- Each ramp mouth: a steel drainage grate across the gap from the wall line
-- to the road, and a concrete pier closing each wall end, its face to the
-- gap banded yellow and black.
local THRESHOLD = { WALL_INNER, ROAD_INNER + 0.5 }
local PIER_WIDTH, PIER_TOP = 1, WALL_TOP + 0.5
local PIER_RADII = { WALL_INNER - 0.3, WALL_OUTER + 0.3 }
slab("RampMouths", function()
	part("ThresholdPit", nil, { 0.05, 0.05, 0.05 }, function(mesh)
		for i = 1, 8 do
			rampBlock(mesh, (i - 1) * 45, THRESHOLD, -RAMP_HALF, RAMP_HALF, 0, 0.4)
		end
	end, nil, 0)
	part("Threshold", nil, STEEL, function(mesh)
		local bars = 6
		local step = (THRESHOLD[2] - THRESHOLD[1] - 0.2) / bars
		for i = 1, 8 do
			for b = 0, bars do
				local radius = THRESHOLD[1] + 0.1 + b * step
				rampBlock(mesh, (i - 1) * 45, { radius - 0.07, radius + 0.07 }, -RAMP_HALF, RAMP_HALF, 0.05, 0.15)
			end
		end
	end, nil, 0.4)
	part("Pier", nil, CONCRETE, function(mesh)
		for i = 1, 8 do
			for _, side in { -1, 1 } do
				local near, far = side * RAMP_HALF, side * (RAMP_HALF + PIER_WIDTH)
				rampBlock(mesh, (i - 1) * 45, PIER_RADII, math.min(near, far), math.max(near, far), PIER_TOP - RAMP_CREST, PIER_TOP + 0.5)
			end
		end
	end, nil, 0.4)
	for k, color in { MARK, { 0.08, 0.08, 0.08 } } do
		part(if k == 1 then "PierStripeYellow" else "PierStripeBlack", nil, color, function(mesh)
			local band = (PIER_TOP - RAMP_CREST) / 4
			for i = 1, 8 do
				for _, side in { -1, 1 } do
					local face, inset = side * RAMP_HALF, side * (RAMP_HALF - 0.04)
					for b = k, 4, 2 do
						rampBlock(mesh, (i - 1) * 45, PIER_RADII, math.min(face, inset), math.max(face, inset), b * band, band)
					end
				end
			end
		end, nil, 0.3)
	end
end, 0, 0)

-- Each yard island is turned so its gate (local -y) faces the arena. A short
-- road runs from the gate to the island edge, and a steel bridge carries it
-- across the gap to the ring road.
local BRIDGE_FROM, BRIDGE_TO = -YARD_ISLAND, -(YARD_RADIUS - ROAD_OUTER)
local BRIDGE_MID, BRIDGE_LENGTH = (BRIDGE_FROM + BRIDGE_TO) / 2, BRIDGE_FROM - BRIDGE_TO
-- Bridges climb from the deck to the yard tier. Every bridge part is built
-- flat and then sheared up along its length, so posts stay upright and the
-- end pieces sit level at their own tier.
local function bridgeLift(y: number): number
	return DECK + (YARD_TIER - DECK) * math.clamp((y - BRIDGE_TO) / BRIDGE_LENGTH, 0, 1)
end
local function bridgePart(name: string, color, build: (any) -> (), paint)
	part(name, nil, color, function(mesh)
		build({
			vertex = function(_, x, y, z)
				return mesh:vertex(x, y, z + bridgeLift(y))
			end,
			face = function(_, corners)
				return mesh:face(corners)
			end,
		})
	end, nil, paint)
end
-- Lumpy yard outlines that never cut into the plot's corners (0.9 * 26
-- clears its 22.6 half-diagonal) and stay full where the bridge lands.
local function yardOutline(seed: number): (number) -> number
	return function(angle)
		local c, n = math.cos(angle), math.sin(angle)
		local lump = 1.1 + 0.5 * math.noise(c * 1.4, n * 1.4, seed) + 0.12 * math.noise(c * 4, n * 4, seed + 3)
		local fromBridge = math.abs((angle + math.pi / 2 + math.pi) % (2 * math.pi) - math.pi)
		local landing = 1 - smoothstep(0.25, 0.7, fromBridge)
		return math.max(0.9, lump + (1 - lump) * landing)
	end
end
-- Builds one yard from the Yard Layout pieces, laid out as in
-- YardLayout.luau but turned and moved onto the plot at (x, y). The crate
-- shows empty, as in the template.
local function yardTemplate(index: number, x: number, y: number, turn: number)
	local c, s = math.cos(math.rad(turn)), math.sin(math.rad(turn))
	local function piece(name: string, build: () -> (), px: number, py: number, pz: number?, pturn: number?)
		place(`Yard{index}_{name}`, build, x + px * c - py * s, y + px * s + py * c, (pz or 0) + YARD_TIER, turn + (pturn or 0))
	end
	for i, tx in { -12, -4, 4, 12 } do
		for j, ty in { -12, -4, 4, 12 } do
			piece(`Tile{(i - 1) * 4 + j}`, buildGroundTile, tx, ty, 0, ((tx + ty * 3) // 8 % 4) * 90)
		end
	end
	for i, pad in { { -9, 2 }, { -9, 10 }, { 9, 2 }, { 9, 10 } } do
		piece(`Pad{i}`, buildMachinePad, pad[1], pad[2])
	end
	piece("Crate", buildStorageCrate, 0, 12)
	for i, py in { -12, -4, 4 } do
		piece(`Path{i}`, buildYardPath, 0, py, 0.01)
	end
	for i, py in { 2, 10 } do
		piece(`Branch{i * 2 - 1}`, buildYardPathStub, -4, py, 0.01, 90)
		piece(`Branch{i * 2}`, buildYardPathStub, 4, py, 0.01, 90)
	end
	for i, f in { -12, -4, 4, 12 } do
		piece(`FenceBack{i}`, buildYardFence, f, 16)
		piece(`FenceLeft{i}`, buildYardFence, -16, f, 0, 90)
		piece(`FenceRight{i}`, buildYardFence, 16, f, 0, 90)
	end
	for i, side in { -1, 1 } do
		piece(`FenceFront{i}`, buildYardFence, side * 8, -16)
		piece(`FenceFrontHalf{i}`, buildYardFenceHalf, side * 14, -16)
	end
	piece("Gate", buildYardGate, 0, -16)
	piece("PlotMarker", buildPlotMarker, 6, -17.5)
end

for i = 1, 8 do
	local degrees = (i - 1) * 45
	local x, y = polar(YARD_RADIUS, degrees)
	slab(`Island{i}`, function()
		part("Island", nil, GROUND, function(mesh)
			floatingIsland(mesh, YARD_ISLAND, 22, 10 + i, yardLevel, yardOutline(10 + i))
		end, nil, islandPaint(yardLevel))
	end, x, y, degrees - 90)
	slab(`Plot{i}`, function()
		part("Slab", nil, PLOT, function(mesh)
			box(mesh, 0, 0, YARD_TIER, 32, 32, 0.05)
		end, nil, 0)
	end, x, y, degrees - 90)
	yardTemplate(i, x, y, degrees - 90)
	local c, s = math.cos(math.rad(degrees - 90)), math.sin(math.rad(degrees - 90))
	slab(`Spoke{i}`, function()
		part("Road", nil, ROAD, function(mesh)
			box(mesh, 0, -18, YARD_TIER, 6, 6, 0.1)
		end, nil, function(px, py)
			local u = (px - x) * c + (py - y) * s
			local v = (py - y) * c - (px - x) * s
			return asphalt(u, v, 3, 70 + i)
		end)
	end, x, y, degrees - 90)
	slab(`Bridge{i}`, function()
		bridgePart("Deck", STEEL, function(mesh)
			box(mesh, 0, BRIDGE_MID, -0.2, 6, BRIDGE_LENGTH, 0.3)
		end, bridgeDeck(degrees, x, y))
		bridgePart("Girders", DARK_STEEL, function(mesh)
			-- I-beams: a web between two flanges, ribbed on the outside, with
			-- bolted splice plates where the beam sections join.
			for _, side in { -2.6, 2.6 } do
				local out = math.sign(side)
				box(mesh, side, BRIDGE_MID, -1.4, 0.2, BRIDGE_LENGTH, 1.2)
				box(mesh, side, BRIDGE_MID, -1.4, 0.6, BRIDGE_LENGTH, 0.15)
				box(mesh, side, BRIDGE_MID, -0.4, 0.6, BRIDGE_LENGTH, 0.15)
				for n = 0, math.floor(BRIDGE_LENGTH / 2) do
					box(mesh, side + out * 0.17, BRIDGE_TO + 1 + n * 2, -1.25, 0.14, 0.1, 0.85)
				end
				for n = 1, math.floor(BRIDGE_LENGTH / 8) do
					local at = BRIDGE_TO + n * 8
					box(mesh, side + out * 0.13, at, -1.15, 0.06, 0.9, 0.65)
					for _, dy in { -0.3, 0.3 } do
						for _, dz in { -1.0, -0.65 } do
							box(mesh, side + out * 0.18, at + dy, dz, 0.06, 0.1, 0.1)
						end
					end
				end
			end
			for n = 0, math.floor(BRIDGE_LENGTH / 4) do
				box(mesh, 0, BRIDGE_TO + 1 + n * 4, -0.6, 5.6, 0.3, 0.4)
			end
		end, bridgeGirders(degrees, x, y))
		-- Railing posts spaced evenly so both ends get one, each bolted down
		-- on a base plate and capped.
		local postCount = math.ceil((BRIDGE_LENGTH - 0.3) / 2.5)
		local postGap = (BRIDGE_LENGTH - 0.3) / postCount
		bridgePart("Posts", STEEL, function(mesh)
			for _, side in { -2.9, 2.9 } do
				for n = 0, postCount do
					local at = BRIDGE_TO + 0.15 + n * postGap
					box(mesh, side, at, -0.05, 0.36, 0.36, 0.06)
					box(mesh, side, at, 0.01, 0.14, 0.14, 1.27)
					box(mesh, side, at, 1.28, 0.2, 0.2, 0.06)
				end
			end
		end, 0.4)
		-- Handrail on top, a thinner mid rail and a kick plate at the deck.
		bridgePart("Rail", MARK, function(mesh)
			for _, side in { -2.9, 2.9 } do
				box(mesh, side, BRIDGE_MID, 1.16, 0.16, BRIDGE_LENGTH - 0.2, 0.12)
				box(mesh, side, BRIDGE_MID, 0.62, 0.08, BRIDGE_LENGTH - 0.3, 0.08)
				box(mesh, side + math.sign(side) * 0.1, BRIDGE_MID, -0.05, 0.04, BRIDGE_LENGTH - 0.3, 0.22)
			end
		end, 0.3)
		-- Each end rests on a concrete seat set into the island edge, with a
		-- low wing wall either side for the kerb or yard edge to end against.
		bridgePart("Abutments", CONCRETE, function(mesh)
			for _, ends in { { BRIDGE_TO, -1 }, { BRIDGE_FROM, 1 } } do
				local edge, land = ends[1], ends[2]
				box(mesh, 0, edge + land * 0.75, -3, 7.3, 3.5, 2.8)
				for _, side in { -3.4, 3.4 } do
					box(mesh, side, edge - land * 0.5, -3, 0.5, 1, 3.45)
				end
			end
		end, 0.5)
		-- The yard end lands on a concrete apron under a gate frame standing on
		-- the wing walls. A steel plate covers the joint at both ends.
		bridgePart("Apron", CONCRETE, function(mesh)
			box(mesh, 0, BRIDGE_FROM + 2.5, 0, 7.3, 5, 0.12)
		end, 0.5)
		bridgePart("JointPlates", STEEL, function(mesh)
			for _, edge in { BRIDGE_TO, BRIDGE_FROM } do
				box(mesh, 0, edge, 0.1, 6, 0.8, 0.04)
			end
		end, 0.3)
		-- The road end gets a hazard bollard on each wing wall.
		bridgePart("Bollards", MARK, function(mesh)
			for _, side in { -3.4, 3.4 } do
				box(mesh, side, BRIDGE_TO + 0.5, 0.45, 0.4, 0.4, 1.2)
			end
		end, 0.3)
		bridgePart("GateFrame", DARK_STEEL, function(mesh)
			for _, side in { -3.4, 3.4 } do
				box(mesh, side, BRIDGE_FROM - 0.5, 0.45, 0.4, 0.4, 4)
			end
			box(mesh, 0, BRIDGE_FROM - 0.5, 4.15, 7.2, 0.3, 0.3)
		end, 0.3)
	end, x, y, degrees - 90)
	local coneX, coneY = polar(ROAD_INNER + 1.5, degrees + 9)
	place(`Cones{i}`, buildTrafficCones, coneX, coneY, heightAt(coneX, coneY), degrees)
end

-- Cover for the storm fights, offset from the spokes so paths stay open.
for i, build in { buildShippingContainer, buildCarStack, buildCrushedCar, buildBarrels, buildTyreStack, buildJunkWall, buildDumpster, buildPallets } do
	local degrees = (i - 0.5) * 45
	local x, y = polar(26, degrees)
	place(`Cover{i}`, build, x, y, 0.2 - ARENA_DEPTH, degrees + 90)
end
-- Bot spawn hatches in the arena floor, inside the cover ring between the spokes.
-- Storm bots climb out of these; the hazard rim marks where they emerge.
for i = 1, 4 do
	local degrees = (i - 0.75) * 90
	local x, y = polar(17, degrees)
	slab(`Hatch{i}`, function()
		local floor = 0.1 - ARENA_DEPTH
		part("Rim", nil, MARK, function(mesh)
			ring(mesh, 0, 0, floor, 2.6, 3.1, 0.12, "z", 24)
		end, nil, 0.3)
		part("Frame", nil, DARK_STEEL, function(mesh)
			ring(mesh, 0, 0, floor, 2.1, 2.6, 0.2, "z", 24)
		end, nil, 0.5)
		part("Pit", nil, { 0.05, 0.05, 0.05 }, function(mesh)
			cylinder(mesh, 0, 0, floor - 0.05, 2.1, 0.1, "z", 24)
		end, nil, 0)
		part("Grate", nil, STEEL, function(mesh)
			for n = -3, 3 do
				local half = math.sqrt(2.1 * 2.1 - (n * 0.55) ^ 2)
				box(mesh, n * 0.55, 0, floor + 0.08, 0.14, half * 2, 0.1)
			end
			box(mesh, 0, 0, floor + 0.1, 4.2, 0.2, 0.12)
		end, nil, 0.4)
	end, x, y, degrees)
end
for i = 1, 4 do
	local degrees = (i - 0.75) * 90
	local x, y = polar(ROAD_INNER - 2, degrees)
	place(`Light{i}`, buildStreetlightBroken, x, y, heightAt(x, y), degrees + 90)
end
