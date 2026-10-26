-- Arena Island: the arena's octagonal floating island, built the same way
-- as Yard Island, from stacked rock columns, in
-- the style of a hand-sculpted stylised island. Three tiers of chunky
-- rock pillars ring the island, each tier tucked further in and
-- ending lower than the last. The pillars of a tier fit edge to edge like
-- basalt columns, with a crevice down each shared edge, and each is a
-- stack of blocks. The model is one closed outer shell over the columns,
-- with a soil lip draped over the rim, meshed as rings of vertices. Top at z = 0.7,
-- sinking into the arena bowl in the middle.
useTexelDensity(16)
local RADIUS = 61
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
	-- The arena's octagon, faces at 0 and 45 degrees, its corners softened,
	-- with a gentle wobble.
	local sector = (angle + math.pi / 8) % (math.pi / 4) - math.pi / 8
	local wobble = 0.07 * math.sin(3 * angle + 0.6) + 0.05 * math.sin(5 * angle + 2.1) + 0.03 * math.sin(9 * angle)
	return 1 / math.cos(sector * 0.85) + 0.2 * wobble
end

-- The arena on top, matching ServerMap: a flat ring road from ROAD_INNER
-- out, banking down to the sunken floor inside ARENA_FLOOR. Radii are
-- octagon radii, measured to the middle of a face.
local ROAD_INNER, ARENA_FLOOR, ARENA_DROP = 50, 36, 5.5
local function octagonRadius(x: number, y: number): number
	local sector = (math.atan2(y, x) + math.pi / 8) % (math.pi / 4) - math.pi / 8
	return math.sqrt(x * x + y * y) * math.cos(sector)
end
local function bowlDrop(radius: number): number
	return ARENA_DROP * (1 - math.clamp((radius - ARENA_FLOOR) / (ROAD_INNER - ARENA_FLOOR), 0, 1))
end
-- The top's rings, by octagon radius: the road's inner edge, the bank, the
-- floor's edge, then the floor.
local BOWL_RINGS = { 55, ROAD_INNER, 46.5, 43, 39.5, ARENA_FLOOR, 24, 12 }

-- Each tier is a ring of pillars: { reach, pillar count, bottom, seed }.
-- Lower tiers sit further in, so each shows below the one above it.
local CAP_TOP = 0.7
local TIERS = {
	{ RADIUS * 1.02, 22, -17, 11 },
	{ RADIUS * 0.72, 16, -30, 23 },
	{ RADIUS * 0.43, 10, -42, 37 },
}
-- Pillar layout per tier. The pillars tile their tier's ring like basalt
-- columns: each owns a slice of the outline, and neighbours share the
-- corner where their faces meet, so they butt together instead of
-- overlapping. A V-shaped crevice runs down every shared edge, and each
-- outer face is broken into a few flat facets.
local CREVICE_DEPTH, CREVICE_WIDTH = 2, 1.2
local CRACK_DEPTH, CRACK_HEIGHT = 0.9, 0.6
local CHIP = 0.8
local TOP_LIP, TOP_LIP_HEIGHT = 3.5, 7
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
		if t == #TIERS then foot = bottom + 7 * (random(seed + i + 85) - 0.6) end
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
local ANGLES, STEP, FLOOR, LIP = 720, 0.4, -52, 0.6
local RIM_JAGGED, RIM_POKE = 0.166, 0.06
local RIM_BLEND = (CAP_TOP - TIERS[1][3]) * 0.5
local WARP = 1.4
-- Rows are finer through the soil lip so its edge doesn't step.
local LIP_STEP, LIP_BAND = 0.08, 3.5
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
	-- The top: octagonal rings from the rim in to the centre, flat under
	-- the road and dropping into the arena bowl.
	local outer = rings[1]
	for n = 1, #BOWL_RINGS + 1 do
		local radius = BOWL_RINGS[n]
		local inner = {}
		if radius then
			for j = 0, ANGLES - 1 do
				local angle = 2 * math.pi * j / ANGLES
				local sector = (angle + math.pi / 8) % (math.pi / 4) - math.pi / 8
				local r = math.min(radius / math.cos(sector), math.max(rows[1][j], 0) - 1)
				inner[j] = mesh:exactVertex(r * math.cos(angle), r * math.sin(angle), CAP_TOP - bowlDrop(radius))
			end
		end
		local centre = if radius then nil else mesh:exactVertex(0, 0, CAP_TOP - ARENA_DROP)
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
	local top = CAP_TOP - bowlDrop(octagonRadius(x, y))
	local depth = if z > top - 0.01 then 0 else math.min(wz, z) - CAP_TOP
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

