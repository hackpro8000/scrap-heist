-- Yard Island: a floating yard island built from stacked rock columns, in
-- the style of a hand-sculpted stylised island. Three tiers of rounded
-- rock pillars ring the island, each tier tucked further in and ending
-- lower than the last, with deep clefts between pillars and a soil lip
-- draped over the rim. The model is one closed outer shell over the
-- columns, with nothing inside. Top at z = 0.7.
useTexelDensity(16)
local RADIUS = 20
local GROUND = { 0.3, 0.27, 0.22 }
local STRATA = { { 0.5, 0.4, 0.27 }, { 0.36, 0.35, 0.34 }, { 0.48, 0.3, 0.22 } }
local TOPSOIL = { 0.24, 0.19, 0.14 }

local function random(k: number): number
	local s = math.sin(k * 12.9898 + 4.1414) * 43758.5453
	return s - math.floor(s)
end

-- The map's island texture: speckled ground on top, then topsoil fading
-- into wavy rock strata that darken with depth. A clump's `seed` shifts its
-- strata, tint and grain so neighbouring clumps don't match.
local function islandPaint(x: number, y: number, z: number, seed: number?)
	local below = -z
	if below < 0.3 then
		local k = 1 + 0.12 * math.noise(x / 4, y / 4, 31) + 0.05 * math.noise(x * 3, y * 3, 37)
		return GROUND[1] * k, GROUND[2] * k, GROUND[3] * k
	end
	local s = seed or 0
	local band = math.noise(x / 9 + s, y / 9, z / 2) * 0.6 + z * (0.8 + 0.2 * random(s + 1)) + random(s + 2) * 3
	local tint = if seed then 0.85 + 0.3 * random(s + 3) else 1
	local wave = math.sin(band * 2.4)
	local layer = STRATA[math.floor(band * 2.4 / (2 * math.pi)) % 3 + 1]
	local k = tint * (1 + 0.1 * wave + 0.06 * math.noise(x * 2 + s, y * 2, z * 2))
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
	{ RADIUS * 0.84, 15, -8, 11 },
	{ RADIUS * 0.58, 11, -14, 23 },
	{ RADIUS * 0.34, 7, -19.5, 37 },
	{ RADIUS * 0.15, 4, -24, 51 },
}
local CLEFT, ROUNDING = 2, 1.2

-- Pillar layout per tier: each pillar's start angle, reach and bottom.
local pillars = {}
for t, tier in TIERS do
	local reach, count, bottom, seed = tier[1], tier[2], tier[3], tier[4]
	local list = {}
	local offset = random(seed) * 2 * math.pi
	local weights, total = {}, 0
	for i = 1, count do
		weights[i] = 0.7 + 0.6 * random(seed + i)
		total += weights[i]
	end
	local angle = offset
	for i = 1, count do
		local span = weights[i] / total * 2 * math.pi
		list[i] = {
			from = angle,
			span = span,
			reach = reach * (0.94 + 0.12 * random(seed + i + 40)),
			bottom = bottom - (TIERS[t][3] - (if t > 1 then TIERS[t - 1][3] else CAP_TOP)) * 0.25 * (random(seed + i + 80) - 0.5),
			seed = seed * 31 + i * 7,
			top = if t == 1 then CAP_TOP else TIERS[t - 1][3] + 0.5,
			-- Like the old clumps: each pillar tapers and leans in toward
			-- its foot by its own amount, and has a chip bitten in or a lump
			-- standing out partway across its face.
			taper = 0.08 + 0.12 * random(seed + i + 120),
			lean = 0.1 + 0.25 * random(seed + i + 140),
			defect = random(seed + i + 160) - 0.45,
			defectAt = (random(seed + i + 180) - 0.5) * 1.2,
		}
		angle += span
	end
	pillars[t] = list
end

