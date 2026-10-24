-- Yard Island: a floating yard island recomposed as stacked rock clumps. A
-- flat dirt cap overhangs a ring of faceted prism clumps tucked under its
-- rim, with two smaller rings stepping inward below that and one clump at
-- the tip. The clumps are only used to cast the outer wall: the model is one
-- closed shell over their union. Top at z = 0.7.
useTexelDensity(16)
local RADIUS = 20
local GROUND = { 0.3, 0.27, 0.22 }
local STRATA = { { 0.5, 0.4, 0.27 }, { 0.36, 0.35, 0.34 }, { 0.48, 0.3, 0.22 } }
local TOPSOIL = { 0.24, 0.19, 0.14 }

local function random(k: number): number
	local s = math.sin(k * 12.9898 + 4.1414) * 43758.5453
	return s - math.floor(s)
end

-- The map's island texture: speckled ground on top, then topsoil fading
-- into wavy rock strata that darken with depth. A clump's `seed` shifts its
-- strata, tint and grain so neighbouring clumps don't match.
local function islandPaint(x: number, y: number, z: number, seed: number?)
	local below = -z
	if below < 0.3 then
		local k = 1 + 0.12 * math.noise(x / 4, y / 4, 31) + 0.05 * math.noise(x * 3, y * 3, 37)
		return GROUND[1] * k, GROUND[2] * k, GROUND[3] * k
	end
	local s = seed or 0
	local band = math.noise(x / 9 + s, y / 9, z / 2) * 0.6 + z * (0.8 + 0.2 * random(s + 1)) + random(s + 2) * 3
	local tint = if seed then 0.85 + 0.3 * random(s + 3) else 1
	local wave = math.sin(band * 2.4)
	local layer = STRATA[math.floor(band * 2.4 / (2 * math.pi)) % 3 + 1]
	local k = tint * (1 + 0.1 * wave + 0.06 * math.noise(x * 2 + s, y * 2, z * 2))
	if wave > 0.93 then k -= 0.25 end
	k *= 1 - 0.6 * math.clamp((below - 3) / 20, 0, 1)
	local soil = 1 - math.clamp((below - 0.5) / 4 + 0.3 * math.noise(x / 2, y / 2, 41), 0, 1)
	local r, g, b = layer[1] * k, layer[2] * k, layer[3] * k
	return r + (TOPSOIL[1] - r) * soil, g + (TOPSOIL[2] - g) * soil, b + (TOPSOIL[3] - b) * soil
end

-- The cap's wobbly outline, as a radius scale per angle.
local function capScale(angle: number): number
	return 1 + 0.07 * math.sin(3 * angle + 0.6) + 0.05 * math.sin(5 * angle + 2.1) + 0.03 * math.sin(9 * angle)
end

-- A faceted prism as data: rings of corners from the top down, each
-- { z, points }. `levels` lists each ring's { z, scale };
-- `outline(scale, ring)` returns the corners counter-clockwise from above.
local function prism(outline: (number, number) -> { { number } }, levels: { { number } })
	local rings = {}
	for r, level in levels do
		rings[r] = { z = level[1], points = outline(level[2], r) }
	end
	return rings
end

-- The usual four levels: under the top chamfer, full width, over the
-- bottom, tapered bottom.
local function prismLevels(top: number, bottom: number, bevel: number, taper: number): { { number } }
	return { { top, 1 - bevel / 3 }, { top - bevel, 1 }, { bottom + bevel, taper }, { bottom, taper - bevel / 4 } }
end

-- One rock clump with its own seed driving everything: an irregular 5-7
-- sided outline round (cx, cy), its own taper, a lower half that leans in
-- toward the middle, and every corner of every ring nudged. Each side is
-- split with a chip knocked in or a lump pushed out, so every clump reads as
-- its own broken formation.
local function clump(cx: number, cy: number, size: number, top: number, bottom: number, seed: number)
	local sides = 5 + math.floor(random(seed) * 3)
	local corners = {}
	for j = 1, sides do
		local angle = (j - 1 + (random(seed + j) - 0.5) * 0.5) / sides * 2 * math.pi + random(seed + 20) * 6
		corners[j] = { angle, size * (0.8 + 0.3 * random(seed + j + 40)) }
	end
	local taper = 0.45 + 0.3 * random(seed + 60)
	local away = math.sqrt(cx * cx + cy * cy)
	local lean = if away > 0 then size * (0.1 + 0.25 * random(seed + 62)) / away else 0
	local tiltX, tiltY = -cx * lean, -cy * lean
	local bevel = math.min(0.6, (top - bottom) / 4)
	local levels = prismLevels(top, bottom, bevel, taper)
	local span = levels[2][1] - levels[3][1]
	local rings = prism(function(scale, ring)
		local shift = math.clamp((levels[2][1] - levels[ring][1]) / span, 0, 1)
		local points = {}
		local function add(angle: number, reach: number)
			table.insert(points, {
				cx + math.cos(angle) * reach + tiltX * shift,
				cy + math.sin(angle) * reach + tiltY * shift,
			})
		end
		for j, corner in corners do
			local k = seed + j * 13 + ring * 101
			local reach = corner[2] * scale * (0.9 + 0.2 * random(k))
			local twist = (random(k + 7) - 0.5) * 0.15
			add(corner[1] + twist, reach)
			-- Halfway to the next corner: a chip bitten in or a lump standing
			-- out, its depth drifting a little from ring to ring.
			local nextCorner = corners[j % sides + 1]
			local nextAngle = nextCorner[1] + (if j == sides then 2 * math.pi else 0)
			local defect = random(seed + j * 17) - 0.45 + (random(k + 11) - 0.5) * 0.15
			add((corner[1] + nextAngle) / 2 + (random(seed + j * 19) - 0.5) * 0.3, (corner[2] + nextCorner[2]) / 2 * scale * (0.85 + 0.35 * defect))
		end
		return points
	end, levels)
	return { rings = rings, x = cx, y = cy, z = (top + bottom) / 2, seed = seed }
