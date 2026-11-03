-- Mountain (now a floating island): a mountain of stone columns turned
-- upside down, so a flat paved top hangs over a rocky cone that tapers to
-- a point below. The columns, of every size and shape, are packed edge to
-- edge like cracked basalt; each hangs as deep as the cone at its centre
-- with a low faceted tip, so the underside steps down in uneven tiers to
-- the lowest point and a shallower shoulder. The columns are the cells of
-- a weighted Voronoi diagram (a power diagram) over scattered stones, so
-- big stones claim big cells. Stones grow from small near the tip to big
-- at the rim, and the big rim stones give the top its lobed outline. Each
-- column is carved, a few angled planes chiselling chunks off its lower
-- corners and edges. The model is built the mountain way up (heights,
-- summit, foot) and flipped as it is written out. Centered on the origin,
-- top at z = 0.
local RADIUS = 20
local PEAK = 28
-- Stone sizes at the summit and at the foot.
local SMALLEST, LARGEST = 0.7, 4.5
-- Stones are scattered a stone's width past the rim, so rim cells close
-- on real neighbours before the ones outside are dropped.
local SCATTER = RADIUS + LARGEST
-- Shortest a column hangs, so the rim stones read as a thick slab.
local MIN_LENGTH = 4
-- Chisel cuts per column, at most, and how deep one bites as a share of
-- the stone's size.
local MAX_CUTS = 3
local CUT_DEPTH = { 0.2, 0.55 }
-- Fine chips per column (fewest, most) and how deep one bites, in studs.
local CHIPS = { 3, 6 }
local CHIP_DEPTH = { 0.15, 0.45 }
-- How far a cut's heading may swing from straight out, in radians.
local CUT_SPREAD = math.rad(55)

local STONE = { 0.46, 0.45, 0.5 }
-- Under the grass the rock is dirt, turning to stone between DIRT_FADE
-- studs down (first and last). The line wanders by up to DIRT_WOBBLE studs, so
-- it isn't a clean ring.
local DIRT = { 0.45, 0.33, 0.23 }
local DIRT_FADE = { 1.5, 5 }
local DIRT_WOBBLE = 1.2
-- Each rock shades from STONE times the first where it meets the top to
-- STONE times the second at its tip.
local ROCK_GRADIENT = { 1.1, 0.6 }
-- Brush splotches in the stone: one may sit in each cell of a 3D grid
-- (`cell` studs, with `chance`), a lobed blot `radius` studs across that
-- shifts the stone's tone by up to `tone` and its tint by up to `tint`. The
-- coat's brush strokes lay them on as dabs.
local SPLOTCH = { cell = 1.8, chance = 1, radius = { 1, 2 }, tone = 0.1, tint = 0.02 }
-- Texture pixels per stud; chunks are 1024 texels across at this density.
local TEXEL_DENSITY = 24
-- Edge highlights: how far edge paint reaches from an edge, in studs, and how
-- many times wider than the default the highlight strokes are.
local EDGE_REACH = 1
local HIGHLIGHT_WIDTH = 4
-- Studs over which a highlight thins from full width at a corner.
local CORNER_TAPER = 0.5

-- Grass over the top: a turf slab GRASS_HEIGHT thick, pushed GRASS_OUTSET
-- past the rim, whose edge hangs down as a lip (shallowest and deepest, in
-- studs) hung all along with tongues of grass dripping further down, each
-- DRIP_WIDTH across and DRIP_LENGTH below the lip. Neighbouring drips
-- overlap by DRIP_OVERLAP of their widths, so the edge runs as one
-- unbroken wave with no flat stretch between drips.
local GRASS = { 0.36, 0.58, 0.25 }
local GRASS_HEIGHT = 0.35
local GRASS_OUTSET = 0.25
local GRASS_LIP = { 0.3, 0.6 }
local DRIP_WIDTH = { 1.6, 4 }
local DRIP_LENGTH = { 0.6, 2.2 }
local DRIP_OVERLAP = 0.35
-- A finer octave of wobble over the wave: how far it moves the edge up or
-- down, in studs, and how fast it changes along the rim.
local DRIP_DETAIL = 0.6
local DRIP_DETAIL_FREQUENCY = 1.1
-- Spacing of the points the rim is walked in, in studs.
local GRASS_STEP = 0.25
-- The turf's top rolls over into its hanging edge on a quarter circle this
-- many studs across, in this many facets.
local GRASS_ROUND = 0.3
local GRASS_ROUND_STEPS = 4
-- How much the grass darkens toward the tip of the deepest drip.
local DRIP_SHADE = 0.35

