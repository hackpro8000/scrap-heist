-- Island Study: steps 1 to 3 of the island generator.
-- The island is a flat top over a wobbly outline with one shallow bay; the
-- body under it (a cosine wall and a small flat underside) is only a guide the
-- stones are fitted round, kept for the bake but not exported. Over the wall sit fitted rock
-- cells: each one a displaced blob cut by the bisector planes to its
-- neighbours, so the stones meet exactly, then sliced with a few facet
-- planes so they read as cut stone rather than balls. A thick layer of soil
-- is spread over the top and the rim stones' tops.
local SEED = 1
local RADIUS = 30
-- How deep the underside hangs, as a share of the radius.
local DEPTH_SHARE = 1.05
-- The top's height, matching the other islands so sea level stays at 0.
local CAP_TOP = 0.7
-- How far the outline moves in and out, as a share of the radius.
local WOBBLE = 0.08
-- The bay: how far it cuts in and how wide (radians) it is.
local BAY_DEPTH, BAY_WIDTH = 0.09, 0.5
-- The wall's reach at the rim, and the share it narrows to at the underside.
-- Nearly zero, so the island closes on a point rather than a flat cap.
local WALL_REACH, UNDERSIDE_SHARE = 0.86, 0.03
-- How sharply the wall draws to that point: 1 is a straight cone, higher
-- numbers keep the top broad and pull the taper into the lower half.
local TAPER_POWER = 1.35
-- The rock cells: rows down the wall, roughly how wide a cell is, and how
-- many facet slices each stone gets.
local ROCK_ROWS = 4
local ROCK_WIDTH = 7
local ROCK_FACETS = 7
-- Breaking up the rows: the wall is split into sectors round the island, and
-- each sector gets ROCK_ROWS plus up to ROW_SPREAD more rows, so the rows
-- don't line up all the way round.
local ROW_SECTORS, ROW_SPREAD = 5, 1
-- How far a seed may wander in its slot, either way, as a share of the
-- row's height and the slot's width. Small, so no slot is left uncovered.
local HEIGHT_JITTER, ANGLE_JITTER = 0.3, 0.25
-- The odd big stone: the share of top-row slots merged with the nearest
-- second-row slot into one stone over both rows, and its power weight in
-- spacing-squared units, so it claims both slots from its neighbours.
local BIG_STONE_SHARE, BIG_STONE_WEIGHT = 1 / 8, 0.5
-- How many times a cell's blob is split. One is enough: the fitting and the
-- slices do the shaping, and the cells are small on screen.
local ROCK_SUBDIVISIONS = 1
-- The chips: an edge counts as sharp when its two facets' normals agree
-- less than this (0 is a right angle), and the edge and corner cuts go
-- this deep, as a share of the stone's radius.
local CHIP_SHARPNESS = 0.3
local CHIP_EDGE, CHIP_CORNER = 0.05, 0.09
-- The worn edges: every edge two cuts (facets and chips) make is rounded off
-- with a bevel ROUND_RADIUS studs in radius (at most ROUND_SHARE of the
-- stone's radius, so small stones keep their facets) in ROUND_SEGMENTS
-- flat steps, each gentle enough to shade smooth. Edges gentler than
-- ROUND_MIN_FOLD (dot of the two normals above it) are left alone.
local ROUND_RADIUS, ROUND_SHARE = 0.3, 0.08
local ROUND_SEGMENTS = 3
local ROUND_MIN_FOLD = math.cos(math.rad(10))
-- The overhanging lip: how far (studs) the top row stands out past where it
-- sat, plus up to LIP_SPREAD more per stone, and how far it is raised so its
-- tops reach the flat-top cut just under the cap.
local LIP_OUT, LIP_SPREAD = 1, 1
local LIP_RISE = 1.2
-- Seam soil: a bead of soil settled into each seam between stones that reaches
-- the top, running from under the soil's lip SEAM_SOIL_MIN to SEAM_SOIL_MAX
-- studs further down. SEAM_SOIL_WIDTH studs across and SEAM_SOIL_PROUD out
-- past the crease at the lip, tapering to nothing at its end, in
-- SEAM_SOIL_STEPS rings of SEAM_SOIL_SIDES segments.
local SEAM_SOIL_MIN, SEAM_SOIL_MAX = 6, 9
local SEAM_SOIL_WIDTH = 1.5
local SEAM_SOIL_PROUD = 0.5
local SEAM_SOIL_STEPS, SEAM_SOIL_SIDES = 6, 4
local ANGLES, STEPS = 128, 28
local TAU = 2 * math.pi
-- Texture detail in pixels per stud. The stones are split into parts by angle
-- so no part's texture needs more than ROCK_TEXTURE at this density.
local TEXEL_DENSITY = 20
local ROCK_TEXTURE = 1024
useTexelDensity(TEXEL_DENSITY)

local function hash(k: number): number
	local s = math.sin(k * 12.9898 + 4.1414) * 43758.5453
	return s - math.floor(s)
end

local function dot(a: { number }, b: { number }): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function cross(a: { number }, b: { number }): { number }
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

local function normalize(p: { number }): { number }
	local length = math.sqrt(dot(p, p))
	return { p[1] / length, p[2] / length, p[3] / length }
end

local phase = {}
for i = 1, 4 do
	phase[i] = hash(SEED * 7 + i) * TAU
end
local bayAngle = hash(SEED * 13) * TAU

-- The outline as a radius scale per angle: a sum of waves, so no two seeds
-- share an island, and one gaussian dip for the bay.
local function outlineScale(angle: number): number
	local wobble = 0.045 * math.sin(2 * angle + phase[1])
		+ 0.025 * math.sin(3 * angle + phase[2])
		+ 0.012 * math.sin(7 * angle + phase[3])
		+ 0.008 * math.sin(11 * angle + phase[4])
	local d = (angle - bayAngle + math.pi) % TAU - math.pi
	local bay = BAY_DEPTH * math.exp(-((d / BAY_WIDTH) ^ 2))
	return 1 + WOBBLE * wobble / 0.09 - bay
end

local DEPTH = RADIUS * DEPTH_SHARE
local RIM_Z = CAP_TOP - DEPTH

-- The wall's reach at `t`, 0 at the rim and 1 at the underside: a power
-- curve, so the island stays broad near the top and draws to a point below.
local function shareAt(t: number): number
	return UNDERSIDE_SHARE + (1 - UNDERSIDE_SHARE) * (1 - t) ^ TAPER_POWER
end

local function wallPoint(angle: number, t: number): { number }
	local r = RADIUS * WALL_REACH * shareAt(t) * outlineScale(angle)
	return { r * math.cos(angle), r * math.sin(angle), CAP_TOP - DEPTH * t }
end

local function wallNormal(angle: number, t: number): { number }
	local e = 1e-3
	local a1, a0 = wallPoint(angle + e, t), wallPoint(angle - e, t)
	local d1, d0 = wallPoint(angle, t + e), wallPoint(angle, t - e)
	local n = normalize(cross(
		{ a1[1] - a0[1], a1[2] - a0[2], a1[3] - a0[3] },
		{ d1[1] - d0[1], d1[2] - d0[2], d1[3] - d0[3] }
	))
	if dot(n, { math.cos(angle), math.sin(angle), 0 }) < 0 then
		n = { -n[1], -n[2], -n[3] }
	end
	return n
end

-- A unit icosphere, split `times`, returned as corners plus triangles.
local function icosphere(times: number)
	local golden = (1 + math.sqrt(5)) / 2
	local vertices = {
		{ -1, golden, 0 }, { 1, golden, 0 }, { -1, -golden, 0 }, { 1, -golden, 0 },
		{ 0, -1, golden }, { 0, 1, golden }, { 0, -1, -golden }, { 0, 1, -golden },
		{ golden, 0, -1 }, { golden, 0, 1 }, { -golden, 0, -1 }, { -golden, 0, 1 },
	}
	for i, p in vertices do
		vertices[i] = normalize(p)
	end
	local faces = {
		{ 1, 12, 6 }, { 1, 6, 2 }, { 1, 2, 8 }, { 1, 8, 11 }, { 1, 11, 12 },
		{ 2, 6, 10 }, { 6, 12, 5 }, { 12, 11, 3 }, { 11, 8, 7 }, { 8, 2, 9 },
		{ 4, 10, 5 }, { 4, 5, 3 }, { 4, 3, 7 }, { 4, 7, 9 }, { 4, 9, 10 },
		{ 5, 10, 6 }, { 3, 5, 12 }, { 7, 3, 11 }, { 9, 7, 8 }, { 10, 9, 2 },
	}
	for _ = 1, times do
		local cache, out = {}, {}
		local function midpoint(a: number, b: number): number
			local key = if a < b then a .. ":" .. b else b .. ":" .. a
			if cache[key] then
				return cache[key]
			end
			local va, vb = vertices[a], vertices[b]
			table.insert(vertices, normalize({ va[1] + vb[1], va[2] + vb[2], va[3] + vb[3] }))
			cache[key] = #vertices
			return #vertices
		end
		for _, f in faces do
			local ab, bc, ca = midpoint(f[1], f[2]), midpoint(f[2], f[3]), midpoint(f[3], f[1])
			table.insert(out, { f[1], ab, ca })
			table.insert(out, { f[2], bc, ab })
			table.insert(out, { f[3], ca, bc })
			table.insert(out, { ab, bc, ca })
		end
		faces = out
	end
	return vertices, faces
end

local unitVertices, unitFaces = icosphere(ROCK_SUBDIVISIONS)

local function wave(p: { number }, frequency: number, salt: number): number
	return math.sin(frequency * p[1] + salt)
		* math.sin(frequency * p[2] + salt * 1.7)
		* math.sin(frequency * p[3] + salt * 2.3)
end

local function planeDistance(plane: { number }, p: { number }): number
	return plane[1] * p[1] + plane[2] * p[2] + plane[3] * p[3] - plane[4]
end

-- Cuts triangles exactly at the plane and caps the opening on the plane. The
-- cap is what makes each cut a solid face rather than a hole.
local function clip(tris, plane)
	local out, cut = {}, {}
	for _, tri in tris do
		local distance = {
			planeDistance(plane, tri[1]),
			planeDistance(plane, tri[2]),
			planeDistance(plane, tri[3]),
		}
		local inside = { distance[1] <= 0, distance[2] <= 0, distance[3] <= 0 }
		if inside[1] and inside[2] and inside[3] then
			table.insert(out, tri)
		elseif not (inside[1] or inside[2] or inside[3]) then
			-- Fully outside: dropped.
		else
			local polygon = {}
			for i = 1, 3 do
				local j = i % 3 + 1
				if inside[i] then
					table.insert(polygon, tri[i])
				end
				if inside[i] ~= inside[j] and math.abs(distance[i]) > 1e-6 then
					local t = distance[i] / (distance[i] - distance[j])
					local p, q = tri[i], tri[j]
					local point = {
						p[1] + (q[1] - p[1]) * t,
						p[2] + (q[2] - p[2]) * t,
						p[3] + (q[3] - p[3]) * t,
					}
					table.insert(polygon, point)
					table.insert(cut, point)
				end
			end
			for k = 2, #polygon - 1 do
				table.insert(out, { polygon[1], polygon[k], polygon[k + 1] })
			end
		end
	end
	if #cut >= 3 then
		local unique, seen = {}, {}
		for _, p in cut do
			local key = string.format("%.4f:%.4f:%.4f", p[1], p[2], p[3])
			if not seen[key] then
				seen[key] = true
				table.insert(unique, p)
			end
		end
		if #unique >= 3 then
			local centre = { 0, 0, 0 }
			for _, p in unique do
				centre = { centre[1] + p[1], centre[2] + p[2], centre[3] + p[3] }
			end
			centre = { centre[1] / #unique, centre[2] / #unique, centre[3] / #unique }
			local normal = { plane[1], plane[2], plane[3] }
			local u = cross(normal, { 0, 0, 1 })
			if dot(u, u) < 1e-8 then
				u = cross(normal, { 1, 0, 0 })
			end
			u = normalize(u)
			local v = cross(normal, u)
			table.sort(unique, function(a, b)
				local da = { a[1] - centre[1], a[2] - centre[2], a[3] - centre[3] }
				local db = { b[1] - centre[1], b[2] - centre[2], b[3] - centre[3] }
				return math.atan2(dot(da, v), dot(da, u)) < math.atan2(dot(db, v), dot(db, u))
			end)
			for i = 1, #unique do
				local j = i % #unique + 1
				table.insert(out, { centre, unique[i], unique[j] })
			end
		end
	end
	return out
end

-- How far apart stones sit round the wall, from the widest row.
local spacing = TAU * RADIUS * WALL_REACH * shareAt(0.5) / math.max(6, math.round(TAU * RADIUS * WALL_REACH * shareAt(0.5) / ROCK_WIDTH))

-- The cells: seeds round the wall in rows. Every slot keeps a stone; size
-- variety comes from a power weight instead of dropped slots, because a
-- dropped slot leaves a hole its neighbours may not reach across. The rows
-- are broken up: each sector has its own row count, each seed wanders in its
-- slot, and now and then two slots on the upper rows share one big stone.
local function makeSeed(angle: number, t: number, row: number, key: number)
	local p = wallPoint(angle, t)
	local n = wallNormal(angle, t)
	-- Some seeds sit inside the wall, some just outside, so the cells cut
	-- the surface at angles rather than all from one shell.
	local lift = -1.2 + 2.6 * hash(SEED * 71 + key)
	-- The top row's lip: its seeds move out and up before the fit, so the
	-- stones stand past the cap's edge and the seams still come out exact.
	local lip = if row == 0 then LIP_OUT + LIP_SPREAD * hash(SEED * 61 + key) else 0
	local rise = if row == 0 then LIP_RISE else 0
	return {
		p[1] + n[1] * lift + math.cos(angle) * lip,
		p[2] + n[2] * lift + math.sin(angle) * lip,
		p[3] + n[3] * lift + rise,
		size = 0.85 + 0.3 * hash(SEED * 53 + key),
		t = t,
		row = row,
		angle = angle,
		-- A heavy seed claims more of the wall than a light one. The
		-- weight is in squared-distance units, so it scales with spacing.
		weight = (hash(SEED * 57 + key) - 0.5) * spacing * spacing * 0.55,
	}
end

local seeds = {}
local key = 0
for sector = 0, ROW_SECTORS - 1 do
	local from, to = TAU * sector / ROW_SECTORS, TAU * (sector + 1) / ROW_SECTORS
	local rows = ROCK_ROWS + math.floor(hash(SEED * 83 + sector) * (ROW_SPREAD + 1))
	local band = (0.86 - 0.1) / rows
	local sectorSeeds = {}
	for row = 0, rows - 1 do
		local t = 0.1 + band * (row + 0.5)
		local circumference = TAU * RADIUS * WALL_REACH * shareAt(t)
		local count = math.max(6, math.round(circumference / ROCK_WIDTH))
		local offset = (row % 2) * 0.5
		for col = 0, count - 1 do
			-- Slots are spaced over the whole ring, and each sector keeps the
			-- ones that start inside it, so every slot belongs to one sector.
			local slotAngle = (TAU * (col + offset) / count) % TAU
			if slotAngle >= from and slotAngle < to then
				key += 1
				local angle = slotAngle + (2 * hash(SEED * 87 + key) - 1) * ANGLE_JITTER * TAU / count
				-- The top row keeps its height so the rim stays flush with the cap.
				local drift = if row == 0 then 0 else (2 * hash(SEED * 89 + key) - 1) * HEIGHT_JITTER * band
				table.insert(sectorSeeds, makeSeed(angle, t + drift, row, key))
			end
		end
	end
	-- The big stones: a top-row seed and its nearest second-row seed become
	-- one heavy seed between them, so the pair's two slots are one stone.
	local merged = {}
	for a, top in sectorSeeds do
		if top.row == 0 and hash(SEED * 91 + sector * 31 + a) < BIG_STONE_SHARE then
			local nearest, gap = nil, math.huge
			for b, below in sectorSeeds do
				if below.row == 1 and not merged[b] then
					local d = math.abs((below.angle - top.angle + math.pi) % TAU - math.pi)
					if d < gap then
						nearest, gap = b, d
					end
				end
			end
			if nearest then
				local below = sectorSeeds[nearest]
				merged[nearest] = true
				sectorSeeds[a] = {
					(top[1] + below[1]) / 2,
					(top[2] + below[2]) / 2,
					(top[3] + below[3]) / 2,
					size = math.max(top.size, below.size),
					t = (top.t + below.t) / 2,
					row = 0,
					angle = top.angle,
					weight = BIG_STONE_WEIGHT * spacing * spacing,
				}
			end
		end
	end
	for b, seed in sectorSeeds do
		if not merged[b] then
			table.insert(seeds, seed)
		end
	end
end

local REACH = spacing * 3.2

-- Each stone's blob has to reach past the furthest bisector it can be cut
-- by, or the cell never fills its share and a hole appears. So the radius is
-- worked out per cell from its own neighbours, not from one global constant.
local cellRadius = {}
for i, seed in seeds do
	local farthest = spacing
	for j, other in seeds do
		if j ~= i then
			local dx, dy, dz = other[1] - seed[1], other[2] - seed[2], other[3] - seed[3]
			local distance = dx * dx + dy * dy + dz * dz
			if distance < REACH * REACH and distance > farthest * farthest then
				farthest = math.sqrt(distance)
			end
		end
	end
	cellRadius[i] = farthest * 0.62 * (0.75 + 0.25 * shareAt(seed.t))
end

-- A stone beside one that stands further out must still reach their shared
-- plane all the way out to the neighbour's face, or the seam opens into a
-- notch. So each blob also grows to cover, on every plane that cuts it, the
-- point level with the neighbour's outer face. The blob's surface is about
-- radius * size^2, give or take the wave, so the reach is divided by that.
-- A grown stone is capped at the furthest such face (seamLimit), so it rises
-- to meet its neighbour but never past it.
local SEAM_WAVE, SEAM_CORE = 0.9, 0.7
local seamRadius, seamLimit = {}, {}
for i, seed in seeds do
	local blob = cellRadius[i] * seed.size * seed.size
	local own = wallNormal(seed.angle, seed.t)
	local needed = cellRadius[i]
	for j, other in seeds do
		if j ~= i then
			local dx, dy, dz = other[1] - seed[1], other[2] - seed[2], other[3] - seed[3]
			local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
			if distance < REACH and distance > 1e-6 then
				local n = { dx / distance, dy / distance, dz / distance }
				local seedSq = seed[1] ^ 2 + seed[2] ^ 2 + seed[3] ^ 2
				local otherSq = other[1] ^ 2 + other[2] ^ 2 + other[3] ^ 2
				local offset = (otherSq - seedSq + seed.weight - other.weight) / (2 * distance)
				local out = wallNormal(other.angle, other.t)
				local extent = cellRadius[j] * other.size * other.size
				local face = { other[1] + out[1] * extent, other[2] + out[2] * extent, other[3] + out[3] * extent }
				-- Only a plane that cuts this blob's facet core makes a seam
				-- with it, and only a neighbour standing further out leaves one
				-- open.
				local seam = offset - dot(n, seed) < blob * SEAM_CORE
				if seam and dot(own, face) > dot(own, seed) + blob then
					local past = dot(n, face) - offset
					local onPlane = { face[1] - n[1] * past - seed[1], face[2] - n[2] * past - seed[2], face[3] - n[3] * past - seed[3] }
					local reach = math.sqrt(dot(onPlane, onPlane)) / (seed.size * seed.size * SEAM_WAVE)
					needed = math.max(needed, reach)
					seamLimit[i] = math.max(seamLimit[i] or -math.huge, dot(own, face))
				end
			end
		end
	end
	seamRadius[i] = needed
end
cellRadius = seamRadius

-- The body under the top: the wall and underside the stones were fitted
-- round. It is never exported, only shaded against.
local function buildWall(mesh)
	local rings = {}
	for i = 0, STEPS do
		local t = i / STEPS
		local ring = {}
		for j = 0, ANGLES - 1 do
			local angle = TAU * j / ANGLES
			local p = wallPoint(angle, t)
			ring[j] = mesh:vertex(p[1], p[2], p[3])
		end
		rings[i] = ring
	end
	for i = 0, STEPS - 1 do
		for j = 0, ANGLES - 1 do
			local l = (j + 1) % ANGLES
			local upper, lower = rings[i], rings[i + 1]
			mesh:face({ upper[j], lower[j], lower[l] })
			mesh:face({ upper[j], lower[l], upper[l] })
		end
	end
	local bottom = mesh:vertex(0, 0, RIM_Z)
	for j = 0, ANGLES - 1 do
		mesh:face({ bottom, rings[STEPS][(j + 1) % ANGLES], rings[STEPS][j] })
	end
	mesh:weld(1e-4)
end

-- A triangle lies on a seam plane when all its corners do.
local function onPlane(tri, plane): boolean
	for k = 1, 3 do
		if math.abs(planeDistance(plane, tri[k])) > 1e-5 then
			return false
		end
	end
	return true
end

local function polygonArea(polygon): number
	local total = { 0, 0, 0 }
	for k = 2, #polygon - 1 do
		local a, b, c = polygon[1], polygon[k], polygon[k + 1]
		local n = cross({ b[1] - a[1], b[2] - a[2], b[3] - a[3] }, { c[1] - a[1], c[2] - a[2], c[3] - a[3] })
		total = { total[1] + n[1], total[2] + n[2], total[3] + n[3] }
	end
	return math.sqrt(dot(total, total)) / 2
end

-- Splits a convex polygon by a plane into the part behind it and the part in
-- front, both keeping the polygon's winding.
local function split(polygon, plane)
	local behind, front = {}, {}
	for k, p in polygon do
		local q = polygon[k % #polygon + 1]
		local dp, dq = planeDistance(plane, p), planeDistance(plane, q)
		if dp <= 0 then
			table.insert(behind, p)
		end
		if dp >= 0 then
			table.insert(front, p)
		end
		if (dp < 0 and dq > 0) or (dp > 0 and dq < 0) then
			local t = dp / (dp - dq)
			local point = { p[1] + (q[1] - p[1]) * t, p[2] + (q[2] - p[2]) * t, p[3] + (q[3] - p[3]) * t }
			table.insert(behind, point)
			table.insert(front, point)
		end
	end
	return behind, front
end

-- A neighbour's faces on one seam plane as convex covers: one outline when
-- they make a convex polygon (their hull holds no more than their own area),
-- else the triangles themselves, so a cover never reaches past the face.
local function seamCover(tris, plane)
	if #tris == 0 then
		return {}
	end
	local normal = { plane[1], plane[2], plane[3] }
	local u = cross(normal, { 0, 0, 1 })
	if dot(u, u) < 1e-8 then
		u = cross(normal, { 1, 0, 0 })
	end
	u = normalize(u)
	local v = cross(normal, u)
	local points, area = {}, 0
	for _, tri in tris do
		area += polygonArea(tri)
		for _, p in tri do
			table.insert(points, { p = p, x = dot(p, u), y = dot(p, v) })
		end
	end
	table.sort(points, function(a, b)
		return a.x < b.x or (a.x == b.x and a.y < b.y)
	end)
	local function turn(o, a, b): number
		return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
	end
	-- Andrew's monotone chain: lower then upper hull.
	local hull = {}
	for _, pass in { 1, -1 } do
		local start = #hull
		local from, to = if pass == 1 then 1 else #points, if pass == 1 then #points else 1
		for k = from, to, pass do
			local point = points[k]
			while #hull >= start + 2 and turn(hull[#hull - 1], hull[#hull], point) <= 0 do
				table.remove(hull)
			end
			table.insert(hull, point)
		end
		table.remove(hull)
	end
	local outline = {}
	for _, h in hull do
		table.insert(outline, h.p)
	end
	if #outline >= 3 and polygonArea(outline) <= area + 1e-4 * math.max(area, 1) then
		return { outline }
	end
	return tris
end

-- The parts of a seam triangle its neighbour's covers on the same plane leave
-- uncovered, as convex polygons. Slivers thinner
-- than a hair are dropped as rounding noise.
local SLIVER = 1e-6
local function uncovered(tri, cover, plane)
	local normal = { plane[1], plane[2], plane[3] }
	local pieces = { tri }
	for _, c in cover do
		local remaining = {}
		for _, piece in pieces do
			-- A piece clear of this cover triangle's box keeps whole.
			local clear = false
			for axis = 1, 3 do
				local low, high = math.huge, -math.huge
				for _, p in c do
					low, high = math.min(low, p[axis]), math.max(high, p[axis])
				end
				local pieceLow, pieceHigh = math.huge, -math.huge
				for _, p in piece do
					pieceLow, pieceHigh = math.min(pieceLow, p[axis]), math.max(pieceHigh, p[axis])
				end
				if pieceLow > high or pieceHigh < low then
					clear = true
					break
				end
			end
			if clear then
				table.insert(remaining, piece)
				continue
			end
			local rest = piece
			local centre = { 0, 0, 0 }
			for _, p in c do
				centre = { centre[1] + p[1] / #c, centre[2] + p[2] / #c, centre[3] + p[3] / #c }
			end
			for e = 1, #c do
				local p, q = c[e], c[e % #c + 1]
				local edge = cross({ q[1] - p[1], q[2] - p[2], q[3] - p[3] }, normal)
				local length = math.sqrt(dot(edge, edge))
				if length > 1e-9 then
					edge = { edge[1] / length, edge[2] / length, edge[3] / length }
					if dot(edge, { centre[1] - p[1], centre[2] - p[2], centre[3] - p[3] }) > 0 then
						edge = { -edge[1], -edge[2], -edge[3] }
					end
					local inside, outside = split(rest, { edge[1], edge[2], edge[3], dot(edge, p) })
					if #outside >= 3 and polygonArea(outside) > SLIVER then
						table.insert(remaining, outside)
					end
					rest = inside
					if #rest < 3 then
						break
					end
				end
			end
		end
		pieces = remaining
	end
	return pieces
end

-- Whether a polygon sits wholly inside the body, a hair in from its wall so
-- the body's flat-sided rings still cover it. Corners, edge midpoints and the
-- centre are tested, so a long face can't bow out between them.
local BODY_MARGIN = 0.15
local function insideBody(polygon): boolean
	local function inside(p): boolean
		if p[3] > CAP_TOP - BODY_MARGIN or p[3] < RIM_Z + BODY_MARGIN then
			return false
		end
		local t = (CAP_TOP - p[3]) / DEPTH
		local angle = math.atan2(p[2], p[1])
		local reach = RADIUS * WALL_REACH * shareAt(t) * outlineScale(angle)
		return math.sqrt(p[1] * p[1] + p[2] * p[2]) < reach - BODY_MARGIN
	end
	local centre = { 0, 0, 0 }
	for k, p in polygon do
		local q = polygon[k % #polygon + 1]
		if not inside(p) or not inside({ (p[1] + q[1]) / 2, (p[2] + q[2]) / 2, (p[3] + q[3]) / 2 }) then
			return false
		end
		centre = { centre[1] + p[1], centre[2] + p[2], centre[3] + p[3] }
	end
	return inside({ centre[1] / #polygon, centre[2] / #polygon, centre[3] / #polygon })
end

-- The stones are cut 0.2 under the top, so a thin slit runs round the rim
-- between the top's edge and the stones. Through it, at a grazing angle, the
-- stones' tops under the rim and the far side's inner faces just below them
-- show, so faces reaching this close under the slit stay exported. The
-- stones reach at least 12 studs in under the rim, so a ray through the slit
-- drops under a stud before it crosses the island.
local SLIT_VIEW = 1.5
local function seenThroughRim(polygon): boolean
	for _, p in polygon do
		if p[3] > CAP_TOP - 0.2 - SLIT_VIEW then
			return true
		end
	end
	return false
end

-- The stone faces nobody sees, kept only so the bake still shades with them.
local hiddenRocks = Mesh.new()

local function emitPolygon(target, polygon)
	for k = 2, #polygon - 1 do
		local a, b, c = polygon[1], polygon[k], polygon[k + 1]
		target:face({
			target:vertex(a[1], a[2], a[3]),
			target:vertex(b[1], b[2], b[3]),
			target:vertex(c[1], c[2], c[3]),
		})
	end
end

-- Builds every stone and returns each one's visible faces as polygons, with
-- their area. The faces nobody sees go into hiddenRocks.
local function buildRocks()
	local stones = {}
	for i, seed in seeds do
		-- Stones shrink with the wall, so the bottom rows are chips rather
		-- than full-size boulders crowded round a point.
		local radius = cellRadius[i] * seed.size
		local points = {}
		for v, p in unitVertices do
			local r = (1 + 0.16 * wave(p, 2.3, SEED + i) + 0.05 * wave(p, 4.9, SEED + i + 3.1)) * seed.size
			points[v] = {
				seed[1] + p[1] * r * radius,
				seed[2] + p[2] * r * radius,
				seed[3] + p[3] * r * radius,
			}
		end
		local tris = {}
		for _, f in unitFaces do
			table.insert(tris, { points[f[1]], points[f[2]], points[f[3]] })
		end
		-- The flat spots, cut while the stone is still free-standing.
		local facets, cuts = {}, {}
		for k = 1, ROCK_FACETS do
			local angle = hash(SEED * 31 + i * 13 + k * 7.1) * TAU
			local z = 2 * hash(SEED * 17 + i * 13 + k * 3.3) - 1
			local ring = math.sqrt(1 - z * z)
			local n = { ring * math.cos(angle), ring * math.sin(angle), z }
			local reach = 0.68 + 0.27 * hash(SEED * 5 + i * 13 + k * 11.7)
			local facet = { n[1], n[2], n[3], dot(n, seed) + reach * radius }
			table.insert(facets, facet)
			table.insert(cuts, facet)
			tris = clip(tris, facet)
		end
		-- The chips: a small cut along every sharp edge two facets make, and
		-- on every corner three of them make. Only facet edges are touched, so
		-- the seams cut later stay exact. Each cut is bounded by its facets,
		-- so it can only take a sliver off that edge or corner.
		for a = 1, #facets do
			for b = a + 1, #facets do
				local p, q = facets[a], facets[b]
				if dot(p, q) < CHIP_SHARPNESS then
					local m = { p[1] + q[1], p[2] + q[2], p[3] + q[3] }
					local length = math.sqrt(dot(m, m))
					if length > 0.5 then
						local edge = (p[4] + q[4]) / length
						local chip = { m[1] / length, m[2] / length, m[3] / length, edge - CHIP_EDGE * radius }
						table.insert(cuts, chip)
						tris = clip(tris, chip)
					end
				end
			end
		end
		for a = 1, #facets do
			for b = a + 1, #facets do
				for c = b + 1, #facets do
					local p, q, r = facets[a], facets[b], facets[c]
					local qr, rp, pq = cross(q, r), cross(r, p), cross(p, q)
					local determinant = dot(p, qr)
					if
						dot(p, q) < CHIP_SHARPNESS
						and dot(q, r) < CHIP_SHARPNESS
						and dot(r, p) < CHIP_SHARPNESS
						and math.abs(determinant) > 1e-3
					then
						local corner = {
							(p[4] * qr[1] + q[4] * rp[1] + r[4] * pq[1]) / determinant,
							(p[4] * qr[2] + q[4] * rp[2] + r[4] * pq[2]) / determinant,
							(p[4] * qr[3] + q[4] * rp[3] + r[4] * pq[3]) / determinant,
						}
						local m = { p[1] + q[1] + r[1], p[2] + q[2] + r[2], p[3] + q[3] + r[3] }
						local length = math.sqrt(dot(m, m))
						if length > 0.5 then
							m = { m[1] / length, m[2] / length, m[3] / length }
							local chip = { m[1], m[2], m[3], dot(m, corner) - CHIP_CORNER * radius }
							table.insert(cuts, chip)
							tris = clip(tris, chip)
						end
					end
				end
			end
		end
		-- The worn edges. An edge exists where two cuts share at least two of
		-- the stone's corners. Each is rounded by planes tangent to a cylinder
		-- of the bevel's radius sitting inside both cuts, at normals stepped
		-- evenly between theirs, so the bevel stays on the stone and the seams
		-- cut later stay exact.
		local bevel = math.min(ROUND_RADIUS, ROUND_SHARE * radius)
		local shared, seenCorner = {}, {}
		for _, tri in tris do
			for _, p in tri do
				local cornerKey = string.format("%.5f:%.5f:%.5f", p[1], p[2], p[3])
				if not seenCorner[cornerKey] then
					seenCorner[cornerKey] = true
					local on = {}
					for c, cut in cuts do
						if math.abs(planeDistance(cut, p)) < 1e-5 then
							table.insert(on, c)
						end
					end
					for x = 1, #on do
						for y = x + 1, #on do
							local pair = on[x] * 1000 + on[y]
							shared[pair] = (shared[pair] or 0) + 1
						end
					end
				end
			end
		end
		for pair, count in shared do
			local p, q = cuts[pair // 1000], cuts[pair % 1000]
			local fold = dot(p, q)
			if count >= 2 and fold < ROUND_MIN_FOLD and fold > -0.99 then
				local angle = math.acos(math.clamp(fold, -1, 1))
				for s = 1, ROUND_SEGMENTS do
					local t = (s - 0.5) / ROUND_SEGMENTS
					local a, b = math.sin((1 - t) * angle) / math.sin(angle), math.sin(t * angle) / math.sin(angle)
					tris = clip(tris, {
						a * p[1] + b * q[1],
						a * p[2] + b * q[2],
						a * p[3] + b * q[3],
						a * (p[4] - bevel) + b * (q[4] - bevel) + bevel,
					})
				end
			end
		end
		-- A stone grown to seal a seam stops level with the neighbour it meets.
		if seamLimit[i] then
			local own = wallNormal(seed.angle, seed.t)
			tris = clip(tris, { own[1], own[2], own[3], seamLimit[i] })
		end
		-- Keep the flat top clear.
		tris = clip(tris, { 0, 0, 1, CAP_TOP - 0.2 })
		-- The fit: cut against every nearby seed, so neighbours share planes.
		local seams = {}
		for j, other in seeds do
			if j ~= i then
				local dx, dy, dz = other[1] - seed[1], other[2] - seed[2], other[3] - seed[3]
				local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
				if distance < REACH and distance > 1e-6 then
					local n = { dx / distance, dy / distance, dz / distance }
					-- The power plane: the midpoint shifts by the weight
					-- difference, so a heavy seed pushes it away from itself.
					local seedSq = seed[1] ^ 2 + seed[2] ^ 2 + seed[3] ^ 2
					local otherSq = other[1] ^ 2 + other[2] ^ 2 + other[3] ^ 2
					local offset = (otherSq - seedSq + seed.weight - other.weight) / (2 * distance)
					local plane = { n[1], n[2], n[3], offset }
					tris = clip(tris, plane)
					table.insert(seams, { other = j, plane = plane })
				end
			end
		end
		-- Wind every triangle outward from the seed.
		for k, tri in tris do
			local a, b, c = tri[1], tri[2], tri[3]
			local n = cross({ b[1] - a[1], b[2] - a[2], b[3] - a[3] }, { c[1] - a[1], c[2] - a[2], c[3] - a[3] })
			local mid = { (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3, (a[3] + b[3] + c[3]) / 3 }
			local facing = n[1] * (mid[1] - seed[1]) + n[2] * (mid[2] - seed[2]) + n[3] * (mid[3] - seed[3])
			if facing < 0 then
				tris[k] = { a, c, b }
			end
		end
		stones[i] = { tris = tris, seams = seams }
	end
	-- Only the faces anyone can see are kept. A seam face loses the part its
	-- neighbour's matching face covers, and anything left wholly inside the
	-- body goes too: the stones cover the whole wall, so only the slit under
	-- the rim looks inside. The dropped faces still shade the stones and the
	-- top, through the hidden part.
	-- Each stone's faces sorted by the seam they lie on, keyed by neighbour.
	for _, stone in stones do
		stone.onSeam, stone.seamOf = {}, {}
		for k, tri in stone.tris do
			for _, seam in stone.seams do
				if onPlane(tri, seam.plane) then
					stone.onSeam[seam.other] = stone.onSeam[seam.other] or {}
					table.insert(stone.onSeam[seam.other], tri)
					stone.seamOf[k] = seam
					break
				end
			end
		end
	end
	local visible = {}
	for i, stone in stones do
		visible[i] = { polygons = {}, area = 0, seams = stone.seams }
		for k, tri in stone.tris do
			local pieces = { tri }
			local seam = stone.seamOf[k]
			if seam then
				local other = stones[seam.other]
				other.covers = other.covers or {}
				other.covers[i] = other.covers[i] or seamCover(other.onSeam[i] or {}, seam.plane)
				pieces = uncovered(tri, other.covers[i], seam.plane)
			end
			-- A face that loses any part keeps its whole self in the hidden
			-- part, so the bake still sees every stone as it was.
			local whole = #pieces == 1 and pieces[1] == tri
			for _, polygon in pieces do
				if insideBody(polygon) and not seenThroughRim(polygon) then
					whole = false
				else
					table.insert(visible[i].polygons, polygon)
					visible[i].area += polygonArea(polygon)
				end
			end
			if not whole then
				emitPolygon(hiddenRocks, tri)
			end
		end
	end
	hiddenRocks:weld(1e-4)
	return visible
end

-- One mesh of the given stones' visible faces, welded so the shading can run
-- smooth over each stone; the crease angle keeps the cuts and seams sharp.
local function stonesMesh(mesh, visible, members)
	for _, i in members do
		for _, polygon in visible[i].polygons do
			emitPolygon(mesh, polygon)
		end
	end
	mesh:weld(1e-4)
end

-- The stones in runs of neighbours round the island, as few runs as fit: runs
-- of about equal area, one more each try, until every run's texture holds it
-- at TEXEL_DENSITY within ROCK_TEXTURE.
local function rockGroups(visible)
	local order, total = {}, 0
	for i in visible do
		table.insert(order, i)
		total += visible[i].area
	end
	table.sort(order, function(a, b)
		return seeds[a].angle % TAU < seeds[b].angle % TAU
	end)
	local function fits(members): boolean
		local mesh = Mesh.new()
		stonesMesh(mesh, visible, members)
		mesh:setSmooth(SMOOTH_ANGLE)
		return math.ceil(TEXEL_DENSITY / mesh:unwrap() / 4) * 4 <= ROCK_TEXTURE
	end
	local count = math.max(1, math.ceil(total * TEXEL_DENSITY ^ 2 / ROCK_TEXTURE ^ 2))
	while true do
		local groups, sum = {}, 0
		for _, i in order do
			local g = math.min(count, math.floor(sum / total * count) + 1)
			groups[g] = groups[g] or {}
			table.insert(groups[g], i)
			sum += visible[i].area
		end
		local ok = true
		for g = 1, count do
			if groups[g] and not fits(groups[g]) then
				ok = false
				break
			end
		end
		if ok then
			return groups
		end
		count += 1
	end
end

-- Each stone's own coat: the rock colour shifted a little per stone, some
-- warmer and browner, some cooler and greyer, up to 8% lighter or darker, flat
-- across the stone so neighbours read apart without any noise.
local STONE_BRIGHTNESS, STONE_WARMTH = 0.08, 0.4
-- How far the light's colour shifts each channel: warm on tops, cool below.
local SKY_TINT = 0.1
-- Rock patches over the stone faces: faceted cells about SPLOTCH_SIZE studs
-- across (jittered Voronoi), each one a stepped shade up to SPLOTCH_STRENGTH
-- lighter or darker, quantized to SPLOTCH_STEPS levels, so patches meet on
-- straight edges like broken facets. SPLOTCH_GREY pulls a patch's colour
-- toward grey by that share at full strength, so the shift is mostly value.
local SPLOTCH_SIZE = 4.5
local SPLOTCH_STRENGTH = 0.07
local SPLOTCH_STEPS = 5
local SPLOTCH_GREY = 0.35
-- Fine grain: small light and dark flecks GRAIN_SIZE studs across, the ones
-- past GRAIN_FLECK in a fast noise, up to GRAIN_STRENGTH lighter or darker.
local GRAIN_SIZE = 0.22
local GRAIN_FLECK = 0.28
local GRAIN_STRENGTH = 0.05
-- Mineral veins: on VEIN_SHARE of the stones, faint thin light streaks
-- VEIN_WIDTH studs wide, VEIN_SPACING apart, slanted across the stone and
-- broken up along their length, VEIN_STRENGTH lighter at most.
local VEIN_SHARE = 0.35
local VEIN_WIDTH = 0.12
local VEIN_SPACING = 3.5
local VEIN_STRENGTH = 0.08
-- The soil's colour, and how far its lip hangs below the top as a share of the
-- island's height (used by the soil below and by the stain on the stones).
local SOIL_COLOUR = { 0.24, 0.17, 0.12 }
local SOIL_HANG = 0.05
-- Soil stain: earthy dirt, warmer than the soil so it reads on shaded sides, bleeding onto the stones under the soil's lip, at
-- most SOIL_STAIN_STRENGTH, fading out over SOIL_STAIN_DEPTH studs with a
-- ragged edge SOIL_STAIN_RAGGED studs either way, and washed-down streaks
-- reaching SOIL_STAIN_STREAK studs further. Tops take it more than sides.
-- It holds full strength SOIL_STAIN_START studs below the lip's shallowest
-- point first, past the soil's usual droop, so the fade shows under it.
local SOIL_STAIN_STRENGTH = 1
local SOIL_STAIN_DEPTH = 7
local SOIL_STAIN_START = 2.5
local SOIL_STAIN_RAGGED = 2
local SOIL_STAIN_STREAK = 4
local SOIL_STAIN_COLOUR = { 0.34, 0.22, 0.13 }
local stoneNeighbours, stoneColour = {}, {}
for i, seed in seeds do
	stoneNeighbours[i] = {}
	for j, other in seeds do
		local dx, dy, dz = other[1] - seed[1], other[2] - seed[2], other[3] - seed[3]
		if j ~= i and dx * dx + dy * dy + dz * dz < REACH * REACH then
			table.insert(stoneNeighbours[i], j)
		end
	end
end

-- Paints stones in their own colours. A point belongs to the stone whose
-- power cell holds it, since the stones were cut on those planes; the walk
-- starts from the last stone found, so it rarely takes more than one step.
local function stonePaint(base, members)
	for _, i in members do
		local light = 1 + (2 * hash(SEED * 211 + i * 7.3) - 1) * STONE_BRIGHTNESS
		local warmth = (2 * hash(SEED * 223 + i * 5.9) - 1) * STONE_WARMTH
		local r, g, b = base[1], base[2], base[3]
		if warmth > 0 then
			r, g, b = r * (1 + 0.07 * warmth), g * (1 + 0.015 * warmth), b * (1 - 0.1 * warmth)
		else
			local grey = (r + g + b) / 3
			local mix = -warmth * 0.55
			r, g, b = r + (grey - r) * mix, g + (grey - g) * mix, b + (grey * 1.04 - b) * mix
		end
		stoneColour[i] = { r * light, g * light, b * light }
	end
	local last = members[1]
	local function power(i, x, y, z): number
		local s = seeds[i]
		return (x - s[1]) ^ 2 + (y - s[2]) ^ 2 + (z - s[3]) ^ 2 - s.weight
	end
	return rusting(0, function(x, y, z, _nx, _ny, nz)
		local best = power(last, x, y, z)
		while true do
			local step = nil
			for _, j in stoneNeighbours[last] do
				local p = power(j, x, y, z)
				if p < best then
					best, step = p, j
				end
			end
			if not step then
				break
			end
			last = step
		end
		local colour = stoneColour[last] or base
		-- Rock patches: the nearest jittered cell point picks the patch, and its
		-- hash a stepped shade, lighter or darker and greyer the further it goes.
		local cx, cy, cz = math.floor(x / SPLOTCH_SIZE), math.floor(y / SPLOTCH_SIZE), math.floor(z / SPLOTCH_SIZE)
		local nearest, cell = math.huge, 0
		for ix = cx - 1, cx + 1 do
			for iy = cy - 1, cy + 1 do
				for iz = cz - 1, cz + 1 do
					local key = ix * 157.1 + iy * 311.7 + iz * 74.3
					local px = (ix + hash(key + 1.7)) * SPLOTCH_SIZE - x
					local py = (iy + hash(key + 5.3)) * SPLOTCH_SIZE - y
					local pz = (iz + hash(key + 9.1)) * SPLOTCH_SIZE - z
					local d = px * px + py * py + pz * pz
					if d < nearest then
						nearest, cell = d, key
					end
				end
			end
		end
		local step = math.floor(hash(cell + SEED * 13.7) * SPLOTCH_STEPS)
		local shade = (2 * step / (SPLOTCH_STEPS - 1) - 1) * SPLOTCH_STRENGTH
		-- Grain: flecks where a fast noise passes GRAIN_FLECK either way.
		local grain = math.noise(x / GRAIN_SIZE, y / GRAIN_SIZE, z / GRAIN_SIZE + 211)
		local fleck = math.clamp((math.abs(grain) - GRAIN_FLECK) / 0.12, 0, 1)
		shade += (if grain > 0 then fleck else -fleck) * GRAIN_STRENGTH
		-- Veins: bands across a slanted direction per stone, thin and broken up
		-- by a slow noise so only stretches of them show.
		if hash(SEED * 241 + last * 3.1) < VEIN_SHARE then
			local turn = hash(SEED * 251 + last * 4.7) * TAU
			local tilt = 0.5 + 0.4 * hash(SEED * 263 + last * 6.1)
			local along = x * math.cos(turn) * tilt + y * math.sin(turn) * tilt + z * (1 - tilt)
				+ 0.3 * math.noise(x / 1.3, y / 1.3, z / 1.3 + 271)
			local band = math.abs(along / VEIN_SPACING - math.floor(along / VEIN_SPACING + 0.5)) * VEIN_SPACING
			local line = math.clamp(1 - band / VEIN_WIDTH, 0, 1)
			local show = math.clamp(math.noise(x / 2, y / 2, z / 2 + 281) * 3 + 0.3, 0, 1)
			shade += line * show * VEIN_STRENGTH
		end
		local grey = (colour[1] + colour[2] + colour[3]) / 3
		local mix = math.min(math.abs(shade) / SPLOTCH_STRENGTH, 1) * SPLOTCH_GREY
		local light = 1 + shade
		colour = {
			(colour[1] + (grey - colour[1]) * mix) * light,
			(colour[2] + (grey - colour[2]) * mix) * light,
			(colour[3] + (grey - colour[3]) * mix) * light,
		}
		-- Soil stain: full just under the soil's lip, fading downward past a
		-- slow-noise ragged edge, with thin streaks running further down.
		local below = math.max(CAP_TOP - SOIL_HANG * DEPTH - SOIL_STAIN_START - z, 0)
		local ragged = SOIL_STAIN_RAGGED * math.noise(x / 3, y / 3, 331)
		local fade = math.clamp(1 - (below + ragged) / SOIL_STAIN_DEPTH, 0, 1)
		local streakLine = math.clamp(math.noise(x / 0.6, y / 0.6, 337) * 2.5 - 0.6, 0, 1)
		local streakFade = math.clamp(1 - (below + ragged) / (SOIL_STAIN_DEPTH + SOIL_STAIN_STREAK), 0, 1)
		local stain = math.max(fade * fade, streakLine * streakFade * 0.7)
		stain *= SOIL_STAIN_STRENGTH * (0.55 + 0.45 * math.max(nz, 0))
		colour = {
			colour[1] + (SOIL_STAIN_COLOUR[1] - colour[1]) * stain,
			colour[2] + (SOIL_STAIN_COLOUR[2] - colour[2]) * stain,
			colour[3] + (SOIL_STAIN_COLOUR[3] - colour[3]) * stain,
		}
		-- Sunlit tops warm toward yellow-orange, undersides cool toward a
		-- blue-purple bounce, the sides blending between.
		local up = math.clamp(nz, -1, 1)
		local warm, cool = math.max(up, 0), math.max(-up, 0)
		local tint = SKY_TINT
		return colour[1] * (1 + tint * (warm - 0.6 * cool)),
			colour[2] * (1 + tint * (0.5 * warm - 0.3 * cool)),
			colour[3] * (1 + tint * (-warm + cool))
	end)
end

-- The soil: a thick layer spread like peanut butter over the flat top and on
-- over the rim stones' tops, ending in a rounded bead that overhangs the
-- stones unevenly with a few drips. It hides the old flat top completely, so
-- it replaces it. Built as one sheet over a polar grid: the top surface out
-- to the bead, round the bead, then a short way back in underneath (the rest
-- of the underside sits inside the stones, so it is left open).
local SOIL_ANGLES, SOIL_RINGS = 192, 24
-- Where the soil rests: just under the stones' cut tops, so no face is shared.
local SOIL_BASE = CAP_TOP - 0.25
-- Thickness above the old flat top's height, and the knife-stroke ridges and lumps.
local SOIL_THICKNESS = 1.15
local SOIL_RIDGE, SOIL_RIDGE_SPACING = 0.17, 5.5
local SOIL_LUMP = 0.14
-- How far the bead's outer edge sits past the stones' top edge, on average,
-- and how far either way it wanders; then the drips. It hangs past and down
-- by at least SOIL_HANG of the island's height everywhere.
local SOIL_OVERHANG, SOIL_OVERHANG_SPREAD = 3, 1.8
-- How much more the hang varies round the edge, as a share of it, so the
-- whole lip drips unevenly rather than at one depth.
local SOIL_DRIP_VARIANCE = 0.25
local SOIL_DRIPS, SOIL_DRIP_WIDTH = 10, 0.09
local BEAD_STEPS = 8
local UNDER_RINGS = { 0.5, 1.2, 2.2, 3.5 }

local soilPhase = {}
for i = 1, 4 do
	soilPhase[i] = hash(SEED * 301 + i) * TAU
end
local drips = {}
for d = 1, SOIL_DRIPS do
	drips[d] = { angle = hash(SEED * 311 + d) * TAU, size = 0.6 + 0.4 * hash(SEED * 313 + d) }
end

-- Thickness at a point: wide gentle strokes whose direction turns slowly over
-- the island, plus soft lumps, kept to 0.8-1.5 studs.
local function soilThickness(x: number, y: number): number
	local turn = 1.4 * math.noise(x / 22, y / 22, 7.3) + soilPhase[1]
	local along = x * math.cos(turn) + y * math.sin(turn) + 1.8 * math.noise(x / 9, y / 9, 3.1)
	local ridge = math.sin(along / SOIL_RIDGE_SPACING * TAU)
	local lump = math.noise(x / 4.5, y / 4.5, 11.7)
	return math.clamp(SOIL_THICKNESS + SOIL_RIDGE * ridge + SOIL_LUMP * lump, 0.8, 1.5)
end

-- The stones' top edge per angle: the furthest point of their cut tops, with
-- the gaps between stones bridged and smoothed so the soil follows them loosely.
local function stoneTopEdge(visible)
	local edge = {}
	for _, stone in visible do
		for _, polygon in stone.polygons do
			for _, p in polygon do
				if p[3] > CAP_TOP - 0.25 then
					local j = math.floor((math.atan2(p[2], p[1]) % TAU) / TAU * SOIL_ANGLES + 0.5) % SOIL_ANGLES
					local r = math.sqrt(p[1] * p[1] + p[2] * p[2])
					edge[j] = math.max(edge[j] or 0, r)
				end
			end
		end
	end
	local widened = {}
	for j = 0, SOIL_ANGLES - 1 do
		local best = 0
		for k = -3, 3 do
			best = math.max(best, edge[(j + k) % SOIL_ANGLES] or 0)
		end
		if best == 0 then
			local p = wallPoint(TAU * j / SOIL_ANGLES, 0)
			best = math.sqrt(p[1] * p[1] + p[2] * p[2]) + 1
		end
		widened[j] = best
	end
	local smooth = {}
	for j = 0, SOIL_ANGLES - 1 do
		local sum = 0
		for k = -4, 4 do
			sum += widened[(j + k) % SOIL_ANGLES]
		end
		smooth[j] = sum / 9
	end
	return smooth
end

local function buildSoil(mesh, visible)
	local stoneEdge = stoneTopEdge(visible)
	local columns = {}
	for j = 0, SOIL_ANGLES - 1 do
		local angle = TAU * j / SOIL_ANGLES
		local c, s = math.cos(angle), math.sin(angle)
		local wander = 0.5 * math.sin(3 * angle + soilPhase[2]) + 0.3 * math.sin(7 * angle + soilPhase[3])
			+ 0.2 * math.sin(13 * angle + soilPhase[4])
		local over = SOIL_OVERHANG + SOIL_OVERHANG_SPREAD * wander
		local drip = 0
		for _, d in drips do
			local gap = (angle - d.angle + math.pi) % TAU - math.pi
			drip = math.max(drip, d.size * math.exp(-((gap / SOIL_DRIP_WIDTH) ^ 2)))
		end
		over = math.max(over, SOIL_HANG * DEPTH) + 0.8 * drip
		local outer = stoneEdge[j] + over
		-- The bead hangs lower where it is past the stones, and lowest at a drip.
		local sag = 0.5 + 0.5 * math.noise(c * 6, s * 6, 5.9) + 0.35 * math.sin(23 * angle + soilPhase[1])
		local droop = (SOIL_HANG * DEPTH + math.clamp(over / 4, 0, 1) + 1.6 * drip) * (1 + SOIL_DRIP_VARIANCE * math.clamp(sag, 0, 1))
		local bottom = SOIL_BASE - droop
		-- The bead: its top meets the surface level, its round runs out to `outer`.
		local probe = outer - 1
		local top = SOIL_BASE + 0.25 + soilThickness(probe * c, probe * s)
		local half = (top - bottom) / 2
		local width = half * (0.85 + 0.25 * hash(SEED * 331 + j))
		local centre = outer - width
		local column = {}
		for k = 1, SOIL_RINGS do
			local r = centre * k / SOIL_RINGS
			local x, y = r * c, r * s
			local z = SOIL_BASE + 0.25 + soilThickness(x, y)
			-- Ease the last stretch onto the bead's top so the surface runs on smooth.
			local blend = math.clamp((k / SOIL_RINGS - 0.85) / 0.15, 0, 1)
			z += (top - z) * blend * blend
			table.insert(column, mesh:vertex(x, y, z))
		end
		local middle = (top + bottom) / 2
		for step = 1, BEAD_STEPS do
			local phi = math.pi * step / BEAD_STEPS
			local r = centre + width * math.sin(phi)
			table.insert(column, mesh:vertex(r * c, r * s, middle + half * math.cos(phi)))
		end
		for _, inward in UNDER_RINGS do
			local r = centre - inward
			local z = SOIL_BASE - droop * math.exp(-((inward / 1.2) ^ 2))
			table.insert(column, mesh:vertex(r * c, r * s, z))
		end
		columns[j] = column
	end
	local middle = mesh:vertex(0, 0, SOIL_BASE + 0.25 + soilThickness(0, 0))
	for j = 0, SOIL_ANGLES - 1 do
		local a, b = columns[j], columns[(j + 1) % SOIL_ANGLES]
		mesh:face({ middle, a[1], b[1] })
		for k = 1, #a - 1 do
			mesh:face({ a[k], a[k + 1], b[k + 1] })
			mesh:face({ a[k], b[k + 1], b[k] })
		end
	end
end

-- Soil settled into the seams. For each pair of neighbouring stones, the
-- seam's outer edge is traced from their visible corners lying on the shared
-- plane (the outermost one per height band), and a half-round bead runs down
-- it from the stones' tops, under the soil's lip, tapering to a point.
local function buildSeamSoil(mesh, visible)
	local top = CAP_TOP - 0.2
	local lip = CAP_TOP - SOIL_HANG * DEPTH
	for i, stone in visible do
		for _, seam in stone.seams do
			local j, plane = seam.other, seam.plane
			if j < i or not visible[j] then
				continue
			end
			local length = SEAM_SOIL_MIN + (SEAM_SOIL_MAX - SEAM_SOIL_MIN) * hash(SEED * 401 + i * 13.1 + j * 7.7)
			local bottom = lip - length
			-- The outermost corner on the seam per band, from both stones.
			local band = (top - bottom) / SEAM_SOIL_STEPS
			local outer = {}
			for _, owner in { stone, visible[j] } do
				for _, polygon in owner.polygons do
					for _, p in polygon do
						if math.abs(planeDistance(plane, p)) < 1e-3 and p[3] <= top + 0.05 and p[3] >= bottom - band then
							local b = math.clamp(math.floor((top - p[3]) / band), 0, SEAM_SOIL_STEPS)
							local r = p[1] * p[1] + p[2] * p[2]
							if not outer[b] or r > outer[b].r then
								outer[b] = { r = r, p = p }
							end
						end
					end
				end
			end
			-- Only seams that reach the top band, near the lip.
			if not outer[0] then
				continue
			end
			local found = {}
			for b = 0, SEAM_SOIL_STEPS do
				if outer[b] then
					table.insert(found, outer[b].p)
				end
			end
			local function edgeAt(z: number): { number }
				local above = found[1]
				for _, p in found do
					if p[3] >= z then
						above = p
					else
						local t = (above[3] - z) / math.max(above[3] - p[3], 1e-6)
						return { above[1] + (p[1] - above[1]) * t, above[2] + (p[2] - above[2]) * t, z }
					end
				end
				return { above[1], above[2], z }
			end
			-- Across the seam, and outward from the crease along the plane.
			local across = { plane[1], plane[2], plane[3] }
			local rings, flip = {}, false
			for s = 0, SEAM_SOIL_STEPS - 1 do
				local z = top - (top - bottom) * s / SEAM_SOIL_STEPS
				local centre = edgeAt(z)
				local radial = normalize({ centre[1], centre[2], 0 })
				local out = normalize({
					radial[1] - across[1] * dot(radial, across),
					radial[2] - across[2] * dot(radial, across),
					radial[3] - across[3] * dot(radial, across),
				})
				-- Wind the faces outward: ring order runs from +across over the top.
				if s == 0 then
					flip = dot(cross({ 0, 0, -1 }, out), across) < 0
				end
				-- Full down to the lip, then tapering, its width wobbling.
				local taper = math.clamp((z - bottom) / math.max(lip - bottom, 1e-6), 0, 1) ^ 0.7
				local wobble = 1 + 0.3 * math.noise(centre[1] / 1.5, centre[2] / 1.5, z / 1.5 + 421)
				local width, proud = SEAM_SOIL_WIDTH * taper * wobble, SEAM_SOIL_PROUD * taper * wobble
				local ring = {}
				for k = 0, SEAM_SOIL_SIDES do
					local theta = math.pi * k / SEAM_SOIL_SIDES
					local a, o = width * math.cos(theta), proud * math.sin(theta) - 0.1
					ring[k] = mesh:vertex(
						centre[1] + across[1] * a + out[1] * o,
						centre[2] + across[2] * a + out[2] * o,
						centre[3] + across[3] * a + out[3] * o
					)
				end
				rings[s] = ring
			end
			local tip = edgeAt(bottom)
			local tipVertex = mesh:vertex(tip[1], tip[2], tip[3])
			local function face(p, q, r)
				mesh:face(if flip then { p, r, q } else { p, q, r })
			end
			for s = 0, SEAM_SOIL_STEPS - 1 do
				local a = rings[s]
				local b = rings[s + 1]
				for k = 0, SEAM_SOIL_SIDES - 1 do
					if b then
						face(a[k], b[k], b[k + 1])
						face(a[k], b[k + 1], a[k + 1])
					else
						face(a[k], tipVertex, a[k + 1])
					end
				end
			end
		end
	end
end

-- The soil's coat: the brown shifted in soft wide patches and fine grain,
-- warmed on top and cooled below like the stones.
local soilPaint = rusting(0, function(x, y, z, _nx, _ny, nz)
	local patch = math.noise(x / 6, y / 6, z / 6 + 401)
	local grain = math.noise(x / 0.3, y / 0.3, z / 0.3 + 409)
	local light = 1 + 0.06 * patch + 0.035 * grain
	local up = math.clamp(nz, -1, 1)
	local warm, cool = math.max(up, 0), math.max(-up, 0)
	return SOIL_COLOUR[1] * light * (1 + SKY_TINT * (warm - 0.6 * cool)),
		SOIL_COLOUR[2] * light * (1 + SKY_TINT * (0.5 * warm - 0.3 * cool)),
		SOIL_COLOUR[3] * light * (1 + SKY_TINT * (-warm + cool))
end)

-- The parts and their shading are cached under a key hashing every line above
-- "-- cached above", so an unchanged rebuild loads them instead of baking.
-- finishParts() adds parts straight to the model, so model.part is swapped
-- for a collector while it runs and the collected list is what gets cached.
local baked = model.cached(CACHE_KEY, function()
	-- The top and the stones shade against the body's island-wide height
	-- range, so the gradient runs on across every part instead of restarting
	-- in each.
	local islandRange = { RIM_Z, CAP_TOP }
	-- The stones go in a few parts of neighbouring stones, all in one group, so
	-- they shade each other as one surface.
	local visible = buildRocks()
	-- The soil replaces the flat top, which it hides completely. Fully smooth,
	-- with the stones' bold painted highlights.
	chunkedPart("Soil", nil, SOIL_COLOUR, function(mesh)
		buildSoil(mesh, visible)
		buildSeamSoil(mesh, visible)
	end, true, soilPaint, true, 1, nil, nil, islandRange)
	for _, entry in parts do
		if entry.group == "Soil" then
			entry.wide = 4
			entry.painted = true
			entry.blend = 1
		end
	end
	for g, members in rockGroups(visible) do
		-- Flat, since a paint fn would otherwise bring back the warp rust 0 skips.
		local rock = { 0.33, 0.34, 0.36 }
		part(`Rocks_{g}`, nil, rock, function(mesh)
			stonesMesh(mesh, visible, members)
		end, nil, stonePaint(rock, members), nil, nil, true)
		parts[#parts].group = "Rocks"
		parts[#parts].heightRange = islandRange
		parts[#parts].wide = 4
		parts[#parts].edge = 1
		parts[#parts].painted = true
		parts[#parts].blend = 1
	end
	-- The hidden faces join the rocks' group, so the stones still shade with
	-- them as their own surfaces and the body still takes their shadows. Marked
	-- emissive, finishParts skips baking them, and they are left out below.
	table.insert(parts, { name = "HiddenRocks", mesh = hiddenRocks, emissive = 1, group = "Rocks" })
	-- The body's wall stays for the bake the same way, in the top's group as
	-- it was when they were one part, so the stones still take its shadows.
	local wall = Mesh.new()
	buildWall(wall)
	table.insert(parts, { name = "BodyWall", mesh = wall, emissive = 1, group = "Top" })
	local addPart, collected = model.part, {}
	model.part = function(name, mesh, image, options)
		if name == "HiddenRocks" or name == "BodyWall" then
			return
		end
		table.insert(collected, { name = name, mesh = mesh, image = image, preview = options.preview, emissive = options.emissive })
	end
	finishParts()
	model.part = addPart
	table.clear(parts)
	return collected
end)
-- cached above

for _, entry in baked do
	model.part(entry.name, entry.mesh, entry.image, { preview = entry.preview, emissive = entry.emissive })
end
