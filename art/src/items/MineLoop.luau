-- Mine Loop: the hub's minecart track and the cave it runs into, as one
-- model (art/concepts/mine-portal-reference.png), at full size in studs.
-- The origin is the middle of the hub at deck level; the layout puts it on
-- the plaza.
-- The track is one lap of radius TRACK_RADIUS. Round 0 degrees a pile of
-- big rounded boulders sits over it, CAVE_HALF degrees either side, with a
-- tunnel through it; both track ends run into the tunnel and dive down out
-- of sight in its middle, so carts come up out of the ground and go back
-- down at one spot.
-- The cave is the boulders themselves: a wall of them down each side of
-- the tunnel, a roof tier across it, a higher tier on the side away from
-- the hub and a peak on top, so from the hub the pile steps up away from
-- you. The rocks themselves wall and roof the tunnel, overlapping so no
-- gap shows through: nothing but rock. Each mouth has a timber porch: two log posts a side, header
-- beams, side beams and a deck of planks, with upright boards closing the
-- gap between the porch and the rocks, a lantern hung on one front post and
-- pebbles round its foot. A black, unlit shade fills each mouth from the
-- inside, its faces turned in, clear at the mouth and opaque a few studs
-- in, so the tunnel reads as dark however it's lit.
-- The opening is 6.4 wide between the posts and 6.6 tall under the
-- headers: a cart (3.6 wide, 4.9 tall with its capsule) passes, and a
-- player (4 by 5.5) fits, though the floor drops away just inside.
-- open: Shades
-- floats: Sleepers, Stones
-- (Each sleeper and pebble lies on the plaza on its own.)
-- include: EditMesh
-- include: EditOps
-- include: EditShapes
useTexelDensity(16)

local TRACK_RADIUS, TRACK_GAUGE = 72, 3
local CAVE_HALF = 11
-- The track's ends, in degrees from the cave's middle, and where it starts
-- to dive (inside the tunnel, out of sight from the mouth).
local TRACK_END, DIVE_FROM = 4, 9
-- The shade fills the bore from the porch's boards to SHADE_DEPTH in.
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

-- ------------------------------------------------------------- the rocks

