-- Mountain: a stylized low-poly stone peak with a shoulder summit and flat
-- facets, built as one jittered polar heightfield. Centered on the origin,
-- base at z = 0.
local RADIUS = 20
local PEAK = 28
local RINGS, SECTORS = 9, 16

local ROCK = { 0.5, 0.49, 0.53 }

-- Fixed per-vertex jitter, so the facets look hand cut but every build matches.
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

-- Every triangle of the heightfield, as three points.
local triangles = {}
do
	local points = { [0] = { { 0, 0, PEAK } } }
	for j = 1, RINGS do
		points[j] = {}
		for i = 0, SECTORS - 1 do
			local edge = j == RINGS
			local r = RADIUS * j / RINGS * (1 + (hash(i, j) - 0.5) * (if edge then 0.12 else 0.18))
			local angle = (i + (hash(j, i) - 0.5) * 0.5) / SECTORS * math.pi * 2
			local x, y = r * math.cos(angle), r * math.sin(angle)
			local z = if edge then 0 else heightAt(x, y) + (hash(i + 7, j) - 0.5) * 1.6
			points[j][i] = { x, y, math.max(z, 0) }
		end
	end
	for i = 0, SECTORS - 1 do
		local nextI = (i + 1) % SECTORS
		table.insert(triangles, { points[0][1], points[1][i], points[1][nextI] })
		for j = 1, RINGS - 1 do
			local a, b = points[j][i], points[j][nextI]
			local c, d = points[j + 1][nextI], points[j + 1][i]
			-- Alternate the split so the facets don't all lean one way.
			if (i + j) % 2 == 0 then
				table.insert(triangles, { a, d, c })
				table.insert(triangles, { a, c, b })
			else
				table.insert(triangles, { a, d, b })
				table.insert(triangles, { b, d, c })
			end
		end
	end
end

part("Rock", nil, ROCK, function(mesh)
	for _, triangle in triangles do
		local verts = {}
		for k, p in triangle do
			verts[k] = mesh:vertex(p[1], p[2], p[3])
		end
		mesh:face(verts)
	end
end, false, 0.1, nil, nil, true)

-- Clusters of hexagonal basalt columns pushing out of the slope: x, y,
-- column radius and how tall the tallest stands above the ground.
local COLUMN_STONE = { 0.42, 0.41, 0.46 }
local CLUSTERS = {
	{ 13, 6, 1.3, 6 },
	{ -4, 14, 1.2, 5 },
	{ -14, 4, 1.4, 7 },
	{ -9, -11, 1.2, 5 },
	{ 5, -14, 1.3, 6 },
	{ 3, 6, 1, 4 },
	{ -5, -3, 1, 3.5 },
}

-- One column sunk into the slope, its top cut on a slant.
local function column(mesh, cx, cy, radius, rise, tiltX, tiltY)
	local ground = heightAt(cx, cy)
	local bottom, top = {}, {}
	for i = 0, 5 do
		local angle = i / 6 * TAU
		local x, y = cx + radius * math.cos(angle), cy + radius * math.sin(angle)
		bottom[i + 1] = mesh:vertex(x, y, ground - 2)
		top[i + 1] = mesh:vertex(x, y, ground + rise + (x - cx) * tiltX + (y - cy) * tiltY)
	end
	for i = 1, 6 do
		local j = i % 6 + 1
		mesh:face({ bottom[i], bottom[j], top[j], top[i] })
	end
	mesh:face(top)
end

part("Columns", nil, COLUMN_STONE, function(mesh)
	for c, cluster in CLUSTERS do
		local cx, cy, radius, tallest = cluster[1], cluster[2], cluster[3], cluster[4]
		-- A centre column with a ring of six packed round it, a few left out.
		local spots = { { cx, cy } }
		for i = 0, 5 do
			local angle = (i + 0.5) / 6 * TAU
			table.insert(spots, { cx + radius * math.sqrt(3) * math.cos(angle), cy + radius * math.sqrt(3) * math.sin(angle) })
		end
		for s, spot in spots do
			if s > 1 and hash(c, s) < 0.3 then
				continue
			end
			local rise = tallest * (if s == 1 then 1 else 0.45 + 0.4 * hash(s, c))
			column(mesh, spot[1], spot[2], radius * 0.97, rise, (hash(c + 3, s) - 0.5) * 0.5, (hash(s + 3, c) - 0.5) * 0.5)
		end
	end
end, false, 0.1, nil, nil, true)

finishParts()
