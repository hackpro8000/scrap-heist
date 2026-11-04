-- uses: ArenaDrone PadIsland MarketIsland YardIsland ShopConceptContainer ScrapTreeLamppost VendingMachine ParkBench ScrapPalm ShippingContainer CarStack CrushedCar Barrels TyreStack JunkWall Dumpster Pallets StreetlightBroken TrafficCones GroundTile MachinePad YardFence YardFenceHalf YardFooting YardGate PlotMarker StorageCrate YardPath YardPathStub
-- Server Map: one server's whole map, centered on the origin, built as
-- floating islands. The arena rides a hovering quadcopter in the middle, its
-- grating ring serving as the ring road round the bowl. A long gangway runs
-- east from the ring, clear of the propellers, to an avenue of four plaza
-- islands ending at the market island, and each plaza has a yard island off
-- either side, a tier higher, joined to it by a steel bridge sloping up to
-- the yard gate. The arena is the storm fight ground, banking up to the road
-- with no steps, and new players spawn round its crusher.
-- Each plot slab carries the Yard Layout template, placed piece by piece the
-- same way YardLayout.luau places it, so the map shows every yard set up.
-- Labels: ArenaDrone, Spawn, Beacon, Ramps, ArenaWall, Pad1-Pad4,
-- Avenue1-Avenue5, MarketIsland, Shop, Island1-Island8, Plot1-Plot8,
-- Yard1_<piece>-Yard8_<piece>, Spoke1-Spoke8, Bridge1-Bridge8,
-- Cover1-Cover8, Hatch1-Hatch4, Light1-Light4 and Cones1-Cones8.
-- Yard crates show empty, as in the Yard Layout template.
skipPart = function(name)
	return name:match("^Fill_") ~= nil
end

-- Every map part is textured at one density so nothing reads sharper or
-- blurrier than its neighbours. Props keep their own texture sizes.
local MAP_DENSITY = 16
useTexelDensity(MAP_DENSITY)

-- A placed model can set its own texel density while it builds, and it only
-- builds when it isn't cached, so the map's density is set again after each
-- one. Otherwise everything after it bakes at the model's density, or not,
-- depending on what happens to be cached.
-- `scale` builds it that many times its own size (see place()).
local function placeModel(label: string, build: () -> (), x: number, y: number, z: number?, turn: number?, scale: number?)
	place(label, build, x, y, z, turn, nil, nil, scale)
	useTexelDensity(MAP_DENSITY)
end

-- The arena is built 1.5 times the old island arena's size, as the yards
-- are, to match the drone's deck: the ring road is the drone's grating ring,
-- and the bowl its plating, from its rim at the road deck down to the floor.
local ARENA_SCALE = 1.5
local ROAD_INNER, ROAD_OUTER = 75, 90
local ARENA_FLOOR, ARENA_DEPTH = 54, 6.25
-- Width of the hazard stripes inlaid round the floor edge and up each ramp.
local HAZARD_WIDTH = 1.8 * ARENA_SCALE
-- Length of each yellow or black block in the bridges' hazard strips.
local HAZARD_BLOCK = 0.6
-- How far the yard island's grass reaches in front of the gate, where the
-- bridge lands, and how its island is turned under the yard (as in
-- YardLayout.luau) so the fence corners stand on its lobes. Its turf
-- stands 1.43 studs above its origin.
local YARD_ISLAND, YARD_ISLAND_TURN = 41, 305
-- The yard's pieces are laid out on a 32-stud plan and built this many
-- times their own size, as in YardLayout.luau.
local YARD_SCALE = 1.5
-- The ring road runs a little above the ground, the arena banking down to
-- the floor inside it and the bridges sloping up to the yards outside it.
local DECK = 2
local YARD_TIER = 6
-- The avenue's plaza pads, east of the road, and the yards either side. The
-- first stands far enough out that its yards clear the drone's propellers.
local PAD_XS = { 220, 332, 444, 556 }
local PAD_PLAZA = 11
local YARD_OFFSET = 84
-- The market island closes the avenue's east end.
local MARKET_X = 653
local MARKET_PLAZA = 30

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

-- Rock clumps: faceted columns stacked round an island's sides in tiers
-- that step inward, so the sides read as chunky masses split by deep
-- cracks. The top tier sits back under the rim, so the dirt cap overhangs
-- it. Each clump is recorded so islandPaint can light its edges and shade
-- the cracks between clumps.
export type Clump = { x: number, y: number, top: number, bottom: number, taper: number, corners: { { number } } }
local CLUMP_TIERS = { { reach = 0.9, from = 0.02, to = 0.42 }, { reach = 0.68, from = 0.3, to = 0.7 }, { reach = 0.42, from = 0.6, to = 1 } }
local CLUMP_BEVEL = 0.35
-- A clump's outline `down` of the way from its top to its bottom: it
-- tapers towards the bottom and pulls in at both bevels.
local function clumpOutline(clump: Clump, z: number): { { number } }
	local height = clump.top - clump.bottom
	local down = math.clamp((clump.top - z) / height, 0, 1)
	local scale = 1 + (clump.taper - 1) * down
	local fromEnd = math.min(clump.top - z, z - clump.bottom)
	if fromEnd < CLUMP_BEVEL then
		scale *= 1 - 0.3 * (1 - math.max(0, fromEnd) / CLUMP_BEVEL) * CLUMP_BEVEL / 1.2
	end
	local points = {}
	for k, corner in clump.corners do
		points[k] = { clump.x + corner[1] * scale, clump.y + corner[2] * scale }
	end
	return points
