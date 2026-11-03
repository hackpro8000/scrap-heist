-- Floating Island: the generator for the game's floating islands.
-- The island is stones, not a body with stones on it. The profile (a wobbly rim
-- with one shallow bay, a cone down to a point) is only a guide for where the
-- stones sit; none of it is drawn. Cells cover the whole surface: rows down the
-- wall from the rim to the point, and a deck of rings over the flat top. Each
-- cell is a displaced blob cut by the bisector planes to its neighbours, so the
-- stones meet exactly, then sliced with a few facet planes so they read as cut
-- stone. Every stone is cut at one height, so the top is flat and walkable.
--
-- Below FLOAT_START the stones pull back from those planes, so the joints open
-- into gaps and the base comes apart into loose rocks instead of tapering to a
-- solid point. The dials, roughly in the order they matter:
--   SEED, RADIUS, DEPTH_SHARE, TAPER_POWER, WALL_REACH   the profile
--   ROCK_WIDTH, ROW_T, ROCK_FACETS, the deck rings       how it is divided
--   FLOAT_START, FLOAT_SHRINK                            how it comes apart
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
-- Below this share of the profile the stones shrink and pull apart, so the
-- base hangs under the island as loose floating rocks instead of a solid tail.
local FLOAT_START, FLOAT_SHRINK = 0.4, 0.85


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

-- The stones are the surface now, so their seeds cover the whole island: rows
-- down the wall from the rim to the tip, then a deck over the flat top. The
-- profile only decides where the seeds sit; none of it is drawn.
-- Every slot keeps a stone; size variety comes from a power weight instead of
-- dropped slots, because a dropped slot leaves a hole its neighbours may not
-- reach across.
local seeds = {}
local function addSeed(x, y, z, t, size, out, floating)
	local i = #seeds + 1
	-- A heavy seed claims more of the surface than a light one. The weight is
	-- in squared-distance units, so it scales with spacing.
	seeds[i] = {
		x, y, z,
		size = size,
		t = t,
		out = out,
		-- Every stone is cut at one height: the top of the island is a flat,
		-- walkable surface, with no stone standing above its neighbours.
		capZ = CAP_TOP,
		floating = floating,
		weight = (hash(SEED * 57 + i) - 0.5) * spacing * spacing * 0.3,
	}
end

-- Rows down the wall from the rim to the point, bunched where the cone turns
-- quickly so the point closes on stone.
local ROW_T = { 0.09, 0.28, 0.47, 0.64, 0.78, 0.89, 0.96 }
for row = 1, #ROW_T do
	local t = ROW_T[row]
	local circumference = TAU * RADIUS * WALL_REACH * shareAt(t)
	local count = math.max(3, math.round(circumference / ROCK_WIDTH))
	local offset = (row % 2) * 0.5
	-- A size gradient down the wall: each row is smaller than the one above it,
	-- so the stones shrink toward the tip instead of jumping around. The jitter
	-- stays under half a row's step, which keeps the order intact.
	local rowSize = 1.15 - 0.5 * row / #ROW_T
	for col = 0, count - 1 do
		local i = #seeds + 1
		local angle = TAU * (col + offset) / count
		local p = wallPoint(angle, t)
		local n = wallNormal(angle, t)
		-- Some seeds sit inside the wall, some just outside, so the cells cut
		-- the surface at angles rather than all from one shell.
		local lift = -1.2 + 2.6 * hash(SEED * 71 + i)
		addSeed(
			p[1] + n[1] * lift,
			p[2] + n[2] * lift,
			p[3] + n[3] * lift,
			t,
			rowSize + (hash(SEED * 53 + i) - 0.5) * 0.07,
			n
		)
	end
end

