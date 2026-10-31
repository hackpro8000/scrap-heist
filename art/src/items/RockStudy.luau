-- Rock Study: step 1 of the rock generator, one basic boulder.
-- An icosphere pushed in and out by a few seeded waves: the coarse wave gives
-- the boulder its lumps, the finer ones break up the silhouette and the
-- surface. Flat shaded, so every facet reads. SEED and SIZE are the dials;
-- later steps add cracks, strata and a shared generator.
local SEED = 1
local SIZE = 7
-- How far the surface moves in and out of the sphere, as a share of the
-- radius: coarse lumps first, then two finer waves.
local LUMPS, BUMPS, GRAIN = 0.2, 0.07, 0.03
-- The ridged wave folds the surface into creases, and CRAG jitters each
-- corner the other way, so the silhouette breaks into chips and notches.
local RIDGE, CRAG = 0.09, 0.16
-- How many planes cut the blob into flat faces, and the radii they sit at.
local FACETS = 10
local FACET_MIN, FACET_MAX = 0.6, 1.0
-- How many times the icosphere is split; 2 gives 320 faces, enough for a
-- basic boulder without turning it into a ball of soup.
local SUBDIVISIONS = 2

local function hash(k: number): number
	local s = math.sin(k * 12.9898 + 4.1414) * 43758.5453
	return s - math.floor(s)
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

-- The three waves: a product of sines per axis, so the rock's lumps run
-- across the surface instead of banding round it.
local function wave(p: { number }, frequency: number, salt: number): number
	return math.sin(frequency * p[1] + salt)
		* math.sin(frequency * p[2] + salt * 1.7)
		* math.sin(frequency * p[3] + salt * 2.3)
end

-- The cutting planes: seeded directions all round the rock, each at its own
-- radius. Where a plane faces the surface it wins, and the rock lands on it,
-- so the shape is the intersection of the blob and these half-spaces.
local planes = {}
for i = 1, FACETS do
	local angle = hash(SEED * 31 + i * 7.1) * TAU
	local z = 2 * hash(SEED * 17 + i * 3.3) - 1
	local ring = math.sqrt(1 - z * z)
	planes[i] = {
		ring * math.cos(angle),
		ring * math.sin(angle),
		z,
		FACET_MIN + (FACET_MAX - FACET_MIN) * hash(SEED * 5 + i * 11.7),
	}
end

local CUT = 0.0

part("Rock", nil, { 0.37, 0.34, 0.29 }, function(mesh)
	local points = {}
	for i, p in vertices do
		local n = LUMPS * wave(p, 2.3, SEED)
			+ BUMPS * wave(p, 4.9, SEED + 3.1)
			+ GRAIN * wave(p, 9.7, SEED + 7.4)
			+ RIDGE * (1 - 2 * math.abs(wave(p, 6.1, SEED + 5.2)))
			+ CRAG * (2 * hash(i * 3.7 + SEED * 11.3) - 1)
		local r = 1 + n
		for _, plane in planes do
			local facing = plane[1] * p[1] + plane[2] * p[2] + plane[3] * p[3]
			if facing > 0.2 then
				r = math.min(r, plane[4] / facing)
			end
		end
		-- Slightly out of round, so no two axes are alike.
		local x, y = p[1] * r * SIZE, p[2] * r * SIZE * 0.88
		local z = p[3] * r * SIZE * 0.8 + SIZE * 0.55
		points[i] = mesh:vertex(x, y, math.max(z, CUT))
	end
	for _, f in faces do
		-- Winding is checked rather than trusted, so every face points out.
		local a, b, c = vertices[f[1]], vertices[f[2]], vertices[f[3]]
		local normal = {
			(b[2] - a[2]) * (c[3] - a[3]) - (b[3] - a[3]) * (c[2] - a[2]),
			(b[3] - a[3]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[3] - a[3]),
			(b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]),
		}
		local out = normal[1] * a[1] + normal[2] * a[2] + normal[3] * a[3]
		if out < 0 then
			mesh:face({ points[f[1]], points[f[3]], points[f[2]] })
		else
			mesh:face({ points[f[1]], points[f[2]], points[f[3]] })
		end
	end
end, false, 0, 512)

finishParts()
