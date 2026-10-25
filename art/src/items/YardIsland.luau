-- Yard Island: a floating yard island built from stacked rock columns, in
-- the style of a hand-sculpted stylised island. Three tiers of chunky
-- rock pillars ring the island, each tier tucked further in and
-- ending lower than the last. The pillars of a tier fit edge to edge like
-- basalt columns, with a crevice down each shared edge, and each is a
-- stack of blocks. The model is one closed outer shell over the columns,
-- with a soil lip draped over the rim, meshed as a solid volume. Top at z = 0.7.
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

-- The island is a solid volume, meshed by adaptive dual contouring. The column layout
-- above gives the wall's reach per angle and height, sampled once into a
-- table; the volume is everything inside that reach and under the top,
-- bent by a slow 3D warp so ledges tilt and curl under each other.
local ANGLES, STEP, FLOOR, LIP = 480, 0.15, -25, 0.35
local RIM_JAGGED, RIM_POKE = 0.166, 0.06
local RIM_BLEND = (CAP_TOP - TIERS[1][3]) * 0.5
local CELL, FINE, WARP, FLAT = 0.6, 0.15, 0.7, 0.03
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
	local rows = {}
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
			local depth = (CAP_TOP - z) / drape(angle)
			if depth < 1 then
				r = math.max(r, rim[j]) + LIP * math.clamp((1 - depth) / 0.2, 0, 1)
			end
			row[j] = r
		end
		if not any then break end
		table.insert(rows, row)
		z -= STEP
	end
	return rows
end

