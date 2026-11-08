-- Mine Loop: the hub's minecart track and the cave it runs into, as one
-- model (art/concepts/mine-column-reference.png: a hill of carved columns
-- built the Column Island way), at full size in studs.
-- The origin is the middle of the hub at deck level; the layout puts it on
-- the plaza.
-- The track is one lap of radius TRACK_RADIUS. Round 0 degrees a cluster
-- of sliced rocks clipped into each other sits over it, CAVE_HALF degrees either
-- side, with a tunnel through it; both track ends run into the tunnel and
-- dive down out of sight in its middle, so carts come up out of the ground
-- and go back down at one spot.
-- The rocks pile up from small ones on the hub side to a tower of stacked
-- rocks on the far side; squared lintels laid across the tunnel roof it,
-- rocks sitting on them. Each mouth has a timber porch: two log posts a side,
-- header beams, side beams and a deck of planks, with upright boards
-- closing the gap between the porch and the stone, and broken-off chunks
-- round its foot. A black, unlit shade fills each mouth from the inside,
-- its faces turned in, clear at the mouth and opaque a few studs in, so the
-- tunnel reads as dark however it's lit.
-- The opening is 6.4 wide between the posts and 6.6 tall under the
-- headers: a cart (3.6 wide, 4.9 tall with its capsule) passes, and a
-- player (4 by 5.5) fits, though the floor drops away just inside.
-- open: Shades
-- floats: Sleepers, Stones
-- (Each sleeper and chunk lies on the plaza on its own.)
-- include: EditMesh
-- include: EditOps
-- include: EditShapes
useTexelDensity(16)

local TRACK_RADIUS, TRACK_GAUGE = 72, 3
local CAVE_HALF = 11
-- The track's ends, in degrees from the cave's middle, and where it starts
-- to dive (inside the tunnel, out of sight from the mouth).
local TRACK_END, DIVE_FROM = 4, 9
-- The shade fills the bore from halfway along the porch to SHADE_DEPTH in.
local SHADE_DEPTH = 6

-- The opening, as {out from the track's middle, up from the deck}, from
-- the inner foot over the top to the outer foot.
local OPEN_HALF, OPEN_TALL = 3.2, 6.6
local MOUTH = {
	{ -OPEN_HALF, 0 }, { -OPEN_HALF, OPEN_TALL / 2 }, { -OPEN_HALF, OPEN_TALL },
	{ OPEN_HALF, OPEN_TALL }, { OPEN_HALF, OPEN_TALL / 2 }, { OPEN_HALF, 0 },
}

local DEGREES_PER_STUD = 180 / (math.pi * TRACK_RADIUS)
local HALF_LENGTH = CAVE_HALF / DEGREES_PER_STUD
-- Where a point lies: `out` from the track's middle, `up` from the deck,
-- `along` studs into the tunnel from the mouth at `side` (+1 the mouth at
-- +CAVE_HALF degrees, -1 the one at -CAVE_HALF; negative is out in front).
local function caveAt(side: number, out: number, up: number, along: number): { number }
	local a = math.rad(side * (CAVE_HALF - along * DEGREES_PER_STUD))
	local r = TRACK_RADIUS + out
	return { math.cos(a) * r, math.sin(a) * r, up }
end
-- The other way: a model point's {out, along from its nearer mouth}.
local function caveOf(x: number, y: number): (number, number)
	local degrees = math.abs(math.deg(math.atan2(y, x)))
	return math.sqrt(x * x + y * y) - TRACK_RADIUS, (CAVE_HALF - degrees) / DEGREES_PER_STUD
end

-- A tube between two cross-sections, rings[k][i] (an outside) and
-- holes[k][i] (the opening through it), closed with a ring at each end and
-- a strip along each foot: one closed surface, wound consistently.
local function ringTube(m, rings, holes)
	local count, points = #rings, #rings[1]
	local O, H = {}, {}
	for k = 1, count do
		O[k], H[k] = {}, {}
		for i = 1, points do
			O[k][i] = m:addVertex(table.unpack(rings[k][i]))
			H[k][i] = m:addVertex(table.unpack(holes[k][i]))
		end
	end
	for k = 1, count - 1 do
		for i = 1, points - 1 do
			m:addFace({ O[k][i], O[k][i + 1], O[k + 1][i + 1], O[k + 1][i] })
			m:addFace({ H[k][i + 1], H[k][i], H[k + 1][i], H[k + 1][i + 1] })
		end
		m:addFace({ O[k][1], O[k + 1][1], H[k + 1][1], H[k][1] })
		m:addFace({ O[k + 1][points], O[k][points], H[k][points], H[k + 1][points] })
	end
	for i = 1, points - 1 do
		m:addFace({ O[1][i + 1], O[1][i], H[1][i], H[1][i + 1] })
		m:addFace({ O[count][i], O[count][i + 1], H[count][i + 1], H[count][i] })
	end
end
-- Turns a closed mesh's faces outward if they were built facing in.
local function faceOut(m)
	local volume = 0
	for face in m.faces do
		local c, n = m:faceCentre(face), m:faceNormal(face)
		volume += EditMesh.vec.dot(c, n) * m:faceArea(face)
	end
	if volume < 0 then
		m:flip()
	end
end
-- A steady pseudo-random number in -1..1 for whole numbers a, b.
local function jitter(a: number, b: number): number
	local s = math.sin(a * 127.1 + b * 311.7) * 43758.5453
	return 2 * (s - math.floor(s)) - 1
end
-- A box shaped by `shape` (each point in its own frame: x out, y along,
-- z up from its middle) and set down at `out`, `along`, its base at
-- `base`, at mouth `side`.
local function placed(m, side: number, out: number, along: number, base: number, h: number)
	m:transform(function(p)
		return caveAt(side, out + p[1], base + h / 2 + p[3], along + p[2])
	end)
	faceOut(m)
	return m
end

-- ------------------------------------------------------------- the stone

-- The cave is a hill of carved stone columns, built the way Column Island
-- builds the islands' stone (art/src/shared/ColumnIsland.luau). Squared
-- lintel blocks laid flat across the tunnel just over the opening roof it;
-- columns stand on the ground down each side of it and on the lintels over
-- it.
local CRACK = 0.15
local LINTEL_BASE, LINTEL_TALL, LINTEL_WIDE = OPEN_TALL + 0.15, 2.8, 8.6
local LINTEL_TOP = LINTEL_BASE + LINTEL_TALL
-- The stone runs to just past each mouth, into the back of the porch's
-- boards (which stand a quarter stud out in front of it).
local LINTEL_REACH = HALF_LENGTH + 0.15
-- The tunnel's walls, out from the track's middle each way.
local WALL = 3.75
-- The porch timber's look: post radius, how much thicker a post is at its
-- foot, how far a post or beam wanders from true (studs), how rough its
-- hewn faces are, the beam's thickness and edge round-off, and the paint:
-- grain contrast, cracks and worn light edges.
local TIMBER = { radius = 0.65, taper = 1.1, wander = 0.06, hewn = 0.04, beam = 0.85, round = 0.16, grain = 1.3, cracks = 0.5, worn = 0.7 }
-- In front of each mouth the hill carries on and the tunnel bores on
-- through it: BORE out from the track's middle each way, just past the
-- porch's posts (its roof's eaves tuck into the stone), the stone over it
-- standing on the roof at BORE_TOP. The hill's face stands about BORE_REACH
-- along the track, following the columns' own outlines; the porch sticks
-- out of it, its frame covering the bore's edges.
local BORE, BORE_TOP, BORE_REACH = OPEN_HALF + 2 * TIMBER.radius + 0.1, OPEN_TALL + TIMBER.beam + 0.7 + 0.45 + 0.1, HALF_LENGTH + 2.3
-- A column takes its side of the bore, or its face beside the track past
-- the hill's face, at up to this many degrees off the track's line.
local BORE_SLANT, PAST_FACE_SLANT = 12, 30
-- How far from the bore's side, and how far back in from the mouth, a
-- column counts as right beside the opening, and about how far above the
-- porch's roof such a column stops.
local FLANK_NEAR, FLANK_BACK, FLANK_ABOVE = 5, 2.5, 1.5
-- Rocks are built in bands about BAND tall, so their edges have points to
-- be chipped at.
local BAND = 1.2
-- The summit: where it stands ({out, along}) and how tall, flat out to
-- CROWN of the way to the foot so a cluster of columns stands at the top;
-- the slope is a cone rounded BOWL of the way toward a dome.
local PEAK, SUMMIT, CROWN, BOWL = { 2, -2 }, 18.5, 0.1, 0.2
-- A ridge along the track keeps the hill high round the tunnel and over
-- each porch: RIDGE tall out to RIDGE_FLAT either side of the track,
-- falling away over RIDGE_WIDTH beyond that, and running RIDGE_PAST past
-- each mouth (to the hill's face) before dropping over RIDGE_FALL.
local RIDGE, RIDGE_FLAT, RIDGE_WIDTH, RIDGE_PAST, RIDGE_FALL = 13.5, 5.5, 11, 2.2, 11
-- The far side falls away sooner, its foot ending short of the plaza's
-- painted ring: no part of a column stands further than FAR_LIMIT out.
local RIDGE_WIDTH_FAR, FAR_LIMIT = 6.5, 11.5
-- Stone sizes at the summit and at the foot, and the shortest a column
-- stands.
local SMALLEST, LARGEST, MIN_LENGTH = 3.2, 4.6, 2.5
-- Stones on the hill's middle slopes grow away from the openings: as they
-- are within OPENING_NEAR studs of a mouth's face, up to GROW times as big
-- from OPENING_FAR on; the crown and the foot keep their sizes.
local GROW, OPENING_NEAR, OPENING_FAR = 1.4, 7, 16
-- Chisel cuts per column, at most, and how deep one bites as a share of the
-- stone's size; fine chips per column (fewest, most) and how deep one bites
-- in studs; how far a cut's heading may swing from straight out.
local MAX_CUTS, CUT_DEPTH = 2, { 0.15, 0.4 }
local CHIPS, CHIP_DEPTH = { 3, 6 }, { 0.2, 0.55 }
local CUT_SPREAD = math.rad(55)
-- Each column's edges are chamfered unevenly, each edge its own width
-- (studs, narrowest and widest), then sub-chamfered: a narrower bevel,
-- SUB_CHAMFER of that width, trims each crease the chamfer left. Top edges
-- lean up to CHAMFER_LEAN either way of 45 degrees.
local CHAMFER, SUB_CHAMFER, CHAMFER_LEAN = { 0.12, 0.6 }, 0.35, math.rad(15)
-- How far an upright corner's chamfer leans in from upright (degrees,
-- least and most), so it runs out a couple of studs below the top.
local CORNER_LEAN = { 8, 16 }
-- Chips knocked off a column's top: the share of corners and of edges
-- chipped, and how deep a chip bites (studs, smallest and biggest).
local CORNER_CHIPS, EDGE_CHIPS, CHIP_SIZE = 0.6, 0.45, { 0.2, 0.55 }

