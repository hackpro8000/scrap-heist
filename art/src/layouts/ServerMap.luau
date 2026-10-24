-- uses: ShippingContainer CarStack CrushedCar Barrels TyreStack JunkWall Dumpster Pallets StreetlightBroken TrafficCones GroundTile MachinePad YardFence YardFenceHalf YardGate PlotMarker StorageCrate YardPath YardPathStub
-- Server Map: one server's whole map, centered on the origin, built as
-- floating islands. The arena island sits in the middle with a ring road
-- around its bowl. An avenue of four plaza islands runs east from the road to
-- the market island at the far end, and each plaza has a yard island off
-- either side, a tier higher, joined to it by a steel bridge sloping up to
-- the yard gate. The arena is the storm fight ground, banking up to the road
-- with no steps, and new players spawn round its crusher.
-- Each plot slab carries the Yard Layout template, placed piece by piece the
-- same way YardLayout.luau places it, so the map shows every yard set up.
-- Labels: ArenaIsland, Road, Arena, Ramps, Spawn, Beacon, Pad1-Pad4,
-- Avenue1-Avenue5, MarketIsland, Stall1-Stall5, Island1-Island8, Plot1-Plot8,
-- Yard1_<piece>-Yard8_<piece>, Spoke1-Spoke8, Bridge1-Bridge8,
-- Cover1-Cover8, Hatch1-Hatch4, Light1-Light4 and Cones1-Cones8.
-- Yard crates show empty, as in the Yard Layout template.
skipPart = function(name)
	return name:match("^Fill_") ~= nil
end

-- Every map part is textured at one density so nothing reads sharper or
-- blurrier than its neighbours. Props keep their own texture sizes.
useTexelDensity(16)

local ROAD_INNER, ROAD_OUTER = 50, 58
local ARENA_FLOOR, ARENA_DEPTH = 36, 3.5
-- Width of the hazard stripes inlaid round the floor edge and up each ramp.
local HAZARD_WIDTH = 1.8
local ARENA_ISLAND, YARD_ISLAND = 61, 26
-- The ring road runs a little above the ground, the arena banking down to
-- the floor inside it and the bridges sloping up to the yards outside it.
local DECK = 2
local YARD_TIER = 6
-- The avenue's plaza pads, east of the road, and the yards either side.
local PAD_XS = { 100, 184, 268, 352 }
local PAD_ISLAND, PAD_PLAZA = 14, 11
local YARD_OFFSET = 63
-- The market island closes the avenue's east end.
local MARKET_X = 424
local MARKET_ISLAND, MARKET_PLAZA = 34, 30

local GROUND = { 0.3, 0.27, 0.22 }
local ROAD = { 0.42, 0.41, 0.4 }
local CONCRETE = { 0.55, 0.54, 0.5 }
local MARK = { 0.85, 0.65, 0.15 }
local PLOT = { 0.36, 0.33, 0.28 }

-- Places one flat piece built here rather than from a model.
local function slab(label: string, build: () -> (), x: number, y: number, turn: number?)
	placeSlab(label, build, x, y, turn, function()
		finishParts()
		table.clear(parts)
	end)
end

local function polar(radius: number, degrees: number): (number, number)
	local angle = math.rad(degrees)
	return math.cos(angle) * radius, math.sin(angle) * radius
end

-- Arena island height: flat, except the arena sinks into a bowl whose
-- sloped rim meets the ring road, so the storm fight can be watched from it.
local function smoothstep(low: number, high: number, value: number): number
	local t = math.clamp((value - low) / (high - low), 0, 1)
	return t * t * (3 - 2 * t)
end

-- The arena island is an octagon with a flat side facing each spoke, so
-- everything built on it (floor, bowl, road, wall) shares its outline.
-- octagonScale is how far the edge reaches at an angle, as a fraction of
-- the radius at the middle of a side; corners sit between the spokes.
local function octagonScale(degrees: number): number
	return 1 / math.cos(math.rad((degrees + 22.5) % 45 - 22.5))
end

-- Distance measured so every point on an octagon of side radius R reads R.
local function octagonRadius(x: number, y: number): number
	return math.sqrt(x * x + y * y) / octagonScale(math.deg(math.atan2(y, x)))
end

local function heightAt(x: number, y: number): number
	local radius = octagonRadius(x, y)
	return -ARENA_DEPTH + (DECK + ARENA_DEPTH) * (math.clamp((radius - ARENA_FLOOR) / (ROAD_INNER - ARENA_FLOOR), 0, 1))
end

