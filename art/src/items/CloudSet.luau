-- Cloud Set: 50 anime cumulus clouds from one genotype, baked here so the
-- game only places them. Each is a lumpy shell round a cluster of puffs,
-- with a flat base, cel shaded in two tones per puff (warm white lit,
-- lavender shadow), a crease line where puffs meet and an ink outline (an
-- inverted hull). About 14-36 studs wide; the game scales them up.
-- Laid out in a 10 x 5 grid for the preview.

local COUNT = 50
local RINGS, SIDES = 20, 36
local OUTLINE = 0.22
local CLOUD_TEXTURE = 256
-- Light from almost straight up, so a cloud turned any way stays lit on top.
local LX, LY, LZ = 0.25, 0.2, 0.95
do
	local l = math.sqrt(LX * LX + LY * LY + LZ * LZ)
	LX, LY, LZ = LX / l, LY / l, LZ / l
end

local HIGHLIGHT = { 1, 1, 1 }
local LIT = { 0.97, 0.96, 0.95 }
local MID = { 0.86, 0.88, 0.97 }
local BOUNCE = { 0.8, 0.88, 1 }
local RIM = { 1, 0.94, 0.8 }
local CREASE = { 0.8, 0.84, 0.97 }
local SHADOW = { 0.72, 0.77, 0.95 }
local DEEP = { 0.58, 0.64, 0.9 }
local INK = { 0.17, 0.22, 0.42 }

-- A seeded random source (the engine has no Random).
local function seeded(seed)
	local state = seed % 2147483647
	local function nextUnit()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	return {
		NextNumber = function(_, low, high)
			return low + (high - low) * nextUnit()
		end,
		NextInteger = function(_, low, high)
			return math.min(high, low + math.floor(nextUnit() * (high - low + 1)))
		end,
	}
end

-- The genotype: a seed picks width, height, puff count and how much it towers.
local function genotype(seed)
	local rng = seeded(seed)
	local width = rng:NextNumber(14, 36)
	local height = width * rng:NextNumber(0.3, 0.6)
	local count = rng:NextInteger(4, 12)
	local tower = rng:NextNumber(0, 2)
	local puffs = {}
	local spacing = width * 0.85 / count
	-- A bottom row resting on the base, so the puffs always join up.
	local baseRadius = math.max(spacing * 0.9, height * 0.18)
	for i = 1, count do
		local x = (((i - 0.5) / count) - 0.5) * width * 0.85
		for _, side in { -1, 1 } do
			local y = side * baseRadius * 0.6 + rng:NextNumber(-0.1, 0.1) * width
			table.insert(puffs, { x, y, baseRadius * 0.55, baseRadius })
		end
	end
	-- Upper puffs, bulging up in the middle; tower narrows the bulge.
	for i = 1, count do
		local t = (i - 0.5) / count
		local bulge = math.sin(t * math.pi) ^ (1 + tower)
		local radius = math.max(height * 0.28 * (0.6 + 0.6 * bulge) * rng:NextNumber(0.85, 1.15), spacing * 0.85)
		local x = (t - 0.5) * width * 0.8
		local z = radius * 0.6 + bulge * height * 0.5 * rng:NextNumber(0.8, 1.1)
		table.insert(puffs, { x, rng:NextNumber(-0.35, 0.35) * radius, z, radius })
	end
	-- Crown puffs on top of the upper row.
	for _ = 1, count // 2 do
		local under = puffs[2 * count + rng:NextInteger(2, math.max(2, count - 1))]
		local radius = under[4] * rng:NextNumber(0.55, 0.75)
		table.insert(puffs, {
			under[1] + rng:NextNumber(-0.4, 0.4) * under[4],
			under[2] + rng:NextNumber(-0.5, 0.5) * under[4],
			under[3] + under[4] * 0.6,
			radius,
		})
	end
	return { width = width, puffs = puffs, spineZ = baseRadius * 0.5, spineX = width * 0.85 / 2 - baseRadius, seed = seed }
end

-- Farthest point where a ray leaves a puff.
local function exitDistance(puffs, ox, oy, oz, dx, dy, dz)
	local best = 0
	for _, p in puffs do
		local px, py, pz = p[1] - ox, p[2] - oy, p[3] - oz
		local along = px * dx + py * dy + pz * dz
		local d2 = px * px + py * py + pz * pz - along * along
		local r2 = p[4] * p[4]
		if d2 < r2 then
			best = math.max(best, along + math.sqrt(r2 - d2))
		end
	end
	return best
