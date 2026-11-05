-- Sky Islands: the far-off floating islands and loose rocks of the sky, baked
-- here as variants of two genotypes so the game only places them.
--
-- An island is two or three tiers of rock, each a wobbly disc with a domed
-- grass cap that overhangs a little, the lowest hanging down to a lumpy,
-- knobbled point. Trees grow on every tier: a bent, tapering trunk that
-- forks into a few branches, each ending in a cluster of lumpy leaf
-- clumps. A rock is one knobbled boulder with a mossy top.
--
-- Each island is two parts, IslandNN_Ground and IslandNN_Trees, and each
-- rock one, RockNN; the game groups an island's parts by their name. The
-- rock wears the map islands' strata paint (IslandPaint) and every part
-- gets the kit's painted shading. About 44 studs across; the game scales
-- them up. Laid out in rows for the preview: islands at the back, rocks in
-- front.
-- include: IslandPaint

local ISLANDS = 6
local ROCKS = 8
local SIDES = 44
local WALL_RINGS = 14
local CAP_RINGS = 4
local RADIUS = 20

local GRASS = { { 0.25, 0.42, 0.17 }, { 0.36, 0.56, 0.2 }, { 0.5, 0.7, 0.26 } }
local MOSS_DARK = { 0.2, 0.33, 0.15 }
local LEAF = { { 0.16, 0.32, 0.17 }, { 0.26, 0.47, 0.2 }, { 0.42, 0.62, 0.24 }, { 0.6, 0.76, 0.32 } }
local BARK = { 0.36, 0.25, 0.17 }
local BARK_DARK = { 0.24, 0.16, 0.11 }
local HAZE = { 0.62, 0.7, 0.86 }

-- A seeded random source (the engine has no Random).
local function seeded(seed)
	local state = seed % 2147483647
	local function nextUnit()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	return {
		number = function(low, high)
			return low + (high - low) * nextUnit()
		end,
		integer = function(low, high)
			return math.min(high, low + math.floor(nextUnit() * (high - low + 1)))
		end,
	}
end

local function fbm(x, y, z)
	return math.noise(x, y, z) + 0.5 * math.noise(x * 2.1, y * 2.1, z * 2.1) + 0.25 * math.noise(x * 4.3, y * 4.3, z * 4.3)
end

local function blend(a, b, f)
	return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

-- A tier's rim radius at an angle: a wobbly outline with a bay or two.
local function rimOf(tier, theta)
	local c, s = math.cos(theta), math.sin(theta)
	return tier.radius * (1 + 0.16 * fbm(c * 0.9 + tier.seed, s * 0.9, tier.seed * 0.37))
end

-- How far the grass reaches down the wall below the rim, at an angle:
-- ragged tongues of moss.
local function dripOf(tier, theta)
	local c, s = math.cos(theta), math.sin(theta)
	return 0.5 + 2.6 * math.max(0, fbm(c * 3 + tier.seed, s * 3, 4.4) + 0.15)
end

