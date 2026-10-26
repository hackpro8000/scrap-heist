-- Yard Island: a floating yard island built from stacked rock columns, in
-- the style of a hand-sculpted stylised island. Three tiers of chunky
-- rock pillars ring the island, each tier tucked further in and
-- ending lower than the last. The pillars of a tier fit edge to edge like
-- basalt columns, with a crevice down each shared edge, and each is a
-- stack of blocks. The model is one closed outer shell over the columns,
-- with a soil lip draped over the rim, meshed as rings of vertices. Top at z = 0.7.
useTexelDensity(16)
local RADIUS = 26
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
-- A lower pillar rises to just above the highest foot of the pillars it sits
-- under, so no gap opens between tiers where an upper pillar ends short.
local function tuckedTop(above, from: number, to: number): number
	local top = -math.huge
	for _, upper in above do
		local start = from + (upper.from - from) % (2 * math.pi)
		local overlaps = start < to or start + (upper.to - upper.from) > from + 2 * math.pi
		if overlaps then top = math.max(top, upper.bottom) end
	end
	return top + 0.5
end
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
			top = if t == 1 then CAP_TOP else tuckedTop(pillars[t - 1], from.angle, toAngle),
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
	local chip = CHIP * (0.2 + peak)
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

-- How far the island's wall reaches at `angle` and height z, and the
-- pillar there, for painting: the outermost tier with a pillar standing
-- at that height.
local function wall(angle: number, z: number)
	for t = 1, #TIERS do
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

-- The column layout above gives the wall's reach per angle and height,
-- sampled once into a table and meshed directly as rings of vertices, bent
-- by a slow 3D warp so ledges tilt and curl under each other.
local ANGLES, STEP, FLOOR, LIP = 360, 0.2, -25, 0.35
local RIM_JAGGED, RIM_POKE = 0.166, 0.06
local RIM_BLEND = (CAP_TOP - TIERS[1][3]) * 0.5
local WARP, CAP_RINGS = 0.7, 8
-- Rows are finer through the soil lip so its edge doesn't step.
local LIP_STEP, LIP_BAND = 0.04, 2.5
-- The shell and its shading are cached under a key hashing every line above
-- "-- cached above", so changes below it skip the rebuild.
local function shade(entries, occluders, gradient: number?)
	for _, entry in entries do
		entry.mesh:paintShading(entry.image, {
			highlight = 0.5,
			highlightRamp = 0.3,
			shadow = 0.75,
			gradient = gradient or GRADIENT,
			blend = 1,
			brushed = true,
			occluders = occluders,
		})
	end
end

-- The wall's reach per row (stepping down from the top) and angle, with the
-- calm rim easing into the jagged pillar faces and the soil lip standing
-- proud of the rock. Rows below every pillar's foot are empty.
local function reachTable()
	local rim = {}
	for j = 0, ANGLES - 1 do
		-- The rim's jaggedness, its departure from the smooth outline,
		-- exaggerated inward by RIM_JAGGED and tamed outward by RIM_POKE.
		local angle = 2 * math.pi * j / ANGLES
		local smooth = TIERS[1][1] * outlineScale(angle)
		local departure = wall(angle, CAP_TOP) - smooth
		rim[j] = smooth + departure * (if departure > 0 then RIM_POKE else RIM_JAGGED)
	end
	local rows, heights = {}, {}
	local z = CAP_TOP
	while z > FLOOR do
		local row, any = {}, false
		for j = 0, ANGLES - 1 do
			local angle = 2 * math.pi * j / ANGLES
			local reach = wall(angle, z)
			if reach > 0.3 then any = true end
			local t = math.clamp((CAP_TOP - z) / RIM_BLEND, 0, 1)
			t = t * t * (3 - 2 * t)
			local r = if reach > 0.3 then rim[j] + (reach - rim[j]) * t else -1
			-- The lip tapers over several rows so its lower edge doesn't step.
			local lip = math.clamp((drape(angle) - (CAP_TOP - z)) / 0.8, 0, 1)
			if lip > 0 then
				r = math.max(r, rim[j]) + LIP * lip * lip * (3 - 2 * lip)
			end
			row[j] = r
		end
		if not any then break end
		table.insert(rows, row)
		table.insert(heights, z)
		z -= if CAP_TOP - z < LIP_BAND then LIP_STEP else STEP
	end
	return rows, heights
