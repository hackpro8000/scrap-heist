-- Rock Island: the shared generator behind Arena, Yard, Pad and Market Island,
-- the Island Rocks algorithm (items/IslandRocks.luau) sized per island. One
-- set of rocks covers the whole island, from the top rim down the wall, round
-- the bottom rim and in across the underside. The seeds are scattered in 3D on
-- the surface and each rock is the set of points nearer its seed than any
-- other (a power diagram, so bigger rocks claim more), so a rock carries round
-- the rim instead of the pattern restarting there. The surface is meshed as a
-- grid and every triangle is cut by the bisector planes between the seeds its
-- corners belong to, so the seams are exact and both rocks on a seam share it.
--
-- The item sets, before including this:
--   RADIUS        the island's radius;
--   ROCK_SCALE    how many times the base rock size its rocks are;
--   outlineScale  the outline as a radius scale per angle;
--   ROCK_BULGE    optionally, how many times the base bulge its rocks stand
--                 out (ROCK_SCALE if not set; 0 for a smooth body);
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
-- Rock spacing, scaled by the item's ROCK_SCALE, and how far a rock of base
-- size bulges out, scaled by its ROCK_BULGE. Rock sizes spread by
-- e^(SIZE_SPREAD * r) for r from -1 to 1, and are bigger near the top:
-- TOP_SIZE times the base size at the rim, easing to BOTTOM_SIZE.
local RELIEF = if ROCK_BULGE ~= nil then ROCK_BULGE else ROCK_SCALE
local ROCK, BULGE = 4.6 * ROCK_SCALE, 1.5 * RELIEF
local SIZE_SPREAD = 0.8
-- A rock's size runs from MIN_SHARE of the largest rock its zone allows up to
-- that largest size, so the smallest rock is always 80% of the biggest.
local MIN_SHARE = 0.8
local TOP_SIZE, BOTTOM_SIZE = 1.3, 0.8
-- How sharply the size falls off going down: the size eases from TOP_SIZE to
-- BOTTOM_SIZE along (1 - depth)^SIZE_CURVE, so the top stays near its maximum
-- and the drop comes lower down.
local SIZE_CURVE = 3
-- How deep each joint sits (scaling with the bulge, but never under the
-- base joint, so even a smooth body shows its seams), and how far from the
-- top rim the joint takes to reach that depth. The rim itself stays on the
-- profile. The joint's width is set below, from the grid.
local SEAM_DEPTH, SEAM_FADE = 0.2 * math.max(RELIEF, 1), 2.5
-- Below DOWN_FROM of the way down the wall, a rock pushes straight down rather
-- than out along the wall, so the rocks near the bottom stand off the underside
-- instead of flaring the island's silhouette.
local DOWN_FROM = 0.55
-- The tip is one rock covering the bottom out to TIP_SHARE of the underside's rim.
local TIP_SHARE = 0.5
-- How much of its crest a rock still stands off at its seams.
local REST = 0.45
-- How far the seams near the top merge: their dip is cut by MERGE_TOP at the
-- rim, easing back to full depth by the middle of the wall.
local MERGE_TOP = 1.0
-- How much of its bulge a rock keeps at the bottom: BOTTOM_BULGE of it, easing
-- in from the middle of the wall.
local BOTTOM_BULGE = 0.3
-- How much each rock's texture varies from its neighbours': TOP_SPREAD at the
-- rim, easing to BOTTOM_SPREAD at the bottom.
local TOP_SPREAD, BOTTOM_SPREAD = 2.0, 0.5
-- The surface grid: samples round the island, rows down the wall and rings in
-- across the underside, finer on bigger islands up to a limit.
local ANGLES = math.clamp(math.round(96 * PROPORTION), 96, 384)
local WALL_ROWS = math.clamp(math.round(36 * PROPORTION), 36, 120)
local UNDER_ROWS = math.clamp(math.round(30 * PROPORTION), 30, 90)
local ROCK_COLOUR = { 0.36, 0.33, 0.28 }

