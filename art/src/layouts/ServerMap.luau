-- uses: ShippingContainer CarStack CrushedCar Barrels TyreStack JunkWall Dumpster Pallets StreetlightBroken TrafficCones ScrapTreeAntenna ScrapTreeExhaust ScrapTreeLamppost ScrapTreeRebar ScrapTreeSignpost ScrapPalm BushCans BushChainLink BushHubcap BushSpring BushWire RockBoulderPile RockCarCube RockConcrete RockEngine RockGearbox RockSlab GrassRebar GrassWire FlowerBulbs FlowerFan LogGirder LogPipe StumpDrum JunkMound OilPuddle CoolantPond ManholeCover HydrantLeaking TrafficLight SignBent BusStopWreck PhoneBooth ParkBench VendingMachine Mailbox ShoppingCarts BrickRuin BillboardFrame
-- Server Map: one server's whole map, centered on the origin. Eight yard
-- plots stand in a ring with their gates facing a central arena, joined to
-- it by a ring road and a spoke from each gate. The arena is the storm fight
-- ground and, between storms, the spawn plaza new players start on. Scrap props
-- fill the gaps between the yards.
-- Yards are only plot slabs here: the game drops the Yard Layout template
-- onto each one, so every yard is built from the same pieces.
-- Labels: Ground, Road, Arena, Spawn, Plot1-Plot8, Spoke1-Spoke8,
-- Cover1-Cover8, Light1-Light4, Cones1-Cones8, and
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
slab("Spawn", function()
	part("Pad", nil, MARK, function(mesh)
		cylinder(mesh, 0, 0, 0.2 - ARENA_DEPTH, 6, 0.1, "z", 24)
	end, nil, 0)
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
