-- Mountain: a stylized peak built entirely from hexagonal basalt columns
-- packed on a grid, each standing as tall as the slope at its centre with
-- its top cut on a slant, so the terrain climbs in uneven steps to the
-- summit and a lower shoulder. Only the faces that show are built: a side
-- wall runs down just past its neighbour's lowest top corner. Centered on
-- the origin, base at z = 0.
local RADIUS = 20
local PEAK = 28
-- Corner radius of a column and the grid it packs on, a hair wider so a
-- groove shows between neighbours.
local COLUMN = 1.5
local SPACING = COLUMN * 1.04 * math.sqrt(3)

local STONE = { 0.46, 0.45, 0.5 }

-- Fixed per-column jitter, so the columns look uneven but every build matches.
local function hash(i: number, j: number): number
	local n = math.sin(i * 127.1 + j * 311.7) * 43758.5453
	return n - math.floor(n)
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

-- The six neighbours on the grid, one per side: side i faces 30 + 60i degrees.
local NEIGHBOURS = { { 1, 0 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { 0, -1 }, { 1, -1 } }

-- Every column's centre and top corners, keyed by its grid cell.
local columns = {}
local REACH = math.ceil(RADIUS / SPACING) + 1
for q = -REACH * 2, REACH * 2 do
	for r = -REACH * 2, REACH * 2 do
		local cx = q * SPACING * math.cos(math.pi / 6)
		local cy = q * SPACING * 0.5 + r * SPACING
		if cx * cx + cy * cy > RADIUS * RADIUS then
			continue
		end
		local rise = math.max(0.8, heightAt(cx, cy) + (hash(q, r) - 0.5) * 2.4)
		local tiltX, tiltY = (hash(q + 5, r) - 0.5) * 0.4, (hash(r + 5, q) - 0.5) * 0.4
		local corners = {}
		for i = 0, 5 do
			local angle = i / 6 * TAU
			local x, y = cx + COLUMN * math.cos(angle), cy + COLUMN * math.sin(angle)
			corners[i + 1] = { x, y, rise + (x - cx) * tiltX + (y - cy) * tiltY }
		end
		local lowest = math.huge
		for _, corner in corners do
			lowest = math.min(lowest, corner[3])
		end
		columns[`{q},{r}`] = { q = q, r = r, corners = corners, lowest = lowest }
	end
end

part("Columns", nil, STONE, function(mesh)
	for _, column in columns do
		local top = {}
		for i, corner in column.corners do
			top[i] = mesh:vertex(corner[1], corner[2], corner[3])
		end
		mesh:face(top)
		for i = 1, 6 do
			local offset = NEIGHBOURS[i]
			local neighbour = columns[`{column.q + offset[1]},{column.r + offset[2]}`]
			local floor = if neighbour then math.max(0, neighbour.lowest - 0.6) else 0
			local a, b = column.corners[i], column.corners[i % 6 + 1]
			if math.max(a[3], b[3]) <= floor then
				continue
			end
			mesh:face({
				mesh:vertex(a[1], a[2], math.min(floor, a[3])),
				mesh:vertex(b[1], b[2], math.min(floor, b[3])),
				top[i % 6 + 1],
				top[i],
			})
		end
	end
end, false, 0.1, nil, nil, true)

finishParts()
