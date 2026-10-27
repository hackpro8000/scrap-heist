-- Rock Cube: a cube cell-fractured into pieces. Seed points scattered through
-- the cube each claim the space nearer them than any other seed (a Voronoi
-- cell), and each cell is cut from the cube by the planes halfway between its
-- seed and each neighbouring seed. Every cell then shrinks a little toward its
-- seed, so the fractures show as seams, interior cells included.
local CUBE = 8
local SEEDS_PER_AXIS = 4
-- The cube's layers stacked up from the bottom, each a grid of seeds.
local LAYERS = 8
-- How uneven the cell sizes are, at the top and at the bottom of the cube:
-- the spread is set by e^(spread * r) for r from -1 to 1, and eases from one
-- to the other going down.
local SPREAD_TOP, SPREAD_BOTTOM = 1.2, 0.08
-- How far each seed wanders from the middle of its grid cell, as a share of
-- that cell's width.
local JITTER = 0.35
-- How far each cell shrinks toward its seed, as a share of its size.
local SEAM = 0.04
local ROCK_COLOUR = { 0.4, 0.36, 0.3 }

local function random(k: number): number
	local s = math.sin(k * 12.9898 + 4.1414) * 43758.5453
	return s - math.floor(s)
end

local function sub(a: { number }, b: { number }): { number }
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function dot(a: { number }, b: { number }): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function cross(a: { number }, b: { number }): { number }
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

-- The cube's six faces, as quads.
local BOX = {
	{ { 0, 0, 0 }, { 0, CUBE, 0 }, { 0, CUBE, CUBE }, { 0, 0, CUBE } },
	{ { CUBE, 0, 0 }, { CUBE, 0, CUBE }, { CUBE, CUBE, CUBE }, { CUBE, CUBE, 0 } },
	{ { 0, 0, 0 }, { 0, 0, CUBE }, { CUBE, 0, CUBE }, { CUBE, 0, 0 } },
	{ { 0, CUBE, 0 }, { CUBE, CUBE, 0 }, { CUBE, CUBE, CUBE }, { 0, CUBE, CUBE } },
	{ { 0, 0, 0 }, { CUBE, 0, 0 }, { CUBE, CUBE, 0 }, { 0, CUBE, 0 } },
	{ { 0, 0, CUBE }, { 0, CUBE, CUBE }, { CUBE, CUBE, CUBE }, { CUBE, 0, CUBE } },
}

-- Orders points round a plane with normal `n`, so they form a convex face.
local function orderRound(points: { { number } }, n: { number }): { { number } }
	local cx, cy, cz = 0, 0, 0
	for _, p in points do
		cx, cy, cz = cx + p[1] / #points, cy + p[2] / #points, cz + p[3] / #points
	end
	local centre = { cx, cy, cz }
	local helper = if math.abs(n[1]) < 0.9 then { 1, 0, 0 } else { 0, 1, 0 }
	local u = cross(n, helper)
	local v = cross(n, u)
	local angles = {}
	for i, p in points do
		local d = sub(p, centre)
		angles[i] = math.atan2(dot(d, v), dot(d, u))
	end
	local order = {}
	for i in points do table.insert(order, i) end
	table.sort(order, function(a, b) return angles[a] < angles[b] end)
	local ordered = {}
	for _, i in order do table.insert(ordered, points[i]) end
	return ordered
end

-- Keeps the part of a convex cell where dot(n, p) <= d, closing it with a new
-- face where the plane cuts through.
local function clip(cell: { { { number } } }, n: { number }, d: number): { { { number } } }
	local out, cut = {}, {}
	for _, poly in cell do
		local kept = {}
		for m = 1, #poly do
			local a, b = poly[m], poly[m % #poly + 1]
			local da, db = dot(n, a) - d, dot(n, b) - d
			if da <= 0 then table.insert(kept, a) end
			if da == 0 then table.insert(cut, a) end
			if (da < 0 and db > 0) or (da > 0 and db < 0) then
				local t = da / (da - db)
				local p = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
				table.insert(kept, p)
				table.insert(cut, p)
			end
		end
		if #kept >= 3 then table.insert(out, kept) end
	end
	if #cut >= 3 then table.insert(out, orderRound(cut, n)) end
	return out
end

-- The stops along one axis, `count` cells from 0 to CUBE, with widths
-- spread by `spread`.
local function stopsFor(seed: number, count: number, spread: number): { number }
	local widths, total = {}, 0
	for i = 1, count do
		widths[i] = math.exp(spread * (2 * random(seed + i) - 1))
		total += widths[i]
	end
	local stops, at = { [0] = 0 }, 0
	for i = 1, count do
		at += widths[i] / total * CUBE
		stops[i] = at
	end
	return stops
end

-- The seeds, in layers from the bottom up. Each layer's grid is spread by
-- how high it sits, so the top's cells vary widely and the bottom's barely.
local seeds = {}
do
	local layers = LAYERS
	for layer = 0, layers - 1 do
		local centre = (layer + 0.5) * CUBE / layers
		local spread = SPREAD_BOTTOM + (SPREAD_TOP - SPREAD_BOTTOM) * centre / CUBE
		local xs = stopsFor(layer * 1000 + 1, SEEDS_PER_AXIS, spread)
		local ys = stopsFor(layer * 1000 + 101, SEEDS_PER_AXIS, spread)
		for i = 1, SEEDS_PER_AXIS do
			for j = 1, SEEDS_PER_AXIS do
				local n = #seeds * 3
				local wx, wy = xs[i] - xs[i - 1], ys[j] - ys[j - 1]
				table.insert(seeds, {
					(xs[i] + xs[i - 1]) / 2 + JITTER * wx * (2 * random(n + 1) - 1),
					(ys[j] + ys[j - 1]) / 2 + JITTER * wy * (2 * random(n + 2) - 1),
					centre + JITTER * (CUBE / layers) * (2 * random(n + 3) - 1),
				})
			end
		end
	end
end

-- Each seed's cell: the cube cut by the bisector with every other seed.
local cells = {}
for s, seed in seeds do
	local cell = table.clone(BOX)
	for t, other in seeds do
		if t == s then continue end
		local n = sub(other, seed)
		local mid = { (seed[1] + other[1]) / 2, (seed[2] + other[2]) / 2, (seed[3] + other[3]) / 2 }
		cell = clip(cell, n, dot(n, mid))
	end
	cells[s] = cell
end

part("Rock", nil, ROCK_COLOUR, function(mesh)
	for s, seed in seeds do
		for _, poly in cells[s] do
			local ids, points = {}, {}
			for m, p in poly do
				local q = {
					seed[1] + (p[1] - seed[1]) * (1 - SEAM),
					seed[2] + (p[2] - seed[2]) * (1 - SEAM),
					seed[3] + (p[3] - seed[3]) * (1 - SEAM),
				}
				points[m] = q
				ids[m] = mesh:vertex(q[1], q[2], q[3])
			end
			-- Fan each face from its first point, wound so every triangle faces away from the seed.
			for m = 2, #poly - 1 do
				local a, b, c = points[1], points[m], points[m + 1]
				local normal = cross(sub(b, a), sub(c, a))
				local toward = { (a[1] + b[1] + c[1]) / 3 - seed[1], (a[2] + b[2] + c[2]) / 3 - seed[2], (a[3] + b[3] + c[3]) / 3 - seed[3] }
				if dot(normal, toward) >= 0 then
					mesh:face({ ids[1], ids[m], ids[m + 1] })
				else
					mesh:face({ ids[1], ids[m + 1], ids[m] })
				end
			end
		end
	end
end, nil, 0.6)

finishParts()