local R0 = RADIUS * WALL_REACH
local RIM_Z = CAP_TOP - PROFILE_DEPTH
-- The grid's spacing on the wall: the larger of its step round the island
-- and its step down the steep top of the wall. Each joint is at least
-- JOINT_STEPS of these wide, so the dip into a seam spans several vertices
-- either side and doesn't step where the seam crosses the grid at a slant.
local GRID_STEP = math.max(TAU * R0 * 1.1 / ANGLES, 2 * PROFILE_DEPTH / WALL_ROWS)
local JOINT_STEPS = 3
local JOINT_WIDTH = math.max(0.4 * math.max(RELIEF, 1), JOINT_STEPS * GRID_STEP)

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

-- Which way a rock at `p` pushes: out along the wall near the top, turning
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
-- square of its size), so the cells are a power diagram and bigger rocks claim
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
	-- The tip is one rock: a single seed on the axis that claims the whole
	-- bottom, with the underside's rocks kept only around its edge.
	local tipSize = TIP_SHARE * R0 * shareAt(PROFILE_DEPTH)
	table.insert(seeds, { p = { 0, 0, RIM_Z }, weight = tipSize * tipSize, size = tipSize, key = 999, tint = 1 })
	for i = #seeds, 1, -1 do
		local seed = seeds[i]
		if seed.key ~= 999 and seed.p[3] <= RIM_Z + 1e-6 and math.sqrt(seed.p[1] ^ 2 + seed.p[2] ^ 2) < TIP_SHARE * R0 * shareAt(PROFILE_DEPTH) then
			table.remove(seeds, i)
		end
	end
end

-- Seams wander: rocks claim the surface in a gently warped copy of it, so the
-- seam between two rocks bends and wobbles instead of running straight. Two
-- octaves of noise sized to the rocks, SEAM_WANDER studs at most.
local SEAM_WANDER = 0.09 * ROCK
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

-- The rock owning `p`, and how far `p` lies from that rock's nearest seam: the
-- distance to the bisector plane with the runner-up, both in the warped space.
local function ownerAt(point: { number })
	local p = warp(point)
	local best, second = seeds[1], seeds[2]
	local bestPower, secondPower = math.huge, math.huge
	for _, seed in seeds do
		local d = sub(p, seed.p)
		local power = dot(d, d) - seed.weight
		if power < bestPower then
			bestPower, secondPower = power, bestPower
			best, second = seed, best
		elseif power < secondPower then
			secondPower, second = power, seed
		end
	end
	local span = math.max(math.sqrt(dot(sub(second.p, best.p), sub(second.p, best.p))), 1e-6)
	return best, (secondPower - bestPower) / (2 * span)
end

-- How far a rock's surface stands off the island at `p`: a crest over the
-- rock's middle falling to a narrow joint at the seam. The top rim keeps its
-- profile, so the top meets the rocks without a lip.
local function standoff(p: { number }, seed, edge: number): number
	local depth = CAP_TOP - p[3]
	local lower = 1 - (1 - BOTTOM_BULGE) * math.clamp((depth / PROFILE_DEPTH - DOWN_FROM) / (1 - DOWN_FROM), 0, 1)
	local crest = BULGE * math.sqrt(seed.size / (ROCK / 2)) * lower
	local t = math.clamp(edge / (0.5 * seed.size), 0, 1)
	-- Eased in, so the joint's sides curve into the rock instead of kinking.
	local joint = math.clamp(edge / JOINT_WIDTH, 0, 1)
	joint = joint * joint * (3 - 2 * joint)
	local fade = math.clamp(depth / SEAM_FADE, 0, 1)
	-- Every rock stands off by at least REST of its crest, so the seams sit on
	-- the island's body rather than cutting into it.
	local merge = 1 - MERGE_TOP * math.clamp(1 - depth / (PROFILE_DEPTH / 2), 0, 1)
	-- The joint runs deeper and shallower along the seam, 40% to 160% of SEAM_DEPTH.
	local s = 5 / ROCK
	local uneven = 1 + 0.6 * math.noise(p[1] * s + 41, p[2] * s, p[3] * s)
	local h = crest * (REST + (1 - REST) * math.sin(math.pi / 2 * t)) - SEAM_DEPTH * uneven * fade * merge * (1 - joint)
	return h * math.clamp(depth / 1.5, 0, 1)