end

local shell = model.cached(CACHE_KEY, function()
chunkedPart("Island", nil, GROUND, function(mesh)
	local rows, heights = reachTable()
	-- The wall is a grid wrapped round the island: one ring of vertices per
	-- row of the reach table, so every face points outward by construction.
	-- Where a column has no rock the ring pulls in to the axis, closing the
	-- underside. Rows are bent by the same slow warp the paint reads, faded
	-- out toward the top so the rim stays level.
	local function ringPoint(row: number, j: number, r: number)
		local zr = heights[row]
		local angle = 2 * math.pi * j / ANGLES
		local x, y = r * math.cos(angle), r * math.sin(angle)
		-- The warp reads the outline, not the vertex, so a column shifts as
		-- one and its rows never cross where the reach jumps.
		local wx, wy = RADIUS * math.cos(angle), RADIUS * math.sin(angle)
		local fade = math.clamp((CAP_TOP - zr) / 1.5, 0, 1)
		return x, y, zr - fade * WARP * math.noise(wx / 7, wy / 7, zr / 9 + 5)
	end
	local rings = {}
	for row, reach in rows do
		local ring = {}
		for j = 0, ANGLES - 1 do
			local x, y, z = ringPoint(row, j, math.max(reach[j], 0))
			ring[j] = if row == 1 then mesh:exactVertex(x, y, z) else mesh:vertex(x, y, z)
		end
		rings[row] = ring
	end
	for row = 1, #rings - 1 do
		local upper, lower = rings[row], rings[row + 1]
		for j = 0, ANGLES - 1 do
			local l = (j + 1) % ANGLES
			mesh:face({ upper[j], lower[j], lower[l] })
			mesh:face({ upper[j], lower[l], upper[l] })
		end
	end
	-- The top: dead flat rings shrinking from the rim to the centre.
	local outer = rings[1]
	for n = 1, CAP_RINGS do
		local s = 1 - n / CAP_RINGS
		local inner = {}
		for j = 0, ANGLES - 1 do
			local x, y = ringPoint(1, j, math.max(rows[1][j], 0) * s)
			inner[j] = if n == CAP_RINGS then nil else mesh:exactVertex(x, y, CAP_TOP)
		end
		local centre = if n == CAP_RINGS then mesh:exactVertex(0, 0, CAP_TOP) else nil
		for j = 0, ANGLES - 1 do
			local l = (j + 1) % ANGLES
			if centre then
				mesh:face({ centre, outer[j], outer[l] })
			else
				mesh:face({ outer[j], inner[l], inner[j] })
				mesh:face({ outer[j], outer[l], inner[l] })
			end
		end
		outer = inner
	end
	-- The bottom: the last ring closes onto a point under the axis.
	local last = rings[#rings]
	local tip = mesh:vertex(0, 0, heights[#rings] - STEP)
	for j = 0, ANGLES - 1 do
		mesh:face({ tip, last[(j + 1) % ANGLES], last[j] })
	end
end, 45, function(x, y, z)
	-- Paint in the same warped space the mesh was carved from, so blocks,
	-- tints and strata follow the meshed ledges.
	local wz = z + WARP * math.noise(x / 7, y / 7, z / 9 + 5)
	local wa = math.atan2(y, x) + 0.02 * math.noise(x / 5, y / 5, z / 5 + 17)
	local _, pillar = wall(wa, wz)
	-- The flat top keeps its true height so it paints as even ground.
	local depth = if z > CAP_TOP - 0.01 then 0 else math.min(wz, z) - CAP_TOP
	return islandPaint(x, y, depth, if pillar then pillar.seed else nil, if pillar then (blockAt(pillar, wz)).tint else nil)
end)

-- Aggressive shading: half-strength edge highlights, ramping 30% stronger
-- toward the bottom, and strong contact shadows, with the shell as its own
-- occluder so the crevices and overhangs darken.
local entries = table.clone(parts)
local meshes = {}
for _, entry in entries do
	table.insert(meshes, entry.mesh)
end
shade(entries, meshes)
table.clear(parts)
return entries
end)
-- cached above

for _, entry in shell do
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
