-- Sky Islands: the far-off floating islands and loose rocks of the sky, baked
-- here as variants of two genotypes so the game only places them.
--
-- An island is two or three tiers of rock, each a wobbly disc with an
-- overhanging grass cap, the lowest tapering to a jagged point, with
-- broad-canopied trees on every tier. A rock is one jagged boulder with a
-- mossy top. Both are painted flat and cel shaded: the game shows them tiny
-- and far away, so the paint carries the look, not the polygons.
-- About 40 studs across; the game scales them up. Laid out in rows for the
-- preview: islands at the back, rocks in front.

local ISLANDS = 6
local ROCKS = 8
local SIDES = 22
local WALL_RINGS = 7
local ISLAND_TEXTURE = 512
local ROCK_TEXTURE = 128
local RADIUS = 20

local LX, LY, LZ = -0.45, -0.35, 0.82

local GRASS = { { 0.3, 0.46, 0.2 }, { 0.44, 0.63, 0.25 }, { 0.6, 0.76, 0.32 } }
local LEAF = { { 0.19, 0.35, 0.2 }, { 0.33, 0.53, 0.23 }, { 0.56, 0.73, 0.31 } }
local STONE = { { 0.4, 0.33, 0.3 }, { 0.58, 0.5, 0.43 }, { 0.78, 0.71, 0.6 } }
local BARK = { { 0.3, 0.21, 0.16 }, { 0.45, 0.32, 0.22 } }
local HAZE = { 0.62, 0.66, 0.78 }

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

