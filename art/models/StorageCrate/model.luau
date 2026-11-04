-- Storage crate: a lopsided green scrap bin that flares toward its wobbly rim,
-- leaning and twisting as it rises. Bolted patch plates cover its sides, a
-- hazard band runs round its foot and a fat orange tube trims the rim. Six fill
-- levels heap scrap inside with junk (tires, cogs, springs, cones) sticking out;
-- the game shows one level's Fill_N group at a time.
-- Sits on the ground with its base at the origin.

-- Bin shape: footprint at the base and the rim, height, how far the rim leans
-- along x, its twist in degrees, how far the sides bulge out and the wall
-- thickness.
local BOTTOM_WIDTH = 4.2
local BOTTOM_DEPTH = 2.9
local TOP_WIDTH = 5.8
local TOP_DEPTH = 4.0
local HEIGHT = 2.9
local LEAN = 0.45
local TWIST = 7
local BULGE = 0.28
local WALL = 0.22
-- Wall resolution: columns per side, rows from floor to rim.
local COLUMNS = 4
local ROWS = 3

local BOLT_SIZE = 0.102
local TRIM_SIZE = 0.16
local TRIM_SAMPLES = 12
-- Hazard band: from and to (0-1 of the height), stripe count and slant.
local HAZARD_LOW = 0.03
local HAZARD_HIGH = 0.2
local HAZARD_STRIPES = 48
local HAZARD_SLANT = 1.9

-- Patch plates: thickness, and the gap they sit off the wall.
local PLATE_SEED = 7
local PLATE_THICKNESS = 0.05
local STANDOFF = 0.015
-- Where plates go: {side, s from, s to}.
local PLATE_SPOTS = {
	{ 0, 0.22, 0.38 },
	{ 0, 0.62, 0.75 },
	{ 1, 0.4, 0.6 },
	{ 2, 0.25, 0.45 },
	{ 2, 0.6, 0.72 },
	{ 3, 0.4, 0.6 },
}

-- Per level: {height 0-1, mound, junk pieces}.
local FILL_LEVELS = {
	{ 0.15, 0.1, 1 },
	{ 0.3, 0.15, 2 },
	{ 0.45, 0.2, 4 },
	{ 0.6, 0.28, 6 },
	{ 0.75, 0.35, 8 },
	{ 0.9, 0.45, 11 },
}
local FILL_RINGS = 6
local FILL_PER_SIDE = 8
local FILL_LUMPS = 0.12

-- Junk on the heap, first pieces first: kind, spot on the heap (-1 to 1 of
-- its half size), how far it sinks in, tilt XYZ in degrees and scale. A piece
-- with `on` stands over that earlier piece instead, offset by `at`. Each is
-- dropped straight down until it meets the heap or a piece already there,
-- then sunk in by `sink`, so nothing hangs in the air.
local JUNK = {
	{ kind = "Tire", at = { -0.45, -0.2 }, sink = 0.12, tilt = { 25, -10, 23 } },
	{ kind = "Cog", at = { 0.2, 0.45 }, sink = 0.05, tilt = { 70, 15, 17 } },
	{ kind = "Spring", at = { 0.45, -0.35 }, sink = 0.3, tilt = { -12, 8, 0 } },
	{ kind = "Cone", at = { 0.75, 0.3 }, sink = 0.35, tilt = { 10, -35, 46 } },
	{ kind = "Cog", at = { -0.7, 0.5 }, sink = 0.08, tilt = { 60, -20, 70 }, scale = 0.8 },
	{ kind = "Spring", at = { -0.1, -0.6 }, sink = 0.25, tilt = { 55, 10, 30 }, scale = 0.9 },
	{ kind = "Tire", at = { 0.35, 0 }, sink = 0.15, tilt = { -12, 15, 60 }, scale = 0.8 },
	{ kind = "Cone", at = { -0.35, 0.4 }, sink = 0.3, tilt = { -30, 10, 110 } },
	{ kind = "Spring", at = { 0.8, -0.55 }, sink = 0.2, tilt = { -40, -20, 0 }, scale = 0.8 },
	{ kind = "Tire", on = 6, at = { 0.1, -0.05 }, sink = 0.05, tilt = { -6, 8, 15 }, scale = 0.7 },
	{ kind = "Cog", on = 0, at = { 0.15, 0.1 }, sink = 0.1, tilt = { 35, 5, 80 }, scale = 0.9 },
}

