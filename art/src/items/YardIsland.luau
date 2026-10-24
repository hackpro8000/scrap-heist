-- Yard Island: a floating yard island recomposed as stacked rock clumps. A
-- flat dirt cap overhangs a ring of faceted prism clumps tucked under its
-- rim, with two smaller rings stepping inward below that and one clump at
-- the tip. Each tier is its own part so the tiers shadow each other, and the
-- shading pushes edge highlights and contact shadows hard. Top at z = 0.
local RADIUS = 20
local DIRT = { 0.47, 0.36, 0.24 }
local ROCK = { 0.42, 0.38, 0.35 }
local ROCK_LIGHT = { 0.56, 0.5, 0.44 }

local function random(k: number): number
	local s = math.sin(k * 12.9898 + 4.1414) * 43758.5453
	return s - math.floor(s)
end

-- The cap's wobbly outline, as a radius scale per angle.
local function capScale(angle: number): number
	return 1 + 0.07 * math.sin(3 * angle + 0.6) + 0.05 * math.sin(5 * angle + 2.1) + 0.03 * math.sin(9 * angle)
end

-- A faceted prism: an outline at each height, a chamfer round the top and a
-- taper toward the bottom, closed with caps. `outline(scale)` returns the
-- corners counter-clockwise seen from above.
local function prism(mesh, outline: (number) -> { { number } }, top: number, bottom: number, bevel: number, taper: number)
	local rings = {}
	for r, level in { { top, 1 - bevel / 3 }, { top - bevel, 1 }, { bottom + bevel, taper }, { bottom, taper - bevel / 4 } } do
		rings[r] = {}
		for j, point in outline(level[2]) do
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

-- One rock clump: an irregular 5-7 sided outline round (cx, cy).
local function clump(mesh, cx: number, cy: number, size: number, top: number, bottom: number, seed: number)
	local sides = 5 + math.floor(random(seed) * 3)
	local corners = {}
	for j = 1, sides do
		local angle = (j - 1 + (random(seed + j) - 0.5) * 0.5) / sides * 2 * math.pi + random(seed + 20) * 6
		corners[j] = { angle, size * (0.8 + 0.3 * random(seed + j + 40)) }
	end
	prism(mesh, function(scale)
		local points = {}
		for j, corner in corners do
			points[j] = { cx + math.cos(corner[1]) * corner[2] * scale, cy + math.sin(corner[1]) * corner[2] * scale }
		end
		return points
	end, top, bottom, math.min(0.6, (top - bottom) / 4), 0.7)
end

-- A tier: clumps spaced round a ring under the tier above, plus a core
-- filling the middle so no gaps show through.
local function tier(name: string, reach: number, size: number, top: number, bottom: number, seed: number)
	part(name, nil, ROCK, function(mesh)
		local count = math.floor(2 * math.pi * reach / (size * 1.25))
		for i = 1, count do
			local angle = (i + (random(seed + i) - 0.5) * 0.4) / count * 2 * math.pi
			local edge = reach * capScale(angle)
			local drop = random(seed + i + 100) * (top - bottom) * 0.3
			local s = size * (0.8 + 0.4 * random(seed + i + 200))
			clump(mesh, math.cos(angle) * edge, math.sin(angle) * edge, s, top - drop * 0.3, bottom + drop, seed * 31 + i * 7)
		end
		clump(mesh, 0, 0, reach * 0.95, top - 0.3, bottom + (top - bottom) * 0.25, seed + 999)
	end, false, function(_x, _y, z, _nx, _ny, nz)
		-- Upward faces catch light, and rock darkens toward the bottom.
		local fall = math.clamp((z + 24) / 24, 0, 1)
		local up = math.clamp(nz, 0, 1)
		local r = ROCK[1] + (ROCK_LIGHT[1] - ROCK[1]) * up
		local g = ROCK[2] + (ROCK_LIGHT[2] - ROCK[2]) * up
		local b = ROCK[3] + (ROCK_LIGHT[3] - ROCK[3]) * up
		local shade = 0.55 + 0.45 * fall
		return r * shade, g * shade, b * shade
	end)
end

part("Cap", nil, DIRT, function(mesh)
	prism(mesh, function(scale)
		local points = {}
		for j = 1, 28 do
			local angle = (j - 1) / 28 * 2 * math.pi
			local reach = RADIUS * capScale(angle) * scale
			points[j] = { math.cos(angle) * reach, math.sin(angle) * reach }
		end
		return points
	end, 0, -2.2, 0.5, 0.94)
end, false, function(x, y, _z, _nx, _ny, nz)
	if nz < 0.7 then
		return ROCK_LIGHT[1], ROCK_LIGHT[2], ROCK_LIGHT[3]
	end
	local speck = 0.94 + 0.06 * math.sin(x * 0.7 + math.sin(y * 0.5) * 2) * math.sin(y * 0.6 - x * 0.3)
	return DIRT[1] * speck, DIRT[2] * speck, DIRT[3] * speck
end)

tier("Tier1", RADIUS * 0.74, 4.5, -2.2, -8, 11)
tier("Tier2", RADIUS * 0.52, 4, -7, -14, 23)
tier("Tier3", RADIUS * 0.3, 3.5, -12.5, -19, 37)
part("Tip", nil, ROCK, function(mesh)
	clump(mesh, 0.5, -0.4, 3.2, -18, -25, 51)
end, false, function()
	return ROCK[1] * 0.6, ROCK[2] * 0.6, ROCK[3] * 0.6
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