-- The arena, copied from Server Map and lowered to sit in the bowl: the
-- concrete fight floor, hazard-striped entry ramps down from the road, the
-- spawn ring and the storm beacon.
local CONCRETE = { 0.55, 0.54, 0.5 }
local MARK = { 0.85, 0.65, 0.15 }
local DECK = CAP_TOP
local ARENA_DEPTH = ARENA_DROP - CAP_TOP
local HAZARD_WIDTH = 1.8
local function octagonScale(degrees: number): number
	return 1 / math.cos(math.rad((degrees + 22.5) % 45 - 22.5))
end
local function fbm(x: number, y: number, z: number): number
	local total, amplitude = 0, 0.5
	for _ = 1, 4 do
		total += math.noise(x, y, z) * amplitude
		x, y, z, amplitude = x * 2, y * 2, z * 2, amplitude / 2
	end
	return total
end
-- fBm sampled through another fBm, so the wear twists into blotches and
-- streaks instead of even waves.
local function warpedFbm(x: number, y: number, z: number): number
	return fbm(x + 1.8 * fbm(x + 5.2, y + 1.3, z), y + 1.8 * fbm(x + 1.7, y + 9.2, z), z)
end
-- A solid band following a circle between two angles, used for the kerb,
-- floor stripes and rim wall. With `octagon` it follows the arena octagon
-- instead, with a row on every corner it passes so the corners stay sharp.
local function arc(mesh, inner: number, outer: number, bottom: number, top: number, from: number, to: number, octagon: boolean?)
	local angles = {}
	local steps = math.max(1, math.ceil((to - from) / 4))
	for s = 0, steps do
		table.insert(angles, from + (to - from) * s / steps)
	end
	if octagon then
		for corner = math.floor((from - 22.5) / 45 + 1) * 45 + 22.5, to - 0.01, 45 do
			if math.abs((corner - from) % ((to - from) / steps)) > 0.01 then
				table.insert(angles, corner)
			end
		end
		table.sort(angles)
	end
	steps = #angles - 1
	local rows = {}
	for s = 0, steps do
		local scale = if octagon then octagonScale(angles[s + 1]) else 1
		local angle = math.rad(angles[s + 1])
		local c, n = math.cos(angle) * scale, math.sin(angle) * scale
		rows[s] = {
			mesh:vertex(c * outer, n * outer, bottom),
			mesh:vertex(c * outer, n * outer, top),
			mesh:vertex(c * inner, n * inner, top),
			mesh:vertex(c * inner, n * inner, bottom),
		}
	end
	for s = 0, steps - 1 do
		local a, b = rows[s], rows[s + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
	mesh:face({ rows[0][4], rows[0][3], rows[0][2], rows[0][1] })
	mesh:face(rows[steps])
end

-- Arena concrete: broad warped stains from oil and fights, mottled patches
-- of differing cure, fine aggregate showing through the worn top, and
-- scuffs: short streaks scraped by bots, running one way per patch of floor.
local function scuff(x: number, y: number): number
	local angle = math.noise(x / 12, y / 12, 17) * math.pi * 2
	local u = x * math.cos(angle) + y * math.sin(angle)
	local v = y * math.cos(angle) - x * math.sin(angle)
	local streak = math.noise(u / 1.6, v * 7, 19)
	local patch = fbm(x / 6, y / 6, 23) + 0.02
	if patch <= 0 then return 0 end
	return math.clamp(math.abs(streak) - 0.12, 0, 1) * math.sign(streak) * math.min(1, patch * 8)
end
local function arenaConcrete(x: number, y: number, _z: number)
	local stain = warpedFbm(x / 14, y / 14, 3)
	local mottle = fbm(x / 3, y / 3, 7)
	local grain = math.noise(x * 6, y * 6, 11) * 0.5 + math.noise(x * 19, y * 19, 13) * 0.5
	local k = 1 + mottle * 0.12 + grain * 0.05 - math.max(0, stain) * 0.35
	if grain > 0.42 then
		k += 0.1
	elseif grain < -0.45 then
		k -= 0.08
	end
	local mark = scuff(x, y)
	k += if mark > 0 then mark * 0.4 else mark * 0.5
	return CONCRETE[1] * k, CONCRETE[2] * k, CONCRETE[3] * (k - math.max(0, stain) * 0.04)
end
-- Bridge deck: riveted steel tread plates laid across the span, with dark
-- seams, raised diamond treads worn smooth down the two wheel paths, hazard
-- chevrons painted along both outer plates, and grime and rust bleeding in
-- from the edges. Painted in the bridge's own frame so every bridge wears
-- the same way along its length.
do
	chunkedPart("Floor", nil, CONCRETE, function(mesh)
		arc(mesh, 0, ARENA_FLOOR - HAZARD_WIDTH, -ARENA_DEPTH - 0.1, 0.1 - ARENA_DEPTH, 0, 360, true)
	end, nil, arenaConcrete)
end
-- New players start on a ring round the crusher.
do
	part("Pad", nil, MARK, function(mesh)
		ring(mesh, 0, 0, 0.2 - ARENA_DEPTH, 6.5, 8.5, 0.1, "z", 32)
	end, nil, 0)
end

-- The crusher, the arena's centrepiece: a hydraulic press over a sunken
-- bed, four pillars carrying a crossbeam, and a press head held up over a
-- half-flattened car.
-- A square beam with flat ends running from one point up to another, for
-- legs that lean.
local function leg(mesh, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, width: number)
	local h = width / 2
	local corners = { { -h, -h }, { h, -h }, { h, h }, { -h, h } }
	local base, cap = {}, {}
	for k, c in corners do
		base[k] = mesh:vertex(x0 + c[1], y0 + c[2], z0)
		cap[k] = mesh:vertex(x1 + c[1], y1 + c[2], z1)
	end
	for k = 1, 4 do
		local l = k % 4 + 1
		mesh:face({ base[k], base[l], cap[l], cap[k] })
	end
	mesh:face(cap)
	mesh:face({ base[4], base[3], base[2], base[1] })
end

-- The storm beacon: a mast with a glowing core that lights up when a storm
-- round starts, visible from every yard.
local MAST_TOP = 24
local STORM_GLOW = { 0.35, 0.85, 1 }
do
	local floor = 0.1 - ARENA_DEPTH
	part("Plinth", nil, CONCRETE, function(mesh)
		cylinder(mesh, 0, 0, floor + 0.6, 4.5, 1.2, "z", 8)
		cylinder(mesh, 0, 0, floor + 1.5, 3.4, 0.6, "z", 8)
	end, nil, 0.5)
	part("PlinthStripe", nil, MARK, function(mesh)
		ring(mesh, 0, 0, floor + 1.15, 4.4, 4.55, 0.25, "z", 8)
	end, nil, 0.3)
	-- Four straight legs leaning in towards the top, tied together with braces.
	part("Mast", nil, DARK_STEEL, function(mesh)
		local bottom, top = floor + 1.8, floor + MAST_TOP
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				leg(mesh, sx * 2.2, sy * 2.2, bottom, sx * 0.8, sy * 0.8, top, 0.45)
			end
		end
		local braces = 6
		for i = 1, braces do
			local t = i / braces
			local z = bottom + t * (top - bottom) - 0.25
			local half = 2.2 - t * 1.4
			box(mesh, 0, half, z, half * 2, 0.25, 0.25)
			box(mesh, 0, -half, z, half * 2, 0.25, 0.25)
			box(mesh, half, 0, z, 0.25, half * 2, 0.25)
			box(mesh, -half, 0, z, 0.25, half * 2, 0.25)
		end
	end, nil, 0.6)
	part("CoreMount", nil, STEEL, function(mesh)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 0.3, 1.9, 0.6, "z", 16)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 4.25, 1.9, 0.5, "z", 16)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 6.5, 0.15, 4, "z", 8)
	end, nil, 0.2)
	-- The core sits on top of the mast and is the part that glows during a storm.
	part("Core", nil, STORM_GLOW, function(mesh)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 2.3, 1.4, 3.4, "z", 16)
	end, nil, 0, nil, 1)
	part("CoreCage", nil, DARK_STEEL, function(mesh)
		for k = 0, 5 do
			local angle = math.rad(k * 60)
			box(mesh, math.cos(angle) * 1.65, math.sin(angle) * 1.65, floor + MAST_TOP + 0.6, 0.2, 0.2, 3.4)
		end
	end, nil, 0.3)