-- A floating island: a dirt top following `top`, over a rock underside that
-- tapers to a ragged point `depth` below. Rings run outward across the top,
-- then inward down the underside, so every face keeps the same winding.
local ISLAND_SIDES = 48
local UNDERSIDE_RINGS = 16
-- outline(angle) scales the radius around the edge; nil keeps it round.
local function floatingIsland(mesh, radius: number, depth: number, seed: number, top: (number, number) -> number, outline: ((number) -> number)?, creases: { number }?)
	local rows = {}
	local function edge(angle: number): number
		return if outline then radius * outline(angle) else radius
	end
	local function addRing(fraction: number, z: (number, number, number) -> number)
		local row = {}
		for j = 0, ISLAND_SIDES - 1 do
			local angle = 2 * math.pi * j / ISLAND_SIDES
			local r = math.max(0.5, edge(angle) * fraction)
			local x, y = math.cos(angle) * r, math.sin(angle) * r
			row[j] = { x, y, z(x, y, angle) }
		end
		table.insert(rows, row)
	end
	-- Extra rings on every crease of `top`, so the surface bends there
	-- instead of cutting across the bend.
	local topRings = math.max(4, math.ceil(radius / 3))
	local fractions = {}
	for s = 0, topRings do
		table.insert(fractions, s / topRings)
	end
	for _, crease in creases or {} do
		table.insert(fractions, crease / radius)
	end
	table.sort(fractions)
	for _, fraction in fractions do
		addRing(fraction, function(x, y) return top(x, y) end)
	end
	-- The underside leans a little off centre, steps in at rough ledges, sags
	-- deeper under some lobes than others and splits into a jagged point.
	local leanAngle = math.noise(seed * 0.37, 1.7, 5) * 2 * math.pi
	local leanX, leanY = math.cos(leanAngle) * radius * 0.22, math.sin(leanAngle) * radius * 0.22
	local function undersideZ(c: number, n: number, t: number): number
		local sag = 1 + 0.35 * math.noise(c * 1.6, n * 1.6, seed + 17)
		return -depth * t ^ 1.3 * sag + 1.5 * t * math.noise(c * 3, n * 3, seed + 9)
	end
	for k = 1, UNDERSIDE_RINGS do
		local t = k / UNDERSIDE_RINGS
		local row = {}
		local ledge = 0.07 * ((t * 4 + 0.3 * math.noise(seed, t, 3)) % 1)
		for j = 0, ISLAND_SIDES - 1 do
			local angle = 2 * math.pi * j / ISLAND_SIDES
			local c, n = math.cos(angle), math.sin(angle)
			local wobble = (math.noise(c * 2, n * 2, seed + t * 3) + 0.4 * math.noise(c * 6, n * 6, seed + t * 5)) * math.min(1, t * 3)
			local r = math.max(edge(angle) * ((1 - t) ^ 1.1 - ledge * (1 - t)) * (1 + 0.35 * wobble), radius * 0.03)
			row[j] = { c * r + leanX * t * t, n * r + leanY * t * t, undersideZ(c, n, t) }
		end
		table.insert(rows, row)
	end
	local verts = {}
	for i, row in rows do
		verts[i] = {}
		for j = 0, ISLAND_SIDES - 1 do
			verts[i][j] = mesh:vertex(row[j][1], row[j][2], row[j][3])
		end
	end
	for i = 1, #verts - 1 do
		for j = 0, ISLAND_SIDES - 1 do
			local l = (j + 1) % ISLAND_SIDES
			mesh:face({ verts[i][j], verts[i + 1][j], verts[i + 1][l], verts[i][l] })
		end
	end
	local topCap, bottomCap = {}, {}
	for j = 0, ISLAND_SIDES - 1 do
		table.insert(topCap, verts[1][j])
		table.insert(bottomCap, 1, verts[#verts][j])
	end
	mesh:face(topCap)
	mesh:face(bottomCap)
	-- Rock spikes hang from the underside, rooted inside it.
	local SPIKE_SIDES = 6
	for spike = 1, 2 + math.floor(radius / 20) do
		local angle = (seed * 2.3 + spike * 2.1 + math.noise(seed, spike, 11)) % (2 * math.pi)
		local c, n = math.cos(angle), math.sin(angle)
		local reach = edge(angle) * (0.35 + 0.2 * (math.noise(seed, spike, 13) + 0.5))
		local t = 1 - (reach / edge(angle)) ^ (1 / 1.1)
		local width = math.max(1, radius * 0.08)
		-- Root at the highest underside point across the base so no side of
		-- it hangs below the rock where the underside slopes.
		local outerT = 1 - (math.min(reach + width * 1.5, edge(angle)) / edge(angle)) ^ (1 / 1.1)
		local rootZ = math.max(undersideZ(c, n, t), undersideZ(c, n, outerT)) + 1.5
		local length = depth * (0.25 + 0.3 * (math.noise(seed, spike, 19) + 0.5)) + rootZ - undersideZ(c, n, t)
		local x, y = c * reach + leanX * t * t, n * reach + leanY * t * t
		local ring = {}
		for j = 0, SPIKE_SIDES - 1 do
			local a = 2 * math.pi * j / SPIKE_SIDES
			local w = width * (1 + 0.3 * math.noise(spike, j, seed))
			ring[j] = mesh:vertex(x + math.cos(a) * w, y + math.sin(a) * w, rootZ)
		end
		local tip = mesh:vertex(x + c * width * 0.6, y + n * width * 0.6, rootZ - length)
		for j = 0, SPIKE_SIDES - 1 do
			mesh:face({ ring[j], tip, ring[(j + 1) % SPIKE_SIDES] })
		end
	end
	-- The underside wall at `angle`, `t` of the way down, for things set into it.
	return function(angle: number, t: number): (number, number, number)
		local c, n = math.cos(angle), math.sin(angle)
		local ledge = 0.07 * ((t * 4 + 0.3 * math.noise(seed, t, 3)) % 1)
		local wobble = (math.noise(c * 2, n * 2, seed + t * 3) + 0.4 * math.noise(c * 6, n * 6, seed + t * 5)) * math.min(1, t * 3)
		local r = math.max(edge(angle) * ((1 - t) ^ 1.1 - ledge * (1 - t)) * (1 + 0.35 * wobble), radius * 0.03)
		return c * r + leanX * t * t, n * r + leanY * t * t, undersideZ(c, n, t)
	end
end

-- Mechanical scrap half buried in an island's wall: cogs set edge-on, pipe
-- stubs and I-beam ends jutting out. Each piece is centred on the wall or
-- behind it, so a good part of it is always inside the rock.
local RUST = { 0.45, 0.25, 0.14 }
local function scrapPaint(x: number, y: number, z: number): (number, number, number)
	local k = 1 + 0.2 * math.noise(x * 1.5, y * 1.5, z * 1.5)
	local bare = math.clamp(math.noise(x / 2, y / 2, z / 2 + 7) * 3, 0, 1)
	return (RUST[1] + (0.38 - RUST[1]) * bare) * k, (RUST[2] + (0.37 - RUST[2]) * bare) * k, (RUST[3] + (0.36 - RUST[3]) * bare) * k
end
-- A prism along `axis`: `profile` swept from `from` to `to`, capped by fans
-- from the axis so star-shaped profiles like cogs close properly.
local function prism(mesh, origin, axis, side, up, profile: { { number } }, from: number, to: number)
	local function at(a: number, b: number, s: number)
		return mesh:vertex(
			origin[1] + axis[1] * s + side[1] * a + up[1] * b,
			origin[2] + axis[2] * s + side[2] * a + up[2] * b,
			origin[3] + axis[3] * s + side[3] * a + up[3] * b
		)
	end
	local near, far = {}, {}
	for k, point in profile do
		near[k], far[k] = at(point[1], point[2], from), at(point[1], point[2], to)
	end
	local nearMiddle, farMiddle = at(0, 0, from), at(0, 0, to)
	for k = 1, #profile do
		local l = k % #profile + 1
		mesh:face({ near[k], near[l], far[l], far[k] })
		mesh:face({ nearMiddle, near[l], near[k] })
		mesh:face({ farMiddle, far[k], far[l] })
	end
end
local function unit(v)
	local length = math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
	return { v[1] / length, v[2] / length, v[3] / length }
end
local function cross(a, b)
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
local function circle(radius: number, sides: number)
	local profile = {}
	for k = 0, sides - 1 do
		local a = 2 * math.pi * k / sides
		table.insert(profile, { math.cos(a) * radius, math.sin(a) * radius })
	end
	return profile
end
-- A point on the island wall and its outward normal, from the wall's slope
-- round and down.
local function wallPoint(wall: (number, number) -> (number, number, number), angle: number, t: number)
	local e = 0.01
	local x, y, z = wall(angle, t)
	local ax, ay, az = wall(angle + e, t)
	local dx, dy, dz = wall(angle, t + e)
	local out = unit(cross({ dx - x, dy - y, dz - z }, { ax - x, ay - y, az - z }))
	if out[1] * math.cos(angle) + out[2] * math.sin(angle) < 0 then
		out = { -out[1], -out[2], -out[3] }
	end
	return { x, y, z }, out
end

local function buryScrap(mesh, wall: (number, number) -> (number, number, number), radius: number, seed: number)
	local function rectangle(halfA: number, halfB: number, offsetB: number)
		return { { -halfA, offsetB - halfB }, { halfA, offsetB - halfB }, { halfA, offsetB + halfB }, { -halfA, offsetB + halfB } }
	end
	local size = math.clamp(radius / 12, 1.5, 3)
	for piece = 1, 3 + math.floor(radius / 20) do
		local angle = (seed * 1.7 + piece * 2 * math.pi / (3 + math.floor(radius / 20)) + 0.8 * math.noise(seed, piece, 23)) % (2 * math.pi)
		local t = 0.3 + 0.35 * (math.noise(seed, piece, 29) + 0.5)
		local scale = size * (0.6 + 0.8 * math.clamp(math.noise(seed, piece, 31) + 0.5, 0, 1))
		local point, out = wallPoint(wall, angle, t)
		local x, y, z = point[1], point[2], point[3]
		local tangent = unit(cross({ 0, 0, 1 }, out))
		local tangentUp = cross(out, tangent)
		local twist = math.noise(seed, piece, 37) * math.pi
		local kind = (seed + piece) % 3
		if kind == 0 then
			-- A cog set edge-on, its axle along the wall at a random tilt and
			-- its hub sunk behind the surface so only a toothed arc shows.
			local axle = unit({
				tangent[1] * math.cos(twist) + tangentUp[1] * math.sin(twist),
				tangent[2] * math.cos(twist) + tangentUp[2] * math.sin(twist),
				tangent[3] * math.cos(twist) + tangentUp[3] * math.sin(twist),
			})
			local across = cross(axle, out)
			local cogRadius = 1.6 * scale
			local teeth = 8 + 2 * math.floor(scale * 2)
			local profile = {}
			for k = 0, teeth * 4 - 1 do
				local a = 2 * math.pi * k / (teeth * 4)
				local r = if k % 4 < 2 then cogRadius * 1.22 else cogRadius
				table.insert(profile, { math.cos(a) * r, math.sin(a) * r })
			end
			local sink = cogRadius * 0.35
			local centre = { x - out[1] * sink, y - out[2] * sink, z - out[3] * sink }
			prism(mesh, centre, axle, out, across, profile, -0.25 * scale, 0.25 * scale)
			prism(mesh, centre, axle, out, across, circle(cogRadius * 0.3, 8), -0.45 * scale, 0.45 * scale)
		else
			-- A pipe or an I-beam jutting out of the rock, tilted off the
			-- normal, with as much buried behind the wall as shows in front.
			local tilt = 0.5 * math.noise(seed, piece, 41)
			local axis = unit({
				out[1] + tangent[1] * tilt + tangentUp[1] * twist * 0.25,
				out[2] + tangent[2] * tilt + tangentUp[2] * twist * 0.25,
				out[3] + tangent[3] * tilt + tangentUp[3] * twist * 0.25,
			})
			local side = unit(cross(axis, tangentUp))
			local up = cross(side, axis)
			local length = (if kind == 1 then 2.5 else 3.5) * scale
			local origin = { x, y, z }
			if kind == 1 then
				prism(mesh, origin, axis, side, up, circle(0.55 * scale, 10), -length, length)
				-- A flange round the open end.
				prism(mesh, origin, axis, side, up, circle(0.7 * scale, 10), length - 0.25 * scale, length)
			else
				local h, w = 0.6 * scale, 0.5 * scale
				prism(mesh, origin, axis, side, up, rectangle(0.08 * scale, h, 0), -length, length)
				prism(mesh, origin, axis, side, up, rectangle(w, 0.08 * scale, h), -length, length)
				prism(mesh, origin, axis, side, up, rectangle(w, 0.08 * scale, -h), -length, length)
			end
		end
	end
end

-- Dirt on top; underneath, rock in uneven strata with darker seams.
-- Rock strata alternate between ochre, slate and rust, darkening with depth
-- as less light reaches the underside. A band of topsoil fades into them
-- under the rim.
local STRATA = { { 0.5, 0.4, 0.27 }, { 0.36, 0.35, 0.34 }, { 0.48, 0.3, 0.22 } }
local TOPSOIL = { 0.24, 0.19, 0.14 }
local function islandPaint(top: (number, number) -> number)
	return function(x: number, y: number, z: number)
		local below = top(x, y) - z
		if below < 0.3 then
			local k = 1 + 0.12 * math.noise(x / 4, y / 4, 31) + 0.05 * math.noise(x * 3, y * 3, 37)
			return GROUND[1] * k, GROUND[2] * k, GROUND[3] * k
		end
		local band = math.noise(x / 9, y / 9, z / 2) * 0.6 + z * 0.9
		local wave = math.sin(band * 2.4)
		local layer = STRATA[math.floor(band * 2.4 / (2 * math.pi)) % 3 + 1]
		local k = 1 + 0.1 * wave + 0.06 * math.noise(x * 2, y * 2, z * 2)
		if wave > 0.93 then k -= 0.25 end
		k *= 1 - 0.6 * math.clamp((below - 3) / 20, 0, 1)
		local soil = 1 - math.clamp((below - 1) / 1.5 + 0.3 * math.noise(x / 2, y / 2, 41), 0, 1)
		local r, g, b = layer[1] * k, layer[2] * k, layer[3] * k
		return r + (TOPSOIL[1] - r) * soil, g + (TOPSOIL[2] - g) * soil, b + (TOPSOIL[3] - b) * soil
	end
end

local function flat(_x: number, _y: number): number
	return 0
end
local function yardLevel(_x: number, _y: number): number
	return YARD_TIER
end

-- Under the ring road the dirt dips out of sight, since the road is thinner
-- than the surface wobble and the dirt would otherwise poke through it. It
-- comes back up under the kerb.
local ROAD_SINK = 0.15
local function islandTop(x: number, y: number): number
	local radius = octagonRadius(x, y)
	local into = math.clamp((radius - ROAD_INNER) / 0.5, 0, 1)
	local out = math.clamp((radius - ROAD_OUTER) / 0.4, 0, 1)
	return heightAt(x, y) - ROAD_SINK * (into - out)
end

slab("ArenaIsland", function()
	local arenaWall
	chunkedPart("Island", nil, GROUND, function(mesh)
		arenaWall = floatingIsland(mesh, ARENA_ISLAND, 42, 1, islandTop, function(angle)
			return octagonScale(math.deg(angle))
		end, { ARENA_FLOOR, ROAD_INNER, ROAD_INNER + 0.5, ROAD_OUTER, ROAD_OUTER + 0.4 })
	end, nil, islandPaint(islandTop))
	part("Scrap", nil, RUST, function(mesh)
		buryScrap(mesh, arenaWall, ARENA_ISLAND, 1)
	end, nil, scrapPaint)
end, 0, 0)
-- Fractal noise: octaves of math.noise, each twice as fine and half as strong.
local function fbm(x: number, y: number, z: number): number
	local total, amplitude = 0, 0.5
	for _ = 1, 4 do
		total += math.noise(x, y, z) * amplitude
		x, y, z, amplitude = x * 2, y * 2, z * 2, amplitude / 2
	end
	return total
end
-- fBm sampled through another fBm, so the wear twists into blotches and
-- streaks instead of even waves.
local function warpedFbm(x: number, y: number, z: number): number
	return fbm(x + 1.8 * fbm(x + 5.2, y + 1.3, z), y + 1.8 * fbm(x + 1.7, y + 9.2, z), z)
end
-- A solid band following a circle between two angles, used for the kerb,
-- floor stripes and rim wall. With `octagon` it follows the arena octagon
-- instead, with a row on every corner it passes so the corners stay sharp.
local function arc(mesh, inner: number, outer: number, bottom: number, top: number, from: number, to: number, octagon: boolean?)
	local angles = {}
	local steps = math.max(1, math.ceil((to - from) / 4))
	for s = 0, steps do
		table.insert(angles, from + (to - from) * s / steps)
	end
	if octagon then
		for corner = math.floor((from - 22.5) / 45 + 1) * 45 + 22.5, to - 0.01, 45 do
			if math.abs((corner - from) % ((to - from) / steps)) > 0.01 then
				table.insert(angles, corner)
			end
		end
		table.sort(angles)
	end
	steps = #angles - 1
	local rows = {}
	for s = 0, steps do
		local scale = if octagon then octagonScale(angles[s + 1]) else 1
		local angle = math.rad(angles[s + 1])
		local c, n = math.cos(angle) * scale, math.sin(angle) * scale
		rows[s] = {
			mesh:vertex(c * outer, n * outer, bottom),
			mesh:vertex(c * outer, n * outer, top),
			mesh:vertex(c * inner, n * inner, top),
			mesh:vertex(c * inner, n * inner, bottom),
		}
	end
	for s = 0, steps - 1 do
		local a, b = rows[s], rows[s + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
	mesh:face({ rows[0][4], rows[0][3], rows[0][2], rows[0][1] })
	mesh:face(rows[steps])
end

-- Arena concrete: broad warped stains from oil and fights, mottled patches
-- of differing cure, fine aggregate showing through the worn top, and
-- scuffs: short streaks scraped by bots, running one way per patch of floor.
local function scuff(x: number, y: number): number
	local angle = math.noise(x / 12, y / 12, 17) * math.pi * 2
	local u = x * math.cos(angle) + y * math.sin(angle)
	local v = y * math.cos(angle) - x * math.sin(angle)
	local streak = math.noise(u / 1.6, v * 7, 19)
	local patch = fbm(x / 6, y / 6, 23) + 0.02
	if patch <= 0 then return 0 end
	return math.clamp(math.abs(streak) - 0.12, 0, 1) * math.sign(streak) * math.min(1, patch * 8)
end
local function arenaConcrete(x: number, y: number, _z: number)
	local stain = warpedFbm(x / 14, y / 14, 3)
	local mottle = fbm(x / 3, y / 3, 7)
	local grain = math.noise(x * 6, y * 6, 11) * 0.5 + math.noise(x * 19, y * 19, 13) * 0.5
	local k = 1 + mottle * 0.12 + grain * 0.05 - math.max(0, stain) * 0.35
	if grain > 0.42 then
		k += 0.1
	elseif grain < -0.45 then
		k -= 0.08
	end
	local mark = scuff(x, y)
	k += if mark > 0 then mark * 0.4 else mark * 0.5
	return CONCRETE[1] * k, CONCRETE[2] * k, CONCRETE[3] * (k - math.max(0, stain) * 0.04)
end
-- Bridge deck: riveted steel tread plates laid across the span, with dark
-- seams, raised diamond treads worn smooth down the two wheel paths, hazard
-- chevrons painted along both outer plates, and grime and rust bleeding in
-- from the edges. Painted in the bridge's own frame so every bridge wears
-- the same way along its length.
local function bridgeDeck(degrees: number, cx: number, cy: number)
	local angle = math.rad(degrees - 90)
	local c, s = math.cos(angle), math.sin(angle)
	return function(x: number, y: number, _z: number)
		local u = (x - cx) * c + (y - cy) * s
		local v = (y - cy) * c - (x - cx) * s
		local edge = 3 - math.abs(u)
		local wheel = math.exp(-((math.abs(u) - 1.4) / 0.5) ^ 2)
		local k = 0.72 + fbm(u / 2, v / 2, 31) * 0.1
		-- Diamond treads alternate direction, flattened where tyres run.
		local du, dv = (u * 5) % 1 - 0.5, (v * 2.5) % 1 - 0.5
		local flip = if math.floor(u * 5) % 2 == math.floor(v * 2.5) % 2 then 1 else -1
		local tread = math.abs(du * 2 + flip * dv * 1.2) < 0.18 and math.abs(du) < 0.38
		if tread then
			k += 0.14 * (1 - wheel * 0.8)
		end
		k += wheel * (0.08 + fbm(u * 3, v / 4, 37) * 0.08)
		-- Plate seams every 2 studs, with a bolt pair near each edge.
		local seam = math.abs((v % 2) - 1)
		if seam > 0.96 then
			k -= 0.35
		elseif seam > 0.86 and math.abs(edge - 0.35) < 0.1 then
			k += 0.25
		end
		-- Edge grime and rust runs.
		local grime = math.clamp(1 - edge / 0.9, 0, 1) * (0.6 + fbm(v / 1.5, u, 41) * 0.8)
		k -= grime * 0.3 + math.max(0, warpedFbm(u / 3, v / 3, 43)) * 0.25
		local rust = math.clamp(grime + math.max(0, fbm(u, v / 1.2, 47)) - 0.35, 0, 1)
		local r, g, b = STEEL[1], STEEL[2], STEEL[3]
		-- Hazard chevrons painted onto the outer plates, leaning toward the
		-- arena and worn through to bare steel on the raised treads.
		if math.abs(math.abs(u) - 2.45) < 0.25 then
			local paint = if math.floor((v + math.abs(u) * 1.2) / 0.45) % 2 == 0 then MARK else { 0.1, 0.1, 0.1 }
			local wear = math.clamp(fbm(u * 4, v, 53) * 0.8 + (if tread then 0.35 else 0), 0, 1)
			r, g, b = paint[1] + (r - paint[1]) * wear, paint[2] + (g - paint[2]) * wear, paint[3] + (b - paint[3]) * wear
			k = 0.75 + (k - 0.75) * 0.5
		end
		return r * k + rust * 0.12, g * k + rust * 0.02, b * k - rust * 0.06
	end
end
-- Bridge girders: dark paint flaking off in patches to bare rust, with
-- rivet rows along both flanges.
local function bridgeGirders(degrees: number, cx: number, cy: number)
	local angle = math.rad(degrees - 90)
	local c, s = math.cos(angle), math.sin(angle)
	return function(x: number, y: number, z: number)
		local u = (x - cx) * c + (y - cy) * s
		local v = (y - cy) * c - (x - cx) * s
		local k = 1 + fbm(u + v / 2, z * 2, 51) * 0.12
		local flake = warpedFbm(v / 2.5, z * 1.5 + u, 53)
		local rust = math.clamp((flake - 0.1) * 4, 0, 1)
		local flange = math.abs(z + 0.35) < 0.05 or math.abs(z + 1.25) < 0.05
		local rivet = flange and math.abs(((v * 2) % 1) - 0.5) < 0.04
		if rivet then k += 0.45 end
		local r = DARK_STEEL[1] * k * (1 - rust) + 0.42 * rust * k
		local g = DARK_STEEL[2] * k * (1 - rust) + 0.2 * rust * k
		local b = DARK_STEEL[3] * k * (1 - rust) + 0.1 * rust * k
		return r, g, b
	end
end
slab("Arena", function()
	chunkedPart("Floor", nil, CONCRETE, function(mesh)
		arc(mesh, 0, ARENA_FLOOR - HAZARD_WIDTH, -ARENA_DEPTH - 0.1, 0.1 - ARENA_DEPTH, 0, 360, true)
	end, nil, arenaConcrete)
end, 0, 0)
-- New players start on a ring round the crusher.
slab("Spawn", function()
	part("Pad", nil, MARK, function(mesh)
		ring(mesh, 0, 0, 0.2 - ARENA_DEPTH, 6.5, 8.5, 0.1, "z", 32)
	end, nil, 0)
end, 0, 0)

-- The crusher, the arena's centrepiece: a hydraulic press over a sunken
-- bed, four pillars carrying a crossbeam, and a press head held up over a
-- half-flattened car.
-- A square beam with flat ends running from one point up to another, for
-- legs that lean.
local function leg(mesh, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, width: number)
	local h = width / 2
	local corners = { { -h, -h }, { h, -h }, { h, h }, { -h, h } }
	local base, cap = {}, {}
	for k, c in corners do
		base[k] = mesh:vertex(x0 + c[1], y0 + c[2], z0)
		cap[k] = mesh:vertex(x1 + c[1], y1 + c[2], z1)
	end
	for k = 1, 4 do
		local l = k % 4 + 1
		mesh:face({ base[k], base[l], cap[l], cap[k] })
	end
	mesh:face(cap)
	mesh:face({ base[4], base[3], base[2], base[1] })
end

-- The storm beacon: a mast with a glowing core that lights up when a storm
-- round starts, visible from every yard.
local MAST_TOP = 24
local STORM_GLOW = { 0.35, 0.85, 1 }
slab("Beacon", function()
	local floor = 0.1 - ARENA_DEPTH
	part("Plinth", nil, CONCRETE, function(mesh)
		cylinder(mesh, 0, 0, floor + 0.6, 4.5, 1.2, "z", 8)
		cylinder(mesh, 0, 0, floor + 1.5, 3.4, 0.6, "z", 8)
	end, nil, 0.5)
	part("PlinthStripe", nil, MARK, function(mesh)
		ring(mesh, 0, 0, floor + 1.15, 4.4, 4.55, 0.25, "z", 8)
	end, nil, 0.3)
	-- Four straight legs leaning in towards the top, tied together with braces.
	part("Mast", nil, DARK_STEEL, function(mesh)
		local bottom, top = floor + 1.8, floor + MAST_TOP
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				leg(mesh, sx * 2.2, sy * 2.2, bottom, sx * 0.8, sy * 0.8, top, 0.45)
			end
		end
		local braces = 6
		for i = 1, braces do
			local t = i / braces
			local z = bottom + t * (top - bottom) - 0.25
			local half = 2.2 - t * 1.4
			box(mesh, 0, half, z, half * 2, 0.25, 0.25)
			box(mesh, 0, -half, z, half * 2, 0.25, 0.25)
			box(mesh, half, 0, z, 0.25, half * 2, 0.25)
			box(mesh, -half, 0, z, 0.25, half * 2, 0.25)
		end
	end, nil, 0.6)
	part("CoreMount", nil, STEEL, function(mesh)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 0.3, 1.9, 0.6, "z", 16)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 4.25, 1.9, 0.5, "z", 16)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 6.5, 0.15, 4, "z", 8)
	end, nil, 0.2)
	-- The core sits on top of the mast and is the part that glows during a storm.
	part("Core", nil, STORM_GLOW, function(mesh)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 2.3, 1.4, 3.4, "z", 16)
	end, nil, 0, nil, 1)
	part("CoreCage", nil, DARK_STEEL, function(mesh)
		for k = 0, 5 do
			local angle = math.rad(k * 60)
			box(mesh, math.cos(angle) * 1.65, math.sin(angle) * 1.65, floor + MAST_TOP + 0.6, 0.2, 0.2, 3.4)
		end
	end, nil, 0.3)
