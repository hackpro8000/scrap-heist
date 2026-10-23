-- uses: ShippingContainer CarStack CrushedCar Barrels TyreStack JunkWall Dumpster Pallets StreetlightBroken TrafficCones ScrapTreeAntenna ScrapTreeExhaust ScrapTreeLamppost ScrapTreeRebar ScrapTreeSignpost ScrapPalm BushCans BushChainLink BushHubcap BushSpring BushWire RockBoulderPile RockCarCube RockConcrete RockEngine RockGearbox RockSlab GrassRebar GrassWire FlowerBulbs FlowerFan LogGirder LogPipe StumpDrum JunkMound OilPuddle CoolantPond ManholeCover HydrantLeaking TrafficLight SignBent BusStopWreck PhoneBooth ParkBench VendingMachine Mailbox ShoppingCarts BrickRuin BillboardFrame
-- Server Map: one server's whole map, centered on the origin. Eight yard
-- plots stand in a ring with their gates facing a central arena, joined to
-- it by a ring road and a spoke from each gate. The arena is the storm fight
-- ground and, between storms, the spawn plaza new players start on. Scrap props
-- fill the gaps between the yards.
-- Yards are only plot slabs here: the game drops the Yard Layout template
-- onto each one, so every yard is built from the same pieces.
-- Labels: Ground, Road, Arena, ArenaEdge, Ramps, Spawn, TyreMarks, Beacon, Plot1-Plot8, Spoke1-Spoke8,
-- Cover1-Cover8, Hatch1-Hatch4, Light1-Light4, Cones1-Cones8, and
-- Wedge<w><ring>_<n> props between the yards.
local YARD_RADIUS = 90
local ROAD_INNER, ROAD_OUTER = 50, 58
local ARENA_FLOOR, ARENA_DEPTH = 36, 3.5
local MAP_SIZE = 260

local GROUND = { 0.3, 0.27, 0.22 }
local ROAD = { 0.42, 0.41, 0.4 }
local CONCRETE = { 0.55, 0.54, 0.5 }
local MARK = { 0.85, 0.65, 0.15 }
local PLOT = { 0.36, 0.33, 0.28 }

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

-- Ground height. The arena, ring road, spokes and plots stay flat so the
-- slabs sit on it; everywhere else rolls in low hills that climb into a
-- ridge at the map edge. The arena sinks into a bowl whose sloped rim
-- meets the ring road, so the storm fight can be watched from the road.
local function smoothstep(low: number, high: number, value: number): number
	local t = math.clamp((value - low) / (high - low), 0, 1)
	return t * t * (3 - 2 * t)
end

local function heightAt(x: number, y: number): number
	local radius = math.sqrt(x * x + y * y)
	local hilly = smoothstep(ROAD_OUTER + 2, ROAD_OUTER + 9, radius)
	for i = 1, 8 do
		local plotX, plotY = polar(YARD_RADIUS, (i - 1) * 45)
		local along = (x * plotX + y * plotY) / YARD_RADIUS
		local across = math.abs(x * plotY - y * plotX) / YARD_RADIUS
		local spoke = if along > 0 and along < YARD_RADIUS then smoothstep(5, 10, across) else 1
		local plot = smoothstep(19, 27, math.max(math.abs(along - YARD_RADIUS), across))
		hilly = math.min(hilly, spoke, plot)
	end
	local edge = math.max(math.abs(x), math.abs(y))
	local rolling = 2.5 + 4 * math.noise(x / 23, y / 23, 0.5) + 1.5 * math.noise(x / 9, y / 9, 3.5)
	local ridge = smoothstep(108, MAP_SIZE / 2, edge) * (12 + 6 * math.noise(x / 30, y / 30, 7.5))
	local bowl = -ARENA_DEPTH * (1 - smoothstep(ARENA_FLOOR, ROAD_INNER - 2, radius))
	return bowl + hilly * math.max(rolling + ridge, -0.6)
end

local GROUND_CELLS = 80
slab("Ground", function()
	part("Surface", nil, GROUND, function(mesh)
		local rows = {}
		for j = 0, GROUND_CELLS do
			local y = -MAP_SIZE / 2 + MAP_SIZE * j / GROUND_CELLS
			rows[j] = {}
			for i = 0, GROUND_CELLS do
				local x = -MAP_SIZE / 2 + MAP_SIZE * i / GROUND_CELLS
				rows[j][i] = mesh:vertex(x, y, heightAt(x, y))
			end
		end
		for j = 0, GROUND_CELLS - 1 do
			for i = 0, GROUND_CELLS - 1 do
				mesh:face({ rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i] })
			end
		end
	end, true, 0)
