-- Mountain: a stylized peak built entirely from stone columns of every size
-- and shape, packed edge to edge like cracked basalt. Each column stands as
-- tall as the slope at its centre with a low faceted top, so the terrain
-- climbs in uneven steps to the summit and a lower shoulder. The columns are
-- the cells of a weighted Voronoi diagram (a power diagram) over scattered
-- stones, so big stones claim big cells. Only the faces that show are
-- built: a side wall runs down just past its neighbour's lowest top corner.
-- Centered on the origin, base at z = 0.
local RADIUS = 20
local PEAK = 28
local SMALLEST, LARGEST = 0.9, 2.8
-- Groove left between neighbouring columns.
local GAP = 0.12

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

-- Stones scattered over the disc by dart throwing, mostly small with a few
-- big ones, none crowding another: x, y and size.
local stones = {}
for _ = 1, 6000 do
	local angle, reach = random() * TAU, math.sqrt(random()) * RADIUS
	local x, y = reach * math.cos(angle), reach * math.sin(angle)
	local size = SMALLEST + (LARGEST - SMALLEST) * random() ^ 2
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
		table.insert(outline, { RADIUS * math.cos(angle), RADIUS * math.sin(angle), nil })
	end
	for other, neighbour in stones do
		if other ~= index and #outline >= 3 then
			local dx, dy = neighbour[1] - stone[1], neighbour[2] - stone[2]
			if dx * dx + dy * dy < (LARGEST * 3) ^ 2 then
				outline = clip(outline, stone, neighbour, other)
			end
		end
	end
	-- Cells cut by the outer rim are dropped, so the foot ends ragged
	-- instead of on a clean circle.
	local onRim = false
	for _, corner in outline do
		onRim = onRim or corner[3] == nil
	end
	if #outline < 3 or onRim then
		continue
	end
	local cx, cy = 0, 0
	for _, corner in outline do
		cx, cy = cx + corner[1] / #outline, cy + corner[2] / #outline
	end
	local rise = math.max(0.8, heightAt(cx, cy) + (hash(index, 1) - 0.5) * (1 + stone[3]))
	local tiltX, tiltY = (hash(index, 2) - 0.5) * 0.45, (hash(index, 3) - 0.5) * 0.45
	local corners, lowest = {}, math.huge
	for i, corner in outline do
		local ox, oy = corner[1] - cx, corner[2] - cy
		local pull = math.max(0, 1 - GAP / math.max(math.sqrt(ox * ox + oy * oy), 1e-3))
		local x, y = cx + ox * pull, cy + oy * pull
		local z = rise + ox * tiltX + oy * tiltY
		corners[i] = { x, y, z, corner[3] }
		lowest = math.min(lowest, z)
	end
	columns[index] = {
		corners = corners,
		lowest = lowest,
		-- The top rises to a low ridge point, so it reads as broken stone.
		peak = { cx, cy, rise + 0.15 * stone[3] * (0.5 + hash(index, 4)) },
	}
end

part("Columns", nil, STONE, function(mesh)
	for _, column in columns do
		local corners = column.corners
		local count = #corners
		local top = {}
		for i, corner in corners do
			top[i] = mesh:vertex(corner[1], corner[2], corner[3])
		end
		local peak = mesh:vertex(column.peak[1], column.peak[2], column.peak[3])
		for i = 1, count do
			mesh:face({ peak, top[i], top[i % count + 1] })
		end
		for i = 1, count do
			local a, b = corners[i], corners[i % count + 1]
			local neighbour = a[4] and columns[a[4]]
			local floor = if neighbour then math.max(0, neighbour.lowest - 0.6) else 0
			if math.max(a[3], b[3]) <= floor then
				continue
			end
			mesh:face({
				mesh:vertex(a[1], a[2], math.min(floor, a[3])),
				mesh:vertex(b[1], b[2], math.min(floor, b[3])),
				top[i % count + 1],
				top[i],
			})
		end
	end
end, false, 0.1, 1024, nil, true)

finishParts()