-- The pillar of `tier` covering `angle`, and where across it the angle
-- falls, from -1 at one cleft to 1 at the next.
local function pillarAt(tier: number, angle: number)
	for _, pillar in pillars[tier] do
		local a = (angle - pillar.from) % (2 * math.pi)
		if a < pillar.span then
			return pillar, a / pillar.span * 2 - 1
		end
	end
	return pillars[tier][1], 0
end

-- How far the island's wall reaches at `angle` and height z, and the
-- pillar there with its across position, for painting. Each pillar is
-- rounded across its face so clefts open between pillars, and rounded
-- under its foot down onto the tier below.
local function wall(angle: number, z: number)
	local best, owner, across = 0.05, nil, 0
	for t = 1, #TIERS do
		local pillar, u = pillarAt(t, angle)
		if z < pillar.bottom then continue end
		-- Faceted across the face: the round profile sampled at a few
		-- jittered corners with flat faces between, like the old clumps.
		local facets = 3 + pillar.seed % 2
		local f = math.clamp(math.floor((u + 1) / 2 * facets), 0, facets - 1)
		local function corner(n: number): (number, number)
			local cu = if n == 0 or n == facets then n / facets * 2 - 1 else n / facets * 2 - 1 + (random(pillar.seed + n * 29) - 0.5) * 0.3
			return cu, CLEFT * (1 - math.sqrt(math.max(1 - cu * cu, 0))) + (if n == 0 or n == facets then 0 else 0.35 * (random(pillar.seed + n * 31) - 0.5))
		end
		local u0, d0 = corner(f)
		local u1, d1 = corner(f + 1)
		local r = pillar.reach * outlineScale(angle) - (d0 + (d1 - d0) * math.clamp((u - u0) / (u1 - u0), 0, 1))
		local size = pillar.reach * pillar.span / 2
		local shift = math.clamp((pillar.top - z) / (pillar.top - pillar.bottom), 0, 1)
		r -= pillar.reach * pillar.taper * shift + size * pillar.lean * shift
		r += size * 0.35 * pillar.defect * math.max(1 - math.abs(u - pillar.defectAt) / 0.5, 0)
		-- Every ring of the face nudged a little, stepping down the pillar.
		local at = (pillar.top - z) / 1.5
		local ring = math.floor(at)
		local blend = math.clamp((at - ring - 0.7) / 0.3, 0, 1)
		local function ringNudge(n: number): number
			return random(pillar.seed + n * 101)
		end
		local nudge = ringNudge(ring) + (ringNudge(ring + 1) - ringNudge(ring)) * blend
		r += 0.25 * math.noise(angle * 6, z / 3, pillar.seed % 97) + 0.7 * (nudge - 0.5)
		local lift = z - pillar.bottom
		if lift < ROUNDING then
			local inner = if t < #TIERS then pillarAt(t + 1, angle).reach * outlineScale(angle) * 0.9 else 0
			r = inner + (r - inner) * math.sqrt(1 - (1 - lift / ROUNDING) ^ 2)
		end
		if r > best then
			best, owner, across = r, pillar, u
		end
	end
	return best, owner, across
end

-- The soil lip: how far it drapes down the rim at `angle`, in clumps.
local function drape(angle: number): number
	local n = math.noise(angle * 7, 3.7) + 0.5 * math.noise(angle * 23, 9.1)
	return 0.35 + 1.1 * math.clamp(n + 0.4, 0, 1)
end

-- One closed outer shell: rows of wall points stepping down from the top to
-- the tip, a flat top in concentric rings and a point at the bottom.
local ANGLES, STEP, TIP, LIP, TOP_RINGS = 240, 0.3, -25, 0.35, 8
local RIM_JAGGED, RIM_POKE = 0.166, 0.06
local RIM_BLEND = (CAP_TOP - TIERS[1][3]) * 0.5
-- The shell and its shading are cached under a key hashing every line above
-- "-- cached above", so changes below it (the plumbing) skip the rebuild.
local function shade(entries, occluders)
	for _, entry in entries do
		entry.mesh:paintShading(entry.image, {
			highlight = 0.5,
			highlightRamp = 0.3,
			shadow = 1.5,
			gradient = GRADIENT,
			blend = 0.78,
			occluders = occluders,
		})
	end
