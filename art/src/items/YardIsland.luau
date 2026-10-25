-- Yard Island: a floating yard island built from stacked rock columns, in
-- the style of a hand-sculpted stylised island. Three tiers of chunky
-- rock pillars ring the island, each tier tucked further in and
-- ending lower than the last. Each pillar is a polygonal prism standing on
-- the shell's profile, a stack of blocks, with clefts between pillars and a soil lip draped over the rim. The model is one closed outer shell over the
-- columns, with nothing inside. Top at z = 0.7.
useTexelDensity(16)
local RADIUS = 20
local GROUND = { 0.3, 0.27, 0.22 }
local STRATA = { { 0.5, 0.4, 0.27 }, { 0.36, 0.35, 0.34 }, { 0.48, 0.3, 0.22 } }
local TOPSOIL = { 0.24, 0.19, 0.14 }

local function random(k: number): number
	local s = math.sin(k * 12.9898 + 4.1414) * 43758.5453
	return s - math.floor(s)
end

-- The island's texture: speckled ground on top, then topsoil fading into
-- wavy rock strata that darken with depth. A pillar's `seed` shifts its
-- strata and grain so neighbours don't match, and each rock block has its
-- own `tint`.
local function islandPaint(x: number, y: number, z: number, seed: number?, tint: number?)
	local below = -z
	if below < 0.3 then
		local k = 1 + 0.12 * math.noise(x / 4, y / 4, 31) + 0.05 * math.noise(x * 3, y * 3, 37)
		return GROUND[1] * k, GROUND[2] * k, GROUND[3] * k
	end
	local s = seed or 0
	local band = math.noise(x / 9 + s, y / 9, z / 2) * 0.6 + z * (0.8 + 0.2 * random(s + 1)) + random(s + 2) * 3
	local wave = math.sin(band * 2.4)
	local layer = STRATA[math.floor(band * 2.4 / (2 * math.pi)) % 3 + 1]
	local k = (tint or 1) * (1 + 0.1 * wave + 0.06 * math.noise(x * 2 + s, y * 2, z * 2))
	if wave > 0.93 then k -= 0.25 end
	k *= 1 - 0.6 * math.clamp((below - 3) / 20, 0, 1)
	local soil = 1 - math.clamp((below - 0.5) / 4 + 0.3 * math.noise(x / 2, y / 2, 41), 0, 1)
	local r, g, b = layer[1] * k, layer[2] * k, layer[3] * k
	return r + (TOPSOIL[1] - r) * soil, g + (TOPSOIL[2] - g) * soil, b + (TOPSOIL[3] - b) * soil
end

-- The island's wobbly outline, as a radius scale per angle.
local function outlineScale(angle: number): number
	return 1 + 0.07 * math.sin(3 * angle + 0.6) + 0.05 * math.sin(5 * angle + 2.1) + 0.03 * math.sin(9 * angle)
end

-- Each tier is a ring of pillars: { reach, pillar count, bottom, seed }.
-- Lower tiers sit further in, so each shows below the one above it.
local CAP_TOP = 0.7
local TIERS = {
	{ RADIUS * 0.84, 10, -8, 11 },
	{ RADIUS * 0.58, 8, -14, 23 },
	{ RADIUS * 0.34, 6, -19.5, 37 },
}
local BEVEL, CORNER = 0.6, 1.5
-- Block-edge and foot rounding plus surface noise, held off for now to
-- judge the plain polygonal geometry.
local ROUNDED = false

-- A point on the island's outline at `angle`, scaled to `reach`.
local function outlinePoint(reach: number, angle: number): (number, number)
	local r = reach * outlineScale(angle)
	return math.cos(angle) * r, math.sin(angle) * r
end

