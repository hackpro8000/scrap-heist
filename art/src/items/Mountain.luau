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
-- Groove left between neighbouring columns.
local GAP = 0.12
-- Chisel cuts per column, at most, and how deep one bites as a share of
-- the stone's size.
local MAX_CUTS = 3
local CUT_DEPTH = { 0.2, 0.55 }
-- How far a cut's heading may swing from straight out, in radians.
local CUT_SPREAD = math.rad(55)

local STONE = { 0.46, 0.45, 0.5 }

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

-- Each stone's column: its outline pulled in by the groove, and its top
-- corners on a slanted plane.
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
	local rise = math.max(0.8, heightAt(cx, cy) + (hash(index, 1) - 0.5) * (1 + stone[3]))
	local tiltX, tiltY = (hash(index, 2) - 0.5) * 0.45, (hash(index, 3) - 0.5) * 0.45
	local corners = {}
	for i, corner in outline do
		local ox, oy = corner[1] - cx, corner[2] - cy
		local pull = math.max(0, 1 - GAP / math.max(math.sqrt(ox * ox + oy * oy), 1e-3))
		local x, y = cx + ox * pull, cy + oy * pull
		local z = rise + ox * tiltX + oy * tiltY
		corners[i] = { x, y, z, corner[3] }
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

part("Columns", nil, STONE, function(mesh)
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
		for k = 1, 1 + math.floor(hash(index, 40) * MAX_CUTS) do
			local heading = outward + (hash(index, 40 + k) - 0.5) * 2 * CUT_SPREAD
			local lift = 0.35 + hash(index, 50 + k) * 0.85
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
			local depth = column.size * (CUT_DEPTH[1] + (CUT_DEPTH[2] - CUT_DEPTH[1]) * hash(index, 60 + k))
			local plane = math.max(farthest - depth, footmost + 0.3)
			if plane < farthest then
				faces = carve(faces, n, plane)
			end
		end

		-- Flipped upside down: z mirrors, and the winding reverses so faces
		-- still point outward. The foot becomes the island's flat top.
		for _, face in faces do
			local verts = {}
			for i, p in face do
				verts[#face + 1 - i] = mesh:vertex(p[1], p[2], -p[3])
			end
			mesh:face(verts)
		end
	end
end, false, 0.1, 1024, nil, true)

finishParts()