-- A convex outline ({{x, y}, ...}, counter-clockwise) cut down to the side
-- where a x + b y <= c.
local function clipOutline(outline, a: number, b: number, c: number)
	local kept = {}
	for i, p in outline do
		local q = outline[i % #outline + 1]
		local sp, sq = a * p[1] + b * p[2] - c, a * q[1] + b * q[2] - c
		if sp <= 0 then
			table.insert(kept, p)
		end
		if (sp < 0 and sq > 0) or (sp > 0 and sq < 0) then
			local t = sp / (sp - sq)
			table.insert(kept, { p[1] + t * (q[1] - p[1]), p[2] + t * (q[2] - p[2]) })
		end
	end
	return kept
end
-- An outline's area and centroid.
local function outlineCentre(outline): (number, number, number)
	local area, cx, cy = 0, 0, 0
	for i, p in outline do
		local q = outline[i % #outline + 1]
		local cross = p[1] * q[2] - q[1] * p[2]
		area += cross / 2
		cx += (p[1] + q[1]) * cross
		cy += (p[2] + q[2]) * cross
	end
	if math.abs(area) < 0.05 then
		-- Too thin for a steady centroid: the points' average.
		local sx, sy = 0, 0
		for _, p in outline do
			sx, sy = sx + p[1], sy + p[2]
		end
		return area, sx / #outline, sy / #outline
	end
	return area, cx / (6 * area), cy / (6 * area)
end
-- The convex hull of some points ({{x, y}, ...}), counter-clockwise.
local function convexHull(points)
	local sorted = table.clone(points)
	table.sort(sorted, function(a, b)
		return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
	end)
	local function turn(o, a, b)
		return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1])
	end
	local hull = {}
	for _, pass in { 1, -1 } do
		local start = #hull
		local first, last = if pass == 1 then 1 else #sorted, if pass == 1 then #sorted else 1
		for k = first, last, pass do
			while #hull >= start + 2 and turn(hull[#hull - 1], hull[#hull], sorted[k]) <= 0 do
				table.remove(hull)
			end
			table.insert(hull, sorted[k])
		end
		table.remove(hull)
	end
	return hull
end