end, 0, 0)


-- The arena edge stands out from the yards around it: hazard stripes ring the
-- fight floor, and a low concrete wall with yellow caps tops the bowl,
-- broken where each spoke comes in.
-- The ramp lane, with a hazard strip outside it on each side.
local LANE_HALF = 3.6
local RAMP_HALF = LANE_HALF + HAZARD_WIDTH
-- Asphalt at u studs across and v along a road: fine aggregate, darker
-- repair patches, polished tyre lanes, oil drips between them, a web of
-- cracks, and worn paint: white edge lines and a dashed yellow centre line.
local function asphalt(u: number, v: number, half: number, seed: number): (number, number, number)
	local k = 1 + fbm(u * 3, v * 3, seed) * 0.12
	k += (math.noise(u * 9.1, v * 9.1, seed + 1) > 0.35 and 0.1 or 0)
	local patch = warpedFbm(u / 6, v / 6, seed + 2)
	if patch > 0.22 then
		k -= 0.16
	end
	local lane = math.exp(-((math.abs(u) - half / 2) / 0.6) ^ 2)
	k += lane * (0.07 + fbm(u, v / 5, seed + 3) * 0.05)
	local oil = math.max(0, fbm(u / 1.5, v / 3, seed + 4) - 0.15) * (1 - lane)
	k -= oil * 0.9
	local crack = math.abs(warpedFbm(u / 3, v / 3, seed + 5))
	if crack < 0.012 then
		k -= 0.35
	end
	local r, g, b = ROAD[1] * k, ROAD[2] * k, ROAD[3] * k * 1.02
	local fade = math.clamp(0.75 + fbm(u * 2, v / 2, seed + 6) * 1.2 - lane * 0.3, 0, 1)
	local edgeLine = math.abs(math.abs(u) - (half - 0.5)) < 0.1
	if edgeLine then
		return r + (0.82 - r) * fade, g + (0.8 - g) * fade, b + (0.74 - b) * fade
	end
	return r, g, b
