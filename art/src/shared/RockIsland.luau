-- Rock Island: the shared generator behind Arena, Yard, Pad and Market Island.
-- A fractured shell: one continuous dark core, the wall profile (shareAt /
-- wallAt) set back by CORE_INSET and hanging below the rim, and over it a
-- shell of separate, chunky Voronoi shards. The seeds are scattered over the
-- surface and each shard is the set of points nearer its seed than any other
-- (a power diagram), so a shard carries round the rim instead of the pattern
-- restarting at a seam. Every cell is inset towards its own centroid by half
-- a gap, so real seams open down to the core; the shard then gets an outer
-- surface pushed out along its normals (with varied proudness and a little
-- lean), an inner surface SHARD_THICKNESS behind it, and a side wall along
-- every boundary edge. Underside shards hang lower than wall ones. The top is
-- a separate continuous cap with an overhanging lip, flat or shaped by the
-- item, so it always covers the core and the shard tops.
--
-- The item sets, before including this:
--   RADIUS        the island's radius;
--   ROCK_SCALE    how many times the base rock size its rocks are;
--   outlineScale  the outline as a radius scale per angle;
--   ROCK_BULGE    optionally, how many times the base bulge its rocks stand
--                 out (ROCK_SCALE if not set); it now sets the shard
--                 thickness, from 3.5 to 5 studs;
--   islandTop     optionally, a shaped top instead of a flat one:
--                 { radii, height, octagon }, rings at octagon radii `radii`
--                 (outermost first), each at height(radius), measured with
--                 octagon(angle) as the radius scale.
useTexelDensity(16)
local CAP_TOP = 0.7
local WALL_REACH = 0.86
-- The body keeps the Island Rocks test island's proportions (16 deep at
-- radius 14), so a big island is as deep for its size as a small one.
local PROPORTION = RADIUS / 14
local PROFILE_DEPTH, HALF_DEPTH = 16 * PROPORTION, 4 * PROPORTION
local UNDERSIDE_SHARE = 0.18
local RELIEF = if ROCK_BULGE ~= nil then ROCK_BULGE else ROCK_SCALE
-- The shards' cells: their base size across, how far their sizes spread, and
-- how small the smallest cell is against the largest one its zone allows.
local ROCK = 5.0 * ROCK_SCALE
local SIZE_SPREAD = 0.9
local MIN_SHARE = 0.65
local TOP_SIZE, BOTTOM_SIZE = 1.3, 0.8
-- How sharply the size falls off going down: the size eases from TOP_SIZE to
-- BOTTOM_SIZE along (1 - depth)^SIZE_CURVE.
local SIZE_CURVE = 3
-- The tip is one cell covering the bottom out to TIP_SHARE of the underside's
-- rim, so the centre of the grid is a single clean shard.
local TIP_SHARE = 0.5
-- The fractured shell's tuning. GAP is the width of the seam between two
-- shards, PUSH how far a shard stands out, and SHARD_THICKNESS how far its
-- inner surface sits behind its outer one. CORE_INSET sets the dark core back
-- from the profile, and CORE_DROP how far it hangs below the bottom rim.
local GAP = math.clamp(0.06 * ROCK, 0.6, 2.2)
local PUSH = math.clamp(2 + 0.06 * ROCK, 2, 5)
local SHARD_THICKNESS = math.clamp(3.5 + 0.15 * (RELIEF - 1), 3.5, 5)
local CORE_INSET = 1.8
local CORE_DROP = 0.18 * PROFILE_DEPTH
local CORE_TOP_INSET = 0.35
-- The top's overhanging lip: how far down it drops, how far it flares out,
-- and how far it reaches back in under the shard tops for its underside.
local TOP_SKIRT, TOP_FLARE, TOP_LIP = 1.6, 0.9, 1.5
-- The shard tops stay on the profile for TOP_FADE studs below the cap, so
-- they tuck in under the lip instead of poking through it.
local TOP_FADE = 1.5
-- Below DOWN_FROM of the way down the wall, a shard pushes straight down
-- rather than out along the wall, so the shards near the bottom stand off the
-- underside instead of flaring the island's silhouette.
local DOWN_FROM = 0.55
-- How much each shard's texture varies from its neighbours': TOP_SPREAD at
-- the rim, easing to BOTTOM_SPREAD at the bottom.
local TOP_SPREAD, BOTTOM_SPREAD = 2.0, 0.5
-- How far seams wander: two octaves of noise sized to the shards.
local SEAM_WANDER = 0.09 * ROCK
-- The surface grid: samples round the island, rows down the wall and rings in
-- across the underside, finer on bigger islands up to a limit.
local ANGLES = math.clamp(math.round(96 * PROPORTION), 96, 384)
local WALL_ROWS = math.clamp(math.round(36 * PROPORTION), 36, 120)
local UNDER_ROWS = math.clamp(math.round(30 * PROPORTION), 30, 90)
local ROCK_COLOUR = { 0.36, 0.33, 0.28 }
local CORE_COLOUR = { 0.1, 0.09, 0.08 }

