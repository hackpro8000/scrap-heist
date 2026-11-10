-- Rough Rocks: the island layout's rough-zone rock group Rough10 (a low
-- cluster of three boulders with chips, loose stone and two clumps) built on
-- its own, so the stones can be baked and looked at apart from the map. The
-- same boulder code and site numbers as IslandPreview.luau, with the ground
-- at z = 0. Centered on the slab's own origin, like the layout's Rough10.
-- include: HandFinish
-- Four times the layout's ground density: the stones are chunked into 16
-- stud cells so each cell gets its own 1024 texture and the edge rims have
-- the texels to show.
useTexelDensity(64)
local ROCK = { 0.56, 0.5, 0.42 }
-- Just above the ground, where the layout traces each stone's contact line.
local SHADE_Z = 0.03
-- What stands on the sand: { x, y, radius x, radius y, seed, rim }.
local groundFeet = {}

local function fbm(x: number, y: number, z: number): number
	local total, amplitude = 0, 0.5
	for _ = 1, 4 do
		total += math.noise(x, y, z) * amplitude
		x, y, z, amplitude = x * 2, y * 2, z * 2, amplitude / 2
	end
	return total
end
local function smoothStep(from: number, to: number, x: number): number
	local t = math.clamp((x - from) / (to - from), 0, 1)
	return t * t * (3 - 2 * t)
end
local function rockColour(x: number, y: number, z: number): (number, number, number)
	local band = 0.82 + 0.18 * math.sin(z * 0.9 + fbm(x / 10, y / 10, 80) * 5)
	local streak = smoothStep(0.15, 0.35, fbm(x / 3, y / 3, z / 20 + 81))
	local red, green, blue = ROCK[1] * band, ROCK[2] * band, ROCK[3] * band
	return red + (0.56 - red) * streak * 0.5, green + (0.45 - green) * streak * 0.5, blue + (0.28 - blue) * streak * 0.5
end

-- A lumpy rock half sunk in the ground (IslandPreview.luau's boulder).
local function boulder(mesh, cx: number, cy: number, cz: number, size: number, seed: number, heightScale: number?)
	local SIDES = 11
	local LEVELS = { { 0.5, 0.74 }, { 0.82, 0.48 }, { 1, 0.08 }, { 0.92, -0.6 } }
	local stretchX = 0.7 + 0.6 * (0.5 + math.noise(seed, 1.3, 2.7))
	local stretchY = 0.7 + 0.6 * (0.5 + math.noise(seed, 4.1, 2.7))
	local stretchZ = (0.55 + 0.6 * (0.5 + math.noise(seed, 7.9, 2.7))) * (heightScale or 1)
	local cuts = {}
	for k = 1, 2 do
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

-- Rough10's site: { bearing, distance, half length, height, shift, radius }.
local n = 10
local bearing, long, tall, shift, radius = 318, 26, 3.30, -10.5, 13.0
local ux, uy = math.cos(math.rad(bearing)), math.sin(math.rad(bearing))
local function onGap(along: number, across: number): (number, number)
	return ux * along - uy * across, uy * along + ux * across
end

chunkedPart("Stones", nil, ROCK, function(mesh)
	local middleX, middleY = onGap(0, shift)
	local main = math.min(2.2 * tall + 1.5, radius / 1.5)
	local kind = n % 3
	if kind == 1 then
		for s = 1, 3 do
			local a = s * 2.1 + n * 0.7
			boulder(mesh, middleX + math.cos(a) * main * 0.62, middleY + math.sin(a) * main * 0.62, -0.3, main * (0.82 - s * 0.1), n * 13 + s, 0.7)
		end
	else
		boulder(mesh, middleX, middleY, -0.3, if kind == 0 then main * 0.92 else main, n * 13, if kind == 0 then 1.25 else 1.6)
	end
	if kind == 0 then
		local a = n * 0.9
		boulder(mesh, middleX + math.cos(a) * main * 0.8, middleY + math.sin(a) * main * 0.8, -0.3, main * 0.68, n * 13 + 5, 0.75)
	end
	for s = 2, (if n % 4 == 0 then 1 else 7) do
		local a = n * 1.7 + (s - 4.5) * 0.42
		local spread = math.min(main * 0.9, radius - 2.5)
		boulder(mesh, middleX + math.cos(a) * spread, middleY + math.sin(a) * spread, -0.2, 0.8 + (s * 5 + n) % 3 * 0.45 + (if s % 3 == 0 then 1.2 else 0), s * 13 + n)
	end
	for s = 1, 10 do
		local bunch = if s <= 7 then n * 1.7 else n * 1.7 + 2.4
		local a = bunch + (s * 3 % 7 - 3) * 0.11
		local spread = main * 1.02 + (s * 5 % 4) * 0.5
		boulder(mesh, middleX + math.cos(a) * spread, middleY + math.sin(a) * spread, -0.1, 0.45 + (s * 7 % 5) * 0.3, s * 3 + n * 7)
	end
	local side = if n % 2 == 0 then 1 else -1
	local nearX, nearY = onGap(side * (radius + 1), shift - side * radius * 0.6)
	for s = 1, (if n % 3 == 1 then 0 else 3 + n % 3) do
		local a = s * 2.4 + n
		local size = if s == 1 then 1.8 + (n % 3) * 0.5 else 0.6 + ((s * 5 + n) % 4) * 0.35
		boulder(mesh, nearX + math.cos(a) * (s - 1) * 1.3, nearY + math.sin(a) * (s - 1) * 1.3, -0.1, size, s * 7 + n * 11)
	end
	if n % 3 ~= 0 then
		local farX, farY = onGap(-side * (long * 0.95 + (n % 4) * 1.5), shift + side * radius * (0.3 + (n % 3) * 0.14))
		for s = 1, 3 + n % 2 do
			local a = s * 2.4 + 2 + n
			local size = if s == 1 then 2.1 + (n % 3) * 0.6 else 0.7 + ((s * 5 + n) % 4) * 0.4
			boulder(mesh, farX + math.cos(a) * (s - 1) * 1.5, farY + math.sin(a) * (s - 1) * 1.5, -0.1, size, s * 7 + n * 17)
		end
	end
end, nil, rockColour, true)

-- The layout's rock finish: bold wide edge strokes over a light base, and
-- bands running up each stone on its own from the ground to its top. Each
-- chunk is named Stones_<cx>_<cy>_<cz>.
for _, entry in parts do
	if entry.chunkOf == "Stones" or entry.name == "Stones" then
		entry.lit, entry.wide, entry.gradient = 2.2, 1.5, 0.15
		entry.bandDepth = function(x: number, y: number, z: number): number
			local nearest, best = groundFeet[1], math.huge
			for _, foot in groundFeet do
				local dx, dy = x - foot[1], y - foot[2]
				local reach = (dx * dx + dy * dy) / (foot[3] * foot[3])
				if reach < best then
					nearest, best = foot, reach
				end
			end
			return 1 - math.clamp((z - SHADE_Z) / (nearest[3] * 1.4), 0, 1)
		end
	end
end
handFinish({ Stones = "rock" }, {}, { rock = "rock" })
finishParts()
