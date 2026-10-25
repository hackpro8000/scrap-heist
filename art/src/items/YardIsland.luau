-- Yard Island: a floating yard island built from stacked rock columns, in
-- the style of a hand-sculpted stylised island. Three tiers of chunky
-- rock pillars ring the island, each tier tucked further in and
-- ending lower than the last. The pillars of a tier fit edge to edge like
-- basalt columns, with a crevice down each shared edge, and each is a
-- stack of blocks. The model is one closed outer shell over the columns,
-- with a soil lip draped over the rim and nothing inside. Top at z = 0.7.
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
-- Pillar layout per tier. The pillars tile their tier's ring like basalt
-- columns: each owns a slice of the outline, and neighbours share the
-- corner where their faces meet, so they butt together instead of
-- overlapping. A V-shaped crevice runs down every shared edge, and each
-- outer face is broken into a few flat facets.
local CREVICE_DEPTH, CREVICE_WIDTH = 1.1, 0.7
local CRACK_DEPTH, CRACK_HEIGHT = 0.5, 0.35
local CHIP = 0.45
local TOP_LIP, TOP_LIP_HEIGHT = 1.8, 3.5
local pillars = {}
for t, tier in TIERS do
	local reach, count, bottom, seed = tier[1], tier[2], tier[3], tier[4]
	local list = {}
	local weights, total = {}, 0
	for i = 1, count do
		weights[i] = 0.7 + 0.6 * random(seed + i)
		total += weights[i]
	end
	-- Shared corners: each sits on the outline, pulled in by its own amount.
	local edges, angle = {}, random(seed) * 2 * math.pi
	for i = 1, count do
		edges[i] = { angle = angle, reach = reach * (0.88 + 0.12 * random(seed + i + 60)) }
		angle += weights[i] / total * 2 * math.pi
	end
	for i = 1, count do
		local from, to = edges[i], edges[i % count + 1]
		local toAngle = if i == count then to.angle + 2 * math.pi else to.angle
		-- The face: the two shared corners plus 1-2 corners between them,
		-- standing proud or sunk so the face reads as jagged facets.
		local corners = { { from.angle, from.reach } }
		local inner = 1 + math.floor(random(seed + i + 70) * 3)
		for k = 1, inner do
			local f = (k + (random(seed + i * 5 + k + 90) - 0.5) * 0.6) / (inner + 1)
			table.insert(corners, { from.angle + (toAngle - from.angle) * f, reach * (0.94 + 0.14 * random(seed + i * 5 + k + 100)) })
		end
		table.insert(corners, { toAngle, to.reach })
		local foot = bottom - (TIERS[t][3] - (if t > 1 then TIERS[t - 1][3] else CAP_TOP)) * 0.9 * (random(seed + i + 80) - 0.5)
		-- The bottom tier's pillars end at stepped heights, so the tip
		-- comes out ragged.
		if t == #TIERS then foot = bottom + 3.5 * (random(seed + i + 85) - 0.6) end
		local pillar = {
			from = from.angle,
			to = toAngle,
			corners = corners,
			bottom = foot,
			top = if t == 1 then CAP_TOP else TIERS[t - 1][3] + 0.5,
			seed = seed * 31 + i * 7,
			blocks = {},
		}
		-- Each pillar is a stack of 2-3 rock blocks split by cracks.
		local joints = 1 + math.floor(random(seed + i + 200) * 2)
		local height = pillar.top - pillar.bottom
		for n = 1, joints + 1 do
			table.insert(pillar.blocks, {
				floor = if n > joints then -math.huge else pillar.top - height * (n + (random(seed + i + n * 13 + 210) - 0.5) * 0.5) / (joints + 1),
				tint = 0.88 + 0.24 * random(seed + i + n * 13 + 230),
				-- Blocks jut out or sit back from their neighbours above and below.
				jut = 0.9 * (random(seed + i + n * 13 + 240) - 0.4),
			})
		end
		list[i] = pillar
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