local R0 = RADIUS * WALL_REACH
local RIM_Z = CAP_TOP - PROFILE_DEPTH

local function random(k: number): number
	local s = math.sin(k * 12.9898 + 4.1414) * 43758.5453
	return s - math.floor(s)
end

local function sub(a: { number }, b: { number }): { number }
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function dot(a: { number }, b: { number }): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function cross(a: { number }, b: { number }): { number }
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

-- The profile's share of the reach, `depth` studs below the top rim: it halves
-- every HALF_DEPTH studs and levels out at UNDERSIDE_SHARE.
local function shareAt(depth: number): number
	return UNDERSIDE_SHARE + (1 - UNDERSIDE_SHARE) * 2 ^ (-depth / HALF_DEPTH)
end

-- The profile's point at `angle` and `depth`.
local function wallAt(angle: number, depth: number): { number }
	local r = R0 * outlineScale(angle) * shareAt(depth)
	return { r * math.cos(angle), r * math.sin(angle), CAP_TOP - depth }
end

-- The outward normal of the profile at `angle` and `depth`, from its tangents.
local function wallNormal(angle: number, depth: number): { number }
	local e = 1e-3
	local along = sub(wallAt(angle + e, depth), wallAt(angle - e, depth))
	local down = sub(wallAt(angle, depth + e), wallAt(angle, depth - e))
	local n = cross(along, down)
	local length = math.sqrt(dot(n, n))
	n = { n[1] / length, n[2] / length, n[3] / length }
	if dot(n, { math.cos(angle), math.sin(angle), 0 }) < 0 then
		n = { -n[1], -n[2], -n[3] }
	end
	return n
end

-- Which way a shard at `p` pushes: out along the wall near the top, turning
-- straight down toward the underside, and straight down under the island.
local function pushAt(p: { number }): { number }
	if p[3] <= RIM_Z + 1e-6 then return { 0, 0, -1 } end
	local angle = math.atan2(p[2], p[1])
	local depth = math.clamp(CAP_TOP - p[3], 0, PROFILE_DEPTH)
	local n = wallNormal(angle, depth)
	local t = math.clamp((depth / PROFILE_DEPTH - DOWN_FROM) / (1 - DOWN_FROM), 0, 1)
	local d = { n[1] * (1 - t), n[2] * (1 - t), n[3] * (1 - t) - t }
	local length = math.max(math.sqrt(dot(d, d)), 1e-6)
	return { d[1] / length, d[2] / length, d[3] / length }
end

-- The seeds: one set over the whole surface, each a 3D point with a weight (the
-- square of its size), so the cells are a power diagram and bigger shards claim
-- more of the surface.
local seeds = {}
local function addSeed(p: { number }, key: number, scale: number)
	local largest = scale * ROCK / 2 * math.exp(SIZE_SPREAD)
	local size = largest * (MIN_SHARE + (1 - MIN_SHARE) * random(key))
	table.insert(seeds, {
		p = p,
		weight = size * size,
		size = size,
		key = key,
		tint = 0.88 + 0.24 * random(key + 9),
	})