-- The deck: seeds on concentric rings over the flat top, trimmed to the
-- outline. Rings keep the spacing even all the way in, so no band of the
-- plateau is left without a stone to cover it. The blobs are cut flat at the
-- cap, so the plateau comes out as a mosaic of stone tops that meet on the
-- same planes the wall stones meet on.
local deckStep = ROCK_WIDTH
local deckSize = 1.15 - 0.5 * 0.5 / #ROW_T
local deckRim = RADIUS * WALL_REACH * (1 + WOBBLE)
for ring = 0, math.floor(deckRim / deckStep) do
	local r = ring * deckStep
	local count = if ring == 0 then 1 else math.max(5, math.round(TAU * r / deckStep))
	local offset = (ring % 2) * 0.5
	for col = 0, count - 1 do
		local angle = TAU * (col + offset) / count
		local x, y = r * math.cos(angle), r * math.sin(angle)
		local rim = RADIUS * WALL_REACH * outlineScale(math.atan2(y, x))
		if math.sqrt(x * x + y * y) < rim - 0.4 then
			local i = #seeds + 1
			addSeed(x, y, CAP_TOP, 0, deckSize + (hash(SEED * 61 + i) - 0.5) * 0.07, { 0, 0, 1 })
		end
	end
end

local REACH = spacing * 3.2

-- Each stone's blob has to reach past the furthest bisector it can be cut
-- by, or the cell never fills its share and a hole appears. So the radius is
-- worked out per cell from its own neighbours, not from one global constant.
local cellRadius = {}
for i, seed in seeds do
	if seed.radius then
		cellRadius[i] = seed.radius
		continue
	end
	-- No floor at the wall spacing: the rows near the tip are only a couple of
	-- studs across, and a floor there grows the chips into a bulb.
	local farthest = 0
	for j, other in seeds do
		if j ~= i then
			local dx, dy, dz = other[1] - seed[1], other[2] - seed[2], other[3] - seed[3]
			local distance = dx * dx + dy * dy + dz * dz
			if distance < REACH * REACH and distance > farthest * farthest then
				farthest = math.sqrt(distance)
			end
		end
	end
	-- A blob far bigger than its own cell clips away to nothing, so the reach
	-- stays close to the cell it has to fill.
	-- Capped at 1.3 spacings: a blob far bigger than its own cell clips away
	-- to nothing. The small floor keeps the chips at the tip from vanishing.
	local radius = math.clamp(farthest, 0.5, spacing * 1.3) * 0.9 * (0.75 + 0.25 * shareAt(seed.t))
	-- Below the float start the stones pull back from their neighbours, so the
	-- joints open into gaps and the base comes apart. The jitter keeps it from
	-- reading as a ring: every stone lets go at its own rate.
	local float = math.clamp((seed.t - FLOAT_START) / (1 - FLOAT_START), 0, 1)
	local jitter = 0.72 + 0.56 * hash(SEED * 107 + i)
	cellRadius[i] = radius * (1 - FLOAT_SHRINK * float ^ 0.5 * jitter)
end

-- Smooth value noise on a lattice, for the grain inside one material.
local function noise(p, scale, salt)
	local x, y, z = p[1] * scale, p[2] * scale, p[3] * scale
	local i, j, k = math.floor(x), math.floor(y), math.floor(z)
	local fx, fy, fz = x - i, y - j, z - k
	local ux, uy, uz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
	local function at(a, b, c)
		return hash(a * 157.0 + b * 311.0 + c * 613.0 + salt)
	end
	local function mix(a, b, t)
		return a + (b - a) * t
	end
	local x00 = mix(at(i, j, k), at(i + 1, j, k), ux)
	local x10 = mix(at(i, j + 1, k), at(i + 1, j + 1, k), ux)
	local x01 = mix(at(i, j, k + 1), at(i + 1, j, k + 1), ux)
	local x11 = mix(at(i, j + 1, k + 1), at(i + 1, j + 1, k + 1), ux)
	return mix(mix(x00, x10, uy), mix(x01, x11, uy), uz)
end

