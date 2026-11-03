-- Column Island: the generator for the map's floating islands, a mountain
-- of stone columns turned upside down, so a flat stone top hangs over a
-- rocky cone that tapers to a point below. The columns, of every size and
-- shape, are packed edge to edge like cracked basalt; each hangs as deep as
-- the cone at its centre with a low faceted tip, so the underside steps down
-- in uneven tiers to the lowest point and a shallower shoulder. The columns
-- are the cells of a weighted Voronoi diagram (a power diagram) over
-- scattered stones, so big stones claim big cells. Stones grow from small
-- near the tip to big at the rim, all trimmed to a gently wobbling rim.
-- Each column is carved, a few angled planes chiselling chunks off its
-- lower corners and edges. The model is built the mountain
-- way up (heights, summit, foot) and flipped as it is written out. Centered
-- on the origin, stone top at z = 0.
--
-- The item including this sets:
--   RADIUS        the island's radius;
--   PEAK          how far the cone hangs below the top;
--   SEED          which scatter of stones it gets.
-- Stone sizes at the summit and at the foot, as shares of the radius, so
-- a bigger island has bigger stones rather than more of them.
local SMALLEST, LARGEST = 0.055 * RADIUS, 0.34 * RADIUS
-- Every other size in studs below was tuned on stones up to 4.5 studs
-- across and is multiplied by DETAIL, so an island with bigger stones looks
-- the same, only bigger: chips and the paint's blotches grow with the stones.
local DETAIL = LARGEST / 4.5
-- The rim the columns are trimmed to: a circle of RIM_PUSH * RADIUS
-- swelling and dipping by up to RIM_WOBBLE of it in broad waves, so the top
-- is a dependable surface rather than sharp lobes and bays. RIM_SIDES flat
-- facets make it up, so the rim stones end in cut faces.
local RIM_WOBBLE = 0.16
local RIM_SIDES = 192
-- The rim stands RIM_PUSH times RADIUS out.
local RIM_PUSH = 1.1
-- The top tier, this deep under the top, stays a clean wall straight down
-- from the rim: chisel cuts and chips all start below it.
local TOP_TIER = 1.5 * DETAIL
-- Stones are scattered a stone's width past the rim, so rim cells close
-- on real neighbours before they are trimmed to it.
local SCATTER = RIM_PUSH * RADIUS + LARGEST
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
-- island's depth down to the tip, where it covers SOOT_COVER of it.
local SOOT = { 0.1, 0.09, 0.09 }
local SOOT_FROM = 0.55
local SOOT_COVER = 0.5

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
	return RIM_PUSH * RADIUS * (1 + RIM_WOBBLE * wave)
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
		-- A cut stops short of the top tier, so the wall under the rim is
		-- never carved into.
		local tiermost = -math.huge
		for _, corner in corners do
			tiermost = math.max(tiermost, corner[1] * n[1] + corner[2] * n[2] + TOP_TIER * n[3])
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

-- How deep the island hangs at its lowest point.
local islandDepth = 0
for _, column in columns do
	islandDepth = math.max(islandDepth, column.peak[3])
end

-- Every column is one solid of stone.
for _, column in columns do
	column.solids = { { faces = column.faces } }
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
-- island hangs below z = 0, so depth is -z.
local paintRock = rusting(0.1, function(x, y, z)
	local rock = rockAt(x, y)
	local depth = if rock
		then math.clamp((-z - rock.shownFrom) / math.max(rock.peak[3] - rock.shownFrom, 0.5), 0, 1)
		else 0
	local shade = ROCK_GRADIENT[1] + (ROCK_GRADIENT[2] - ROCK_GRADIENT[1]) * depth ^ 0.8
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	local r, g, b = STONE[1], STONE[2], STONE[3]
	-- Soot: dark blotches spreading over the lower stone.
	local sooting = math.clamp((-z / islandDepth - SOOT_FROM) / (1 - SOOT_FROM), 0, 1)
	if sooting > 0 then
		local f = 0.3 / DETAIL
		local blot = 0.5 + math.noise(x * f + 53, y * f, z * f) + 0.3 * math.noise(x * f * 3.7, y * f * 3.7, z * f * 3.7 + 29)
		local soot = 0.85 * math.clamp((blot - (1 - SOOT_COVER * sooting)) / 0.2, 0, 1)
		r, g, b = r + (SOOT[1] - r) * soot, g + (SOOT[2] - g) * soot, b + (SOOT[3] - b) * soot
	end
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

-- The faces of every column that show, the flat top among them. Only what
-- no neighbour covers is kept, so nothing lies buried inside the island.
local function visibleRock()
	local shown = {}
	for _, column in columns do
		for _, solid in column.solids do
			local others = coverersOf(column, solid)
			for _, face in solid.faces do
				if isFoot(face) then
					table.insert(shown, face)
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

chunkedPart("Columns", nil, STONE, function(mesh)
	for _, piece in visibleRock() do
		addFlipped(mesh, piece)
	end
end, false, paintRock, true, EDGE_REACH)

-- The chunks are shaded here rather than by finishParts, which has no corner
-- taper: highlights run full width at a corner and thin toward the middle of
-- an edge, as finishParts would otherwise shade them. Chunks of the island
-- count as one surface, so their seams shade like any other edge.
local chunks = {}
for _, entry in parts do
	table.insert(chunks, entry.mesh)
end
for _, entry in parts do
	local group = {}
	for _, other in parts do
		if other ~= entry then
			table.insert(group, other.mesh)
		end
	end
	entry.mesh:paintShading(entry.image, {
		highlight = EDGE_HIGHLIGHT,
		shadow = CONTACT_SHADOW,
		gradient = GRADIENT,
		blend = EDGE_BLEND,
		group = group,
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
	})
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
