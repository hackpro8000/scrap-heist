-- Part bundle: a sealed tarp sack of salvaged parts, cinched shut at the neck
-- with a rope and a tufted knot. Six fill levels; each one bloats the sack
-- more, from a flat, wrinkly slump to a tight ball with parts pressing lumps
-- out through the tarp. The game shows one level's Sack_N group at a time.
-- Sits on the ground with its base at the origin.

-- Per level: {width, height, fullness 0-1}. Fullness drives how round the
-- body gets, how hard the parts push lumps out and how much the slack tarp
-- wrinkles.
local FILL_LEVELS = {
	{ 1.7, 0.75, 0.0 },
	{ 1.8, 1.0, 0.2 },
	{ 1.9, 1.25, 0.4 },
	{ 2.0, 1.5, 0.6 },
	{ 2.1, 1.75, 0.8 },
	{ 2.2, 2.0, 1.0 },
}

-- Mesh resolution: segments around, rings from floor to neck.
local SEGMENTS = 40
local RINGS = 24

-- Cinched neck: radius at the tie, its height above the body, and the
-- frilled tuft of gathered tarp above the knot.
local NECK = 0.13
local NECK_HEIGHT = 0.12
local TUFT_RADIUS = 0.3
local TUFT_HEIGHT = 0.3
local TUFT_POINTS = 7

-- Lumps where parts press out, and folds of slack tarp.
local LUMP_SCALE = 1.6
local LUMP_AMOUNT = 0.16
local WRINKLES = 11
local WRINKLE_AMOUNT = 0.07

-- Rope round the neck: tube radius, strands twisted together.
local ROPE_SIZE = 0.05
local ROPE_STRANDS = 3

-- Grey-green tarp with darker patches, and a hemp rope, in sRGB.
local TARP = { 0.45, 0.55, 0.42 }
local PATCH = { 0.33, 0.4, 0.34 }
local ROPE = { 0.78, 0.62, 0.38 }
-- Patches: noise scale, and the noise value where tarp turns to patch.
local PATCH_SCALE = 1.8
local PATCH_EDGE = 0.18

local TAU = 2 * math.pi

-- Body radius 0-1 from floor (v=0) to the top of the body (v=1). A slack
-- sack slumps into a squat, flat-sided pile; a full one rounds into a ball.
local function profile(v, fullness)
	local n = 3.2 - fullness
	local t = math.abs(2 * v - 1)
	local r = math.max(0, 1 - t ^ n) ^ (1 / n)
	-- Weight sags low: slack sacks spread at the bottom.
	return r * (1 + (1 - fullness) * 0.25 * (1 - v))
end

local function bodyPoint(angle, v, width, height, fullness, seed)
	local radius = width / 2
	local r = profile(v, fullness) * radius
	-- Pinch in toward the neck near the top.
	local gather = math.max(0, (v - 0.7) / 0.3) ^ 2
	r = if r > NECK then r * (1 - gather) + NECK * gather else NECK
	local dx, dy = math.cos(angle), math.sin(angle)
	if v == 0 then
		return dx * r, dy * r, 0
	end
	-- Parts pushing out: big soft lumps, stronger as the sack fills.
	local sx, sy, sz = dx * LUMP_SCALE + seed, dy * LUMP_SCALE, (v * 2 - 1) * LUMP_SCALE
	local lump = math.noise(sx, sy, sz) * LUMP_AMOUNT * (0.3 + fullness) * radius
	-- Slack folds running up the sides, and folds always gathered at the neck.
	local fold = math.sin(angle * WRINKLES + math.noise(sx * 2, sy * 2, sz * 2) * 2) * WRINKLE_AMOUNT
	fold *= (1 - fullness) * math.sin(math.pi * v) + gather * 0.6
	r += (lump + fold) * (1 - gather * 0.5)
	return dx * r, dy * r, v * height
end