-- One tier: a domed grass cap, a lip that overhangs the wall, and the rock
-- wall under it. The lowest tier's wall hangs down to a knobbled point; the
-- others stop out of sight inside the tier below.
local function buildTier(vertex, face, tier)
	local rings = {}
	local function ring(scale, z, jag)
		local row = {}
		for s = 0, SIDES - 1 do
			local theta = s / SIDES * TAU
			local r = rimOf(tier, theta) * scale
			if jag > 0 then
				-- Knobbles: lumps that grow toward the bottom.
				r *= 1 + jag * fbm(math.cos(theta) * 2.2 + tier.seed, math.sin(theta) * 2.2, z * 0.22)
			end
			row[s] = vertex(tier.x + math.cos(theta) * r, tier.y + math.sin(theta) * r, z)
		end
		table.insert(rings, row)
	end
	-- The cap, from near the middle out to the lip, rising toward the middle.
	for k = 1, CAP_RINGS do
		local share = k / CAP_RINGS
		ring(share * 1.02, tier.top + tier.dome * (1 - share * share), 0)
	end
	ring(1.06, tier.top - 0.35, 0)
	ring(1.04, tier.top - tier.lip, 0)
	ring(0.95, tier.top - tier.lip - 0.2, 0)
	for j = 1, WALL_RINGS do
		local t = j / WALL_RINGS
		local scale = if tier.pointed then 0.95 * (1 - t) ^ tier.taper else 0.95 * (1 - 0.15 * t)
		ring(math.max(scale, 0.02), tier.top - tier.lip - 0.2 - tier.depth * t, if tier.pointed then 0.18 + 0.3 * t else 0.12)
	end
	local center = vertex(tier.x, tier.y, tier.top + tier.dome)
	for s = 0, SIDES - 1 do
		local n = (s + 1) % SIDES
		face({ center, rings[1][s], rings[1][n] })
		for r = 1, #rings - 1 do
			face({ rings[r][s], rings[r + 1][s], rings[r + 1][n], rings[r][n] })
		end
	end
	local last = rings[#rings]
	local tip = vertex(tier.x + tier.radius * 0.08, tier.y, tier.top - tier.lip - 0.4 - tier.depth * 1.04)
	for s = 0, SIDES - 1 do
		face({ last[s], tip, last[(s + 1) % SIDES] })
	end
end

-- A tapering limb along `points`, from radius r0 to r1.
local function limb(vertex, face, points, r0, r1, sides)
	local rings = {}
	for i, p in points do
		local a, b = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
		local r = r0 + (r1 - r0) * (i - 1) / (#points - 1)
		local row = {}
		for k = 0, sides - 1 do
			local t = k / sides * TAU
			local c, n = math.cos(t) * r, math.sin(t) * r
			row[k] = vertex(p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n)
		end
		rings[i] = row
	end
	for i = 1, #points - 1 do
		for k = 0, sides - 1 do
			local n = (k + 1) % sides
			face({ rings[i][k], rings[i][n], rings[i + 1][n], rings[i + 1][k] })
		end
	end
end

-- A lumpy leaf clump: a sphere pushed in and out by noise, flatter below.
local function clump(vertex, face, cx, cy, cz, radius, seed)
	local rings, sides = 6, 10
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local theta = s / sides * TAU
			local x, y, z = math.sin(phi) * math.cos(theta), math.sin(phi) * math.sin(theta), math.cos(phi)
			local lump = 1 + 0.28 * math.noise(x * 1.8 + seed, y * 1.8, z * 1.8)
			local squash = if z < 0 then 0.55 else 0.85
			grid[r][s] = vertex(cx + x * radius * lump, cy + y * radius * lump, cz + z * radius * lump * squash)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			face({ grid[r][s], grid[r + 1][s], grid[r + 1][n], grid[r][n] })
		end
	end
end

-- A tree: a bent trunk that forks into branches, each ending in a cluster
-- of clumps, plus one cluster crowning the trunk.
local function growTree(rng, x, y, z, height)
	local tree = { limbs = {}, clumps = {} }
	local lean = rng.number(0, TAU)
	local bend = rng.number(0.05, 0.16) * height
	local trunk = {}
	for i = 0, 4 do
		local t = i / 4
		-- Bowed: leans out, then curls back toward upright near the top.
		local sway = math.sin(t * math.pi * 0.9) * bend
		table.insert(trunk, { x + math.cos(lean) * sway, y + math.sin(lean) * sway, z - 0.4 + t * height })
	end
	local girth = height * rng.number(0.05, 0.07)
	table.insert(tree.limbs, { points = trunk, r0 = girth, r1 = girth * 0.45 })
	local top = trunk[#trunk]
	local crown = height * rng.number(0.26, 0.34)
	local function cluster(cx, cy, cz, size)
		for c = 1, rng.integer(3, 5) do
			local a = rng.number(0, TAU)
			local d = if c == 1 then 0 else size * rng.number(0.45, 0.85)
			table.insert(tree.clumps, {
				cx + math.cos(a) * d,
				cy + math.sin(a) * d,
				cz + rng.number(-0.15, 0.3) * size,
				size * (if c == 1 then 0.95 else rng.number(0.55, 0.8)),
			})
		end
	end
	cluster(top[1], top[2], top[3] + crown * 0.3, crown)
	for b = 1, rng.integer(2, 4) do
		-- Branches leave the upper trunk and reach out and up.
		local from = trunk[rng.integer(3, 4)]
		local a = lean + b / 4 * TAU + rng.number(-0.5, 0.5)
		local reach = height * rng.number(0.25, 0.42)
		local rise = height * rng.number(0.12, 0.28)
		local mid = { from[1] + math.cos(a) * reach * 0.5, from[2] + math.sin(a) * reach * 0.5, from[3] + rise * 0.7 }
		local tip = { from[1] + math.cos(a) * reach, from[2] + math.sin(a) * reach, from[3] + rise }
		table.insert(tree.limbs, { points = { from, mid, tip }, r0 = girth * 0.55, r1 = girth * 0.25 })
		cluster(tip[1], tip[2], tip[3] + crown * 0.15, crown * rng.number(0.6, 0.8))
	end
	return tree
end

local function islandGenotype(seed)
	local rng = seeded(seed)
	local tiers, trees = {}, {}
	local count = rng.integer(2, 3)
	local x, y, top, radius = 0, 0, 0, RADIUS
	for k = 1, count do
		table.insert(tiers, {
			x = x,
			y = y,
			top = top,
			radius = radius,
			seed = seed % 97 + k * 3.1,
			lip = 1.1,
			dome = radius * 0.06,
			pointed = k == 1,
			taper = rng.number(0.55, 0.8),
			depth = if k == 1 then RADIUS * rng.number(1.1, 1.5) else RADIUS * 0.5,
		})
		local shrink = rng.number(0.5, 0.62)
		local angle = rng.number(0, TAU)
		local shift = radius * (1 - shrink) * rng.number(0.3, 0.7)
		x, y = x + math.cos(angle) * shift, y + math.sin(angle) * shift
		top += RADIUS * rng.number(0.26, 0.36)
		radius *= shrink
	end
	for k, tier in tiers do
		local above = tiers[k + 1]
		local wanted = if k == 1 then rng.integer(4, 7) else rng.integer(1, 3)
		local tries = 0
		while wanted > 0 and tries < 80 do
			tries += 1
			local angle, reach = rng.number(0, TAU), math.sqrt(rng.number(0.04, 0.6)) * tier.radius
			local tx, ty = tier.x + math.cos(angle) * reach, tier.y + math.sin(angle) * reach
			if above and math.sqrt((tx - above.x) ^ 2 + (ty - above.y) ^ 2) < above.radius * 1.3 then
				continue
			end
			wanted -= 1
			-- The cap's dome at that point, so the tree stands on it.
			local share = reach / tier.radius
			local ground = tier.top + tier.dome * (1 - share * share)
			local height = RADIUS * rng.number(0.3, 0.5) * (if k == 1 then 1 else 0.8)
			local tree = growTree(rng, tx, ty, ground, height)
			tree.tier = k
			table.insert(trees, tree)
		end
	end
	return { tiers = tiers, trees = trees, seed = seed % 97 }
end

-- Ground paint: grass on each tier's cap and its drips, the map islands'
-- strata below, the rock fading toward the sky's blue at the point. Grass
-- under a tree's crown is darker.
local function groundPainter(island, offsetX, offsetY)
	local bottom = island.tiers[1].top - island.tiers[1].lip - island.tiers[1].depth
	return function(x, y, z)
		x, y = x - offsetX, y - offsetY
		for k = #island.tiers, 1, -1 do
			local tier = island.tiers[k]
			local dx, dy = x - tier.x, y - tier.y
			local reach = math.sqrt(dx * dx + dy * dy)
			if reach < tier.radius * 1.35 and z <= tier.top + tier.dome + 0.1 then
				local theta = math.atan2(dy, dx)
				if z > tier.top - tier.lip - dripOf(tier, theta) then
					local patch = fbm(x * 0.18 + tier.seed, y * 0.18, z * 0.18)
					local color = if patch > 0.2 then GRASS[3] elseif patch > -0.25 then GRASS[2] else GRASS[1]
					local r, g, b = color[1], color[2], color[3]
					for _, tree in island.trees do
						local base = tree.limbs[1].points[1]
						local sx, sy = x - base[1] - 1.2, y - base[2] - 0.9
						if tree.tier == k and sx * sx + sy * sy < 9 then
							r, g, b = blend({ r, g, b }, MOSS_DARK, 0.7)
						end
					end
					-- The drips darken as they run down the rock.
					local below = math.clamp((tier.top - tier.lip - z) / 2.5, 0, 1)
					return blend({ r, g, b }, MOSS_DARK, below * 0.6)
				end
				-- Below this tier's grass: it may still be the grass of a
				-- tier beneath, round the foot of this one's wall.
			end
		end
		-- Strata measured down from the top of the tier this wall belongs to:
		-- the lowest tier whose top is above the point.
		local wallTop = math.huge
		for _, tier in island.tiers do
			if tier.top >= z - 0.05 then
				wallTop = math.min(wallTop, tier.top)
			end
		end
		if wallTop == math.huge then
			wallTop = island.tiers[1].top
		end
		local r, g, b = islandPaint(x, y, z - wallTop + 0.5, island.seed, 1.05)
		local fade = math.clamp(-z / -bottom, 0, 1) * 0.35
		return blend({ r, g, b }, HAZE, fade)
	end
end

local function treePainter(island, offsetX, offsetY)
	return function(x, y, z, _nx, _ny, nz)
		x, y = x - offsetX, y - offsetY
		for _, tree in island.trees do
			for _, c in tree.clumps do
				local dx, dy, dz = x - c[1], y - c[2], z - c[3]
				if dx * dx + dy * dy + dz * dz < (c[4] * 1.4) ^ 2 then
					-- Dappled leaves: a light top, a dark underside.
					local light = nz * 0.5 + fbm(x * 0.9, y * 0.9, z * 0.9) * 0.55 + 0.45
					local level = math.clamp(math.floor(light * 2.2) + 1, 1, #LEAF)
					local leaf = LEAF[level]
					return leaf[1], leaf[2], leaf[3]
				end
			end
		end
		-- Bark: dark grooves running up the limbs.
		local groove = math.noise(x * 3, y * 3, z * 0.4) > 0.25
		local color = if groove then BARK_DARK else BARK
		return color[1], color[2], color[3]
	end
end

local function rockGenotype(seed)
	local rng = seeded(seed)
	return { radius = rng.number(2.5, 5), tall = rng.number(0.9, 1.7), seed = seed % 89 }
end

-- A boulder: a knobbled blob, flat on top, drawn down to a point.
local function buildRock(vertex, face, rock)
	local rings, sides = 9, 16
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local theta = s / sides * TAU
			local bump = 1 + 0.35 * fbm(math.cos(theta) * 1.4 + rock.seed, math.sin(theta) * 1.4, r * 0.45)
			local reach = math.sin(phi) * rock.radius * bump
			local z = if phi < math.pi / 2 then math.cos(phi) * rock.radius * 0.3 else math.cos(phi) * rock.radius * rock.tall
			grid[r][s] = vertex(math.cos(theta) * reach, math.sin(theta) * reach, z)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			face({ grid[r][s], grid[r + 1][s], grid[r + 1][n], grid[r][n] })
		end
	end
end

local function rockPainter(rock, offsetX, offsetY)
	return function(x, y, z, _nx, _ny, nz)
		x, y = x - offsetX, y - offsetY
		if nz > 0.5 and z > rock.radius * 0.05 then
			local color = if fbm(x * 0.5 + rock.seed, y * 0.5, 0.5) > 0 then GRASS[3] else GRASS[2]
			return color[1], color[2], color[3]
		end
		local r, g, b = islandPaint(x, y, z - rock.radius * 0.3, rock.seed, 1.05)
		return blend({ r, g, b }, HAZE, math.clamp(-z / (rock.radius * rock.tall), 0, 1) * 0.3)
	end
end

-- A part built at a preview offset.
local function offsetPart(name, offsetX, offsetY, size, smooth, build, paint)
	part(name, nil, { 1, 1, 1 }, function(mesh)
		local function vertex(x, y, z)
			return mesh:vertex(x + offsetX, y + offsetY, z)
		end
		local function face(verts)
			mesh:face(verts)
		end
		build(vertex, face)
	end, smooth, rusting(0, paint), size, nil, true, 1.2)
end

for index = 1, ISLANDS do
	local island = islandGenotype(index * 6151)
	local offsetX, offsetY = (index - (ISLANDS + 1) / 2) * 60, 30
	local name = string.format("Island%02d", index)
	offsetPart(name .. "_Ground", offsetX, offsetY, 1024, 50, function(vertex, face)
		for _, tier in island.tiers do
			buildTier(vertex, face, tier)
		end
	end, groundPainter(island, offsetX, offsetY))
	offsetPart(name .. "_Trees", offsetX, offsetY, 512, 60, function(vertex, face)
		for _, tree in island.trees do
			for _, l in tree.limbs do
				limb(vertex, face, l.points, l.r0, l.r1, 6)
			end
			for k, c in tree.clumps do
				clump(vertex, face, c[1], c[2], c[3], c[4], k * 1.7 + index)
			end
		end
	end, treePainter(island, offsetX, offsetY))
end

for index = 1, ROCKS do
	local rock = rockGenotype(index * 3571)
	local offsetX, offsetY = (index - (ROCKS + 1) / 2) * 16, -30
	offsetPart(string.format("Rock%02d", index), offsetX, offsetY, 256, 50, function(vertex, face)
		buildRock(vertex, face, rock)
	end, rockPainter(rock, offsetX, offsetY))
end

finishParts()
