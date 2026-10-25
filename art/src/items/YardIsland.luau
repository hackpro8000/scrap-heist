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
local function shade(entries, occluders, gradient: number?, shadow: number?)
	for _, entry in entries do
		entry.mesh:paintShading(entry.image, {
			highlight = 0.5,
			highlightRamp = 0.3,
			shadow = shadow or 1.5,
			gradient = gradient or GRADIENT,
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

for _, entry in shell do
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end

-- Plumbing: iron brackets bolted round the island and a big grated outfall
-- at the bottom that drips green goo.
local IRON = { 0.42, 0.4, 0.38 }
local GOO = { 0.45, 0.95, 0.2 }
local PIPE, STANDOFF = 0.8, 1.1
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
-- carrying each ring's side vector on to the next. `capped` closes the ends.
local function sweep(mesh, points, profile: { { number } }, capped: boolean?)
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
	if not capped then return end
	for _, ends in { { 1, points[1] }, { #points, points[#points] } } do
		local ring, p = rings[ends[1]], ends[2]
		local middle = mesh:vertex(p[1], p[2], p[3])
		for k = 1, #profile do
			local l = k % #profile + 1
			mesh:face(if ends[1] == 1 then { middle, ring[l], ring[k] } else { middle, ring[k], ring[l] })
		end
	end
end
local function lerp(a, b, t: number)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end
local function polarPoint(angle: number, r: number, z: number)
	return { math.cos(angle) * r, math.sin(angle) * r, z }
end
-- The furthest the rock reaches over an arc of angles and a span of heights,
-- so a pipe at that radius plus STANDOFF clears it.
local function hull(a0: number, a1: number, z0: number, z1: number): number
	local best = 0
	for i = 0, 16 do
		local angle = a0 + (a1 - a0) * i / 16
		for j = 0, 6 do
			best = math.max(best, (wall(angle, z0 + (z1 - z0) * j / 6)))
		end
	end
	return best
end

-- Where a pipe clears the rock at `angle` and height z.
local function follow(angle: number, z: number): number
	return hull(angle - 0.12, angle + 0.12, z - 2.5, z + 1) + STANDOFF
end

-- Brackets: an iron triangle bolted to the rock under a pipe, a beam out to
-- the pipe, a post down the rock and a diagonal brace, riveted at the joints.
local brackets = {}
local function bracketAt(angle: number, r: number, z: number)
	table.insert(brackets, { angle = angle, r = r, z = z })
end

-- Bracket spots, by tier: under the rim, down the sides and under each
-- overhang, with one on the back.
local FRONT = -math.pi / 2
local DRAIN_Z = -17
local function arcRun(a0: number, a1: number, z: number, zBelow: number): number
	return hull(math.min(a0, a1), math.max(a0, a1), zBelow, z + 1) + STANDOFF
end
do
	for _, side in { -1, 1 } do
		local back, drop, mid = FRONT + side * 2.4, FRONT + side * 1.6, FRONT + side * 0.5
		-- Drops sit far enough out to clear the rock all the way down.
		local rDrop = math.max(follow(drop, -3), arcRun(drop, drop, -3, -10))
		local rMid = math.max(follow(mid, -10), arcRun(mid, mid, -10, DRAIN_Z))
		local between = back - side * 0.4
		bracketAt(between, follow(between, -3), -3)
		bracketAt(drop, rDrop, -6.5)
		bracketAt(mid, rMid, -13.5)
	end
		for _, angle in { FRONT + math.pi - 0.3 } do
		local r = arcRun(angle, angle, -2, -14)
		bracketAt(angle, r, -7)
	end
end

local DRAIN_R = follow(FRONT, DRAIN_Z) + 1.8
part("Drain", nil, IRON, function(mesh)
	-- A thick lipped ring round the mouth and a grate of bars across it.
	local mouth = PIPE * 2.1
	local out = polarPoint(FRONT, 1, 0)
	local at = polarPoint(FRONT, DRAIN_R, DRAIN_Z)
	local ring = {}
	for k = 0, 24 do
		local a = 2 * math.pi * k / 24
		local c = math.cos(a) * mouth
		table.insert(ring, { at[1] + out[2] * c * -1, at[2] + out[1] * c, at[3] + math.sin(a) * mouth })
	end
	sweep(mesh, ring, circle(0.35, 10))
	sweep(mesh, { at, { at[1] - out[1] * 1.2, at[2] - out[2] * 1.2, at[3] } }, circle(mouth, 24), true)
	for n = -2, 2 do
		local d = n * mouth * 0.35
		local half = math.sqrt(mouth ^ 2 - d ^ 2)
		local o = { at[1] + out[1] * 0.12, at[2] + out[2] * 0.12, at[3] }
		sweep(mesh, { { o[1] - out[2] * d * -1, o[2] - out[1] * d, o[3] - half }, { o[1] - out[2] * d * -1, o[2] - out[1] * d, o[3] + half } }, circle(0.13, 6), true)
	end
	-- Brackets.
	for _, b in brackets do
		local rock = wall(b.angle, b.z - PIPE - 0.4) - 0.4
		local top = b.z - PIPE - 0.15
		local p0 = polarPoint(b.angle, rock, top)
		local p1 = polarPoint(b.angle, b.r + 0.3, top)
		local p2 = polarPoint(b.angle, wall(b.angle, top - 2.6) - 0.4, top - 2.6)
		local beam = { { -0.28, -0.28 }, { 0.28, -0.28 }, { 0.28, 0.28 }, { -0.28, 0.28 } }
		sweep(mesh, { p0, p1 }, beam, true)
		sweep(mesh, { p0, p2 }, beam, true)
		sweep(mesh, { p2, lerp(p0, p1, 0.85) }, beam, true)
		-- Rivets at each joint.
		local tangent = polarPoint(b.angle + math.pi / 2, 1, 0)
		for _, p in { p0, p2, lerp(p0, p1, 0.85), lerp(p0, p1, 0.5) } do
			sweep(mesh, { lerp(p, { p[1] + tangent[1], p[2] + tangent[2], p[3] }, -0.32), lerp(p, { p[1] + tangent[1], p[2] + tangent[2], p[3] }, 0.32) }, circle(0.11, 6), true)
		end
	end
end, 40, 0.5, 1024)

-- The goo: a pool sagging out of the mouth's lower lip, a strand stretching
-- down from it and a drop hanging off the end.
part("Goo", nil, GOO, function(mesh)
	local mouth = PIPE * 2.1
	local lip = polarPoint(FRONT, DRAIN_R + 0.15, DRAIN_Z - mouth + 0.15)
	local strand = {}
	for k = 0, 10 do
		local t = k / 10
		table.insert(strand, { lip[1] + 0.25 * math.sin(t * 2), lip[2] - 0.35 * t, lip[3] - 3.2 * t })
	end
	local blob = {}
	for k = 0, 10 do
		local t = k / 10
		local radius = 0.18 + 0.5 * math.sin(math.pi * t) ^ 0.7
		local row = {}
		for s = 0, 11 do
			local a = 2 * math.pi * s / 12
			row[s] = mesh:vertex(strand[11][1] + math.cos(a) * radius, strand[11][2] + math.sin(a) * radius, strand[11][3] - t * 1.3)
		end
		table.insert(blob, row)
	end
	for k = 1, #blob - 1 do
		for s = 0, 11 do
			local l = (s + 1) % 12
			mesh:face({ blob[k][s], blob[k][l], blob[k + 1][l], blob[k + 1][s] })
		end
	end
	sweep(mesh, strand, circle(0.22, 10))
	sweep(mesh, { polarPoint(FRONT - 0.07, DRAIN_R - 0.2, DRAIN_Z - mouth + 0.2), polarPoint(FRONT + 0.07, DRAIN_R - 0.2, DRAIN_Z - mouth + 0.2) }, circle(0.45, 10), true)
end, 60, 0, 1024, 1.5)

-- Plumbing is shaded without occluders or the height gradient, and with a
-- light shadow: its overlapping, rock-buried pieces blacked the drain out.
for _, entry in parts do
	if entry.emissive then
		model.part(entry.name, entry.mesh, entry.image, { preview = true, emissive = entry.emissive })
		continue
	end
	shade({ entry }, {}, 0, 0.3)
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
