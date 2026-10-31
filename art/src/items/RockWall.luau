-- Rock Wall: a proof that rocks cut to fit each other.
-- Every rock is the same displaced icosphere as RockStudy, but it is cut by
-- the bisector planes between its seed and every other seed in the wall.
-- Two neighbours share the same bisector, so their faces land on the same
-- plane and meet exactly: the wall has no gaps and no overlaps. The rounded
-- fronts are each cell's own sphere; the flat seams between them are the
-- cuts.
local SEED = 1
local COLS, ROWS = 4, 3
-- Cell spacing across and up, and how big each rock's sphere is. The sphere
-- must overlap its neighbours or the cells pull apart at the seams.
local SPACING_X, SPACING_Z = 4.6, 4.2
local RADIUS = 3.4
-- How far back the wall is cut flat, and how much the fronts are displaced.
local BACK = 1.2
local LUMPS, BUMPS = 0.12, 0.04
local SUBDIVISIONS = 2

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

local GOLDEN = (1 + math.sqrt(5)) / 2
local corners = {
	{ -1, GOLDEN, 0 }, { 1, GOLDEN, 0 }, { -1, -GOLDEN, 0 }, { 1, -GOLDEN, 0 },
	{ 0, -1, GOLDEN }, { 0, 1, GOLDEN }, { 0, -1, -GOLDEN }, { 0, 1, -GOLDEN },
	{ GOLDEN, 0, -1 }, { GOLDEN, 0, 1 }, { -GOLDEN, 0, -1 }, { -GOLDEN, 0, 1 },
}
for i, p in corners do
	corners[i] = normalize(p)
end
local triangles = {
	{ 1, 12, 6 }, { 1, 6, 2 }, { 1, 2, 8 }, { 1, 8, 11 }, { 1, 11, 12 },
	{ 2, 6, 10 }, { 6, 12, 5 }, { 12, 11, 3 }, { 11, 8, 7 }, { 8, 2, 9 },
	{ 4, 10, 5 }, { 4, 5, 3 }, { 4, 3, 7 }, { 4, 7, 9 }, { 4, 9, 10 },
	{ 5, 10, 6 }, { 3, 5, 12 }, { 7, 3, 11 }, { 9, 7, 8 }, { 10, 9, 2 },
}

local function subdivide(vertices, faces)
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
	return out
end

local unitVertices, unitFaces = corners, triangles
for _ = 1, SUBDIVISIONS do
	unitFaces = subdivide(unitVertices, unitFaces)
end

local function wave(p: { number }, frequency: number, salt: number): number
	return math.sin(frequency * p[1] + salt)
		* math.sin(frequency * p[2] + salt * 1.7)
		* math.sin(frequency * p[3] + salt * 2.3)
end

local function planeDistance(plane: { number }, p: { number }): number
	return plane[1] * p[1] + plane[2] * p[2] + plane[3] * p[3] - plane[4]
end

-- Same clip as RockStudy: split each triangle exactly at the plane and cap
-- the opening on the plane. The cap matters here more than anywhere: these
-- cut faces are the seams the neighbouring rock shares.
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

-- The seeds: a jittered grid in the wall plane (x across, z up, y front/back).
local seeds = {}
for row = 0, ROWS - 1 do
	for col = 0, COLS - 1 do
		local i = row * COLS + col + 1
		local x = (col - (COLS - 1) / 2) * SPACING_X + (hash(SEED * 13 + i) - 0.5) * 1.6
		local z = (row - (ROWS - 1) / 2) * SPACING_Z + (hash(SEED * 29 + i) - 0.5) * 1.4
		local y = (hash(SEED * 41 + i) - 0.5) * 0.8
		seeds[i] = { x, y, z }
	end
end

part("Rocks", nil, { 0.37, 0.34, 0.29 }, function(mesh)
	for i, seed in seeds do
		-- The cell's own blob, displaced the way RockStudy is.
		local points = {}
		for v, p in unitVertices do
			local r = 1 + LUMPS * wave(p, 2.3, SEED + i) + BUMPS * wave(p, 4.9, SEED + i + 3.1)
			points[v] = {
				seed[1] + p[1] * r * RADIUS,
				seed[2] + p[2] * r * RADIUS,
				seed[3] + p[3] * r * RADIUS,
			}
		end
		local tris = {}
		for _, f in unitFaces do
			table.insert(tris, { points[f[1]], points[f[2]], points[f[3]] })
		end
		-- The cut to fit: the bisector between this seed and every other.
		for j, other in seeds do
			if j ~= i then
				local between = { other[1] - seed[1], other[2] - seed[2], other[3] - seed[3] }
				local length = math.sqrt(dot(between, between))
				local n = { between[1] / length, between[2] / length, between[3] / length }
				-- The plane's offset from the origin, worked in world space.
				local mid = {
					(seed[1] + other[1]) / 2,
					(seed[2] + other[2]) / 2,
					(seed[3] + other[3]) / 2,
				}
				tris = clip(tris, { n[1], n[2], n[3], dot(n, mid) })
			end
		end
		-- The wall's back, so the cells are not full spheres.
		tris = clip(tris, { 0, 1, 0, BACK })

		for _, tri in tris do
			local a, b, c = tri[1], tri[2], tri[3]
			local n = cross({ b[1] - a[1], b[2] - a[2], b[3] - a[3] }, { c[1] - a[1], c[2] - a[2], c[3] - a[3] })
			local mid = { (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3, (a[3] + b[3] + c[3]) / 3 }
			local facing = n[1] * (mid[1] - seed[1]) + n[2] * (mid[2] - seed[2]) + n[3] * (mid[3] - seed[3])
			if facing < 0 then
				a, b, c = a, c, b
			end
			mesh:face({
				mesh:vertex(a[1], a[2], a[3]),
				mesh:vertex(b[1], b[2], b[3]),
				mesh:vertex(c[1], c[2], c[3]),
			})
		end
	end
end, false, 0, 512)

finishParts()