-- Fixed per-column jitter, so the columns look uneven but every build matches.
local function hash(i: number, j: number): number
	local n = math.sin(i * 127.1 + j * 311.7) * 43758.5453
	return n - math.floor(n)
end

local seed = 11
local function random(): number
	seed = (seed * 16807) % 2147483647
	return seed / 2147483647
end

-- Height of the slope at a point: the main cone, ridges running down from
-- the summit, and a lower shoulder peak off to one side.
local function heightAt(x: number, y: number): number
	local r = math.sqrt(x * x + y * y) / RADIUS
	local angle = math.atan2(y, x)
	local ridges = 1 + 0.12 * math.cos(angle * 5) * r
	local main = PEAK * math.max(0, 1 - r * ridges) ^ 1.25
	local sx, sy = x - 8, y + 5
	local shoulder = 19 * math.max(0, 1 - math.sqrt(sx * sx + sy * sy) / 11) ^ 1.1
	return math.max(main, shoulder)
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
	-- Stones outside the rim, and cells cut by the scatter's edge, are
	-- dropped, so the foot ends on whole stones instead of a clean circle.
	local onEdge = stone[1] ^ 2 + stone[2] ^ 2 > RADIUS ^ 2
	for _, corner in outline do
		onEdge = onEdge or corner[3] == nil
	end
	if #outline < 3 or onEdge then
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

	-- Chisel cuts: each faces out and up at its own angle, from a low
	-- slant (shaving a side edge) to steep (bevelling the top), and
	-- bites a set depth in from the farthest point along it. None is
	-- near level, which would open holes down between columns. Every cut
	-- faces away from the island's centre, within CUT_SPREAD either side,
	-- so the carving shows on the outside and never faces inward.
	local outward = math.atan2(column.peak[2], column.peak[1])
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
		-- A cut stops short of the foot, which becomes the island's top,
		-- so shallow stones are never carved through into the surface.
		local footmost = -math.huge
		for _, corner in corners do
			footmost = math.max(footmost, corner[1] * n[1] + corner[2] * n[2])
		end
		local plane = math.max(farthest - depth, footmost + 0.3)
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
	column.shownFrom = math.min(column.shownFrom, column.peak[3])
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
local paintRock = rusting(0.1, function(x, y, z)
	local rock = rockAt(x, y)
	local depth = if rock
		then math.clamp((-z - rock.shownFrom) / math.max(rock.peak[3] - rock.shownFrom, 0.5), 0, 1)
		else 0
	local shade = ROCK_GRADIENT[1] + (ROCK_GRADIENT[2] - ROCK_GRADIENT[1]) * depth ^ 0.8
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	local wobble = DIRT_WOBBLE * math.noise(x * 0.25, y * 0.25, z * 0.25)
	local dirt = 1 - math.clamp((-z + wobble - DIRT_FADE[1]) / (DIRT_FADE[2] - DIRT_FADE[1]), 0, 1)
	dirt = dirt * dirt * (3 - 2 * dirt)
	local r = STONE[1] + (DIRT[1] - STONE[1]) * dirt
	local g = STONE[2] + (DIRT[2] - STONE[2]) * dirt
	local b = STONE[3] + (DIRT[3] - STONE[3]) * dirt
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

-- The island's flat top as one outline: the stones' feet (faces lying on
-- z = 0) laid together, with every edge two stones share cancelled out,
-- chained into a loop wound like the feet (clockwise seen from above) and
-- stripped of corners that sit in a straight line.
local function topOutline()
	local function key(p)
		return `{math.round(p[1] * 1e4)},{math.round(p[2] * 1e4)}`
	end
	local edges, points = {}, {}
	for _, column in columns do
		for _, face in column.faces do
			local foot = true
			for _, p in face do
				foot = foot and p[3] == 0
			end
			if foot then
				for i, a in face do
					local b = face[i % #face + 1]
					local from, to = key(a), key(b)
					points[from], points[to] = a, b
					if edges[`{to}>{from}`] then
						edges[`{to}>{from}`] = nil
					else
						edges[`{from}>{to}`] = { from, to }
					end
				end
			end
		end
	end
	local nextOf, first, count = {}, nil, 0
	for _, edge in edges do
		assert(nextOf[edge[1]] == nil, "Mountain: the top outline branches")
		nextOf[edge[1]] = edge[2]
		first = first or edge[1]
		count += 1
	end
	local loop, at = {}, first
	repeat
		table.insert(loop, points[at])
		at = nextOf[at]
	until at == first or at == nil
	assert(#loop == count, "Mountain: the top is not one outline")
	local outline = {}
	for i, b in loop do
		local a, c = loop[(i - 2) % #loop + 1], loop[i % #loop + 1]
		if math.abs((b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])) > 1e-6 then
			table.insert(outline, { b[1], b[2] })
		end
	end
	return outline
end

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

chunkedPart("Columns", nil, STONE, function(mesh)
	for _, column in columns do
		local neighbours = {}
		for _, corner in column.corners do
			if corner[4] and columns[corner[4]] then
				table.insert(neighbours, columns[corner[4]])
			end
		end
		for _, face in column.faces do
			-- The feet are built below as one merged top.
			local foot = true
			for _, p in face do
				foot = foot and p[3] == 0
			end
			if foot then
				continue
			end
			-- Only what no neighbour covers is built, so nothing lies buried
			-- inside the island.
			local pieces = { face }
			for _, neighbour in neighbours do
				local kept = {}
				for _, piece in pieces do
					for _, part in uncovered(piece, neighbour) do
						table.insert(kept, part)
					end
				end
				pieces = kept
			end
			for _, piece in pieces do
				addFlipped(mesh, piece)
			end
		end
	end
	-- The flat top is left open: the grass covers it.
end, false, paintRock, true, EDGE_REACH)

-- The rim walked in even steps, each point pushed out from the stone by the
-- grass's outset (outer) and a hair's width (inner), with how deep the grass
-- hangs there.
local function grassRim()
	local outline = topOutline()
	local points = {}
	for i, a in outline do
		local b = outline[i % #outline + 1]
		local length = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		local steps = math.max(1, math.round(length / GRASS_STEP))
		for k = 0, steps - 1 do
			local t = k / steps
			table.insert(points, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t })
		end
	end
	local count = #points

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
		local depth = GRASS_LIP[1] + (GRASS_LIP[2] - GRASS_LIP[1]) * (0.5 + 0.5 * math.noise(s * 0.3, 3.7))
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
		depth = math.max(depth + DRIP_DETAIL * math.noise(s * DRIP_DETAIL_FREQUENCY, 8.1), 0.15)
		table.insert(rim, {
			outer = { p[1] + ox * GRASS_OUTSET, p[2] + oy * GRASS_OUTSET },
			out = { ox, oy },
			inner = { p[1] + ox * 0.02, p[2] + oy * 0.02 },
			depth = depth,
		})
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

-- Grass is green, darkening down the hanging edge toward the drip tips, and
-- splotched like the stone.
local paintGrass = rusting(0, function(x, y, z)
	local shade = 1 - DRIP_SHADE * math.clamp(-z / GRASS_DEEPEST, 0, 1)
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	return GRASS[1] * shade * (1 + warm), GRASS[2] * shade, GRASS[3] * shade * (1 - warm)
end)

chunkedPart("Grass", nil, GRASS, function(mesh)
	local rim = grassRim()
	local count = #rim
	-- Corners of the turf: rings rounding over from its top edge (the first)
	-- down to its hanging edge (the last), the outer and inner bottom of the
	-- hanging edge, and the inner edge where it meets the stone's top.
	local rings, outerBottom, innerBottom, innerTop = {}, {}, {}, {}
	for k = 0, GRASS_ROUND_STEPS do
		rings[k] = {}
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
		outerBottom[i] = mesh:vertex(point.outer[1], point.outer[2], -point.depth)
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
		mesh:face({ outerBottom[j], outerBottom[i], edge[i] })
		mesh:face({ outerBottom[j], edge[i], edge[j] })
		-- Underside, facing down.
		mesh:face({ outerBottom[i], outerBottom[j], innerBottom[j] })
		mesh:face({ outerBottom[i], innerBottom[j], innerBottom[i] })
		-- Inside, facing the stone.
		mesh:face({ innerBottom[i], innerBottom[j], innerTop[j] })
		mesh:face({ innerBottom[i], innerTop[j], innerTop[i] })
	end
	-- The turf's top, one piece facing up.
	for _, t in earClip(outline) do
		mesh:face({ top[t[3]], top[t[2]], top[t[1]] })
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