end

-- Keeps the part of a polygon on the `keep` side of the bisector between two
-- seeds, tested in the warped space. Both rocks on a seam clip the same edges
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

-- Whether the point lies on the top (flat, or the item's shaped top), which
-- paints as even ground with no rock under it.
local function onTop(x: number, y: number, z: number): boolean
	if z > CAP_TOP - 0.01 then return true end
	if not islandTop then return false end
	local radius = math.sqrt(x * x + y * y) / islandTop.octagon(math.atan2(y, x))
	-- Between two rings the top runs straight, so allow for the bend at each.
	return radius < islandTop.radii[1] - 0.1 and math.abs(z - islandTop.height(radius)) < 0.2
end

-- The shell and its shading are cached under a key hashing every line above
-- "-- cached above", so changes below it skip the rebuild.
local shell = model.cached(CACHE_KEY, function()
-- The surface is built once into plain lists: every vertex where it ends up,
-- and the triangles of each rock and of the top. Each rock then becomes a part
-- of its own, so every part's edge is a seam, where the surface folds anyway.
-- Cutting a smooth rock face into chunks would split its smoothing there and
-- show as a sawtooth of light and dark along the cut.
local positions, rockFaces, topFaces = {}, {}, {}
local function newVertex(q: { number }): number
	table.insert(positions, q)
	return #positions
end
do
	-- The surface grid: rows down the wall, then rings in across the underside.
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

	-- Points are shared by position, so a seam is one set of vertices.
	local indexOf = {}
	local function vertexAt(p: { number }): number
		local key = `{math.round(p[1] * 1e4)}_{math.round(p[2] * 1e4)}_{math.round(p[3] * 1e4)}`
		if not indexOf[key] then
			local seed, edge = ownerAt(p)
			local n = pushAt(p)
			local h = standoff(p, seed, edge)
			indexOf[key] = newVertex({ p[1] + n[1] * h, p[2] + n[2] * h, p[3] + n[3] * h })
		end
		return indexOf[key]
	end

	-- Every vertex sitting on the top rim, for the top.
	local rimVertices = {}

	-- One triangle of the grid: cut into a piece per rock its corners belong to.
	local function emit(a: { number }, b: { number }, c: { number }, oa, ob, oc)
		local u, v = sub(b, a), sub(c, a)
		local face = cross(u, v)
		if dot(face, face) < 1e-12 then return end
		local outward = pushAt({ (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3, (a[3] + b[3] + c[3]) / 3 })
		local present = { oa }
		if ob ~= oa then table.insert(present, ob) end
		if oc ~= oa and oc ~= ob then table.insert(present, oc) end
		for _, owner in present do
			local poly = { a, b, c }
			for _, other in present do
				if other ~= owner then poly = clipTo(poly, owner, other) end
			end
			if #poly < 3 then continue end
			rockFaces[owner] = rockFaces[owner] or {}
			local faces = rockFaces[owner]
			local ids = {}
			for i, p in poly do
				ids[i] = vertexAt(p)
				if math.abs(p[3] - CAP_TOP) < 1e-6 then
					rimVertices[ids[i]] = math.atan2(p[2], p[1]) % TAU
				end
			end
			for i = 2, #poly - 1 do
				local p, q, r = positions[ids[1]], positions[ids[i]], positions[ids[i + 1]]
				local normal = cross(sub(q, p), sub(r, p))
				if dot(normal, outward) >= 0 then
					table.insert(faces, { ids[1], ids[i], ids[i + 1] })
				else
					table.insert(faces, { ids[1], ids[i + 1], ids[i] })
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

	-- The top, wound to face up: every top vertex in order round the rim.
	local function upFace(a: number, b: number, c: number)
		local normal = cross(sub(positions[b], positions[a]), sub(positions[c], positions[a]))
		table.insert(topFaces, if normal[3] >= 0 then { a, b, c } else { a, c, b })
	end
	local outer = {}
	for index, angle in rimVertices do
		table.insert(outer, { index = index, angle = angle })
	end
	table.sort(outer, function(p, q) return p.angle < q.angle end)

	if islandTop then
		-- A shaped top: octagonal rings in from the rim, each at its own
		-- height. The rim's vertices fall wherever the seams cut it, so it is
		-- zipped to the first ring by angle; the rings after share their
		-- angles. A ring never reaches past the rim, so the two can't cross.
		local function ring(radius: number)
			local points = {}
			for j = 0, ANGLES - 1 do
				local angle = TAU * j / ANGLES
				local r = math.min(radius * islandTop.octagon(angle), R0 * outlineScale(angle) - 0.3)
				local index = newVertex({ r * math.cos(angle), r * math.sin(angle), islandTop.height(radius) })
				points[j + 1] = { index = index, angle = angle }
			end
			return points
		end
		local inner = ring(islandTop.radii[1])
		local i, j = 1, 1
		while i <= #outer or j <= #inner do
			local a, b = outer[(i - 1) % #outer + 1], inner[(j - 1) % #inner + 1]
			local nextOuter, nextInner = outer[i % #outer + 1], inner[j % #inner + 1]
			-- Angles past the last vertex wrap round to the first plus a turn.
			local outerAngle = if i < #outer then nextOuter.angle else nextOuter.angle + TAU
			local innerAngle = if j < #inner then nextInner.angle else nextInner.angle + TAU
			if j > #inner or (i <= #outer and outerAngle <= innerAngle) then
				upFace(a.index, nextOuter.index, b.index)
				i += 1
			else
				upFace(a.index, nextInner.index, b.index)
				j += 1
			end
		end
		for n = 2, #islandTop.radii do
			local next = ring(islandTop.radii[n])
			for k = 1, ANGLES do
				local l = k % ANGLES + 1
				upFace(inner[k].index, inner[l].index, next[l].index)
				upFace(inner[k].index, next[l].index, next[k].index)
			end
			inner = next
		end
		outer = inner
	end
	-- The middle: a fan from the axis out to the innermost ring, or to the
	-- rim itself on a flat top.
	local centre = newVertex({ 0, 0, if islandTop then islandTop.height(0) else CAP_TOP })
	for i, p in outer do
		upFace(centre, p.index, outer[i % #outer + 1].index)
	end
end

local function paint(x: number, y: number, z: number)
	if onTop(x, y, z) then return islandPaint(x, y, 0) end
	-- Every other texel takes its rock's seed and tint, and paints as one
	-- material: a single stratum and pebble colour for the whole rock.
	local seed = (ownerAt({ x, y, z }))
	local depth = math.clamp(CAP_TOP - z, 0, PROFILE_DEPTH)
	local spread = TOP_SPREAD + (BOTTOM_SPREAD - TOP_SPREAD) * depth / PROFILE_DEPTH
	return islandPaint(x, y, -depth, seed.key, seed.tint, spread, true)
end

-- Builds a list of faces into a part's mesh, unwarped.
local function facesInto(faces)
	return function(mesh)
		local handles = {}
		for _, face in faces do
			local verts = {}
			for i, v in face do
				if not handles[v] then
					local q = positions[v]
					handles[v] = mesh:vertex(q[1], q[2], q[3])
				end
				verts[i] = handles[v]
			end
			mesh:face(verts)
		end
	end
end
-- A part per rock, sized to it at the layout's texel density. The top is flat
-- or gently curved, so it can be chunked without its cuts showing.
for n, seed in seeds do
	if rockFaces[seed] then
		part(`Rock{n}`, nil, ROCK_COLOUR, facesInto(rockFaces[seed]), 30, paint, nil, nil, true)
	end
end
chunkedPart("Top", nil, ROCK_COLOUR, facesInto(topFaces), 30, paint, true)

-- Stronger highlights along the rock edges, and deeper contact shadows in the
-- seams, than the default: each rock shades against every other rock.
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