end, 0, 0)
slab("Road", function()
	part("Ring", nil, ROAD, function(mesh)
		ring(mesh, 0, 0, 0, ROAD_INNER, ROAD_OUTER, 0.1, "z", 48)
	end, nil, 0)
end, 0, 0)
slab("Arena", function()
	part("Floor", nil, CONCRETE, function(mesh)
		cylinder(mesh, 0, 0, -ARENA_DEPTH, ARENA_FLOOR, 0.2, "z", 48)
	end, nil, 0)
end, 0, 0)
-- New players start on the ring around the crusher.
slab("Spawn", function()
	part("Pad", nil, MARK, function(mesh)
		ring(mesh, 0, 0, 0.2 - ARENA_DEPTH, 6.5, 8.5, 0.1, "z", 32)
	end, nil, 0)
end, 0, 0)

-- Tyre marks left by earlier fights: drift rings around the crusher and
-- looser drifts out between the cover. Each mark is a pair of solid treads
-- following a path with chevron lugs pressed into them and a pale smear where
-- the tyre slid sideways, heaviest at the apex and wearing away toward the
-- ends. All stay only a shade darker than the concrete.
local TYRE = { 0.51, 0.5, 0.465 }
local LUGS = { 0.48, 0.47, 0.44 }
local SMEAR = { 0.53, 0.52, 0.485 }
local TREAD_GAP, TREAD_WIDTH, BLOCK_LENGTH = 0.8, 0.42, 0.25
-- Fractal noise: octaves of math.noise, each twice as fine and half as strong.
local function fbm(x: number, y: number, z: number): number
	local total, amplitude = 0, 0.5
	for _ = 1, 4 do
		total += math.noise(x, y, z) * amplitude
		x, y, z, amplitude = x * 2, y * 2, z * 2, amplitude / 2
	end
	return total
end
local function tyreTrack(mesh, path: (number) -> (number, number), length: number, seed: number, layer: string)
	local z = 0.115 - ARENA_DEPTH + if layer == "Lugs" then 0.005 elseif layer == "Smear" then -0.003 else 0
	local steps = math.floor(length / BLOCK_LENGTH)
	-- A point on the path, pushed sideways by offset.
	local function at(step: number, offset: number): (number, number)
		local x0, y0 = path(step / steps)
		local x1, y1 = path((step + 0.1) / steps)
		local span = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
		return x0 - (y1 - y0) / span * offset, y0 + (x1 - x0) / span * offset
	end
	local function quad(a: number, b: number, c: number, d: number, inner: number, outer: number)
		local ax, ay = at(a, inner)
		local bx, by = at(b, inner)
		local cx, cy = at(c, outer)
		local dx, dy = at(d, outer)
		mesh:face({ mesh:vertex(dx, dy, z), mesh:vertex(cx, cy, z), mesh:vertex(bx, by, z), mesh:vertex(ax, ay, z) })
	end
	for side = -1, 1, 2 do
		local mid = side * TREAD_GAP
		local inner, outer = mid - TREAD_WIDTH / 2, mid + TREAD_WIDTH / 2
		for s = 0, steps - 1 do
			-- Heaviest at the apex of the drift, wearing away toward both ends.
			local press = math.sin(math.pi * (s + 0.5) / steps)
			if fbm(s / 14, side * 0.2, seed) > press * 0.6 - 0.2 then
				continue
			end
			if layer == "Lugs" then
				-- Chevron lugs either side of a bare centre rib.
				quad(s + 0.6, s + 0.2, s + 0.4, s + 0.8, inner + 0.03, mid - 0.04)
				quad(s + 0.8, s + 0.4, s + 0.2, s + 0.6, mid + 0.04, outer - 0.03)
			elseif layer == "Smear" then
				-- The tyre sliding sideways smears rubber out past its outer edge.
				local spread = TREAD_WIDTH * 1.4 * press
				if side > 0 then
					quad(s + 1, s, s, s + 1, outer, outer + spread)
				else
					quad(s + 1, s, s, s + 1, inner - spread, inner)
				end
			else
				quad(s + 1, s, s, s + 1, inner, outer)
			end
		end
	end