end
do
	-- Down the wall: a jittered grid in angle and depth.
	local cols = math.max(3, math.round(TAU * R0 / ROCK))
	local rows = math.max(1, math.round(PROFILE_DEPTH / ROCK))
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local key = (row * cols + col) * 7 + 1
			local angle = (col + 0.5 * (row % 2) + 0.38 * (2 * random(key + 1) - 1)) / cols * TAU
			local depth = (row + 0.5 + 0.3 * (2 * random(key + 2) - 1)) * PROFILE_DEPTH / rows
			depth = math.clamp(depth, 0.2, PROFILE_DEPTH - 0.2)
			addSeed(wallAt(angle, depth), key + 3, BOTTOM_SIZE + (TOP_SIZE - BOTTOM_SIZE) * (1 - depth / PROFILE_DEPTH) ^ SIZE_CURVE)
		end
	end
	-- Across the underside: a jittered grid in its plane, kept inside the rim.
	local reach = R0 * 1.2
	local n = 0
	for gx = -reach, reach, ROCK * 0.8 do
		for gy = -reach, reach, ROCK * 0.8 do
			n += 1
			local x = gx + 0.35 * ROCK * (2 * random(n * 2 + 11) - 1)
			local y = gy + 0.35 * ROCK * (2 * random(n * 2 + 12) - 1)
			local rim = R0 * outlineScale(math.atan2(y, x)) * shareAt(PROFILE_DEPTH)
			if math.sqrt(x * x + y * y) < 0.9 * rim then
				addSeed({ x, y, RIM_Z }, n * 3 + 17, BOTTOM_SIZE)
			end
		end
	end
	-- The tip is one shard: a single seed on the axis that claims the whole
	-- bottom, with the underside's seeds kept only around its edge.
	local tipSize = TIP_SHARE * R0 * shareAt(PROFILE_DEPTH)
	table.insert(seeds, { p = { 0, 0, RIM_Z }, weight = tipSize * tipSize, size = tipSize, key = 999, tint = 1 })
	for i = #seeds, 1, -1 do
		local seed = seeds[i]
		if seed.key ~= 999 and seed.p[3] <= RIM_Z + 1e-6 and math.sqrt(seed.p[1] ^ 2 + seed.p[2] ^ 2) < TIP_SHARE * R0 * shareAt(PROFILE_DEPTH) then
			table.remove(seeds, i)
		end
	end
end

-- Seams wander: shards claim the surface in a gently warped copy of it, so the
-- seam between two shards bends and wobbles instead of running straight.
local function warp(p: { number }): { number }
	local s = 3 / ROCK
	local w = {}
	for k = 1, 3 do
		local o = k * 17.3
		local broad = math.noise(p[1] * s + o, p[2] * s, p[3] * s)
		local fine = math.noise(p[1] * s * 3, p[2] * s * 3 + o, p[3] * s * 3)
		w[k] = p[k] + SEAM_WANDER * (broad + 0.4 * fine)
	end
	return w
end

-- The shard owning `p` in the warped space.
local function ownerAt(point: { number })
	local p = warp(point)
	local best, bestPower = seeds[1], math.huge
	for _, seed in seeds do
		local d = sub(p, seed.p)
		local power = dot(d, d) - seed.weight
		if power < bestPower then
			bestPower, best = power, seed
		end
	end
	return best
end

-- Keeps the part of a polygon on the `keep` side of the bisector between two
-- seeds, tested in the warped space. Both shards on a seam clip the same edges
-- at the same points, so the seam is shared.
local function clipTo(poly: { { number } }, keep, other): { { number } }
	local n = sub(other.p, keep.p)
	local c = (dot(other.p, other.p) - other.weight - dot(keep.p, keep.p) + keep.weight) / 2
	local out = {}
	local count = #poly
	for i = 1, count do
		local a, b = poly[i], poly[i % count + 1]
		local da, db = dot(n, warp(a)) - c, dot(n, warp(b)) - c
		if da <= 0 then table.insert(out, a) end
		if (da < 0 and db > 0) or (da > 0 and db < 0) then
			local t = da / (da - db)
			table.insert(out, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t })
		end
	end
	return out
end

-- The shards' paint: every shard takes its seed's stratum, tint and hue, so a
-- shard reads as one piece of rock against its neighbours.
local function shardPaint(seed)
	return function(x: number, y: number, z: number)
		local depth = math.clamp(CAP_TOP - z, 0, PROFILE_DEPTH)
		local spread = TOP_SPREAD + (BOTTOM_SPREAD - TOP_SPREAD) * depth / PROFILE_DEPTH
		return islandPaint(x, y, -depth, seed.key, seed.tint, spread, true)
	end
end

-- The core is the same rock, kept dark: it sits in shadow behind the shell and
-- is only seen through the seams and around the bottom point.
local function corePaint(x: number, y: number, z: number)
	local depth = math.clamp(CAP_TOP - z, 0.5, PROFILE_DEPTH)
	local r, g, b = islandPaint(x, y, -depth, 991, 0.8, 0.25, true)
	local k = 0.34 + 0.10 * (1 - depth / PROFILE_DEPTH)
	return r * k, g * k, b * k
