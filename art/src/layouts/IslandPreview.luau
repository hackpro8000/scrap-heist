-- uses: MainIsland CapsuleLoop RebirthPress BuildBay YardFence YardFenceHalf YardFooting YardGate PlotMarker HubShop HubTinkerer HubBeacon HubStage BeltCrossing
-- Island Preview: the floating-island server map from
-- art/concepts/server-map-island-sketch.png, built for preview renders only
-- (no kit, no upload). One round column island (MainIsland) centred on the
-- origin: an open hub with a minecart loop round it, eight fenced yards on a
-- ring near the rim with their gates facing the hub, and open ground
-- between, with a mesa between every other pair of yards, and a town of
-- stand-in blocks inside the belt.
-- Labels: Island, Plaza, Mesa1-Mesa4, Plot1-Plot8 with Yard1_<piece>-
-- Yard8_<piece>, CapsuleLoop, Spawn, Market, Tinkerer, Landmark, EventStage
-- and Crossing1-Crossing3.

local GROUND_DENSITY = 8
local YARD_DENSITY = 16
useTexelDensity(GROUND_DENSITY)

-- The island's turf top is level all over, at DECK; the plots lie on it.
local DECK = 2
local YARD_TIER = DECK
local PLOT_WIDTH, PLOT_DEPTH = 96, 112
-- Yards stand on a ring this far out, yard i at (i - 0.5) * 45 degrees.
local YARD_RADIUS = 210
-- The hub: paved plaza to HUB_PAVED, then the ring road to HUB_ROAD.
local HUB_PAVED, HUB_ROAD = 84, 101
-- Mesas at 0, 90, 180 and 270 degrees.
local MESA_RADIUS, MESA_HEIGHT = 250, 16
-- MainIsland's turf thickness: the column generator's GRASS_HEIGHT, 0.45 of
-- its DETAIL (0.34 * RADIUS / 4.5) for a RADIUS of 278.
local ISLAND_TURF = 0.45 * 0.34 * 278 / 4.5

local CONCRETE = { 0.55, 0.54, 0.5 }
local ROAD = { 0.42, 0.41, 0.4 }
local DIRT = { 0.47, 0.4, 0.31 }
local ROCK = { 0.5, 0.44, 0.36 }
local MARK = { 0.85, 0.65, 0.15 }
local YARD_DIRT = { 0.42, 0.36, 0.28 }

local function slab(label: string, build: () -> (), x: number, y: number, turn: number?)
	placeSlab(label, build, x, y, turn, function()
		finishParts()
		table.clear(parts)
	end)
end
local function placeModel(label: string, build: () -> (), x: number, y: number, z: number?, turn: number?, scale: number?)
	place(label, build, x, y, z, turn, nil, nil, scale)
	useTexelDensity(GROUND_DENSITY)
end

local function fbm(x: number, y: number, z: number): number
	local total, amplitude = 0, 0.5
	for _ = 1, 4 do
		total += math.noise(x, y, z) * amplitude
		x, y, z, amplitude = x * 2, y * 2, z * 2, amplitude / 2
	end
	return total
end
local function warpedFbm(x: number, y: number, z: number): number
	return fbm(x + 1.8 * fbm(x + 5.2, y + 1.3, z), y + 1.8 * fbm(x + 1.7, y + 9.2, z), z)
end
local function smooth(from: number, to: number, x: number): number
	local t = math.clamp((x - from) / (to - from), 0, 1)
	return t * t * (3 - 2 * t)
end

-- The island itself, its turf top at DECK.
placeModel("Island", buildMainIsland, 0, 0, DECK - ISLAND_TURF)