-- Boulders, each {out (- toward the hub), along from the cave's middle
-- (+ toward the +CAVE_HALF mouth), base height, width out, depth along,
-- height, turn, lean, kind (BOULDER_KINDS, block when unset)}. The walls
-- stand just clear of the opening and the roof slabs lie right over it,
-- every rock overlapping its neighbours so no gap shows through; the rocks
-- flanking each porch overlap its boards, so no gap shows beside it.
local ROCKS = {
	-- the hub side's wall, up to the roof: one big boulder among medium
	-- ones, with a big low slab, a medium rock and small ones outside it
	{ -7, -11, -0.5, 6, 6, 7.6, 6, -5, "round" },
	{ -9.1, -3, -0.5, 10.5, 10, 8.4, -5, -6 },
	{ -7.4, 4.5, -0.5, 6.5, 7, 7.7, 8, -5, "crag" },
	{ -6.6, 9.8, -0.5, 5, 5.5, 7.6, -6, -6, "round" },
	{ -12.5, -2, -0.5, 6, 9, 3.5, 15, -10, "slab" },
	{ -11.2, -9.5, -0.5, 4.5, 5, 4, 25, -6, "round" },
	{ -11.5, 6.5, -0.5, 3, 3, 2.2, -20, -8, "crag" },
	{ -11.6, 8.2, -0.5, 2, 2.2, 1.6, 30, 0, "round" },
	{ -13.3, -5.6, -0.5, 1.8, 2, 1.4, 10, 0, "round" },
	-- the far side's wall, a tier higher, round one tall boulder with a
	-- rock leaning on its foot, small rocks outside it
	{ 7.2, -10.5, -0.5, 6.5, 6, 7.5, -6, 7, "round" },
	{ 9.5, -2.5, -0.5, 11, 10, 13, 6, 10, "crag" },
	{ 7.3, 5.5, -0.5, 6, 6.5, 9, -7, 8, "round" },
	{ 6.9, 10.5, -0.5, 6, 5, 7, 7, 6, "round" },
	{ 10.6, 8, -0.5, 3, 3.5, 2.5, 20, 6, "round" },
	{ 13.4, -1, -0.5, 4, 5, 4.5, 20, 10, "slab" },
	{ 12.6, -7.6, -0.5, 2.2, 2.4, 1.7, -15, 0, "round" },
	{ 14.2, 3, -0.5, 1.6, 1.8, 1.2, 40, 0, "crag" },
	-- flanking each porch, overlapping its boards
	{ -7.6, -12.9, -0.5, 5.5, 6, 6, 12, -8, "round" },
	{ 7.9, -13, -0.5, 6.5, 6, 7.5, -12, 8, "crag" },
	{ -7.3, 12.9, -0.5, 4.5, 5, 5, -10, -8, "round" },
	{ 7.6, 13, -0.5, 5.5, 6, 6, 12, 8, "round" },
	-- shoulders, wedged where the porch, its lintel rock and the flanking
	-- rock meet
	{ -6.4, -12, 4.5, 4, 4, 4.5, 15, 0, "round" },
	{ 6.4, -12, 4.5, 4, 4, 4.5, -15, 0 },
	{ -6.4, 12, 4.5, 4, 4, 4.5, -15, 0, "crag" },
	{ 6.4, 12, 4.5, 4, 4, 4.5, 15, 0, "round" },
	-- over each porch
	{ 0, -12.2, 7.2, 12, 4.5, 3.5, 4, 0, "slab" },
	{ 0, 12.2, 7.2, 10, 4, 2.8, -5, 0, "slab" },
	-- the backing, mostly hidden: flat slabs right over the opening and long
	-- rocks along each wall, so a crevice anywhere shows rock
	{ 0, -6, 6.75, 9, 12.5, 2.5, 0, 0 },
	{ 0, 6, 6.75, 9, 12.5, 2.5, 0, 0 },
	{ -4.9, -6, -0.5, 3, 12.5, 7.5, 0, 0 },
	{ -4.9, 6, -0.5, 3, 12.5, 7.5, 0, 0 },
	{ 4.9, -6, -0.5, 3, 12.5, 7.5, 0, 0 },
	{ 4.9, 6, -0.5, 3, 12.5, 7.5, 0, 0 },
	-- the roof: slabs of different sizes right over the opening,
	-- overlapping each other and both walls
	{ -2, -6.5, 6.9, 14, 9, 3, 6, 2, "slab" },
	{ -2, -1, 6.9, 9, 4, 2.6, 15, 2 },
	{ -2, 3, 6.9, 13, 8, 4, -5, -2, "slab" },
	{ -2, 8.5, 6.9, 11, 6, 2.8, 6, 2 },
	-- the far side's middle tier, a big slab, a medium one, a small one
	-- between them and one by the + porch
	{ 4.5, -5.5, 8.6, 8, 9, 4.5, -8, 4, "slab" },
	{ 5.5, 4.5, 8.6, 6, 6.5, 3, 12, 3, "round" },
	{ 4.5, -0.3, 8.6, 4, 4, 3.2, 25, 3, "crag" },
	{ 5.5, 8.5, 7.2, 5, 5, 3, 10, 3, "round" },
	-- the ridge: a big peak slab toward the hub, stepping down in smaller
	-- slabs toward the +CAVE_HALF mouth, small rocks in its joints
	{ -1, -4, 9.8, 11, 10, 7, 14, -7, "crag" },
	{ 1.5, 3, 10.2, 7, 6, 3.6, -8, 5, "slab" },
	{ 2, 8, 9.8, 5, 4.5, 2.5, 10, 4, "round" },
	{ 0, -10, 9.8, 4, 3.5, 2.6, 30, 0, "crag" },
	{ -5.5, 1, 9.8, 2.5, 3, 2, 20, 10, "round" },
	{ -6, -8.5, 9.6, 3, 2.5, 2, -25, 8, "crag" },
	{ 6.5, 1.5, 11.4, 2, 2.2, 1.6, 15, 0, "round" },
}
local ROCK = { 0.52, 0.54, 0.6 }