end

-- The cap is walkable ground: even, topsoil-toned paint with the island's grit.
local function topPaint(x: number, y: number, _z: number)
	return islandPaint(x, y, 0)
end

-- The shell and its shading are cached under a key hashing every line above
-- "-- cached above", so changes below it skip the rebuild.
local shell = model.cached(CACHE_KEY, function()
	-- The surface grid: rows down the wall, then rings in across the underside.
	-- Every grid point knows its shard, so each triangle can be cut per owner.
	local ROWS = WALL_ROWS + UNDER_ROWS
	local grid, owners = {}, {}
	for k = 0, ROWS do
		grid[k], owners[k] = {}, {}
		for j = 0, ANGLES - 1 do
			local angle = TAU * j / ANGLES
			local p
			if k <= WALL_ROWS then
				p = wallAt(angle, PROFILE_DEPTH * k / WALL_ROWS)
			else
				local rim = R0 * outlineScale(angle) * shareAt(PROFILE_DEPTH)
				local r = rim * (1 - (k - WALL_ROWS) / UNDER_ROWS)
				p = { r * math.cos(angle), r * math.sin(angle), RIM_Z }
			end
			grid[k][j] = p
			owners[k][j] = (ownerAt(p))
		end
	end

	-- Each shard's surface is collected as its own little mesh of positions
	-- and outward-wound triangles. Points are shared inside one shard by
	-- position, but never between shards: every shard is a separate part.
	local cells = {}
	local function cellFor(seed)
		local cell = cells[seed]
		if not cell then
			cell = { seed = seed, pos = {}, byKey = {}, tris = {} }
			cells[seed] = cell
		end
		return cell
	end
	local function cellPoint(cell, p)
		local key = `{math.round(p[1] * 1e4)}_{math.round(p[2] * 1e4)}_{math.round(p[3] * 1e4)}`
		local id = cell.byKey[key]
		if not id then
			table.insert(cell.pos, p)
			id = #cell.pos
			cell.byKey[key] = id
		end
		return id
	end

	-- One triangle of the grid: cut into a piece per shard its corners belong
	-- to, then fan each piece into the owning shard.
	local function emit(a: { number }, b: { number }, c: { number }, oa, ob, oc)
		local u, v = sub(b, a), sub(c, a)
		local face = cross(u, v)
		if dot(face, face) < 1e-12 then return end
		local centre = { (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3, (a[3] + b[3] + c[3]) / 3 }
		local outward = pushAt(centre)
		local present = { oa }
		if ob ~= oa then table.insert(present, ob) end
		if oc ~= oa and oc ~= ob then table.insert(present, oc) end
		for _, owner in present do
			local poly = { a, b, c }
			for _, other in present do
				if other ~= owner then poly = clipTo(poly, owner, other) end
			end
			if #poly < 3 then continue end
			local cell = cellFor(owner)
			local ids = {}
			for i, p in poly do
				ids[i] = cellPoint(cell, p)
			end
			for i = 2, #poly - 1 do
				local ia, ib, ic = ids[1], ids[i], ids[i + 1]
				if ia ~= ib and ib ~= ic and ia ~= ic then
					local pa, pb, pc = cell.pos[ia], cell.pos[ib], cell.pos[ic]
					local normal = cross(sub(pb, pa), sub(pc, pa))
					if dot(normal, normal) > 1e-12 then
						if dot(normal, outward) < 0 then ib, ic = ic, ib end
						table.insert(cell.tris, { ia, ib, ic })
					end
				end
			end
		end
	end

	for k = 0, ROWS - 1 do
		for j = 0, ANGLES - 1 do
			local l = (j + 1) % ANGLES
			emit(grid[k][j], grid[k + 1][j], grid[k + 1][l], owners[k][j], owners[k + 1][j], owners[k + 1][l])
			emit(grid[k][j], grid[k + 1][l], grid[k][l], owners[k][j], owners[k + 1][l], owners[k][l])
		end
	end

	-- The dark core: the profile set back CORE_INSET, from just under the cap
	-- down past the bottom rim to a jagged point. It is one continuous body,
	-- painted dark, and every seam between the shards opens onto it.
	local CORE_ANGLES = math.clamp(math.round(64 * PROPORTION), 64, 192)
	local CORE_ROWS = 28
	local corePositions, coreFaces = {}, {}
	local function coreVertex(x: number, y: number, z: number)
		table.insert(corePositions, { x, y, z })
		return #corePositions
	end
	local function coreTri(a: number, b: number, c: number, rx: number, ry: number, rz: number)
		local pa, pb, pc = corePositions[a], corePositions[b], corePositions[c]
		local ux, uy, uz = pb[1] - pa[1], pb[2] - pa[2], pb[3] - pa[3]
		local vx, vy, vz = pc[1] - pa[1], pc[2] - pa[2], pc[3] - pa[3]
		local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
		if nx * rx + ny * ry + nz * rz < 0 then b, c = c, b end
		table.insert(coreFaces, { a, b, c })
	end
	do
		local rings = {}
		for k = 0, CORE_ROWS do
			local depth = CORE_TOP_INSET + (PROFILE_DEPTH - CORE_TOP_INSET) * k / CORE_ROWS
			local ring = {}
			for j = 0, CORE_ANGLES - 1 do
				local angle = TAU * j / CORE_ANGLES
				local r = R0 * outlineScale(angle) * shareAt(depth) - CORE_INSET
				ring[j + 1] = coreVertex(r * math.cos(angle), r * math.sin(angle), CAP_TOP - depth)
			end
			rings[k + 1] = ring
		end
		for k = 1, CORE_ROWS do
			local upper, lower = rings[k], rings[k + 1]
			for j = 1, CORE_ANGLES do
				local l = j % CORE_ANGLES + 1
				local angle = TAU * (j - 0.5) / CORE_ANGLES
				local rx, ry = math.cos(angle), math.sin(angle)
				coreTri(upper[j], upper[l], lower[l], rx, ry, 0)
				coreTri(upper[j], lower[l], lower[j], rx, ry, 0)
			end
		end
		-- The bottom: two jagged rings in from the lower rim, then a point.
		local bottom = rings[CORE_ROWS + 1]
		local function bottomRing(scale: number, drop: number, jag: number)
			local ring = {}
			for j = 0, CORE_ANGLES - 1 do
				local angle = TAU * j / CORE_ANGLES
				local p = corePositions[bottom[j + 1]]
				local r = math.sqrt(p[1] * p[1] + p[2] * p[2])
				local wobble = 1 + jag * (0.6 * math.noise(angle * 2.3 + 9, 0.5, 0.5) + 0.4 * math.noise(angle * 5.7 + 31, 1.5, 2.5))
				local z = RIM_Z - drop * (1 + 0.12 * math.noise(angle * 3.1 + 5, 0.5, 1.5))
				ring[j + 1] = coreVertex(r * scale * wobble * math.cos(angle), r * scale * wobble * math.sin(angle), z)
			end
			return ring
		end
		local lowA = bottomRing(0.62, 0.10 * PROFILE_DEPTH, 0.12)
		local lowB = bottomRing(0.30, 0.15 * PROFILE_DEPTH, 0.18)
		local apex = coreVertex(0.02 * R0 * math.cos(2.1), 0.02 * R0 * math.sin(2.1), RIM_Z - CORE_DROP)
		for j = 1, CORE_ANGLES do
			local l = j % CORE_ANGLES + 1
			coreTri(bottom[j], lowA[j], lowA[l], 0, 0, -1)
			coreTri(bottom[j], lowA[l], bottom[l], 0, 0, -1)
			coreTri(lowA[j], lowB[j], lowB[l], 0, 0, -1)
			coreTri(lowA[j], lowB[l], lowA[l], 0, 0, -1)
			coreTri(lowB[j], apex, lowB[l], 0, 0, -1)
		end
	end
	chunkedPart("Core", nil, CORE_COLOUR, function(mesh)
		local handles = {}
		for _, face in coreFaces do
			local verts = {}
			for i, v in face do
				if not handles[v] then
					local p = corePositions[v]
					handles[v] = mesh:vertex(p[1], p[2], p[3])
				end
				verts[i] = handles[v]
			end
			mesh:face(verts)
		end
	end, 30, corePaint, true)

	-- One part per cell: inset towards its centre, outer surface pushed out,
	-- inner surface set back, and a side quad on every boundary edge.
	local function shardGeometry(cell)
		local count = #cell.pos
		if count == 0 or #cell.tris == 0 then return nil end
		-- Count undirected edges and remember each vertex's neighbours.
		local edgeCount, neighbours = {}, {}
		for i = 1, count do
			neighbours[i] = {}
		end
		for _, tri in cell.tris do
			for k = 1, 3 do
				local i, j = tri[k], tri[k % 3 + 1]
				local a, b = i, j
				if a > b then a, b = b, a end
				local key = a * 1048576 + b
				edgeCount[key] = (edgeCount[key] or 0) + 1
				table.insert(neighbours[i], j)
				table.insert(neighbours[j], i)
			end
		end
		-- Boundary vertices move the full half-gap; the rings behind them move
		-- part of the way, so the shard edge eases in instead of folding over.
		local weight = {}
		for i = 1, count do
			weight[i] = 0
		end
		for _, tri in cell.tris do
			for k = 1, 3 do
				local i, j = tri[k], tri[k % 3 + 1]
				local a, b = i, j
				if a > b then a, b = b, a end
				if edgeCount[a * 1048576 + b] == 1 then
					weight[i] = 1
					weight[j] = 1
				end
			end
		end
		for _ = 1, 2 do
			local next = table.clone(weight)
			for i = 1, count do
				local best = weight[i]
				for _, j in neighbours[i] do
					local w = weight[j] * 0.6
					if w > best then best = w end
				end
				next[i] = best
			end
			weight = next
		end
		-- The cell's centre, weighted by triangle area.
		local cx, cy, cz, total = 0, 0, 0, 0
		for _, tri in cell.tris do
			local a, b, c = cell.pos[tri[1]], cell.pos[tri[2]], cell.pos[tri[3]]
			local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
			local vx, vy, vz = c[1] - a[1], c[2] - a[2], c[3] - a[3]
			local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
			local area = math.sqrt(nx * nx + ny * ny + nz * nz) * 0.5
			if area > 0 then
				cx += (a[1] + b[1] + c[1]) / 3 * area
				cy += (a[2] + b[2] + c[2]) / 3 * area
				cz += (a[3] + b[3] + c[3]) / 3 * area
				total += area
			end
		end
		if total <= 0 then return nil end
		local centre = { cx / total, cy / total, cz / total }
		local inset = {}
		for i = 1, count do
			local p = cell.pos[i]
			local dx, dy, dz = centre[1] - p[1], centre[2] - p[2], centre[3] - p[3]
			local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
			local move = math.min(GAP * 0.5 * weight[i], 0.45 * distance)
			local t = if distance > 1e-9 then move / distance else 0
			inset[i] = { p[1] + dx * t, p[2] + dy * t, p[3] + dz * t }
		end
		-- Smooth vertex normals on the inset surface, used to offset both sides.
		local normals = {}
		for i = 1, count do
			normals[i] = { 0, 0, 0 }
		end
		for _, tri in cell.tris do
			local a, b, c = inset[tri[1]], inset[tri[2]], inset[tri[3]]
			local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
			local vx, vy, vz = c[1] - a[1], c[2] - a[2], c[3] - a[3]
			local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
			for k = 1, 3 do
				local n = normals[tri[k]]
				n[1] += nx
				n[2] += ny
				n[3] += nz
			end
		end
		for i = 1, count do
			local n = normals[i]
			local length = math.sqrt(n[1] * n[1] + n[2] * n[2] + n[3] * n[3])
			if length < 1e-9 then
				local fallback = pushAt(inset[i])
				normals[i] = { fallback[1], fallback[2], fallback[3] }
			else
				n[1], n[2], n[3] = n[1] / length, n[2] / length, n[3] / length
			end
		end
		-- Varied proudness, a little sideways lean towards the bottom, and a
		-- hang for the shards under the island.
		local zMin, zMax = math.huge, -math.huge
		for i = 1, count do
			zMin = math.min(zMin, inset[i][3])
			zMax = math.max(zMax, inset[i][3])
		end
		local span = math.max(zMax - zMin, 0.5)
		local proud = 0.75 + 0.5 * random(cell.seed.key + 41)
		local leanAngle = TAU * random(cell.seed.key + 42)
		local lean = (0.08 + 0.20 * random(cell.seed.key + 43)) * PUSH * proud
		local leanX, leanY = math.cos(leanAngle) * lean, math.sin(leanAngle) * lean
		local under = centre[3] <= RIM_Z + 0.5
		local hang = if under then PROFILE_DEPTH * (0.04 + 0.10 * random(cell.seed.key + 44)) else 0
		local outer, inner = {}, {}
		for i = 1, count do
			local p, n = inset[i], normals[i]
			local depth = CAP_TOP - p[3]
			local topFade = math.clamp(depth / TOP_FADE, 0, 1)
			local rel = math.clamp((zMax - p[3]) / span, 0, 1)
			local push = PUSH * proud * (0.78 + 0.22 * rel) * topFade
			outer[i] = {
				p[1] + n[1] * push + leanX * rel,
				p[2] + n[2] * push + leanY * rel,
				p[3] + n[3] * push - hang,
			}
			inner[i] = {
				p[1] - n[1] * SHARD_THICKNESS,
				p[2] - n[2] * SHARD_THICKNESS,
				p[3] - n[3] * SHARD_THICKNESS,
			}
		end
		-- Every edge with only one face in the shard is a seam edge: close it
		-- with a side wall from the outer surface down to the inner one.
		local sides = {}
		for _, tri in cell.tris do
			for k = 1, 3 do
				local i, j = tri[k], tri[k % 3 + 1]
				local a, b = i, j
				if a > b then a, b = b, a end
				if edgeCount[a * 1048576 + b] == 1 then
					table.insert(sides, { i, j })
				end
			end
		end
		return { outer = outer, inner = inner, sides = sides }
	end

	for n, seed in seeds do
		local cell = cells[seed]
		if cell then
			local geometry = shardGeometry(cell)
			if geometry then
				part(`Rock{n}`, nil, ROCK_COLOUR, function(mesh)
					local outerHandles, innerHandles = {}, {}
					for i, p in geometry.outer do
						outerHandles[i] = mesh:vertex(p[1], p[2], p[3])
					end
					for i, p in geometry.inner do
						innerHandles[i] = mesh:vertex(p[1], p[2], p[3])
					end
					for _, tri in cell.tris do
						mesh:face({ outerHandles[tri[1]], outerHandles[tri[2]], outerHandles[tri[3]] })
					end
					for _, tri in cell.tris do
						mesh:face({ innerHandles[tri[3]], innerHandles[tri[2]], innerHandles[tri[1]] })
					end
					for _, side in geometry.sides do
						local i, j = side[1], side[2]
						mesh:face({ outerHandles[i], innerHandles[i], innerHandles[j], outerHandles[j] })
					end
				end, 30, shardPaint(seed), nil, nil, true)
			end
		end
	end

	-- The top: one continuous walkable cap at CAP_TOP, following islandTop
	-- when the item shapes it, with a short flared skirt and a lip underside
	-- that overhang the shard tops all the way round.
	local TOP_ANGLES = math.clamp(math.round(96 * PROPORTION), 96, 384)
	local topPositions, topFaces = {}, {}
	local function topVertex(x: number, y: number, z: number)
		table.insert(topPositions, { x, y, z })
		return #topPositions
	end
	local function upFace(a: number, b: number, c: number)
		local pa, pb, pc = topPositions[a], topPositions[b], topPositions[c]
		local ux, uy, uz = pb[1] - pa[1], pb[2] - pa[2], pb[3] - pa[3]
		local vx, vy, vz = pc[1] - pa[1], pc[2] - pa[2], pc[3] - pa[3]
		local nz = ux * vy - uy * vx
		table.insert(topFaces, if nz >= 0 then { a, b, c } else { a, c, b })
	end
	local function downFace(a: number, b: number, c: number)
		local pa, pb, pc = topPositions[a], topPositions[b], topPositions[c]
		local ux, uy, uz = pb[1] - pa[1], pb[2] - pa[2], pb[3] - pa[3]
		local vx, vy, vz = pc[1] - pa[1], pc[2] - pa[2], pc[3] - pa[3]
		local nz = ux * vy - uy * vx
		table.insert(topFaces, if nz <= 0 then { a, b, c } else { a, c, b })
	end
	local function radialFace(a: number, b: number, c: number)
		local pa, pb, pc = topPositions[a], topPositions[b], topPositions[c]
		local ux, uy, uz = pb[1] - pa[1], pb[2] - pa[2], pb[3] - pa[3]
		local vx, vy, vz = pc[1] - pa[1], pc[2] - pa[2], pc[3] - pa[3]
		local nx, ny = uy * vz - uz * vy, uz * vx - ux * vz
		local mx, my = (pa[1] + pb[1] + pc[1]) / 3, (pa[2] + pb[2] + pc[2]) / 3
		table.insert(topFaces, if nx * mx + ny * my >= 0 then { a, b, c } else { a, c, b })
	end
	do
		local outer = {}
		for j = 0, TOP_ANGLES - 1 do
			local angle = TAU * j / TOP_ANGLES
			local r = R0 * outlineScale(angle)
			outer[j + 1] = topVertex(r * math.cos(angle), r * math.sin(angle), CAP_TOP)
		end
		local rings = { outer }
		if islandTop then
			for n = 1, #islandTop.radii do
				local radius = islandTop.radii[n]
				local height = islandTop.height(radius)
				local ring = {}
				for j = 0, TOP_ANGLES - 1 do
					local angle = TAU * j / TOP_ANGLES
					local r = math.min(radius * islandTop.octagon(angle), R0 * outlineScale(angle) - 0.3)
					ring[j + 1] = topVertex(r * math.cos(angle), r * math.sin(angle), height)
				end
				table.insert(rings, ring)
			end
		else
			for _, share in { 0.8, 0.6, 0.4, 0.2 } do
				local ring = {}
				for j = 0, TOP_ANGLES - 1 do
					local angle = TAU * j / TOP_ANGLES
					local r = R0 * outlineScale(angle) * share
					ring[j + 1] = topVertex(r * math.cos(angle), r * math.sin(angle), CAP_TOP)
				end
				table.insert(rings, ring)
			end
		end
		local centre = topVertex(0, 0, if islandTop then islandTop.height(0) else CAP_TOP)
		for r = 1, #rings - 1 do
			local a, b = rings[r], rings[r + 1]
			for j = 1, TOP_ANGLES do
				local l = j % TOP_ANGLES + 1
				upFace(a[j], a[l], b[l])
				upFace(a[j], b[l], b[j])
			end
		end
		local last = rings[#rings]
		for j = 1, TOP_ANGLES do
			local l = j % TOP_ANGLES + 1
			upFace(last[j], last[l], centre)
		end
		-- The skirt: from the cap's rim down and out to the flared bottom.
		local skirt = {}
		for j = 0, TOP_ANGLES - 1 do
			local angle = TAU * j / TOP_ANGLES
			local r = R0 * outlineScale(angle) + TOP_FLARE
			skirt[j + 1] = topVertex(r * math.cos(angle), r * math.sin(angle), CAP_TOP - TOP_SKIRT)
		end
		for j = 1, TOP_ANGLES do
			local l = j % TOP_ANGLES + 1
			radialFace(outer[j], skirt[j], skirt[l])
			radialFace(outer[j], skirt[l], outer[l])
		end
		-- The lip's underside, reaching back under the shard tops so no gap
		-- between cap and shell is open to the sky.
		local lip = {}
		for j = 0, TOP_ANGLES - 1 do
			local angle = TAU * j / TOP_ANGLES
			local r = math.max(R0 * outlineScale(angle) - TOP_LIP, 0)
			lip[j + 1] = topVertex(r * math.cos(angle), r * math.sin(angle), CAP_TOP - TOP_SKIRT)
		end
		for j = 1, TOP_ANGLES do
			local l = j % TOP_ANGLES + 1
			downFace(skirt[j], lip[j], lip[l])
			downFace(skirt[j], lip[l], skirt[l])
		end
	end
	chunkedPart("Top", nil, ROCK_COLOUR, function(mesh)
		local handles = {}
		for _, face in topFaces do
			local verts = {}
			for i, v in face do
				if not handles[v] then
					local p = topPositions[v]
					handles[v] = mesh:vertex(p[1], p[2], p[3])
				end
				verts[i] = handles[v]
			end
			mesh:face(verts)
		end
	end, 30, topPaint, true)

	-- Stronger highlights along the shard edges, and deeper contact shadows in
	-- the seams, than the default: every shard shades against every other one.
	local entries = table.clone(parts)
	local meshes = {}
	for _, entry in entries do
		table.insert(meshes, entry.mesh)
	end
	for _, entry in entries do
		entry.mesh:paintShading(entry.image, {
			highlight = 1.2,
			highlightRamp = 0.3,
			shadow = 0.9,
			gradient = GRADIENT,
			blend = 1,
			brushed = true,
			occluders = meshes,
			-- The island paint, cached under the item's key since its code is not hashed.
			paint = entry.paint,
			custom = entry.custom,
			salt = CACHE_KEY,
		})
	end
	table.clear(parts)
	return entries
end)
-- cached above

for _, entry in shell do
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