end

-- The ring road, with a concrete kerb along its outer edge broken only where
-- the avenue leaves it to the east. The inner edge stays open onto the arena rim.
slab("Road", function()
	local middle = (ROAD_INNER + ROAD_OUTER) / 2
	chunkedPart("Ring", nil, ROAD, function(mesh)
		arc(mesh, ROAD_INNER, ROAD_OUTER, DECK - 0.6, DECK, 0, 360, true)
	end, nil, function(x, y)
		local radius = octagonRadius(x, y)
		return asphalt(radius - middle, math.atan2(y, x) * middle, (ROAD_OUTER - ROAD_INNER) / 2, 61)
	end)
	-- The kerb stops against the outer faces of the avenue bridge's wing walls.
	local bridgeGap = math.deg(math.asin(3.65 / ROAD_OUTER))
	part("Kerb", nil, CONCRETE, function(mesh)
		arc(mesh, ROAD_OUTER - 0.1, ROAD_OUTER + 0.5, DECK - 0.6, DECK + 0.3, bridgeGap, 360 - bridgeGap, true)
	end, nil, 0.5)
end, 0, 0)

-- A plaza: an asphalt octagon at deck level on its own floating island,
-- kerbed round the edge except where a bridge lands on one of its sides.
-- The dirt dips just under the asphalt, as it does under the ring road.
local function plazaIsland(label: string, x: number, y: number, radius: number, plaza: number, depth: number, seed: number, openings: { number })
	local function top(px: number, py: number): number
		return DECK - ROAD_SINK * (1 - math.clamp((octagonRadius(px, py) - plaza) / 0.5, 0, 1))
	end
	slab(label, function()
		local wall
		part("Island", nil, GROUND, function(mesh)
			wall = floatingIsland(mesh, radius, depth, seed, top, function(angle)
				return octagonScale(math.deg(angle))
			end, { plaza, plaza + 0.5 })
		end, nil, islandPaint(function()
			return DECK - ROAD_SINK
		end))
		part("Scrap", nil, RUST, function(mesh)
			buryScrap(mesh, wall, radius, seed)
		end, nil, scrapPaint)
		part("Plaza", nil, ROAD, function(mesh)
			arc(mesh, 0, plaza, DECK - 0.6, DECK, 0, 360, true)
		end, nil, function(px, py)
			return asphalt(px - x, py - y, 40, seed + 50)
		end)
		local gap = math.deg(math.asin(3.65 / plaza))
		part("Kerb", nil, CONCRETE, function(mesh)
			for k, opening in openings do
				local after = openings[k % #openings + 1] + (if k == #openings then 360 else 0)
				arc(mesh, plaza - 0.1, plaza + 0.5, DECK - 0.6, DECK + 0.3, opening + gap, after - gap, true)
			end
		end, nil, 0.5)
	end, x, y)
end

-- Entry ramps: a concrete deck at each spoke, from the ring road down the
-- bank to the fight floor, one straight slope a touch above the bank so it
-- never dips into the terrain.
local RAMP_FLOOR = 0.1 - ARENA_DEPTH
local RAMP_CREST = DECK + 0.1
local function rampTop(radius: number): number
	return RAMP_FLOOR + (RAMP_CREST - RAMP_FLOOR) * math.clamp((radius - ARENA_FLOOR) / (ROAD_INNER - ARENA_FLOOR), 0, 1)
end
-- A block on spoke `degrees` between `from` and `to` across it and over
-- `radii` along it, its top `lift` above the deck and its bottom at the
-- arena floor or `depth` below its top.
local function rampBlock(mesh, degrees: number, radii: { number }, from: number, to: number, lift: number, depth: number?)
	local angle = math.rad(degrees)
	local c, n = math.cos(angle), math.sin(angle)
	local rows = {}
	for s, radius in radii do
		local top = rampTop(radius) + lift
		local bottom = if depth then top - depth else RAMP_FLOOR - 0.1
		rows[s] = {}
		local miter = radius * math.tan(math.rad(22.5))
		for k, side in { from, to } do
			side = math.clamp(side, -miter, miter)
			local x, y = c * radius - n * side, n * radius + c * side
			rows[s][k] = mesh:vertex(x, y, top)
			rows[s][k + 2] = mesh:vertex(x, y, bottom)
		end
	end
	for s = 1, #radii - 1 do
		local a, b = rows[s], rows[s + 1]
		mesh:face({ b[1], b[2], a[2], a[1] })
		mesh:face({ a[4], b[4], b[3], a[3] })
		mesh:face({ a[3], b[3], b[1], a[1] })
		mesh:face({ b[2], b[4], a[4], a[2] })
	end
	local first, last = rows[1], rows[#radii]
	mesh:face({ first[2], first[4], first[3], first[1] })
	mesh:face({ last[3], last[4], last[2], last[1] })
end
-- Hazard strips inlaid outside both lane edges, as wide as the arena's ring
-- and flush with the deck. They run from the road, ending yellow, across
-- the ring, which is cut at each ramp mouth and runs from strip to strip
-- along each octagon side, mitred at the corners. Blocks are clamped to the
-- octagon miters, so the last ring piece on each side runs into the corner.
local STRIP_BREAKS = { ARENA_FLOOR - HAZARD_WIDTH }
for k = 0, 6 do
	table.insert(STRIP_BREAKS, ARENA_FLOOR + k * (ROAD_INNER - ARENA_FLOOR) / 6)
end
slab("Ramps", function()
	part("Deck", nil, CONCRETE, function(mesh)
		for i = 1, 8 do
			rampBlock(mesh, (i - 1) * 45, { ARENA_FLOOR - HAZARD_WIDTH, ARENA_FLOOR, ROAD_INNER }, -LANE_HALF, LANE_HALF, 0)
		end
	end, nil, 0.25)
	for k, color in { MARK, { 0.08, 0.08, 0.08 } } do
		part(if k == 1 then "RampStripeYellow" else "RampStripeBlack", nil, color, function(mesh)
			for i = 1, 8 do
				for s = k, #STRIP_BREAKS - 1, 2 do
					local radii = { STRIP_BREAKS[s], STRIP_BREAKS[s + 1] }
					rampBlock(mesh, (i - 1) * 45, radii, -RAMP_HALF, -LANE_HALF, 0)
					rampBlock(mesh, (i - 1) * 45, radii, LANE_HALF, RAMP_HALF, 0)
				end
				-- Ring pieces, black-yellow-black from the mouth to the corner.
				local ring = { ARENA_FLOOR - HAZARD_WIDTH, ARENA_FLOOR }
				local cuts = { RAMP_HALF, RAMP_HALF + 3.2, RAMP_HALF + 6.4, 99 }
				for s = 3 - k, 3, 2 do
					rampBlock(mesh, (i - 1) * 45, ring, cuts[s], cuts[s + 1], 0)
					rampBlock(mesh, (i - 1) * 45, ring, -cuts[s + 1], -cuts[s], 0)
				end
			end
		end, nil, 0.2)
	end
end, 0, 0)
-- A steel bridge on spoke `degrees`, placed at (x, y) and turned so local +y
-- runs along it, from its low end at `to` (on deck level) to its far end at
-- `from`, which climbs to `highZ`. Every part is built flat and then sheared
-- up along its length, so posts stay upright and the end pieces sit level at
-- their own tier. A yard end lands on an apron under a gate frame; any other
-- end gets bollards like the low end.
local function bridge(label: string, x: number, y: number, degrees: number, from: number, to: number, highZ: number, yardEnd: boolean)
	local middle, length = (from + to) / 2, from - to
	local function lift(py: number): number
		return DECK + (highZ - DECK) * math.clamp((py - to) / length, 0, 1)
	end
	local function bridgePart(name: string, color, build: (any) -> (), paint)
		part(name, nil, color, function(mesh)
			build({
				vertex = function(_, vx, vy, vz)
					return mesh:vertex(vx, vy, vz + lift(vy))
				end,
				face = function(_, corners)
					return mesh:face(corners)
				end,
			})
		end, nil, paint)
	end
	slab(label, function()
		bridgePart("Deck", STEEL, function(mesh)
			box(mesh, 0, middle, -0.2, 6, length, 0.3)
		end, bridgeDeck(degrees, x, y))
		bridgePart("Girders", DARK_STEEL, function(mesh)
			-- I-beams: a web between two flanges, ribbed on the outside, with
			-- bolted splice plates where the beam sections join.
			for _, side in { -2.6, 2.6 } do
				local out = math.sign(side)
				box(mesh, side, middle, -1.4, 0.2, length, 1.2)
				box(mesh, side, middle, -1.4, 0.6, length, 0.15)
				box(mesh, side, middle, -0.4, 0.6, length, 0.15)
				for n = 0, math.floor(length / 2) do
					box(mesh, side + out * 0.17, to + 1 + n * 2, -1.25, 0.14, 0.1, 0.85)
				end
				for n = 1, math.floor(length / 8) do
					local at = to + n * 8
					box(mesh, side + out * 0.13, at, -1.15, 0.06, 0.9, 0.65)
					for _, dy in { -0.3, 0.3 } do
						for _, dz in { -1.0, -0.65 } do
							box(mesh, side + out * 0.18, at + dy, dz, 0.06, 0.1, 0.1)
						end
					end
				end
			end
			for n = 0, math.floor(length / 4) do
				box(mesh, 0, to + 1 + n * 4, -0.6, 5.6, 0.3, 0.4)
			end
		end, bridgeGirders(degrees, x, y))
		-- Railing posts spaced evenly so both ends get one, each bolted down
		-- on a base plate and capped.
		local postCount = math.ceil((length - 0.3) / 2.5)
		local postGap = (length - 0.3) / postCount
		bridgePart("Posts", STEEL, function(mesh)
			for _, side in { -2.9, 2.9 } do
				for n = 0, postCount do
					local at = to + 0.15 + n * postGap
					box(mesh, side, at, -0.05, 0.36, 0.36, 0.06)
					box(mesh, side, at, 0.01, 0.14, 0.14, 1.27)
					box(mesh, side, at, 1.28, 0.2, 0.2, 0.06)
				end
			end
		end, 0.4)
		-- Handrail on top, a thinner mid rail and a kick plate at the deck.
		bridgePart("Rail", MARK, function(mesh)
			for _, side in { -2.9, 2.9 } do
				box(mesh, side, middle, 1.16, 0.16, length - 0.2, 0.12)
				box(mesh, side, middle, 0.62, 0.08, length - 0.3, 0.08)
				box(mesh, side + math.sign(side) * 0.1, middle, -0.05, 0.04, length - 0.3, 0.22)
			end
		end, 0.3)
		-- Each end rests on a concrete seat set into the island edge, with a
		-- low wing wall either side for the kerb or yard edge to end against.
		bridgePart("Abutments", CONCRETE, function(mesh)
			for _, ends in { { to, -1 }, { from, 1 } } do
				local edge, land = ends[1], ends[2]
				box(mesh, 0, edge + land * 0.75, -3, 7.3, 3.5, 2.8)
				for _, side in { -3.4, 3.4 } do
					box(mesh, side, edge - land * 0.5, -3, 0.5, 1, 3.45)
				end
			end
		end, 0.5)
		-- A steel plate covers the joint at both ends.
		bridgePart("JointPlates", STEEL, function(mesh)
			for _, edge in { to, from } do
				box(mesh, 0, edge, 0.1, 6, 0.8, 0.04)
			end
		end, 0.3)
		-- Road ends get a hazard bollard on each wing wall.
		bridgePart("Bollards", MARK, function(mesh)
			for _, side in { -3.4, 3.4 } do
				box(mesh, side, to + 0.5, 0.45, 0.4, 0.4, 1.2)
				if not yardEnd then
					box(mesh, side, from - 0.5, 0.45, 0.4, 0.4, 1.2)
				end
			end
		end, 0.3)
		if not yardEnd then return end
		bridgePart("Apron", CONCRETE, function(mesh)
			box(mesh, 0, from + 2.5, 0, 7.3, 5, 0.12)
		end, 0.5)
		bridgePart("GateFrame", DARK_STEEL, function(mesh)
			for _, side in { -3.4, 3.4 } do
				box(mesh, side, from - 0.5, 0.45, 0.4, 0.4, 4)
			end
			box(mesh, 0, from - 0.5, 4.15, 7.2, 0.3, 0.3)
		end, 0.3)
	end, x, y, degrees - 90)
end

-- Lumpy yard outlines that never cut into the plot's corners (0.9 * 26
-- clears its 22.6 half-diagonal) and stay full where the bridge lands.
local function yardOutline(seed: number): (number) -> number
	return function(angle)
		local c, n = math.cos(angle), math.sin(angle)
		local lump = 1.1 + 0.5 * math.noise(c * 1.4, n * 1.4, seed) + 0.12 * math.noise(c * 4, n * 4, seed + 3)
		local fromBridge = math.abs((angle + math.pi / 2 + math.pi) % (2 * math.pi) - math.pi)
		local landing = 1 - smoothstep(0.25, 0.7, fromBridge)
		return math.max(0.9, lump + (1 - lump) * landing)
	end
end
-- Builds one yard from the Yard Layout pieces, laid out as in
-- YardLayout.luau but turned and moved onto the plot at (x, y). The crate
-- shows empty, as in the template.
local function yardTemplate(index: number, x: number, y: number, turn: number)
	local c, s = math.cos(math.rad(turn)), math.sin(math.rad(turn))
	local function piece(name: string, build: () -> (), px: number, py: number, pz: number?, pturn: number?)
		place(`Yard{index}_{name}`, build, x + px * c - py * s, y + px * s + py * c, (pz or 0) + YARD_TIER, turn + (pturn or 0))
	end
	for i, tx in { -12, -4, 4, 12 } do
		for j, ty in { -12, -4, 4, 12 } do
			piece(`Tile{(i - 1) * 4 + j}`, buildGroundTile, tx, ty, 0, ((tx + ty * 3) // 8 % 4) * 90)
		end
	end
	for i, pad in { { -9, 2 }, { -9, 10 }, { 9, 2 }, { 9, 10 } } do
		piece(`Pad{i}`, buildMachinePad, pad[1], pad[2])
	end
	piece("Crate", buildStorageCrate, 0, 12)
	for i, py in { -12, -4, 4 } do
		piece(`Path{i}`, buildYardPath, 0, py, 0.01)
	end
	for i, py in { 2, 10 } do
		piece(`Branch{i * 2 - 1}`, buildYardPathStub, -4, py, 0.01, 90)
		piece(`Branch{i * 2}`, buildYardPathStub, 4, py, 0.01, 90)
	end
	for i, f in { -12, -4, 4, 12 } do
		piece(`FenceBack{i}`, buildYardFence, f, 16)
		piece(`FenceLeft{i}`, buildYardFence, -16, f, 0, 90)
		piece(`FenceRight{i}`, buildYardFence, 16, f, 0, 90)
	end
	for i, side in { -1, 1 } do
		piece(`FenceFront{i}`, buildYardFence, side * 8, -16)
		piece(`FenceFrontHalf{i}`, buildYardFenceHalf, side * 14, -16)
	end
	piece("Gate", buildYardGate, 0, -16)
	piece("PlotMarker", buildPlotMarker, 6, -17.5)
end

-- The avenue: a row of plaza islands running east from the arena, each with
-- a yard off either side, joined to the ring road, to each other and to the
-- market at the far end by flat bridges.
for k, padX in PAD_XS do
	plazaIsland(`Pad{k}`, padX, 0, PAD_ISLAND, PAD_PLAZA, 20, 40 + k, { 0, 90, 180, 270 })
	local from = if k == 1 then ROAD_OUTER else PAD_XS[k - 1] + PAD_PLAZA
	bridge(`Avenue{k}`, from, 0, 0, padX - PAD_PLAZA - from, 0, DECK, false)
end
plazaIsland("MarketIsland", MARKET_X, 0, MARKET_ISLAND, MARKET_PLAZA, 30, 60, { 180 })
local lastPad = PAD_XS[#PAD_XS] + PAD_PLAZA
bridge(`Avenue{#PAD_XS + 1}`, lastPad, 0, 0, MARKET_X - MARKET_PLAZA - lastPad, 0, DECK, false)

-- Market stalls round the plaza, each on an octagon side facing the middle:
-- a counter under a striped awning, with a back wall and a post at each
-- front corner. Local +y points away from the middle.
for i, degrees in { -90, -45, 0, 45, 90 } do
	local x, y = polar(MARKET_PLAZA - 6, degrees)
	slab(`Stall{i}`, function()
		part("Frame", nil, CONCRETE, function(mesh)
			box(mesh, 0, 3.5, DECK, 8, 0.4, 3.4)
			box(mesh, -3.8, 0, DECK, 0.3, 0.3, 3.4)
			box(mesh, 3.8, 0, DECK, 0.3, 0.3, 3.4)
			box(mesh, 0, 0, DECK, 7, 1, 1.1)
		end, nil, 0.4)
		part("Awning", nil, { 0.7, 0.18, 0.12 }, function(mesh)
			for n = 0, 3 do
				box(mesh, -3.5 + n * 2 + 0.5, 1.5, DECK + 3.4, 1, 5, 0.12)
			end
		end, nil, 0.3)
		part("AwningStripes", nil, { 0.9, 0.86, 0.78 }, function(mesh)
			for n = 0, 3 do
				box(mesh, -3.5 + n * 2 + 1.5, 1.5, DECK + 3.4, 1, 5, 0.12)
			end
		end, nil, 0.3)
	end, MARKET_X + x, y, degrees - 90)
end

-- Each yard island is turned so its gate (local -y) faces its pad. A short
-- road runs from the gate to the island edge, and a steel bridge carries it
-- across the gap, sloping up from the pad to the yard tier.
local BRIDGE_FROM, BRIDGE_TO = -YARD_ISLAND, -(YARD_OFFSET - PAD_PLAZA)
for i = 1, 2 * #PAD_XS do
	local side = if i % 2 == 1 then 1 else -1
	local degrees = 180 - side * 90
	local x, y = PAD_XS[(i + 1) // 2], side * YARD_OFFSET
	slab(`Island{i}`, function()
		local wall
		part("Island", nil, GROUND, function(mesh)
			wall = floatingIsland(mesh, YARD_ISLAND, 22, 10 + i, yardLevel, yardOutline(10 + i))
		end, nil, islandPaint(yardLevel))
		part("Scrap", nil, RUST, function(mesh)
			buryScrap(mesh, wall, YARD_ISLAND, 10 + i)
		end, nil, scrapPaint)
	end, x, y, degrees - 90)
	slab(`Plot{i}`, function()
		part("Slab", nil, PLOT, function(mesh)
			box(mesh, 0, 0, YARD_TIER, 32, 32, 0.05)
		end, nil, 0)
	end, x, y, degrees - 90)
	yardTemplate(i, x, y, degrees - 90)
	local c, s = math.cos(math.rad(degrees - 90)), math.sin(math.rad(degrees - 90))
	slab(`Spoke{i}`, function()
		part("Road", nil, ROAD, function(mesh)
			box(mesh, 0, -18, YARD_TIER, 6, 6, 0.1)
		end, nil, function(px, py)
			local u = (px - x) * c + (py - y) * s
			local v = (py - y) * c - (px - x) * s
			return asphalt(u, v, 3, 70 + i)
		end)
	end, x, y, degrees - 90)
	bridge(`Bridge{i}`, x, y, degrees, BRIDGE_FROM, BRIDGE_TO, YARD_TIER, true)
end
for i = 1, 8 do
	local degrees = (i - 1) * 45
	local coneX, coneY = polar(ROAD_INNER + 1.5, degrees + 9)
	place(`Cones{i}`, buildTrafficCones, coneX, coneY, heightAt(coneX, coneY), degrees)
end

-- Cover for the storm fights, offset from the spokes so paths stay open.
for i, build in { buildShippingContainer, buildCarStack, buildCrushedCar, buildBarrels, buildTyreStack, buildJunkWall, buildDumpster, buildPallets } do
	local degrees = (i - 0.5) * 45
	local x, y = polar(26, degrees)
	place(`Cover{i}`, build, x, y, 0.2 - ARENA_DEPTH, degrees + 90)
end
-- Bot spawn hatches in the arena floor, inside the cover ring between the spokes.
-- Storm bots climb out of these; the hazard rim marks where they emerge.
for i = 1, 4 do
	local degrees = (i - 0.75) * 90
	local x, y = polar(17, degrees)
	slab(`Hatch{i}`, function()
		local floor = 0.1 - ARENA_DEPTH
		part("Rim", nil, MARK, function(mesh)
			ring(mesh, 0, 0, floor, 2.6, 3.1, 0.12, "z", 24)
		end, nil, 0.3)
		part("Frame", nil, DARK_STEEL, function(mesh)
			ring(mesh, 0, 0, floor, 2.1, 2.6, 0.2, "z", 24)
		end, nil, 0.5)
		part("Pit", nil, { 0.05, 0.05, 0.05 }, function(mesh)
			cylinder(mesh, 0, 0, floor - 0.05, 2.1, 0.1, "z", 24)
		end, nil, 0)
		part("Grate", nil, STEEL, function(mesh)
			for n = -3, 3 do
				local half = math.sqrt(2.1 * 2.1 - (n * 0.55) ^ 2)
				box(mesh, n * 0.55, 0, floor + 0.08, 0.14, half * 2, 0.1)
			end
			box(mesh, 0, 0, floor + 0.1, 4.2, 0.2, 0.12)
		end, nil, 0.4)
	end, x, y, degrees)
end
for i = 1, 4 do
	local degrees = (i - 0.75) * 90
	local x, y = polar(ROAD_INNER - 2, degrees)
	place(`Light{i}`, buildStreetlightBroken, x, y, heightAt(x, y), degrees + 90)
end

-- Plumbing: a large pipe hugging each island's wall round part of the island,
-- banded with a flange at each joint and strapped back into the rock there.
-- It comes out of the rock at one end and at the other bends down and back
-- into it. All of it lives in this one slab, so reworking the pipes rebuilds
-- only the pipes; each island's wall is traced again from its own numbers.
slab("Plumbing", function()
	local traced = { vertex = function() return 0 end, face = function() end }
	local function octagon(angle: number): number
		return octagonScale(math.deg(angle))
	end
	local function layPlumbing(name: string, x: number, y: number, turn: number, radius: number, wall: (number, number) -> (number, number, number), seed: number)
		local c, s = math.cos(math.rad(turn)), math.sin(math.rad(turn))
		local pipeRadius = math.clamp(radius / 16, 1.2, 2.6)
		local pipe, flange = circle(pipeRadius, 12), circle(pipeRadius * 1.25, 12)
		local function centre(angle: number, t: number, lift: number)
			local point, out = wallPoint(wall, angle, t)
			return { point[1] + out[1] * lift, point[2] + out[2] * lift, point[3] + out[3] * lift }, out
		end
		part(name, nil, RUST, function(island)
			-- Built in the island's own frame, then turned and moved onto it.
			local mesh = {
				vertex = function(_, vx, vy, vz)
					return island:vertex(x + vx * c - vy * s, y + vx * s + vy * c, vz)
				end,
				face = function(_, corners)
					return island:face(corners)
				end,
			}
			local function run(from, to, out, buryStart: boolean, buryEnd: boolean)
				local axis = { to[1] - from[1], to[2] - from[2], to[3] - from[3] }
				local length = math.sqrt(axis[1] ^ 2 + axis[2] ^ 2 + axis[3] ^ 2)
				axis = unit(axis)
				local side = unit(cross(axis, out))
				local up = cross(side, axis)
				local start = if buryStart then -pipeRadius * 2 else -pipeRadius * 0.3
				prism(mesh, from, axis, side, up, pipe, start, length + pipeRadius * 0.3)
				prism(mesh, from, axis, side, up, flange, -0.25, 0.25)
				if buryEnd then return end
				-- A strap from the flange back into the rock behind it.
				local strapSide = unit(cross(out, axis))
				prism(mesh, from, { -out[1], -out[2], -out[3] }, axis, strapSide, { { -0.2, -pipeRadius * 0.5 }, { 0.2, -pipeRadius * 0.5 }, { 0.2, pipeRadius * 0.5 }, { -0.2, pipeRadius * 0.5 } }, 0, pipeRadius * 2.5)
			end
			local runs = 1 + math.floor(radius / 40)
			for n = 1, runs do
				local first = (seed * 2.3 + n * 2 * math.pi / runs) % (2 * math.pi)
				local span = 0.6 + 0.3 * (math.noise(seed, n, 53) + 0.5)
				local level = 0.42 + 0.06 * math.noise(seed, n, 59)
				local lift = pipeRadius * 0.9
				-- Round the wall in steps of about four studs.
				local steps = math.max(3, math.floor(span * radius / 4))
				local previous = centre(first, level, lift)
				for k = 1, steps do
					local here, out = centre(first + span * k / steps, level, lift)
					run(previous, here, out, k == 1, false)
					previous = here
				end
				-- Down the wall a little, then back into the rock.
				local last = first + span
				local downT = level + 0.12
				for k = 1, 2 do
					local here, out = centre(last, level + (downT - level) * k / 2, lift)
					run(previous, here, out, false, false)
					previous = here
				end
				local inside, out = centre(last + 0.04, downT + 0.04, -pipeRadius * 2.5)
				run(previous, inside, out, false, true)
			end
		end, nil, scrapPaint)
	end
	-- Waste outfalls: a short pipe out of the wall, tipped down, its open
	-- mouth long dry but for green goo still clinging round the lower lip and
	-- one last drop hanging off it.
	local GOO = { 0.38, 0.95, 0.16 }
	-- A solid of revolution hanging straight down from `top`, from rings of
	-- { depth, radius }.
	local function lathe(mesh, top, rings: { { number } })
		local sides = 10
		local loops = {}
		for i, ring in rings do
			loops[i] = {}
			for k = 0, sides - 1 do
				local a = 2 * math.pi * k / sides
				loops[i][k + 1] = mesh:vertex(top[1] + math.cos(a) * ring[2], top[2] + math.sin(a) * ring[2], top[3] - ring[1])
			end
		end
		local first, last = mesh:vertex(top[1], top[2], top[3] - rings[1][1]), mesh:vertex(top[1], top[2], top[3] - rings[#rings][1])
		for k = 1, sides do
			local l = k % sides + 1
			for i = 1, #rings - 1 do
				mesh:face({ loops[i][k], loops[i][l], loops[i + 1][l], loops[i + 1][k] })
			end
			mesh:face({ first, loops[1][l], loops[1][k] })
			mesh:face({ last, loops[#rings][k], loops[#rings][l] })
		end
	end
	local function layWastePipe(name: string, x: number, y: number, turn: number, radius: number, wall: (number, number) -> (number, number, number), angle: number)
		local c, s = math.cos(math.rad(turn)), math.sin(math.rad(turn))
		local pipeRadius = math.clamp(radius / 22, 1, 1.8)
		local root, normal = wallPoint(wall, angle, 0.3)
		local flatOut = unit({ normal[1], normal[2], 0 })
		local axis = unit({ flatOut[1], flatOut[2], -0.3 })
		local side = unit(cross(axis, { 0, 0, 1 }))
		local up = cross(side, axis)
		local length = pipeRadius * 3.5
		local mouth = { root[1] + axis[1] * length, root[2] + axis[2] * length, root[3] + axis[3] * length }
		local function onIsland(build: (any) -> ())
			return function(island)
				build({
					vertex = function(_, vx, vy, vz)
						return island:vertex(x + vx * c - vy * s, y + vx * s + vy * c, vz)
					end,
					face = function(_, corners)
						return island:face(corners)
					end,
				})
			end
		end
		-- Points round the mouth: `degrees` round from the top, `reach` out
		-- from the axis, `along` past the pipe's end.
		local function rim(degrees: number, reach: number, along: number)
			local a = math.rad(degrees)
			return {
				mouth[1] + (up[1] * math.cos(a) + side[1] * math.sin(a)) * reach + axis[1] * along,
				mouth[2] + (up[2] * math.cos(a) + side[2] * math.sin(a)) * reach + axis[2] * along,
				mouth[3] + (up[3] * math.cos(a) + side[3] * math.sin(a)) * reach + axis[3] * along,
			}
		end
		-- Sweeps a closed { reach, along } section round the mouth from one
		-- angle to another, capping the ends unless it goes all the way round.
		local function sweep(mesh, from: number, to: number, steps: number, section: (number) -> { { number } })
			local loops = {}
			for j = 0, steps do
				local degrees = from + (to - from) * j / steps
				loops[j] = {}
				for i, point in section(degrees) do
					local at = rim(degrees, point[1], point[2])
					loops[j][i] = mesh:vertex(at[1], at[2], at[3])
				end
			end
			for j = 0, steps - 1 do
				local n = #loops[j]
				for i = 1, n do
					local k = i % n + 1
					mesh:face({ loops[j][i], loops[j][k], loops[j + 1][k], loops[j + 1][i] })
				end
			end
			if to - from >= 360 then return end
			for _, ends in { { 0, false }, { steps, true } } do
				local loop = loops[ends[1]]
				for i = 2, #loop - 1 do
					if ends[2] then
						mesh:face({ loop[1], loop[i], loop[i + 1] })
					else
						mesh:face({ loop[1], loop[i + 1], loop[i] })
					end
				end
			end
		end
		local bore, wallOut, lipOut = pipeRadius * 0.8, pipeRadius, pipeRadius * 1.35
		local boreDepth = pipeRadius * 1.6
		-- The rolled lip: a ring round the open end, standing proud of the
		-- pipe wall and past its end, rounded at the front.
		local function lipSection(): { { number } }
			return {
				{ bore, -0.5 }, { lipOut, -0.5 }, { lipOut, 0.1 }, { lipOut - 0.08, 0.2 },
				{ bore + 0.08, 0.2 }, { bore, 0.1 },
			}
		end
		part(`Waste{name}`, nil, RUST, onIsland(function(mesh)
			prism(mesh, root, axis, side, up, circle(pipeRadius, 14), -pipeRadius * 3, length - boreDepth)
			sweep(mesh, 0, 360, 16, function()
				return { { bore, -boreDepth }, { wallOut, -boreDepth }, { wallOut, 0 }, { bore, 0 } }
			end)
			sweep(mesh, 0, 360, 16, lipSection)
			prism(mesh, root, axis, side, up, circle(pipeRadius * 1.3, 14), 0, 0.4)
		end), nil, scrapPaint)
		part(`WasteMouth{name}`, nil, { 0.04, 0.05, 0.03 }, onIsland(function(mesh)
			prism(mesh, mouth, axis, side, up, circle(bore, 14), -boreDepth, -boreDepth + 0.03)
		end), nil, 0)
		part(`Goo{name}`, nil, GOO, onIsland(function(mesh)
			-- A skin over the lower lip, following its section out round the
			-- front and down the outside, thickest at the bottom where it ran.
			sweep(mesh, 115, 245, 16, function(degrees: number)
				local weight = math.max(0, 1 - math.abs(degrees - 180) / 65)
				local skin = 0.015 + 0.13 * weight ^ 0.7 * (1 + 0.25 * math.sin(degrees * 0.3))
				local down = -0.15 - 0.45 * weight
				return {
					{ lipOut, down }, { lipOut + skin, down - skin }, { lipOut + skin, 0.1 },
					{ lipOut - 0.08 + skin * 0.7, 0.2 + skin }, { bore + 0.08 - skin * 0.7, 0.2 + skin },
					{ bore - skin, 0.1 }, { bore - skin, -0.4 }, { bore, -0.4 }, { bore, 0.1 },
					{ bore + 0.08, 0.2 }, { lipOut - 0.08, 0.2 }, { lipOut, 0.1 },
				}
			end)
			-- A puddle left in the bottom of the bore, its surface a little
			-- rippled, running out to the lip.
			local surface = -bore * 0.3
			local middle = (surface - bore) / 2
			local puddle = {}
			for k = 0, 12 do
				local a = math.rad(200 + 140 * k / 12)
				table.insert(puddle, { math.cos(a) * bore * 0.99, math.sin(a) * bore * 0.99 - middle })
			end
			for k = 1, 5 do
				local a = 1 - k / 6 * 2
				table.insert(puddle, { a * bore * 0.9, surface + 0.04 * math.sin(k * 2.1) - middle })
			end
			local pool = { mouth[1] + up[1] * middle, mouth[2] + up[2] * middle, mouth[3] + up[3] * middle }
			prism(mesh, pool, axis, side, up, puddle, -boreDepth, 0.12)
			-- The last drop, hanging from the skin under the lip: a sag, a thin
			-- neck, then the bead.
			local scale = pipeRadius / 1.5
			local lip = rim(180, lipOut + 0.1, -0.2)
			local drop = {
				{ 0, 0.3 }, { 0.25, 0.42 }, { 0.6, 0.32 }, { 0.95, 0.14 }, { 1.3, 0.09 },
				{ 1.6, 0.16 }, { 1.85, 0.27 }, { 2.1, 0.3 }, { 2.35, 0.24 }, { 2.55, 0.03 },
			}
			for _, ring in drop do
				ring[1] *= scale
				ring[2] *= scale
			end
			lathe(mesh, { lip[1], lip[2], lip[3] + 0.15 }, drop)
		end), nil, 0, nil, 0.8)
	end
	layPlumbing("Arena", 0, 0, 0, ARENA_ISLAND, floatingIsland(traced, ARENA_ISLAND, 42, 1, flat, octagon), 1)
	for k, padX in PAD_XS do
		layPlumbing(`Pad{k}`, padX, 0, 0, PAD_ISLAND, floatingIsland(traced, PAD_ISLAND, 20, 40 + k, flat, octagon), 40 + k)
	end
	layPlumbing("Market", MARKET_X, 0, 0, MARKET_ISLAND, floatingIsland(traced, MARKET_ISLAND, 30, 60, flat, octagon), 60)
	for i = 1, 2 * #PAD_XS do
		local side = if i % 2 == 1 then 1 else -1
		local wall = floatingIsland(traced, YARD_ISLAND, 22, 10 + i, yardLevel, yardOutline(10 + i))
		layPlumbing(`Yard{i}`, PAD_XS[(i + 1) // 2], side * YARD_OFFSET, 90 - side * 90, YARD_ISLAND, wall, 10 + i)
		layWastePipe(`Yard{i}`, PAD_XS[(i + 1) // 2], side * YARD_OFFSET, 90 - side * 90, YARD_ISLAND, wall, (10 + i) * 2.3 - 0.4)
	end
	local arenaWall = floatingIsland(traced, ARENA_ISLAND, 42, 1, flat, octagon)
	layWastePipe("Arena1", 0, 0, 0, ARENA_ISLAND, arenaWall, 2.3 - 0.4)
	layWastePipe("Arena2", 0, 0, 0, ARENA_ISLAND, arenaWall, 2.3 + math.pi - 0.4)
	for k, padX in PAD_XS do
		layWastePipe(`Pad{k}`, padX, 0, 0, PAD_ISLAND, floatingIsland(traced, PAD_ISLAND, 20, 40 + k, flat, octagon), (40 + k) * 2.3 - 0.4)
	end
	layWastePipe("Market", MARKET_X, 0, 0, MARKET_ISLAND, floatingIsland(traced, MARKET_ISLAND, 30, 60, flat, octagon), 60 * 2.3 - 0.4)
end, 0, 0)
