-- uses: MainIsland CapsuleLoop RebirthPress BuildBay YardFence YardFenceHalf YardFooting YardGate PlotMarker HubShop HubTinkerer HubBeacon HubStage BeltCrossing JunkMound ScrapPalm ScrapTreeAntenna ScrapTreeExhaust ScrapTreeLamppost ScrapTreeRebar ScrapTreeSignpost RockBoulderPile HubSectionA HubSectionB HubSectionEnd YardIsland PadKitchen PadGarage PadGadget ScrapCrate CapsuleScrap CapsuleSalvaged CapsuleRefurbished CapsuleFactory CapsulePrecision CapsulePrototype CapsuleSecret JunkrotCanettoRustini JunkrotSpoonzoBentolo JunkrotKettlinaDentata JunkrotTyroFlattino JunkrotBoltoloLonelo JunkrotHubcappaWobbla JunkrotRemotinoMuto JunkrotCabloTanglino JunkrotBulboFulminato JunkrotCrumboPoppalot JunkrotPannettoPatchato JunkrotBlendroCigolante JunkrotJackoloCrickato JunkrotOilcannaGluglu JunkrotMuffleroTossetto JunkrotRadioloFruscio JunkrotFanettoWobblino JunkrotClockoTictacco JunkrotFrostboxGelatone JunkrotMicrondoBippetto JunkrotMixerellaVroom JunkrotMopaMopetta JunkrotDrilloTrapanino JunkrotGrindellaScintilla JunkrotTelefonoRingaling JunkrotTypewrittoClackini JunkrotCamerinoFlashetto JunkrotDrippiDroppi JunkrotDingDingDingDongo JunkrotGrindoBeanbasher JunkrotAirfryoCroccante JunkrotDishwashinoSplashetto JunkrotLawnmowoRuggito JunkrotLeafblowaWhooshini JunkrotPressurwashoSprizzo JunkrotConsoloJoypaddino JunkrotSpeakeroneBoomba JunkrotRobovaccoGirotondo JunkrotClankClankClankScrapur JunkrotVrrVrrPatatrim JunkrotChimneyziniSpannerini JunkrotRusteliRustela JunkrotBallerinaTincuppina JunkrotTrashaleroTrashala JunkrotSockettoSeiSette JunkrotChefbotPrecisio JunkrotSousvideSilvano JunkrotKnifeblockSlicetta JunkrotTorquoWrenchelli JunkrotLaserlevelLineo JunkrotWeldettaSparkalot JunkrotDronettoBuzzatti JunkrotTickworthPocketti JunkrotHeadphonoBassimo JunkrotGascaniniHonkini JunkrotPercolattoNinjatto JunkrotBoilerdiroCrockpotilo JunkrotSnackomaticPrototipo JunkrotHoverbikkoZoomzoom JunkrotHolofonoShimmerra JunkrotLaVacuumaSaturnita JunkrotTheMonolito JunkrotUnitZero ProofToaster ProofKettle ProofShark
-- include: HandFinish
-- Server Map: the floating-island server map from
-- art/concepts/server-map-island-sketch.png. Replaced the Scrap Line layout
-- (git history, before 2026-11-10). The island was drafted as IslandPreview,
-- which stays as the preview layout
-- (no kit, no upload). One round column island (MainIsland) centred on the
-- origin: an open hub with a minecart loop round it, eight fenced yards on a
-- ring near the rim with their gates facing the hub, and open ground
-- between with rough ground in the gaps, and a town inside the belt.
-- Labels: Island, Plaza, Rough1-Rough10, Streets, Plot1-Plot8 with Yard1_<piece>-
-- Yard8_<piece>, CapsuleLoop, Spawn, Market, Tinkerer, Landmark, EventStage
-- and Crossing1-Crossing8.

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
-- MainIsland's turf thickness: the column generator's GRASS_HEIGHT, 0.45 of
-- its DETAIL (0.34 * RADIUS / 4.5) for a RADIUS of 278.
local ISLAND_TURF = 0.45 * 0.34 * 278 / 4.5

local CONCRETE = { 0.55, 0.54, 0.5 }
local ROAD = { 0.42, 0.41, 0.4 }
local DIRT = { 0.47, 0.4, 0.31 }
local ROCK = { 0.56, 0.5, 0.42 }
local MARK = { 0.85, 0.65, 0.15 }
local YARD_DIRT = { 0.42, 0.36, 0.28 }

local function fbm(x: number, y: number, z: number): number
	local total, amplitude = 0, 0.5
	for _ = 1, 4 do
		total += math.noise(x, y, z) * amplitude
		x, y, z, amplitude = x * 2, y * 2, z * 2, amplitude / 2
	end
	return total
end
-- Hand coats for the layout's own props. Anything not listed keeps its paint.
local SLAB_COATS = {
	Stones = "rock",
	Grit = "rock",
	Tyre = "rock",
	PipeStone = "rock",
	Pipe = "metal",
	Slab = "rock",
	SlabStone = "rock",
	Walks = "rock",
	Tracks = "rock",
	Kerbs = "rock",
	Drains = "metal",
	Conduits = "metal",
	LampPosts = "metal",
}
local ROCK_PARTS = { Stones = true, Grit = true, PipeStone = true, SlabStone = true }
-- How far the fence footing stands out past the plot's edge.
local FOOTING_REACH = 0.75
-- What stands on the sand in the slab being built: { x, y, radius x, radius y, seed }.
local groundFeet = {}
local SHADE = { 0.13, 0.09, 0.07 }
-- The island's top is flat at DECK (measured in Studio: sand 2.00, yard dirt
-- 2.03); the shadow sheets lie as close above it as they can without
-- fighting it, never more than 0.03 studs off the ground.
local SHADE_Z = DECK + 0.03
-- A contact shadow is ambient occlusion, not a cast shadow (the game lights the
-- world itself): a thin stepped line hugging the foot, whatever the object's
-- size. `past` is studs outside the foot's edge.
local function shadeTier(past: number): number
	return if past < -0.7 then 0 elseif past < 0.25 then 0.6 elseif past < 0.55 then 0.38 elseif past < 0.85 then 0.16 else 0