-- Palette, in sRGB.
local BODY = { 0.44, 0.68, 0.35 }
local BOLT = { 0.62, 0.58, 0.52 }
local TRIM = { 0.95, 0.55, 0.18 }
local HAZARD_YELLOW = { 0.98, 0.8, 0.12 }
local HAZARD_BLACK = { 0.08, 0.08, 0.08 }
local PLATE = { 0.55, 0.57, 0.6 }
local SCRAP = { 0.6, 0.5, 0.42 }
local RUBBER = { 0.2, 0.2, 0.23 }
local CHALK = { 0.45, 0.46, 0.5 }
local BRASS = { 0.8, 0.62, 0.26 }
local RUST = { 0.6, 0.3, 0.13 }
local SPRING_STEEL = { 0.7, 0.74, 0.8 }
local CONE_BAND = { 0.95, 0.94, 0.88 }
local GRIME = { 0.35, 0.3, 0.28 }

local TAU = 2 * math.pi

local function add(a, b)
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end

local function sub(a, b)
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function scale(a, k)
	return { a[1] * k, a[2] * k, a[3] * k }
end

local function dot(a, b)
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function cross(a, b)
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

local function normalize(a)
	local length = math.sqrt(dot(a, a))
	return if length > 0 then scale(a, 1 / length) else { 0, 0, 1 }
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Point on the bin's outer wall: side 0-3 going counterclockwise, s 0-1 along
-- that side, v 0-1 from floor to rim.
local CORNERS = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
local function wallPoint(side, s, v)
	local a, b = CORNERS[side + 1], CORNERS[(side + 1) % 4 + 1]
	local width, depth = lerp(BOTTOM_WIDTH, TOP_WIDTH, v), lerp(BOTTOM_DEPTH, TOP_DEPTH, v)
	local push = 1 + BULGE * math.sin(math.pi * s) * math.sin(math.pi * math.min(1.2 * v, 1)) / (width / 2)
	local x = lerp(a[1], b[1], s) * width / 2 * push
	local y = lerp(a[2], b[2], s) * depth / 2 * push
	local turn = math.rad(TWIST * v)
	x, y = x * math.cos(turn) - y * math.sin(turn), x * math.sin(turn) + y * math.cos(turn)
	local z = HEIGHT * v
	if v == 1 then
		-- Wobbly rim: a ripple, and a hump on the far side.
		local around = (side + s) / 4
		z += 0.12 * math.sin(around * 3 * TAU) + 0.25 * math.max(0, math.cos((around - 0.5) * TAU)) ^ 4
	end
	return { x + LEAN * v * v, y, z }
end

-- Point, outward normal, and the along/up directions of the wall there.
local function wallFrame(side, s, v)
	local point = wallPoint(side, s, v)
	local along = normalize(sub(wallPoint(side, math.min(s + 0.01, 1), v), wallPoint(side, math.max(s - 0.01, 0), v)))
	local low = math.min(v, 0.99)
	local rise = normalize(sub(wallPoint(side, s, low + 0.01), wallPoint(side, s, low)))
	local normal = normalize(cross(along, rise))
	return point, normal, along, cross(normal, along)
end

local function color(c)
	return c[1], c[2], c[3]
end

-- Hard-edged noise blobs of `blotch` over `base`; amount 0-1 is roughly how
-- much of the surface they cover.
local function blotched(base, blotch, size, amount, p)
	local n = math.noise(p[1] * size, p[2] * size, p[3] * size)
	return if n > 2 * (0.62 - amount * 0.25 - 0.5) then blotch else base