end
local function addClumps(mesh, radius: number, depth: number, seed: number, rimZ: number, wallRadius: (number, number) -> number, clumps: { Clump })
	local width = math.clamp(radius * 0.12, 3, 6)
	for tierIndex, tier in CLUMP_TIERS do
		local count = math.max(5, math.floor(2 * math.pi * radius * tier.reach / (width * 1.7)))
		for k = 1, count do
			local key = tierIndex * 97 + k
			local angle = 2 * math.pi * (k + 0.35 * math.noise(seed, key, 3)) / count
			local size = width * (0.8 + 0.5 * (math.noise(seed, key, 5) + 0.5))
			local top = if tierIndex == 1
				then rimZ - 0.6 - 2.2 * math.clamp(math.noise(seed, key, 7) + 0.5, 0, 1)
				else -depth * (tier.from + 0.12 * math.noise(seed, key, 7))
			local bottom = -depth * (tier.to + 0.15 * math.noise(seed, key, 11))
			if tierIndex == #CLUMP_TIERS then
				bottom -= depth * 0.15 * (math.noise(seed, key, 13) + 0.5)
			end
			-- Centred on the core wall at the clump's middle height, so about
			-- half of it stands proud of the wall.
			local reach = math.max(wallRadius(angle, (top + bottom) / 2) - size * 0.1, size)
			local corners = {}
			local sides = 5 + (seed + key) % 3
			local turn = math.noise(seed, key, 17) * math.pi
			for j = 1, sides do
				local a = turn + 2 * math.pi * (j + 0.25 * math.noise(seed, key * 7 + j, 19)) / sides
				local r = size * (0.85 + 0.3 * (math.noise(seed, key * 7 + j, 23) + 0.5))
				corners[j] = { math.cos(a) * r, math.sin(a) * r }
			end
			local clump = {
				x = math.cos(angle) * reach,
				y = math.sin(angle) * reach,
				top = top,
				bottom = bottom,
				taper = 0.55 + 0.25 * (math.noise(seed, key, 29) + 0.5),
				corners = corners,
			}
			table.insert(clumps, clump)
			-- Rings at the top, under the top bevel, over the bottom bevel and
			-- at the bottom, joined into a faceted column and capped.
			local rings = {}
			for r, z in { clump.top, clump.top - CLUMP_BEVEL, clump.bottom + CLUMP_BEVEL, clump.bottom } do
				rings[r] = {}
				for j, point in clumpOutline(clump, z) do
					rings[r][j] = mesh:vertex(point[1], point[2], z)
				end
			end
			for r = 1, 3 do
				for j = 1, sides do
					local l = j % sides + 1
					mesh:face({ rings[r][j], rings[r + 1][j], rings[r + 1][l], rings[r][l] })
				end
			end
			local topCap, bottomCap = {}, {}
			for j = 1, sides do
				table.insert(topCap, 1, rings[1][j])
				table.insert(bottomCap, rings[4][j])
			end
			mesh:face(topCap)
			mesh:face(bottomCap)
		end
	end
end

