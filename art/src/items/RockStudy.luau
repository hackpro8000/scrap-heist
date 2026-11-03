-- Rock Study: step 1 of the rock generator, one basic boulder.
-- An icosphere pushed out by a few seeded waves, then sliced by half a dozen
-- random planes. The slice is a real triangle clip, not a per-vertex clamp:
-- each triangle is cut exactly where the plane crosses it, so every flat face
-- is truly planar and the edges between faces are straight, with no
-- staircasing along the cut. SEED and SIZE are the dials; later steps add
-- strata, chipped corners and a shared generator.
local SEED = 1
local SIZE = 7
-- How far the surface moves in and out of the sphere, as a share of the
-- radius: coarse lumps, then finer waves. Kept low, because the slicing does
-- the shaping; these only stop the base reading as a perfect ball.
local LUMPS, BUMPS, GRAIN = 0.14, 0.05, 0.02
-- How many times the icosphere is split: enough to carry the cut edges,
-- not so much that the rock turns into a dense ball.
local SUBDIVISIONS = 2
-- How many planes slice the rock, and the radii they sit at.
local FACETS = 10
local FACET_MIN, FACET_MAX = 0.62, 0.98

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
	local length = math.sqrt(p[1] * p[1] + p[2] * p[2] + p[3] * p[3])
	return { p[1] / length, p[2] / length, p[3] / length }
end

-- The icosahedron, as unit-length corners and its 20 triangles.
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

-- Splits every triangle into four, the new corners pushed back onto the
-- sphere, and keeps a cache so neighbouring triangles share their midpoints.
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

local vertices, faces = corners, triangles
for _ = 1, SUBDIVISIONS do
	faces = subdivide(vertices, faces)
end

-- Three waves across the sphere: a product of sines per axis, so the lumps
-- run over the surface instead of banding round it.
local function wave(p: { number }, frequency: number, salt: number): number
	return math.sin(frequency * p[1] + salt)
		* math.sin(frequency * p[2] + salt * 1.7)
		* math.sin(frequency * p[3] + salt * 2.3)
end

local function planeDistance(plane: { number }, p: { number }): number
	return plane[1] * p[1] + plane[2] * p[2] + plane[3] * p[3] - plane[4]
end

-- Cuts every triangle at the plane, keeping the side where the distance is
-- negative. A triangle crossing the plane is split at the exact crossings, so
-- the cut edge is a straight line rather than a staircase along the sphere's
-- own tessellation. The opening the cut leaves is then closed with a cap on
-- the plane itself: without the cap the rock would be a hollow shell with a
-- hole where every slice went through.
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
			-- The remaining polygon is convex, so a fan is safe.
			for k = 2, #polygon - 1 do
				table.insert(out, { polygon[1], polygon[k], polygon[k + 1] })
			end
		end
	end

	-- The cap: merge the crossings (each shared edge reports twice), sort them
	-- round the plane's normal and fan them from their centre.
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

-- The slicing planes: seeded directions all round the rock, each at its own
-- radius. They are applied in turn, so a later plane also cuts the faces the
-- earlier ones made.
local planes = {}
for i = 1, FACETS do
	local angle = hash(SEED * 31 + i * 7.1) * 2 * math.pi
	local z = 2 * hash(SEED * 17 + i * 3.3) - 1
	local ring = math.sqrt(1 - z * z)
	planes[i] = {
		ring * math.cos(angle),
		ring * math.sin(angle),
		z,
		FACET_MIN + (FACET_MAX - FACET_MIN) * hash(SEED * 5 + i * 11.7),
	}
end

part("Rock", nil, { 0.37, 0.34, 0.29 }, function(mesh)
	-- The blob, as a triangle soup the clipping can rewrite.
	local points = {}
	for i, p in vertices do
		local r = 1
			+ LUMPS * wave(p, 2.3, SEED)
			+ BUMPS * wave(p, 4.9, SEED + 3.1)
			+ GRAIN * wave(p, 9.7, SEED + 7.4)
		points[i] = { p[1] * r, p[2] * r, p[3] * r }
	end
	local tris = {}
	for _, f in faces do
		table.insert(tris, { points[f[1]], points[f[2]], points[f[3]] })
	end
	for _, plane in planes do
		tris = clip(tris, plane)
	end

	-- Place it: slightly out of round, sat on a flat base at z = 0.
	local placed = {}
	for t, tri in tris do
		placed[t] = {}
		for k = 1, 3 do
			local p = tri[k]
			placed[t][k] = { p[1] * SIZE, p[2] * SIZE * 0.88, p[3] * SIZE * 0.8 + SIZE * 0.55 }
		end
	end
	placed = clip(placed, { 0, 0, -1, 0 })

	-- Winding is checked rather than trusted, so every face points out. The
	-- test is against the rock's own centre, not the origin: the rock is lifted
	-- to sit on the ground, and an origin test would flip its lower half.
	local center = { 0, 0, SIZE * 0.55 }
	for _, tri in placed do
		local a, b, c = tri[1], tri[2], tri[3]
		local n = {
			(b[2] - a[2]) * (c[3] - a[3]) - (b[3] - a[3]) * (c[2] - a[2]),
			(b[3] - a[3]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[3] - a[3]),
			(b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]),
		}
		local mid = { (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3, (a[3] + b[3] + c[3]) / 3 }
		local facing = n[1] * (mid[1] - center[1]) + n[2] * (mid[2] - center[2]) + n[3] * (mid[3] - center[3])
		if facing < 0 then
			a, b, c = a, c, b
		end
		mesh:face({
			mesh:vertex(a[1], a[2], a[3]),
			mesh:vertex(b[1], b[2], b[3]),
			mesh:vertex(c[1], c[2], c[3]),
		})
	end
end, false, 0, 512)

finishParts()