end


-- The arena edge stands out from the yards around it: hazard stripes ring the
-- fight floor, and a low concrete wall with yellow caps tops the bowl,
-- broken where each spoke comes in.
local LANE_HALF = 3.6
local RAMP_HALF = LANE_HALF + HAZARD_WIDTH
-- Entry ramps: a concrete deck at each spoke, from the ring road down the
-- bank to the fight floor, one straight slope a touch above the bank so it
-- never dips into the terrain.
local RAMP_FLOOR = 0.1 - ARENA_DEPTH
local RAMP_CREST = DECK + 0.1
local function rampTop(radius: number): number
	return RAMP_FLOOR + (RAMP_CREST - RAMP_FLOOR) * math.clamp((radius - ARENA_FLOOR) / (ROAD_INNER - ARENA_FLOOR), 0, 1)
end
-- A block on spoke `degrees` between `from` and `to` across it and over
-- `radii` along it, its top `lift` above the deck and its bottom at the
-- arena floor or `depth` below its top.
local function rampBlock(mesh, degrees: number, radii: { number }, from: number, to: number, lift: number, depth: number?)
	local angle = math.rad(degrees)
	local c, n = math.cos(angle), math.sin(angle)
	local rows = {}
	for s, radius in radii do
		local top = rampTop(radius) + lift
		local bottom = if depth then top - depth else RAMP_FLOOR - 0.1
		rows[s] = {}
		local miter = radius * math.tan(math.rad(22.5))
		for k, side in { from, to } do
			side = math.clamp(side, -miter, miter)
			local x, y = c * radius - n * side, n * radius + c * side
			rows[s][k] = mesh:vertex(x, y, top)
			rows[s][k + 2] = mesh:vertex(x, y, bottom)
		end
	end
	for s = 1, #radii - 1 do
		local a, b = rows[s], rows[s + 1]
		mesh:face({ b[1], b[2], a[2], a[1] })
		mesh:face({ a[4], b[4], b[3], a[3] })
		mesh:face({ a[3], b[3], b[1], a[1] })
		mesh:face({ b[2], b[4], a[4], a[2] })
	end
	local first, last = rows[1], rows[#radii]
	mesh:face({ first[2], first[4], first[3], first[1] })
	mesh:face({ last[3], last[4], last[2], last[1] })
end
-- Hazard strips inlaid outside both lane edges, as wide as the arena's ring
-- and flush with the deck. They run from the road, ending yellow, across
-- the ring, which is cut at each ramp mouth and runs from strip to strip
-- along each octagon side, mitred at the corners. Blocks are clamped to the
-- octagon miters, so the last ring piece on each side runs into the corner.
local STRIP_BREAKS = { ARENA_FLOOR - HAZARD_WIDTH }
for k = 0, 6 do
	table.insert(STRIP_BREAKS, ARENA_FLOOR + k * (ROAD_INNER - ARENA_FLOOR) / 6)
end
do
	part("Deck", nil, CONCRETE, function(mesh)
		for i = 1, 8 do
			rampBlock(mesh, (i - 1) * 45, { ARENA_FLOOR - HAZARD_WIDTH, ARENA_FLOOR, ROAD_INNER }, -LANE_HALF, LANE_HALF, 0)
		end
	end, nil, 0.25)
	for k, color in { MARK, { 0.08, 0.08, 0.08 } } do
		part(if k == 1 then "RampStripeYellow" else "RampStripeBlack", nil, color, function(mesh)
			for i = 1, 8 do
				for s = k, #STRIP_BREAKS - 1, 2 do
					local radii = { STRIP_BREAKS[s], STRIP_BREAKS[s + 1] }
					rampBlock(mesh, (i - 1) * 45, radii, -RAMP_HALF, -LANE_HALF, 0)
					rampBlock(mesh, (i - 1) * 45, radii, LANE_HALF, RAMP_HALF, 0)
				end
				-- Ring pieces, black-yellow-black from the mouth to the corner.
				local ring = { ARENA_FLOOR - HAZARD_WIDTH, ARENA_FLOOR }
				local cuts = { RAMP_HALF, RAMP_HALF + 3.2, RAMP_HALF + 6.4, 99 }
				for s = 3 - k, 3, 2 do
					rampBlock(mesh, (i - 1) * 45, ring, cuts[s], cuts[s + 1], 0)
					rampBlock(mesh, (i - 1) * 45, ring, -cuts[s + 1], -cuts[s], 0)
				end
			end
		end, nil, 0.2)
	end
end
-- A steel bridge on spoke `degrees`, placed at (x, y) and turned so local +y
-- runs along it, from its low end at `to` (on deck level) to its far end at
-- `from`, which climbs to `highZ`. Every part is built flat and then sheared
-- up along its length, so posts stay upright and the end pieces sit level at
-- their own tier. A yard end lands on an apron under a gate frame; any other
-- end gets bollards like the low end.
finishParts()