-- Pillar layout per tier. Each pillar is a prism standing on the shell
-- profile: an irregular polygon in its own frame, with its tangent along
-- the outline and its normal facing out of it, set in so its outer faces
-- lie on the shell. Neighbours overlap a little, so the clefts between
-- them follow the shell, not the island's centre.
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
		local at = angle + span / 2
		local ownReach = reach * (0.94 + 0.12 * random(seed + i + 40))
		local x0, y0 = outlinePoint(ownReach, at - 0.01)
		local x1, y1 = outlinePoint(ownReach, at + 0.01)
		local tx, ty = x1 - x0, y1 - y0
		local length = math.sqrt(tx * tx + ty * ty)
		tx, ty = tx / length, ty / length
		local nx, ny = ty, -tx
		local half = ownReach * outlineScale(at) * span / 2 * 1.15
		local depth = half * 1.3
		local pillarSeed = seed * 31 + i * 7
		-- The cross-section: 5-7 corners round the centre, jittered in
		-- angle and distance so the faces come out uneven.
		local shape = {}
		local corners = 5 + pillarSeed % 3
		for k = 0, corners - 1 do
			local phi = (k + (random(pillarSeed + k * 29) - 0.5) * 0.5) / corners * 2 * math.pi
			local stretch = 0.85 + 0.3 * random(pillarSeed + k * 31)
			table.insert(shape, { math.cos(phi) * half * stretch, math.sin(phi) * depth * stretch })
		end
		local px, py = outlinePoint(ownReach, at)
		local foot = bottom - (TIERS[t][3] - (if t > 1 then TIERS[t - 1][3] else CAP_TOP)) * 0.5 * (random(seed + i + 80) - 0.5)
		-- The bottom tier's pillars all end level, so none hangs alone
		-- below the rest.
		if t == #TIERS then foot = bottom end
		list[i] = {
			x = px - nx * depth,
			y = py - ny * depth,
			tx = tx,
			ty = ty,
			nx = nx,
			ny = ny,
			shape = shape,
			bound = depth * 1.3,
			bottom = foot,
			seed = pillarSeed,
			top = if t == 1 then CAP_TOP else TIERS[t - 1][3] + 0.5,
			-- Each pillar tapers and leans in toward its foot by its own
			-- amount.
			taper = 0.08 + 0.12 * random(seed + i + 120),
			lean = 0.1 + 0.25 * random(seed + i + 140),
		}
		-- Each pillar is a stack of 2-3 rock blocks split by cracks, each
		-- block sitting a little in or out from the one above.
		local pillar = list[i]
		pillar.blocks = {}
		local joints = 1 + math.floor(random(seed + i + 200) * 2)
		local height = pillar.top - pillar.bottom
		for n = 1, joints + 1 do
			table.insert(pillar.blocks, {
				floor = if n > joints then -math.huge else pillar.top - height * (n + (random(seed + i + n * 13 + 210) - 0.5) * 0.5) / (joints + 1),
				offset = if n == 1 then 0 else (random(seed + i + n * 13 + 220) - 0.4) * 1.2,
				tint = 0.88 + 0.24 * random(seed + i + n * 13 + 230),
			})
		end
		angle += span
	end
	pillars[t] = list
end

