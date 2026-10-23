-- uses: ShippingContainer CarStack CrushedCar Barrels TyreStack JunkWall Dumpster Pallets StreetlightBroken TrafficCones
-- Server Map: one server's whole map, centered on the origin, built as
-- floating islands. The arena island sits in the middle with a ring road
-- around its bowl; eight yard islands float in a ring with their gates facing
-- it, each joined to the road by a steel bridge. The arena is the storm fight
-- ground and, between storms, the spawn plaza new players start on.
-- Yards are only plot slabs here: the game drops the Yard Layout template
-- onto each one, so every yard is built from the same pieces.
-- Labels: ArenaIsland, Road, Arena, ArenaEdge, Ramps, Spawn, Beacon, Island1-Island8, Plot1-Plot8, Spoke1-Spoke8, Bridge1-Bridge8,
-- Cover1-Cover8, Hatch1-Hatch4, Light1-Light4 and Cones1-Cones8.
local YARD_RADIUS = 110
local ROAD_INNER, ROAD_OUTER = 50, 58
local ARENA_FLOOR, ARENA_DEPTH = 36, 3.5
local ARENA_ISLAND, YARD_ISLAND = 61, 26

local GROUND = { 0.3, 0.27, 0.22 }
local ROAD = { 0.42, 0.41, 0.4 }
local CONCRETE = { 0.55, 0.54, 0.5 }
local MARK = { 0.85, 0.65, 0.15 }
local PLOT = { 0.36, 0.33, 0.28 }
local ROCK = { 0.42, 0.37, 0.31 }

-- Places one flat piece built here rather than from a model.
local function slab(label: string, build: () -> (), x: number, y: number, turn: number?)
	place(label, function()
		build()
		finishParts()
		table.clear(parts)
	end, x, y, 0, turn)
end

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

local function heightAt(x: number, y: number): number
	local radius = math.sqrt(x * x + y * y)
	return -ARENA_DEPTH * (1 - smoothstep(ARENA_FLOOR, ROAD_INNER - 2, radius))
end

-- A floating island: a dirt top following `top`, over a rock underside that
-- tapers to a ragged point `depth` below. Rings run outward across the top,
-- then inward down the underside, so every face keeps the same winding.
local ISLAND_SIDES = 48
local UNDERSIDE_RINGS = 10
-- outline(angle) scales the radius around the edge; nil keeps it round.
local function floatingIsland(mesh, radius: number, depth: number, seed: number, top: (number, number) -> number, outline: ((number) -> number)?)
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
	local topRings = math.max(4, math.ceil(radius / 3))
	for s = 0, topRings do
		addRing(s / topRings, function(x, y) return top(x, y) end)
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

slab("ArenaIsland", function()
	part("Island", nil, GROUND, function(mesh)
		floatingIsland(mesh, ARENA_ISLAND, 42, 1, heightAt)
	end, nil, islandPaint(heightAt), 2048)
end, 0, 0)
slab("Road", function()
	part("Ring", nil, ROAD, function(mesh)
		ring(mesh, 0, 0, 0, ROAD_INNER, ROAD_OUTER, 0.1, "z", 48)
	end, nil, 0)
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
-- seams, raised diamond treads worn smooth down the two wheel paths, and
-- grime and rust bleeding in from the edges. Painted in the bridge's own
-- frame so every bridge wears the same way along its length.
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
		return STEEL[1] * k + rust * 0.12, STEEL[2] * k + rust * 0.02, STEEL[3] * k - rust * 0.06
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
	part("Floor", nil, CONCRETE, function(mesh)
		cylinder(mesh, 0, 0, -ARENA_DEPTH, ARENA_FLOOR, 0.2, "z", 48)
	end, nil, arenaConcrete, 2048)
end, 0, 0)
-- New players start on the ring around the crusher.
slab("Spawn", function()
	part("Pad", nil, MARK, function(mesh)
		ring(mesh, 0, 0, 0.2 - ARENA_DEPTH, 6.5, 8.5, 0.1, "z", 32)
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
local TOWER_TEXTURE = 1024
local STORM_GLOW = { 0.35, 0.85, 1 }
slab("Beacon", function()
	local floor = 0.1 - ARENA_DEPTH
	part("Plinth", nil, CONCRETE, function(mesh)
		cylinder(mesh, 0, 0, floor + 0.6, 4.5, 1.2, "z", 8)
		cylinder(mesh, 0, 0, floor + 1.5, 3.4, 0.6, "z", 8)
	end, nil, 0.5, TOWER_TEXTURE)
	part("PlinthStripe", nil, MARK, function(mesh)
		ring(mesh, 0, 0, floor + 1.15, 4.4, 4.55, 0.25, "z", 8)
	end, nil, 0.3, TOWER_TEXTURE)
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
	end, nil, 0.6, TOWER_TEXTURE)
	part("CoreMount", nil, STEEL, function(mesh)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 0.3, 1.9, 0.6, "z", 16)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 4.25, 1.9, 0.5, "z", 16)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 6.5, 0.15, 4, "z", 8)
	end, nil, 0.2, TOWER_TEXTURE)
	-- The core sits on top of the mast and is the part that glows during a storm.
	part("Core", nil, STORM_GLOW, function(mesh)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 2.3, 1.4, 3.4, "z", 16)
	end, nil, 0, TOWER_TEXTURE, 1)
	part("CoreCage", nil, DARK_STEEL, function(mesh)
		for k = 0, 5 do
			local angle = math.rad(k * 60)
			box(mesh, math.cos(angle) * 1.65, math.sin(angle) * 1.65, floor + MAST_TOP + 0.6, 0.2, 0.2, 3.4)
		end
	end, nil, 0.3, TOWER_TEXTURE)