-- Three flat tones picked by how lit the surface is.
local function tone(colors, light)
	local color = if light > 0.62 then colors[#colors] elseif light > 0.3 then colors[math.max(#colors - 1, 1)] else colors[1]
	return color[1], color[2], color[3]
end

local function lightOf(nx, ny, nz)
	return nx * LX + ny * LY + nz * LZ
end

-- A tier's rim radius at an angle: a wobbly outline.
local function rimOf(tier, theta)
	return tier.radius
		* (1 + 0.14 * math.noise(math.cos(theta) * 1.3 + tier.seed, math.sin(theta) * 1.3, tier.seed * 0.37))
end

-- One tier: a grass cap overhanging a rock wall. The lowest tier's wall
-- tapers to a jagged point; the others stop inside the tier below.
local function buildTier(vertex, face, tier)
	local lip = tier.lip
	local rings = {}
	local function ringAt(scale, z, jag)
		local ring = {}
		for s = 0, SIDES - 1 do
			local theta = s / SIDES * TAU
			local r = rimOf(tier, theta) * scale
			if jag > 0 then
				r *= 1 + jag * math.noise(s * 1.7 + tier.seed, z * 0.35, tier.seed)
			end
			ring[s] = vertex(tier.x + math.cos(theta) * r, tier.y + math.sin(theta) * r, z)
		end
		table.insert(rings, ring)
	end
	ringAt(1.05, tier.top, 0)
	ringAt(1.07, tier.top - lip, 0)
	ringAt(0.96, tier.top - lip, 0)
	for j = 1, WALL_RINGS - 1 do
		local t = j / WALL_RINGS
		local scale = if tier.pointed then 0.96 * (1 - t) ^ 0.62 else 0.96 * (1 - 0.18 * t)
		ringAt(scale, tier.top - lip - tier.depth * t, if tier.pointed then 0.5 else 0.2)
	end
	local center = vertex(tier.x, tier.y, tier.top)
	for s = 0, SIDES - 1 do
		local n = (s + 1) % SIDES
		face({ center, rings[1][s], rings[1][n] })
		for r = 1, #rings - 1 do
			face({ rings[r][s], rings[r + 1][s], rings[r + 1][n], rings[r][n] })
		end
	end
	if tier.pointed then
		local tip = vertex(tier.x + tier.radius * 0.1, tier.y, tier.top - lip - tier.depth)
		local last = rings[#rings]
		for s = 0, SIDES - 1 do
			face({ last[s], tip, last[(s + 1) % SIDES] })
		end
	end
end

-- A low-poly blob: a sphere of `rings` x `sides`, squashed in z.
local function blob(vertex, face, cx, cy, cz, rx, rz, rings, sides)
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local theta = s / sides * TAU
			grid[r][s] = vertex(
				cx + math.sin(phi) * math.cos(theta) * rx,
				cy + math.sin(phi) * math.sin(theta) * rx,
				cz + math.cos(phi) * rz
			)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			face({ grid[r][s], grid[r + 1][s], grid[r + 1][n], grid[r][n] })
		end
	end
end

-- A tree: a tapered trunk and a broad, flat-bottomed canopy of blobs.
local function buildTree(vertex, face, tree)
	local sides = 5
	local low, high = {}, {}
	for s = 0, sides - 1 do
		local theta = s / sides * TAU
		low[s] = vertex(tree.x + math.cos(theta) * tree.trunk, tree.y + math.sin(theta) * tree.trunk, tree.z - 0.5)
		high[s] = vertex(
			tree.x + tree.lean + math.cos(theta) * tree.trunk * 0.6,
			tree.y + math.sin(theta) * tree.trunk * 0.6,
			tree.z + tree.height
		)
	end
	for s = 0, sides - 1 do
		local n = (s + 1) % sides
		face({ low[s], low[n], high[n], high[s] })
	end
	for _, canopy in tree.canopies do
		blob(vertex, face, canopy[1], canopy[2], canopy[3], canopy[4], canopy[5], 4, 8)
	end
end

local function islandGenotype(seed)
	local rng = seeded(seed)
	local tiers, trees = {}, {}
	local count = rng.integer(2, 3)
	local x, y, top, radius = 0, 0, 0, RADIUS
	for k = 1, count do
		local tier = {
			x = x,
			y = y,
			top = top,
			radius = radius,
			seed = seed % 97 + k * 3.1,
			lip = 0.9,
			pointed = k == 1,
			depth = if k == 1 then RADIUS * rng.number(1.1, 1.6) else RADIUS * 0.45,
		}
		table.insert(tiers, tier)
		local shrink = rng.number(0.5, 0.62)
		local angle = rng.number(0, TAU)
		local shift = radius * (1 - shrink) * rng.number(0.3, 0.7)
		x, y = x + math.cos(angle) * shift, y + math.sin(angle) * shift
		top += RADIUS * rng.number(0.26, 0.38)
		radius *= shrink
	end
	for k, tier in tiers do
		local above = tiers[k + 1]
		local wanted = if k == 1 then rng.integer(4, 7) else rng.integer(1, 3)
		local tries = 0
		while wanted > 0 and tries < 60 do
			tries += 1
			local angle, reach = rng.number(0, TAU), math.sqrt(rng.number(0.05, 0.7)) * tier.radius
			local tx, ty = tier.x + math.cos(angle) * reach, tier.y + math.sin(angle) * reach
			if above and math.sqrt((tx - above.x) ^ 2 + (ty - above.y) ^ 2) < above.radius * 1.25 then
				continue
			end
			wanted -= 1
			local height = RADIUS * rng.number(0.28, 0.5) * (if k == 1 then 1 else 0.8)
			local tree = { x = tx, y = ty, z = tier.top, height = height, trunk = height * 0.07, lean = rng.number(-0.1, 0.1) * height, canopies = {} }
			local crown = height * rng.number(0.42, 0.55)
			for c = 1, rng.integer(3, 5) do
				local a, d = rng.number(0, TAU), if c == 1 then 0 else crown * rng.number(0.5, 0.9)
				local r = crown * (if c == 1 then 1 else rng.number(0.5, 0.75))
				table.insert(tree.canopies, {
					tx + tree.lean + math.cos(a) * d,
					ty + math.sin(a) * d,
					tier.top + height + r * rng.number(0, 0.25),
					r,
					r * 0.55,
				})
			end
			table.insert(trees, tree)
		end
	end
	return { tiers = tiers, trees = trees, seed = seed % 97 }
end

local function islandPainter(island, offsetX, offsetY)
	local bottom = island.tiers[1].top - island.tiers[1].depth
	return function(x, y, z, nx, ny, nz)
		x, y = x - offsetX, y - offsetY
		local light = lightOf(nx, ny, nz) + math.noise(x * 0.4, y * 0.4, z * 0.4 + island.seed) * 0.2
		for _, tree in island.trees do
			for _, canopy in tree.canopies do
				local dx, dy, dz = (x - canopy[1]) / canopy[4], (y - canopy[2]) / canopy[4], (z - canopy[3]) / canopy[5]
				if dx * dx + dy * dy + dz * dz < 1.15 then
					-- Lit from above across the whole crown, dark underneath.
					return tone(LEAF, light * 0.6 + dz * 0.45 + 0.2)
				end
			end
			local dx, dy = x - tree.x - tree.lean * (z - tree.z) / tree.height, y - tree.y
			if z > tree.z - 0.6 and z < tree.z + tree.height + 0.5 and dx * dx + dy * dy < (tree.trunk * 1.5) ^ 2 then
				return tone(BARK, light + 0.2)
			end
		end
		for k = #island.tiers, 1, -1 do
			local tier = island.tiers[k]
			local dx, dy = x - tier.x, y - tier.y
			local reach = math.sqrt(dx * dx + dy * dy)
			if z <= tier.top + 0.05 and reach < tier.radius * 1.3 then
				-- Grass on the cap, dripping unevenly down the wall.
				local theta = math.atan2(dy, dx)
				local drip = 2.2 * math.max(0, math.noise(math.cos(theta) * 4, math.sin(theta) * 4, tier.seed) + 0.25)
				if z > tier.top - tier.lip - 0.05 - drip then
					-- The top is painted in patches of the two lighter greens.
					local patch = math.noise(x * 0.22 + tier.seed, y * 0.22, 0.5)
					local r, g, b = tone(GRASS, if nz > 0.7 then (if patch > 0.05 then 0.7 else 0.45) else light)
					-- Shade under the trees.
					if nz > 0.7 then
						for _, tree in island.trees do
							local sx, sy = x - tree.x - 1.5, y - tree.y - 1
							if math.abs(tree.z - tier.top) < 0.1 and sx * sx + sy * sy < (tree.height * 0.42) ^ 2 then
								return GRASS[1][1], GRASS[1][2], GRASS[1][3]
							end
						end
					end
					return r, g, b
				end
				break
			end
		end
		-- Rock: strata bands, fading toward the sky's blue at the point.
		local strata = math.sin(z * 0.9 + math.noise(x * 0.15, y * 0.15, island.seed) * 5)
		local r, g, b = tone(STONE, light + 0.15 + (if strata > 0.6 then -0.25 else 0))
		local fade = math.clamp((0 - z) / (0 - bottom), 0, 1) * 0.3
		return r + (HAZE[1] - r) * fade, g + (HAZE[2] - g) * fade, b + (HAZE[3] - b) * fade
	end
end

local function rockGenotype(seed)
	local rng = seeded(seed)
	return {
		radius = rng.number(2.5, 5),
		tall = rng.number(0.8, 1.7),
		seed = seed % 89,
	}
end

-- A boulder: a blob with a flattened top, its sides pushed in and out.
local function buildRock(vertex, face, rock)
	local rings, sides = 6, 9
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local theta = s / sides * TAU
			local bump = 1 + 0.45 * math.noise(math.cos(theta) * 1.5 + rock.seed, math.sin(theta) * 1.5, r * 0.8)
			local reach = math.sin(phi) * rock.radius * bump
			-- Flat on top, drawn out to a point underneath.
			local z = if phi < math.pi / 2 then math.cos(phi) * rock.radius * 0.35 else math.cos(phi) * rock.radius * rock.tall
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
	return function(x, y, z, nx, ny, nz)
		x, y = x - offsetX, y - offsetY
		local light = lightOf(nx, ny, nz) + math.noise(x * 0.7, y * 0.7, z * 0.7 + rock.seed) * 0.2
		if nz > 0.55 and z > 0 then
			return tone(GRASS, if math.noise(x * 0.5 + rock.seed, y * 0.5, 0.5) > 0 then 0.7 else 0.45)
		end
		local r, g, b = tone(STONE, light + 0.15)
		local fade = math.clamp(-z / (rock.radius * rock.tall), 0, 1) * 0.35
		return r + (HAZE[1] - r) * fade, g + (HAZE[2] - g) * fade, b + (HAZE[3] - b) * fade
	end
end

-- Builds one part at a preview offset, flat shaded.
local function bake(name, offsetX, offsetY, size, build, painter)
	local mesh = Mesh.new()
	local function vertex(x, y, z)
		return mesh:vertex(x + offsetX, y + offsetY, z)
	end
	local function face(verts)
		mesh:face(verts)
	end
	build(vertex, face)
	mesh:setSmooth(40)
	mesh:unwrap()
	local image = Image.new(size, size, 1, 1, 1)
	mesh:paint(image, painter)
	model.part(name, mesh, image, { preview = true })
end

for index = 1, ISLANDS do
	local island = islandGenotype(index * 6151)
	local offsetX, offsetY = (index - (ISLANDS + 1) / 2) * 60, 30
	bake(string.format("Island%02d", index), offsetX, offsetY, ISLAND_TEXTURE, function(vertex, face)
		for _, tier in island.tiers do
			buildTier(vertex, face, tier)
		end
		for _, tree in island.trees do
			buildTree(vertex, face, tree)
		end
	end, islandPainter(island, offsetX, offsetY))
end

for index = 1, ROCKS do
	local rock = rockGenotype(index * 3571)
	local offsetX, offsetY = (index - (ROCKS + 1) / 2) * 16, -30
	bake(string.format("Rock%02d", index), offsetX, offsetY, ROCK_TEXTURE, function(vertex, face)
		buildRock(vertex, face, rock)
	end, rockPainter(rock, offsetX, offsetY))
end