-- One closed shell: floor, bulging body, cinched neck, then a frilled tuft.
local function sack(width, height, fullness, seed)
	local mesh = Mesh.new()
	local rings = {}
	local function ring(point)
		local verts = {}
		for i = 0, SEGMENTS - 1 do
			verts[i + 1] = mesh:vertex(point(i / SEGMENTS * TAU))
		end
		table.insert(rings, verts)
	end
	for row = 1, RINGS do
		ring(function(a)
			return bodyPoint(a, row / RINGS, width, height, fullness, seed)
		end)
	end
	local tie = height + NECK_HEIGHT
	ring(function(a)
		return math.cos(a) * NECK, math.sin(a) * NECK, tie
	end)
	-- Tuft: gathered tarp fanning out above the knot, edge cut in points.
	for _, shape in { { 0.35, 0.55 }, { 0.75, 1.0 } } do
		local lift, spread = shape[1], shape[2]
		ring(function(a)
			local point = 0.6 + 0.4 * math.abs(math.cos(a * TUFT_POINTS / 2))
			local r = NECK + (TUFT_RADIUS * point - NECK) * spread
			return math.cos(a) * r, math.sin(a) * r, tie + TUFT_HEIGHT * lift * (0.8 + 0.4 * point)
		end)
	end
	local floor = mesh:vertex(0, 0, 0)
	local top = mesh:vertex(0, 0, tie + TUFT_HEIGHT * 0.55)
	local first, last = rings[1], rings[#rings]
	for i = 1, SEGMENTS do
		local j = i % SEGMENTS + 1
		mesh:face({ floor, first[j], first[i] })
		mesh:face({ top, last[i], last[j] })
	end
	for k = 1, #rings - 1 do
		local low, high = rings[k], rings[k + 1]
		for i = 1, SEGMENTS do
			local j = i % SEGMENTS + 1
			mesh:face({ low[i], low[j], high[j], high[i] })
		end
	end
	mesh:setSmooth(true)
	return mesh, tie
end

-- Twisted rope looped round the neck: a torus whose tube ripples in strands.
local function rope(height)
	local mesh = Mesh.new()
	local around, tube = 32, 10
	local ringRadius = NECK + ROPE_SIZE * 0.6
	local rings = {}
	for i = 0, around - 1 do
		local a = i / around * TAU
		local ox, oy = math.cos(a), math.sin(a)
		local verts = {}
		for k = 0, tube - 1 do
			local b = k / tube * TAU
			local r = ROPE_SIZE * (1 + 0.18 * math.cos(b * ROPE_STRANDS + a * 9))
			local out = ringRadius + math.cos(b) * r
			verts[k + 1] = mesh:vertex(ox * out, oy * out, height + math.sin(b) * r)
		end
		rings[i + 1] = verts
	end
	for i = 1, around do
		local low, high = rings[i], rings[i % around + 1]
		for k = 1, tube do
			local m = k % tube + 1
			mesh:face({ low[k], high[k], high[m], low[m] })
		end
	end
	mesh:setSmooth(true)
	return mesh
end

-- Hard-edged noise blobs of patch color over the tarp.
local function tarpColor(x, y, z)
	local fac = math.noise(x * PATCH_SCALE, y * PATCH_SCALE, z * PATCH_SCALE)
	local c = if fac > PATCH_EDGE then PATCH else TARP
	return c[1], c[2], c[3]
end

for number, level in FILL_LEVELS do
	local name = `Sack_{number}`
	local preview = number == #FILL_LEVELS
	local body, tie = sack(level[1], level[2], level[3], number * 3.7)
	local knot = rope(tie)

	body:unwrap()
	local tarp = Image.new(1024, 1024)
	body:paint(tarp, tarpColor)
	body:paintShading(tarp, { occluders = { knot } })

	knot:unwrap()
	local hemp = Image.new(256, 256, ROPE[1], ROPE[2], ROPE[3])
	knot:paintShading(hemp, { occluders = { body } })

	model.part(name, body, tarp, { group = name, preview = preview })
	model.part(`{name}_Rope`, knot, hemp, { group = name, preview = preview })
end
