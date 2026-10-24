-- Yard Island: a floating yard island built from stacked rock columns, in
-- the style of a hand-sculpted stylised island. Three tiers of rounded
-- sandstone pillars ring the island, each tier tucked further in and ending
-- lower than the last, with deep clefts between pillars and a grassy lip
-- draped over the rim. The model is one closed outer shell over the
-- columns, with nothing inside. Top at z = 0.7.
useTexelDensity(16)
local RADIUS = 20
local GROUND = { 0.3, 0.27, 0.22 }
local GRASS = { 0.36, 0.52, 0.15 }
local SANDSTONE = { 0.66, 0.45, 0.25 }

local function random(k: number): number
	local s = math.sin(k * 12.9898 + 4.1414) * 43758.5453
	return s - math.floor(s)
end

-- The island's wobbly outline, as a radius scale per angle.
local function outlineScale(angle: number): number
	return 1 + 0.07 * math.sin(3 * angle + 0.6) + 0.05 * math.sin(5 * angle + 2.1) + 0.03 * math.sin(9 * angle)
end

-- Each tier is a ring of pillars: { reach, pillar count, bottom, seed }.
-- Lower tiers sit further in, so each shows below the one above it.
local CAP_TOP = 0.7
local TIERS = {
	{ RADIUS * 0.84, 15, -8, 11 },
	{ RADIUS * 0.58, 11, -14, 23 },
	{ RADIUS * 0.34, 7, -19.5, 37 },
	{ RADIUS * 0.15, 4, -24, 51 },
}
local CLEFT, ROUNDING = 1.6, 2

-- Pillar layout per tier: each pillar's start angle, reach and bottom.
local pillars = {}
for t, tier in TIERS do
	local reach, count, bottom, seed = tier[1], tier[2], tier[3], tier[4]
	local list = {}
	local offset = random(seed) * 2 * math.pi
	local weights, total = {}, 0
	for i = 1, count do
		weights[i] = 0.7 + 0.6 * random(seed + i)
		total += weights[i]
	end
	local angle = offset
	for i = 1, count do
		local span = weights[i] / total * 2 * math.pi
		list[i] = {
			from = angle,
			span = span,
			reach = reach * (0.94 + 0.12 * random(seed + i + 40)),
			bottom = bottom - (TIERS[t][3] - (if t > 1 then TIERS[t - 1][3] else CAP_TOP)) * 0.25 * (random(seed + i + 80) - 0.5),
			seed = seed * 31 + i * 7,
			top = if t == 1 then CAP_TOP else TIERS[t - 1][3] + 0.5,
			-- Like the old clumps: each pillar tapers and leans in toward
			-- its foot by its own amount, and has a chip bitten in or a lump
			-- standing out partway across its face.
			taper = 0.08 + 0.12 * random(seed + i + 120),
			lean = 0.1 + 0.25 * random(seed + i + 140),
			defect = random(seed + i + 160) - 0.45,
			defectAt = (random(seed + i + 180) - 0.5) * 1.2,
		}
		angle += span
	end
	pillars[t] = list
end

-- The pillar of `tier` covering `angle`, and where across it the angle
-- falls, from -1 at one cleft to 1 at the next.
local function pillarAt(tier: number, angle: number)
	for _, pillar in pillars[tier] do
		local a = (angle - pillar.from) % (2 * math.pi)
		if a < pillar.span then
			return pillar, a / pillar.span * 2 - 1
		end
	end
	return pillars[tier][1], 0
end

-- How far the island's wall reaches at `angle` and height z, and the
-- pillar there with its across position, for painting. Each pillar is
-- rounded across its face so clefts open between pillars, and rounded
-- under its foot down onto the tier below.
local function wall(angle: number, z: number)
	local best, owner, across = 0.05, nil, 0
	for t = 1, #TIERS do
		local pillar, u = pillarAt(t, angle)
		if z < pillar.bottom then continue end
		local r = pillar.reach * outlineScale(angle) - CLEFT * (1 - math.sqrt(math.max(1 - u * u, 0)))
		local size = pillar.reach * pillar.span / 2
		local shift = math.clamp((pillar.top - z) / (pillar.top - pillar.bottom), 0, 1)
		r -= pillar.reach * pillar.taper * shift + size * pillar.lean * shift
		r += size * 0.35 * pillar.defect * math.max(1 - math.abs(u - pillar.defectAt) / 0.5, 0)
		-- Every ring of the face nudged a little, stepping down the pillar.
		local at = (pillar.top - z) / 1.5
		local ring = math.floor(at)
		local blend = (at - ring) ^ 2 * (3 - 2 * (at - ring))
		local function ringNudge(n: number): number
			return random(pillar.seed + n * 101)
		end
		local nudge = ringNudge(ring) + (ringNudge(ring + 1) - ringNudge(ring)) * blend
		r += 0.25 * math.noise(angle * 6, z / 3, pillar.seed % 97) + 0.3 * (nudge - 0.5)
		local lift = z - pillar.bottom
		if lift < ROUNDING then
			local inner = if t < #TIERS then pillarAt(t + 1, angle).reach * outlineScale(angle) * 0.9 else 0
			r = inner + (r - inner) * math.sqrt(1 - (1 - lift / ROUNDING) ^ 2)
		end
		if r > best then
			best, owner, across = r, pillar, u
		end
	end
	return best, owner, across