-- Each stone takes one material and keeps it: no blending inside a rock, no
-- gradient across one. A texel finds its stone through a lookup grid, built
-- once from the seeds, so the paint stays a table read per texel.
local MATERIALS = {
	-- grey rock, warm rock, pale rock, dark rock, topsoil, grass, moss
	{ 0.36, 0.34, 0.31 },
	{ 0.37, 0.33, 0.28 },
	{ 0.40, 0.39, 0.36 },
	{ 0.30, 0.29, 0.27 },
	{ 0.30, 0.26, 0.20 },
	{ 0.33, 0.29, 0.23 },
	{ 0.26, 0.29, 0.21 },
}

-- Below the deck, stones mostly stay rock; the top course gets soil and grass.
local DECK_MATERIALS = { 5, 5, 5, 6, 6, 7, 7, 1 }
local WALL_MATERIALS = { 1, 1, 2, 2, 4, 3, 7 }

for i, seed in seeds do
	local pick = if seed.t == 0 then DECK_MATERIALS else WALL_MATERIALS
	seed.material = pick[1 + math.floor(hash(SEED * 163 + i) * #pick)]
	-- A small tone shift per stone, so two stones of one material differ.
	seed.tone = 0.95 + 0.1 * hash(SEED * 167 + i)
end

-- The lookup grid: 1-stud cells holding the nearest stone. It is filled by
-- walking each stone's own box, so the build stays linear in stones rather
-- than in stones times cells.
local GRID = 1.0
local lows, highs = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
for _, seed in seeds do
	for k = 1, 3 do
		lows[k] = math.min(lows[k], seed[k] - 1)
		highs[k] = math.max(highs[k], seed[k] + 1)
	end
end
local counts = {}
for k = 1, 3 do
	counts[k] = math.ceil((highs[k] - lows[k]) / GRID) + 1
end
local index, closest = {}, {}
for i, seed in seeds do
	local reach = 5
	for ix = math.floor((seed[1] - reach - lows[1]) / GRID), math.ceil((seed[1] + reach - lows[1]) / GRID) do
		for iy = math.floor((seed[2] - reach - lows[2]) / GRID), math.ceil((seed[2] + reach - lows[2]) / GRID) do
			for iz = math.floor((seed[3] - reach - lows[3]) / GRID), math.ceil((seed[3] + reach - lows[3]) / GRID) do
				if ix < 0 or iy < 0 or iz < 0 or ix >= counts[1] or iy >= counts[2] or iz >= counts[3] then
					continue
				end
				local x, y, z = lows[1] + (ix + 0.5) * GRID, lows[2] + (iy + 0.5) * GRID, lows[3] + (iz + 0.5) * GRID
				local dx, dy, dz = seed[1] - x, seed[2] - y, seed[3] - z
				local d = dx * dx + dy * dy + dz * dz
				local at = ix + counts[1] * (iy + counts[2] * iz)
				if not closest[at] or d < closest[at] then
					closest[at], index[at] = d, i
				end
			end
		end
	end
end

local function stoneAt(x, y, z): number
	local ix = math.floor((x - lows[1]) / GRID)
	local iy = math.floor((y - lows[2]) / GRID)
	local iz = math.floor((z - lows[3]) / GRID)
	if ix < 0 or iy < 0 or iz < 0 or ix >= counts[1] or iy >= counts[2] or iz >= counts[3] then
		return 1
	end
	return index[ix + counts[1] * (iy + counts[2] * iz)] or 1
end

local function material(px, py, pz, _nx, _ny, _nz)
	local seed = seeds[stoneAt(px, py, pz)]
	local colour = MATERIALS[seed.material]
	-- Grain is the stone's own material, not a second one: a small tonal shift
	-- inside the colour it already has.
	local grain = 0.9 + 0.2 * noise({ px, py, pz }, 0.8, 5.1)
	local tone = seed.tone * grain
	return colour[1] * tone, colour[2] * tone, colour[3] * tone
end

-- Chunks: the surface is cut into sectors and height bands, each its own part
-- with a 1024 texture. Cutting by stone rather than by face keeps every cell's
-- seam inside one part, so the fitting survives the split, and the islands of
-- the unwrap stay whole.
local SECTORS = 6

local function chunkOf(seed): number
	if seed.t == 0 then
		return 0
	end
	local angle = math.atan2(seed[2], seed[1]) + math.pi
	local sector = math.floor(angle / TAU * SECTORS) % SECTORS
	local band = if seed.t < 0.45 then 1 else 2
	return 1 + sector + SECTORS * (band - 1)
end

local function buildRocks(mesh, chunk)
	for i, seed in seeds do
		if chunkOf(seed) ~= chunk then
			continue
		end
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
		-- The flat spots, cut while the stone is still free-standing. They are
		-- biased to the exposed side of the stone: a facet that cuts across the
		-- cell's own bisectors would leave a gap the core shows through.
		local out = seed.out
		-- Deck stones get no facet cuts: their top is the flat cap, and facets
		-- would break it into a fan of small faces.
		for k = 1, (if seed.t == 0 then 0 else ROCK_FACETS) do
			local n = normalize({
				out[1] + 1.2 * (hash(SEED * 31 + i * 13 + k * 7.1) - 0.5),
				out[2] + 1.2 * (hash(SEED * 17 + i * 13 + k * 3.3) - 0.5),
				out[3] + 1.2 * (hash(SEED * 5 + i * 13 + k * 11.7) - 0.5),
			})
			local reach = 0.86 + 0.11 * hash(SEED * 41 + i * 13 + k * 5.9)
			tris = clip(tris, { n[1], n[2], n[3], dot(n, seed) + reach * radius })
		end
		-- Cut every stone flat at its cap height: the deck and the top wall row
		-- share the plane, so the top of the island is a mosaic of flat tops.
		tris = clip(tris, { 0, 0, 1, seed.capZ })
		-- The fit: cut against every nearby seed, so neighbours share planes.
		for j, other in seeds do
			-- A falling rock is not fitted to anything: it is a free boulder.
			if j ~= i and not seed.floating then
				local dx, dy, dz = other[1] - seed[1], other[2] - seed[2], other[3] - seed[3]
				local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
				if distance < REACH and distance > 1e-6 then
					local n = { dx / distance, dy / distance, dz / distance }
					-- The power plane: the midpoint shifts by the weight
					-- difference, so a heavy seed pushes it away from itself.
					local seedSq = seed[1] ^ 2 + seed[2] ^ 2 + seed[3] ^ 2
					local otherSq = other[1] ^ 2 + other[2] ^ 2 + other[3] ^ 2
					-- The midpoint plane sits (otherSq - seedSq) / 2d from the
					-- origin; the weight only shifts it along n. Clamping the
					-- whole constant instead would drag rim cells' planes back
					-- to the origin and cut the cell away entirely.
					local midpoint = (otherSq - seedSq) / (2 * distance)
					local shift = (seed.weight - other.weight) / (2 * distance)
					shift = math.clamp(shift, -0.32 * distance, 0.32 * distance)
					tris = clip(tris, { n[1], n[2], n[3], midpoint + shift })
				end
			end
		end
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
	-- Weld so the shading can run smooth over each stone; the crease angle in
	-- part() keeps the cut faces and the seams sharp. A chunked build gets its
	-- own weld per chunk instead, so the recorder is skipped.
	if mesh.weld then
		mesh:weld(1e-4)
	end
end

-- The upper half of the wall and the deck take the wide wear band; the stones
-- that fall away underneath take a narrow one, because they are smaller.
for chunk = 0, SECTORS * 2 do
	local edge = if chunk <= SECTORS then 0.55 else 0.3
	part("Island_" .. chunk, nil, MATERIALS[1], function(mesh)
		buildRocks(mesh, chunk)
	end, nil, material, 1024, nil, true, edge, 2.0, 1.4, 2.4)
	-- Chunks of one island share a group, so a seam between two of them is a
	-- crease the bake knows belongs to the island, not a dark edge.
	parts[#parts].group = "Island"
end

finishParts()