end
-- Studs from a point to the edge of an elliptical foot, negative inside it.
local function pastFoot(dx: number, dy: number, foot): number
	local rim = foot[6]
	if rim then
		local side = (math.atan2(dy, dx) / (2 * math.pi) % 1) * #rim
		local low = math.floor(side)
		local reach = rim[low + 1] + (rim[(low + 1) % #rim + 1] - rim[low + 1]) * (side - low)
		return math.sqrt(dx * dx + dy * dy) - reach
	end
	local out = math.sqrt((dx / foot[3]) ^ 2 + (dy / foot[4]) ^ 2)
	if out < 0.001 then
		return -math.huge
	end
	return (out - 1) / out * math.sqrt(dx * dx + dy * dy)
end
-- A see-through sheet on the sand, darkened round each of groundFeet. Painted
-- flat, so it skips the bake: `emissive` 0 glows not at all.
local function shadeGroundFeet()
	if #groundFeet == 0 then
		return nil
	end
	local feet = table.clone(groundFeet)
	table.clear(groundFeet)
	local left, right, bottom, top = math.huge, -math.huge, math.huge, -math.huge
	for _, foot in feet do
		left, right = math.min(left, foot[1] - foot[3] - 1.2), math.max(right, foot[1] + foot[3] + 1.2)
		bottom, top = math.min(bottom, foot[2] - foot[4] - 1.2), math.max(top, foot[2] + foot[4] + 1.2)
	end
	part("GroundShade", nil, SHADE, function(mesh)
		mesh:face({ mesh:vertex(left, bottom, SHADE_Z), mesh:vertex(right, bottom, SHADE_Z), mesh:vertex(right, top, SHADE_Z), mesh:vertex(left, top, SHADE_Z) })
	end, nil, function(px: number, py: number)
		local dark = 0
		for _, foot in feet do
			local dx, dy = px - placeX - foot[1], py - placeY - foot[2]
			dark = math.max(dark, shadeTier(pastFoot(dx, dy, foot) + 0.08 * fbm(dx * 1.4, dy * 1.4, foot[5])))
		end
		return SHADE[1], SHADE[2], SHADE[3], dark
	end, nil, 0, true)
	return feet
end
local function slab(label: string, build: () -> (), x: number, y: number, turn: number?)
	placeSlab(label, build, x, y, turn, function()
		local feet = shadeGroundFeet()
		local untouched = {}
		for _, entry in parts do
			if ROCK_PARTS[entry.name] then
				-- Stone edges catch the light in bold, wide strokes, over a light base.
				entry.lit, entry.wide, entry.gradient = 2.2, 1.5, 0.15
			end
			if feet and ROCK_PARTS[entry.name] then
				-- Bands run up each rock on its own, from the turf to its top.
				entry.bandDepth = function(x: number, y: number, z: number): number
					local nearest, best = feet[1], math.huge
					for _, foot in feet do
						local dx, dy = x - placeX - foot[1], y - placeY - foot[2]
						local reach = (dx * dx + dy * dy) / (foot[3] * foot[3])
						if reach < best then
							nearest, best = foot, reach
						end
					end
					-- Eased, so a rock's foot stays stone rather than going black.
					return 1 - math.clamp((z - SHADE_Z) / (nearest[3] * 1.4), 0, 1)
				end
			end
			if not SLAB_COATS[entry.name] then
				untouched[entry.name] = true
			end
		end
		handFinish(SLAB_COATS, untouched, { rock = "rock", metal = "propMetal" })
		finishParts()
		table.clear(parts)
	end)
end
local function placeModel(label: string, build: () -> (), x: number, y: number, z: number?, turn: number?, scale: number?)
	place(label, build, x, y, z, turn, nil, nil, scale)
	useTexelDensity(GROUND_DENSITY)
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
		return ROAD[1] * k, ROAD[2] * k, ROAD[3] * k
	end, true)
end, 0, 0)

-- Rock in bands, streaked with rust where water ran down.
local function rockColour(x: number, y: number, z: number): (number, number, number)
	local band = 0.82 + 0.18 * math.sin(z * 0.9 + fbm(x / 10, y / 10, 80) * 5)
	local streak = smooth(0.15, 0.35, fbm(x / 3, y / 3, z / 20 + 81))
	local red, green, blue = ROCK[1] * band, ROCK[2] * band, ROCK[3] * band
	return red + (0.56 - red) * streak * 0.5, green + (0.45 - green) * streak * 0.5, blue + (0.28 - blue) * streak * 0.5
end

-- A box running from (x0, y0) to (x1, y1), its top rising from z0 to z1, its
-- sides down to `bottom`: a ramp when the ends differ, a kerb or walk if not.
local function run(mesh, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, half: number, bottom: number)
	local dx, dy = x1 - x0, y1 - y0
	local length = math.sqrt(dx * dx + dy * dy)
	local nx, ny = -dy / length * half, dx / length * half
	local a = mesh:vertex(x0 - nx, y0 - ny, z0)
	local b = mesh:vertex(x1 - nx, y1 - ny, z1)
	local c = mesh:vertex(x1 + nx, y1 + ny, z1)
	local d = mesh:vertex(x0 + nx, y0 + ny, z0)
	local a0 = mesh:vertex(x0 - nx, y0 - ny, bottom)
	local b0 = mesh:vertex(x1 - nx, y1 - ny, bottom)
	local c0 = mesh:vertex(x1 + nx, y1 + ny, bottom)
	local d0 = mesh:vertex(x0 + nx, y0 + ny, bottom)
	mesh:face({ a, b, c, d })
	mesh:face({ a0, b0, b, a })
	mesh:face({ c0, d0, d, c })
	mesh:face({ d0, a0, a, d })
	mesh:face({ b0, c0, c, b })
end