end, 0, 0)

-- A solid band following the arena circle between two angles, used for the
-- floor stripes and the rim wall.
local function arc(mesh, inner: number, outer: number, bottom: number, top: number, from: number, to: number)
	local steps = math.max(1, math.ceil((to - from) / 4))
	local rows = {}
	for s = 0, steps do
		local angle = math.rad(from + (to - from) * s / steps)
		local c, n = math.cos(angle), math.sin(angle)
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

-- The arena edge stands out from the yards around it: hazard stripes ring the
-- fight floor, and a low concrete wall with yellow caps tops the bowl,
-- broken where each spoke comes in.
local STRIPES = 72
slab("ArenaEdge", function()
	local floor = 0.1 - ARENA_DEPTH
	for k, color in { MARK, { 0.08, 0.08, 0.08 } } do
		part(if k == 1 then "StripeYellow" else "StripeBlack", nil, color, function(mesh)
			for s = k - 1, STRIPES - 1, 2 do
				arc(mesh, ARENA_FLOOR - 2, ARENA_FLOOR - 0.2, floor, floor + 0.12, s * 360 / STRIPES, (s + 1) * 360 / STRIPES)
			end
		end, nil, 0.2)
	end
	part("Wall", nil, CONCRETE, function(mesh)
		for i = 1, 8 do
			local from = (i - 1) * 45
			arc(mesh, ROAD_INNER - 1.2, ROAD_INNER - 0.4, -0.5, 0.9, from + 5, from + 40)
		end
	end, nil, 0.4)
	part("WallCap", nil, MARK, function(mesh)
		for i = 1, 8 do
			local from = (i - 1) * 45
			arc(mesh, ROAD_INNER - 1.3, ROAD_INNER - 0.3, 0.9, 1.05, from + 5, from + 40)
		end
	end, nil, 0.3)
end, 0, 0)

-- Entry ramps: a concrete apron down the bowl rim at each spoke, through the
-- wall gap, edged with yellow curbs so players and bots see the way in.
-- Each strip follows the rim's curve from the ring road to the floor.
local RAMP_STEPS = 12
local function rampStrip(mesh, degrees: number, from: number, to: number, lift: number, thickness: number)
	local angle = math.rad(degrees)
	local c, n = math.cos(angle), math.sin(angle)
	local rows = {}
	for s = 0, RAMP_STEPS do
		local radius = ARENA_FLOOR - 1 + (ROAD_INNER + 0.5 - (ARENA_FLOOR - 1)) * s / RAMP_STEPS
		local top = math.max(heightAt(c * radius, n * radius), -ARENA_DEPTH + 0.2) + lift
		rows[s] = {}
		for k, side in { from, to } do
			local x, y = c * radius - n * side, n * radius + c * side
			rows[s][k] = mesh:vertex(x, y, top)
			rows[s][k + 2] = mesh:vertex(x, y, top - thickness)
		end
	end
	for s = 0, RAMP_STEPS - 1 do
		local a, b = rows[s], rows[s + 1]
		mesh:face({ a[1], a[2], b[2], b[1] })
		mesh:face({ a[3], b[3], b[4], a[4] })
		mesh:face({ a[1], b[1], b[3], a[3] })
		mesh:face({ a[2], a[4], b[4], b[2] })
	end
	mesh:face({ rows[0][1], rows[0][3], rows[0][4], rows[0][2] })
	local last = rows[RAMP_STEPS]
	mesh:face({ last[1], last[2], last[4], last[3] })