end
local shell = model.cached(CACHE_KEY, function()
part("Island", nil, GROUND, function(mesh)
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
	while z > TIP + STEP / 2 do
		-- Stop once every pillar has ended, so no needle trails below.
		local any = false
		for j = 0, ANGLES - 1, 8 do
			if wall(2 * math.pi * j / ANGLES, z) > 0.3 then
				any = true
				break
			end
		end
		if not any then break end
		local row = {}
		for j = 0, ANGLES - 1 do
			local angle = 2 * math.pi * j / ANGLES
			-- The calm rim eases into the jagged pillar faces over the top half
			-- of the first tier.
			local t = math.clamp((CAP_TOP - z) / RIM_BLEND, 0, 1)
			t = t * t * (3 - 2 * t)
			local r = rim[j] + (wall(angle, z) - rim[j]) * t
			-- The grass lip stands proud of the rock, easing back in over
			-- its last fifth so it overhangs the stone below.
			local depth = (CAP_TOP - z) / drape(angle)
			if depth < 1 then
				r = math.max(r, rim[j]) + LIP * math.clamp((1 - depth) / 0.2, 0, 1)
			end
			row[j] = mesh:vertex(math.cos(angle) * r, math.sin(angle) * r, z)
		end
		table.insert(rows, row)
		z -= STEP
	end
	for i = 1, #rows - 1 do
		for j = 0, ANGLES - 1 do
			local l = (j + 1) % ANGLES
			mesh:face({ rows[i + 1][j], rows[i + 1][l], rows[i][l], rows[i][j] })
		end
	end
	-- The top in concentric rings out to the rim, so no long thin fan
	-- triangles streak its shading.
	local inner = rows[1]
	for ring = TOP_RINGS - 1, 1, -1 do
		local k = ring / TOP_RINGS
		local row = {}
		for j = 0, ANGLES - 1 do
			local angle = 2 * math.pi * j / ANGLES
			row[j] = mesh:vertex(math.cos(angle) * (rim[j] + LIP) * k, math.sin(angle) * (rim[j] + LIP) * k, CAP_TOP)
		end
		for j = 0, ANGLES - 1 do
			local l = (j + 1) % ANGLES
			mesh:face({ row[j], inner[j], inner[l], row[l] })
		end
		inner = row
	end
	local middle = mesh:vertex(0, 0, CAP_TOP)
	for j = 0, ANGLES - 1 do
		mesh:face({ middle, inner[j], inner[(j + 1) % ANGLES] })
	end
	local tip = mesh:vertex(0, 0, z + STEP - 0.4)
	for j = 0, ANGLES - 1 do
		mesh:face({ tip, rows[#rows][(j + 1) % ANGLES], rows[#rows][j] })
	end
end, false, function(x, y, z)
	-- The original island colouring: speckled ground on top, then topsoil
	-- fading into wavy strata, shifted per pillar so neighbours don't match.
	local _, pillar = wall(math.atan2(y, x), z)
	return islandPaint(x, y, z - CAP_TOP, if pillar then pillar.seed else nil)
end)

-- Aggressive shading: half-strength edge highlights, ramping 30% stronger
-- toward the bottom, and strong contact shadows, with the shell as its own
-- occluder so the crevices and overhangs darken.
local entries = table.clone(parts)
shade(entries, { entries[1].mesh })
table.clear(parts)
return entries
end)
-- cached above

-- Plumbing helpers: rust paint and vector maths for the pipe network below.
local RUST = { 0.45, 0.25, 0.14 }
local function scrapPaint(x: number, y: number, z: number): (number, number, number)
	local k = 1 + 0.2 * math.noise(x * 1.5, y * 1.5, z * 1.5)
	local bare = math.clamp(math.noise(x / 2, y / 2, z / 2 + 7) * 3, 0, 1)
	return (RUST[1] + (0.38 - RUST[1]) * bare) * k, (RUST[2] + (0.37 - RUST[2]) * bare) * k, (RUST[3] + (0.36 - RUST[3]) * bare) * k
end
local function unit(v)
	local length = math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
	return { v[1] / length, v[2] / length, v[3] / length }
end
local function cross(a, b)
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
local function circle(radius: number, sides: number)
	local profile = {}
	for k = 0, sides - 1 do
		local a = 2 * math.pi * k / sides
		table.insert(profile, { math.cos(a) * radius, math.sin(a) * radius })
	end
	return profile
end
-- A tube of `profile` swept along `points`, its rings kept from twisting by
-- carrying each ring's side vector on to the next.
local function sweep(mesh, points, profile: { { number } })
	local rings, side = {}, nil
	for i, p in points do
		local a, b = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local axis = unit({ b[1] - a[1], b[2] - a[2], b[3] - a[3] })
		if not side then
			side = cross(axis, if math.abs(axis[3]) < 0.9 then { 0, 0, 1 } else { 1, 0, 0 })
		end
		local along = side[1] * axis[1] + side[2] * axis[2] + side[3] * axis[3]
		side = unit({ side[1] - axis[1] * along, side[2] - axis[2] * along, side[3] - axis[3] * along })
		local up = cross(side, axis)
		local ring = {}
		for k, point in profile do
			ring[k] = mesh:vertex(p[1] + side[1] * point[1] + up[1] * point[2], p[2] + side[2] * point[1] + up[2] * point[2], p[3] + side[3] * point[1] + up[3] * point[2])
		end
		rings[i] = ring
	end
	for i = 1, #points - 1 do
		for k = 1, #profile do
			local l = k % #profile + 1
			mesh:face({ rings[i][k], rings[i][l], rings[i + 1][l], rings[i + 1][k] })
		end
	end
end
-- A ball fitting where pipes meet.
local function ball(mesh, c, radius: number)
	local rows = {}
	for i = 0, 6 do
		local lat = math.pi * (i / 6 - 0.5)
		rows[i] = {}
		for k = 0, 9 do
			local lon = 2 * math.pi * k / 10
			rows[i][k] = mesh:vertex(c[1] + math.cos(lat) * math.cos(lon) * radius, c[2] + math.cos(lat) * math.sin(lon) * radius, c[3] + math.sin(lat) * radius)
		end
	end
	for i = 0, 5 do
		for k = 0, 9 do
			local l = (k + 1) % 10
			mesh:face({ rows[i][k], rows[i][l], rows[i + 1][l], rows[i + 1][k] })
		end
	end
end

-- The pipe network: a lattice of junctions over the lower terrain, columns
-- round the island and levels down the tiers, joined by a seeded pick of the
-- lattice's edges plus whatever keeps every junction connected. Pipes hug
-- the rock's hull, so they climb out over each ledge and round its edge in
-- a smooth bend instead of a sharp corner.
local PIPE, COLUMNS, SMOOTHING = 0.42, 14, 3
local LEVELS = { -2.6, -7.5, -12.5, -17, -21 }
local function hull(angle: number, z: number): number
	local best = 0
	for da = -2, 2 do
		for dz = 0, 2 do
			best = math.max(best, (wall(angle + da * 0.05, z + dz * 0.8)))
		end
	end
	return best + PIPE + 0.12
end
local function onRock(angle: number, z: number)
	local r = hull(angle, z)
	return { math.cos(angle) * r, math.sin(angle) * r, z }
end
local columnAngle = {}
for c = 1, COLUMNS do
	columnAngle[c] = (c - 1 + 0.6 * (random(300 + c) - 0.5)) / COLUMNS * 2 * math.pi
end
-- A junction per lattice slot, with edges round each level and down each
-- column. Lower levels have shorter rings, so they keep fewer columns.
local junctions, edges = {}, {}
local function key(c: number, l: number): number
	return l * 100 + c
end
for l, z in LEVELS do
	for c = 1, COLUMNS do
		if l >= 4 and c % 2 == 0 then continue end
		junctions[key(c, l)] = { c = c, l = l, z = z }
	end
end
for l = 1, #LEVELS do
	local row = {}
	for c = 1, COLUMNS do
		if junctions[key(c, l)] then table.insert(row, c) end
	end
	for n, c in row do
		table.insert(edges, { key(c, l), key(row[n % #row + 1], l), random(400 + l * 31 + c) })
	end
	if l == 1 then continue end
	for _, c in row do
		local above = if junctions[key(c, l - 1)] then c else c - 1
		table.insert(edges, { key(above, l - 1), key(c, l), random(500 + l * 37 + c) })
	end
end
-- Keep edges whose roll passes; then add any still needed to connect
-- every junction, and drop junctions nothing reached.
local group = {}
local function find(k)
	while group[k] and group[k] ~= k do
		k = group[k]
	end
	return k
end
for k in junctions do
	group[k] = k
end
local kept = {}
for pass = 1, 2 do
	for _, edge in edges do
		local a, b = find(edge[1]), find(edge[2])
		if (pass == 1 and edge[3] < 0.5) or (pass == 2 and a ~= b) then
			if pass == 2 or not kept[edge] then
				kept[edge] = true
				group[a] = b
			end
		end
	end
end
local used = {}
local function route(edge)
	local from, to = junctions[edge[1]], junctions[edge[2]]
	local a0, a1 = columnAngle[from.c], columnAngle[to.c]
	if from.l == to.l and a1 <= a0 then a1 += 2 * math.pi end
	local samples = {}
	local count = if from.l == to.l then math.ceil((a1 - a0) * TIERS[1][1] / 1.2) else math.ceil((from.z - to.z) / 0.5)
	for n = 0, count do
		local t = n / count
		samples[n + 1] = { a0 + (a1 - a0) * t, from.z + (to.z - from.z) * t, 0 }
	end
	for _, s in samples do
		s[3] = hull(s[1], s[2])
	end
	-- Ease the radius along the run so the pipe bends round ledges.
	for _ = 1, SMOOTHING do
		local before = table.clone(samples)
		for n = 2, #samples - 1 do
			samples[n][3] = math.max((before[n - 1][3] + 2 * before[n][3] + before[n + 1][3]) / 4, before[n][3] - 0.05)
		end
	end
	local points = {}
	for n, s in samples do
		points[n] = { math.cos(s[1]) * s[3], math.sin(s[1]) * s[3], s[2] }
	end
	used[edge[1]], used[edge[2]] = true, true
	return points
end
part("Plumbing", nil, RUST, function(mesh)
	local pipe = circle(PIPE, 10)
	for _, edge in edges do
		if not kept[edge] then continue end
		local points = route(edge)
		sweep(mesh, points, pipe)
		-- A clamp ring every few studs along the run.
		for n = 4, #points - 3, 5 do
			local a, b = points[n], points[n + 1]
			local d = unit({ b[1] - a[1], b[2] - a[2], b[3] - a[3] })
			sweep(mesh, { { a[1] - d[1] * 0.1, a[2] - d[2] * 0.1, a[3] - d[3] * 0.1 }, { a[1] + d[1] * 0.1, a[2] + d[2] * 0.1, a[3] + d[3] * 0.1 } }, circle(PIPE * 1.3, 10))
		end
	end
	for k, junction in junctions do
		if used[k] then
			ball(mesh, onRock(columnAngle[junction.c], junction.z), PIPE * 1.6)
		end
	end
end, false, scrapPaint)


-- The plumbing shades against the shell and itself; the shell keeps its
-- cached shading.
shade(parts, { shell[1].mesh, parts[1].mesh })
for _, entry in shell do
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
for _, entry in parts do
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