end

-- The shell: a sphere grid round a spine along x, each vertex pushed out to
-- where its ray leaves the puffs, the base flattened at z = 0. With `hull`
-- it is grown by OUTLINE and wound the other way (inside out), for the ink outline. The
-- offset moves it into its preview grid cell.
local function shell(mesh, cloud, hull, offsetX, offsetY)
	local grid = {}
	for r = 0, RINGS do
		local phi = r / RINGS * math.pi
		grid[r] = {}
		local ox = -cloud.spineX + cloud.spineX * (1 - math.cos(phi))
		for s = 0, SIDES - 1 do
			local theta = s / SIDES * TAU
			local dx, dy, dz = -math.cos(phi), math.sin(phi) * math.cos(theta), math.sin(phi) * math.sin(theta)
			local t = exitDistance(cloud.puffs, ox, 0, cloud.spineZ, dx, dy, dz)
			if t <= 0 then
				t = cloud.spineZ
			end
			if hull then
				t += OUTLINE
			end
			local x, y, z = ox + dx * t, dy * t, cloud.spineZ + dz * t
			grid[r][s] = mesh:vertex(x + offsetX, y + offsetY, math.max(z, if hull then -OUTLINE * 0.5 else 0))
		end
	end
	for r = 0, RINGS - 1 do
		for s = 0, SIDES - 1 do
			local n = (s + 1) % SIDES
			local quad = { grid[r][s], grid[r][n], grid[r + 1][n], grid[r + 1][s] }
			if not hull then
				quad = { quad[4], quad[3], quad[2], quad[1] }
			end
			mesh:face(quad)
		end
	end
end

-- Cel paint. Each texel is shaded by the puff it belongs to (the one whose
-- surface it is nearest), so every puff reads as its own round lobe.
local function painter(cloud, offsetX, offsetY)
	local puffs = cloud.puffs
	local seed = cloud.seed
	return function(x, y, z, nx, ny, nz)
		x, y = x - offsetX, y - offsetY
		local first, second, owner = math.huge, math.huge, puffs[1]
		for _, p in puffs do
			local dx, dy, dz = x - p[1], y - p[2], z - p[3]
			local d = math.sqrt(dx * dx + dy * dy + dz * dz) - p[4]
			if d < first then
				first, second, owner = d, first, p
			elseif d < second then
				second = d
			end
		end
		-- Hull texels sit OUTLINE off the puffs and face in towards the spine.
		local inward = nx * x + ny * y + nz * (z - cloud.spineZ) < 0
		if inward and first > OUTLINE * 0.6 then
			return INK[1], INK[2], INK[3]
		end
		local px, py, pz = x - owner[1], y - owner[2], z - owner[3]
		local length = math.max(math.sqrt(px * px + py * py + pz * pz), 1e-4)
		local light = (px * LX + py * LY + pz * LZ) / length
		-- A hand-drawn wobble on the terminator.
		light += math.noise(x * 0.35 + seed, y * 0.35, z * 0.35) * 0.18
		if z < 0.05 or nz < -0.7 then
			return DEEP[1], DEEP[2], DEEP[3]
		end
		local color = if light > 0.78 then HIGHLIGHT
			elseif light > 0.42 then LIT
			elseif light > 0.3 then RIM
			elseif light > 0.12 then MID
			else SHADOW
		-- Light bounced up from below catches the lower rims of shadowed lobes.
		if light < 0.12 and pz / length < -0.35 and z > 0.6 then
			color = BOUNCE
		end
		-- Where two lobes meet: a crease line on the lit side, occlusion in shadow.
		if second - first < 0.18 then
			color = if light > 0.3 then CREASE else DEEP
		end
		return color[1], color[2], color[3]
	end
end

for index = 1, COUNT do
	local cloud = genotype(index * 7919)
	local offsetX = ((index - 1) % 10 - 4.5) * 45
	local offsetY = ((index - 1) // 10 - 2) * 45
	local mesh = Mesh.new()
	shell(mesh, cloud, false, offsetX, offsetY)
	shell(mesh, cloud, true, offsetX, offsetY)
	mesh:setSmooth(true)
	mesh:unwrap()
	local image = Image.new(CLOUD_TEXTURE, CLOUD_TEXTURE, 1, 1, 1)
	mesh:paint(image, painter(cloud, offsetX, offsetY))
	model.part(string.format("Cloud%02d", index), mesh, image, { preview = true })
end