end

-- The grass lip: how far it drapes down the rim at `angle`, in clumps.
local function drape(angle: number): number
	local n = math.noise(angle * 7, 3.7) + 0.5 * math.noise(angle * 23, 9.1)
	return 0.35 + 1.1 * math.clamp(n + 0.4, 0, 1)
end

-- One closed outer shell: rows of wall points stepping down from the top to
-- the tip, a flat top in concentric rings and a point at the bottom.
local ANGLES, STEP, TIP, LIP, TOP_RINGS = 240, 0.3, -25, 0.35, 8
part("Island", nil, GROUND, function(mesh)
	local rim = {}
	for j = 0, ANGLES - 1 do
		rim[j] = wall(2 * math.pi * j / ANGLES, CAP_TOP)
	end
	local rows = {}
	local z = CAP_TOP
	while z > TIP + STEP / 2 do
		local row = {}
		for j = 0, ANGLES - 1 do
			local angle = 2 * math.pi * j / ANGLES
			local r = wall(angle, z)
			-- The grass lip stands proud of the rock, easing back in over
			-- its last fifth so it overhangs the stone below.
			local depth = (CAP_TOP - z) / drape(angle)
			if depth < 1 then
				r = math.max(r, rim[j]) + LIP * math.clamp((1 - depth) / 0.2, 0, 1)
			end
			row[j] = mesh:vertex(math.cos(angle) * r, math.sin(angle) * r, z)
		end
		table.insert(rows, row)
		z -= STEP
	end
	for i = 1, #rows - 1 do
		for j = 0, ANGLES - 1 do
			local l = (j + 1) % ANGLES
			mesh:face({ rows[i + 1][j], rows[i + 1][l], rows[i][l], rows[i][j] })
		end
	end
	-- The top in concentric rings out to the rim, so no long thin fan
	-- triangles streak its shading.
	local inner = rows[1]
	for ring = TOP_RINGS - 1, 1, -1 do
		local k = ring / TOP_RINGS
		local row = {}
		for j = 0, ANGLES - 1 do
			local angle = 2 * math.pi * j / ANGLES
			row[j] = mesh:vertex(math.cos(angle) * (rim[j] + LIP) * k, math.sin(angle) * (rim[j] + LIP) * k, CAP_TOP)
		end
		for j = 0, ANGLES - 1 do
			local l = (j + 1) % ANGLES
			mesh:face({ row[j], inner[j], inner[l], row[l] })
		end
		inner = row
	end
	local middle = mesh:vertex(0, 0, CAP_TOP)
	for j = 0, ANGLES - 1 do
		mesh:face({ middle, inner[j], inner[(j + 1) % ANGLES] })
	end
	local tip = mesh:vertex(0.3, -0.2, TIP)
	for j = 0, ANGLES - 1 do
		mesh:face({ tip, rows[#rows][(j + 1) % ANGLES], rows[#rows][j] })
	end
end, false, function(x, y, z)
	local angle = math.atan2(y, x)
	local away = math.sqrt(x * x + y * y)
	-- Top: dirt in the middle, grass in a band round the edge.
	if z > CAP_TOP - 0.02 then
		local edge = wall(angle, CAP_TOP) + LIP - away
		local k = 1 + 0.12 * math.noise(x / 4, y / 4, 31) + 0.05 * math.noise(x * 3, y * 3, 37)
		local grassy = math.clamp((2.2 + 0.8 * math.noise(x / 3, y / 3, 5) - edge) / 0.6, 0, 1)
		local r = GROUND[1] + (GRASS[1] - GROUND[1]) * grassy
		local g = GROUND[2] + (GRASS[2] - GROUND[2]) * grassy
		local b = GROUND[3] + (GRASS[3] - GROUND[3]) * grassy
		return r * k, g * k, b * k
	end
	if CAP_TOP - z < drape(angle) then
		local k = 1 + 0.15 * math.noise(x * 1.5, y * 1.5, z * 2)
		return GRASS[1] * k, GRASS[2] * k, GRASS[3] * k
	end
	-- Rock: one sandstone per pillar, a little warmer or paler pillar to
	-- pillar, darkening into the clefts either side.
	local _, pillar, across = wall(angle, z)
	local s = if pillar then pillar.seed else 0
	local k = (0.88 + 0.24 * random(s + 3)) * (1 + 0.06 * math.noise(x * 0.8, y * 0.8, z * 0.8))
	k *= 1 - 0.35 * math.clamp((math.abs(across) - 0.75) / 0.25, 0, 1)
	local warm = 0.06 * (random(s + 5) - 0.5)
	return SANDSTONE[1] * k + warm, SANDSTONE[2] * k, SANDSTONE[3] * k - warm
end)

-- Aggressive shading: half-strength edge highlights, ramping 30% stronger
-- toward the bottom, and strong contact shadows, with every part (the shell
-- included) as an occluder so each clump darkens the crevices and overhangs
-- round it.
for _, entry in parts do
	local occluders = {}
	for _, other in parts do
		table.insert(occluders, other.mesh)
	end
	entry.mesh:paintShading(entry.image, {
		highlight = 0.5,
		highlightRamp = 0.3,
		shadow = 1.5,
		gradient = GRADIENT,
		blend = 0.78,
		occluders = occluders,
	})
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