-- Signed distance-ish field: negative inside the island.
local function islandField(rows)
	return function(x: number, y: number, z: number): number
		local flat = math.sqrt(x * x + y * y)
		-- The warp shifts which height and angle a point reads, so block
		-- ledges wander and undercut instead of running dead level.
		local wz = z + WARP * math.noise(x / 7, y / 7, z / 9 + 5)
		local wa = math.atan2(y, x) + 0.02 * math.noise(x / 5, y / 5, z / 5 + 17)
		local u = (CAP_TOP - wz) / STEP + 1
		local v = (wa % (2 * math.pi)) / (2 * math.pi) * ANGLES
		local i = math.clamp(math.floor(u), 1, #rows)
		local i2 = math.min(i + 1, #rows)
		local fu = math.clamp(u - i, 0, 1)
		local j = math.floor(v) % ANGLES
		local fv = v - math.floor(v)
		local l = (j + 1) % ANGLES
		local r0 = rows[i][j] + (rows[i][l] - rows[i][j]) * fv
		local r1 = rows[i2][j] + (rows[i2][l] - rows[i2][j]) * fv
		local reach = if u < 1 or u > #rows + 1 then -1 else r0 + (r1 - r0) * fu
		return math.max(flat - reach, z - CAP_TOP)
	end
end

local shell = model.cached(CACHE_KEY, function()
chunkedPart("Island", nil, GROUND, function(mesh)
	local rows = reachTable()
	local field = islandField(rows)
	local extent = 0
	for _, row in rows do
		for j = 0, ANGLES - 1 do
			extent = math.max(extent, row[j])
		end
	end
	extent += WARP + 2 * CELL
	local bottom = CAP_TOP - (#rows + 1) * STEP - WARP - 2 * CELL
	-- Sample on a coarse grid, then only refine near the surface: the fine
	-- grid is read lazily through `sample`.
	local ratio = math.round(CELL / FINE)
	local nx = (math.ceil(2 * extent / CELL) + 1) * ratio
	local nz = (math.ceil((CAP_TOP + 2 * CELL - bottom) / CELL) + 1) * ratio
	local function at(i, j, k) return -extent + i * FINE, -extent + j * FINE, bottom + k * FINE end
	local function index(i, j, k) return (k * nx + j) * nx + i end
	local values = {}
	local function sample(i, j, k)
		local key = index(i, j, k)
		local v = values[key]
		if v == nil then
			v = field(at(i, j, k))
			values[key] = v
		end
		return v
	end
	local function gradient(x, y, z)
		local h = 0.05
		local gx = field(x + h, y, z) - field(x - h, y, z)
		local gy = field(x, y + h, z) - field(x, y - h, z)
		local gz = field(x, y, z + h) - field(x, y, z - h)
		local len = math.sqrt(gx * gx + gy * gy + gz * gz)
		if len < 1e-9 then return 0, 0, 0 end
		return gx / len, gy / len, gz / len
	end

	-- Hermite data: every edge the surface crosses gives a point and a normal,
	-- shared by the four cells around it.
	local crossings = {}
	local AXES = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
	local function crossing(i, j, k, axis)
		local key = index(i, j, k) * 3 + axis
		local found = crossings[key]
		if found ~= nil then return found end
		local o = AXES[axis]
		local da, db = sample(i, j, k), sample(i + o[1], j + o[2], k + o[3])
		found = false
		if (da < 0) ~= (db < 0) then
			local f = da / (da - db)
			local x, y, z = at(i + o[1] * f, j + o[2] * f, k + o[3] * f)
			local gx, gy, gz = gradient(x, y, z)
			found = { x, y, z, gx, gy, gz }
		end
		crossings[key] = found
		return found
	end

	-- A quadric error function: the summed squared distance to each
	-- crossing's tangent plane, plus the crossings' mass point.
	local function newQef()
		return { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
	end
	local function addPlane(q, c)
		local px, py, pz = c[4], c[5], c[6]
		local d = px * c[1] + py * c[2] + pz * c[3]
		q[1] += px * px; q[2] += px * py; q[3] += px * pz
		q[4] += py * py; q[5] += py * pz; q[6] += pz * pz
		q[7] += px * d; q[8] += py * d; q[9] += pz * d
		q[10] += d * d
		q[11] += c[1]; q[12] += c[2]; q[13] += c[3]; q[14] += 1
	end
	local function addQef(q, other)
		for n = 1, 14 do q[n] += other[n] end
	end
	-- Minimise the quadric, leaning toward the mass point where the planes
	-- leave it free, kept inside the (slightly grown) box. Returns the point
	-- and its mean squared error.
	local function solve(q, lo, hi)
		local count = q[14]
		local mx, my, mz = q[11] / count, q[12] / count, q[13] / count
		local lambda = 0.02 * count
		local a, b, c, d, e, f = q[1] + lambda, q[2], q[3], q[4] + lambda, q[5], q[6] + lambda
		local rx, ry, rz = q[7] + lambda * mx, q[8] + lambda * my, q[9] + lambda * mz
		local det = a * (d * f - e * e) - b * (b * f - e * c) + c * (b * e - d * c)
		local x, y, z = mx, my, mz
		if math.abs(det) > 1e-12 then
			x = (rx * (d * f - e * e) - b * (ry * f - e * rz) + c * (ry * e - d * rz)) / det
			y = (a * (ry * f - e * rz) - rx * (b * f - e * c) + c * (b * rz - ry * c)) / det
			z = (a * (d * rz - ry * e) - b * (b * rz - ry * c) + rx * (b * e - d * c)) / det
		end
		x = math.clamp(x, lo[1], hi[1])
		y = math.clamp(y, lo[2], hi[2])
		z = math.clamp(z, lo[3], hi[3])
		local err = x * (q[1] * x + q[2] * y + q[3] * z) + y * (q[2] * x + q[4] * y + q[5] * z)
			+ z * (q[3] * x + q[5] * y + q[6] * z) - 2 * (x * q[7] + y * q[8] + z * q[9]) + q[10]
		return x, y, z, math.max(err, 0) / count
	end
	local function box(i, j, k, size)
		local x, y, z = at(i - 0.5, j - 0.5, k - 0.5)
		local span = (size + 1) * FINE
		return { x, y, z }, { x + span, y + span, z + span }
	end

	-- Fine cells the surface crosses, found only inside coarse cells near it.
	local CORNERS = { { 0, 0, 0 }, { 1, 0, 0 }, { 0, 1, 0 }, { 1, 1, 0 }, { 0, 0, 1 }, { 1, 0, 1 }, { 0, 1, 1 }, { 1, 1, 1 } }
	local EDGES = {
		{ 0, 0, 0, 1 }, { 0, 1, 0, 1 }, { 0, 0, 1, 1 }, { 0, 1, 1, 1 },
		{ 0, 0, 0, 2 }, { 1, 0, 0, 2 }, { 0, 0, 1, 2 }, { 1, 0, 1, 2 },
		{ 0, 0, 0, 3 }, { 1, 0, 0, 3 }, { 0, 1, 0, 3 }, { 1, 1, 0, 3 },
	}
	local cells = {}
	local surface = {}
	local band = 1.5 * CELL
	for ck = 0, nz - 1 - ratio, ratio do
		for cj = 0, nx - 1 - ratio, ratio do
			for ci = 0, nx - 1 - ratio, ratio do
				local near = false
				for _, o in CORNERS do
					if math.abs(sample(ci + o[1] * ratio, cj + o[2] * ratio, ck + o[3] * ratio)) < band then
						near = true
						break
					end
				end
				if not near then continue end
				for k = ck, ck + ratio - 1 do
					for j = cj, cj + ratio - 1 do
						for i = ci, ci + ratio - 1 do
							local q
							for _, e in EDGES do
								local c = crossing(i + e[1], j + e[2], k + e[3], e[4])
								if not c then continue end
								q = q or newQef()
								addPlane(q, c)
							end
							if not q then continue end
							local lo, hi = box(i, j, k, 1)
							local x, y, z = solve(q, lo, hi)
							local node = { qef = q, x = x, y = y, z = z, ok = true }
							cells[index(i, j, k)] = node
							table.insert(surface, { i, j, k, node })
						end
					end
				end
			end
		end
	end

	-- Merge blocks of 2, 4 and 8 cells where one plane still fits them all
	-- within FLAT; chips, cracks and corners don't fit and stay fine.
	local level = surface
	for _, size in { 2, 4, 8 } do
		local blocks, nextLevel = {}, {}
		for _, entry in level do
			local bi, bj, bk = entry[1] // size * size, entry[2] // size * size, entry[3] // size * size
			local key = index(bi, bj, bk)
			local block = blocks[key]
			if not block then
				block = { bi, bj, bk, { qef = newQef(), ok = true, children = {} } }
				blocks[key] = block
				table.insert(nextLevel, block)
			end
			local parent, child = block[4], entry[4]
			table.insert(parent.children, child)
			if not child.ok then parent.ok = false end
			addQef(parent.qef, child.qef)
		end
		for _, block in nextLevel do
			local parent = block[4]
			if parent.ok then
				local lo, hi = box(block[1], block[2], block[3], size)
				local x, y, z, err = solve(parent.qef, lo, hi)
				parent.x, parent.y, parent.z = x, y, z
				parent.ok = err < FLAT * FLAT
			end
			if parent.ok then
				for _, child in parent.children do child.parent = parent end
			end
			parent.children = nil
		end
		level = nextLevel
	end
	local function vertexOf(node)
		if not node then return nil end
		while node.parent do node = node.parent end
		if not node.vertex then node.vertex = mesh:vertex(node.x, node.y, node.z) end
		return node
	end

	-- One quad per fine edge the surface crosses, joining the cells around
	-- it; where merged cells meet, the quad shrinks to a triangle.
	local function quad(a, b, c, d, flip)
		a, b, c, d = vertexOf(a), vertexOf(b), vertexOf(c), vertexOf(d)
		if not (a and b and c and d) then return end
		local ring = if flip then { d, c, b, a } else { a, b, c, d }
		local kept = {}
		for n = 1, 4 do
			if ring[n] ~= ring[n % 4 + 1] then table.insert(kept, ring[n].vertex) end
		end
		if #kept == 4 then
			mesh:face(kept)
		elseif #kept == 3 and kept[1] ~= kept[3] then
			mesh:face(kept)
		end
	end
	for _, entry in surface do
		local i, j, k = entry[1], entry[2], entry[3]
		if i < 1 or j < 1 or k < 1 then continue end
		local here = sample(i, j, k) < 0
		if crossing(i, j, k, 1) then
			quad(cells[index(i, j - 1, k - 1)], cells[index(i, j, k - 1)], cells[index(i, j, k)], cells[index(i, j - 1, k)], not here)
		end
		if crossing(i, j, k, 2) then
			quad(cells[index(i - 1, j, k - 1)], cells[index(i - 1, j, k)], cells[index(i, j, k)], cells[index(i, j, k - 1)], not here)
		end
		if crossing(i, j, k, 3) then
			quad(cells[index(i - 1, j - 1, k)], cells[index(i, j - 1, k)], cells[index(i, j, k)], cells[index(i - 1, j, k)], not here)
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