end

-- Tube along a path, with parallel-transport rings. Open tubes get end caps.
local function tube(mesh, points, radius, sides, cyclic)
	local count = #points
	local rings = {}
	local normal
	for i, point in points do
		local before = points[if i > 1 then i - 1 elseif cyclic then count else i]
		local after = points[if i < count then i + 1 elseif cyclic then 1 else i]
		local tangent = normalize(sub(after, before))
		if normal then
			normal = normalize(sub(normal, scale(tangent, dot(normal, tangent))))
		else
			local guide = if math.abs(tangent[3]) < 0.9 then { 0, 0, 1 } else { 1, 0, 0 }
			normal = normalize(cross(tangent, guide))
		end
		local binormal = cross(tangent, normal)
		local ring = {}
		for k = 0, sides - 1 do
			local a = k / sides * TAU
			local offset = add(scale(normal, math.cos(a) * radius), scale(binormal, math.sin(a) * radius))
			local p = add(point, offset)
			ring[k + 1] = mesh:vertex(p[1], p[2], p[3])
		end
		rings[i] = ring
	end
	for i = 1, if cyclic then count else count - 1 do
		local low, high = rings[i], rings[i % count + 1]
		for k = 1, sides do
			local m = k % sides + 1
			mesh:face({ low[k], low[m], high[m], high[k] })
		end
	end
	if not cyclic then
		local first, last = {}, rings[count]
		for k = sides, 1, -1 do
			table.insert(first, rings[1][k])
		end
		mesh:face(first)
		mesh:face(last)
	end
end

-- Bolt head: a short cone whose axis points along `normal`.
local function bolt(mesh, center, normal, along, size)
	local up = cross(normal, along)
	local segments = 8
	local base, top = {}, {}
	for k = 0, segments - 1 do
		local a = k / segments * TAU
		local radial = add(scale(along, math.cos(a)), scale(up, math.sin(a)))
		local low = add(add(center, scale(normal, -size / 2)), scale(radial, size))
		local high = add(add(center, scale(normal, size / 2)), scale(radial, size * 0.8))
		base[k + 1] = mesh:vertex(low[1], low[2], low[3])
		top[k + 1] = mesh:vertex(high[1], high[2], high[3])
	end
	local cap = {}
	for k = 1, segments do
		local m = k % segments + 1
		mesh:face({ base[k], base[m], top[m], top[k] })
		cap[segments - k + 1] = base[k]
	end
	mesh:face(cap)
	mesh:face(top)
end

-- Body: the open-topped bin, its wall thickened inward.
local function body()
	local mesh = Mesh.new()
	local rings = {}
	for row = 0, ROWS do
		local ring = {}
		for side = 0, 3 do
			for column = 0, COLUMNS - 1 do
				local p = wallPoint(side, column / COLUMNS, row / ROWS)
				table.insert(ring, mesh:vertex(p[1], p[2], p[3]))
			end
		end
		rings[row + 1] = ring
	end
	local count = #rings[1]
	local floor = {}
	for i = count, 1, -1 do
		table.insert(floor, rings[1][i])
	end
	mesh:face(floor)
	for row = 1, ROWS do
		local low, high = rings[row], rings[row + 1]
		for i = 1, count do
			local j = i % count + 1
			mesh:face({ low[i], low[j], high[j], high[i] })
		end
	end
	mesh:solidify(-WALL)
	mesh:setSmooth(60)
	return mesh
end

local function bodyBolts()
	local mesh = Mesh.new()
	for side = 0, 3 do
		for _, s in { 0.1, 0.9 } do
			for _, v in { 0.12, 0.88 } do
				-- Upper bolts follow the rim's wobble.
				if v > 0.5 then
					v += (wallPoint(side, s, 1)[3] - HEIGHT) * 1.6 / HEIGHT
				end
				local point, normal, along = wallFrame(side, s, v)
				bolt(mesh, add(point, scale(normal, BOLT_SIZE * 0.3)), normal, along, BOLT_SIZE)
			end
		end
	end
	return mesh