-- The highlight band's reach from an edge, in studs, its strength, and how
-- far from a corner its strokes taper away.
local ROCK_EDGE, ROCK_LIT, ROCK_TAPER = 0.6, 1.8, 0.8
-- Pebbles are small, so their rims are narrower and fainter.
local PEBBLE_EDGE, PEBBLE_LIT = 0.25, 0.7

-- Each rock's middle in the model, to tell which rock a texel is on.
local rockMiddles = {}
for n, rock in ROCKS do
	local out, middle, base, _w, _d, h = table.unpack(rock)
	rockMiddles[n] = caveAt(1, out, base + h / 2, HALF_LENGTH - middle)
end
local function nearestRock(x: number, y: number, z: number): number
	local best, nearest = math.huge, 1
	for n, p in rockMiddles do
		local d = (p[1] - x) ^ 2 + (p[2] - y) ^ 2 + (p[3] - z) ^ 2
		if d < best then
			best, nearest = d, n
		end
	end
	return nearest
end

-- Blue-grey stone in broad soft patches, lighter on tops, each boulder a
-- little lighter or darker, warmer or cooler than its neighbours.
local function rockPaint(x: number, y: number, z: number, _nx: number, _ny: number, nz: number): (number, number, number)
	local n = nearestRock(x, y, z)
	local k = (0.92 + 0.1 * math.noise(x / 3, y / 3, z / 3)) * (1 + 0.09 * jitter(n, 5))
	if nz > 0.6 then
		k *= 1.1
	end
	local warm = 0.025 * jitter(n, 9)
	return (ROCK[1] + warm) * k, ROCK[2] * k, (ROCK[3] - warm) * k