-- The block of `pillar` at height z, and the height of its top.
local function blockAt(pillar, z: number)
	local ceiling = pillar.top
	for _, block in pillar.blocks do
		if z >= block.floor then return block, ceiling end
		ceiling = block.floor
	end
	return pillar.blocks[#pillar.blocks], ceiling
end

-- How far out along the ray from the island's centre in direction (dx, dy)
-- the pillar's cross-section at height z reaches, or nil if it misses.
local function pillarReach(pillar, dx: number, dy: number, z: number): number?
	local shift = math.clamp((pillar.top - z) / (pillar.top - pillar.bottom), 0, 1)
	local scale = 1 - pillar.taper * shift
	local block = blockAt(pillar, z)
	local inward = pillar.bound * pillar.lean * shift - block.offset
	local cx, cy = pillar.x - pillar.nx * inward, pillar.y - pillar.ny * inward
	-- Skip pillars well off to the side of the ray.
	if math.abs(cx * dy - cy * dx) > pillar.bound then return nil end
	local far = nil
	local shape = pillar.shape
	for k = 1, #shape do
		local a, b = shape[k], shape[k % #shape + 1]
		local ax = cx + (pillar.tx * a[1] + pillar.nx * a[2]) * scale
		local ay = cy + (pillar.ty * a[1] + pillar.ny * a[2]) * scale
		local ex = (pillar.tx * (b[1] - a[1]) + pillar.nx * (b[2] - a[2])) * scale
		local ey = (pillar.ty * (b[1] - a[1]) + pillar.ny * (b[2] - a[2])) * scale
		-- Solve s * d = a + u * e for the edge from a to b.
		local denominator = dx * ey - dy * ex
		if math.abs(denominator) > 1e-9 then
			local s = (ax * ey - ay * ex) / denominator
			local u = (ax * dy - ay * dx) / denominator
			if u >= 0 and u <= 1 and s > 0 and (far == nil or s > far) then far = s end
		end
	end
	return far
end

-- How far the island's wall reaches at `angle` and height z, and the
-- pillar there, for painting: the furthest reach of any pillar standing
-- at that height, cut flat under its foot.
local function wall(angle: number, z: number)
	local dx, dy = math.cos(angle), math.sin(angle)
	local best, owner = 0.05, nil
	for t = 1, #TIERS do
		for _, pillar in pillars[t] do
			if z < pillar.bottom or z > pillar.top then continue end
			local r = pillarReach(pillar, dx, dy, z)
			if r == nil then continue end
			if ROUNDED then
				-- Round each block's edges into the cracks above and below
				-- it, and the pillar's foot, and roughen the faces.
				local block, ceiling = blockAt(pillar, z)
				r += 0.2 * math.noise(angle * 4, z / 4, pillar.seed % 97)
				local edge = math.min(if ceiling < pillar.top then ceiling - z else math.huge, z - block.floor)
				if edge < BEVEL then
					r -= BEVEL * (1 - math.sqrt(1 - (1 - edge / BEVEL) ^ 2))
				end
				local lift = z - pillar.bottom
				if lift < CORNER then
					r -= CORNER * (1 - math.sqrt(1 - (1 - lift / CORNER) ^ 2))
				end
			end
			if r > best then
				best, owner = r, pillar
			end
		end
	end
	return best, owner
end

-- The soil lip: how far it drapes down the rim at `angle`, in clumps.
local function drape(angle: number): number
	local n = math.noise(angle * 7, 3.7) + 0.5 * math.noise(angle * 23, 9.1)
	return 0.35 + 1.1 * math.clamp(n + 0.4, 0, 1)
end

-- One closed outer shell: rows of wall points stepping down from the top to
-- the last column's foot, a flat top in concentric rings and a small cap at the bottom.
local ANGLES, STEP, FLOOR, LIP, TOP_RINGS = 240, 0.3, -25, 0.35, 8
-- The shell and its shading are cached under a key hashing every line above
-- "-- cached above", so changes below it skip the rebuild.
local function shade(entries, occluders, gradient: number?)
	for _, entry in entries do
		entry.mesh:paintShading(entry.image, {
			highlight = 0.5,
			highlightRamp = 0.3,
			shadow = 1.5,
			gradient = gradient or GRADIENT,
			blend = 0.78,
			occluders = occluders,
		})
	end
end
local shell = model.cached(CACHE_KEY, function()
part("Island", nil, GROUND, function(mesh)
	local rim = {}
	for j = 0, ANGLES - 1 do
		-- The rim follows the top pillars' jagged faces.
		rim[j] = wall(2 * math.pi * j / ANGLES, CAP_TOP)
	end
	local rows = {}
	local z = CAP_TOP
	while z > FLOOR + STEP / 2 do
		-- Stop once every pillar has ended, so no needle trails below.
		local any = false
		for j = 0, ANGLES - 1, 8 do
			if wall(2 * math.pi * j / ANGLES, z) > 0.3 then
				any = true
				break
			end
		end
		if not any then break end
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
	local bottom = mesh:vertex(0, 0, z + STEP)
	for j = 0, ANGLES - 1 do
		mesh:face({ bottom, rows[#rows][(j + 1) % ANGLES], rows[#rows][j] })
	end
end, false, function(x, y, z)
	local _, pillar = wall(math.atan2(y, x), z)
	return islandPaint(x, y, z - CAP_TOP, if pillar then pillar.seed else nil, if pillar then (blockAt(pillar, z)).tint else nil)
end)

-- Aggressive shading: half-strength edge highlights, ramping 30% stronger
-- toward the bottom, and strong contact shadows, with the shell as its own
-- occluder so the crevices and overhangs darken.
local entries = table.clone(parts)
shade(entries, { entries[1].mesh })
table.clear(parts)
return entries
end)
-- cached above

for _, entry in shell do
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