-- A floating island: a dirt top following `top`, over a rock underside that
-- tapers to a ragged point `depth` below. Rings run outward across the top,
-- then inward down the underside, so every face keeps the same winding.
local ISLAND_SIDES = 48
local UNDERSIDE_RINGS = 16
-- outline(angle) scales the radius around the edge; nil keeps it round.
local function floatingIsland(mesh, radius: number, depth: number, seed: number, top: (number, number) -> number, outline: ((number) -> number)?, creases: { number }?, clumps: { Clump }?)
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
	if clumps then
		-- The wall's distance from the middle at `angle` and height `z`, read
		-- off the rim and underside rows.
		local function wallRadius(angle: number, z: number): number
			local j = math.round(angle / (2 * math.pi) * ISLAND_SIDES) % ISLAND_SIDES
			for i = #fractions, #rows - 1 do
				local upper, lower = rows[i][j], rows[i + 1][j]
				if z >= lower[3] then
					local blend = math.clamp((upper[3] - z) / math.max(upper[3] - lower[3], 0.01), 0, 1)
					local above, below = math.sqrt(upper[1] ^ 2 + upper[2] ^ 2), math.sqrt(lower[1] ^ 2 + lower[2] ^ 2)
					return above + (below - above) * blend
				end
			end
			return radius * 0.03
		end
		addClumps(mesh, radius, depth, seed, rows[#fractions][0][3], wallRadius, clumps)
	end
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
-- How far (x, y) sits from a clump's outline at height z, and from its
-- nearest vertical edge.
local function clumpDistances(clump: Clump, x: number, y: number, z: number): (number, number)
	local points = clumpOutline(clump, z)
	local side, corner = math.huge, math.huge
	for k, a in points do
		local b = points[k % #points + 1]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local t = math.clamp(((x - a[1]) * dx + (y - a[2]) * dy) / (dx * dx + dy * dy), 0, 1)
		side = math.min(side, math.sqrt((x - a[1] - dx * t) ^ 2 + (y - a[2] - dy * t) ^ 2))
		corner = math.min(corner, math.sqrt((x - a[1]) ^ 2 + (y - a[2]) ^ 2))
	end
	return side, corner
end

-- Clumps get hard lit edges along their corners and top bevels, a shadow
-- under the bevel and dark contact shadows where they crowd a neighbour.
-- The core between them reads as deep crack. Clumps are in island space;
-- (originX, originY) is where the island sits in the paint's space. The
-- clump list fills while the island builds, so it is indexed on first use.
local CLUMP_CELL = 8
local EDGE_LIGHT = { 0.95, 0.82, 0.62 }
local function islandPaint(top: (number, number) -> number, clumps: { Clump }?, originX: number?, originY: number?)
	local cells
	local ox, oy = originX or 0, originY or 0
	local function indexClumps()
		cells = {}
		for _, clump in clumps or {} do
			local reach = 0
			for _, corner in clump.corners do
				reach = math.max(reach, math.abs(corner[1]), math.abs(corner[2]))
			end
			for cx = math.floor((clump.x - reach) / CLUMP_CELL), math.floor((clump.x + reach) / CLUMP_CELL) do
				for cy = math.floor((clump.y - reach) / CLUMP_CELL), math.floor((clump.y + reach) / CLUMP_CELL) do
					local key = cx * 4096 + cy
					cells[key] = cells[key] or {}
					table.insert(cells[key], clump)
				end
			end
		end
	end
	return function(x: number, y: number, z: number, _nx: number?, _ny: number?, nz: number?)
		local below = top(x, y) - z
		if below < 0.3 then
			local k = 1 + 0.12 * math.noise(x / 4, y / 4, 31) + 0.05 * math.noise(x * 3, y * 3, 37)
			return GROUND[1] * k, GROUND[2] * k, GROUND[3] * k
		end
		local shade, light = 1, 0
		if clumps then
			if not cells then indexClumps() end
			local lx, ly = x - ox, y - oy
			local nearest, nearSide, nearCorner, otherSide = nil, math.huge, math.huge, math.huge
			for _, clump in cells[math.floor(lx / CLUMP_CELL) * 4096 + math.floor(ly / CLUMP_CELL)] or {} do
				if z <= clump.top + 0.1 and z >= clump.bottom - 0.1 then
					local side, corner = clumpDistances(clump, lx, ly, z)
					if side < nearSide then
						otherSide = nearSide
						nearest, nearSide, nearCorner = clump, side, corner
					elseif side < otherSide then
						otherSide = side
					end
				end
			end
			if nearest and nearSide < 0.4 then
				local fromTop = nearest.top - z
				if fromTop < CLUMP_BEVEL + 0.15 or (nz or 0) > 0.5 then
					light = 0.75
				elseif nearCorner < 0.45 then
					light = 0.6 * (1 - nearCorner / 0.45)
				end
				if fromTop > CLUMP_BEVEL + 0.15 then
					shade *= 0.45 + 0.55 * math.clamp((fromTop - CLUMP_BEVEL - 0.15) / 1.2, 0, 1)
				end
				shade *= 0.35 + 0.65 * math.clamp((otherSide - 0.2) / 1.5, 0, 1)
				shade *= 0.55 + 0.45 * math.clamp((z - nearest.bottom) / 1.5, 0, 1)
				if (nz or 0) < -0.5 then shade *= 0.5 end
			elseif below > 1.2 then
				shade = 0.18
			end
		end
		local band = math.noise(x / 9, y / 9, z / 2) * 0.6 + z * 0.9
		local wave = math.sin(band * 2.4)
		local layer = STRATA[math.floor(band * 2.4 / (2 * math.pi)) % 3 + 1]
		local k = 1 + 0.1 * wave + 0.06 * math.noise(x * 2, y * 2, z * 2)
		if wave > 0.93 then k -= 0.25 end
		k *= 1 - 0.6 * math.clamp((below - 3) / 20, 0, 1)
		local soil = 1 - math.clamp((below - 1) / 1.5 + 0.3 * math.noise(x / 2, y / 2, 41), 0, 1)
		local r, g, b = layer[1] * k, layer[2] * k, layer[3] * k
		r, g, b = r + (TOPSOIL[1] - r) * soil, g + (TOPSOIL[2] - g) * soil, b + (TOPSOIL[3] - b) * soil
		r, g, b = r + (EDGE_LIGHT[1] - r) * light, g + (EDGE_LIGHT[2] - g) * light, b + (EDGE_LIGHT[3] - b) * light
		return r * shade, g * shade, b * shade
	end
end

local function flat(_x: number, _y: number): number
	return 0
end
local function yardLevel(_x: number, _y: number): number
	return YARD_TIER
end

-- Under a ring road the dirt dips out of sight, since the road is thinner
-- than the surface wobble and the dirt would otherwise poke through it.
local ROAD_SINK = 0.15

-- The arena drone is its own model, its deck's rim level with the road deck.
placeModel("ArenaDrone", buildArenaDrone, 0, 0, DECK)
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

-- Bridge deck: riveted steel tread plates laid across the span, with dark
-- seams, raised diamond treads worn smooth down the two wheel paths, and
-- grime and rust bleeding in from the edges. (The hazard strips are parts of
-- their own, laid on top; see bridge().) Painted in the bridge's own frame so
-- every bridge wears the same way along its length. `flareAt` says how far the
-- railings have flared at each point along it, and the edges flare with them.
local function bridgeDeck(degrees: number, cx: number, cy: number, flareAt: (number) -> number)
	local angle = math.rad(degrees - 90)
	local c, s = math.cos(angle), math.sin(angle)
	return function(x: number, y: number, _z: number)
		local u = (x - cx) * c + (y - cy) * s
		local v = (y - cy) * c - (x - cx) * s
		local flare = flareAt(v)
		local edge = 3 + 0.5 * flare - math.abs(u)
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



-- The arena edge stands out from the yards around it: hazard stripes ring the
-- fight floor, and a low concrete wall with yellow caps tops the bowl,
-- broken where each spoke comes in.
-- The ramp lane, with a hazard strip outside it on each side.
local LANE_HALF = 3.6 * ARENA_SCALE
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


-- A plaza: an asphalt octagon at deck level on its own floating island,
-- kerbed round the edge except where a bridge lands on one of its sides.
-- The dirt dips just under the asphalt, as it does under the ring road.
-- `turf` is how far the island's grass stands above its origin, and `turn`
-- turns its lobes under the plaza's corners.
local function plazaIsland(label: string, x: number, y: number, buildIsland: () -> (), turf: number, turn: number, plaza: number, seed: number, openings: { number })
	-- The grass sits 0.2 under the plaza so the floor never z-fights it.
	place(`{label}Rock`, buildIsland, x, y, DECK - 0.2 - turf, turn)
	slab(label, function()
		-- Chunked, so the market's wide plaza and its long kerb ring keep the
		-- map's texel density instead of stretching one capped texture.
		chunkedPart("Plaza", nil, ROAD, function(mesh)
			arc(mesh, 0, plaza, DECK - 0.6, DECK, 0, 360, true)
		end, nil, function(px, py)
			return asphalt(px - x, py - y, 40, seed + 50)
		end, true)
		-- Each run ends inside a bridge end post, 3.5 off the bridge's middle
		-- halfway across the kerb, on the octagon's flat side.
		local gap = math.deg(math.atan(3.5 / (plaza + 0.2)))
		chunkedPart("Kerb", nil, CONCRETE, function(mesh)
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

-- Builds into a mesh grown `scale` times about the point (0, 0, z0), so a
-- piece of the old island arena can be built at the drone arena's size.
local function grown(mesh, scale: number, z0: number)
	return setmetatable({
		vertex = function(_, x, y, z)
			return mesh:vertex(x * scale, y * scale, z0 + (z - z0) * scale)
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

-- The arena's pieces stand on the drone's floor plating. New players start
-- on a ring round the crusher.
slab("Spawn", function()
	part("Pad", nil, MARK, function(mesh)
		ring(mesh, 0, 0, 0.2 - ARENA_DEPTH, 6.5 * ARENA_SCALE, 8.5 * ARENA_SCALE, 0.1, "z", 32)
	end, nil, 0)
end, 0, 0)

-- The storm beacon: a mast with a glowing core that lights up when a storm
-- round starts, visible from every yard. Built at the old arena's size and
-- grown to the drone arena's.
local MAST_TOP = 24
local STORM_GLOW = { 0.35, 0.85, 1 }
slab("Beacon", function()
	local floor = 0.1 - ARENA_DEPTH
	part("Plinth", nil, CONCRETE, function(base)
		local mesh = grown(base, ARENA_SCALE, floor)
		cylinder(mesh, 0, 0, floor + 0.6, 4.5, 1.2, "z", 8)
		cylinder(mesh, 0, 0, floor + 1.5, 3.4, 0.6, "z", 8)
	end, nil, 0.5)
	part("PlinthStripe", nil, MARK, function(base)
		local mesh = grown(base, ARENA_SCALE, floor)
		ring(mesh, 0, 0, floor + 1.15, 4.4, 4.55, 0.25, "z", 8)
	end, nil, 0.3)
	-- Four straight legs leaning in towards the top, tied together with braces.
	part("Mast", nil, DARK_STEEL, function(base)
		local mesh = grown(base, ARENA_SCALE, floor)
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
	part("CoreMount", nil, STEEL, function(base)
		local mesh = grown(base, ARENA_SCALE, floor)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 0.3, 1.9, 0.6, "z", 16)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 4.25, 1.9, 0.5, "z", 16)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 6.5, 0.15, 4, "z", 8)
	end, nil, 0.2)
	-- The core sits on top of the mast and is the part that glows during a storm.
	part("Core", nil, STORM_GLOW, function(base)
		local mesh = grown(base, ARENA_SCALE, floor)
		cylinder(mesh, 0, 0, floor + MAST_TOP + 2.3, 1.4, 3.4, "z", 16)
	end, nil, 0, nil, 1)
	part("CoreCage", nil, DARK_STEEL, function(base)
		local mesh = grown(base, ARENA_SCALE, floor)
		for k = 0, 5 do
			local angle = math.rad(k * 60)
			box(mesh, math.cos(angle) * 1.65, math.sin(angle) * 1.65, floor + MAST_TOP + 0.6, 0.2, 0.2, 3.4)
		end
	end, nil, 0.3)
end, 0, 0)

-- Entry ramps down the bank at every spoke, with hazard stripes either side
-- and round the mouth of each. Each part spans all eight spokes, so it is
-- chunked rather than stretching one texture across the arena.
slab("Ramps", function()
	chunkedPart("Deck", nil, CONCRETE, function(mesh)
		for i = 1, 8 do
			rampBlock(mesh, (i - 1) * 45, { ARENA_FLOOR - HAZARD_WIDTH, ARENA_FLOOR, ROAD_INNER }, -LANE_HALF, LANE_HALF, 0)
		end
	end, nil, 0.25)
	for k, color in { MARK, { 0.08, 0.08, 0.08 } } do
		chunkedPart(if k == 1 then "RampStripeYellow" else "RampStripeBlack", nil, color, function(mesh)
			for i = 1, 8 do
				for s = k, #STRIP_BREAKS - 1, 2 do
					local radii = { STRIP_BREAKS[s], STRIP_BREAKS[s + 1] }
					rampBlock(mesh, (i - 1) * 45, radii, -RAMP_HALF, -LANE_HALF, 0)
					rampBlock(mesh, (i - 1) * 45, radii, LANE_HALF, RAMP_HALF, 0)
				end
				-- Ring pieces, black-yellow-black from the mouth to the corner.
				local ring = { ARENA_FLOOR - HAZARD_WIDTH, ARENA_FLOOR }
				local cuts = { RAMP_HALF, RAMP_HALF + 3.2 * ARENA_SCALE, RAMP_HALF + 6.4 * ARENA_SCALE, 99 }
				for s = 3 - k, 3, 2 do
					rampBlock(mesh, (i - 1) * 45, ring, cuts[s], cuts[s + 1], 0)
					rampBlock(mesh, (i - 1) * 45, ring, -cuts[s + 1], -cuts[s], 0)
				end
			end
		end, nil, 0.2)
	end
end, 0, 0)

-- The arena wall runs along each octagon side in two halves, one each side
-- of the spoke, along the top of the bank just inside the road. A half
-- starts square at `near` across the spoke, where it meets the ramp's hazard
-- strip, and ends mitred at the octagon corner.
local WALL_INNER, WALL_OUTER = ROAD_INNER - 1.8, ROAD_INNER - 0.6
-- Its foot sinks into the bank; its top stands about waist high (1.9) over
-- the road deck.
local WALL_BOTTOM, WALL_TOP = DECK - 0.8, DECK + 1.9
local function wallRun(mesh, degrees: number, side: number, inner: number, outer: number, near: number, bottom: number, top: number)
	local angle = math.rad(degrees)
	local c, n = math.cos(angle), math.sin(angle)
	local corner = math.tan(math.rad(22.5))
	-- Footprint counter-clockwise seen from above.
	local footprint = { { inner, near }, { outer, near }, { outer, outer * corner }, { inner, inner * corner } }
	if side < 0 then
		footprint = { { inner, -inner * corner }, { outer, -outer * corner }, { outer, -near }, { inner, -near } }
	end
	local low, high = {}, {}
	for k, p in footprint do
		local x, y = c * p[1] - n * p[2], n * p[1] + c * p[2]
		low[k] = mesh:vertex(x, y, bottom)
		high[k] = mesh:vertex(x, y, top)
	end
	mesh:face({ high[1], high[2], high[3], high[4] })
	mesh:face({ low[4], low[3], low[2], low[1] })
	for k = 1, 4 do
		local l = k % 4 + 1
		mesh:face({ low[k], low[l], high[l], high[k] })
	end
end
-- A low concrete wall with a yellow cap round the top of the bowl, broken
-- where each ramp comes in. Chunked, as it rings the whole arena.
slab("ArenaWall", function()
	chunkedPart("Wall", nil, CONCRETE, function(mesh)
		for i = 1, 8 do
			for _, side in { -1, 1 } do
				wallRun(mesh, (i - 1) * 45, side, WALL_INNER, WALL_OUTER, RAMP_HALF, WALL_BOTTOM, WALL_TOP)
			end
		end
	end, nil, 0.4)
	chunkedPart("WallCap", nil, MARK, function(mesh)
		for i = 1, 8 do
			for _, side in { -1, 1 } do
				wallRun(mesh, (i - 1) * 45, side, WALL_INNER - 0.1, WALL_OUTER + 0.1, RAMP_HALF - 0.1, WALL_TOP, WALL_TOP + 0.15)
			end
		end
	end, nil, 0.3)
end, 0, 0)
-- A straight block `width` wide from (ax, ay) to (bx, by), its bottom and
-- top heights at each end given as { bottom, top }, so it can slope.
local function upstand(mesh, ax: number, ay: number, bx: number, by: number, width: number, aHeights: { number }, bHeights: { number })
	local dx, dy = bx - ax, by - ay
	local length = math.sqrt(dx * dx + dy * dy)
	local px, py = -dy / length * width / 2, dx / length * width / 2
	-- Each end's corners: right bottom, left bottom, left top, right top.
	local function corners(x: number, y: number, heights: { number })
		return {
			mesh:vertex(x - px, y - py, heights[1]),
			mesh:vertex(x + px, y + py, heights[1]),
			mesh:vertex(x + px, y + py, heights[2]),
			mesh:vertex(x - px, y - py, heights[2]),
		}
	end
	local a, b = corners(ax, ay, aHeights), corners(bx, by, bHeights)
	mesh:face({ a[4], b[4], b[3], a[3] })
	mesh:face({ a[2], b[2], b[1], a[1] })
	mesh:face({ a[1], b[1], b[4], a[4] })
	mesh:face({ a[2], a[3], b[3], b[2] })
	mesh:face({ a[1], a[4], a[3], a[2] })
	mesh:face({ b[1], b[2], b[3], b[4] })
end
-- A steel bridge on spoke `degrees`, placed at (x, y) and turned so local +y
-- runs along it, from its low end at `to` (on deck level) to its far end at
-- `from`, which climbs to `highZ`. Every part is built flat and then sheared
-- up along its length, so posts stay upright and the end pieces sit level at
-- their own tier. A yard end lands on an apron under a gate frame; at any
-- other end the railings flare out to the kerb ends and stop at end posts.
-- `droneEnd` says the low end lands on the arena drone's rim, which carries
-- it, so that end needs no concrete seat.
local function bridge(label: string, x: number, y: number, degrees: number, from: number, to: number, highZ: number, yardEnd: boolean, droneEnd: boolean?)
	local middle, length = (from + to) / 2, from - to
	local function lift(py: number): number
		return DECK + (highZ - DECK) * math.clamp((py - to) / length, 0, 1)
	end
	local function bridgePart(name: string, color, build: (any) -> (), paint, flat: boolean?)
		part(name, nil, color, function(mesh)
			build({
				vertex = function(_, vx, vy, vz)
					return mesh:vertex(vx, vy, vz + lift(vy))
				end,
				face = function(_, corners)
					return mesh:face(corners)
				end,
			})
		end, nil, paint, nil, nil, flat)
	end
	local postCount = math.ceil((length - 0.3) / 2.5)
	local postGap = (length - 0.3) / postCount
	local flareFrom = if yardEnd then from - 0.1 else from - 0.15 - postGap
	local flareTo = to + 0.15 + postGap
	-- Where the railings flare: each end at `edge`, its rails running
	-- inward along +y (`inward` 1) or -y (-1) from the end post.
	local flares = { { to, 1, flareTo } }
	if not yardEnd then
		table.insert(flares, { from, -1, flareFrom })
	end
	local function endPostAt(edge: number, inward: number): number
		return edge + inward * 0.2
	end
	-- How far the railings have flared at `py`: 0 between the flares, 1 at
	-- the end posts and beyond.
	local function flareAt(py: number): number
		local amount = math.clamp((flareTo - py) / (flareTo - endPostAt(to, 1)), 0, 1)
		if yardEnd then
			return amount
		end
		return math.max(amount, math.clamp((py - flareFrom) / (endPostAt(from, -1) - flareFrom), 0, 1))
	end
	-- The deck's top at `py`, above the bridge's line: level along the span,
	-- ramping down over the last stud at a kerb end.
	local function topAt(py: number): number
		local inFromEdge = if yardEnd then py - to else math.min(py - to, from - py)
		return 0.1 * math.clamp(inFromEdge, -0.4, 1)
	end
	slab(label, function()
		-- Steel decking that widens with the railings where they flare, so it
		-- runs under the upstands out to the kerb ends. At a kerb end its top
		-- ramps down to the plaza over the last stud and runs on just under
		-- it, so the walk off the bridge has no lip. Left unwarped so the
		-- walking surface and its seam with the plaza stay true. Built as
		-- rows of vertices across the deck at each station along it.
		bridgePart("Deck", STEEL, function(mesh)
			local stations = { to - 0.4, to, endPostAt(to, 1), to + 1 }
			for n = 0, 8 do
				table.insert(stations, flareTo + (flareFrom - flareTo) * n / 8)
			end
			if yardEnd then
				table.insert(stations, from)
			else
				for _, py in { from - 1, endPostAt(from, -1), from, from + 0.4 } do
					table.insert(stations, py)
				end
			end
			local top, bottom = {}, {}
			for k, py in stations do
				local half = 3 + 0.5 * flareAt(py)
				top[k], bottom[k] = {}, {}
				for i = 0, 8 do
					local px = -half + half * i / 4
					top[k][i] = mesh:vertex(px, py, topAt(py))
					bottom[k][i] = mesh:vertex(px, py, -0.2)
				end
			end
			local last = #stations
			for k = 1, last - 1 do
				for i = 0, 7 do
					mesh:face({ top[k][i], top[k][i + 1], top[k + 1][i + 1], top[k + 1][i] })
					mesh:face({ bottom[k][i], bottom[k + 1][i], bottom[k + 1][i + 1], bottom[k][i + 1] })
				end
				mesh:face({ bottom[k][8], bottom[k + 1][8], top[k + 1][8], top[k][8] })
				mesh:face({ bottom[k][0], top[k][0], top[k + 1][0], bottom[k + 1][0] })
			end
			for i = 0, 7 do
				mesh:face({ bottom[1][i], bottom[1][i + 1], top[1][i + 1], top[1][i] })
				mesh:face({ bottom[last][i], top[last][i], top[last][i + 1], bottom[last][i + 1] })
			end
		end, bridgeDeck(degrees, x, y, flareAt), true)
		-- Hazard strips along both outer plates: blocks of yellow and black laid
		-- just proud of the deck, each colour its own part so the blocks stay
		-- crisp and even. They run from end post to end post and step out with
		-- the railings where they flare.
		local first = endPostAt(to, 1)
		local last = if yardEnd then from - 0.1 else endPostAt(from, -1)
		local blocks = math.max(1, math.round((last - first) / HAZARD_BLOCK))
		for k, colour in { MARK, { 0.08, 0.08, 0.08 } } do
			bridgePart(if k == 1 then "HazardYellow" else "HazardBlack", colour, function(mesh)
				for n = k - 1, blocks - 1, 2 do
					local a = first + (last - first) * n / blocks
					local b = first + (last - first) * (n + 1) / blocks
					for _, side in { -1, 1 } do
						local corners = {}
						for i, py in { a, b } do
							local out = 0.6 * flareAt(py)
							local z = topAt(py) + 0.015
							corners[i] = { side * (2.2 + out), side * (2.7 + out), py, z }
						end
						-- A thin block: its top, and the four sides down to the deck.
						local top, base = {}, {}
						for i, corner in { corners[1], corners[2] } do
							local inner, outer, py, z = corner[1], corner[2], corner[3], corner[4]
							top[i * 2 - 1] = mesh:vertex(inner, py, z)
							top[i * 2] = mesh:vertex(outer, py, z)
							base[i * 2 - 1] = mesh:vertex(inner, py, z - 0.03)
							base[i * 2] = mesh:vertex(outer, py, z - 0.03)
						end
						local quads = {
							{ top[1], top[2], top[4], top[3] },
							{ base[1], base[2], top[2], top[1] },
							{ base[4], base[3], top[3], top[4] },
							{ base[2], base[4], top[4], top[2] },
							{ base[3], base[1], top[1], top[3] },
						}
						for _, quad in quads do
							-- The left side mirrors the right, so it winds the other way.
							mesh:face(if side > 0 then quad else { quad[4], quad[3], quad[2], quad[1] })
						end
					end
				end
			end, 0.1, true)
		end
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
		-- on a base plate and capped. A flared end trades its last post for
		-- an end post out at the kerb end.
		bridgePart("Posts", STEEL, function(mesh)
			for _, side in { -2.9, 2.9 } do
				for n = 1, if yardEnd then postCount else postCount - 1 do
					local at = to + 0.15 + n * postGap
					box(mesh, side, at, -0.05, 0.36, 0.36, 0.06)
					box(mesh, side, at, 0.01, 0.14, 0.14, 1.27)
					box(mesh, side, at, 1.28, 0.2, 0.2, 0.06)
				end
			end
		end, 0.4)
		-- Handrail on top, a thinner mid rail and a kick plate at the deck,
		-- straight between the flares, then angled out to the end posts.
		bridgePart("Rail", MARK, function(mesh)
			local straight, span = (flareFrom + flareTo) / 2, flareFrom - flareTo
			for _, side in { -2.9, 2.9 } do
				local out = math.sign(side)
				box(mesh, side, straight, 1.16, 0.16, span, 0.12)
				box(mesh, side, straight, 0.62, 0.08, span, 0.08)
				box(mesh, side + out * 0.1, straight, -0.05, 0.04, span, 0.22)
				for _, flare in flares do
					local edge, inward, start = flare[1], flare[2], flare[3]
					local postY = endPostAt(edge, inward)
					strut(mesh, side, start, 1.22, out * 3.5, postY, 1.22, 0.14)
					strut(mesh, side, start, 0.66, out * 3.5, postY, 0.66, 0.08)
				end
			end
		end, 0.3)
		-- The kerb wraps round each end: a block over the kerb end, then an
		-- upstand under the flared rail that sinks into the deck where the
		-- flare starts, so the railing grows out of the kerb.
		bridgePart("KerbEnds", CONCRETE, function(mesh)
			for _, side in { -2.9, 2.9 } do
				local out = math.sign(side)
				for _, flare in flares do
					local postY = endPostAt(flare[1], flare[2])
					box(mesh, out * 3.5, postY, -0.6, 0.7, 0.7, 0.9)
					upstand(mesh, out * 3.5, postY, side, flare[3], 0.4, { -0.6, 0.3 }, { -0.2, 0.1 })
				end
			end
		end, 0.5)
		-- End posts: heavy dark steel standing on the kerb ends, each bolted
		-- down on a base plate and capped with a broad plate, so the railing
		-- reads as ending.
		bridgePart("EndPosts", DARK_STEEL, function(mesh)
			for _, side in { -3.5, 3.5 } do
				for _, flare in flares do
					local postY = endPostAt(flare[1], flare[2])
					box(mesh, side, postY, 0.3, 0.6, 0.6, 0.06)
					box(mesh, side, postY, 0.36, 0.4, 0.4, 1.04)
					box(mesh, side, postY, 1.4, 0.52, 0.52, 0.1)
				end
			end
		end, 0.4)
		-- Each island end rests on a concrete seat set into the island edge,
		-- its top clear of the island's rock top (0.2 under the deck) so the
		-- rock never shows through. A yard end adds a low wing wall either side
		-- for the yard edge to end against; a kerb ends inside an end post.
		bridgePart("Abutments", CONCRETE, function(mesh)
			for _, ends in { { to, -1 }, { from, 1 } } do
				local edge, land = ends[1], ends[2]
				if land == -1 and droneEnd then
					continue
				end
				box(mesh, 0, edge + land * 0.75, -3, 7.3, 3.5, 2.92)
				if land == 1 and yardEnd then
					for _, side in { -3.4, 3.4 } do
						box(mesh, side, edge - land * 0.5, -3, 0.5, 1, 3.45)
					end
				end
			end
		end, 0.5)
		-- A yard end lands on its apron with a steel plate over the joint.
		if not yardEnd then return end
		bridgePart("JointPlate", STEEL, function(mesh)
			box(mesh, 0, from, 0.1, 6, 0.8, 0.04)
		end, 0.3, true)
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

-- Lumpy outlines that never cut into a 32-stud plot's corners (0.9 * 26
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
	local function piece(name: string, build: () -> (), px: number, py: number, pz: number?, pturn: number?, stretch: number?)
		px, py = px * YARD_SCALE, py * YARD_SCALE
		local pieceZ = (pz or 0) * YARD_SCALE + YARD_TIER
		place(`Yard{index}_{name}`, build, x + px * c - py * s, y + px * s + py * c, pieceZ, turn + (pturn or 0), stretch, nil, YARD_SCALE)
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
		piece(`FootingBack{i}`, buildYardFooting, f, 16)
		piece(`FootingLeft{i}`, buildYardFooting, -16, f, 0, 90)
		piece(`FootingRight{i}`, buildYardFooting, 16, f, 0, 90)
	end
	for i, side in { -1, 1 } do
		piece(`FenceFront{i}`, buildYardFence, side * 8, -16)
		piece(`FenceFrontHalf{i}`, buildYardFenceHalf, side * 14, -16)
		piece(`FootingFront{i}`, buildYardFooting, side * 8, -16)
		piece(`FootingFrontHalf{i}`, buildYardFooting, side * 14, -16, 0, 0, 0.5)
	end
	piece("Gate", buildYardGate, 0, -16)
	piece("PlotMarker", buildPlotMarker, 6, -17.5)
end

-- The avenue: a row of plaza islands running east from the arena, each with
-- a yard off either side, joined to the ring road, to each other and to the
-- market at the far end by flat bridges.
for k, padX in PAD_XS do
	plazaIsland(`Pad{k}`, padX, 0, buildPadIsland, 0.71, 340, PAD_PLAZA, 40 + k, { 0, 90, 180, 270 })
	local from = if k == 1 then ROAD_OUTER else PAD_XS[k - 1] + PAD_PLAZA
	bridge(`Avenue{k}`, from, 0, 0, padX - PAD_PLAZA - from, 0, DECK, false, k == 1)
end
plazaIsland("MarketIsland", MARKET_X, 0, buildMarketIsland, 1.7, 335, MARKET_PLAZA, 60, { 180 })
local lastPad = PAD_XS[#PAD_XS] + PAD_PLAZA
bridge(`Avenue{#PAD_XS + 1}`, lastPad, 0, 0, MARKET_X - MARKET_PLAZA - lastPad, 0, DECK, false)

-- The market's shop on the plaza's east side, its front (local -y) toward the
-- middle. Local +y points away from the middle. Its shell is built small, so
-- it grows to a real 20-foot container a player walks into.
local SHOP_SCALE = 2.5
local shopX, shopY = polar(MARKET_PLAZA - 6, 0)
placeModel("Shop", buildShopConceptContainer, MARKET_X + shopX, shopY, DECK, -90, SHOP_SCALE)
-- Trees stand in concrete planters full of soil, their roots down in the soil.
-- Trees and planters grow together to stand well over the players.
local TREE_SCALE = 1.5
local PLANTER_TOP = DECK + TREE_SCALE
local DIRT = { 0.22, 0.16, 0.1 }
local function plantTree(label: string, build: () -> (), x: number, y: number, turn: number)
	slab(`{label}Planter`, function()
		part("Box", nil, CONCRETE, function(mesh)
			box(mesh, 0, 0, DECK, 3.4 * TREE_SCALE, 3.4 * TREE_SCALE, TREE_SCALE)
		end, nil, 0.5)
		part("Soil", nil, DIRT, function(mesh)
			box(mesh, 0, 0, PLANTER_TOP - 0.2, 3 * TREE_SCALE, 3 * TREE_SCALE, 0.3)
		end, nil, 0.8)
	end, MARKET_X + x, y)
	place(label, build, MARKET_X + x, y, PLANTER_TOP - 0.1, turn, nil, nil, TREE_SCALE)
end
-- Plaza dressing: a scrap-tree lamppost off to the north so the walk in from
-- the bridge looks straight at the shop, a vending machine and bench by the
-- shop, and palms at the west corners clear of the bridge.
plantTree("Landmark", buildScrapTreeLamppost, 0, 14, 0)
place("Vending", buildVendingMachine, MARKET_X + 10, -9, DECK, -90, nil, nil, 2)
place("Bench", buildParkBench, MARKET_X + 10, 9, DECK, -90, nil, nil, 1.85)
for i, degrees in { 135, -135 } do
	local x, y = polar(MARKET_PLAZA - 5, degrees)
	plantTree(`Palm{i}`, buildScrapPalm, x, y, 0)
end

-- Each yard island is turned so its gate (local -y) faces its pad. A short
-- road runs from the gate to the island edge, and a steel bridge carries it
-- across the gap, sloping up from the pad to the yard tier.
local BRIDGE_FROM, BRIDGE_TO = -YARD_ISLAND, -(YARD_OFFSET - PAD_PLAZA)
for i = 1, 2 * #PAD_XS do
	local side = if i % 2 == 1 then 1 else -1
	local degrees = 180 - side * 90
	local x, y = PAD_XS[(i + 1) // 2], side * YARD_OFFSET
	place(`Island{i}`, buildYardIsland, x, y, YARD_TIER - 1.43, degrees - 90 + YARD_ISLAND_TURN)
	slab(`Plot{i}`, function()
		part("Slab", nil, PLOT, function(mesh)
			box(mesh, 0, 0, YARD_TIER, 32 * YARD_SCALE, 32 * YARD_SCALE, 0.05)
		end, nil, 0)
	end, x, y, degrees - 90)
	yardTemplate(i, x, y, degrees - 90)
	local c, s = math.cos(math.rad(degrees - 90)), math.sin(math.rad(degrees - 90))
	slab(`Spoke{i}`, function()
		part("Road", nil, ROAD, function(mesh)
			box(mesh, 0, -(16 * YARD_SCALE + YARD_ISLAND) / 2, YARD_TIER, 6, YARD_ISLAND - 16 * YARD_SCALE, 0.1)
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
	place(`Cones{i}`, buildTrafficCones, coneX, coneY, heightAt(coneX, coneY), degrees, nil, nil, 1.8)
end

-- Cover for the storm fights, offset from the spokes so paths stay open.
-- The props are built about half real size; each grows to its real size
-- beside a 5.5-stud-tall player (a 20-foot container stands 7.8 tall).
local COVER = {
	{ buildShippingContainer, 1.5 },
	{ buildCarStack, 2.5 },
	{ buildCrushedCar, 2.5 },
	{ buildBarrels, 1.9 },
	{ buildTyreStack, 1.8 },
	{ buildJunkWall, 1.75 },
	{ buildDumpster, 2.2 },
	{ buildPallets, 1.4 },
}
for i, cover in COVER do
	local degrees = (i - 0.5) * 45
	local x, y = polar(26 * ARENA_SCALE, degrees)
	placeModel(`Cover{i}`, cover[1], x, y, 0.2 - ARENA_DEPTH, degrees + 90, cover[2])
end
-- Bot spawn hatches in the arena floor, inside the cover ring between the spokes.
-- Storm bots climb out of these; the hazard rim marks where they emerge.
for i = 1, 4 do
	local degrees = (i - 0.75) * 90
	local x, y = polar(17 * ARENA_SCALE, degrees)
	slab(`Hatch{i}`, function()
		local floor = 0.1 - ARENA_DEPTH
		part("Rim", nil, MARK, function(base)
			local mesh = grown(base, ARENA_SCALE, floor)
			ring(mesh, 0, 0, floor, 2.6, 3.1, 0.12, "z", 24)
		end, nil, 0.3)
		part("Frame", nil, DARK_STEEL, function(base)
			local mesh = grown(base, ARENA_SCALE, floor)
			ring(mesh, 0, 0, floor, 2.1, 2.6, 0.2, "z", 24)
		end, nil, 0.5)
		part("Pit", nil, { 0.05, 0.05, 0.05 }, function(base)
			local mesh = grown(base, ARENA_SCALE, floor)
			cylinder(mesh, 0, 0, floor - 0.05, 2.1, 0.1, "z", 24)
		end, nil, 0)
		part("Grate", nil, STEEL, function(base)
			local mesh = grown(base, ARENA_SCALE, floor)
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
	place(`Light{i}`, buildStreetlightBroken, x, y, heightAt(x, y), degrees + 90, nil, nil, 2)
end