-- The hub's paving: concrete slabs on the plaza, asphalt on the ring road,
-- a hair over the turf.
slab("Plaza", function()
	chunkedPart("Paving", nil, CONCRETE, function(mesh)
		local STEPS = 128
		local rings = {}
		for r = 4, HUB_ROAD, 4 do
			table.insert(rings, r)
		end
		if rings[#rings] ~= HUB_ROAD then
			table.insert(rings, HUB_ROAD)
		end
		local middle = mesh:vertex(0, 0, DECK + 0.05)
		local grid = {}
		for a = 0, STEPS do
			local theta = 2 * math.pi * a / STEPS
			grid[a] = {}
			for k, r in rings do
				grid[a][k] = mesh:vertex(math.cos(theta) * r, math.sin(theta) * r, DECK + 0.05)
			end
		end
		for a = 0, STEPS - 1 do
			mesh:face({ middle, grid[a][1], grid[a + 1][1] })
			for k = 1, #rings - 1 do
				mesh:face({ grid[a][k], grid[a][k + 1], grid[a + 1][k + 1], grid[a + 1][k] })
			end
		end
	end, nil, function(x, y)
		local r = math.sqrt(x * x + y * y)
		if r < HUB_PAVED then
			local k = 1 + fbm(x / 4, y / 4, 120) * 0.12
			if math.min(x % 6, 6 - x % 6, y % 6, 6 - y % 6) < 0.08 then
				k -= 0.2
			end
			return CONCRETE[1] * k, CONCRETE[2] * k, CONCRETE[3] * k
		end
		local k = 1 + fbm(x / 2, y / 2, 50) * 0.15
		if r > HUB_ROAD - 1 or (r > HUB_PAVED and r < HUB_PAVED + 1) then
			return MARK[1], MARK[2], MARK[3]
		end
		return ROAD[1] * k, ROAD[2] * k, ROAD[3] * k
	end, true)
end, 0, 0)

-- Rock in bands, streaked with rust where water ran down.
local function rockColour(x: number, y: number, z: number): (number, number, number)
	local band = 0.82 + 0.18 * math.sin(z * 0.9 + fbm(x / 10, y / 10, 80) * 5)
	local streak = smooth(0.15, 0.35, fbm(x / 3, y / 3, z / 20 + 81))
	local red, green, blue = ROCK[1] * band, ROCK[2] * band, ROCK[3] * band
	return red + (0.5 - red) * streak * 0.6, green + (0.27 - green) * streak * 0.6, blue + (0.15 - blue) * streak * 0.6
end

-- A mesa between each pair of yards: a rock butte with steep banded sides
-- and a dusty flat top, its outline wobbling round MESA_TOP.
local MESA_TOP = 18
for k = 1, 4 do
	local degrees = (k - 1) * 90
	slab(`Mesa{k}`, function()
		part("Rock", nil, ROCK, function(mesh)
			local STEPS = 48
			-- Out from the middle as fractions of the outline, with heights.
			local PROFILE = { { 0.35, MESA_HEIGHT }, { 0.7, MESA_HEIGHT }, { 1, MESA_HEIGHT - 0.5 }, { 1.06, MESA_HEIGHT * 0.6 }, { 1.12, MESA_HEIGHT * 0.25 }, { 1.3, -1 } }
			local middle = mesh:vertex(0, 0, DECK + MESA_HEIGHT)
			local grid = {}
			for a = 0, STEPS - 1 do
				local theta = 2 * math.pi * a / STEPS
				local c, s = math.cos(theta), math.sin(theta)
				local outline = MESA_TOP * (1 + 0.18 * math.noise(c * 1.7, s * 1.7, k * 3) + 0.08 * math.noise(c * 5, s * 5, k * 3 + 1))
				grid[a] = {}
				for n, step in PROFILE do
					local r = outline * step[1] * (1 + 0.04 * math.noise(c * 9, s * 9, n + k))
					grid[a][n] = mesh:vertex(c * r, s * r, DECK + step[2])
				end
			end
			for a = 0, STEPS - 1 do
				local b = (a + 1) % STEPS
				mesh:face({ middle, grid[a][1], grid[b][1] })
				for n = 1, #PROFILE - 1 do
					mesh:face({ grid[a][n], grid[a][n + 1], grid[b][n + 1], grid[b][n] })
				end
			end
		end, nil, function(x, y, z, _nx, _ny, nz)
			if nz > 0.85 then
				local k = 1 + fbm(x / 5, y / 5, 70) * 0.2
				return DIRT[1] * k, DIRT[2] * k, DIRT[3] * k
			end
			return rockColour(x, y, z)
		end, nil, nil, true)
	end, math.cos(math.rad(degrees)) * MESA_RADIUS, math.sin(math.rad(degrees)) * MESA_RADIUS)
end

-- Packed dirt for a yard's floor, as on the server map's plots.
local function yardGround(u: number, v: number, seed: number): (number, number, number)
	local patch = warpedFbm(u / 9, v / 9, seed + 2)
	if patch > 0.2 then
		local k = 1 + fbm(u, v, seed + 3) * 0.12
		if math.min(u % 4, 4 - u % 4, v % 4, 4 - v % 4) < 0.06 then
			k -= 0.25
		end
		return 0.56 * k, 0.55 * k, 0.52 * k
	end
	local k = 1 + fbm(u / 3, v / 3, seed) * 0.2 + fbm(u * 2, v * 2, seed + 1) * 0.08
	if patch > 0.17 then
		k -= 0.2
	end
	return YARD_DIRT[1] * k, YARD_DIRT[2] * k, YARD_DIRT[3] * k
end

-- A yard's shell on the plot at (x, y), turned so its gate (local -y) faces
-- the hub: fence panels with their footings, the gate and the plot marker.
local function yardShell(index: number, x: number, y: number, turn: number)
	local c, s = math.cos(math.rad(turn)), math.sin(math.rad(turn))
	local function piece(name: string, build: () -> (), scale: number, px: number, py: number, pz: number?, pturn: number?, stretch: number?, axis: string?)
		place(`Yard{index}_{name}`, build, x + px * c - py * s, y + px * s + py * c, YARD_TIER + (pz or 0), turn + (pturn or 0), stretch, axis, scale)
		useTexelDensity(GROUND_DENSITY)
	end
	local FENCE = 1.5
	local sidePanel = PLOT_DEPTH / 9
	for n = 1, 8 do
		local px = -PLOT_WIDTH / 2 + (n - 0.5) * 12
		piece(`FenceBack{n}`, buildYardFence, FENCE, px, PLOT_DEPTH / 2, 0, 180)
		piece(`FootingBack{n}`, buildYardFooting, FENCE, px, PLOT_DEPTH / 2)
	end
	for n = 1, 9 do
		local py = -PLOT_DEPTH / 2 + (n - 0.5) * sidePanel
		piece(`FenceLeft{n}`, buildYardFence, FENCE, -PLOT_WIDTH / 2, py, 0, 270, sidePanel / 12)
		piece(`FenceRight{n}`, buildYardFence, FENCE, PLOT_WIDTH / 2, py, 0, 90, sidePanel / 12)
		piece(`FootingLeft{n}`, buildYardFooting, FENCE, -PLOT_WIDTH / 2, py, 0, 90, sidePanel / 12)
		piece(`FootingRight{n}`, buildYardFooting, FENCE, PLOT_WIDTH / 2, py, 0, 90, sidePanel / 12)
	end
	for n, side in { -1, 1 } do
		for k = 1, 3 do
			piece(`FenceFront{(n - 1) * 3 + k}`, buildYardFence, FENCE, side * (k * 12), -PLOT_DEPTH / 2)
			piece(`FootingFront{(n - 1) * 3 + k}`, buildYardFooting, FENCE, side * (k * 12), -PLOT_DEPTH / 2)
		end
		piece(`FenceFrontHalf{n}`, buildYardFenceHalf, FENCE, side * 45, -PLOT_DEPTH / 2)
		piece(`FootingFrontHalf{n}`, buildYardFooting, FENCE, side * 45, -PLOT_DEPTH / 2, 0, 0, 0.5)
	end
	piece("Gate", buildYardGate, FENCE, 0, -PLOT_DEPTH / 2)
	piece("PlotMarker", buildPlotMarker, FENCE, 9, -PLOT_DEPTH / 2 - 2.25)
	-- The yard's remade props on their starter spots (STARTER_LAYOUT in
	-- Config/Yard), turned to face into the yard: the fence is too close in
	-- front of them for a player to stand there.
	piece("Bay", buildBuildBay, 1, -19, -49, 0, 180)
	piece("Press", buildRebirthPress, 1, 18, -48, 0, 180)