end
-- The last part added gets bold, fully loaded highlight strokes on its
-- edges, tinted toward a lighter stone, full width at the corners and
-- tapering along each edge.
local function boldRims()
	parts[#parts].painted = true
	parts[#parts].blend = 0.65
	parts[#parts].taper = ROCK_TAPER
end
-- The kinds of boulder, so the pile isn't one shape over and over: how
-- big its chamfers are (share of its smallest side), how much it narrows to
-- the top, how far its top tilts, how many top corners are chipped off,
-- and whether its top steps up into a plateau or it is pulled round.
local BOULDER_KINDS = {
	block = { chamfer = 0.16, taper = 0.12, tilt = 7, chips = 1, plateau = true },
	slab = { chamfer = 0.12, taper = 0.08, tilt = 20, chips = 1 },
	crag = { chamfer = 0.14, taper = 0.38, tilt = 10, chips = 2 },
	round = { chamfer = 0.24, taper = 0.06, tilt = 5, chips = 0, round = 0.15 },
}

-- One boulder `n` of a kind, w by d by h about its middle: a block with
-- every edge chamfered (each face inset and lifted, so the rings slope off
-- at 45 degrees), then shaped by its kind.
local function boulder(n: number, w: number, d: number, h: number, kindName: string?)
	local kind = BOULDER_KINDS[kindName or "block"]
	local size = math.min(w, d, h)
	local chamfer = kind.chamfer * size * (1 + 0.2 * jitter(n, 13))
	local m = EditMesh.box({ w - 2 * chamfer, d - 2 * chamfer, h - 2 * chamfer })
	m:inset(m:select("face", "all"), chamfer, chamfer, { each = true })
	if kind.round then
		m:toSphere(m:select("vertex", "all"), kind.round)
	end
	if kind.plateau and n % 3 ~= 0 then
		m:inset(m:select("face", "facing", { 0, 0, 1 }, 5), 0.2 * size, 0.06 * h)
	end
	local tilt = kind.tilt * (if jitter(n, 11) > 0 then 1 else -1) * (0.7 + 0.3 * math.abs(jitter(n, 12)))
	m:select("vertex", "where", function(p)
		return p[3] > h / 2 - chamfer
	end):rotate({ 1, 0, 0 }, tilt, { 0, 0, h / 2 })
	-- Chips: every point within `reach` of a corner (summing the three
	-- axes) pushed back onto the plane that far from it, so the corner is
	-- cut off in one flat face. Only top corners, so no rock is cut away
	-- where it meets its neighbours below.
	for k = 1, kind.chips + (if kind.plateau then n % 2 else 0) do
		local corner = {
			if jitter(n, k * 3) > 0 then w / 2 else -w / 2,
			if jitter(n, k * 3 + 1) > 0 then d / 2 else -d / 2,
			h / 2,
		}
		local reach = (0.55 + 0.25 * jitter(n, k * 3 + 7)) * size
		m:transform(function(p)
			local depth = 0
			for axis = 1, 3 do
				depth += math.abs(p[axis] - corner[axis])
			end
			if depth >= reach then
				return p
			end
			local back = (reach - depth) / 3
			return {
				p[1] - math.sign(corner[1]) * back,
				p[2] - math.sign(corner[2]) * back,
				p[3] - math.sign(corner[3]) * back,
			}
		end)
	end
	m:transform(function(p)
		local taper = 1 - kind.taper * (p[3] / h + 0.5)
		local s = 0.03 * size
		return {
			p[1] * taper + s * math.noise(p[1] / size + n, p[2] / size, p[3] / size),
			p[2] * taper + s * math.noise(p[1] / size, p[2] / size + n, p[3] / size),
			p[3] + s * math.noise(p[1] / size, p[2] / size, p[3] / size + n),
		}
	end)
	return m
end

part("Rocks", nil, ROCK, function(mesh)
	for n, rock in ROCKS do
		local out, middle, base, w, d, h, turn, lean, kind = table.unpack(rock)
		local m = boulder(n, w, d, h, kind)
		m:select("vertex", "all"):rotate({ 1, 0, 0 }, lean, { 0, 0, -h / 2 })
		m:select("vertex", "all"):rotate({ 0, 0, 1 }, turn, { 0, 0, 0 })
		placed(m, 1, out, HALF_LENGTH - middle, base, h):emit(mesh)
	end
end, nil, rockPaint, nil, nil, true, ROCK_EDGE, nil, ROCK_LIT)
boldRims()

-- ------------------------------------------------------------ the porches

-- Along from each mouth (negative is out in front): the back posts stand
-- just before the boards, the front posts PORCH_DEPTH further out.
local POST_RADIUS = 0.6
local POST_OUT = OPEN_HALF + POST_RADIUS
local BACK_POSTS, FRONT_POSTS = -0.75, -0.75 - 3.4
local BEAM = 0.8
local HEADER_TOP = OPEN_TALL + BEAM
local SIDE_TOP = HEADER_TOP + 0.7
local DECK_THICK, DECK_PLANK = 0.45, 0.9
local DECK_FROM, DECK_TO = FRONT_POSTS - 0.7, BACK_POSTS + 0.5
local BOARDS_AT, BOARD_THICK, BOARD_WIDE = -0.25, 0.35, 0.8
local WOOD = { 0.66, 0.38, 0.2 }
-- The lanterns hang this high, under a bracket off the hub-side front
-- post.
local LANTERN_AT = 2.6
local LANTERN_OUT = -POST_OUT - POST_RADIUS - 0.3

-- Wood: each piece `index` its own shade, with fine grain lines.
local function wood(index: number, grain: number, x: number, y: number, z: number, spread: number?): (number, number, number)
	local k = 0.9 + (spread or 0.12) * jitter(index, 3) + 0.05 * math.noise(x / 2, y / 2, z / 2)
	if math.abs(math.sin(grain * 6 + 1.5 * math.noise(x * 0.7, y * 0.7, z * 0.7))) < 0.14 then
		k -= 0.12
	end
	return WOOD[1] * k, WOOD[2] * k, WOOD[3] * k
end

part("Posts", nil, WOOD, function(mesh)
	for _, side in { -1, 1 } do
		for _, along in { BACK_POSTS, FRONT_POSTS } do
			for _, flank in { -1, 1 } do
				local m = EditMesh.cylinder(POST_RADIUS, OPEN_TALL + 0.3, 8, 3)
				m:select("vertex", "all"):rotate({ 1, 0, 0 }, 1.5 * jitter(along * 10, flank + side * 3), { 0, 0, 0 })
				placed(m, side, flank * POST_OUT, along, -0.3, OPEN_TALL + 0.3):emit(mesh)
			end
		end
		-- The lantern's bracket: an arm out of the post over the lantern.
		local arm = EditMesh.roundedBox({ 1.3, 0.3, 0.3 }, 0.06, 1, { 2, 1, 1 })
		placed(arm, side, LANTERN_OUT + 0.25, FRONT_POSTS, LANTERN_AT + 1.1, 0.3):emit(mesh)
	end
end, nil, function(x, y, z)
	local out, along = caveOf(x, y)
	return wood(math.floor(out) + math.floor(along) * 7, z, x, y, z)
end, nil, nil, true)

part("Beams", nil, WOOD, function(mesh)
	for _, side in { -1, 1 } do
		-- A header across each pair of posts, and a side beam along each
		-- side on top of them.
		for _, along in { BACK_POSTS, FRONT_POSTS } do
			local length = 2 * POST_OUT + 1.6
			local m = EditMesh.roundedBox({ length, BEAM, BEAM }, 0.12, 1, { 4, 1, 1 })
			placed(m, side, 0, along, OPEN_TALL, BEAM):emit(mesh)
		end
		for _, flank in { -1, 1 } do
			local length = BACK_POSTS - FRONT_POSTS + 1.4
			local m = EditMesh.roundedBox({ BEAM, length, 0.7 }, 0.12, 1, { 1, 4, 1 })
			placed(m, side, flank * POST_OUT, (BACK_POSTS + FRONT_POSTS) / 2, HEADER_TOP, 0.7):emit(mesh)
		end
	end
end, nil, function(x, y, z)
	local out, along = caveOf(x, y)
	local index = if z > HEADER_TOP then math.floor(out) else math.floor(along * 2)
	return wood(index + 40, if z > HEADER_TOP then along else out, x, y, z)
end, nil, nil, true)

-- The deck: planks laid across the side beams, side by side out to the
-- front, each a little different in length, set and tilt.
local function deckPlanks(): { { number } }
	local planks = {}
	local n = math.floor((DECK_TO - DECK_FROM) / DECK_PLANK)
	for i = 1, n do
		local along = DECK_FROM + (i - 0.5) * (DECK_TO - DECK_FROM) / n
		local length = 2 * POST_OUT + 2 + 0.5 * jitter(i, 1)
		table.insert(planks, { along, length, 0.3 * jitter(i, 2), 2 * jitter(i, 4) })
	end
	return planks
end
part("Roofs", nil, WOOD, function(mesh)
	for _, side in { -1, 1 } do
		for _, plank in deckPlanks() do
			local along, length, shift, tilt = table.unpack(plank)
			local m = EditMesh.roundedBox({ length, DECK_PLANK - 0.1, DECK_THICK }, 0.08, 1, { 4, 1, 1 })
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
end, nil, nil, true)

-- Upright boards in the rock face behind the back posts: down each side
-- of the opening, and across above the headers, up to the rocks.
part("Boards", nil, WOOD, function(mesh)
	for _, side in { -1, 1 } do
		for _, flank in { -1, 1 } do
			for i = 0, 4 do
				local out = flank * (OPEN_HALF + 0.1 + (i + 0.5) * BOARD_WIDE)
				local tall = HEADER_TOP + 0.4 * jitter(i, flank + side * 5)
				local m = EditMesh.roundedBox({ BOARD_WIDE - 0.08, BOARD_THICK, tall }, 0.08, 1, { 1, 1, 4 })
				placed(m, side, out, BOARDS_AT, -0.2, tall):emit(mesh)
			end
		end
		for i = 0, 14 do
			local out = -6.4 + (i + 0.5) * 12.8 / 15
			local tall = 2.4 + 0.3 * jitter(i, side)
			local m = EditMesh.roundedBox({ 12.8 / 15 - 0.08, BOARD_THICK, tall }, 0.08, 1, { 1, 1, 2 })
			placed(m, side, out, BOARDS_AT, OPEN_TALL, tall):emit(mesh)
		end
	end
end, nil, function(x, y, z)
	local out = caveOf(x, y)
	return wood(math.floor(out / BOARD_WIDE) + (if z > OPEN_TALL then 30 else 0) + 120, z, x, y, z)
end, nil, nil, true)

-- A lantern hung on the hub-side front post of each mouth, against its
-- outer side: a glowing glass body between a dark cap and base.
local GLOW = { 1, 0.78, 0.35 }
part("Lanterns", nil, GLOW, function(mesh)
	for _, side in { -1, 1 } do
		local m = EditMesh.roundedBox({ 0.7, 0.7, 1.1 }, 0.15, 1, { 1, 1, 2 })
		placed(m, side, LANTERN_OUT, FRONT_POSTS, LANTERN_AT, 1.1):emit(mesh)
	end
end, nil, function(_x, _y, z)
	if z > LANTERN_AT + 0.85 or z < LANTERN_AT + 0.15 then
		return 0.25, 0.2, 0.15
	end
	return GLOW[1], GLOW[2], GLOW[3]
end, nil, 1, true)

-- ------------------------------------------------------------ the stones

-- Pebbles round each porch's foot, small chipped boulders partly buried: {out, along from the
-- mouth, width, depth, height}; the far mouth's are mirrored across.
local PEBBLES = {
	{ -5.3, -2.4, 1.3, 1.1, 0.8 },
	{ -6.2, -0.9, 1.8, 1.5, 1.1 },
	{ -5.8, -5.2, 0.9, 0.8, 0.55 },
	{ 5.4, -3, 1.1, 1, 0.65 },
	{ 6.3, -1.4, 2, 1.6, 1.2 },
	{ 4.9, -5.6, 1.2, 1, 0.6 },
	{ -4.6, -1.2, 0.7, 0.6, 0.45 },
	{ 5.1, -0.6, 0.8, 0.7, 0.5 },
	{ -7, -3.6, 1.4, 1.2, 0.9 },
	{ 7.3, -4.2, 1, 0.9, 0.6 },
}
part("Stones", nil, ROCK, function(mesh)
	for _, side in { -1, 1 } do
		for n, pebble in PEBBLES do
			local out, along, w, d, h = table.unpack(pebble)
			local m = boulder(100 + n + side * 10, w, d, h, "round")
			m:select("vertex", "all"):rotate({ 0, 0, 1 }, 40 * jitter(n, side), { 0, 0, 0 })
			placed(m, side, side * out, along, -0.25 * h, h):emit(mesh)
		end
	end
end, nil, function(x, y, z, nx, ny, nz)
	local r, g, b = rockPaint(x, y, z, nx, ny, nz)
	return r * 0.88, g * 0.88, b * 0.88
end, nil, nil, true, PEBBLE_EDGE, nil, PEBBLE_LIT)
boldRims()

-- ------------------------------------------------------------ the shades

-- (Open at the mouth on purpose: `-- open: Shades` above.)
-- Each mouth's shade: the bore's own shape drawn in a hair, from the
-- boards to SHADE_DEPTH in, closed at the far end and open at the mouth,
-- its faces turned inward so the inside is what shows. Black and unlit,
-- clear at the mouth and opaque toward the back.
part("Shades", nil, { 0, 0, 0 }, function(mesh)
	for _, side in { -1, 1 } do
		local m = EditMesh.new()
		local STEPS = 6
		local rings = {}
		for k = 0, STEPS do
			local along = BOARDS_AT + (SHADE_DEPTH - BOARDS_AT) * k / STEPS
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
	return 0, 0, 0, math.clamp((along - BOARDS_AT) / (SHADE_DEPTH * 0.75), 0, 1)
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
		bar(mesh, math.cos(a) * inner, math.sin(a) * inner, math.cos(a) * outer, math.sin(a) * outer, 0.8, z - 0.1, z + 0.35, z - 0.1, z + 0.35)
	end
end, nil, 0, nil, nil, true)
finishParts()