end

-- Fat tube round the rim, sunk halfway into the wall.
local function trim()
	local mesh = Mesh.new()
	local points = {}
	for side = 0, 3 do
		for i = 0, TRIM_SAMPLES - 1 do
			local s = i / TRIM_SAMPLES
			local _, normal = wallFrame(side, math.max(s, 0.02), 1)
			table.insert(points, sub(wallPoint(side, s, 1), scale(normal, WALL / 2)))
		end
	end
	tube(mesh, points, TRIM_SIZE, 8, true)
	mesh:setSmooth(true)
	return mesh
end

-- Hazard band round the foot, UV'd straight onto its stripe texture.
local function hazard()
	local mesh = Mesh.new()
	local columns = 16
	for side = 0, 3 do
		local grid = {}
		for column = 0, columns do
			grid[column] = {}
			for band = 0, 2 do
				local point, normal = wallFrame(side, column / columns, lerp(HAZARD_LOW, HAZARD_HIGH, band / 2))
				local p = add(point, scale(normal, STANDOFF))
				grid[column][band] = mesh:vertex(p[1], p[2], p[3])
			end
		end
		for column = 0, columns - 1 do
			for band = 0, 1 do
				local u0, u1 = (side + column / columns) / 4, (side + (column + 1) / columns) / 4
				local v0, v1 = band / 2, (band + 1) / 2
				mesh:face(
					{ grid[column][band], grid[column + 1][band], grid[column + 1][band + 1], grid[column][band + 1] },
					{ u0, v0, u1, v0, u1, v1, u0, v1 }
				)
			end
		end
	end
	local stripes = Image.new(1024, 64)
	for x = 0, 1023 do
		for y = 0, 63 do
			local u, band = (x + 0.5) / 1024, (y + 0.5) / 64
			local stripe = math.floor(u * HAZARD_STRIPES + band * HAZARD_SLANT) % 2
			local c = if band < 0.08 or band > 0.92 or stripe == 1 then HAZARD_BLACK else HAZARD_YELLOW
			stripes:set(x, y, color(c))
		end
	end
	return mesh, stripes
end

-- Patch plates: random scrappy quads bolted over the walls.
local function plates(bolts)
	math.randomseed(PLATE_SEED)
	local function uniform(a, b)
		return a + (b - a) * math.random()
	end
	local mesh = Mesh.new()
	local lift = STANDOFF + PLATE_THICKNESS
	for _, spot in PLATE_SPOTS do
		local side = spot[1]
		local s, v = uniform(spot[2], spot[3]), uniform(0.42, 0.62)
		local w, h = uniform(0.22, 0.85), uniform(0.16, 0.5)
		local shape = math.random(4)
		local taper = if shape == 2 then uniform(0.3, 0.75) else 1
		local shear = if shape == 3 then uniform(-0.5, 0.5) else 0
		local drop = if shape == 4 then uniform(0.4, 0.8) else 0
		local corners = { { -w, -h }, { w, -h }, { w * taper + shear, h - 2 * h * drop }, { -w * taper + shear, h } }
		local tilt = uniform(-0.3, 0.3)
		for _, c in corners do
			local x, y = c[1] + uniform(-0.12, 0.12), c[2] + uniform(-0.1, 0.1)
			c[1], c[2] = x * math.cos(tilt) - y * math.sin(tilt), x * math.sin(tilt) + y * math.cos(tilt)
		end
		local sideLength = lerp(BOTTOM_WIDTH, TOP_WIDTH, v) * (if side % 2 == 0 then 1 else TOP_DEPTH / TOP_WIDTH)
		-- Point on the plate at (a, b) 0-1 across its corners, snapped to the wall.
		local function snapped(a, b)
			local x = lerp(lerp(corners[1][1], corners[2][1], a), lerp(corners[4][1], corners[3][1], a), b)
			local y = lerp(lerp(corners[1][2], corners[2][2], a), lerp(corners[4][2], corners[3][2], a), b)
			local point, normal, along = wallFrame(side, s + x / sideLength, v + y / HEIGHT)
			return add(point, scale(normal, lift)), normal, along
		end
		local grid = {}
		for i = 0, 2 do
			grid[i] = {}
			for j = 0, 2 do
				local p = snapped(i / 2, j / 2)
				grid[i][j] = mesh:vertex(p[1], p[2], p[3])
			end
		end
		for i = 0, 1 do
			for j = 0, 1 do
				mesh:face({ grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1] })
			end
		end
		for _, at in { { 0.15, 0.18 }, { 0.85, 0.18 }, { 0.85, 0.82 }, { 0.15, 0.82 } } do
			local p, normal, along = snapped(at[1], at[2])
			bolt(bolts, add(p, scale(normal, BOLT_SIZE * 0.15)), normal, along, BOLT_SIZE / 2)
		end
	end
	mesh:solidify(-PLATE_THICKNESS)
	mesh:setSmooth(40)
	return mesh
