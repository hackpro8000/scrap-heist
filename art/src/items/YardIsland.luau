-- Yard Island: a floating yard island recomposed as stacked rock clumps. A
-- flat dirt cap overhangs a ring of faceted prism clumps tucked under its
-- rim, with two smaller rings stepping inward below that and one clump at
-- the tip. Each tier is its own part so the tiers shadow each other, and the
-- shading pushes edge highlights and contact shadows hard. Top at z = 0.
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

-- A faceted prism: an outline at each height, a chamfer round the top and a
-- taper toward the bottom, closed with caps. `outline(scale, ring)` returns
-- the corners counter-clockwise seen from above.
local function prism(mesh, outline: (number, number) -> { { number } }, top: number, bottom: number, bevel: number, taper: number)
	local rings = {}
	for r, level in { { top, 1 - bevel / 3 }, { top - bevel, 1 }, { bottom + bevel, taper }, { bottom, taper - bevel / 4 } } do
		rings[r] = {}
		for j, point in outline(level[2], r) do
			rings[r][j] = mesh:vertex(point[1], point[2], level[1])
		end
	end
	local n = #rings[1]
	for r = 1, 3 do
		for j = 1, n do
			local k = j % n + 1
			mesh:face({ rings[r + 1][j], rings[r + 1][k], rings[r][k], rings[r][j] })
		end
	end
	mesh:face(rings[1])
	local bottomCap = {}
	for j = n, 1, -1 do
		table.insert(bottomCap, rings[4][j])
	end
	mesh:face(bottomCap)
end

-- One rock clump with its own seed driving everything: an irregular 5-7
-- sided outline round (cx, cy), its own taper, a lower half that leans in toward the middle, and
-- every corner of every ring nudged so no two clumps share a silhouette.
local function clump(mesh, cx: number, cy: number, size: number, top: number, bottom: number, seed: number)
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
	prism(mesh, function(scale, ring)
		local shift = if ring <= 2 then 0 else 1
		local points = {}
		for j, corner in corners do
			local k = seed + j * 13 + ring * 101
			local reach = corner[2] * scale * (0.9 + 0.2 * random(k))
			local twist = (random(k + 7) - 0.5) * 0.15
			points[j] = {
				cx + math.cos(corner[1] + twist) * reach + tiltX * shift,
				cy + math.sin(corner[1] + twist) * reach + tiltY * shift,
			}
		end
		return points
	end, top, bottom, math.min(0.6, (top - bottom) / 4), taper)
end

-- A tier: clumps spaced round a ring under the tier above, plus a core
-- filling the middle so no gaps show through.
local function tier(name: string, reach: number, size: number, top: number, bottom: number, seed: number)
	local clumps = {}
	part(name, nil, GROUND, function(mesh)
		local count = math.floor(2 * math.pi * reach / (size * 0.8))
		for i = 1, count do
			local angle = (i + (random(seed + i) - 0.5) * 0.4) / count * 2 * math.pi
			local edge = reach * capScale(angle)
			local drop = random(seed + i + 100) * (top - bottom) * 0.3
			local s = size * (0.8 + 0.4 * random(seed + i + 200))
			local x, y, clumpSeed = math.cos(angle) * edge, math.sin(angle) * edge, seed * 31 + i * 7
			table.insert(clumps, { x, y, clumpSeed })
			clump(mesh, x, y, s, top - drop * 0.3, bottom + drop, clumpSeed)
		end
		clump(mesh, 0, 0, reach * 1.08, top - 0.1, bottom + (top - bottom) * 0.15, seed + 999)
	end, false, function(x, y, z)
		-- Paint each point with the seed of the ring clump nearest it.
		local nearest, best = seed + 999, math.huge
		for _, c in clumps do
			local d = (x - c[1]) ^ 2 + (y - c[2]) ^ 2
			if d < best then
				nearest, best = c[3], d
			end
		end
		return islandPaint(x, y, z, nearest)
	end)
end

part("Cap", nil, GROUND, function(mesh)
	prism(mesh, function(scale)
		local points = {}
		for j = 1, 28 do
			local angle = (j - 1) / 28 * 2 * math.pi
			local reach = RADIUS * 0.8 * capScale(angle) * scale
			points[j] = { math.cos(angle) * reach, math.sin(angle) * reach }
		end
		return points
	end, 0, -4, 0.5, 0.62)
end, false, islandPaint)

tier("Tier1", RADIUS * 0.86, 4.5, 0.3, -8.5, 11)
tier("Tier2", RADIUS * 0.52, 4, -6, -14, 23)
tier("Tier3", RADIUS * 0.3, 3.5, -11.5, -19.5, 37)
part("Tip", nil, GROUND, function(mesh)
	clump(mesh, 0.5, -0.4, 3.6, -17, -25, 51)
end, false, function(x, y, z)
	return islandPaint(x, y, z, 51)
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
		blend = 0.3,
		occluders = occluders,
	})
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