end
slab("Ramps", function()
	part("Apron", nil, CONCRETE, function(mesh)
		for i = 1, 8 do
			rampStrip(mesh, (i - 1) * 45, -3, 3, 0.15, 0.6)
		end
	end, nil, 0.15)
	part("Curb", nil, MARK, function(mesh)
		for i = 1, 8 do
			rampStrip(mesh, (i - 1) * 45, -3.4, -2.9, 0.4, 0.8)
			rampStrip(mesh, (i - 1) * 45, 2.9, 3.4, 0.4, 0.8)
		end
	end, nil, 0.3)
end, 0, 0)

-- Each yard island is turned so its gate (local -y) faces the arena. A short
-- road runs from the gate to the island edge, and a steel bridge carries it
-- across the gap to the ring road.
local BRIDGE_FROM, BRIDGE_TO = -(YARD_ISLAND - 1), -(YARD_RADIUS - ROAD_OUTER + 1)
local BRIDGE_MID, BRIDGE_LENGTH = (BRIDGE_FROM + BRIDGE_TO) / 2, BRIDGE_FROM - BRIDGE_TO
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
for i = 1, 8 do
	local degrees = (i - 1) * 45
	local x, y = polar(YARD_RADIUS, degrees)
	slab(`Island{i}`, function()
		part("Island", nil, GROUND, function(mesh)
			floatingIsland(mesh, YARD_ISLAND, 22, 10 + i, flat, yardOutline(10 + i))
		end, nil, islandPaint(flat), 1024)
	end, x, y, degrees - 90)
	slab(`Plot{i}`, function()
		part("Slab", nil, PLOT, function(mesh)
			box(mesh, 0, 0, 0, 32, 32, 0.05)
		end, nil, 0)
	end, x, y, degrees - 90)
	slab(`Spoke{i}`, function()
		part("Road", nil, ROAD, function(mesh)
			box(mesh, 0, -20.5, 0, 6, 11, 0.1)
		end, nil, 0)
	end, x, y, degrees - 90)
	slab(`Bridge{i}`, function()
		part("Deck", nil, STEEL, function(mesh)
			box(mesh, 0, BRIDGE_MID, -0.2, 6, BRIDGE_LENGTH, 0.3)
		end, nil, bridgeDeck(degrees, x, y), 1024)
		part("Girders", nil, DARK_STEEL, function(mesh)
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
		end, nil, bridgeGirders(degrees, x, y), 1024)
		-- Railing posts spaced evenly so both ends get one, each bolted down
		-- on a base plate and capped.
		local postCount = math.ceil((BRIDGE_LENGTH - 0.3) / 2.5)
		local postGap = (BRIDGE_LENGTH - 0.3) / postCount
		part("Posts", nil, STEEL, function(mesh)
			for _, side in { -2.9, 2.9 } do
				for n = 0, postCount do
					local at = BRIDGE_TO + 0.15 + n * postGap
					box(mesh, side, at, -0.05, 0.36, 0.36, 0.06)
					box(mesh, side, at, 0.01, 0.14, 0.14, 1.27)
					box(mesh, side, at, 1.28, 0.2, 0.2, 0.06)
				end
			end
		end, nil, 0.4)
		-- Handrail on top, a thinner mid rail and a kick plate at the deck.
		part("Rail", nil, MARK, function(mesh)
			for _, side in { -2.9, 2.9 } do
				box(mesh, side, BRIDGE_MID, 1.16, 0.16, BRIDGE_LENGTH - 0.2, 0.12)
				box(mesh, side, BRIDGE_MID, 0.62, 0.08, BRIDGE_LENGTH - 0.3, 0.08)
				box(mesh, side + math.sign(side) * 0.1, BRIDGE_MID, -0.05, 0.04, BRIDGE_LENGTH - 0.3, 0.22)
			end
		end, nil, 0.3)
	end, x, y, degrees - 90)
	local coneX, coneY = polar(ROAD_INNER - 2, degrees + 6)
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
	local degrees = (i - 0.5) * 90
	local x, y = polar(ROAD_INNER - 2, degrees)
	place(`Light{i}`, buildStreetlightBroken, x, y, heightAt(x, y), degrees + 90)
end