end

-- Junk pieces in their own space: {verts, faces, smooth, solidify?, paint}.
local junkShapes = {}

function junkShapes.Tire()
	local verts, faces = {}, {}
	local segments, sides = 24, 8
	for i = 0, segments - 1 do
		local a = i / segments * TAU
		for j = 0, sides - 1 do
			local b = j / sides * TAU
			local minor = 0.3 + (if (i // 2) % 2 == 0 and math.cos(b) > 0.5 then 0.07 else 0)
			local r = 0.62 + minor * math.cos(b)
			table.insert(verts, { r * math.cos(a), r * math.sin(a), minor * math.sin(b) * 0.75 })
		end
	end
	for i = 0, segments - 1 do
		local n = (i + 1) % segments
		for j = 0, sides - 1 do
			local k = (j + 1) % sides
			table.insert(faces, { i * sides + j + 1, n * sides + j + 1, n * sides + k + 1, i * sides + k + 1 })
		end
	end
	return verts, faces, 40, nil, function(p)
		return blotched(RUBBER, CHALK, 1.5, 0.1, p)
	end
end

function junkShapes.Cog()
	local verts, faces = {}, {}
	local teeth = 32
	for i = 0, teeth - 1 do
		local a = TAU * (i - 0.5) / teeth
		local r = if i % 4 == 1 or i % 4 == 2 then 0.62 else 0.46
		table.insert(verts, { 0.16 * math.cos(a), 0.16 * math.sin(a), -0.1 })
		table.insert(verts, { r * math.cos(a), r * math.sin(a), -0.1 })
	end
	for i = 0, teeth - 1 do
		local j = (i + 1) % teeth
		table.insert(faces, { 2 * i + 1, 2 * i + 2, 2 * j + 2, 2 * j + 1 })
	end
	return verts, faces, 40, 0.2, function(p)
		return blotched(BRASS, RUST, 2.5, 0.35, p)
	end
end

function junkShapes.Spring()
	local points = {}
	local coils, steps = 5, 10
	for k = 0, coils * steps do
		local t = k / (coils * steps)
		local a = t * coils * TAU
		local lean = 0.25 * t * t + 0.05 * math.sin(9 * t)
		table.insert(points, { 0.3 * math.cos(a) + lean, 0.3 * math.sin(a), 1.1 * t })
	end
	return points, nil, 180, nil, function(p)
		return blotched(SPRING_STEEL, RUST, 4, 0.12, p)
	end
end

function junkShapes.Cone()
	local verts, faces = {}, {}
	local profile = { { 0.42, 0.12 }, { 0.36, 0.4 }, { 0.27, 0.75 }, { 0.17, 1.05 }, { 0.09, 1.25 } }
	local segments = 12
	for _, step in profile do
		local r, z = step[1], step[2]
		local bend = 0.18 * (z / 1.3) ^ 2
		for i = 0, segments - 1 do
			local a = i / segments * TAU
			table.insert(verts, { r * math.cos(a) + bend, r * math.sin(a), z })
		end
	end
	table.insert(verts, { 0.18, 0, 1.3 })
	local tip = #verts
	for ring = 0, #profile - 2 do
		for i = 0, segments - 1 do
			local j = (i + 1) % segments
			local low, high = ring * segments, (ring + 1) * segments
			table.insert(faces, { low + i + 1, low + j + 1, high + j + 1, high + i + 1 })
		end
	end
	local last = (#profile - 1) * segments
	for i = 0, segments - 1 do
		table.insert(faces, { last + i + 1, last + (i + 1) % segments + 1, tip })
	end
	-- Square foot.
	local foot = #verts
	for _, z in { 0, 0.12 } do
		for _, c in CORNERS do
			table.insert(verts, { c[1] * 0.5, c[2] * 0.5, z })
		end
	end
	local f = function(i)
		return foot + i
	end
	table.insert(faces, { f(4), f(3), f(2), f(1) })
	table.insert(faces, { f(5), f(6), f(7), f(8) })
	for i = 1, 4 do
		local j = i % 4 + 1
		table.insert(faces, { f(i), f(j), f(j + 4), f(i + 4) })
	end
	return verts, faces, 40, nil, function(p)
		local z = p[3]
		return if z < 0.15 then GRIME elseif z < 0.55 then TRIM elseif z < 0.75 then CONE_BAND else TRIM
	end
end

-- Tilt then turn, like Blender's XYZ Euler.
local function rotation(tilt)
	local x, y, z = math.rad(tilt[1]), math.rad(tilt[2]), math.rad(tilt[3])
	local cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
	return {
		{ cz * cy, cz * sy * sx - sz * cx, cz * sy * cx + sz * sx },
		{ sz * cy, sz * sy * sx + cz * cx, sz * sy * cx - cz * sx },
		{ -sy, cy * sx, cy * cx },
	}
end

local function rotate(m, p)
	return { dot(m[1], p), dot(m[2], p), dot(m[3], p) }
end

local function unrotate(m, p)
	return {
		m[1][1] * p[1] + m[2][1] * p[2] + m[3][1] * p[3],
		m[1][2] * p[1] + m[2][2] * p[2] + m[3][2] * p[3],
		m[1][3] * p[1] + m[2][3] * p[2] + m[3][3] * p[3],
	}
end

-- Heap of scrap filling the bin to `level`, mounded in the middle with lumps.
-- Returns its mesh and a function giving the heap's height at (x, y).
local function heap(level, mound)
	local mesh = Mesh.new()
	local edge = {}
	local middle = { 0, 0, 0 }
	for side = 0, 3 do
		for column = 0, FILL_PER_SIDE - 1 do
			local p = wallPoint(side, column / FILL_PER_SIDE, level)
			table.insert(edge, p)
			middle = add(middle, p)
		end
	end
	middle = scale(middle, 1 / #edge)
	local positions = {}
	local function vertex(p)
		table.insert(positions, p)
		return mesh:vertex(p[1], p[2], p[3])
	end
	local function lumps(p)
		return FILL_LUMPS * math.noise(p[1] * 1.3, p[2] * 1.3, p[3] * 1.3)
	end
	local rings = {}
	for ring = 0, FILL_RINGS - 1 do
		local t = 1 - ring / FILL_RINGS
		local verts = {}
		for i, p in edge do
			local out = sub(p, middle)
			local flat = sub(add(middle, scale(out, t)), scale(normalize(out), WALL * 1.2 * t))
			flat[3] = middle[3] + mound * (1 - t * t) + lumps(flat)
			verts[i] = vertex(flat)
		end
		rings[ring + 1] = verts
	end
	local top = vertex({ middle[1], middle[2], middle[3] + mound + lumps(middle) })
	local triangles = {}
	local function face(verts)
		mesh:face(verts)
		for k = 2, #verts - 1 do
			table.insert(triangles, { positions[verts[1]], positions[verts[k]], positions[verts[k + 1]] })
		end
	end
	-- Mesh indices match `positions` because the heap mesh holds nothing else.
	local count = #edge
	for ring = 1, FILL_RINGS - 1 do
		local outer, inner = rings[ring], rings[ring + 1]
		for i = 1, count do
			local j = i % count + 1
			face({ outer[i], outer[j], inner[j], inner[i] })
		end
	end
	local last = rings[FILL_RINGS]
	for i = 1, count do
		face({ last[i], last[i % count + 1], top })
	end
	mesh:setSmooth(true)

	local function heightAt(x, y)
		local best = middle[3]
		for _, tri in triangles do
			local a, b, c = tri[1], tri[2], tri[3]
			local d = (b[2] - c[2]) * (a[1] - c[1]) + (c[1] - b[1]) * (a[2] - c[2])
			if d ~= 0 then
				local l1 = ((b[2] - c[2]) * (x - c[1]) + (c[1] - b[1]) * (y - c[2])) / d
				local l2 = ((c[2] - a[2]) * (x - c[1]) + (a[1] - c[1]) * (y - c[2])) / d
				local l3 = 1 - l1 - l2
				if l1 >= 0 and l2 >= 0 and l3 >= 0 then
					best = math.max(best, l1 * a[3] + l2 * b[3] + l3 * c[3])
				end
			end
		end
		return best
	end

	local halfX, halfY = 0, 0
	for _, p in edge do
		halfX = math.max(halfX, math.abs(p[1] - middle[1]))
		halfY = math.max(halfY, math.abs(p[2] - middle[2]))
	end
	return mesh, heightAt, middle, halfX * 0.75, halfY * 0.75
end

-- Places one junk piece: builds its mesh in world space and returns it with a
-- painter working in the piece's own space.
local function placeJunk(piece, location, size, turn, verts, faces, smooth, thickness)
	local mesh = Mesh.new()
	local function place(p)
		local w = add(location, rotate(turn, scale(p, size)))
		return mesh:vertex(w[1], w[2], w[3])
	end
	if faces then
		local indices = {}
		for i, p in verts do
			indices[i] = place(p)
		end
		for _, f in faces do
			local mapped = {}
			for k, i in f do
				mapped[k] = indices[i]
			end
			mesh:face(mapped)
		end
	else
		-- No faces: verts is a spring's centerline.
		local points = {}
		for i, p in verts do
			points[i] = add(location, rotate(turn, scale(p, size)))
		end
		tube(mesh, points, 0.075 * size, 8, false)
	end
	if thickness then
		mesh:solidify(thickness * size)
	end
	mesh:setSmooth(smooth)
	return mesh
end

-- Points over a piece's surface relative to where it's placed, turned and
-- scaled, with how far its surface stands out from them: a spring's points
-- run down its tube's middle, and a cog's ring is solidified up its own z.
local SPRING_RADIUS = 0.075
local function surfacePoints(verts, faces, thickness, size, turn)
	local points = {}
	for _, p in verts do
		table.insert(points, rotate(turn, scale(p, size)))
		if thickness then
			table.insert(points, rotate(turn, scale(add(p, { 0, 0, thickness }), size)))
		end
	end
	return points, if faces then 0 else SPRING_RADIUS * size
end

-- How close (across) a point of a resting piece must be to hold up a
-- falling one.
local RESTING_REACH = 0.12

-- Drops a piece at (x, y) until its surface meets the heap or a resting
-- piece, returning the height to place it at.
local function dropHeight(points, pad, x, y, heightAt, resting)
	local best = -math.huge
	for _, p in points do
		local px, py = x + p[1], y + p[2]
		local support = heightAt(px, py)
		for _, r in resting do
			if math.abs(r[1] - px) < RESTING_REACH and math.abs(r[2] - py) < RESTING_REACH then
				support = math.max(support, r[3])
			end
		end
		best = math.max(best, support + pad - p[3])
	end
	return best
end

local bodyMesh = body()
local bolts = bodyBolts()
local plateMesh = plates(bolts)
bolts:setSmooth(40)
local trimMesh = trim()
local hazardMesh, stripes = hazard()

bodyMesh:unwrap()
local green = Image.new(1024, 1024, color(BODY))
bodyMesh:paintShading(green, { bands = 6, occluders = { bolts, plateMesh, trimMesh, hazardMesh } })

plateMesh:unwrap()
local steel = Image.new(512, 512, color(PLATE))
plateMesh:paintShading(steel, { occluders = { bodyMesh, bolts } })

trimMesh:unwrap()
local orange = Image.new(512, 512, color(TRIM))
trimMesh:paintShading(orange, { occluders = { bodyMesh } })

bolts:unwrap()
local boltColor = Image.new(256, 256, color(BOLT))
bolts:paintShading(boltColor, { occluders = { bodyMesh, plateMesh } })

hazardMesh:paintShading(stripes, { occluders = { bodyMesh } })

model.part("Body", bodyMesh, green)
model.part("Hazard", hazardMesh, stripes)
model.part("Plates", plateMesh, steel)
model.part("Bolts", bolts, boltColor)
model.part("Trim", trimMesh, orange)

for number, level in FILL_LEVELS do
	local name = `Fill_{number}`
	local preview = number == #FILL_LEVELS
	local fill, heightAt, middle, halfX, halfY = heap(level[1] * 1, level[2])
	local pieces = {}
	local placed = {}
	-- Surface points of the pieces already down, for later ones to land on.
	local resting = {}
	for index = 1, level[3] do
		local piece = JUNK[index]
		local verts, faces, smooth, thickness, painter = junkShapes[piece.kind]()
		local size = piece.scale or 1
		local turn = rotation(piece.tilt)
		local base = if piece.on then placed[piece.on + 1] else nil
		local x, y
		if base then
			x, y = base[1] + piece.at[1], base[2] + piece.at[2]
		else
			x, y = middle[1] + piece.at[1] * halfX, middle[2] + piece.at[2] * halfY
		end
		local points, pad = surfacePoints(verts, faces, thickness, size, turn)
		local location = { x, y, dropHeight(points, pad, x, y, heightAt, resting) - piece.sink }
		for _, p in points do
			table.insert(resting, { x + p[1], y + p[2], location[3] + p[3] + pad })
		end
		local mesh = placeJunk(piece, location, size, turn, verts, faces, smooth, thickness)
		placed[index] = location
		table.insert(pieces, { mesh = mesh, kind = piece.kind, location = location, size = size, turn = turn, paint = painter })
	end

	local junkMeshes = {}
	for _, piece in pieces do
		table.insert(junkMeshes, piece.mesh)
	end
	fill:unwrap()
	local scrap = Image.new(1024, 1024, color(SCRAP))
	fill:paintShading(scrap, { occluders = junkMeshes })
	model.part(name, fill, scrap, { group = name, preview = preview })

	for i, piece in pieces do
		piece.mesh:unwrap()
		local texture = Image.new(256, 256)
		piece.mesh:paint(texture, function(x, y, z)
			local p = scale(unrotate(piece.turn, sub({ x, y, z }, piece.location)), 1 / piece.size)
			return color(piece.paint(p))
		end)
		piece.mesh:paintShading(texture, { occluders = { fill } })
		model.part(`{name}_{piece.kind}{i}`, piece.mesh, texture, { group = name, preview = preview })
	end
end
