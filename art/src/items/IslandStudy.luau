-- Island Study: steps 1 to 3 of the island generator.
-- The body is the flat-topped solid: a wobbly outline with one shallow bay,
-- a cosine wall and a small flat underside. Over the wall sit fitted rock
-- cells: each one a displaced blob cut by the bisector planes to its
-- neighbours, so the stones meet exactly, then sliced with a few facet
-- planes so they read as cut stone rather than balls.
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
-- How many times a cell's blob is split. One is enough: the fitting and the
-- slices do the shaping, and the cells are small on screen.
local ROCK_SUBDIVISIONS = 1
local ANGLES, STEPS = 128, 28
local TAU = 2 * math.pi

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

-- The cells: seeds round the wall in staggered rows. Every slot keeps a
-- stone; size variety comes from a power weight instead of dropped slots,
-- because a dropped slot leaves a hole its neighbours may not reach across.
local seeds = {}
for row = 0, ROCK_ROWS - 1 do
	local t = 0.1 + (0.86 - 0.1) * (row + 0.5) / ROCK_ROWS
	local circumference = TAU * RADIUS * WALL_REACH * shareAt(t)
	local count = math.max(6, math.round(circumference / ROCK_WIDTH))
	local offset = (row % 2) * 0.5
	for col = 0, count - 1 do
		local i = #seeds + 1
		local angle = TAU * (col + offset) / count
		local p = wallPoint(angle, t)
		local n = wallNormal(angle, t)
		-- Some seeds sit inside the wall, some just outside, so the cells cut
		-- the surface at angles rather than all from one shell.
		local lift = -1.2 + 2.6 * hash(SEED * 71 + i)
		seeds[i] = {
			p[1] + n[1] * lift,
			p[2] + n[2] * lift,
			p[3] + n[3] * lift,
			size = 0.85 + 0.3 * hash(SEED * 53 + i),
			t = t,
			-- A heavy seed claims more of the wall than a light one. The
			-- weight is in squared-distance units, so it scales with spacing.
			weight = (hash(SEED * 57 + i) - 0.5) * spacing * spacing * 0.55,
		}
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

part("Body", nil, { 0.33, 0.3, 0.26 }, function(mesh)
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
	local top = mesh:vertex(0, 0, CAP_TOP)
	local bottom = mesh:vertex(0, 0, RIM_Z)
	for j = 0, ANGLES - 1 do
		local l = (j + 1) % ANGLES
		mesh:face({ top, rings[0][j], rings[0][l] })
		mesh:face({ bottom, rings[STEPS][l], rings[STEPS][j] })
	end
end, nil, 0)

part("Rocks", nil, { 0.37, 0.34, 0.29 }, function(mesh)
	for i, seed in seeds do
		-- Stones shrink with the wall, so the bottom rows are chips rather
		-- than full-size boulders crowded round a point.
		local radius = cellRadius[i] * seed.size
		local points = {}
		for v, p in unitVertices do
			local r = (1 + 0.16 * wave(p, 2.3, SEED + i) + 0.05 * wave(p, 4.9, SEED + i + 3.1)) * seed.size
			local z = p[3] * r * radius
			-- A hanging stone grows downward from its seed, not both ways.
			if z < 0 then
				z = z * (seed.stretch or 1)
			end
			points[v] = {
				seed[1] + p[1] * r * radius,
				seed[2] + p[2] * r * radius,
				seed[3] + z,
			}
		end
		local tris = {}
		for _, f in unitFaces do
			table.insert(tris, { points[f[1]], points[f[2]], points[f[3]] })
		end
		-- The flat spots, cut while the stone is still free-standing.
		for k = 1, ROCK_FACETS do
			local angle = hash(SEED * 31 + i * 13 + k * 7.1) * TAU
			local z = 2 * hash(SEED * 17 + i * 13 + k * 3.3) - 1
			local ring = math.sqrt(1 - z * z)
			local n = { ring * math.cos(angle), ring * math.sin(angle), z }
			local reach = 0.68 + 0.27 * hash(SEED * 5 + i * 13 + k * 11.7)
			tris = clip(tris, { n[1], n[2], n[3], dot(n, seed) + reach * radius })
		end
		-- Keep the flat top clear.
		tris = clip(tris, { 0, 0, 1, CAP_TOP - 0.2 })
		-- The fit: cut against every nearby seed, so neighbours share planes.
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
					tris = clip(tris, { n[1], n[2], n[3], offset })
				end
			end
		end
		local function emit(list, offsetX: number, offsetY: number, offsetZ: number)
			for _, tri in list do
				local a, b, c = tri[1], tri[2], tri[3]
				local n = cross({ b[1] - a[1], b[2] - a[2], b[3] - a[3] }, { c[1] - a[1], c[2] - a[2], c[3] - a[3] })
				local mid = { (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3, (a[3] + b[3] + c[3]) / 3 }
				local facing = n[1] * (mid[1] - seed[1] - offsetX)
					+ n[2] * (mid[2] - seed[2] - offsetY)
					+ n[3] * (mid[3] - seed[3] - offsetZ)
				if facing < 0 then
					a, b, c = a, c, b
				end
				mesh:face({
					mesh:vertex(a[1] + offsetX, a[2] + offsetY, a[3] + offsetZ),
					mesh:vertex(b[1] + offsetX, b[2] + offsetY, b[3] + offsetZ),
					mesh:vertex(c[1] + offsetX, c[2] + offsetY, c[3] + offsetZ),
				})
			end
		end

		-- A crack: cut the stone in two along its own plane and pull the halves
		-- apart, so the fracture is geometry with a real gap, not paint. The
		-- halves are capped by the same clip as any other cut.
		if hash(SEED * 137 + i) < 0.45 then
			local angle = hash(SEED * 151 + i) * TAU
			local z = 2 * hash(SEED * 163 + i) - 1
			local ring = math.sqrt(1 - z * z)
			local n = { ring * math.cos(angle), ring * math.sin(angle), z }
			local offset = dot(n, seed)
			local gap = 0.34
			local first = clip(tris, { n[1], n[2], n[3], offset })
			local second = clip(tris, { -n[1], -n[2], -n[3], -offset })
			emit(first, n[1] * gap / 2, n[2] * gap / 2, n[3] * gap / 2)
			emit(second, -n[1] * gap / 2, -n[2] * gap / 2, -n[3] * gap / 2)
		else
			emit(tris, 0, 0, 0)
		end
	end
	-- Weld so the shading can run smooth over each stone; the crease angle in
	-- part() keeps the cut faces and the seams sharp.
	mesh:weld(1e-4)
end, nil, 0, 512)

finishParts()