-- How far out `pillar` reaches at `angle` (already inside its slice) and
-- height z: its faceted face, tapering in toward the tier's foot, with a
-- crevice at each shared edge and a crack under each block.
local function pillarReach(pillar, t: number, angle: number, z: number): number
	local corners = pillar.corners
	local r = corners[#corners][2]
	for k = 1, #corners - 1 do
		local a, b = corners[k], corners[k + 1]
		if angle <= b[1] then
			r = a[2] + (b[2] - a[2]) * (angle - a[1]) / (b[1] - a[1])
			break
		end
	end
	r *= outlineScale(angle)
	-- Taper by the tier, not the pillar, so shared corners stay shared.
	local tierTop = if t == 1 then CAP_TOP else TIERS[t - 1][3] + 0.5
	r *= 1 - 0.15 * math.clamp((tierTop - z) / (tierTop - TIERS[t][3]), 0, 1)
	-- The top layer flares out over the columns below it to form a lip,
	-- undercut by a short slope.
	if t == 1 then
		r += TOP_LIP * math.clamp((z - (tierTop - TOP_LIP_HEIGHT)) / 1.2, 0, 1)
	end
	local block, ceiling = blockAt(pillar, z)
	local gap = math.min(angle - pillar.from, pillar.to - angle) * r
	r -= CREVICE_DEPTH * math.max(0, 1 - gap / CREVICE_WIDTH)
	r += block.jut * math.min(1, gap / CREVICE_WIDTH)
	if block.floor > -math.huge then
		r -= CRACK_DEPTH * math.max(0, 1 - math.abs(z - block.floor) / CRACK_HEIGHT)
	end
	-- Chipped bevels: every block edge and the pillar's sides are cut back
	-- at 45 degrees by a depth that wanders along the edge, so they read
	-- as knocked-off chips rather than a clean chamfer. Only the noise peaks
	-- chip deep, so chips are long but sparse along a mostly crisp edge.
	local along = (angle - pillar.from) * r
	local peak = math.clamp((math.noise(along / 2.5, z / 2.5, pillar.seed % 97) - 0.1) * 3, 0, 1)
	local chip = CHIP * (0.2 + 2 * peak)
	-- Vertical edges: the shared sides and every facet fold on the face.
	local side = gap
	for k = 2, #corners - 1 do
		side = math.min(side, math.abs(angle - corners[k][1]) * r)
	end
	local level = math.min(z - math.max(block.floor, pillar.bottom), if ceiling < pillar.top then ceiling - z else math.huge)
	-- Corners, where a vertical edge meets a block edge, chip deeper.
	local edge = math.min(side, level, (side + level) * 0.6)
	if edge < chip then r -= chip - edge end
	return r
end

-- How far tier t's rock facets reach at `angle`, before the outline's wobble.
local function facetReach(t: number, angle: number): number
	for _, pillar in pillars[t] do
		local a = pillar.from + (angle - pillar.from) % (2 * math.pi)
		if a > pillar.to then continue end
		local corners = pillar.corners
		for k = 1, #corners - 1 do
			local c, d = corners[k], corners[k + 1]
			if a <= d[1] then
				return c[2] + (d[2] - c[2]) * (a - c[1]) / (d[1] - c[1])
			end
		end
		return corners[#corners][2]
	end
	return TIERS[t][1]
end

-- How far the island's wall reaches at `angle` and height z, and the
-- pillar there, for painting: the outermost tier, of the first `tiers`,
-- with a pillar standing at that height.
local function wall(angle: number, z: number, tiers: number?)
	for t = 1, tiers or #TIERS do
		for _, pillar in pillars[t] do
			local a = pillar.from + (angle - pillar.from) % (2 * math.pi)
			if a > pillar.to then continue end
			if z >= pillar.bottom and z <= pillar.top then
				return pillarReach(pillar, t, a, z), pillar
			end
			break
		end
	end
	return 0.05, nil
end

-- The soil lip: how far it drapes down the rim at `angle`, in clumps.
local function drape(angle: number): number
	local n = math.noise(angle * 7, 3.7) + 0.5 * math.noise(angle * 23, 9.1)
	return 0.35 + 1.1 * math.clamp(n + 0.4, 0, 1)
end

-- The top slab: one closed shell of rows stepping down from the top to the
-- slab's underside, a flat top in concentric rings and a cap at the bottom.
-- Every column's blocks below it are built as separate faceted rocks.
-- The columns' blocks as closed rocks: each block's footprint is its
-- pillar's wedge of facet corners, closed by two inner corners hidden in
-- the island, and its outer edges are cut back by a bevel that varies
-- per block. Corners wander a little so no two rocks are true.
local BEVEL, WANDER = 0.35, 0.2
local function blockRocks(mesh, pillar, t: number)
	local tierTop = if t == 1 then CAP_TOP else TIERS[t - 1][3] + 0.5
	local inside = TIERS[t][1] * 0.45
	local ceiling = CAP_TOP - TOP_LIP_HEIGHT
	for n, block in pillar.blocks do
		local floor = math.max(block.floor, pillar.bottom)
		-- Blocks hidden inside the top slab are skipped.
		if floor > ceiling - 1 then
			ceiling = math.min(ceiling, block.floor)
			continue
		end
		local key = pillar.seed + n * 17
		local bevel = BEVEL * (0.6 + 0.9 * random(key + 1))
		-- A ring of the footprint at height z, pulled in by `inset`.
		local function ring(z: number, inset: number, salt: number)
			local taper = 1 - 0.15 * math.clamp((tierTop - z) / (tierTop - TIERS[t][3]), 0, 1)
			local points = {}
			local corners = pillar.corners
			for k, corner in corners do
				local r = (corner[2] * outlineScale(corner[1]) * taper + block.jut) - inset
				r += WANDER * (random(key + k * 3 + salt) - 0.5) * 2
				-- The shared sides sit back a hair so neighbours don't touch.
				local shift = if k == 1 then 1 elseif k == #corners then -1 else 0
				local angle = corner[1] + shift * (0.12 + inset) / r
				table.insert(points, mesh:vertex(math.cos(angle) * r, math.sin(angle) * r, z))
			end
			for _, k in { #corners, 1 } do
				local angle = corners[k][1] + (if k == 1 then 1 else -1) * (0.12 + inset) / inside
				table.insert(points, mesh:vertex(math.cos(angle) * inside, math.sin(angle) * inside, z))
			end
			return points
		end
		local rings = {
			ring(floor, bevel, 0),
			ring(floor + bevel, 0, 40),
			ring(ceiling - bevel, 0, 80),
			ring(ceiling, bevel, 120),
		}
		for i = 1, #rings - 1 do
			local low, high = rings[i], rings[i + 1]
			for j = 1, #low do
				local l = j % #low + 1
				mesh:face({ low[j], low[l], high[l], high[j] })
			end
		end
		local mid = (pillar.from + pillar.to) / 2
		local centre = (inside + TIERS[t][1]) / 2
		local top = mesh:vertex(math.cos(mid) * centre, math.sin(mid) * centre, ceiling)
		local bottom = mesh:vertex(math.cos(mid) * centre, math.sin(mid) * centre, floor)
		local last, first = rings[#rings], rings[1]
		for j = 1, #last do
			local l = j % #last + 1
			mesh:face({ top, last[j], last[l] })
			mesh:face({ bottom, first[l], first[j] })
		end
		ceiling = block.floor
	end
end

local ANGLES, STEP, FLOOR, LIP, TOP_RINGS = 480, 0.15, -25, 0.35, 8
local SLAB_BOTTOM = CAP_TOP - TOP_LIP_HEIGHT
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
	-- Smooth across the sampled rock, but keep the rim and deep folds creased.
	mesh:setSmooth(60)
	-- The rim follows the top tier's faceted rocks, flared out by the lip,
	-- so the slab's edge lines up with the columns below it.
	local rim = {}
	for j = 0, ANGLES - 1 do
		local angle = 2 * math.pi * j / ANGLES
		rim[j] = facetReach(1, angle) * outlineScale(angle) + TOP_LIP
	end
	-- Each column steps down the soil to its own drape depth, then evenly
	-- down the rock to the slab's underside, so the soil's edge follows the
	-- drape exactly instead of snapping to rows of fixed height. The soil
	-- steps tighten toward its edge, where it curls back in to the rock.
	local SOIL_STEPS = { 0, 0.2, 0.4, 0.6, 0.75, 0.85, 0.92, 0.97, 1 }
	local ROCK_ROWS = math.ceil((CAP_TOP - SLAB_BOTTOM) / STEP)
	local rows = {}
	for i = 1, #SOIL_STEPS + ROCK_ROWS do
		rows[i] = {}
	end
	for j = 0, ANGLES - 1 do
		local angle = 2 * math.pi * j / ANGLES
		local edge = CAP_TOP - drape(angle)
		for i = 1, #rows do
			local z, r
			if i <= #SOIL_STEPS then
				local u = SOIL_STEPS[i]
				z = CAP_TOP - u * (CAP_TOP - edge)
				r = rim[j] + LIP * math.clamp((1 - u) / 0.2, 0, 1)
			else
				z = edge + (SLAB_BOTTOM - edge) * (i - #SOIL_STEPS) / ROCK_ROWS
				-- The slab's underside slopes back in to the columns' faces.
				r = rim[j] - TOP_LIP * (1 - math.clamp((z - SLAB_BOTTOM) / 1.2, 0, 1))
			end
			rows[i][j] = mesh:vertex(math.cos(angle) * r, math.sin(angle) * r, z)
		end
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
	local bottom = mesh:vertex(0, 0, SLAB_BOTTOM)
	for j = 0, ANGLES - 1 do
		mesh:face({ bottom, rows[#rows][(j + 1) % ANGLES], rows[#rows][j] })
	end
	for t = 1, #TIERS do
		for _, pillar in pillars[t] do
			blockRocks(mesh, pillar, t)
		end
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