-- A lumpy rock half sunk in the ground.
local function boulder(mesh, cx: number, cy: number, cz: number, size: number, seed: number, heightScale: number?)
	local SIDES = 11
	local LEVELS = { { 0.5, 0.74 }, { 0.82, 0.48 }, { 1, 0.08 }, { 0.92, -0.6 } }
	-- Squat or tall, broad or narrow, and split along up to two flat planes.
	local stretchX = 0.7 + 0.6 * (0.5 + math.noise(seed, 1.3, 2.7))
	local stretchY = 0.7 + 0.6 * (0.5 + math.noise(seed, 4.1, 2.7))
	local stretchZ = (0.55 + 0.6 * (0.5 + math.noise(seed, 7.9, 2.7))) * (heightScale or 1)
	local cuts = {}
	for k = 1, 2 do
		-- On a big rock the two breaks face opposite ways and run near vertical,
		-- right down to the ground, so no approach sees a plain dome.
		local yaw = if size > 2.5 then seed * 1.7 + (k - 1) * 2.1 else seed * 1.7 + k * 2.1
		local tilt = if size > 2.5 then 0.05 + (k - 1) * 0.12 else 0.25 + 0.35 * (0.5 + math.noise(seed, k, 5.1))
		table.insert(cuts, { math.cos(yaw) * math.cos(tilt), math.sin(yaw) * math.cos(tilt), math.sin(tilt), size * (0.62 + 0.2 * (0.5 + math.noise(seed, k, 9.3))) })
	end
	local function shaped(x: number, y: number, z: number): (number, number, number)
		x, y, z = x * stretchX, y * stretchY, z * stretchZ
		for _, cut in cuts do
			local over = x * cut[1] + y * cut[2] + z * cut[3] - cut[4]
			if over > 0 then
				x, y, z = x - cut[1] * over, y - cut[2] * over, z - cut[3] * over
			end
		end
		return cx + x, cy + y, cz + z
	end
	local function vertex(x: number, y: number, z: number)
		return mesh:vertex(shaped(x, y, z))
	end
	local top = vertex(0, 0, size * 0.86)
	local grid = {}
	-- How far the rock reaches at turf height, side by side, for its contact line.
	local rim, widest = table.create(SIDES, 0), 0
	for a = 0, SIDES - 1 do
		local theta = 2 * math.pi * a / SIDES
		local c, s = math.cos(theta), math.sin(theta)
		grid[a] = {}
		local aboveX, aboveY, aboveZ
		for n, level in LEVELS do
			local r = size * level[1] * (1 + 0.3 * math.noise(c * 2.3, s * 2.3, seed + n) + 0.32 * math.noise(c * 7, s * 7, seed + n * 2))
			local h = size * level[2] * (1 + 0.2 * math.noise(c * 3, s * 3, seed - n))
			grid[a][n] = vertex(c * r, s * r, h)
			local x, y, z = shaped(c * r, s * r, h)
			-- Traced a little above the turf, so the line hugs what shows of a
			-- half-buried stone rather than its wider outline underground.
			local trace = SHADE_Z + 0.3
			if n > 1 and aboveX and aboveZ >= trace and z < trace then
				local t = (aboveZ - trace) / (aboveZ - z)
				local reach = math.sqrt((aboveX + (x - aboveX) * t - cx) ^ 2 + (aboveY + (y - aboveY) * t - cy) ^ 2)
				rim[a + 1] = reach
				widest = math.max(widest, reach)
			end
			aboveX, aboveY, aboveZ = x, y, z
		end
	end
	-- A stone wholly under the turf has nothing to shade.
	if widest > 0 then
		table.insert(groundFeet, { cx, cy, widest, widest, seed, rim })
	end
	for a = 0, SIDES - 1 do
		local b = (a + 1) % SIDES
		mesh:face({ top, grid[a][1], grid[b][1] })
		for n = 1, #LEVELS - 1 do
			mesh:face({ grid[a][n], grid[a][n + 1], grid[b][n + 1], grid[b][n] })
		end
	end
end