end

for i = 1, 8 do
	local degrees = (i - 0.5) * 45
	local x, y = math.cos(math.rad(degrees)) * YARD_RADIUS, math.sin(math.rad(degrees)) * YARD_RADIUS
	local turn = degrees - 90
	local c, s = math.cos(math.rad(turn)), math.sin(math.rad(turn))
	slab(`Plot{i}`, function()
		useTexelDensity(YARD_DENSITY)
		chunkedPart("Ground", nil, YARD_DIRT, function(mesh)
			box(mesh, 0, 0, YARD_TIER - 0.3, PLOT_WIDTH, PLOT_DEPTH, 0.33)
		end, nil, function(px, py)
			return yardGround((px - x) * c + (py - y) * s, (py - y) * c - (px - x) * s, 200 + i * 7)
		end, true)
	end, x, y, turn)
	useTexelDensity(GROUND_DENSITY)
	yardShell(i, x, y, turn)
end

-- The capsule belt and its factory (CapsuleLoop), on the plaza.
placeModel("CapsuleLoop", buildCapsuleLoop, 0, 0, DECK + 0.05)

-- New players start on a ring painted on the plaza.
slab("Spawn", function()
	part("Pad", nil, MARK, function(mesh)
		ring(mesh, 0, 0, DECK + 0.05, 8, 9, 0.1, "z", 48)
	end, nil, 0)
end, math.cos(math.rad(250)) * 45, math.sin(math.rad(250)) * 45)

-- The town, inside the belt. Each piece's front (-y) faces the middle.
local TOWN_Z = DECK + 0.05
placeModel("Market", buildHubShop, 0, 44, TOWN_Z)
placeModel("Tinkerer", buildHubTinkerer, -46, -14, TOWN_Z, 107)
placeModel("Landmark", buildHubBeacon, 0, 0, TOWN_Z)
placeModel("EventStage", buildHubStage, math.cos(math.rad(-38)) * 46, math.sin(math.rad(-38)) * 46, TOWN_Z, 232)

-- Crossings over the belt, whose middle runs at radius 72.
for n, degrees in { 90, 210, 300 } do
	placeModel(`Crossing{n}`, buildBeltCrossing, math.cos(math.rad(degrees)) * 72, math.sin(math.rad(degrees)) * 72, TOWN_Z, degrees)
end