-- Whether a solid's faces close up: every edge used once each way.
local function isClosed(faces): boolean
	local function key(p)
		return `{math.round(p[1] * 1e4)},{math.round(p[2] * 1e4)},{math.round(p[3] * 1e4)}`
	end
	local edges = {}
	for _, face in faces do
		for i, a in face do
			local b = face[i % #face + 1]
			local ka, kb = key(a), key(b)
			if ka ~= kb then
				edges[`{ka}|{kb}`] = (edges[`{ka}|{kb}`] or 0) + 1
			end
		end
	end
	for edge, uses in edges do
		local ka, kb = string.match(edge, "^(.-)|(.*)$")
		if uses ~= 1 or edges[`{kb}|{ka}`] ~= 1 then
			return false
		end
	end
	return true
end

-- Cuts a solid (faces as lists of points, wound outward) down to the side
-- of the plane n . p = d it lies behind, closing the wound with a cap
-- facing along n; as Column Island carves its stone.
local function carveSolid(faces, n, d)
	local kept, cut = {}, {}
	for _, face in faces do
		local out = {}
		for i, a in face do
			local b = face[i % #face + 1]
			local sa = a[1] * n[1] + a[2] * n[2] + a[3] * n[3] - d
			local sb = b[1] * n[1] + b[2] * n[2] + b[3] * n[3] - d
			if sa <= 0 then
				table.insert(out, a)
			end
			if (sa <= 0) ~= (sb <= 0) then
				local t = sa / (sa - sb)
				local p = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
				table.insert(out, p)
				table.insert(cut, p)
			end
		end
		if #out >= 3 then
			table.insert(kept, out)
		end
	end
	if #cut < 3 then
		return kept
	end
	-- The cap's corners, sorted round their centre in the plane.
	local mx, my, mz = 0, 0, 0
	for _, p in cut do
		mx, my, mz = mx + p[1] / #cut, my + p[2] / #cut, mz + p[3] / #cut
	end
	local ux, uy, uz = if math.abs(n[3]) < 0.9 then -n[2] else 0, if math.abs(n[3]) < 0.9 then n[1] else -n[3], if math.abs(n[3]) < 0.9 then 0 else n[2]
	local length = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / length, uy / length, uz / length
	local vx, vy, vz = n[2] * uz - n[3] * uy, n[3] * ux - n[1] * uz, n[1] * uy - n[2] * ux
	local cap = {}
	for _, p in cut do
		local ox, oy, oz = p[1] - mx, p[2] - my, p[3] - mz
		local angle = math.atan2(ox * vx + oy * vy + oz * vz, ox * ux + oy * uy + oz * uz)
		local duplicate = false
		for _, other in cap do
			duplicate = duplicate or math.abs(other[2] - angle) < 1e-4
		end
		if not duplicate then
			table.insert(cap, { p, angle })
		end
	end
	table.sort(cap, function(a, b)
		return a[2] < b[2]
	end)
	if #cap >= 3 then
		local face = {}
		for i, entry in cap do
			face[i] = entry[1]
		end
		table.insert(kept, face)
	end
	return kept
end

-- Every block of the cave: {out (- toward the hub), along from the cave's
-- middle (+ toward the +CAVE_HALF mouth), base height, width out, depth
-- along, height, turn, lean out, lean along (degrees), lintel, outline in
-- the block's own frame (x out, y along toward the -CAVE_HALF mouth), for
-- a block meeting a mouth which way that mouth is in its frame, and for a
-- column its carved faces in (out, along, up)}.
local BLOCKS = {}
local function rectangle(w: number, d: number)
	return { { -w / 2, -d / 2 }, { w / 2, -d / 2 }, { w / 2, d / 2 }, { -w / 2, d / 2 } }
end
do
	-- The lintels, end to end along the tunnel.
	local from, n = -LINTEL_REACH, 0
	while LINTEL_REACH - from > 0.5 do
		n += 1
		local depth = 5.5 + (jitter(n, 51) + 1)
		if LINTEL_REACH - (from + depth) < 3 then
			depth = LINTEL_REACH - from
		end
		local middle = from + depth / 2
		local mouth = if middle - depth / 2 <= -LINTEL_REACH + 0.01 then { 0, 1 } elseif middle + depth / 2 >= LINTEL_REACH - 0.01 then { 0, -1 } else nil
		table.insert(BLOCKS, {
			0.3 * jitter(n, 52), middle, LINTEL_BASE, LINTEL_WIDE, depth - CRACK, LINTEL_TALL,
			1.5 * jitter(n, 53), 0, 0, true, rectangle(LINTEL_WIDE, depth - CRACK), mouth,
		})
		from += depth
	end
	-- The columns, built the way Column Island builds its stone
	-- (art/src/shared/ColumnIsland.luau), the mountain way up: stones
	-- scattered over the cave's footprint, small near the summit and big
	-- toward the foot; each stone's cell of a power diagram (so big stones
	-- claim big cells) raised as a column to the slope's height, its top
	-- one flat tilted plane, so neighbours step against each other in
	-- tiers; then chiselled by a cut or two biting gently into the top and
	-- fine chips at its edges, all facing out from the summit. Cells crossing the tunnel are
	-- split at its walls: the parts beside it stand on the ground, the part
	-- over it stands on the lintels.
	local function random(i: number, j: number): number
		return (jitter(i, j) + 1) / 2
	end
	-- The footprint, out (hub side, far side) and along either way from the
	-- summit's line.
	local FOOT_OUT, FOOT_ALONG = { -12.5, 9.5 }, 24
	-- How far a point sits from the summit toward the foot (0 to 1): on a
	-- squared-off oval (power `square`) for the footprint, so it stays wide
	-- out to the mouths; on a plain oval (power 2) for the slope, so heights
	-- fall away steadily in every direction and inner columns stand taller
	-- than outer ones.
	local SQUARE = 4
	local function fromSummit(out: number, middle: number, square: number?): number
		local power = square or SQUARE
		local dx = (out - PEAK[1]) / (if out < PEAK[1] then PEAK[1] - FOOT_OUT[1] else FOOT_OUT[2] - PEAK[1])
		local dy = (middle - PEAK[2]) / (if middle < PEAK[2] then FOOT_ALONG + PEAK[2] else FOOT_ALONG - PEAK[2])
		return (math.abs(dx) ^ power + math.abs(dy) ^ power) ^ (1 / power)
	end
	-- The slope's height: a cone rounded BOWL of the way toward a dome, or
	-- the ridge along the track where that stands higher.
	local function slopeAt(out: number, middle: number): number
		local r = math.clamp((fromSummit(out, middle, 2) - CROWN) / (1 - CROWN), 0, 1)
		local cone = (1 - r) ^ 1.25
		local dome = math.sqrt(1 - r * r)
		local across = math.clamp(1 - (math.abs(out) - RIDGE_FLAT) / (if out > 0 then RIDGE_WIDTH_FAR else RIDGE_WIDTH), 0, 1)
		local along = math.clamp((LINTEL_REACH + RIDGE_PAST - math.abs(middle)) / RIDGE_FALL, 0, 1)
		return math.max(SUMMIT * (cone + (dome - cone) * BOWL), RIDGE * across ^ 0.7 * along)
	end
	-- Stones, by dart throwing: none crowding another, sized by how high
	-- on the slope they sit.
	-- Round each mouth, rows of like-sized stones set so their cells meet
	-- right on the lines the tunnel and bore cut along (the tunnel's walls,
	-- the mouth and the bore's sides), so no cut leaves a thin sliver of a
	-- column: one row just inside the mouth and one between the mouth and
	-- the face, shifted stone by stone so the face has no straight line.
	local stones = {}
	local ROW_SIZE = 2.6
	local rowDepth = (BORE_REACH - LINTEL_REACH) / 2
	local rows = {
		{ LINTEL_REACH - rowDepth, WALL * 2 / 3 },
		{ LINTEL_REACH + rowDepth, BORE * 2 / 3, 1.2 },
	}
	for _, side in { -1, 1 } do
		for _, row in rows do
			local along, spacing, shift = row[1], row[2], row[3] or 0
			for k = -3, 3 do
				table.insert(stones, { k * spacing, side * (along + shift * (random(k + 4, 95 + side) - 0.5)), ROW_SIZE })
			end
		end
	end
	for dart = 1, 4000 do
		local out = FOOT_OUT[1] - 4 + (FOOT_OUT[2] - FOOT_OUT[1] + 8) * random(dart, 91)
		local middle = (FOOT_ALONG + 4) * (2 * random(dart, 92) - 1)
		if fromSummit(out, middle) <= 1.3 then
			local height = math.clamp(slopeAt(out, middle) / SUMMIT, 0, 1)
			local size = (LARGEST + (SMALLEST - LARGEST) * height ^ 0.5) * (0.6 + 0.65 * random(dart, 93))
			local fromOpening = math.sqrt(out * out + (math.abs(middle) - BORE_REACH) ^ 2)
			local midSlope = math.clamp(height / 0.3, 0, 1) * math.clamp((1 - height) / 0.3, 0, 1)
			size *= 1 + (GROW - 1) * midSlope * math.clamp((fromOpening - OPENING_NEAR) / (OPENING_FAR - OPENING_NEAR), 0, 1)
			local clear = true
			for _, other in stones do
				if (out - other[1]) ^ 2 + (middle - other[2]) ^ 2 < ((size + other[3]) * 0.72) ^ 2 then
					clear = false
					break
				end
			end
			if clear then
				table.insert(stones, { out, middle, size })
			end
		end
	end
	-- Stones scattered past the footprint only bound their neighbours'
	-- cells, so the foot ends in the stones' own broken edges rather than a
	-- smooth trimmed wall.
	for index, stone in stones do
		-- Stones round the porches are always built, so each porch has stone
		-- round it out to its front.
		local byPorches = math.abs(stone[1]) < 9 and math.abs(stone[2]) < BORE_REACH + 1
		if fromSummit(stone[1], stone[2]) > 1 and not byPorches then
			continue
		end
		-- The stone's power cell, never reaching more than 1.4 times the
		-- stone's size from it, so a cell at the foot with no stone beyond it
		-- doesn't sprawl.
		local reach = 1.4 * stone[3]
		local cell = { { stone[1] - reach, stone[2] - reach }, { stone[1] + reach, stone[2] - reach }, { stone[1] + reach, stone[2] + reach }, { stone[1] - reach, stone[2] + reach } }
		for other, q in stones do
			if other ~= index and #cell >= 3 and (q[1] - stone[1]) ^ 2 + (q[2] - stone[2]) ^ 2 < (3 * GROW * LARGEST) ^ 2 then
				local limit = (q[1] ^ 2 + q[2] ^ 2 - stone[1] ^ 2 - stone[2] ^ 2 - q[3] ^ 2 + stone[3] ^ 2) / 2
				cell = clipOutline(cell, q[1] - stone[1], q[2] - stone[2], limit)
			end
		end
		if #cell < 3 then
			continue
		end
		-- A column that would reach the plaza's painted ring isn't built, so
		-- the far foot ends in the columns' own outlines.
		local reachesRing = false
		for _, q in cell do
			reachesRing = reachesRing or q[1] > FAR_LIMIT
		end
		if reachesRing then
			continue
		end
		local cellArea, cellOut, cellMiddle = outlineCentre(cell)
		-- Between the mouths a cell splits at the tunnel's walls, its part
		-- over the tunnel standing on the lintels; in front of each mouth the
		-- tunnel bores on through the hill round the porch, the part over it
		-- standing on the porch's roof; the porch sticks out past the hill's
		-- face, its frame covering the bore's edges. The pieces of a cell
		-- share its height and tilt, so they meet flush.
		local inside = clipOutline(clipOutline(cell, 0, 1, LINTEL_REACH), 0, -1, LINTEL_REACH)
		local pieces = {
			{ outline = clipOutline(inside, 1, 0, -WALL), base = -0.5, inside = true },
			{ outline = clipOutline(clipOutline(inside, -1, 0, WALL), 1, 0, WALL), base = LINTEL_TOP - 0.3, inside = true, over = true },
			{ outline = clipOutline(inside, -1, 0, -WALL), base = -0.5, inside = true },
		}
		-- Whole columns decide where the hill ends, so its face follows their
		-- own outlines, and each takes its side of the bore at its own slight
		-- angle: a column reaching in beside the bore wraps round it, the
		-- part over the porch standing on its roof if the column's middle is
		-- short of the face; one wholly past the face stands only beside the
		-- track, clear of the porch's eaves.
		for _, side in { -1, 1 } do
			local front = clipOutline(cell, 0, -side, -LINTEL_REACH)
			if #front < 3 then
				continue
			end
			local lowest, highest = math.huge, -math.huge
			for _, q in front do
				lowest, highest = math.min(lowest, q[2]), math.max(highest, q[2])
			end
			local reachesBore = math.min(math.abs(lowest), math.abs(highest)) < BORE_REACH
			local slantLimit = if reachesBore then BORE_SLANT else PAST_FACE_SLANT
			local least = if reachesBore then BORE else OPEN_HALF + TIMBER.radius + 1.5 + 0.6 * random(index, 8)
			local across = {}
			for n, flank in { -1, 1 } do
				local slant = math.tan(math.rad(slantLimit * (2 * random(index, 8 + n) - 1)))
				local clear = least + math.abs(slant) * (highest - lowest) / 2
				across[flank] = { slant, -clear + slant * (lowest + highest) / 2 }
				local seams = if reachesBore then { { -flank, slant, across[flank][2] } } else nil
				table.insert(pieces, { outline = clipOutline(front, -flank, slant, across[flank][2]), base = -0.5, flank = reachesBore, seams = seams })
			end
			if reachesBore and math.abs(cellMiddle) < BORE_REACH then
				local over = clipOutline(clipOutline(front, 1, -across[1][1], -across[1][2]), -1, -across[-1][1], -across[-1][2])
				local seams = { { 1, -across[1][1], -across[1][2] }, { -1, -across[-1][1], -across[-1][2] } }
				table.insert(pieces, { outline = over, base = BORE_TOP, over = true, seams = seams })
			end
		end
		-- A column stands to the slope halfway between its middle and its
		-- lowest corner, so a broad one on a steep slope doesn't tower over
		-- its neighbours.
		local lowest = math.huge
		for _, q in cell do
			lowest = math.min(lowest, slopeAt(q[1], q[2]))
		end
		local cellRise = (slopeAt(cellOut, cellMiddle) + lowest) / 2 + (random(index, 1) - 0.5) * (1.4 + 0.3 * stone[3])
		-- Bigger stones stand flatter on top: less tilt and cuts that bite
		-- more nearly level (flat 0 for cells of 8 square studs or less, 1
		-- for 20 or more), each still with a gentle break;
		-- the crown's columns keep their tilts so the summit stays a peak.
		local flat = math.clamp((cellArea - 8) / 12, 0, 1) * math.clamp((fromSummit(cellOut, cellMiddle, 2) - 0.1) / 0.25, 0, 1)
		local tilt = 0.6 * (1 - 0.7 * flat)
		local tiltX, tiltY = (random(index, 2) - 0.5) * tilt, (random(index, 3) - 0.5) * tilt
		for p, piece in pieces do
			local outline = piece.outline
			-- Each column pulled in a hairline, so neighbours don't share
			-- their walls' corners.
			if #outline >= 3 then
				local shrunk = outline
				for i, a in outline do
					local b = outline[i % #outline + 1]
					local nx, ny = b[2] - a[2], a[1] - b[1]
					local length = math.sqrt(nx * nx + ny * ny)
					if length > 1e-6 then
						shrunk = clipOutline(shrunk, nx / length, ny / length, (nx * a[1] + ny * a[2]) / length - 0.01)
					end
				end
				outline = shrunk
			end
			local area, cx, cy = outlineCentre(outline)
			if #outline < 3 or area < 0.5 then
				continue
			end
			local key = index * 7 + p
			local rise = math.max(MIN_LENGTH * (0.8 + 0.4 * random(index, 5)), cellRise)
			-- Over the tunnel and the porches, and beside them, the stone
			-- stands clear of the lintels and roofs.
			if piece.over then
				rise = math.max(rise, piece.base + 4 + random(key, 6))
			elseif (piece.inside or piece.flank) and math.abs(cx) < BORE + 3 then
				rise = math.max(rise, LINTEL_TOP + 0.8 + random(key, 6))
			end
			-- The columns right beside each opening stop a little above the
			-- porch's roof, so the opening isn't framed by two tall pillars
			-- and the full height of the hill starts one column further back.
			if not piece.over and math.abs(cx) < BORE + FLANK_NEAR and math.abs(cellMiddle) > LINTEL_REACH - FLANK_BACK then
				rise = math.min(rise, BORE_TOP + FLANK_ABOVE * (0.6 + 0.8 * random(key, 7)))
			end
			local corners = {}
			for i, corner in outline do
				corners[i] = { corner[1], corner[2], rise + (corner[1] - cellOut) * tiltX + (corner[2] - cellMiddle) * tiltY }
			end
			local peak = { cx, cy, rise + (cx - cellOut) * tiltX + (cy - cellMiddle) * tiltY }
			-- The column as a closed solid, faces wound outward.
			local faces = {}
			local count = #corners
			local foot = {}
			for i = count, 1, -1 do
				table.insert(foot, { corners[i][1], corners[i][2], piece.base })
			end
			table.insert(faces, foot)
			for i = 1, count do
				local a, b = corners[i], corners[i % count + 1]
				table.insert(faces, { { a[1], a[2], piece.base }, { b[1], b[2], piece.base }, { b[1], b[2], b[3] }, { a[1], a[2], a[3] } })
				table.insert(faces, { peak, a, b })
			end
			-- Chisel cuts, then fine chips: each faces out from the summit
			-- within CUT_SPREAD and up at its own angle, biting a set depth
			-- in from the farthest point along it. By the porches none faces
			-- a mouth, so the porch boards keep stone behind them.
			local outward = math.atan2(cy - PEAK[2], cx - PEAK[1])
			local cuts = {}
			for k = 1, 1 + math.floor(random(key, 40) * MAX_CUTS) do
				table.insert(cuts, { outward + (random(key, 40 + k) - 0.5) * 2 * CUT_SPREAD, 0.72 + 0.1 * flat + random(key, 50 + k) * 0.3 * (1 - 0.5 * flat), stone[3] * (CUT_DEPTH[1] + (CUT_DEPTH[2] - CUT_DEPTH[1]) * random(key, 60 + k)) })
			end
			for k = 1, CHIPS[1] + math.floor(random(key, 70) * (CHIPS[2] - CHIPS[1] + 1)) do
				table.insert(cuts, { outward + (random(key, 70 + k) - 0.5) * 2 * CUT_SPREAD, 0.6 + 0.1 * flat + random(key, 80 + k) * 0.45 * (1 - 0.5 * flat), CHIP_DEPTH[1] + (CHIP_DEPTH[2] - CHIP_DEPTH[1]) * random(key, 90 + k) })
			end
			for _, cut in cuts do
				local heading, lift, depth = cut[1], cut[2], cut[3]
				local n = { math.cos(heading) * math.cos(lift), math.sin(heading) * math.cos(lift), math.sin(lift) }
				if piece.inside and math.abs(cx) < 8.5 and math.abs(cy) > LINTEL_REACH - 4 and n[2] * cy > 0 then
					n[2] = -n[2]
				end
				local farthest = -math.huge
				for _, face in faces do
					for _, q in face do
						farthest = math.max(farthest, q[1] * n[1] + q[2] * n[2] + q[3] * n[3])
					end
				end
				-- A cut stays clear of the column's whole foot, so the column
				-- still stands on its full outline (and the porch boards keep
				-- stone behind them); over a porch it leaves the face above the
				-- roof standing upright for a few studs, so no wedge opens
				-- between the roof and the stone.
				local footMost = -math.huge
				for _, corner in corners do
					footMost = math.max(footMost, corner[1] * n[1] + corner[2] * n[2] + piece.base * n[3])
				end
				local plane = math.max(farthest - depth, footMost + (if piece.over then 3 else 0.4))
				if plane < farthest then
					-- A cut whose cap fails to close (a sliver) is left out.
					local carved = carveSolid(faces, n, plane)
					if isClosed(carved) then
						faces = carved
					end
				end
			end
			-- Top edges chamfered unevenly and sub-chamfered, all but those
			-- along a line the cell was split on (where its pieces meet flush,
			-- or the tunnel and bore are cut).
			local function onSplit(a, b): boolean
				local function same(i, values)
					for _, value in values do
						if math.abs(a[i] - value) < 0.05 and math.abs(b[i] - value) < 0.05 then
							return true
						end
					end
					return false
				end
				for _, seam in piece.seams or {} do
					local length = math.sqrt(seam[1] ^ 2 + seam[2] ^ 2)
					local function off(q)
						return math.abs(seam[1] * q[1] + seam[2] * q[2] - seam[3]) / length
					end
					if off(a) < 0.05 and off(b) < 0.05 then
						return true
					end
				end
				return same(1, { -WALL, WALL }) or same(2, { -LINTEL_REACH, LINTEL_REACH })
			end
			local function bevel(n, depth)
				local farthest = -math.huge
				for _, face in faces do
					for _, q in face do
						farthest = math.max(farthest, q[1] * n[1] + q[2] * n[2] + q[3] * n[3])
					end
				end
				local footMost = -math.huge
				for _, corner in corners do
					footMost = math.max(footMost, corner[1] * n[1] + corner[2] * n[2] + piece.base * n[3])
				end
				local plane = math.max(farthest - depth, footMost + (if piece.over then 3 else 0.4))
				if plane < farthest then
					local carved = carveSolid(faces, n, plane)
					if isClosed(carved) then
						faces = carved
					end
				end
			end
			-- Upright corners chamfered unevenly, each bevel leaning in a
			-- little so it is widest at the top and runs out a couple of
			-- studs down: below that the corner stays whole, so where
			-- columns meet the seam stays sealed.
			for i, v in outline do
				local p, q = outline[(i - 2) % #outline + 1], outline[i % #outline + 1]
				local ax, ay = v[2] - p[2], p[1] - v[1]
				local bx, by = q[2] - v[2], v[1] - q[1]
				local la, lb = math.sqrt(ax * ax + ay * ay), math.sqrt(bx * bx + by * by)
				if la > 0.3 and lb > 0.3 and not onSplit(p, v) and not onSplit(v, q) then
					local nx, ny = ax / la + bx / lb, ay / la + by / lb
					local ln = math.sqrt(nx * nx + ny * ny)
					local lift = math.rad(CORNER_LEAN[1] + (CORNER_LEAN[2] - CORNER_LEAN[1]) * random(key, 140 + i))
					local width = CHAMFER[1] + (CHAMFER[2] - CHAMFER[1]) * random(key, 100 + i)
					bevel({ nx / ln * math.cos(lift), ny / ln * math.cos(lift), math.sin(lift) }, width)
				end
			end
			for i, a in outline do
				local b = outline[i % #outline + 1]
				local ex, ey = b[2] - a[2], a[1] - b[1]
				local length = math.sqrt(ex * ex + ey * ey)
				if length > 0.3 and not onSplit(a, b) then
					ex, ey = ex / length, ey / length
					local width = CHAMFER[1] + (CHAMFER[2] - CHAMFER[1]) * random(key, 160 + i)
					local lean = math.rad(45) + (random(key, 190 + i) - 0.5) * 2 * CHAMFER_LEAN
					bevel({ ex * math.cos(lean), ey * math.cos(lean), math.sin(lean) }, width * 0.7)
					-- The sub-chamfers stay steep enough to read as edges, and
					-- deep enough not to leave slivers.
					if width > 0.22 then
						for _, turn in { -1, 1 } do
							local subLean = math.min(lean + turn * math.rad(20), math.rad(62))
							bevel({ ex * math.cos(subLean), ey * math.cos(subLean), math.sin(subLean) }, width * 0.7 * SUB_CHAMFER)
						end
					end
				end
			end
			-- Chips knocked off the top's corners and along its edges, each
			-- its own size and angle: a corner chip faces out along the
			-- corner's bisector, an edge chip out from the edge but swung
			-- along it, so it takes a tapering bite toward one end.
			local count = #outline
			for i, v in outline do
				local p, q = outline[(i - 2) % count + 1], outline[i % count + 1]
				local ax, ay = v[2] - p[2], p[1] - v[1]
				local bx, by = q[2] - v[2], v[1] - q[1]
				local la, lb = math.sqrt(ax * ax + ay * ay), math.sqrt(bx * bx + by * by)
				if la > 0.3 and lb > 0.3 and not onSplit(p, v) and not onSplit(v, q) and random(key, 220 + i) < CORNER_CHIPS then
					local nx, ny = ax / la + bx / lb, ay / la + by / lb
					local ln = math.sqrt(nx * nx + ny * ny)
					local lift = math.rad(35 + 25 * random(key, 240 + i))
					local depth = CHIP_SIZE[1] + (CHIP_SIZE[2] - CHIP_SIZE[1]) * random(key, 260 + i)
					bevel({ nx / ln * math.cos(lift), ny / ln * math.cos(lift), math.sin(lift) }, depth)
				end
				if lb > 0.8 and not onSplit(v, q) and random(key, 280 + i) < EDGE_CHIPS then
					local ox, oy, ex, ey = bx / lb, by / lb, (q[1] - v[1]) / lb, (q[2] - v[2]) / lb
					local swing = math.rad(35 + 20 * random(key, 300 + i)) * (if random(key, 320 + i) < 0.5 then -1 else 1)
					local hx, hy = ox * math.cos(swing) + ex * math.sin(swing), oy * math.cos(swing) + ey * math.sin(swing)
					local lift = math.rad(30 + 25 * random(key, 340 + i))
					local depth = CHIP_SIZE[1] + (CHIP_SIZE[2] - CHIP_SIZE[1]) * random(key, 360 + i)
					bevel({ hx * math.cos(lift), hy * math.cos(lift), math.sin(lift) }, depth * 0.8)
				end
			end
			local low, high = { math.huge, math.huge }, { -math.huge, -math.huge }
			for _, q in outline do
				low = { math.min(low[1], q[1]), math.min(low[2], q[2]) }
				high = { math.max(high[1], q[1]), math.max(high[2], q[2]) }
			end
			table.insert(BLOCKS, { cx, cy, piece.base, high[1] - low[1], high[2] - low[2], rise - piece.base, 0, 0, 0, false, nil, nil, faces })
		end
	end
end
local ROCK = { 0.52, 0.54, 0.6 }

-- The highlight band's reach from an edge, in studs, its strength, and how
-- far from a corner its strokes taper away.
local ROCK_EDGE, ROCK_LIT, ROCK_TAPER = 0.6, 1.8, 0.8
-- A wide, very soft highlight under the rims: how strong at an edge, how
-- many studs it fades out over at its widest (rocks, then pebbles), how far
-- its width wanders along the edge, and the studs it thins over away from
-- a corner.
local ROCK_GLOW, ROCK_GLOW_EDGE, PEBBLE_GLOW_EDGE = 0.22, 2.2, 0.5
local ROCK_GLOW_UNEVEN, ROCK_GLOW_TAPER = 0.65, 2
-- Chunks are small, so their rims are narrower and fainter.
local PEBBLE_EDGE, PEBBLE_LIT = 0.25, 0.7

-- Which block a texel is on. As each block is built, points are scattered
-- over its faces about SAMPLE apart into a grid of SAMPLE_CELL cells, each
-- point tagged with its block; a texel lies on its own block's surface, so
-- the nearest point on a face turned the same way names it. Most cells hold
-- one block's points, so the search only runs where blocks meet.
local SAMPLE, SAMPLE_CELL = 0.35, 0.5
local blockSamples = {}
local function sampleCell(x: number, y: number, z: number): string
	return `{math.floor(x / SAMPLE_CELL)},{math.floor(y / SAMPLE_CELL)},{math.floor(z / SAMPLE_CELL)}`
end
local function sampleBlock(m, n: number)
	local vec = EditMesh.vec
	for id, face in m.faces do
		local normal = m:faceNormal(id)
		local a = m.verts[face.verts[1]].position
		for k = 2, #face.verts - 1 do
			local b, c = m.verts[face.verts[k]].position, m.verts[face.verts[k + 1]].position
			local longest = math.max(vec.length(vec.sub(b, a)), vec.length(vec.sub(c, a)), vec.length(vec.sub(c, b)))
			local steps = math.max(1, math.ceil(longest / SAMPLE))
			for i = 0, steps do
				for j = 0, steps - i do
					local p = vec.add(a, vec.add(vec.scale(vec.sub(b, a), i / steps), vec.scale(vec.sub(c, a), j / steps)))
					local key = sampleCell(p[1], p[2], p[3])
					local cell = blockSamples[key]
					if not cell then
						cell = { blocks = {}, points = {} }
						blockSamples[key] = cell
					end
					cell.blocks[n] = true
					table.insert(cell.points, { p[1], p[2], p[3], n, normal })
				end
			end
		end
	end
end

-- The texel's place in block n (-1..1 each way: out, along, up), in the
-- block's own frame, with its lean undone.
local function blockFrame(n: number, x: number, y: number, z: number): (number, number, number)
	local blockOut, blockMiddle, base, w, d, h, turn, leanOut, leanAlong = table.unpack(BLOCKS[n])
	-- The block's frame runs along toward the -CAVE_HALF mouth.
	local dx = math.sqrt(x * x + y * y) - TRACK_RADIUS - blockOut
	local dy = blockMiddle - math.deg(math.atan2(y, x)) / DEGREES_PER_STUD
	local c, s = math.cos(math.rad(turn)), math.sin(math.rad(turn))
	local u = dx * c + dy * s - math.tan(math.rad(leanOut)) * (z - base)
	local v = dy * c - dx * s - math.tan(math.rad(leanAlong)) * (z - base)
	return math.clamp(u / (w / 2), -1, 1), math.clamp(v / (d / 2), -1, 1), math.clamp((z - base - h / 2) / (h / 2), -1, 1)
end

local function blockAt(x: number, y: number, z: number, nx: number, ny: number, nz: number): number?
	local cx, cy, cz = math.floor(x / SAMPLE_CELL), math.floor(y / SAMPLE_CELL), math.floor(z / SAMPLE_CELL)
	local home = blockSamples[`{cx},{cy},{cz}`]
	if home then
		local only = next(home.blocks)
		if next(home.blocks, only) == nil then
			return only
		end
	end
	-- The nearest point on a face turned the texel's way, else the nearest.
	local best, nearest, anyBest, any = math.huge, nil, math.huge, nil
	for ix = cx - 1, cx + 1 do
		for iy = cy - 1, cy + 1 do
			for iz = cz - 1, cz + 1 do
				local cell = blockSamples[`{ix},{iy},{iz}`]
				if cell then
					for _, p in cell.points do
						local d = (p[1] - x) ^ 2 + (p[2] - y) ^ 2 + (p[3] - z) ^ 2
						if d < anyBest then
							anyBest, any = d, p[4]
						end
						if d < best and p[5][1] * nx + p[5][2] * ny + p[5][3] * nz > 0.5 then
							best, nearest = d, p[4]
						end
					end
				end
			end
		end
	end
	return nearest or any
end

-- Blue-grey stone, each block its own gradient: darker and cooler at its
-- foot, lighter at its top, the shade running its own way (tilted a little
-- off upright), as strong (about a quarter either way) and as warm or cool
-- as that block has it. Broad soft patches over it, and tops a little lighter.
local function rockPaint(x: number, y: number, z: number, nx: number, ny: number, nz: number): (number, number, number)
	-- Chunks aren't sampled: the first block's tones, shaded by height alone.
	local n = blockAt(x, y, z, nx, ny, nz)
	local shade
	if n then
		local u, v, t = blockFrame(n, x, y, z)
		shade = 0.8 * t + 0.35 * jitter(n, 21) * u + 0.35 * jitter(n, 22) * v
	else
		n, shade = 1, math.clamp(z / 0.5 - 1, -1, 1)
	end
	-- Feet darken a fifth more than tops lighten; small blocks a stronger
	-- gradient, so they stand apart from the big ones behind them.
	if shade < 0 then
		shade *= 1.2
	end
	local _out, _middle, _base, w, d, h = table.unpack(BLOCKS[n])
	local strength = 0.24 + 0.05 * jitter(n, 23) + (if math.min(w, d, h) < 3 then 0.06 else 0)
	local k = (0.94 + 0.06 * math.noise(x / 3, y / 3, z / 3)) * (1 + 0.12 * jitter(n, 5)) * (1 + strength * shade)
	if nz > 0.6 then
		k *= 1.08
	end
	local warm = 0.03 * jitter(n, 9) + 0.03 * shade * (0.5 + 0.5 * jitter(n, 24))
	return (ROCK[1] + warm) * k, ROCK[2] * k, (ROCK[3] - warm) * k
end
-- The last part added gets bold, fully loaded highlight strokes on its
-- edges, tinted toward a lighter stone, full width at the corners and
-- tapering along each edge.
local function boldRims()
	parts[#parts].painted = true
	parts[#parts].blend = 0.65
	parts[#parts].taper = ROCK_TAPER
	parts[#parts].softLit = ROCK_GLOW
	parts[#parts].softEdge = ROCK_GLOW_EDGE
	parts[#parts].softUneven = ROCK_GLOW_UNEVEN
	parts[#parts].softTaper = ROCK_GLOW_TAPER
end

-- How each kind of block is cut by plane slicing, the way stylized rocks
-- are chipped: one big slab cut `slab` studs deep
-- across its top, `tops` more shallow cuts break the rest into facets,
-- `chips` small cuts take bites out of the edges, and on a third of the
-- taller blocks a corner of the top is stepped down `notch` studs.
local CUTS = {
	rock = { slab = 0.8, tops = 2, chips = 3, notch = 1 },
	lintel = { slab = 0, tops = 1, chips = 2, notch = 0 },
	chunk = { slab = 0.3, tops = 3, chips = 1, notch = 0 },
}

-- One cut: a plane tangent at a point (along unit direction u) of the
-- ellipsoid with radii r about `centre`, moved `depth` inward; every point
-- past it (and, when `reach` is set, within reach of the touching point)
-- pressed back onto it. Pressing keeps the mesh as it is, faces flattened.
local function slice(m, centre, r, u, depth: number, reach: number?)
	local vec = EditMesh.vec
	local touch = vec.add(centre, { r[1] * u[1], r[2] * u[2], r[3] * u[3] })
	local normal = vec.unit({ u[1] / r[1], u[2] / r[2], u[3] / r[3] })
	m:transform(function(p)
		local over = vec.dot(vec.sub(p, touch), normal) + depth
		if over <= 0 or (reach and vec.length(vec.sub(p, touch)) > reach) then
			return p
		end
		return vec.sub(p, vec.scale(normal, over))
	end)
end

-- One block n: its outline (convex, counter-clockwise, about its middle)
-- raised h tall in bands, every edge chamfered unevenly (the outline pulled
-- in by each side's own depth, then each side and the top and bottom
-- pushed back out by their depth and inset by their own width, so each
-- chamfer is wider on one side and slopes off at its own angle), then cut
-- by plane slicing as its kind says, and given a slight taper. A
-- `grounded` one has its underside pressed flat so it sits flat on the
-- ground. No cut faces `mouth` (a direction in the block's frame), so the
-- side a porch's boards rest on stays whole.
local function stoneBlock(n: number, outline, h: number, kind: string, grounded: boolean, mouth: { number }?)
	local vec = EditMesh.vec
	local cuts = CUTS[kind]
	local low, high = { math.huge, math.huge }, { -math.huge, -math.huge }
	for _, p in outline do
		low = { math.min(low[1], p[1]), math.min(low[2], p[2]) }
		high = { math.max(high[1], p[1]), math.max(high[2], p[2]) }
	end
	local narrow = math.min(high[1] - low[1], high[2] - low[2])
	local size = math.min(narrow, h)
	local chamfer = math.min((if kind == "rock" then 0.12 elseif h < 4.5 then 0.2 else 0.12) * narrow * (1 + 0.25 * jitter(n, 13)), 0.2 * h)
	-- Each side's depth and its outward direction; the outline pulled in.
	local sides, inner = {}, outline
	for i, p in outline do
		local q = outline[i % #outline + 1]
		local dx, dy = q[1] - p[1], q[2] - p[2]
		local length = math.sqrt(dx * dx + dy * dy)
		local normal = { dy / length, -dx / length }
		local depth = chamfer * (1 + 0.5 * jitter(n, 30 + i))
		table.insert(sides, { normal = normal, depth = depth, length = length })
		inner = clipOutline(inner, normal[1], normal[2], normal[1] * p[1] + normal[2] * p[2] - depth)
	end
	local top, bottom = chamfer * (1 + 0.5 * jitter(n, 28)), chamfer * (1 + 0.5 * jitter(n, 29))
	-- The prism: rings of the pulled-in outline up its height.
	local m = EditMesh.new()
	local z0, z1 = -h / 2 + bottom, h / 2 - top
	local bands = math.max(1, math.round((z1 - z0) / BAND))
	local rings = {}
	for k = 0, bands do
		local z = z0 + (z1 - z0) * k / bands
		rings[k] = {}
		for i, p in inner do
			rings[k][i] = m:addVertex(p[1], p[2], z)
		end
	end
	-- Each side's faces and each cap's, kept to inset exactly those.
	local count = #inner
	local sideFaces = {}
	for i = 1, count do
		sideFaces[i] = {}
		local j = i % count + 1
		for k = 0, bands - 1 do
			table.insert(sideFaces[i], m:addFace({ rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i] }))
		end
	end
	-- The caps, as a fan of quads (and one triangle when the sides are odd)
	-- round a middle point.
	local _area, cx, cy = outlineCentre(inner)
	local capFaces = { top = {}, bottom = {} }
	for _, cap in { { ring = rings[bands], z = z1, up = true }, { ring = rings[0], z = z0, up = false } } do
		local ring = cap.ring
		local made = if cap.up then capFaces.top else capFaces.bottom
		local function face(ids)
			if not cap.up then
				local flipped = {}
				for k = #ids, 1, -1 do
					table.insert(flipped, ids[k])
				end
				ids = flipped
			end
			table.insert(made, m:addFace(ids))
		end
		if count <= 4 then
			face(table.clone(ring))
		else
			local middle = m:addVertex(cx, cy, cap.z)
			local i = 1
			while i <= count do
				if i + 1 <= count then
					face({ middle, ring[i], ring[i + 1], ring[(i + 1) % count + 1] })
					i += 2
				else
					face({ middle, ring[i], ring[1] })
					i += 1
				end
			end
		end
	end
	-- The chamfers: each side, the top and the bottom pushed back out to the
	-- outline by its depth and inset by its own width, never past a third of
	-- the face.
	-- A pulled-in side that vanished (a short edge between two deep ones)
	-- has no faces; the others are matched by the way they face.
	for i, side in sides do
		local facing = { side.normal[1], side.normal[2], 0 }
		local ids = nil
		for k, faces in sideFaces do
			if #faces > 0 and EditMesh.vec.dot(m:faceNormal(faces[1]), facing) > 0.999 then
				ids = faces
				sideFaces[k] = {}
				break
			end
		end
		if ids then
			local width = math.min(side.depth * (1 + 0.35 * jitter(n, 40 + i)), side.length / 3, (z1 - z0) / 3)
			m:inset(m:select("face", "ids", ids), width, side.depth)
		end
	end
	m:inset(m:select("face", "ids", capFaces.top), math.min(top * (1 + 0.35 * jitter(n, 47)), narrow / 3), top)
	m:inset(m:select("face", "ids", capFaces.bottom), math.min(bottom * (1 + 0.35 * jitter(n, 48)), narrow / 3), bottom)
	-- Plane slicing. The top cuts touch an ellipsoid round the block's top
	-- (as wide as the block, as tall as it is wide or the block's height,
	-- whichever is less), from directions tipped 25 to 55 degrees off
	-- upright; the chips touch one round a spot up the block's side, from
	-- near-level directions, and reach only a little way.
	local function awayFromMouth(u)
		if mouth and u[1] * mouth[1] + u[2] * mouth[2] > 0 then
			return { -u[1], -u[2], u[3] }
		end
		return u
	end
	local half = { (high[1] - low[1]) / 2, (high[2] - low[2]) / 2 }
	local centre = { (high[1] + low[1]) / 2, (high[2] + low[2]) / 2 }
	local capTall = math.min(h / 2, 1.2 * math.max(half[1], half[2]))
	local cap = { centre[1], centre[2], h / 2 - capTall }
	for k = 0, cuts.tops do
		-- Cut 0 is the slab: 45 to 55 degrees, deep. The rest are shallow,
		-- set out past the ellipsoid so they only shave.
		local around = math.pi * jitter(n, 100 + k)
		local tip = math.rad(if k == 0 then 50 + 5 * jitter(n, 110) else 40 + 15 * jitter(n, 110 + k))
		local u = awayFromMouth({ math.sin(tip) * math.cos(around), math.sin(tip) * math.sin(around), math.cos(tip) })
		local depth = if k == 0 then math.min(cuts.slab * (1 + 0.25 * jitter(n, 120)), 0.3 * h) - 0.25 * size else -0.25 * size + 0.1 * jitter(n, 120 + k)
		if k > 0 or cuts.slab > 0 then
			slice(m, cap, { half[1], half[2], capTall }, u, depth)
		end
	end
	-- The notch: a near-level cut at a top corner, only that corner, so it
	-- steps down.
	if cuts.notch > 0 and h > 4 and jitter(n, 125) > 0.33 then
		local toward = awayFromMouth({ math.cos(math.pi * jitter(n, 126)), math.sin(math.pi * jitter(n, 126)), 0 })
		local corner = { centre[1] + half[1] * toward[1], centre[2] + half[2] * toward[2], h / 2 }
		slice(m, corner, { 1, 1, 1 }, { 0, 0, 1 }, cuts.notch, 0.35 * narrow)
	end
	for k = 1, cuts.chips + math.floor(h / 6) do
		local around = math.pi * jitter(n, 130 + k)
		local tip = math.rad(90 + 25 * jitter(n, 140 + k))
		local u = awayFromMouth({ math.sin(tip) * math.cos(around), math.sin(tip) * math.sin(around), math.cos(tip) })
		local at = { centre[1], centre[2], (h / 2 - 0.6) * jitter(n, 150 + k) }
		slice(m, at, { half[1], half[2], math.min(half[1], half[2]) }, u, -0.04 * size, (0.35 + 0.15 * jitter(n, 160 + k)) * narrow)
	end
	-- A slight taper and a little unevenness.
	local taper = 0.03 + 0.03 * jitter(n, 80)
	m:transform(function(p)
		local k = 1 - taper * (p[3] / h + 0.5)
		local s = 0.02 * size
		return {
			p[1] * k + s * math.noise(p[1] / size + n, p[2] / size, p[3] / size),
			p[2] * k + s * math.noise(p[1] / size, p[2] / size + n, p[3] / size),
			p[3] + s * math.noise(p[1] / size, p[2] / size, p[3] / size + n),
		}
	end)
	if grounded then
		-- Everything below a plane above the bottom chamfer pressed flat
		-- onto it, then stretched back down so that plane is its base and
		-- its top stays put.
		local floor = math.min(0.3 * size, 0.6) - h / 2
		m:transform(function(p)
			return { p[1], p[2], -h / 2 + (math.max(p[3], floor) - floor) * h / (h / 2 - floor) }
		end)
	end
	faceOut(m)
	return m
end

-- A block leaned by shearing (so its base stays flat), turned, and set in
-- place.
local function placedBlock(m, n: number, block)
	local out, middle, base, _w, _d, h, turn, leanOut, leanAlong = table.unpack(block)
	local tanOut, tanAlong = math.tan(math.rad(leanOut)), math.tan(math.rad(leanAlong))
	m:transform(function(p)
		return { p[1] + tanOut * (p[3] + h / 2), p[2] + tanAlong * (p[3] + h / 2), p[3] }
	end)
	m:select("vertex", "all"):rotate({ 0, 0, 1 }, turn, { 0, 0, 0 })
	placed(m, 1, out, HALF_LENGTH - middle, base, h)
	sampleBlock(m, n)
	return m
end

part("Lintels", nil, ROCK, function(mesh)
	for n, block in BLOCKS do
		if block[10] then
			placedBlock(stoneBlock(n, block[11], block[6], "lintel", false, block[12]), n, block):emit(mesh)
		end
	end
end, nil, rockPaint, nil, nil, true, ROCK_EDGE, nil, ROCK_LIT)
boldRims()

-- A column's carved faces, set along the track's curve and sampled for
-- the paint.
local function emitColumn(mesh, n: number, faces)
	local vec = EditMesh.vec
	for _, face in faces do
		local points, ids = {}, {}
		for k, p in face do
			points[k] = caveAt(1, p[1], p[3], HALF_LENGTH - p[2])
			ids[k] = mesh:vertex(table.unpack(points[k]))
		end
		mesh:face(ids)
		-- Points over the face for which block a texel is on.
		local normal = vec.cross(vec.sub(points[2], points[1]), vec.sub(points[3], points[1]))
		if vec.length(normal) > 1e-9 then
			normal = vec.unit(normal)
			local a = points[1]
			for k = 2, #points - 1 do
				local b, c = points[k], points[k + 1]
				local longest = math.max(vec.length(vec.sub(b, a)), vec.length(vec.sub(c, a)), vec.length(vec.sub(c, b)))
				local steps = math.max(1, math.ceil(longest / SAMPLE))
				for i = 0, steps do
					for j = 0, steps - i do
						local p = vec.add(a, vec.add(vec.scale(vec.sub(b, a), i / steps), vec.scale(vec.sub(c, a), j / steps)))
						local key = sampleCell(p[1], p[2], p[3])
						local cell = blockSamples[key]
						if not cell then
							cell = { blocks = {}, points = {} }
							blockSamples[key] = cell
						end
						cell.blocks[n] = true
						table.insert(cell.points, { p[1], p[2], p[3], n, normal })
					end
				end
			end
		end
	end
end

-- The columns go in four parts, one per quarter of the hill (hub or far
-- side, either half along), so each part's texture stays within 1024
-- texels square at the item's texel density.
local function columnQuarter(block): number
	return (if block[1] < 0 then 1 else 2) + (if block[2] < 0 then 0 else 2)
end
for quarter = 1, 4 do
	part(`Rocks{quarter}`, nil, ROCK, function(mesh)
		for n, block in BLOCKS do
			if block[13] and columnQuarter(block) == quarter then
				emitColumn(mesh, n, block[13])
			end
		end
		-- Twice the contact shadow, so the joints between columns go dark.
	end, nil, rockPaint, nil, nil, true, ROCK_EDGE, 2, ROCK_LIT)
	boldRims()
end

-- ------------------------------------------------------------ the porches

-- Along from each mouth (negative is out in front): the back posts stand
-- just before the boards, the front posts PORCH_DEPTH further out.
local POST_RADIUS = TIMBER.radius
local POST_OUT = OPEN_HALF + POST_RADIUS
local BACK_POSTS, FRONT_POSTS = -0.75, -0.75 - 3.4
local BEAM = TIMBER.beam
local HEADER_TOP = OPEN_TALL + BEAM
local SIDE_TOP = HEADER_TOP + 0.7
local DECK_THICK, DECK_PLANK = 0.45, 0.9
local DECK_FROM, DECK_TO = FRONT_POSTS - 0.7, BACK_POSTS + 0.5
local BOARDS_AT, BOARD_THICK, BOARD_WIDE = -0.25, 0.35, 0.8
local WOOD = { 0.66, 0.38, 0.2 }

-- Wood: each piece `index` its own shade, with grain lines along `grain`
-- (TIMBER.grain sets their contrast) and now and then a dark crack running
-- with the grain.
local function wood(index: number, grain: number, x: number, y: number, z: number, spread: number?): (number, number, number)
	local k = 0.9 + (spread or 0.12) * jitter(index, 3) + 0.05 * math.noise(x / 2, y / 2, z / 2)
	if math.abs(math.sin(grain * 6 + 1.5 * math.noise(x * 0.7, y * 0.7, z * 0.7))) < 0.14 then
		k -= 0.09 * TIMBER.grain
	end
	if math.abs(math.sin(grain * 2.3 + 0.8 * math.noise(x * 0.4, y * 0.4, index))) < 0.02 * TIMBER.cracks and math.noise(x * 0.9, y * 0.9, z * 0.9 + index) > 0.15 then
		k -= 0.35
	end
	return WOOD[1] * k, WOOD[2] * k, WOOD[3] * k
end
-- A cut end's rings: lighter heartwood rings round the log's middle, `r`
-- studs out from it.
local function rings(index: number, r: number): (number, number, number)
	local k = 1.05 + 0.08 * jitter(index, 5) - 0.12 * (if math.sin(r * 14) > 0.6 then 1 else 0)
	return WOOD[1] * 1.12 * k, WOOD[2] * 1.15 * k, WOOD[3] * 1.15 * k
end
-- Hand-hewn timber: every point pushed a little off true by smooth noise
-- (`seed` per piece), so posts and beams wander and their faces undulate.
local function hewn(m, seed: number)
	return m:transform(function(p)
		local w, h = TIMBER.wander, TIMBER.hewn
		return {
			p[1] + w * math.noise(p[3] * 0.25, seed, 0.3) + h * math.noise(p[1] * 1.7, p[2] * 1.7 + seed, p[3] * 1.7),
			p[2] + w * math.noise(p[3] * 0.25, seed, 5.1) + h * math.noise(p[1] * 1.7 + 3.1, p[2] * 1.7, p[3] * 1.7 + seed),
			p[3] + h * 0.5 * math.noise(p[1] * 1.3 + seed, p[2] * 1.3, p[3] * 1.3),
		}
	end)
end
-- Worn timber: soft light strokes along the edges, thinning away from the
-- corners.
local function wornEdges()
	parts[#parts].blend = 0.8
	parts[#parts].taper = 0.5
end

part("Posts", nil, WOOD, function(mesh)
	for _, side in { -1, 1 } do
		for _, along in { BACK_POSTS, FRONT_POSTS } do
			for _, flank in { -1, 1 } do
				local seed = along * 10 + flank * 3 + side * 7
				local m = EditMesh.cone(POST_RADIUS * TIMBER.taper, POST_RADIUS, OPEN_TALL + 0.3, 12, 6)
				m:select("vertex", "all"):rotate({ 0, 0, 1 }, 1.5 * jitter(along * 10, flank + side * 3), { 0, 0, 0 })
				hewn(m, seed)
				placed(m, side, flank * POST_OUT, along, -0.3, OPEN_TALL + 0.3):emit(mesh)
			end
		end
	end
end, nil, function(x, y, z)
	local out, along = caveOf(x, y)
	return wood(math.floor(out) + math.floor(along) * 7, z, x, y, z)
end, nil, nil, true, nil, nil, TIMBER.worn)
wornEdges()

-- How far a beam end sticks out past the post or beam it sits on.
local HEADER_LENGTH = 2 * POST_OUT + 1.6
local SIDE_LENGTH = BACK_POSTS - FRONT_POSTS + 1.4
part("Beams", nil, WOOD, function(mesh)
	for _, side in { -1, 1 } do
		-- A header across each pair of posts, and a side beam along each
		-- side on top of them.
		for _, along in { BACK_POSTS, FRONT_POSTS } do
			local m = EditMesh.roundedBox({ HEADER_LENGTH, BEAM, BEAM }, TIMBER.round, 1, { 8, 2, 2 })
			hewn(m, along * 3 + side)
			placed(m, side, 0, along, OPEN_TALL, BEAM):emit(mesh)
		end
		for _, flank in { -1, 1 } do
			local m = EditMesh.roundedBox({ BEAM, SIDE_LENGTH, 0.7 }, TIMBER.round, 1, { 2, 6, 2 })
			hewn(m, flank * 5 + side * 11)
			placed(m, side, flank * POST_OUT, (BACK_POSTS + FRONT_POSTS) / 2, HEADER_TOP, 0.7):emit(mesh)
		end
	end
end, nil, function(x, y, z)
	local out, along = caveOf(x, y)
	-- Cut ends show their rings.
	if z < HEADER_TOP and math.abs(out) > HEADER_LENGTH / 2 - 0.15 then
		local middle = if math.abs(along - BACK_POSTS) < math.abs(along - FRONT_POSTS) then BACK_POSTS else FRONT_POSTS
		return rings(math.floor(along * 2), math.sqrt((along - middle) ^ 2 + (z - OPEN_TALL - BEAM / 2) ^ 2))
	end
	if z > HEADER_TOP and math.abs(along - (BACK_POSTS + FRONT_POSTS) / 2) > SIDE_LENGTH / 2 - 0.15 then
		return rings(math.floor(out), math.sqrt((math.abs(out) - POST_OUT) ^ 2 + (z - HEADER_TOP - 0.35) ^ 2))
	end
	local index = if z > HEADER_TOP then math.floor(out) else math.floor(along * 2)
	return wood(index + 40, if z > HEADER_TOP then along else out, x, y, z)
end, nil, nil, true, nil, nil, TIMBER.worn)
wornEdges()

-- The deck: planks laid across the side beams, side by side out to the
-- front, each a little different in length, set and tilt, their ends
-- roughly sawn.
local function deckPlanks(): { { number } }
	local planks = {}
	local n = math.floor((DECK_TO - DECK_FROM) / DECK_PLANK)
	for i = 1, n do
		local along = DECK_FROM + (i - 0.5) * (DECK_TO - DECK_FROM) / n
		local length = 2 * POST_OUT + 2 + (0.5 + 2 * TIMBER.wander) * jitter(i, 1)
		table.insert(planks, { along, length, 0.3 * jitter(i, 2), (2 + 10 * TIMBER.wander) * jitter(i, 4) })
	end
	return planks
end
part("Roofs", nil, WOOD, function(mesh)
	for _, side in { -1, 1 } do
		for i, plank in deckPlanks() do
			local along, length, shift, tilt = table.unpack(plank)
			local m = EditMesh.roundedBox({ length, DECK_PLANK - 0.1, DECK_THICK }, 0.08, 1, { 6, 1, 1 })
			-- Each end sawn a little off square.
			m:transform(function(p)
				local endward = math.clamp(math.abs(p[1]) / (length / 2), 0, 1) ^ 6
				return { p[1] + endward * 0.25 * jitter(i, if p[1] > 0 then 7 else 8) * p[2] / ((DECK_PLANK - 0.1) / 2), p[2], p[3] }
			end)
			hewn(m, i * 5 + side)
			m:select("vertex", "all"):rotate({ 0, 1, 0 }, tilt, { 0, 0, 0 })
			placed(m, side, shift, along, SIDE_TOP, DECK_THICK):emit(mesh)
		end
	end
end, nil, function(x, y, z)
	-- Each plank its own shade; a dark nail head where it crosses each
	-- side beam.
	local out, along = caveOf(x, y)
	local i = math.floor((along - DECK_FROM) / ((DECK_TO - DECK_FROM) / math.floor((DECK_TO - DECK_FROM) / DECK_PLANK)))
	local plankMiddle = DECK_FROM + (i + 0.5) * (DECK_TO - DECK_FROM) / math.floor((DECK_TO - DECK_FROM) / DECK_PLANK)
	if z > SIDE_TOP + DECK_THICK - 0.05 and math.abs(math.abs(out) - POST_OUT) < 0.26 and math.abs(along - plankMiddle) < 0.26 then
		return 0.2, 0.19, 0.2
	end
	return wood(i + 80, out, x, y, z, 0.22)
end, nil, nil, true, nil, nil, TIMBER.worn)
wornEdges()

-- Upright boards in the rock face behind the back posts: down each side
-- of the opening, and across above the headers, up to the rocks; none
-- past BOARDS_OUT, so none can show through a gap in the columns.
local BOARDS_OUT = BORE + 0.8
part("Boards", nil, WOOD, function(mesh)
	for _, side in { -1, 1 } do
		for _, flank in { -1, 1 } do
			for i = 0, math.ceil((BOARDS_OUT - OPEN_HALF - 0.1) / BOARD_WIDE) - 1 do
				local out = flank * (OPEN_HALF + 0.1 + (i + 0.5) * BOARD_WIDE)
				local tall = HEADER_TOP + 0.4 * jitter(i, flank + side * 5)
				local m = EditMesh.roundedBox({ BOARD_WIDE - 0.08, BOARD_THICK, tall }, 0.08, 1, { 1, 1, 4 })
				hewn(m, i * 3 + flank * 7 + side)
				placed(m, side, out, BOARDS_AT, -0.2, tall):emit(mesh)
			end
		end
		for i = 0, 14 do
			local out = -6.4 + (i + 0.5) * 12.8 / 15
			local tall = 2.4 + 0.3 * jitter(i, side)
			if math.abs(out) < BOARDS_OUT then
				local m = EditMesh.roundedBox({ 12.8 / 15 - 0.08, BOARD_THICK, tall }, 0.08, 1, { 1, 1, 2 })
				placed(m, side, out, BOARDS_AT, OPEN_TALL, tall):emit(mesh)
			end
		end
	end
end, nil, function(x, y, z)
	local out = caveOf(x, y)
	return wood(math.floor(out / BOARD_WIDE) + (if z > OPEN_TALL then 30 else 0) + 120, z, x, y, z)
end, nil, nil, true, nil, nil, TIMBER.worn)
wornEdges()

-- ------------------------------------------------------------ the stones

-- Chunks beside the track past each porch's front, small squared blocks
-- broken off the hill's face, partly buried: {out, along from the mouth,
-- width, depth, height}; the far mouth's are mirrored across.
local PEBBLES = {
	{ -3.8, -8.4, 0.98, 0.83, 0.6 },
	{ -4.2, -6.9, 1.35, 1.12, 0.83 },
	{ -4.0, -11.2, 0.68, 0.6, 0.41 },
	{ 3.8, -9, 0.83, 0.75, 0.49 },
	{ 4.3, -7.4, 1.5, 1.2, 0.9 },
	{ 3.6, -11.6, 0.9, 0.75, 0.45 },
	{ -3.4, -7.2, 0.52, 0.45, 0.34 },
	{ 3.7, -6.6, 0.6, 0.52, 0.38 },
	{ -4.6, -9.6, 1.05, 0.9, 0.68 },
	{ 4.8, -10.2, 0.75, 0.68, 0.45 },
}
part("Stones", nil, ROCK, function(mesh)
	for _, side in { -1, 1 } do
		for n, pebble in PEBBLES do
			local out, along, w, d, h = table.unpack(pebble)
			local m = stoneBlock(200 + n + side * 10, rectangle(w, d), h, "chunk", true)
			m:select("vertex", "all"):rotate({ 0, 0, 1 }, 40 * jitter(n, side), { 0, 0, 0 })
			placed(m, side, side * out, along, -0.25 * h, h):emit(mesh)
		end
	end
end, nil, function(x, y, z, nx, ny, nz)
	local r, g, b = rockPaint(x, y, z, nx, ny, nz)
	return r * 0.88, g * 0.88, b * 0.88
end, nil, nil, true, PEBBLE_EDGE, nil, PEBBLE_LIT)
boldRims()
parts[#parts].softEdge = PEBBLE_GLOW_EDGE

-- ------------------------------------------------------------ the shades

-- (Open at the mouth on purpose: `-- open: Shades` above.)
-- Each mouth's shade: the bore's own shape drawn in a hair, from halfway
-- along the porch's timber to SHADE_DEPTH in, closed at the far end and
-- open at the front, its faces turned inward so the inside is what shows.
-- Black and unlit, clear at its front and opaque SHADE_OPAQUE in.
local SHADE_FROM, SHADE_OPAQUE = (FRONT_POSTS + BACK_POSTS) / 2, BOARDS_AT + SHADE_DEPTH * 0.75
part("Shades", nil, { 0, 0, 0 }, function(mesh)
	for _, side in { -1, 1 } do
		local m = EditMesh.new()
		local STEPS = 8
		local rings = {}
		for k = 0, STEPS do
			local along = SHADE_FROM + (SHADE_DEPTH - SHADE_FROM) * k / STEPS
			local ring = {}
			for i, p in MOUTH do
				ring[i] = m:addVertex(table.unpack(caveAt(side, p[1] * 0.97, math.max(p[2] * 0.97, 0.02), along)))
			end
			rings[k] = ring
		end
		local count = #MOUTH
		for k = 0, STEPS - 1 do
			for i = 1, count do
				local j = i % count + 1
				m:addFace({ rings[k][j], rings[k][i], rings[k + 1][i], rings[k + 1][j] })
			end
		end
		-- The far end, closed in two quads from the feet up.
		local back = rings[STEPS]
		m:addFace({ back[6], back[5], back[2], back[1] })
		m:addFace({ back[5], back[4], back[3], back[2] })
		faceOut(m)
		m:flip()
		m:emit(mesh)
	end
end, nil, function(x, y)
	local _, along = caveOf(x, y)
	return 0, 0, 0, math.clamp((along - SHADE_FROM) / (SHADE_OPAQUE - SHADE_FROM), 0, 1)
end, nil, 1, true)

-- ------------------------------------------------------------- the track

-- One lap of rails on timber sleepers, both ends diving inside the tunnel.
local function trackHeight(degrees: number): number
	local fromMiddle = math.min(degrees, 360 - degrees)
	local t = math.clamp((fromMiddle - TRACK_END) / (DIVE_FROM - TRACK_END), 0, 1)
	return 0.15 - 3.5 * (1 - t * t * (3 - 2 * t))
end
-- A low box from (ax, ay) to (bx, by), `width` across, between heights.
local function bar(mesh, ax: number, ay: number, bx: number, by: number, width: number, a0: number, a1: number, b0: number, b1: number)
	local length = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
	local ox, oy = -(by - ay) / length * width / 2, (bx - ax) / length * width / 2
	local p = {
		mesh:vertex(ax - ox, ay - oy, a0), mesh:vertex(ax + ox, ay + oy, a0), mesh:vertex(bx + ox, by + oy, b0), mesh:vertex(bx - ox, by - oy, b0),
		mesh:vertex(ax - ox, ay - oy, a1), mesh:vertex(ax + ox, ay + oy, a1), mesh:vertex(bx + ox, by + oy, b1), mesh:vertex(bx - ox, by - oy, b1),
	}
	mesh:face({ p[8], p[7], p[6], p[5] })
	mesh:face({ p[2], p[3], p[4], p[1] })
	mesh:face({ p[5], p[6], p[2], p[1] })
	mesh:face({ p[7], p[8], p[4], p[3] })
	mesh:face({ p[6], p[7], p[3], p[2] })
	mesh:face({ p[8], p[5], p[1], p[4] })
end
local STEEL = { 0.36, 0.36, 0.38 }
local SLEEPER = { 0.45, 0.31, 0.2 }
part("Rails", nil, STEEL, function(mesh)
	for _, side in { -1, 1 } do
		local r = TRACK_RADIUS + side * TRACK_GAUGE / 2
		for d = TRACK_END, 360 - TRACK_END - 2, 2 do
			local a, b = math.rad(d), math.rad(d + 2)
			local za, zb = trackHeight(d) + 0.3, trackHeight(d + 2) + 0.3
			bar(mesh, math.cos(a) * r, math.sin(a) * r, math.cos(b) * r, math.sin(b) * r, 0.35, za, za + 0.35, zb, zb + 0.35)
		end
	end
end, nil, 0, nil, nil, true)
part("Sleepers", nil, SLEEPER, function(mesh)
	for d = TRACK_END + 1, 360 - TRACK_END - 1, 1.6 do
		local a = math.rad(d)
		local z = trackHeight(d)
		local inner, outer = TRACK_RADIUS - TRACK_GAUGE / 2 - 0.8, TRACK_RADIUS + TRACK_GAUGE / 2 + 0.8
		bar(mesh, math.cos(a) * inner, math.sin(a) * inner, math.cos(a) * outer, math.sin(a) * outer, 0.8, z - 0.15, z + 0.35, z - 0.15, z + 0.35)
	end
end, nil, 0, nil, nil, true)
finishParts()