end

local solids = {}

-- A tier: clumps spaced round a ring under the tier above, plus a core
-- filling the middle.
local function tier(reach: number, size: number, top: number, bottom: number, seed: number)
	local count = math.floor(2 * math.pi * reach / (size * 0.8))
	for i = 1, count do
		local angle = (i + (random(seed + i) - 0.5) * 0.4) / count * 2 * math.pi
		local edge = reach * capScale(angle)
		local drop = random(seed + i + 100) * (top - bottom) * 0.3
		local s = size * (0.8 + 0.4 * random(seed + i + 200))
		table.insert(solids, clump(math.cos(angle) * edge, math.sin(angle) * edge, s, top - drop * 0.3, bottom + drop, seed * 31 + i * 7))
	end
	table.insert(solids, clump(0, 0, reach * 1.08, top - 0.1, bottom + (top - bottom) * 0.15, seed + 999))
end

local CAP_TOP = 0.7
table.insert(solids, {
	rings = prism(function(scale)
		local points = {}
		for j = 1, 28 do
			local angle = (j - 1) / 28 * 2 * math.pi
			local reach = RADIUS * 0.8 * capScale(angle) * scale
			points[j] = { math.cos(angle) * reach, math.sin(angle) * reach }
		end
		return points
	end, prismLevels(CAP_TOP, -4, 0.5, 0.62)),
	x = 0, y = 0, z = -1.5,
})
tier(RADIUS * 0.86, 4.5, 0.3, -8.5, 11)
tier(RADIUS * 0.52, 4, -6, -14, 23)
tier(RADIUS * 0.3, 3.5, -11.5, -19.5, 37)
table.insert(solids, clump(0.5, -0.4, 3.6, -17, -25, 51))

-- How far a ray from the axis at height z, heading (dx, dy), runs before it
-- leaves the last solid: the island's outer wall there.
local function wallReach(dx: number, dy: number, z: number): number
	local best = 0
	for _, solid in solids do
		local rings = solid.rings
		if z > rings[1].z or z < rings[#rings].z then continue end
		local r = 1
		while r < #rings and z < rings[r + 1].z do r += 1 end
		local upper, lower = rings[r], rings[math.min(r + 1, #rings)]
		local blend = if upper.z > lower.z then (upper.z - z) / (upper.z - lower.z) else 0
		local n = #upper.points
		local function corner(j: number): (number, number)
			local a, b = upper.points[j], lower.points[j]
			return a[1] + (b[1] - a[1]) * blend, a[2] + (b[2] - a[2]) * blend
		end
		for j = 1, n do
			local px, py = corner(j)
			local qx, qy = corner(j % n + 1)
			local ex, ey = qx - px, qy - py
			local denom = dx * ey - dy * ex
			if math.abs(denom) < 1e-9 then continue end
			local t = (px * ey - py * ex) / denom
			local u = (px * dy - py * dx) / denom
			if t > best and u >= 0 and u <= 1 then best = t end
		end
	end
	return best
end

-- One closed outer shell over the union of every solid: rows of wall
-- points stepping down from the cap to the tip, a flat top and a point at
-- the bottom. Nothing inside is modelled, so there are no gaps or buried faces.
local ANGLES, STEP, TIP = 192, 0.3, -25
part("Island", nil, GROUND, function(mesh)
	local rows = {}
	local z = CAP_TOP
	while z > TIP + STEP / 2 do
		local row = {}
		for j = 0, ANGLES - 1 do
			local angle = 2 * math.pi * j / ANGLES
			local dx, dy = math.cos(angle), math.sin(angle)
			local r = math.max(wallReach(dx, dy, z), 0.05)
			row[j] = mesh:vertex(dx * r, dy * r, z)
		end
		table.insert(rows, row)
		z -= STEP
	end
	for i = 1, #rows - 1 do
		for j = 0, ANGLES - 1 do
			local l = (j + 1) % ANGLES
			mesh:face({ rows[i + 1][j], rows[i + 1][l], rows[i][l], rows[i][j] })
		end
	end
	local middle = mesh:vertex(0, 0, CAP_TOP)
	for j = 0, ANGLES - 1 do
		mesh:face({ middle, rows[1][j], rows[1][(j + 1) % ANGLES] })
	end
	local tip = mesh:vertex(0.5, -0.4, TIP)
	for j = 0, ANGLES - 1 do
		mesh:face({ tip, rows[#rows][(j + 1) % ANGLES], rows[#rows][j] })
	end
end, false, function(x, y, z)
	-- Paint each point with the seed of the clump whose middle is nearest.
	local nearest, best = nil, math.huge
	for _, solid in solids do
		local d = (x - solid.x) ^ 2 + (y - solid.y) ^ 2 + ((z - solid.z) * 0.5) ^ 2
		if d < best then
			nearest, best = solid.seed, d
		end
	end
	return islandPaint(x, y, z, nearest)
end)

-- Aggressive shading: full edge highlights and contact shadows, with every
-- other part as an occluder.
for _, entry in parts do
	local occluders = {}
	for _, other in parts do
		if other ~= entry then
			table.insert(occluders, other.mesh)
		end
	end
	entry.mesh:paintShading(entry.image, {
		highlight = 1,
		shadow = 1,
		gradient = GRADIENT,
		blend = 0.56,
		occluders = occluders,
	})
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
