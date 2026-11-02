-- Mountain: a stylized peak built entirely from stone columns of every size
-- and shape, packed edge to edge like cracked basalt. Each column stands as
-- tall as the slope at its centre with a low faceted top, so the terrain
-- climbs in uneven steps to the summit and a lower shoulder. The columns are
-- the cells of a weighted Voronoi diagram (a power diagram) over scattered
-- stones, so big stones claim big cells. Stones grow from small near the
-- summit to big at the foot, and the big foot stones give the rim its
-- lobed outline. Only the faces that show are
-- built: a side wall runs down just past its neighbour's lowest top corner.
-- Centered on the origin, base at z = 0.
local RADIUS = 20
local PEAK = 28
-- Stone sizes at the summit and at the foot.
local SMALLEST, LARGEST = 0.7, 4.5
-- Stones are scattered a stone's width past the rim, so rim cells close
-- on real neighbours before the ones outside are dropped.
local SCATTER = RADIUS + LARGEST
-- Groove left between neighbouring columns.
local GAP = 0.12
-- Crack where a column is sliced through, and the steepest a slice leans.
local SLICE_GAP = 0.16
local SLICE_TILT = 0.4

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
		index = index,
		centre = { cx, cy },
		corners = corners,
		lowest = lowest,
		-- The top rises to a low ridge point, so it reads as broken stone.
		peak = { cx, cy, rise + 0.15 * stone[3] * (0.5 + hash(index, 4)) },
	}
end

-- Planes slicing a column through its exposed height at irregular spacing
-- and lean, each kept clear of the one below and of the top at every corner:
-- a plane is its height at the centre and its lean along x and y.
local function slicesOf(column, exposedFrom: number)
	local corners, index = column.corners, column.index
	local cx, cy = column.centre[1], column.centre[2]
	local function heightOn(plane, corner)
		return plane[1] + (corner[1] - cx) * plane[2] + (corner[2] - cy) * plane[3]
	end
	local slices = {}
	local below = { exposedFrom, 0, 0 }
	for k = 1, 3 do
		local plane = {
			below[1] + 1.4 + 2.6 * hash(index, 10 + k),
			(hash(index, 20 + k) - 0.5) * 2 * SLICE_TILT,
			(hash(index, 30 + k) - 0.5) * 2 * SLICE_TILT,
		}
		local clear = true
		for _, corner in corners do
			local z = heightOn(plane, corner)
			clear = clear and z > heightOn(below, corner) + 0.6 and z < corner[3] - 0.6
		end
		if not clear then
			break
		end
		table.insert(slices, plane)
		below = plane
	end
	return slices, heightOn
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

		-- How far down each side shows above its neighbour.
		local floors, exposedFrom = {}, math.huge
		for i, corner in corners do
			local neighbour = corner[4] and columns[corner[4]]
			floors[i] = if neighbour then math.max(0, neighbour.lowest - 0.6) else 0
			exposedFrom = math.min(exposedFrom, floors[i])
		end

		-- The column as stacked segments, split by the slices with a crack
		-- between, each with caps facing into the crack.
		local slices, heightOn = slicesOf(column, exposedFrom)
		local bounds = { function(_corner)
			return -math.huge
		end }
		for _, plane in slices do
			local function lower(corner)
				return heightOn(plane, corner) - SLICE_GAP / 2
			end
			local function upper(corner)
				return heightOn(plane, corner) + SLICE_GAP / 2
			end
			table.insert(bounds, lower)
			table.insert(bounds, upper)
			local up, down = {}, {}
			for i, corner in corners do
				up[i] = mesh:vertex(corner[1], corner[2], lower(corner))
				down[count + 1 - i] = mesh:vertex(corner[1], corner[2], upper(corner))
			end
			mesh:face(up)
			mesh:face(down)
		end
		table.insert(bounds, function(corner)
			return corner[3]
		end)

		for segment = 1, #bounds, 2 do
			local bottomAt, topAt = bounds[segment], bounds[segment + 1]
			for i = 1, count do
				local j = i % count + 1
				local a, b = corners[i], corners[j]
				local aTop, bTop = topAt(a), topAt(b)
				if math.max(aTop, bTop) <= floors[i] then
					continue
				end
				local aBottom = math.min(math.max(bottomAt(a), floors[i]), aTop)
				local bBottom = math.min(math.max(bottomAt(b), floors[i]), bTop)
				mesh:face({
					mesh:vertex(a[1], a[2], aBottom),
					mesh:vertex(b[1], b[2], bBottom),
					if segment == #bounds - 1 then top[j] else mesh:vertex(b[1], b[2], bTop),
					if segment == #bounds - 1 then top[i] else mesh:vertex(a[1], a[2], aTop),
				})
			end
		end
	end
end, false, 0.1, 1024, nil, true)

finishParts()