-- Rough ground in the gaps between yards: a rock outcrop, smaller clumps along
-- the gap and scrap heaps, placed by hand so no two gaps match. Each is
-- { bearing, distance, half length, height, how far the outcrop sits off the
-- gap's centre line, its radius }: centred between the fences and small enough
-- to leave 8 studs to walk past on each side, its clumps clear of the fences.
local ROUGH_SITES = {
	{ 2, 178, 30, 3.30, -6.5, 13.0 },
	{ 45, 152, 22, 3.85, 0.0, 13.0 },
	{ 88, 190, 34, 4.95, 7.0, 13.0 },
	{ 131, 235, 26, 2.75, 17.5, 13.0 },
	{ 138, 160, 20, 2.20, -7.0, 8.0 },
	{ 183, 205, 32, 4.40, -11.5, 13.0 },
	{ 223, 172, 22, 3.30, 6.0, 11.0 },
	{ 227, 248, 24, 2.75, -9.5, 13.0 },
	{ 272, 220, 30, 5.50, -8.0, 13.0 },
	{ 318, 185, 26, 3.30, -10.5, 13.0 },
}

for n, site in ROUGH_SITES do
	local bearing, distance, long, tall, shift, radius = site[1], site[2], site[3], site[4], site[5], site[6]
	local x, y = math.cos(math.rad(bearing)) * distance, math.sin(math.rad(bearing)) * distance
	local ux, uy = math.cos(math.rad(bearing)), math.sin(math.rad(bearing))
	local function onGap(along: number, across: number): (number, number)
		return ux * along - uy * across, uy * along + ux * across
	end
	slab(`Rough{n}`, function()
		part("Stones", nil, ROCK, function(mesh)
			-- The outcrop, with chips and loose stone bedding its foot.
			local middleX, middleY = onGap(0, shift)
			local main = math.min(2.2 * tall + 1.5, radius / 1.5)
			-- Each gap's outcrop is its own kind: one big rock, a split rock wedged
			-- against its other half, or a low cluster of three.
			local kind = n % 3
			if kind == 1 then
				for s = 1, 3 do
					local a = s * 2.1 + n * 0.7
					boulder(mesh, middleX + math.cos(a) * main * 0.62, middleY + math.sin(a) * main * 0.62, DECK - 0.3, main * (0.82 - s * 0.1), n * 13 + s, 0.7)
				end
			else
				boulder(mesh, middleX, middleY, DECK - 0.3, if kind == 0 then main * 0.92 else main, n * 13, if kind == 0 then 1.25 else 1.6)
			end
			if kind == 0 then
				local a = n * 0.9
				boulder(mesh, middleX + math.cos(a) * main * 0.8, middleY + math.sin(a) * main * 0.8, DECK - 0.3, main * 0.68, n * 13 + 5, 0.75)
			end
			-- Chips bunched on one side of it, the way they rolled.
			for s = 2, (if n % 4 == 0 then 1 else 7) do
				local a = n * 1.7 + (s - 4.5) * 0.42
				local spread = math.min(main * 0.9, radius - 2.5)
				boulder(mesh, middleX + math.cos(a) * spread, middleY + math.sin(a) * spread, DECK - 0.2, 0.8 + (s * 5 + n) % 3 * 0.45 + (if s % 3 == 0 then 1.2 else 0), s * 13 + n)
			end
			for s = 1, 10 do
				local bunch = if s <= 7 then n * 1.7 else n * 1.7 + 2.4
				local a = bunch + (s * 3 % 7 - 3) * 0.11
				local spread = main * 1.02 + (s * 5 % 4) * 0.5
				boulder(mesh, middleX + math.cos(a) * spread, middleY + math.sin(a) * spread, DECK - 0.1, 0.45 + (s * 7 % 5) * 0.3, s * 3 + n * 7)
			end
			-- A small clump beside the outcrop, and one far off with empty ground
			-- between them, so a gap reads as two groups, not a row.
			local side = if n % 2 == 0 then 1 else -1
			local nearX, nearY = onGap(side * (radius + 1), shift - side * radius * 0.6)
			for s = 1, (if n % 3 == 1 then 0 else 3 + n % 3) do
				local a = s * 2.4 + n
				local size = if s == 1 then 1.8 + (n % 3) * 0.5 else 0.6 + ((s * 5 + n) % 4) * 0.35
				boulder(mesh, nearX + math.cos(a) * (s - 1) * 1.3, nearY + math.sin(a) * (s - 1) * 1.3, DECK - 0.1, size, s * 7 + n * 11)
			end
			if n % 3 ~= 0 then
				local farX, farY = onGap(-side * (long * 0.95 + (n % 4) * 1.5), shift + side * radius * (0.3 + (n % 3) * 0.14))
				for s = 1, 3 + n % 2 do
					local a = s * 2.4 + 2 + n
					local size = if s == 1 then 2.1 + (n % 3) * 0.6 else 0.7 + ((s * 5 + n) % 4) * 0.4
					boulder(mesh, farX + math.cos(a) * (s - 1) * 1.5, farY + math.sin(a) * (s - 1) * 1.5, DECK - 0.1, size, s * 7 + n * 17)
				end
			end
		end, nil, rockColour, nil, nil, true)
	end, x, y)
end

-- A finished scrap model in each gap, none repeated side by side, placed where
-- the first group's heap belongs: beside the outcrop, clear of it and the fences.
-- A site marked false is left to its rocks.
local SITE_SCRAP = { buildScrapTreeRebar, buildScrapTreeExhaust, false, buildJunkMound, buildScrapPalm, buildRockBoulderPile, buildScrapTreeSignpost, buildRockBoulderPile, buildScrapTreeAntenna, buildScrapTreeLamppost }
-- Each model's size at its site: scrap built near player height, made to stand
-- up against a 5.5 stud player and the rocks round it.
-- Each model's foot on the sand before scaling: radius, and how far it sits off
-- the model's origin along its x. False where a ring wouldn't follow the edge.
local SITE_FOOT = { 0.9, 1.35, false, false, 2.1, false, 1.35, false, 1, 1.5 }
local SITE_FOOT_OFF = { 0, 0, 0, 0, 1, 0, 0, 0, 0, 0 }
local SITE_SCALE = { 1.8, 1.4, 2.5, 2.8, 1.6, 2.2, 1.4, 2.8, 1.4, 1.3 }
for n, site in ROUGH_SITES do
	if not SITE_SCRAP[n] then
		continue
	end
	local bearing, distance, shift, radius = site[1], site[2], site[5], site[6]
	local ux, uy = math.cos(math.rad(bearing)), math.sin(math.rad(bearing))
	local side = if n % 2 == 0 then 1 else -1
	-- The canister tree and the palm stand a little off their rocks' sight lines.
	local reach = ({ 4.5, 4.6, 8, 10.5, 9.6, 6.6, 4.2, 8.8, 3.8, 3.9 })[n]
	local along, across = side * (radius + 7 + reach), shift - side * radius * 0.25 + (if n == 2 then 7 elseif n == 5 then -4 else 0)
	local x = ux * distance + ux * along - uy * across
	local y = uy * distance + uy * along + ux * across
	placeModel(`RoughScrap{n}`, SITE_SCRAP[n], x, y, DECK, n * 47, SITE_SCALE[n])
	-- Heaps have uneven skirts a ring can't follow; their dark base does the job.
	if SITE_FOOT[n] then
		slab(`RoughShade{n}`, function()
			local foot, off, turn = SITE_FOOT[n] * SITE_SCALE[n], SITE_FOOT_OFF[n] * SITE_SCALE[n], math.rad(n * 47)
			table.insert(groundFeet, { math.cos(turn) * off, math.sin(turn) * off, foot, foot, n * 3 })
		end, x, y)
	end
	-- Some models stand bare; the rest get a stone or two of real size, half
	-- sunk, with grit bunched on one side.
	if n % 3 ~= 1 then
		slab(`RoughFoot{n}`, function()
			part("Grit", nil, ROCK, function(mesh)
				-- Clear of the model standing here, whatever its footprint.
				local reach = ({ 4.5, 4.6, 8, 10.5, 9.6, 6.6, 4.2, 7.9, 3.8, 3.9 })[n]
				boulder(mesh, math.cos(n * 2.1) * (reach + 1.2), math.sin(n * 2.1) * (reach + 1.2), DECK - 0.5, 0.9 + (n % 3) * 0.3, n * 9)
				for s = 1, 5 + n % 4 do
					local a = n * 2.1 + (s - 3) * 0.3
					local r = reach + 0.8 + (s * 3 % 5) * 1.1
					boulder(mesh, math.cos(a) * r, math.sin(a) * r, DECK - 0.15, 0.12 + (s * 7 % 4) * 0.13, s * 5 + n * 3)
				end
			end, nil, rockColour, nil, nil, true)
		end, x, y)
	end
end

-- Lone bits of wreckage between the sites, so the walk out has something to
-- pass: a half-buried tyre, a length of pipe or a broken slab, each clear of the
-- yards, the tracks and the rock sites.
local LONE_WRECKS = {
	{ 137.9, 44.8 }, { 65.8, 129.2 }, { -22.7, 143.2 }, { -85.2, 117.3 }, { -137.9, -44.8 },
	{ -117.3, -85.2 }, { -44.8, -137.9 }, { 65.8, -129.2 }, { 137.9, -44.8 }, { -175, 0 }, { 0, -175 },
	{ 145, 145 }, { -145, 145 }, { -145, -145 }, { 240, 0 }, { 141.1, 194.2 }, { 0, 240 }, { -37.5, -237 }, { 141.1, -194.2 }, { 237, -37.5 },
	{ -237, 37.5 }, { 194.2, -141.1 }, { -194.2, 141.1 }, { 37.5, 237 }, { 169.7, 169.7 },
}
-- A slab tipped up at one end: its height climbs along x.
local function tippedUp(mesh, slope: number)
	return {
		vertex = function(_self, x: number, y: number, z: number)
			return mesh:vertex(x, y, z + x * slope)
		end,
		face = function(_self, face)
			return mesh:face(face)
		end,
	}
end
for n, spot in LONE_WRECKS do
	-- Every fourth spot is left bare, so they don't read as evenly dealt out.
	if n % 4 == 3 then
		continue
	end
	slab(`LoneWreck{n}`, function()
		local kind = n % 3
		local side = if n % 2 == 0 then 1 else -1
		if kind == 0 then
			part("Tyre", nil, { 0.12, 0.12, 0.13 }, function(mesh)
				-- Heaped against a stone of the size that stopped them rolling.
				if side > 0 then
					-- Stacked where they were thrown, the top one askew.
					table.insert(groundFeet, { 0, 0, 1.5, 1.5, n })
					ring(mesh, 0, 0, DECK + 0.4, 0.9, 1.8, 0.75, "z", 18)
					ring(mesh, 0.5, -0.3, DECK + 1.1, 0.75, 1.6, 0.65, "z", 16)
				else
					table.insert(groundFeet, { 0, 0, 1.2, 0.75, n })
					ring(mesh, 0, 0, DECK + 0.7, 0.95, 1.9, 0.75, "y", 18)
					table.insert(groundFeet, { 2.4, 1.2, 1.25, 1.25, n + 1 })
					ring(mesh, 2.4, 1.2, DECK + 0.32, 0.8, 1.5, 0.6, "z", 16)
				end
				table.insert(groundFeet, { -2.5 * side, -1.4, 1.15, 1.15, n + 2 })
				ring(mesh, -2.5 * side, -1.4, DECK + 0.3, 0.7, 1.35, 0.55, "z", 16)
			end, nil, 0.7)
		elseif kind == 1 then
			part("PipeStone", nil, ROCK, function(mesh)
				boulder(mesh, 0, side * 3.6, DECK, 2.4, n * 9, 0.8)
			end, nil, rockColour, nil, nil, true)
			part("Pipe", nil, { 0.46, 0.28, 0.17 }, function(mesh)
				-- A straight run into a right-angle elbow, flanged at one end, and a
				-- sheared-off length beside it.
				for _, spot in { { -4.4, -0.4 }, { -2, -0.4 }, { 0.5, -0.4 }, { 2.6, -0.1 * side }, { 3, side * 1.4 }, { 3, side * 2.8 }, { 1.6, -2.6 * side }, { 4.2, -3.3 * side } } do
					table.insert(groundFeet, { spot[1], spot[2], 0.9, 0.9, n })
				end
				tube(mesh, roundedPath({ { -4.4, -0.4, DECK + 0.65 }, { 3, -0.4, DECK + 0.65 }, { 3, side * 2.8, DECK + 0.65 } }, 1.7, 6), 1.1, 12)
				ring(mesh, -4.5, -0.4, DECK + 0.65, 0.7, 1.55, 0.22, "x", 14)
				tube(mesh, { { 1.6, -2.6 * side, DECK + 0.45 }, { 4.2, -3.3 * side, DECK + 0.5 } }, 0.8, 10)
			end, nil, 0.8)
		else
			part("Slab", nil, { 0.56, 0.55, 0.52 }, function(mesh)
				-- Tipped up on a stone at one end, with a broken corner off it.
				table.insert(groundFeet, { 0, 0, 3.5, 2.1, n })
				table.insert(groundFeet, { side * 3.9, 2.4, 1.2, 1.0, n + 1 })
				box(tippedUp(mesh, side * 0.16), 0, 0, DECK + 0.45, 6.5, 3.8, 0.75)
				box(mesh, side * 3.9, 2.4, DECK + 0.35, 2.2, 1.8, 0.65)
			end, nil, 0.3)
			part("SlabStone", nil, ROCK, function(mesh)
				boulder(mesh, side * 2.3, -0.4, DECK, 1.5, n * 11)
			end, nil, rockColour, nil, nil, true)
		end
	end, spot[1], spot[2])
end

-- Packed dirt for a yard's floor, as on the server map's plots.
local function yardGround(u: number, v: number, seed: number): (number, number, number)
	-- Trodden in a line in from the gate (at -v) to where the work happens,
	-- which sits somewhere different in each yard.
	local workU = math.noise(seed * 0.37, 2.1, 0.5) * 28
	local workV = 4 + math.noise(seed * 0.37, 7.3, 0.5) * 22
	local reach = 13 + (seed % 5) * 2.5
	local toward = math.clamp((v + 56) / math.max(workV + 56, 1), 0, 1)
	local lineU = workU * toward + fbm(v / 9, seed, seed + 2) * 5
	local lane = smooth(7, 2, math.abs(u - lineU) + fbm(u / 3, v / 3, seed + 3) * 3) * (if v < workV then 1 else 0)
	local du, dv = u - workU, v - workV
	local yardWork = smooth(reach, reach * 0.35, math.sqrt(du * du + dv * dv * 1.4) + fbm(u / 5, v / 5, seed + 4) * 8)
	local packed = math.max(lane * 0.85, yardWork * (0.6 + (seed % 3) * 0.15))
	local k = 1 + fbm(u / 3, v / 3, seed) * 0.2 + fbm(u * 2, v * 2, seed + 1) * 0.08
	-- Trodden dirt packs a shade darker; it never bleaches.
	local firm = k * (1 - 0.14 * packed)
	return YARD_DIRT[1] * firm, YARD_DIRT[2] * firm, YARD_DIRT[3] * firm
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
	-- The line where the fence's footing meets the sand, left open at the gate.
	slab(`YardShade{i}`, function()
		part("GroundShade", nil, SHADE, function(mesh)
			local w, d, out, z = PLOT_WIDTH / 2, PLOT_DEPTH / 2, 2, SHADE_Z
			local function sheet(x0: number, y0: number, x1: number, y1: number)
				mesh:face({ mesh:vertex(x0, y0, z), mesh:vertex(x1, y0, z), mesh:vertex(x1, y1, z), mesh:vertex(x0, y1, z) })
			end
			sheet(-w - out, -d - out, -w, d + out)
			sheet(w, -d - out, w + out, d + out)
			sheet(-w, -d - out, w, -d)
			sheet(-w, d, w, d + out)
		end, nil, function(px: number, py: number)
			local u, v = (px - x) * c + (py - y) * s, (py - y) * c - (px - x) * s
			if v < 0 and math.abs(u) < 7 then
				return SHADE[1], SHADE[2], SHADE[3], 0
			end
			local past = math.max(math.abs(u) - PLOT_WIDTH / 2, math.abs(v) - PLOT_DEPTH / 2)
			return SHADE[1], SHADE[2], SHADE[3], shadeTier(past - FOOTING_REACH + 0.06 * fbm(u * 1.3, v * 1.3, i * 11))
		end, nil, 0, true)
	end, x, y, turn)
	useTexelDensity(GROUND_DENSITY)
	yardShell(i, x, y, turn)
end

-- The capsule belt and its factory (CapsuleLoop), on the plaza.
placeModel("CapsuleLoop", buildCapsuleLoop, 0, 0, DECK + 0.05)

-- New players start on a ring painted on the plaza, over the walk it crosses
-- (the walk's top is at DECK + 0.1).
slab("Spawn", function()
	part("Pad", nil, MARK, function(mesh)
		ring(mesh, 0, 0, DECK + 0.1, 8, 9, 0.1, "z", 48)
	end, nil, 0)
end, 0, 22)

-- The town, inside the belt. Each piece's front (-y) faces the middle.
local TOWN_Z = DECK + 0.05
placeModel("Market", buildHubShop, 0, 44, TOWN_Z)
placeModel("Tinkerer", buildHubTinkerer, -48, 0, TOWN_Z, 90)
placeModel("Landmark", buildHubBeacon, 0, 0, TOWN_Z)
placeModel("EventStage", buildHubStage, math.cos(math.rad(-45)) * 46, math.sin(math.rad(-45)) * 46, TOWN_Z, 225)

-- The hub's streets. A promenade just inside the belt meets every bridge,
-- walks tie it to the landmark and the buildings, and a kerbed track runs from
-- each gate to the ring road.
local PROMENADE_INNER, PROMENADE_OUTER = 60.5, 67
local WALK = { 0.47, 0.46, 0.43 }
local KERB = { 0.62, 0.6, 0.55 }
local TRACK = { 0.3, 0.26, 0.21 }
local TRACK_END = YARD_RADIUS - PLOT_DEPTH / 2
-- The turf stands proud of DECK, so a track is laid up on top of it.
local TRACK_TOP = DECK + 0.8
local WALK_BEARINGS = { 22.5, 157.5, 247.5, 292.5 }
-- A building's front toward the landmark: bearing and where the walk stops.
local BUILDING_WALKS = { { 90, 33 }, { 180, 39 }, { -45, 33 } }
local function polar(degrees: number, r: number): (number, number)
	return math.cos(math.rad(degrees)) * r, math.sin(math.rad(degrees)) * r
end
local function flatRing(mesh, inner: number, outer: number, z: number)
	local STEPS = 96
	for a = 0, STEPS - 1 do
		local t0, t1 = 2 * math.pi * a / STEPS, 2 * math.pi * (a + 1) / STEPS
		mesh:face({
			mesh:vertex(math.cos(t0) * outer, math.sin(t0) * outer, z),
			mesh:vertex(math.cos(t1) * outer, math.sin(t1) * outer, z),
			mesh:vertex(math.cos(t1) * inner, math.sin(t1) * inner, z),
			mesh:vertex(math.cos(t0) * inner, math.sin(t0) * inner, z),
		})
	end
end
slab("Streets", function()
	local STREET_Z = DECK + 0.1
	part("Walks", nil, WALK, function(mesh)
		flatRing(mesh, PROMENADE_INNER, PROMENADE_OUTER, STREET_Z)
		flatRing(mesh, 9, 12.5, STREET_Z)
		for _, bearing in WALK_BEARINGS do
			local x0, y0 = polar(bearing, 12)
			local x1, y1 = polar(bearing, PROMENADE_INNER)
			run(mesh, x0, y0, STREET_Z, x1, y1, STREET_Z, 2.5, DECK)
		end
		for _, building in BUILDING_WALKS do
			local x0, y0 = polar(building[1], 12)
			local x1, y1 = polar(building[1], building[2])
			run(mesh, x0, y0, STREET_Z, x1, y1, STREET_Z, 2.5, DECK)
		end
	end, nil, function(x, y)
		-- Trodden darker down the middle of the promenade.
		local r = math.sqrt(x * x + y * y)
		local trodden = 1 - 0.28 * math.exp(-((r - 63.75) / 2.6) ^ 2)
		local k = (1 + fbm(x / 3, y / 3, 140) * 0.1) * trodden
		return WALK[1] * k, WALK[2] * k, WALK[3] * k
	end, nil, nil, true)
	chunkedPart("RoadMarks", nil, MARK, function(mesh)
		-- The ring road's edge lines, laid on the paving as their own sheets so
		-- their edges print crisp.
		flatRing(mesh, HUB_PAVED, HUB_PAVED + 1, DECK + 0.07)
		flatRing(mesh, HUB_ROAD - 1, HUB_ROAD, DECK + 0.07)
	end, nil, 0.5, true)
	part("LaneMarks", nil, { 0.86, 0.7, 0.16 }, function(mesh)
		-- Painted dashes round the promenade and along the walks, for the carts.
		local PAINT_Z = STREET_Z + 0.02
		for a = 0, 39 do
			local t0, t1 = a * 9, a * 9 + 6
			local x0, y0 = polar(t0, PROMENADE_INNER + 0.7)
			local x1, y1 = polar(t1, PROMENADE_INNER + 0.7)
			run(mesh, x0, y0, PAINT_Z, x1, y1, PAINT_Z, 0.32, DECK)
		end
		for _, bearing in WALK_BEARINGS do
			local r = 15
			while r < PROMENADE_INNER - 2 do
				local x0, y0 = polar(bearing, r)
				local x1, y1 = polar(bearing, r + 3)
				run(mesh, x0, y0, PAINT_Z, x1, y1, PAINT_Z, 0.26, DECK)
				r += 5
			end
		end
	end, nil, 0.5, nil, nil, true)
	part("Drains", nil, { 0.16, 0.16, 0.18 }, function(mesh)
		-- A barred drain every so often round the promenade, flush with the walk.
		local DRAIN_Z = STREET_Z + 0.02
		for a = 1, 8 do
			local cx, cy = polar(a * 45 - 8, PROMENADE_OUTER - 0.9)
			box(mesh, cx, cy, DECK, 2.6, 2.6, DRAIN_Z - DECK)
		end
		-- And one at the foot of each walk into the town.
		for _, bearing in WALK_BEARINGS do
			local cx, cy = polar(bearing, 14.6)
			box(mesh, cx, cy, DECK, 1.2, 1.2, DRAIN_Z - DECK)
		end
	end, nil, 0.4, nil, nil, true)
	part("Tracks", nil, TRACK, function(mesh)
		for i = 1, 8 do
			local degrees = (i - 0.5) * 45
			local x0, y0 = polar(degrees, HUB_ROAD - 0.5)
			local x1, y1 = polar(degrees, TRACK_END + 1)
			run(mesh, x0, y0, TRACK_TOP, x1, y1, TRACK_TOP, 4.75, DECK - 0.2)
		end
	end, nil, function(x, y)
		local k = 1 + fbm(x / 2, y / 2, 150) * 0.16
		return TRACK[1] * k, TRACK[2] * k, TRACK[3] * k
	end, nil, nil, true)
	part("Kerbs", nil, KERB, function(mesh)
		local SEGMENT = 3
		-- The pale bars over each drain, standing out on its dark pit.
		for a = 1, 8 do
			local cx, cy = polar(a * 45 - 8, PROMENADE_OUTER - 0.9)
			for s = -3, 3 do
				box(mesh, cx + s * 0.36, cy, STREET_Z + 0.02, 0.2, 2.4, 0.05)
			end
		end
		for i = 1, 8 do
			local degrees = (i - 0.5) * 45
			local across = math.rad(degrees + 90)
			for _, side in { -5, 5 } do
				local ox, oy = math.cos(across) * side, math.sin(across) * side
				local r = HUB_ROAD
				while r + SEGMENT <= TRACK_END do
					local x0, y0 = polar(degrees, r)
					local x1, y1 = polar(degrees, r + SEGMENT - 0.15)
					run(mesh, x0 + ox, y0 + oy, TRACK_TOP + 0.22, x1 + ox, y1 + oy, TRACK_TOP + 0.22, 0.3, DECK - 0.2)
					r += SEGMENT
				end
			end
		end
	end, nil, function(x, y)
		local k = 1 + fbm(x, y, 160) * 0.14
		return KERB[1] * k, KERB[2] * k, KERB[3] * k
	end, nil, nil, true)
	part("Conduits", nil, { 0.24, 0.24, 0.26 }, function(mesh)
		local CONDUIT_TOP, COVER_TOP = DECK + 0.4, DECK + 0.46
		-- A run from a to b with clamps, and a riser into the building at b.
		local function conduit(ax: number, ay: number, bx: number, by: number)
			run(mesh, ax, ay, CONDUIT_TOP, bx, by, CONDUIT_TOP, 0.2, DECK)
			local dx, dy = bx - ax, by - ay
			local length = math.sqrt(dx * dx + dy * dy)
			local ux, uy = dx / length, dy / length
			local along = 5
			while along < length - 2 do
				local cx, cy = ax + ux * along, ay + uy * along
				run(mesh, cx - uy * 0.42, cy + ux * 0.42, DECK + 0.5, cx + uy * 0.42, cy - ux * 0.42, DECK + 0.5, 0.14, DECK)
				along += 5
			end
		end
		-- A plate players walk over where a conduit crosses the landmark's ring.
		local function cover(ax: number, ay: number, bx: number, by: number)
			run(mesh, ax, ay, COVER_TOP, bx, by, COVER_TOP, 0.75, DECK)
		end
		-- The market's goes round the spawn ring, on the ring's +X side.
		conduit(7.6, 6, 11, 6)
		conduit(11, 6, 11, 33)
		cover(7.6, 6, 11.4, 6)
		box(mesh, 11, 33, DECK, 1, 1, 1.1)
		-- The Tinkerer's and the Stage's run straight from the plinth.
		for _, building in { { 180, 39 }, { -45, 33 } } do
			local across = math.rad(building[1] + 90)
			local ox, oy = math.cos(across) * 3.1, math.sin(across) * 3.1
			local x0, y0 = polar(building[1], 7.5)
			local x1, y1 = polar(building[1], building[2])
			conduit(x0 + ox, y0 + oy, x1 + ox, y1 + oy)
			local cx0, cy0 = polar(building[1], 8.6)
			local cx1, cy1 = polar(building[1], 12.9)
			cover(cx0 + ox, cy0 + oy, cx1 + ox, cy1 + oy)
			box(mesh, x1 + ox, y1 + oy, DECK, 1, 1, 1.1)
		end
	end, nil, 0.2)
	part("LampPosts", nil, { 0.2, 0.21, 0.23 }, function(mesh)
		for n = 1, 7 do
			local x, y = polar(n * 45, PROMENADE_OUTER + 0.8)
			box(mesh, x, y, DECK, 0.9, 0.9, 0.5)
			box(mesh, x, y, DECK + 0.5, 0.36, 0.36, 7)
			box(mesh, x, y, DECK + 7.5, 1.5, 1.5, 0.3)
		end
	end, nil, 0.2)
	part("LampGlow", nil, { 1, 0.86, 0.55 }, function(mesh)
		for n = 1, 7 do
			local x, y = polar(n * 45, PROMENADE_OUTER + 0.8)
			box(mesh, x, y, DECK + 6.9, 1.1, 1.1, 0.6)
		end
	end, nil, 0, nil, 1.6)
end, 0, 0)

-- Crossings over the belt, whose middle runs at radius 72, one on each
-- yard's path so the walk to the hub runs straight over.
for n = 1, 8 do
	local degrees = (n - 0.5) * 45
	placeModel(`Crossing{n}`, buildBeltCrossing, math.cos(math.rad(degrees)) * 72, math.sin(math.rad(degrees)) * 72, TOWN_Z, degrees)
end

-- slab keys skip (the kit below places models only; no slab uses it)
-- The kit: one of each model the game places itself (yard things, capsules
-- and junkrots), built here so they upload with the map. They stand in a
-- row far under the hub; tools/studio/PlaceMap.luau takes them out of the
-- map and files them where the game clones them from. Yard things are
-- built to their plot footprint (pads and the mound are modelled 6 studs
-- across and stand 10), and everything at KIT_DENSITY, finer than the
-- map's, as players stand right next to them.
local KIT_DENSITY = 40
-- Far under the island's root, where no camera looks.
local KIT_Z = -260
local KIT_SPACING = 24
local KIT = {
	{ "ProofToaster", buildProofToaster, 1 },
	{ "ProofKettle", buildProofKettle, 1 },
	{ "ProofShark", buildProofShark, 1 },
	{ "PadKitchen", buildPadKitchen, 10 / 6 },
	{ "PadGarage", buildPadGarage, 10 / 6 },
	{ "PadGadget", buildPadGadget, 10 / 6 },
	{ "Bay", buildBuildBay, 1 },
	{ "Crate", buildScrapCrate, 1 },
	{ "Press", buildRebirthPress, 1 },
	{ "Mound", buildJunkMound, 10 / 6 },
	{ "CapsuleScrap", buildCapsuleScrap, 1 },
	{ "CapsuleSalvaged", buildCapsuleSalvaged, 1 },
	{ "CapsuleRefurbished", buildCapsuleRefurbished, 1 },
	{ "CapsuleFactory", buildCapsuleFactory, 1 },
	{ "CapsulePrecision", buildCapsulePrecision, 1 },
	{ "CapsulePrototype", buildCapsulePrototype, 1 },
	{ "CapsuleSecret", buildCapsuleSecret, 1 },
	{ "JunkrotCanettoRustini", buildJunkrotCanettoRustini, 1 },
	{ "JunkrotSpoonzoBentolo", buildJunkrotSpoonzoBentolo, 1 },
	{ "JunkrotKettlinaDentata", buildJunkrotKettlinaDentata, 1 },
	{ "JunkrotTyroFlattino", buildJunkrotTyroFlattino, 1 },
	{ "JunkrotBoltoloLonelo", buildJunkrotBoltoloLonelo, 1 },
	{ "JunkrotHubcappaWobbla", buildJunkrotHubcappaWobbla, 1 },
	{ "JunkrotRemotinoMuto", buildJunkrotRemotinoMuto, 1 },
	{ "JunkrotCabloTanglino", buildJunkrotCabloTanglino, 1 },
	{ "JunkrotBulboFulminato", buildJunkrotBulboFulminato, 1 },
	{ "JunkrotCrumboPoppalot", buildJunkrotCrumboPoppalot, 1 },
	{ "JunkrotPannettoPatchato", buildJunkrotPannettoPatchato, 1 },
	{ "JunkrotBlendroCigolante", buildJunkrotBlendroCigolante, 1 },
	{ "JunkrotJackoloCrickato", buildJunkrotJackoloCrickato, 1 },
	{ "JunkrotOilcannaGluglu", buildJunkrotOilcannaGluglu, 1 },
	{ "JunkrotMuffleroTossetto", buildJunkrotMuffleroTossetto, 1 },
	{ "JunkrotRadioloFruscio", buildJunkrotRadioloFruscio, 1 },
	{ "JunkrotFanettoWobblino", buildJunkrotFanettoWobblino, 1 },
	{ "JunkrotClockoTictacco", buildJunkrotClockoTictacco, 1 },
	{ "JunkrotFrostboxGelatone", buildJunkrotFrostboxGelatone, 1 },
	{ "JunkrotMicrondoBippetto", buildJunkrotMicrondoBippetto, 1 },
	{ "JunkrotMixerellaVroom", buildJunkrotMixerellaVroom, 1 },
	{ "JunkrotMopaMopetta", buildJunkrotMopaMopetta, 1 },
	{ "JunkrotDrilloTrapanino", buildJunkrotDrilloTrapanino, 1 },
	{ "JunkrotGrindellaScintilla", buildJunkrotGrindellaScintilla, 1 },
	{ "JunkrotTelefonoRingaling", buildJunkrotTelefonoRingaling, 1 },
	{ "JunkrotTypewrittoClackini", buildJunkrotTypewrittoClackini, 1 },
	{ "JunkrotCamerinoFlashetto", buildJunkrotCamerinoFlashetto, 1 },
	{ "JunkrotDrippiDroppi", buildJunkrotDrippiDroppi, 1 },
	{ "JunkrotDingDingDingDongo", buildJunkrotDingDingDingDongo, 1 },
	{ "JunkrotGrindoBeanbasher", buildJunkrotGrindoBeanbasher, 1 },
	{ "JunkrotAirfryoCroccante", buildJunkrotAirfryoCroccante, 1 },
	{ "JunkrotDishwashinoSplashetto", buildJunkrotDishwashinoSplashetto, 1 },
	{ "JunkrotLawnmowoRuggito", buildJunkrotLawnmowoRuggito, 1 },
	{ "JunkrotLeafblowaWhooshini", buildJunkrotLeafblowaWhooshini, 1 },
	{ "JunkrotPressurwashoSprizzo", buildJunkrotPressurwashoSprizzo, 1 },
	{ "JunkrotConsoloJoypaddino", buildJunkrotConsoloJoypaddino, 1 },
	{ "JunkrotSpeakeroneBoomba", buildJunkrotSpeakeroneBoomba, 1 },
	{ "JunkrotRobovaccoGirotondo", buildJunkrotRobovaccoGirotondo, 1 },
	{ "JunkrotClankClankClankScrapur", buildJunkrotClankClankClankScrapur, 1 },
	{ "JunkrotVrrVrrPatatrim", buildJunkrotVrrVrrPatatrim, 1 },
	{ "JunkrotChimneyziniSpannerini", buildJunkrotChimneyziniSpannerini, 1 },
	{ "JunkrotRusteliRustela", buildJunkrotRusteliRustela, 1 },
	{ "JunkrotBallerinaTincuppina", buildJunkrotBallerinaTincuppina, 1 },
	{ "JunkrotTrashaleroTrashala", buildJunkrotTrashaleroTrashala, 1 },
	{ "JunkrotSockettoSeiSette", buildJunkrotSockettoSeiSette, 1 },
	{ "JunkrotChefbotPrecisio", buildJunkrotChefbotPrecisio, 1 },
	{ "JunkrotSousvideSilvano", buildJunkrotSousvideSilvano, 1 },
	{ "JunkrotKnifeblockSlicetta", buildJunkrotKnifeblockSlicetta, 1 },
	{ "JunkrotTorquoWrenchelli", buildJunkrotTorquoWrenchelli, 1 },
	{ "JunkrotLaserlevelLineo", buildJunkrotLaserlevelLineo, 1 },
	{ "JunkrotWeldettaSparkalot", buildJunkrotWeldettaSparkalot, 1 },
	{ "JunkrotDronettoBuzzatti", buildJunkrotDronettoBuzzatti, 1 },
	{ "JunkrotTickworthPocketti", buildJunkrotTickworthPocketti, 1 },
	{ "JunkrotHeadphonoBassimo", buildJunkrotHeadphonoBassimo, 1 },
	{ "JunkrotGascaniniHonkini", buildJunkrotGascaniniHonkini, 1 },
	{ "JunkrotPercolattoNinjatto", buildJunkrotPercolattoNinjatto, 1 },
	{ "JunkrotBoilerdiroCrockpotilo", buildJunkrotBoilerdiroCrockpotilo, 1 },
	{ "JunkrotSnackomaticPrototipo", buildJunkrotSnackomaticPrototipo, 1 },
	{ "JunkrotHoverbikkoZoomzoom", buildJunkrotHoverbikkoZoomzoom, 1 },
	{ "JunkrotHolofonoShimmerra", buildJunkrotHolofonoShimmerra, 1 },
	{ "JunkrotLaVacuumaSaturnita", buildJunkrotLaVacuumaSaturnita, 1 },
	{ "JunkrotTheMonolito", buildJunkrotTheMonolito, 1 },
	{ "JunkrotUnitZero", buildJunkrotUnitZero, 1 },
}
useTexelDensity(KIT_DENSITY)
for index, entry in KIT do
	place(`Kit_{entry[1]}`, entry[2], (index - #KIT / 2) * KIT_SPACING, 0, KIT_Z, 0, nil, nil, entry[3])
	useTexelDensity(KIT_DENSITY)
end
useTexelDensity(GROUND_DENSITY)
-- slab keys resume
