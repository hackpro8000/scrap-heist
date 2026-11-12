-- Column Island: the generator for the map's floating islands, a mountain
-- of stone columns turned upside down, so a flat grassy top hangs over a
-- rocky cone that tapers to a point below. The columns, of every size and
-- shape, are packed edge to edge like cracked basalt; each hangs as deep as
-- the cone at its centre with a low faceted tip, so the underside steps down
-- in uneven tiers to the lowest point and a shallower shoulder. The columns
-- are the cells of a weighted Voronoi diagram (a power diagram) over
-- scattered stones, so big stones claim big cells. Stones grow from small
-- near the tip to big at the rim, and the big rim stones give the top its
-- lobed outline. Each column is carved, a few angled planes chiselling
-- chunks off its lower corners and edges. The model is built the mountain
-- way up (heights, summit, foot) and flipped as it is written out. Centered
-- on the origin, stone top at z = 0, turf GRASS_HEIGHT above it.
--
-- The item including this sets:
--   RADIUS        the island's radius;
--   PEAK          how far the cone hangs below the top;
--   SEED          which scatter of stones it gets;
--   wornDistance(x, y)  how far a point on the top lies outside the ground
--                 worn by what stands on it (math.huge where nothing does);
--                 the grass wears to dirt within about APRON_WIDTH of it;
--   COVER_INSET   turf lying more than this many studs inside the worn
--                 ground is buried under what stands there and left out
--                 (math.huge keeps it all);
--   RIM_WOBBLE    how far the rim swells and dips, as a share of its radius;
--   rimShape(angle)  how far out the rim stands at an angle, as a multiple
--                 of the round rim: 1 all round for a round island, never
--                 under 1, more toward the corners of a squarer one.

-- Tiled coat, on MainIsland only: the brushed base coat is painted once on
-- seamless square tiles and laid over every chunk by world position, instead
-- of stroked over each chunk's own surface, so the coat repeats every
-- TILED_COAT_STUDS but bakes far faster. TILED_COAT_VARIANTS differently
-- stroked tiles are mixed so neighbouring tiles differ. Look choices: tune by eye.
local TILED_COAT = true
local TILED_COAT_STUDS = 32
local TILED_COAT_VARIANTS = 4
local tiledCoat = if TILED_COAT and string.match(CACHE_KEY, "^MainIsland%-")
	then { TILED_COAT_STUDS, TILED_COAT_VARIANTS }
	else nil
-- Stone sizes at the summit and at the foot, as shares of the radius, so
-- a bigger island has bigger stones rather than more of them.
local SMALLEST, LARGEST = 0.055 * RADIUS, 0.34 * RADIUS
-- Every other size in studs below was tuned on stones up to 4.5 studs
-- across and is multiplied by DETAIL, so an island with bigger stones looks
-- the same, only bigger: chips, slabs, cookie stones, cracks, rounding,
-- grass and the paint's blotches all grow with the stones.
local DETAIL = LARGEST / 4.5
-- The rim the columns are trimmed to: a circle of RIM_PUSH * RADIUS
-- swelling and dipping by up to RIM_WOBBLE of it in broad waves, so the top
-- is a dependable surface rather than sharp lobes and bays, and standing
-- rimShape times as far out at each angle. RIM_SIDES flat facets make it up,
-- so the rim stones end in cut faces.
local RIM_SIDES = 192
-- The rim stands RIM_PUSH times RADIUS out.
local RIM_PUSH = 1.1
-- The top tier of dirt, this deep under the grass, stays a clean wall
-- straight down from the rim the grass follows: chisel cuts, chips and bare
-- rock slabs all start below it.
local DIRT_CONFORM = 1.5 * DETAIL
-- Stones are scattered a stone's width past the rim, so rim cells close
-- on real neighbours before they are trimmed to it.
local RIM_REACH = 1
for i = 0, RIM_SIDES - 1 do
	RIM_REACH = math.max(RIM_REACH, rimShape(i / RIM_SIDES * 2 * math.pi))
end
local SCATTER = RIM_PUSH * RADIUS * RIM_REACH + LARGEST
-- Shortest a column hangs, so the rim stones read as a thick slab; a
-- share of the radius like the stone sizes.
local MIN_LENGTH = 0.2 * RADIUS
-- Chisel cuts per column, at most, and how deep one bites as a share of
-- the stone's size.
local MAX_CUTS = 3
local CUT_DEPTH = { 0.2, 0.55 }
-- Fine chips per column (fewest, most) and how deep one bites, in studs.
local CHIPS = { 3, 6 }
local CHIP_DEPTH = { 0.15 * DETAIL, 0.45 * DETAIL }
-- How far a cut's heading may swing from straight out, in radians.
local CUT_SPREAD = math.rad(55)

local STONE = { 0.46, 0.45, 0.5 }
-- Under the grass the island is all dirt, until rocks start breaking
-- through it at the first share of the island's depth in DIRT_TRANSITION,
-- more and more of them going down, until from the second share it is all
-- rock. Each rock comes through the dirt at its own depth in that range. The
-- dirt's bottom edge is bevelled back DIRT_BEVEL studs on its outer side, so
-- the rock it sits on stands proud.
local DIRT = { 0.33, 0.24, 0.18 }
local DIRT_TRANSITION = { 0.2, 0.65 }
-- Where a rock comes through, the line between its dirt and its stone tilts
-- by up to DIRT_TILT radians, each rock its own way, so the line wanders
-- round the island instead of stepping level.
local DIRT_TILT = math.rad(25)
-- Above that, rock already shows through the dirt in slabs: a rock still
-- under dirt may have up to PATCHES slabs of its faces bare below tilted
-- lines, each facing out from the island's centre within PATCH_SPREAD
-- radians. The chance of each rises from nothing at PATCH_FROM of the depth
-- to certain at PATCH_FULL. A slab is PATCH_THICKNESS studs deep, its back
-- leaning in or out by up to PATCH_LEAN, and its top line tilted by up to
-- PATCH_TILT; PATCH_PEAKED of the slabs have a second top line, so the bare
-- rock comes up to a point through the dirt.
local PATCHES = 2
local PATCH_FROM = 0.04
local PATCH_FULL = 0.25
local PATCH_SPREAD = math.rad(45)
local PATCH_THICKNESS = { 0.4 * DETAIL, 1.4 * DETAIL }
local PATCH_LEAN = 0.5
local PATCH_TILT = 0.8
local PATCH_PEAKED = 0.6
-- The bare rock of a slab is chiselled into a rough stone: this many chips
-- (fewest, most), each biting this deep (studs) off its outer side at its
-- own angle, up to PATCH_CHIP_SPREAD radians off straight out.
local PATCH_CHIPS = { 4, 8 }
local PATCH_CHIP_DEPTH = { 0.3 * DETAIL, 0.8 * DETAIL }
local PATCH_CHIP_SPREAD = math.rad(65)
-- The colours blend too, over a wider share of the depth: dirt greys toward
-- stone and stone keeps a dirty tint across COLOR_TRANSITION, the line
-- wandering by COLOR_WOBBLE of the depth. At any depth the dirt stays
-- DIRT_LEAD further toward dirt than the stone, so the two still read apart.
local COLOR_TRANSITION = { 0.08, 0.55 }
local COLOR_WOBBLE = 0.06
local DIRT_LEAD = 0.45
-- Traces of dirt stay on the stone just under each rock's dirt line, as
-- patchy blotches thinning out over DIRT_TRACE studs below it. Bare rock
-- breaking through above the line keeps DIRT_DUSTING of them.
local DIRT_TRACE = 4 * DETAIL
local DIRT_DUSTING = 0.35
-- Grime and dead grey lichen crust the stone in patches, thickest where
-- the dirt gives way to rock and thinning out to nothing by GRIME_REACH of
-- the island's depth.
-- GRIME_COVER is the most of the stone it covers.
local GRIME = { 0.21, 0.22, 0.19 }
local GRIME_REACH = 0.8
local GRIME_COVER = 0.45

-- Small whole stones half sunk in the dirt, like crushed cookie in ice
-- cream: STONE_BITS of them per square stud of dirt near the top, rising to
-- the second number where the dirt gives way to rock. Each is STONE_BIT_SIZE
-- studs across, most of them small and a few big (STONE_BIT_SKEW over 1), a
-- chipped box, and stands out of the dirt by STONE_BIT_RISE
-- of its size. None sit within STONE_BIT_CLEAR studs of the top, under the
-- grass's lip. With bigger stones (DETAIL) they are bigger and sparser.
local PEBBLE = { 0.47, 0.46, 0.49 }
local STONE_BITS = { 0.035 / DETAIL ^ 2, 0.17 / DETAIL ^ 2 }
local STONE_BIT_SIZE = { 0.45 * DETAIL, 1.9 * DETAIL }
local STONE_BIT_SKEW = 2
local STONE_BIT_RISE = { 0.3, 0.4 }
local STONE_BIT_CLEAR = 1.2 * DETAIL
-- The stones are stained with dirt: solid where they come out of it,
-- breaking into blotches up to STONE_BIT_STAIN of their height.
local STONE_BIT_STAIN = 1.6