end
-- Each drift: centre radius and angle, turning radius, start and end angle.
local DRIFTS = {
	{ 0, 0, 11, 20, 190 },
	{ 0, 0, 12.5, 150, 330 },
	{ 0, 0, 11.8, 250, 400 },
	{ 0, 0, 14, 60, 140 },
	{ 24, 0, 6, 100, 260 },
	{ 22, 135, 7, -40, 110 },
	{ 25, 225, 5.5, 200, 330 },
	{ 23, 315, 6.5, 30, 170 },
}
slab("TyreMarks", function()
	for _, layer in { { "Smear", SMEAR }, { "Rubber", TYRE }, { "Lugs", LUGS } } do
		part(layer[1], nil, layer[2], function(mesh)
			for k, drift in DRIFTS do
				local cx, cy = polar(drift[1], drift[2])
				local radius, from, to = drift[3], drift[4], drift[5]
				tyreTrack(mesh, function(t)
					local x, y = polar(radius + 0.6 * math.sin(t * 5), from + (to - from) * t)
					return cx + x, cy + y
				end, math.rad(to - from) * radius, k, layer[1])
			end
		end, nil, 0)
	end
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

-- Each plot is turned so its gate (local -y) faces the arena.
for i = 1, 8 do
	local degrees = (i - 1) * 45
	local x, y = polar(YARD_RADIUS, degrees)
	slab(`Plot{i}`, function()
		part("Slab", nil, PLOT, function(mesh)
			box(mesh, 0, 0, 0, 32, 32, 0.05)
		end, nil, 0)
	end, x, y, degrees - 90)
	slab(`Spoke{i}`, function()
		part("Road", nil, ROAD, function(mesh)
			box(mesh, 0, -24, 0, 6, 17, 0.1)
		end, nil, 0)
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

-- Props between the yards. Each wedge has an inner cluster between the road
-- and the yards and an outer one out past the yard corners, laid out by
-- tangent offset u and radial offset v. Wedges rotate through the cluster
-- sets so neighbouring gaps look different.
local INNER = {
	{ { buildScrapTreeLamppost, -6, 0 }, { buildBushCans, -2, -3 }, { buildParkBench, 3, -2 }, { buildGrassWire, 6, 2 }, { buildFlowerBulbs, 0, 4 } },
	{ { buildHydrantLeaking, -5, -3 }, { buildRockConcrete, 2, 1 }, { buildBushSpring, 6, -2 }, { buildManholeCover, -1, -5 }, { buildGrassRebar, -6, 4 } },
	{ { buildBusStopWreck, 0, 1 }, { buildTrafficLight, -7, -3 }, { buildBushHubcap, 7, 3 }, { buildOilPuddle, 3, -4 } },
	{ { buildPhoneBooth, -5, 1 }, { buildMailbox, 0, -3 }, { buildVendingMachine, 5, 1 }, { buildFlowerFan, 0, 4 }, { buildBushWire, 7, -3 } },
}
local OUTER = {
	{ { buildScrapTreeAntenna, -5, 0 }, { buildScrapTreeRebar, 4, 6 }, { buildRockBoulderPile, 4, -3 }, { buildLogGirder, -3, 7 }, { buildBushChainLink, 0, -6 } },
	{ { buildScrapPalm, -4, 2 }, { buildCoolantPond, 4, 0 }, { buildRockSlab, -6, -5 }, { buildStumpDrum, 7, 7 }, { buildGrassWire, 0, 8 } },
	{ { buildScrapTreeExhaust, 5, 4 }, { buildJunkMound, -3, 1 }, { buildRockEngine, 6, -5 }, { buildLogPipe, -6, 8 }, { buildShoppingCarts, 1, -6 } },
	{ { buildBillboardFrame, 0, 6 }, { buildScrapTreeSignpost, -6, -2 }, { buildRockCarCube, 5, -3 }, { buildBrickRuin, -2, -5 }, { buildRockGearbox, 7, 3 }, { buildSignBent, 3, 8 } },
}
for w = 1, 8 do
	local degrees = (w - 0.5) * 45
	local angle = math.rad(degrees)
	local radialX, radialY = math.cos(angle), math.sin(angle)
	for r, cluster in { { INNER[(w - 1) % 4 + 1], 66 }, { OUTER[(w + 1) % 4 + 1], 84 } } do
		for n, prop in cluster[1] do
			local u, v = prop[2], prop[3] + cluster[2]
			local x = radialX * v - radialY * u
			local y = radialY * v + radialX * u
			place(`Wedge{w}{if r == 1 then "Inner" else "Outer"}_{n}`, prop[1], x, y, heightAt(x, y), degrees + n * 70)
		end
	end
end