-- Drawn cracks in the dirt, running out from the stones sunk in it, as if
-- pushing them in split it: CRACK_CHANCE of the stones have them, up to
-- CRACKS each, CRACK_LENGTH studs long in CRACK_SEGMENTS jagged steps,
-- CRACK_WIDTH wide at the stone and thinning steadily to nothing at its end.
-- CRACK_BRANCH of the cracks fork once.
local CRACK = { 0.17, 0.12, 0.08 }
-- Each crack is drawn in depth: a pale lip where light catches its lower
-- edge (CRACK_LIP), the crack over it, and a darker core down its middle
-- (CRACK_CORE, CRACK_CORE_WIDTH of the crack's width).
local CRACK_LIP = { 0.66, 0.53, 0.4 }
local CRACK_CORE = { 0.06, 0.04, 0.03 }
local CRACK_CORE_WIDTH = 0.45
local CRACK_CHANCE = 1
local CRACKS = 3
local CRACK_LENGTH = { 0.6 * DETAIL, 1.8 * DETAIL }
local CRACK_SEGMENTS = 4
local CRACK_WIDTH = { 0.1 * DETAIL, 0.18 * DETAIL }
local CRACK_BRANCH = 0.4
local DIRT_BEVEL = { 0.3 * DETAIL, 0.6 * DETAIL }
-- How steeply each rock's bevel slants, in radians up from flat; each rock
-- takes its own angle in this range, so the bevels don't all match.
local DIRT_BEVEL_LIFT = { math.rad(25), math.rad(65) }
-- The dirt's outer edges and corners are rounded off on this radius, each
-- edge in this many facets, so it reads soft rather than jagged.
local DIRT_ROUND = 0.6 * DETAIL
local DIRT_ROUND_STEPS = 4
-- Each rock shades from STONE times the first where it meets the top to
-- STONE times the second at its tip.
local ROCK_GRADIENT = { 1.1, 0.6 }
-- Brush splotches in the stone: one may sit in each cell of a 3D grid
-- (`cell` studs, with `chance`), a lobed blot `radius` studs across that
-- shifts the stone's tone by up to `tone` and its tint by up to `tint`. The
-- coat's brush strokes lay them on as dabs.
local SPLOTCH = { cell = 1.8 * DETAIL, chance = 1, radius = { DETAIL, 2 * DETAIL }, tone = 0.1, tint = 0.02 }
-- Texture pixels per stud; chunks are 1024 texels across at this density.
local TEXEL_DENSITY = 16
-- Edge highlights: how far edge paint reaches from an edge, in studs, and how
-- many times wider than the default the highlight strokes are.
local EDGE_REACH = DETAIL
local HIGHLIGHT_WIDTH = 4
-- Studs over which a highlight thins from full width at a corner.
local CORNER_TAPER = 0.5 * DETAIL
-- Grass and dirt are soft, so their edge highlights and contact shadows run
-- at this share of the stone's.
local SOFT_SHADING = 0.12

-- Grass over the top: a turf slab GRASS_HEIGHT thick, pushed GRASS_OUTSET
-- past the rim, whose edge hangs down as a lip (shallowest and deepest, in
-- studs) hung all along with tongues of grass dripping further down, each
-- DRIP_WIDTH across and DRIP_LENGTH below the lip. Neighbouring drips
-- overlap by DRIP_OVERLAP of their widths, so the edge runs as one
-- unbroken wave with no flat stretch between drips.
local GRASS = { 0.74, 0.63, 0.4 }
local GRASS_HEIGHT = 0.45 * DETAIL
local GRASS_OUTSET = 0.25 * DETAIL
local GRASS_LIP = { 0.3 * DETAIL, 0.6 * DETAIL }
local DRIP_WIDTH = { 1.6 * DETAIL, 4 * DETAIL }
local DRIP_LENGTH = { 0.3 * DETAIL, 1.1 * DETAIL }
local DRIP_OVERLAP = 0.35
-- A finer octave of wobble over the wave: how far it moves the edge up or
-- down, in studs, and how fast it changes along the rim.
local DRIP_DETAIL = 0.3 * DETAIL
local DRIP_DETAIL_FREQUENCY = 1.1 / DETAIL
-- Spacing of the points the rim is walked in, in studs.
local GRASS_STEP = 0.25 * DETAIL
-- The turf's top rolls over into its hanging edge on a quarter circle this
-- many studs across, in this many facets.
local GRASS_ROUND = 0.42 * DETAIL
local GRASS_ROUND_STEPS = 4
-- The hanging edge's bottom curls under into its underside on this radius.
local GRASS_BOTTOM_ROUND = 0.2 * DETAIL
-- The rim's corners in plan are rounded off by blurring its outline over
-- about this many studs, just enough to soften each stone's jog while the
-- grass still follows the stones, pushed out GRASS_OUTSET past them. The drips' depth is
-- blurred over GRASS_DEPTH_BLUR studs, so neighbouring tongues meet in soft
-- dips rather than sharp notches.
local GRASS_CORNER_BLUR = 0.2 * DETAIL
local GRASS_DEPTH_BLUR = 0.3 * DETAIL
-- The turf's flat top is cut into squares this many studs across, to keep
-- its texture chunks small; this one doesn't grow with DETAIL.
local GRASS_TOP_CELL = 8
-- How much the grass darkens toward the tip of the deepest drip.
local DRIP_SHADE = 0.35
-- The grass is dead: straw GRASS drifting into a dull olive where a little
-- life hangs on (GRASS_OLIVE_COVER of it), in soft noise patches this many
-- studs across.
local GRASS_OLIVE = { 0.6, 0.57, 0.35 }
local GRASS_OLIVE_COVER = 0.3
local GRASS_PATCH_SIZE = 6 * DETAIL
local GRASS_SPLOTCH = 0.25
-- Within about APRON_WIDTH studs of what stands on the top (wornDistance)
-- the grass is worn down to TRODDEN dirt and gravel, in patches toward the
-- outside. These follow what stands there, not the stones, so DETAIL leaves
-- them alone.
local APRON_WIDTH = 6
local TRODDEN = { 0.47, 0.4, 0.31 }

-- Fixed per-column jitter, so the columns look uneven but every build matches.
local function hash(i: number, j: number): number
	local n = math.sin(i * 127.1 + j * 311.7) * 43758.5453
	return n - math.floor(n)
end

local seed = SEED
local function random(): number
	seed = (seed * 16807) % 2147483647
	return seed / 2147483647
end

-- Height of the slope at a point: the main cone, ridges running down from
-- the summit, and a lower shoulder peak off to one side. The cone is
-- rounded BOWL of the way toward a dome, so the underside reads as a
-- shallow bowl rather than a spike under a flat shelf.
local BOWL = 0.4
local function heightAt(x: number, y: number): number
	local r = math.sqrt(x * x + y * y) / RADIUS
	local angle = math.atan2(y, x)
	local ridges = 1 + 0.12 * math.cos(angle * 5) * r
	local out = math.min(r * ridges, 1)
	local cone = (1 - out) ^ 1.25
	local dome = math.sqrt(1 - out * out)
	local main = PEAK * (cone + (dome - cone) * BOWL)
	local sx, sy = x - 8, y + 5
	local shoulder = 19 * math.max(0, 1 - math.sqrt(sx * sx + sy * sy) / 11) ^ 1.1
	return math.max(main, shoulder)
end

-- The rim's radius at an angle.
local function rimAt(angle: number): number
	local phase = SEED * 1.7
	local wave = 0.5 * math.sin(2 * angle + phase) + 0.3 * math.sin(3 * angle + 2 * phase) + 0.2 * math.sin(5 * angle + 3 * phase)
	return RIM_PUSH * RADIUS * rimShape(angle) * (1 + RIM_WOBBLE * wave)
end

-- Stones scattered by dart throwing, none crowding another, sized by how
-- high on the slope they sit: x, y and size.
local stones = {}
for _ = 1, 8000 do
	local angle, reach = random() * TAU, math.sqrt(random()) * SCATTER
	local x, y = reach * math.cos(angle), reach * math.sin(angle)
	local height = math.clamp(heightAt(x, y) / PEAK, 0, 1)
	local size = (LARGEST + (SMALLEST - LARGEST) * height ^ 0.5) * (0.8 + 0.4 * random())
	local clear = true
	for _, other in stones do
		local dx, dy = x - other[1], y - other[2]
		if dx * dx + dy * dy < ((size + other[3]) * 0.72) ^ 2 then
			clear = false
			break
		end
	end
	if clear then
		table.insert(stones, { x, y, size })
	end
end

-- Cuts a cell outline down to the side of stone q's boundary nearer stone
-- p. Each corner carries the stone across the edge that starts there (nil
-- on the outer rim), so walls can find their neighbour.
local function clip(outline, p, q, neighbour)
	local nx, ny = q[1] - p[1], q[2] - p[2]
	local limit = (q[1] ^ 2 + q[2] ^ 2 - p[1] ^ 2 - p[2] ^ 2 - q[3] ^ 2 + p[3] ^ 2) / 2
	local function side(point)
		return point[1] * nx + point[2] * ny - limit
	end
	local kept = {}
	for i, a in outline do
		local b = outline[i % #outline + 1]
		local sa, sb = side(a), side(b)
		local crossing = if (sa <= 0) ~= (sb <= 0)
			then { a[1] + (b[1] - a[1]) * sa / (sa - sb), a[2] + (b[2] - a[2]) * sa / (sa - sb) }
			else nil
		if sa <= 0 then
			table.insert(kept, { a[1], a[2], a[3] })
			if crossing then
				table.insert(kept, { crossing[1], crossing[2], neighbour })
			end
		elseif crossing then
			table.insert(kept, { crossing[1], crossing[2], a[3] })
		end
	end
	return kept
end

-- The rim's corners, then each of its sides as a plane n . p <= limit,
-- in order round from angle 0.
local rimSides = {}
do
	local rim = {}
	for i = 0, RIM_SIDES - 1 do
		local angle = i / RIM_SIDES * TAU
		local r = rimAt(angle)
		rim[i + 1] = { r * math.cos(angle), r * math.sin(angle) }
	end
	for i, a in rim do
		local b = rim[i % #rim + 1]
		-- Counter-clockwise, so out is to the right of each side.
		local nx, ny = b[2] - a[2], a[1] - b[1]
		table.insert(rimSides, { nx, ny, nx * a[1] + ny * a[2] })
	end
end

-- Cuts a cell outline down to the inside of one rim side; corners where it
-- crosses carry nil, as on the outer rim.
local function clipToRim(outline, side)
	local nx, ny, limit = side[1], side[2], side[3]
	local kept = {}
	for i, a in outline do
		local b = outline[i % #outline + 1]
		local sa, sb = a[1] * nx + a[2] * ny - limit, b[1] * nx + b[2] * ny - limit
		if sa <= 0 then
			table.insert(kept, { a[1], a[2], a[3] })
		end
		if (sa <= 0) ~= (sb <= 0) then
			local t = sa / (sa - sb)
			table.insert(kept, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, if sa <= 0 then nil else a[3] })
		end
	end
	return kept
end

-- Each stone's column: its outline and its top corners on a slanted plane.
local columns = {}
for index, stone in stones do
	local outline = {}
	for i = 0, 31 do
		local angle = i / 32 * TAU
		table.insert(outline, { SCATTER * math.cos(angle), SCATTER * math.sin(angle), nil })
	end
	for other, neighbour in stones do
		if other ~= index and #outline >= 3 then
			local dx, dy = neighbour[1] - stone[1], neighbour[2] - stone[2]
			if dx * dx + dy * dy < (LARGEST * 3) ^ 2 then
				outline = clip(outline, stone, neighbour, other)
			end
		end
	end
	-- Every cell is trimmed to the rim sides it faces (the rim isn't convex,
	-- so the far sides would cut into its swells); those left with nothing
	-- inside the rim are dropped. A cell's sides are those over the angles
	-- its corners span, and a few either way so neighbours trim alike.
	local low, high, farthest = math.huge, -math.huge, 0
	local heading = math.atan2(stone[2], stone[1])
	for _, corner in outline do
		local offset = (math.atan2(corner[2], corner[1]) - heading + math.pi) % TAU - math.pi
		low, high = math.min(low, offset), math.max(high, offset)
		farthest = math.max(farthest, math.sqrt(corner[1] ^ 2 + corner[2] ^ 2))
	end
	if farthest > RIM_PUSH * RADIUS * (1 - RIM_WOBBLE) then
		local first = math.floor((heading + low) / TAU * RIM_SIDES) - 8
		local last = math.ceil((heading + high) / TAU * RIM_SIDES) + 8
		for k = first, last do
			if #outline < 3 then
				break
			end
			outline = clipToRim(outline, rimSides[k % RIM_SIDES + 1])
		end
	end
	local area = 0
	for i, a in outline do
		local b = outline[i % #outline + 1]
		area += (a[1] * b[2] - b[1] * a[2]) / 2
	end
	-- Only cells the rim leaves nothing of are dropped; a small one kept at
	-- the rim fills its stretch so the edge doesn't notch.
	if #outline < 3 or math.abs(area) < 1e-3 then
		continue
	end
	local cx, cy = 0, 0
	for _, corner in outline do
		cx, cy = cx + corner[1] / #outline, cy + corner[2] / #outline
	end
	local rise = math.max(MIN_LENGTH * (0.8 + 0.4 * hash(index, 5)), heightAt(cx, cy) + (hash(index, 1) - 0.5) * (1 + stone[3]))
	local tiltX, tiltY = (hash(index, 2) - 0.5) * 0.45, (hash(index, 3) - 0.5) * 0.45
	local corners = {}
	-- Neighbouring columns share their edges exactly, so no gap opens
	-- between them.
	for i, corner in outline do
		local z = rise + (corner[1] - cx) * tiltX + (corner[2] - cy) * tiltY
		corners[i] = { corner[1], corner[2], z, corner[3] }
	end
	columns[index] = {
		index = index,
		size = stone[3],
		corners = corners,
		-- The top rises to a low ridge point, so it reads as broken stone.
		peak = { cx, cy, rise + 0.15 * stone[3] * (0.5 + hash(index, 4)) },
	}
end

-- A column as a closed solid: faces as lists of points, wound outward,
-- from the foot (z = 0) up to its slanted top and the low point above it.
local function solidOf(column)
	local bottom = 0
	local corners, peak = column.corners, column.peak
	local count = #corners
	local faces = {}
	local base = {}
	for i = count, 1, -1 do
		table.insert(base, { corners[i][1], corners[i][2], bottom })
	end
	table.insert(faces, base)
	for i = 1, count do
		local a, b = corners[i], corners[i % count + 1]
		table.insert(faces, { { a[1], a[2], bottom }, { b[1], b[2], bottom }, { b[1], b[2], b[3] }, { a[1], a[2], a[3] } })
		table.insert(faces, { { peak[1], peak[2], peak[3] }, { a[1], a[2], a[3] }, { b[1], b[2], b[3] } })
	end
	return faces
end

-- Cuts away everything on the far side of the plane n . p = d, closing the
-- wound with a cap facing along n.
local function carve(faces, n, d)
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

-- Carve every column first, so walls can be cut against their
-- neighbours' finished shapes.
for _, column in columns do
	local corners, index = column.corners, column.index
	local faces = solidOf(column)
	local outward = math.atan2(column.peak[2], column.peak[1])

	-- Chisel cuts: each faces out and up at its own angle, from a low
	-- slant (shaving a side edge) to steep (bevelling the top), and
	-- bites a set depth in from the farthest point along it. None is
	-- near level, which would open holes down between columns. Every cut
	-- faces away from the island's centre, within CUT_SPREAD either side,
	-- so the carving shows on the outside and never faces inward.
	-- The cuts to make: heading, lift and depth. The big chisel cuts come
	-- first, then fine chips that knock small corners off what is left.
	local cuts = {}
	for k = 1, 1 + math.floor(hash(index, 40) * MAX_CUTS) do
		table.insert(cuts, {
			outward + (hash(index, 40 + k) - 0.5) * 2 * CUT_SPREAD,
			0.35 + hash(index, 50 + k) * 0.85,
			column.size * (CUT_DEPTH[1] + (CUT_DEPTH[2] - CUT_DEPTH[1]) * hash(index, 60 + k)),
		})
	end
	for k = 1, CHIPS[1] + math.floor(hash(index, 70) * (CHIPS[2] - CHIPS[1] + 1)) do
		table.insert(cuts, {
			outward + (hash(index, 70 + k) - 0.5) * 2 * CUT_SPREAD,
			0.35 + hash(index, 80 + k) * 1.05,
			CHIP_DEPTH[1] + (CHIP_DEPTH[2] - CHIP_DEPTH[1]) * hash(index, 90 + k),
		})
	end
	for _, cut in cuts do
		local heading, lift, depth = cut[1], cut[2], cut[3]
		local n = { math.cos(heading) * math.cos(lift), math.sin(heading) * math.cos(lift), math.sin(lift) }
		local farthest = -math.huge
		for _, face in faces do
			for _, p in face do
				farthest = math.max(farthest, p[1] * n[1] + p[2] * n[2] + p[3] * n[3])
			end
		end
		-- A cut stops short of the top tier, which follows the grass, so
		-- the wall under the grass is never carved into.
		local tiermost = -math.huge
		for _, corner in corners do
			tiermost = math.max(tiermost, corner[1] * n[1] + corner[2] * n[2] + DIRT_CONFORM * n[3])
		end
		local plane = math.max(farthest - depth, tiermost + 0.3)
		if plane < farthest then
			faces = carve(faces, n, plane)
		end
	end

	column.faces = faces

	-- Where the column's carved underside begins: the shallowest point of
	-- any face that isn't a side wall or its foot.
	column.surfaceFrom = math.huge
	for _, face in faces do
		local foot, nz = true, 0
		for i, p in face do
			local q = face[i % #face + 1]
			foot = foot and p[3] == 0
			nz += (p[1] - q[1]) * (p[2] + q[2])
		end
		if not foot and math.abs(nz) > 1e-3 then
			for _, p in face do
				column.surfaceFrom = math.min(column.surfaceFrom, p[3])
			end
		end
	end
end

-- How deep each column hides behind the tier around it: it comes into view
-- where its shallowest neighbour's underside begins, or at the top if it
-- faces the open edge.
for _, column in columns do
	column.shownFrom = math.huge
	for _, corner in column.corners do
		local neighbour = corner[4] and columns[corner[4]]
		column.shownFrom = math.min(column.shownFrom, if neighbour then neighbour.surfaceFrom else 0)
	end
end

-- How deep the island hangs at its lowest point.
local islandDepth = 0
for _, column in columns do
	islandDepth = math.max(islandDepth, column.peak[3])
end

-- How far a solid reaches along a direction.
local function farthestAlong(faces, n): number
	local farthest = -math.huge
	for _, face in faces do
		for _, p in face do
			farthest = math.max(farthest, p[1] * n[1] + p[2] * n[2] + p[3] * n[3])
		end
	end
	return farthest
end

-- Cuts a solid's outer bottom edge off, `depth` studs in along a slant facing
-- out from the island's centre and down, `lift` radians up from flat.
local function bevelled(faces, outward: number, depth: number, lift: number)
	local n = { math.cos(outward) * math.cos(lift), math.sin(outward) * math.cos(lift), math.sin(lift) }
	return carve(faces, n, farthestAlong(faces, n) - depth)
end

-- Each rock is dirt down to where it comes through, and stone below, split
-- into a dirt solid and a stone one. The dirt's outer bottom edge is
-- bevelled off, so the stone under it stands proud. Higher up, a patch of a
-- rock's outer face may already show through: the dirt is split into the
-- slab on its outer face and the rest, and the slab into bare stone below a
-- tilted line and dirt above, bevelled like the rest.
for _, column in columns do
	local index, faces = column.index, column.faces
	local share = DIRT_TRANSITION[1] + (DIRT_TRANSITION[2] - DIRT_TRANSITION[1]) * hash(index, 30)
	local dirtLine = islandDepth * share
	column.dirtLine = dirtLine
	if dirtLine <= column.shownFrom then
		column.solids = { { faces = faces, dirt = false } }
		continue
	end
	local shown = column.shownFrom
	local outward = math.atan2(column.peak[2], column.peak[1])
	local bevel = DIRT_BEVEL[1] + (DIRT_BEVEL[2] - DIRT_BEVEL[1]) * hash(index, 31)
	local lift = DIRT_BEVEL_LIFT[1] + (DIRT_BEVEL_LIFT[2] - DIRT_BEVEL_LIFT[1]) * hash(index, 34)
	-- The tilted line passes through dirtLine under the rock's tip.
	local tilt, heading = DIRT_TILT * hash(index, 32), hash(index, 33) * 2 * math.pi
	local down = { math.sin(tilt) * math.cos(heading), math.sin(tilt) * math.sin(heading), math.cos(tilt) }
	local line = down[1] * column.peak[1] + down[2] * column.peak[2] + down[3] * dirtLine
	local dirt = bevelled(carve(faces, down, line), outward, bevel, lift)
	local stone = carve(faces, { -down[1], -down[2], -down[3] }, -line)
	column.solids = { { faces = dirt, dirt = true }, { faces = stone, dirt = false } }
	-- The stone shows from below the dirt.
	column.shownFrom = math.min(dirtLine, column.peak[3])

	local middle = (shown + dirtLine) / 2 / islandDepth
	local chance = math.clamp((middle - PATCH_FROM) / (PATCH_FULL - PATCH_FROM), 0, 1)
	if dirtLine - shown <= 1 then
		continue
	end
	-- Each slab is cut from the dirt left after the last, so they sit side
	-- by side round the rock.
	local rest, solids = dirt, { { faces = stone, dirt = false } }
	for k = 1, PATCHES do
		if hash(index, 204 + k * 10) >= chance then
			continue
		end
		local heading = outward + (hash(index, 205 + k * 10) - 0.5) * 2 * PATCH_SPREAD
		local lean = (hash(index, 300 + k * 10) - 0.5) * 2 * PATCH_LEAN
		local size = math.sqrt(1 + lean * lean)
		local across = { math.cos(heading) / size, math.sin(heading) / size, lean / size }
		local thickness = PATCH_THICKNESS[1] + (PATCH_THICKNESS[2] - PATCH_THICKNESS[1]) * hash(index, 206 + k * 10)
		local face = farthestAlong(rest, across) - thickness
		local slab = carve(rest, { -across[1], -across[2], -across[3] }, -face)
		rest = carve(rest, across, face)
		-- The slab's top line, tilted, somewhere down what shows of the rock:
		-- above it dirt, below it bare rock.
		local function topLine(seed: number)
			local top = shown + (dirtLine - shown) * (0.05 + 0.45 * hash(index, seed))
			local tx = (hash(index, seed + 1) - 0.5) * 2 * PATCH_TILT
			local ty = (hash(index, seed + 2) - 0.5) * 2 * PATCH_TILT
			local length = math.sqrt(tx * tx + ty * ty + 1)
			local down = { tx / length, ty / length, 1 / length }
			-- Never above the top tier anywhere across the slab.
			local level = -math.huge
			for _, f in slab do
				for _, p in f do
					level = math.max(level, down[1] * p[1] + down[2] * p[2] + down[3] * DIRT_CONFORM)
				end
			end
			return down, math.max(down[1] * column.peak[1] + down[2] * column.peak[2] + down[3] * top, level)
		end
		local down, line = topLine(207 + k * 10)
		table.insert(solids, { faces = bevelled(carve(slab, down, line), heading, bevel * 0.7, lift), dirt = true })
		local bare = carve(slab, { -down[1], -down[2], -down[3] }, -line)
		-- A second line peaks the rock: the dirt it cuts off stays dirt.
		if hash(index, 320 + k * 10) < PATCH_PEAKED then
			local second, secondLine = topLine(330 + k * 10)
			table.insert(solids, { faces = bevelled(carve(bare, second, secondLine), heading, bevel * 0.7, lift), dirt = true })
			bare = carve(bare, { -second[1], -second[2], -second[3] }, -secondLine)
		end
		-- Chipped into a rough stone rather than a flat slab.
		local chips = PATCH_CHIPS[1] + math.floor(hash(index, 400 + k * 10) * (PATCH_CHIPS[2] - PATCH_CHIPS[1] + 1))
		for c = 1, chips do
			local seed = 500 + k * 100 + c * 7
			local yaw = heading + (hash(index, seed) - 0.5) * 2 * PATCH_CHIP_SPREAD
			local pitch = (hash(index, seed + 1) - 0.5) * 2 * PATCH_CHIP_SPREAD
			local n = { math.cos(yaw) * math.cos(pitch), math.sin(yaw) * math.cos(pitch), math.sin(pitch) }
			local depth = PATCH_CHIP_DEPTH[1] + (PATCH_CHIP_DEPTH[2] - PATCH_CHIP_DEPTH[1]) * hash(index, seed + 2)
			local plane = farthestAlong(bare, n) - depth
			if plane > -math.huge then
				bare = carve(bare, n, plane)
			end
		end
		table.insert(solids, { faces = bare, dirt = false })
	end
	table.insert(solids, { faces = rest, dirt = true })
	column.solids = solids
end

-- Each face's plane, as a unit normal pointing out and its distance.
local function planeOf(face)
	local nx, ny, nz = 0, 0, 0
	for i, a in face do
		local b = face[i % #face + 1]
		nx += (a[2] - b[2]) * (a[3] + b[3])
		ny += (a[3] - b[3]) * (a[1] + b[1])
		nz += (a[1] - b[1]) * (a[2] + b[2])
	end
	local length = math.sqrt(nx * nx + ny * ny + nz * nz)
	if length < 1e-9 then
		return nil
	end
	nx, ny, nz = nx / length, ny / length, nz / length
	local p = face[1]
	return { nx, ny, nz, nx * p[1] + ny * p[2] + nz * p[3] }
end

-- Splits a face by a plane into the part outside it and the part inside.
local EPSILON = 1e-5
local function split(face, plane)
	local outside, inside = {}, {}
	local function side(p)
		local s = plane[1] * p[1] + plane[2] * p[2] + plane[3] * p[3] - plane[4]
		return if math.abs(s) < EPSILON then 0 else s
	end
	for i, a in face do
		local b = face[i % #face + 1]
		local sa, sb = side(a), side(b)
		if sa >= 0 then
			table.insert(outside, a)
		end
		if sa <= 0 then
			table.insert(inside, a)
		end
		if (sa > 0 and sb < 0) or (sa < 0 and sb > 0) then
			local t = sa / (sa - sb)
			local p = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
			table.insert(outside, p)
			table.insert(inside, p)
		end
	end
	return outside, inside
end

local function area(face): number
	local plane = planeOf(face)
	if not plane or #face < 3 then
		return 0
	end
	local total = 0
	for i = 2, #face - 1 do
		local a, b, c = face[1], face[i], face[i + 1]
		local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local vx, vy, vz = c[1] - a[1], c[2] - a[2], c[3] - a[3]
		total += ((uy * vz - uz * vy) * plane[1] + (uz * vx - ux * vz) * plane[2] + (ux * vy - uy * vx) * plane[3]) / 2
	end
	return total
end

-- The parts of a face that don't lie inside a neighbour. Only a face lying
-- against one of the neighbour's own faces can touch it; that face's plane
-- is skipped, and the face is carved by the rest, every piece that falls
-- outside one of them showing.
local function uncovered(face, neighbour)
	local own = planeOf(face)
	if not own then
		return {}
	end
	local touching, planes = false, {}
	for _, other in neighbour.faces do
		local plane = planeOf(other)
		if plane then
			local facing = own[1] * plane[1] + own[2] * plane[2] + own[3] * plane[3] < -0.9999
			local p = face[1]
			if facing and math.abs(plane[1] * p[1] + plane[2] * p[2] + plane[3] * p[3] - plane[4]) < 1e-4 then
				touching = true
			else
				table.insert(planes, plane)
			end
		end
	end
	if not touching then
		return { face }
	end
	local shown, rest = {}, face
	for _, plane in planes do
		local outside, inside = split(rest, plane)
		if #outside >= 3 and area(outside) > 1e-4 then
			table.insert(shown, outside)
		end
		rest = inside
		if #rest < 3 or area(rest) <= 1e-4 then
			break
		end
	end
	return shown
end

-- Columns bucketed by the 2-stud cells their outlines cover, so paint can
-- find the rock under a point without testing them all.
local CELL = 2
local cells = {}
for _, column in columns do
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, corner in column.corners do
		x0, y0 = math.min(x0, corner[1]), math.min(y0, corner[2])
		x1, y1 = math.max(x1, corner[1]), math.max(y1, corner[2])
	end
	for cx = math.floor(x0 / CELL), math.floor(x1 / CELL) do
		for cy = math.floor(y0 / CELL), math.floor(y1 / CELL) do
			local cellKey = `{cx},{cy}`
			cells[cellKey] = cells[cellKey] or {}
			table.insert(cells[cellKey], column)
		end
	end
end

-- The rock a point on the island belongs to. On a wall two rocks share,
-- the deeper one owns it, since only its wall shows there.
local function rockAt(x: number, y: number)
	local found = nil
	for _, column in cells[`{math.floor(x / CELL)},{math.floor(y / CELL)}`] or {} do
		local corners, within = column.corners, true
		for i, a in corners do
			local b = corners[i % #corners + 1]
			if (b[1] - a[1]) * (y - a[2]) - (b[2] - a[2]) * (x - a[1]) < -1e-3 then
				within = false
				break
			end
		end
		if within and (found == nil or column.peak[3] > found.peak[3]) then
			found = column
		end
	end
	return found
end

-- The splotch on top at a point, as its tone and warmth shifts (0, 0 where
-- none reaches). Of the splotches covering a point, the one laid last wins.
local function splotchAt(x: number, y: number, z: number): (number, number)
	local size = SPLOTCH.cell
	local gx, gy, gz = math.floor(x / size), math.floor(y / size), math.floor(z / size)
	local tone, warm, order = 0, 0, -1
	for i = gx - 1, gx + 1 do
		for j = gy - 1, gy + 1 do
			for k = gz - 1, gz + 1 do
				local seed = i * 7.31 + k * 3.17
				if hash(seed, j + 101) < SPLOTCH.chance then
					local cx = (i + hash(seed, j + 201)) * size
					local cy = (j + hash(seed, j + 301)) * size
					local cz = (k + hash(seed, j + 401)) * size
					local radius = SPLOTCH.radius[1] + (SPLOTCH.radius[2] - SPLOTCH.radius[1]) * hash(seed, j + 501)
					local dx, dy, dz = x - cx, y - cy, z - cz
					-- Lobed rim, so a blot isn't a clean circle.
					local lobes = 1 + 0.25 * math.noise(dx / radius * 1.5 + i, dy / radius * 1.5 + j, dz / radius * 1.5 + k)
					local laid = hash(seed, j + 601)
					if dx * dx + dy * dy + dz * dz < (radius * lobes) ^ 2 and laid > order then
						order = laid
						tone = (hash(seed, j + 701) - 0.5) * 2 * SPLOTCH.tone
						warm = (hash(seed, j + 801) - 0.5) * 2 * SPLOTCH.tint
					end
				end
			end
		end
	end
	return tone, warm
end

-- Per-rock gradient over the part of a rock that shows: light where it
-- comes out from behind the tier around it, darkening toward its tip. The
-- island hangs below z = 0, so depth is -z. Near the top the rock is dirt,
-- fading to stone further down.
-- How far from dirt toward stone the colour has blended at a point, 0 to 1.
local function stoneAt(x: number, y: number, z: number): number
	local share = -z / islandDepth + COLOR_WOBBLE * math.noise(x * 0.15 / DETAIL, y * 0.15 / DETAIL, z * 0.15 / DETAIL)
	local t = math.clamp((share - COLOR_TRANSITION[1]) / (COLOR_TRANSITION[2] - COLOR_TRANSITION[1]), 0, 1)
	return t * t * (3 - 2 * t)
end

-- A colour between dirt and stone, `t` of the way to stone.
local function soil(t: number): (number, number, number)
	return DIRT[1] + (STONE[1] - DIRT[1]) * t, DIRT[2] + (STONE[2] - DIRT[2]) * t, DIRT[3] + (STONE[3] - DIRT[3]) * t
end

local paintRock = rusting(0.1, function(x, y, z)
	local rock = rockAt(x, y)
	local depth = if rock
		then math.clamp((-z - rock.shownFrom) / math.max(rock.peak[3] - rock.shownFrom, 0.5), 0, 1)
		else 0
	local shade = ROCK_GRADIENT[1] + (ROCK_GRADIENT[2] - ROCK_GRADIENT[1]) * depth ^ 0.8
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	local blend = stoneAt(x, y, z)
	local r, g, b = soil(DIRT_LEAD + (1 - DIRT_LEAD) * blend)
	-- Dirt traces: blotches whose share of the stone shrinks below the line.
	if rock then
		local below = -z - rock.dirtLine
		local amount = if below < 0 then DIRT_DUSTING else math.max(0, 1 - below / DIRT_TRACE) ^ 1.5
		local f = 0.7 / DETAIL
		local blot = 0.5 + 0.5 * math.noise(x * f, y * f, z * f) + 0.25 * math.noise(x * f * 3, y * f * 3, z * f * 3)
		local trace = math.clamp((blot - (1 - 0.7 * amount)) / 0.08, 0, 1)
		if trace > 0 then
			local dr, dg, db = soil(0.25 * blend)
			r, g, b = r + (dr - r) * trace, g + (dg - g) * trace, b + (db - b) * trace
		end
	end
	local share = -z / islandDepth
	-- Grime: soft-edged patches, less of them deeper down.
	local growth = math.clamp((GRIME_REACH - share) / (GRIME_REACH - DIRT_TRANSITION[1]), 0, 1)
	if growth > 0 then
		local f = 0.45 / DETAIL
		local patch = 0.5 + 0.5 * math.noise(x * f + 31, y * f, z * f) + 0.2 * math.noise(x * f * 3.6, y * f * 3.6 + 17, z * f * 3.6)
		local grime = math.clamp((patch - (1 - GRIME_COVER * growth)) / 0.1, 0, 1)
		r, g, b = r + (GRIME[1] - r) * grime, g + (GRIME[2] - g) * grime, b + (GRIME[3] - b) * grime
	end
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

-- Dirt darkens a little with depth, greys toward stone, and is splotched
-- like the stone.
local paintDirt = rusting(0.05, function(x, y, z)
	local shade = 1.05 - 0.3 * math.clamp(-z / (islandDepth * DIRT_TRANSITION[2]), 0, 1)
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	local r, g, b = soil((1 - DIRT_LEAD) * stoneAt(x, y, z))
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

-- Flipped upside down as it is written out: z mirrors, and the winding
-- reverses so faces still point outward. The foot becomes the island's top.
local function addFlipped(mesh, face)
	local verts = {}
	for i, p in face do
		verts[#face + 1 - i] = mesh:vertex(p[1], p[2], -p[3])
	end
	mesh:face(verts)
end

-- The island is split into cubic chunks, each with its own texture, so the
-- stone reads sharp at one density everywhere.
useTexelDensity(TEXEL_DENSITY)

-- A unit vector along x, y, z, and the cross product of two vectors.
local function unit(x: number, y: number, z: number)
	local length = math.max(math.sqrt(x * x + y * y + z * z), 1e-9)
	return { x / length, y / length, z / length }
end
local function cross(a, b)
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

-- The solids that may cover a solid of a column: the column's other pieces
-- and its neighbours'.
local function coverersOf(column, solid)
	local others = {}
	for _, other in column.solids do
		if other ~= solid then
			table.insert(others, other)
		end
	end
	for _, corner in column.corners do
		local neighbour = corner[4] and columns[corner[4]]
		if neighbour then
			for _, other in neighbour.solids do
				table.insert(others, other)
			end
		end
	end
	return others
end

-- What of a face no other solid covers.
local function exposed(face, others)
	local pieces = { face }
	for _, other in others do
		local kept = {}
		for _, piece in pieces do
			for _, part in uncovered(piece, other) do
				table.insert(kept, part)
			end
		end
		pieces = kept
	end
	return pieces
end

local function isFoot(face): boolean
	for _, p in face do
		if p[3] ~= 0 then
			return false
		end
	end
	return true
end

-- Rounds a convex solid's edges and corners where faces that show meet, on
-- DIRT_ROUND. Each such edge is cut by planes turning from one face to the
-- other, each touching a cylinder of that radius set in from both faces;
-- each such corner by one plane facing out between its faces.
local function rounded(faces, shows)
	local planes = {}
	for i, face in faces do
		planes[i] = planeOf(face)
	end
	local function key(p)
		return `{math.round(p[1] * 1e4)},{math.round(p[2] * 1e4)},{math.round(p[3] * 1e4)}`
	end
	local edgeFaces, cornerFaces, points = {}, {}, {}
	for i, face in faces do
		if not planes[i] or not shows[i] then
			continue
		end
		for k, a in face do
			local b = face[k % #face + 1]
			local ka, kb = key(a), key(b)
			points[ka] = a
			local edge = if ka < kb then `{ka}|{kb}` else `{kb}|{ka}`
			edgeFaces[edge] = edgeFaces[edge] or { a = a }
			table.insert(edgeFaces[edge], i)
			cornerFaces[ka] = cornerFaces[ka] or {}
			cornerFaces[ka][i] = true
		end
	end
	local cuts = {}
	for _, edge in edgeFaces do
		if #edge ~= 2 then
			continue
		end
		local n1, n2 = planes[edge[1]], planes[edge[2]]
		local cosine = n1[1] * n2[1] + n1[2] * n2[2] + n1[3] * n2[3]
		if cosine > 0.985 then
			continue
		end
		local p = edge.a
		local inset = DIRT_ROUND / (1 + cosine)
		local centre = { p[1] - (n1[1] + n2[1]) * inset, p[2] - (n1[2] + n2[2]) * inset, p[3] - (n1[3] + n2[3]) * inset }
		for k = 1, DIRT_ROUND_STEPS do
			local t = k / (DIRT_ROUND_STEPS + 1)
			local m = unit(n1[1] + (n2[1] - n1[1]) * t, n1[2] + (n2[2] - n1[2]) * t, n1[3] + (n2[3] - n1[3]) * t)
			table.insert(cuts, { m, m[1] * centre[1] + m[2] * centre[2] + m[3] * centre[3] + DIRT_ROUND })
		end
	end
	for corner, touching in cornerFaces do
		local sum, count = { 0, 0, 0 }, 0
		for i in touching do
			sum = { sum[1] + planes[i][1], sum[2] + planes[i][2], sum[3] + planes[i][3] }
			count += 1
		end
		if count >= 3 then
			local m = unit(sum[1], sum[2], sum[3])
			local v = points[corner]
			table.insert(cuts, { m, m[1] * v[1] + m[2] * v[2] + m[3] * v[3] - DIRT_ROUND * 0.6 })
		end
	end
	for _, cut in cuts do
		faces = carve(faces, cut[1], cut[2])
	end
	return faces
end

-- Round the dirt where it shows: which faces show is settled for every
-- solid first, so rounding one doesn't change what its neighbours see.
do
	local plans = {}
	for _, column in columns do
		for _, solid in column.solids do
			if not solid.dirt then
				continue
			end
			local others, shows = coverersOf(column, solid), {}
			for i, face in solid.faces do
				local whole = area(face)
				if whole > 1e-4 and not isFoot(face) then
					local open = 0
					for _, piece in exposed(face, others) do
						open += area(piece)
					end
					shows[i] = open > whole * 0.5
				end
			end
			table.insert(plans, { solid = solid, shows = shows })
		end
	end
	for _, plan in plans do
		plan.solid.faces = rounded(plan.solid.faces, plan.shows)
	end
end

-- The faces of every column's dirt or stone that show. Only what no other
-- solid covers is kept, another piece of its own column or a neighbour's,
-- so nothing lies buried inside the island. The flat top is left open: the
-- grass covers it.
local function visibleRock(dirt: boolean)
	local shown = {}
	for _, column in columns do
		for _, solid in column.solids do
			if solid.dirt ~= dirt then
				continue
			end
			local others = coverersOf(column, solid)
			for _, face in solid.faces do
				if isFoot(face) then
					continue
				end
				for _, piece in exposed(face, others) do
					table.insert(shown, piece)
				end
			end
		end
	end
	return shown
end

local dirtFaces = visibleRock(true)

-- A box around a centre, `r` from it each way, its faces wound outward.
local function boxAround(c, r)
	local x0, x1, y0, y1, z0, z1 = c[1] - r, c[1] + r, c[2] - r, c[2] + r, c[3] - r, c[3] + r
	return {
		{ { x0, y0, z0 }, { x0, y1, z0 }, { x1, y1, z0 }, { x1, y0, z0 } },
		{ { x0, y0, z1 }, { x1, y0, z1 }, { x1, y1, z1 }, { x0, y1, z1 } },
		{ { x0, y0, z0 }, { x1, y0, z0 }, { x1, y0, z1 }, { x0, y0, z1 } },
		{ { x0, y1, z0 }, { x0, y1, z1 }, { x1, y1, z1 }, { x1, y1, z0 } },
		{ { x0, y0, z0 }, { x0, y0, z1 }, { x0, y1, z1 }, { x0, y1, z0 } },
		{ { x1, y0, z0 }, { x1, y1, z0 }, { x1, y1, z1 }, { x1, y0, z1 } },
	}
end

-- The stones in the dirt, each as the faces that stand out of it. A stone
-- is a box turned at random and chipped at its corners, sunk into a dirt
-- face, and cut off at that face so nothing of it lies buried.
local pebbleSeed = 7
local function pebbleRandom(): number
	pebbleSeed = (pebbleSeed * 16807) % 2147483647
	return pebbleSeed / 2147483647
end
-- How far a point lies from the nearest edge of a face.
local function edgeDistance(face, p): number
	local nearest = math.huge
	for i, a in face do
		local b = face[i % #face + 1]
		local ab = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
		local length = ab[1] ^ 2 + ab[2] ^ 2 + ab[3] ^ 2
		local t = if length > 0 then math.clamp(((p[1] - a[1]) * ab[1] + (p[2] - a[2]) * ab[2] + (p[3] - a[3]) * ab[3]) / length, 0, 1) else 0
		local dx, dy, dz = p[1] - a[1] - ab[1] * t, p[2] - a[2] - ab[2] * t, p[3] - a[3] - ab[3] * t
		nearest = math.min(nearest, math.sqrt(dx * dx + dy * dy + dz * dz))
	end
	return nearest
end

local pebbles = {}
-- Where cracks start: each stone's face, normal, centre on the dirt and how
-- far its rim reaches.
local crackOrigins = {}
-- Each stone as where it meets the dirt (point and outward normal, already
-- flipped) and how far it stands out, bucketed by 2-stud cell for its paint.
local pebbleCells = {}
local function pebbleCell(x: number, y: number, z: number): string
	return `{math.floor(x / 2)},{math.floor(y / 2)},{math.floor(z / 2)}`
end
for _, face in dirtFaces do
	local plane = planeOf(face)
	if not plane then
		continue
	end
	local n = { plane[1], plane[2], plane[3] }
	for i = 2, #face - 1 do
		local a, b, c = face[1], face[i], face[i + 1]
		local triangle = area({ a, b, c })
		local depth = (a[3] + b[3] + c[3]) / 3
		local toward = math.clamp(depth / (islandDepth * DIRT_TRANSITION[1]), 0, 1)
		local density = STONE_BITS[1] + (STONE_BITS[2] - STONE_BITS[1]) * toward
		local count = math.floor(triangle * density + pebbleRandom())
		for _ = 1, count do
			local u, v = pebbleRandom(), pebbleRandom()
			if u + v > 1 then
				u, v = 1 - u, 1 - v
			end
			local p = {
				a[1] + (b[1] - a[1]) * u + (c[1] - a[1]) * v,
				a[2] + (b[2] - a[2]) * u + (c[2] - a[2]) * v,
				a[3] + (b[3] - a[3]) * u + (c[3] - a[3]) * v,
			}
			local size = STONE_BIT_SIZE[1] + (STONE_BIT_SIZE[2] - STONE_BIT_SIZE[1]) * pebbleRandom() ^ STONE_BIT_SKEW
			-- A stone too big for the room it has on its face is made smaller,
			-- so it never hangs off an edge.
			size = math.min(size, edgeDistance(face, p) * 2.2)
			local r = size / 2
			if p[3] < STONE_BIT_CLEAR or size < STONE_BIT_SIZE[1] * 0.8 then
				continue
			end
			local rise = STONE_BIT_RISE[1] + (STONE_BIT_RISE[2] - STONE_BIT_RISE[1]) * pebbleRandom()
			table.insert(crackOrigins, { face = face, normal = n, at = p, rim = r * 1.0 })
			local centre = { p[1] + n[1] * r * (2 * rise - 1), p[2] + n[2] * r * (2 * rise - 1), p[3] + n[3] * r * (2 * rise - 1) }
			-- A box turned at random: start big, and cut each side in to r.
			local x = unit(pebbleRandom() - 0.5, pebbleRandom() - 0.5, pebbleRandom() - 0.5)
			local y = cross(x, unit(pebbleRandom() - 0.5, pebbleRandom() - 0.5, pebbleRandom() - 0.5))
			y = unit(y[1], y[2], y[3])
			local z = cross(x, y)
			local stone = boxAround(centre, size * 2)
			for _, axis in { x, y, z } do
				for _, sign in { 1, -1 } do
					local d = { axis[1] * sign, axis[2] * sign, axis[3] * sign }
					local reach = r * (0.75 + 0.35 * pebbleRandom())
					stone = carve(stone, d, d[1] * centre[1] + d[2] * centre[2] + d[3] * centre[3] + reach)
				end
			end
			-- Chips knock its corners off.
			for _ = 1, 9 do
				local d = unit(pebbleRandom() - 0.5, pebbleRandom() - 0.5, pebbleRandom() - 0.5)
				stone = carve(stone, d, d[1] * centre[1] + d[2] * centre[2] + d[3] * centre[3] + r * (0.65 + 0.25 * pebbleRandom()))
			end
			-- Cut off at the dirt: only what stands out of it is kept, and the
			-- cap the cut leaves lies against the dirt, so it goes too.
			local level = n[1] * p[1] + n[2] * p[2] + n[3] * p[3]
			stone = carve(stone, { -n[1], -n[2], -n[3] }, -level)
			local record = { point = { p[1], p[2], -p[3] }, normal = { n[1], n[2], -n[3] }, height = size * rise, reach = size }
			for cx = -1, 1 do
				for cy = -1, 1 do
					for cz = -1, 1 do
						local key = pebbleCell(p[1] + cx * 2, p[2] + cy * 2, -p[3] + cz * 2)
						pebbleCells[key] = pebbleCells[key] or {}
						table.insert(pebbleCells[key], record)
					end
				end
			end
			for _, piece in stone do
				local onDirt = true
				for _, q in piece do
					onDirt = onDirt and math.abs(n[1] * q[1] + n[2] * q[2] + n[3] * q[3] - level) < 1e-6
				end
				if not onDirt then
					table.insert(pebbles, piece)
				end
			end
		end
	end
end

-- The cracks, drawn over the dirt's coat as tapering brush strokes, one per
-- step of a crack (already flipped).
local crackStrokes = {}
local crackSeed = 3
local function crackRandom(): number
	crackSeed = (crackSeed * 16807) % 2147483647
	return crackSeed / 2147483647
end
-- Whether a point lies inside a convex face, `margin` studs in from its edges.
local function insideFace(face, n, p, margin: number): boolean
	for i, a in face do
		local b = face[i % #face + 1]
		local edge = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
		local inward = unit(table.unpack(cross(n, edge)))
		if (p[1] - a[1]) * inward[1] + (p[2] - a[2]) * inward[2] + (p[3] - a[3]) * inward[3] < margin then
			return false
		end
	end
	return true
end
-- A direction turned by `angle` about the face's normal.
local function turned(v, n, angle: number)
	local side = cross(n, v)
	local c, s = math.cos(angle), math.sin(angle)
	return { v[1] * c + side[1] * s, v[2] * c + side[2] * s, v[3] * c + side[3] * s }
end
-- A jagged line from `start` heading along `heading` in a face, stopping
-- short of its edges.
local function crackLine(face, n, start, heading, length: number)
	local points = { start }
	local step = length / CRACK_SEGMENTS
	local at, way = start, heading
	for _ = 1, CRACK_SEGMENTS do
		way = turned(way, n, (crackRandom() - 0.5) * 1.1)
		local nextAt = { at[1] + way[1] * step, at[2] + way[2] * step, at[3] + way[3] * step }
		if not insideFace(face, n, nextAt, 0.04 * DETAIL) then
			break
		end
		table.insert(points, nextAt)
		at = nextAt
	end
	return points
end
-- Lays a line down as a crack `width` wide at its start, thinning evenly
-- along its length to nothing at its end.
local function addCrack(points, normal, width: number)
	if #points < 2 then
		return
	end
	local total = 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		total += math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
	end
	local travelled = 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local length = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
		local widthA = width * (1 - travelled / total)
		local widthB = width * (1 - (travelled + length) / total)
		travelled += length
		local start = { a[1], a[2], -a[3] }
		local along = { (b[1] - a[1]) / length, (b[2] - a[2]) / length, -(b[3] - a[3]) / length }
		local facing = { normal[1], normal[2], -normal[3] }
		local function stroke(at, width: number, color)
			-- Its place in the whole list is its seed, so it is drawn the same
			-- whichever chunks are handed it.
			table.insert(crackStrokes, { start = at, along = along, normal = facing, length = length, width = width, tail = widthB / widthA, color = color, seed = #crackStrokes })
		end
		-- The lip sits on the crack's lower side, half a crack's width over.
		local across = cross(facing, along)
		local side = if across[3] > 0 then -1 else 1
		local shift = widthA * 0.5 * side
		stroke({ start[1] + across[1] * shift, start[2] + across[2] * shift, start[3] + across[3] * shift }, widthA * 0.8, CRACK_LIP)
		stroke(start, widthA, CRACK)
		stroke(start, widthA * CRACK_CORE_WIDTH, CRACK_CORE)
	end
end

for _, origin in crackOrigins do
	if crackRandom() >= CRACK_CHANCE then
		continue
	end
	local face, n, at = origin.face, origin.normal, origin.at
	-- Some way across the face, to turn into each crack's heading.
	local first = face[1]
	local outward = unit(first[1] - at[1], first[2] - at[2], first[3] - at[3])
	for _ = 1, 1 + math.floor(crackRandom() * CRACKS) do
		local heading = turned(outward, n, crackRandom() * TAU)
		local start = { at[1] + heading[1] * origin.rim, at[2] + heading[2] * origin.rim, at[3] + heading[3] * origin.rim }
		if not insideFace(face, n, start, 0.04 * DETAIL) then
			continue
		end
		local length = CRACK_LENGTH[1] + (CRACK_LENGTH[2] - CRACK_LENGTH[1]) * crackRandom()
		local width = CRACK_WIDTH[1] + (CRACK_WIDTH[2] - CRACK_WIDTH[1]) * crackRandom()
		local line = crackLine(face, n, start, heading, length)
		addCrack(line, n, width)
		-- A fork off partway along, thinner and shorter.
		if #line >= 3 and crackRandom() < CRACK_BRANCH then
			local from = line[2]
			local share = 1 / (#line - 1)
			local away = unit(line[3][1] - from[1], line[3][2] - from[2], line[3][3] - from[3])
			local fork = turned(away, n, (if crackRandom() < 0.5 then -1 else 1) * (0.5 + 0.4 * crackRandom()))
			addCrack(crackLine(face, n, from, fork, length * 0.5), n, width * (1 - share) * 0.8)
		end
	end
end


-- The stones are grey, splotched like the rest and stained with the dirt
-- they sit in: solid at the dirt line, in blotches higher up.
local paintPebble = rusting(0.1, function(x, y, z)
	local tone, warm = splotchAt(x, y, z)
	local shade = 1 + tone * 1.5
	local r, g, b = PEBBLE[1], PEBBLE[2], PEBBLE[3]
	-- The stone this point is on: the nearest whose dirt line it sits above.
	local height, best = math.huge, math.huge
	for _, record in pebbleCells[pebbleCell(x, y, z)] or {} do
		local q, n = record.point, record.normal
		local dx, dy, dz = x - q[1], y - q[2], z - q[3]
		local distance = dx * dx + dy * dy + dz * dz
		if distance < record.reach * record.reach and distance < best then
			best = distance
			height = (dx * n[1] + dy * n[2] + dz * n[3]) / math.max(record.height, 0.05)
		end
	end
	if height < STONE_BIT_STAIN then
		local f = 2.2 / DETAIL
		local blot = 0.5 + 0.5 * math.noise(x * f, y * f, z * f)
		local stain = math.clamp((blot - height / STONE_BIT_STAIN) / 0.12, 0, 1)
		local dr, dg, db = soil(0.15 * stoneAt(x, y, z))
		r, g, b = r + (dr - r) * stain, g + (dg - g) * stain, b + (db - b) * stain
	end
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

chunkedPart("Columns", nil, STONE, function(mesh)
	for _, piece in visibleRock(false) do
		addFlipped(mesh, piece)
	end
end, false, paintRock, true, EDGE_REACH)

chunkedPart("Dirt", nil, DIRT, function(mesh)
	for _, piece in dirtFaces do
		addFlipped(mesh, piece)
	end
end, nil, paintDirt, true, EDGE_REACH)

chunkedPart("Pebbles", nil, PEBBLE, function(mesh)
	for _, piece in pebbles do
		addFlipped(mesh, piece)
	end
end, false, paintPebble, true, EDGE_REACH)

-- The rim walked in even steps, each point pushed out from the stone by the
-- grass's outset (outer) and a hair's width (inner), with how deep the grass
-- hangs there.
local function grassRim()
	-- The rim the stones are trimmed to, walked clockwise seen from above
	-- in GRASS_STEP strides, so the grass follows it exactly.
	local points = {}
	local steps = math.ceil(TAU * RIM_PUSH * RADIUS * RIM_REACH * (1 + RIM_WOBBLE) / GRASS_STEP)
	for k = 0, steps - 1 do
		local angle = -k / steps * TAU
		local r = rimAt(angle)
		table.insert(points, { r * math.cos(angle), r * math.sin(angle) })
	end
	local count = #points

	-- Blurs a list of numbers round the loop: repeated passes of a 1-2-1
	-- average, each spreading it by half a step squared, until it spreads
	-- `studs`.
	local function blurLoop(values: { number }, studs: number)
		for _ = 1, math.round(2 * (studs / GRASS_STEP) ^ 2) do
			local before = table.clone(values)
			for i = 1, #values do
				values[i] = (before[(i - 2) % #values + 1] + 2 * before[i] + before[i % #values + 1]) / 4
			end
		end
	end
	local raw = table.clone(points)
	for axis = 1, 2 do
		local coordinates = {}
		for i, p in points do
			coordinates[i] = p[axis]
		end
		blurLoop(coordinates, GRASS_CORNER_BLUR)
		for i = 1, count do
			points[i] = table.clone(points[i])
			points[i][axis] = coordinates[i]
		end
	end
	-- Blurring cuts the outside corners in, uncovering the stone there, so
	-- the rim swells back out round each one: by the most it was cut in
	-- anywhere near, blurred so the swell has no edge of its own.
	local cut, outward = {}, {}
	for i, p in points do
		local a, b = points[(i - 2) % count + 1], points[i % count + 1]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local length = math.max(math.sqrt(dx * dx + dy * dy), 1e-9)
		outward[i] = { -dy / length, dx / length }
		cut[i] = math.max(0, (raw[i][1] - p[1]) * outward[i][1] + (raw[i][2] - p[2]) * outward[i][2])
	end
	local reach = math.ceil(2 * GRASS_CORNER_BLUR / GRASS_STEP)
	local swell = {}
	for i = 1, count do
		local most = 0
		for k = -reach, reach do
			most = math.max(most, cut[(i + k - 1) % count + 1])
		end
		swell[i] = most
	end
	blurLoop(swell, GRASS_CORNER_BLUR)
	for i, p in points do
		p[1] += outward[i][1] * swell[i]
		p[2] += outward[i][2] * swell[i]
	end

	-- The lip wanders between its shallowest and deepest, and drips hang
	-- from it as rounded tongues, each overlapping the next.
	local along, travelled = {}, 0
	for i, p in points do
		along[i] = travelled
		local q = points[i % count + 1]
		travelled += math.sqrt((q[1] - p[1]) ^ 2 + (q[2] - p[2]) ^ 2)
	end
	local function halfWidth(n)
		return (DRIP_WIDTH[1] + (DRIP_WIDTH[2] - DRIP_WIDTH[1]) * hash(n, 21)) / 2
	end
	local drips, at, n = {}, 0, 0
	while at < travelled do
		n += 1
		table.insert(drips, { at, halfWidth(n), DRIP_LENGTH[1] + (DRIP_LENGTH[2] - DRIP_LENGTH[1]) * hash(n, 22) })
		at += (halfWidth(n) + halfWidth(n + 1)) * (1 - DRIP_OVERLAP)
	end

	-- The outline is wound clockwise seen from above, so out is to the left
	-- of each step. A point's way out averages the steps either side of it.
	local rim = {}
	for i, p in points do
		local a, b = points[(i - 2) % count + 1], points[i % count + 1]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local length = math.max(math.sqrt(dx * dx + dy * dy), 1e-9)
		local ox, oy = -dy / length, dx / length
		local s = along[i]
		local depth = GRASS_LIP[1] + (GRASS_LIP[2] - GRASS_LIP[1]) * (0.5 + 0.5 * math.noise(s * 0.3 / DETAIL, 3.7))
		for _, drip in drips do
			-- The distance round the rim either way, so drips near the
			-- start also reach the end.
			local gap = math.abs(s - drip[1])
			gap = math.min(gap, travelled - gap)
			if gap < drip[2] then
				depth = math.max(depth, GRASS_LIP[1] + drip[3] * math.sqrt(1 - (gap / drip[2]) ^ 2))
			end
		end
		-- The finer octave never lifts the edge above the stone's top.
		depth = math.max(depth + DRIP_DETAIL * math.noise(s * DRIP_DETAIL_FREQUENCY, 8.1), 0.15 * DETAIL)
		table.insert(rim, {
			outer = { p[1] + ox * GRASS_OUTSET, p[2] + oy * GRASS_OUTSET },
			out = { ox, oy },
			inner = { p[1] + ox * 0.02 * DETAIL, p[2] + oy * 0.02 * DETAIL },
			depth = depth,
		})
	end

	local depths = {}
	for i, point in rim do
		depths[i] = point.depth
	end
	blurLoop(depths, GRASS_DEPTH_BLUR)
	for i, point in rim do
		point.depth = depths[i]
	end

	-- Pushed out of a sharp inward notch, the outer line crosses itself; the
	-- loop it makes is cut away at the crossing.
	local function crossing(a, b, c, d)
		local rx, ry, sx, sy = b[1] - a[1], b[2] - a[2], d[1] - c[1], d[2] - c[2]
		local denominator = rx * sy - ry * sx
		if math.abs(denominator) < 1e-12 then
			return nil
		end
		local t = ((c[1] - a[1]) * sy - (c[2] - a[2]) * sx) / denominator
		local u = ((c[1] - a[1]) * ry - (c[2] - a[2]) * rx) / denominator
		if t <= 0 or t >= 1 or u <= 0 or u >= 1 then
			return nil
		end
		return { a[1] + rx * t, a[2] + ry * t }
	end
	local i = 1
	while i < #rim do
		for k = 2, 12 do
			local j = i + k
			if j + 1 > #rim then
				break
			end
			local hit = crossing(rim[i].outer, rim[i + 1].outer, rim[j].outer, rim[j + 1].outer)
			if hit then
				local kept = rim[i]
				for _ = i + 1, j do
					table.remove(rim, i + 1)
				end
				table.insert(rim, i + 1, { outer = hit, out = kept.out, inner = kept.inner, depth = kept.depth })
				break
			end
		end
		i += 1
	end
	return rim
end

-- How deep the deepest drip hangs, for the grass's shading.
local GRASS_DEEPEST = GRASS_LIP[1] + DRIP_LENGTH[2]

-- Grass is dead straw with olive patches, darkening down
-- the hanging edge toward the drip tips, and splotched like the stone.
local paintGrass = rusting(0, function(x, y, z)
	local shade = 1 - DRIP_SHADE * math.clamp(-z / GRASS_DEEPEST, 0, 1)
	local tone, warm = splotchAt(x, y, z)
	-- On a big open island splotches read as hard discs, so grass takes a trace.
	if SOFT_GRASS then
		tone, warm = tone * GRASS_SPLOTCH, warm * GRASS_SPLOTCH
	end
	shade *= 1 + tone
	-- Patch strength from soft noise: 0 outside, 1 well inside a patch
	-- covering `cover` of the grass.
	local function patch(cover: number, seed: number): number
		local u, v = x / GRASS_PATCH_SIZE + seed, y / GRASS_PATCH_SIZE
		local n = 0.5 + math.noise(u, v, seed) + 0.3 * math.noise(u * 3, v * 3, seed + 5)
		return math.clamp((n - (1 - cover)) / (if SOFT_GRASS then 0.4 else 0.12), 0, 1)
	end
	local function toward(r, g, b, c, t)
		return r + (c[1] - r) * t, g + (c[2] - g) * t, b + (c[3] - b) * t
	end
	local r, g, b = toward(GRASS[1], GRASS[2], GRASS[3], GRASS_OLIVE, patch(GRASS_OLIVE_COVER, 11.3))
	-- Broad darker drifts of bare soil, so open ground isn't one even tone.
	if SOFT_GRASS then
		local drift = math.clamp((math.noise(x * 0.018, y * 0.018, 63.1) + 0.35 * math.noise(x * 0.07, y * 0.07, 12.4) - 0.28) / 0.45, 0, 1)
		r, g, b = toward(r, g, b, TRODDEN, drift * 0.42)
	end
	-- The worn apron round what stands on the top.
	local outside = wornDistance(x, y)
	local wobble = 0.4 * APRON_WIDTH * math.noise(x * 0.3, y * 0.3, 71.3)
	local wear = math.clamp(1 - (outside + wobble) / APRON_WIDTH, 0, 1)
	if wear > 0 then
		local patchy = 0.5 + 0.6 * math.noise(x * 0.55, y * 0.55, 93.1)
		local worn = math.clamp((wear - 0.75 * (1 - patchy)) / (if SOFT_GRASS then 0.55 else 0.2), 0, 1)
		if SOFT_GRASS then
			-- Wear gathers in stretches, not as an even ring round everything.
			worn *= math.clamp(0.55 + 1.3 * math.noise(x * 0.09, y * 0.09, 41.7), 0, 1)
		end
		local grit = 0.9 + 0.2 * math.noise(x * 1.7, y * 1.7, 17.9)
		r, g, b = toward(r, g, b, { TRODDEN[1] * grit, TRODDEN[2] * grit, TRODDEN[3] * grit }, worn)
	end
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

chunkedPart("Grass", nil, GRASS, function(mesh)
	local rim = grassRim()
	local count = #rim
	-- Corners of the turf: rings rounding over from its top edge (the first)
	-- down to its hanging edge (the last), rings curling the hanging edge's
	-- bottom under, the inner bottom of the hanging edge, and the inner edge
	-- where it meets the stone's top.
	local rings, curl, innerBottom, innerTop = {}, {}, {}, {}
	for k = 0, GRASS_ROUND_STEPS do
		rings[k], curl[k] = {}, {}
	end
	local outline = {}
	for i, point in rim do
		for k = 0, GRASS_ROUND_STEPS do
			local angle = k / GRASS_ROUND_STEPS * math.pi / 2
			local back = GRASS_ROUND * (1 - math.sin(angle))
			local x, y = point.outer[1] - point.out[1] * back, point.outer[2] - point.out[2] * back
			rings[k][i] = mesh:vertex(x, y, GRASS_HEIGHT - GRASS_ROUND * (1 - math.cos(angle)))
			if k == 0 then
				outline[i] = { x, y }
			end
		end
		for k = 0, GRASS_ROUND_STEPS do
			local angle = k / GRASS_ROUND_STEPS * math.pi / 2
			local back = GRASS_BOTTOM_ROUND * (1 - math.cos(angle))
			local x, y = point.outer[1] - point.out[1] * back, point.outer[2] - point.out[2] * back
			curl[k][i] = mesh:vertex(x, y, -point.depth + GRASS_BOTTOM_ROUND * (1 - math.sin(angle)))
		end
		innerBottom[i] = mesh:vertex(point.inner[1], point.inner[2], -point.depth)
		innerTop[i] = mesh:vertex(point.inner[1], point.inner[2], 0)
	end
	local top, edge = rings[0], rings[GRASS_ROUND_STEPS]
	for i = 1, count do
		local j = i % count + 1
		-- The rounded rim, ring by ring, facing out and up.
		for k = 1, GRASS_ROUND_STEPS do
			local upper, lower = rings[k - 1], rings[k]
			mesh:face({ lower[j], lower[i], upper[i] })
			mesh:face({ lower[j], upper[i], upper[j] })
		end
		-- Outside, facing out.
		local wallBottom, underEdge = curl[0], curl[GRASS_ROUND_STEPS]
		mesh:face({ wallBottom[j], wallBottom[i], edge[i] })
		mesh:face({ wallBottom[j], edge[i], edge[j] })
		-- The curl under, ring by ring, facing out and down.
		for k = 1, GRASS_ROUND_STEPS do
			local upper, lower = curl[k - 1], curl[k]
			mesh:face({ lower[j], lower[i], upper[i] })
			mesh:face({ lower[j], upper[i], upper[j] })
		end
		-- Underside, facing down.
		mesh:face({ underEdge[i], underEdge[j], innerBottom[j] })
		mesh:face({ underEdge[i], innerBottom[j], innerBottom[i] })
		-- Inside, facing the stone.
		mesh:face({ innerBottom[i], innerBottom[j], innerTop[j] })
		mesh:face({ innerBottom[i], innerTop[j], innerTop[i] })
	end
	-- The turf's top, facing up, cut into GRASS_TOP_CELL squares so no
	-- piece spans the island and the chunker can keep each texture small:
	-- the outline clipped to each square in turn, one edge at a time.
	local function clipped(points, axis: number, at: number, below: boolean)
		local kept = {}
		for i, a in points do
			local b = points[i % #points + 1]
			local aIn, bIn = (a[axis] <= at) == below, (b[axis] <= at) == below
			if aIn then
				table.insert(kept, a)
			end
			if aIn ~= bIn then
				local t = (at - a[axis]) / (b[axis] - a[axis])
				table.insert(kept, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t })
			end
		end
		return kept
	end
	-- Outline corners keep their ring vertex, so the top meets the rounded
	-- edge without a seam.
	local cornerOf = {}
	for i, p in outline do
		cornerOf[p] = top[i]
	end
	local low, high = { math.huge, math.huge }, { -math.huge, -math.huge }
	for _, p in outline do
		for axis = 1, 2 do
			low[axis], high[axis] = math.min(low[axis], p[axis]), math.max(high[axis], p[axis])
		end
	end
	-- A piece is buried when every corner of it lies deep in the worn ground.
	local function buried(piece): boolean
		for _, p in piece do
			if wornDistance(p[1], p[2]) > -COVER_INSET then
				return false
			end
		end
		return true
	end
	for cx = math.floor(low[1] / GRASS_TOP_CELL), math.floor(high[1] / GRASS_TOP_CELL) do
		for cy = math.floor(low[2] / GRASS_TOP_CELL), math.floor(high[2] / GRASS_TOP_CELL) do
			local piece = clipped(outline, 1, cx * GRASS_TOP_CELL, false)
			piece = clipped(piece, 1, (cx + 1) * GRASS_TOP_CELL, true)
			piece = clipped(piece, 2, cy * GRASS_TOP_CELL, false)
			piece = clipped(piece, 2, (cy + 1) * GRASS_TOP_CELL, true)
			if #piece >= 3 and not buried(piece) then
				local corners = {}
				for i, p in piece do
					corners[i] = cornerOf[p] or mesh:vertex(p[1], p[2], GRASS_HEIGHT)
				end
				for _, t in earClip(piece) do
					mesh:face({ corners[t[3]], corners[t[2]], corners[t[1]] })
				end
			end
		end
	end
end, nil, paintGrass, true, EDGE_REACH)

-- The chunks are shaded here rather than by finishParts, which has no corner
-- taper: highlights run full width at a corner and thin toward the middle of
-- an edge, as finishParts would otherwise shade them. Chunks of the island
-- count as one surface, so their seams shade like any other edge.
local chunks = {}
for _, entry in parts do
	table.insert(chunks, entry.mesh)
end
-- The bake paints a chunk with every chunk of its group, itself included and
-- in this order, each with its texture size and the chunk's own place in the
-- list (as finishParts does in common.luau).
local chunkSizes = {}
for _, entry in parts do
	table.insert(chunkSizes, { entry.image:width(), entry.image:height() })
end

-- A dirt chunk is handed only the cracks that could lie on it, not the whole
-- island's: the bake reads every stroke it is given, for every chunk. Cracks
-- are filed by the cell their start lies in, and a chunk takes those within
-- its own radius plus the stroke's reach and some slack for the bake's
-- stroke grid, in the order they were made.
local CRACK_CELL = 32
local CRACK_SLACK = 8
local crackCells = {}
local crackReach = 0
for index, stroke in crackStrokes do
	local key = `{math.floor(stroke.start[1] / CRACK_CELL)}_{math.floor(stroke.start[2] / CRACK_CELL)}_{math.floor(stroke.start[3] / CRACK_CELL)}`
	crackCells[key] = crackCells[key] or {}
	table.insert(crackCells[key], index)
	crackReach = math.max(crackReach, stroke.length + stroke.width)
end
local function cracksNear(mesh)
	local cx, cy, cz, radius = mesh:bounds()
	local widest = radius + crackReach + CRACK_SLACK
	local found = {}
	for x = math.floor((cx - widest) / CRACK_CELL), math.floor((cx + widest) / CRACK_CELL) do
		for y = math.floor((cy - widest) / CRACK_CELL), math.floor((cy + widest) / CRACK_CELL) do
			for z = math.floor((cz - widest) / CRACK_CELL), math.floor((cz + widest) / CRACK_CELL) do
				for _, index in crackCells[`{x}_{y}_{z}`] or {} do
					local stroke = crackStrokes[index]
					local dx, dy, dz = stroke.start[1] - cx, stroke.start[2] - cy, stroke.start[3] - cz
					local far = radius + stroke.length + stroke.width + CRACK_SLACK
					if dx * dx + dy * dy + dz * dz <= far * far then
						table.insert(found, index)
					end
				end
			end
		end
	end
	table.sort(found)
	local near = {}
	for i, index in found do
		near[i] = crackStrokes[index]
	end
	return near
end
for index, entry in parts do
	local kind = string.match(entry.name, "^%a+")
	local soft = kind == "Grass" or kind == "Dirt"
	entry.mesh:paintShading(entry.image, {
		highlight = if soft then EDGE_HIGHLIGHT * SOFT_SHADING else EDGE_HIGHLIGHT,
		shadow = if soft then CONTACT_SHADOW * SOFT_SHADING else CONTACT_SHADOW,
		gradient = GRADIENT,
		blend = EDGE_BLEND,
		group = chunks,
		groupSizes = chunkSizes,
		groupIndex = index,
		name = entry.name,
		paint = entry.paint,
		-- The rock paint is cached under the item's key, since its code is not hashed.
		custom = entry.custom,
		salt = CACHE_KEY,
		rust = entry.rust * WEAR,
		reach = EDGE_REACH,
		highlightWidth = HIGHLIGHT_WIDTH,
		cornerTaper = CORNER_TAPER,
		heightRange = entry.heightRange,
		strokes = if string.sub(entry.name, 1, 4) == "Dirt" then cracksNear(entry.mesh) else nil,
		tiledCoat = tiledCoat,
	})
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
