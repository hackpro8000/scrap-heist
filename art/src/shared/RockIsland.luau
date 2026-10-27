-- Rock Island: the shared generator behind Yard, Pad and Market Island.
-- The item sets RADIUS and outlineScale(angle) before including this.
useTexelDensity(16)

-- The wall is a staircase of rock tiers stepping in as it goes down, ending
-- on a flat underside. The top tier is tall and built of big chunks; each
-- tier below is shorter, built of smaller rocks, and steps in by half as far
-- as the one above, so the staircase bows inward and levels out. Within a
-- tier the rocks are packed edge to edge: each is a cell of a jittered grid
-- laid round the tier, owning the points nearer its centre than any other,
-- so the outlines are random but every edge is shared with a neighbour. The
-- underside is covered the same way on a polar grid, its rocks hanging below
-- the flat base. A rock stands proud of its face as a faceted boss whose
-- edges bevel down to a tight seam.
local CAP_TOP = 0.7
local WALL_REACH = 0.86
local TIERS = 9
-- The top tier's height, its rock size, the share of the reach the staircase
-- levels out at, and how much each step in is shorter than the one above.
local TIER_HEIGHT, HEIGHT_SHRINK = 4, 0.78
local ROCK, ROCK_SHRINK, ROCK_MIN = 2.4, 0.8, 0.9
local UNDERSIDE_SHARE, STEP_SHRINK = 0.4, 0.5
-- The underside's rings run in from the rim to UNDERSIDE_CENTRE of its
-- radius, then close on a flat centre, so the rings don't crowd the axis.
local UNDERSIDE_RINGS, UNDERSIDE_CENTRE = 12, 0.3
-- How far a tier's floor wanders round the island, and how much its face
-- leans in from top to bottom.
local FLOOR_WANDER, BATTER = 0.35, 0.03
-- How far a rock's centre strays from its cell, along and down the tier.
local JITTER_ALONG, JITTER_DOWN = 0.38, 0.3
-- How proud a rock stands, a minimum plus a random spread; bigger rocks
-- stand prouder in proportion to their size.
local PROUD_MIN, PROUD_SPREAD = 0.4, 0.35
-- Rock sizes vary wildly: each rock's size is the tier's size times
-- e^(SIZE_SPREAD * r) for r from -1 to 1, so a boulder can be several
-- times the size of a pebble beside it.
local SIZE_SPREAD = 0.95
-- Each rock's face is cut into FACETS planes falling away at FACET_SLOPE,
-- then bevelled down to the seam at BEVEL, chipped by up to CHIP.
local FACETS, FACET_SLOPE, TILT = 5, 0.3, 0.12
local BEVEL, CHIP = 1.6, 0.15

local GIRTH = RADIUS * WALL_REACH
local UNDERSIDE_RADIUS = GIRTH * UNDERSIDE_SHARE

-- Each tier's nominal top and floor, its share of the outline's reach, and
-- the grid its rocks sit on. Each step in is measured from the underside, so
-- the staircase closes in on it.
local tiers = {}
do
	local top, share, height, size = CAP_TOP, 1, TIER_HEIGHT, ROCK
	for k = 1, TIERS do
		local rows = math.max(1, math.round(height / size))
		local columns = math.max(3, math.round(TAU * GIRTH * share / size))
		tiers[k] = {
			index = k,
			top = top,
			floor = top - height,
			share = share,
			size = size,
			rows = rows,
			rowHeight = height / rows,
			columnsAt = function(_j: number): number return columns end,
			rocks = {},
		}
		top -= height
		share = UNDERSIDE_SHARE + (share - UNDERSIDE_SHARE) * STEP_SHRINK
		height *= HEIGHT_SHRINK
		size = math.max(size * ROCK_SHRINK, ROCK_MIN)
	end
end

-- The flat underside: rings of rocks on a polar grid, ring 0 at the rim.
local underside
do
	local size = tiers[TIERS].size
	local rows = math.max(1, math.round(UNDERSIDE_RADIUS / size))
	local rowHeight = UNDERSIDE_RADIUS / rows
	underside = {
		index = 0,
		rows = rows,
		rowHeight = rowHeight,
		size = size,
		columnsAt = function(j: number): number
			local radius = UNDERSIDE_RADIUS - (j + 0.5) * rowHeight
			return math.max(3, math.round(TAU * radius / size))
		end,
		rocks = {},
	}
end

-- Where tier k's floor actually runs at `angle`.
local function floorAt(k: number, angle: number): number
	local tier = tiers[k]
	local wander = FLOOR_WANDER * math.min(1, (tier.top - tier.floor) / 2)
	return tier.floor + wander * math.noise(math.cos(angle) * 1.1, math.sin(angle) * 1.1, k * 3.1)
end

-- The tier at height z and `angle`, with its floor and top there, or nil
-- below the last tier.
local function tierAt(z: number, angle: number)
	local top = CAP_TOP
	for k = 1, TIERS do
		local floor = floorAt(k, angle)
		if z >= floor then return k, floor, top end
		top = floor
	end
	return nil
end

-- The rock at column i and row j of `tier`: its angle round the island and
-- centre down the tier, and the facets, tilt, height and tint of its face.
-- Odd rows sit half a column over so the rocks bond like a wall.
local function rockAt(tier, i: number, j: number)
	local key = j * 4096 + i
	local rock = tier.rocks[key]
	if rock then return rock end
	local seed = tier.index * 100003 + key * 13 + 7
	local facets, turn = {}, random(seed + 1) * TAU
	for f = 1, FACETS do
		local a = turn + (f + 0.5 * random(seed + f * 5)) / FACETS * TAU
		facets[f] = { math.cos(a), math.sin(a) }
	end
	local tilt = random(seed + 2) * TAU
	local scale = math.exp(SIZE_SPREAD * (2 * random(seed + 7) - 1))
	local size = tier.size * scale
	rock = {
		-- The rock's claim on the wall: a power diagram, so big rocks take more.
		weight = (size / 2) ^ 2,
		angle = (i + 0.5 * (j % 2) + JITTER_ALONG * (2 * random(seed + 3) - 1)) / tier.columnsAt(j) * TAU,
		down = (j + 0.5 + JITTER_DOWN * (2 * random(seed + 4) - 1)) * tier.rowHeight,
		proud = (PROUD_MIN + PROUD_SPREAD * random(seed + 5)) * math.sqrt(scale),
		facets = facets,
		tiltX = TILT * math.cos(tilt),
		tiltY = TILT * math.sin(tilt),
		tint = 0.85 + 0.3 * random(seed + 6),
		seed = seed,
	}
	tier.rocks[key] = rock
	return rock
end

-- The rock of `tier` that owns the point at arc-length `girth` round the
-- wall (at `angle`) and `down` rows below the tier's top, and how far the
-- point is from that rock's edge.
local function ownerIn(tier, angle: number, down: number, girth: number)
	local row = math.clamp(math.floor(down / tier.rowHeight), 0, tier.rows - 1)
	-- Every rock near enough to own the point, as offsets from it.
	local near = {}
	for j = math.max(row - 1, 0), math.min(row + 1, tier.rows - 1) do
		local count = tier.columnsAt(j)
		local column = math.floor((angle % TAU) / TAU * count)
		for di = -4, 4 do
			local rock = rockAt(tier, (column + di) % count, j)
			local dx = ((rock.angle - angle + math.pi) % TAU - math.pi) * girth
			local dy = rock.down - down
			table.insert(near, { rock = rock, dx = dx, dy = dy, d = dx * dx + dy * dy - rock.weight })
		end
	end
	local owner = near[1]
	for _, candidate in near do
		if candidate.d < owner.d then owner = candidate end
	end
	-- Distance to the nearest edge: the closest bisector to another rock.
	local edge = math.huge
	for _, other in near do
		if other.rock == owner.rock then continue end
		local span = math.sqrt((other.dx - owner.dx) ^ 2 + (other.dy - owner.dy) ^ 2)
		edge = math.min(edge, (other.d - owner.d) / (2 * span))
	end
	return owner, edge
end

-- How far a rock's face stands out at its point: the lowest of its facet
-- planes, tilted, then bevelled down to the seam by a chipped edge.
local function faceHeight(owner, edge: number, along: number, down: number): number
	local rock = owner.rock
	local qx, qy = -owner.dx, -owner.dy
	local fall = 0
	for _, facet in rock.facets do
		fall = math.max(fall, FACET_SLOPE * (facet[1] * qx + facet[2] * qy))
	end
	local height = rock.proud - fall + rock.tiltX * qx + rock.tiltY * qy
	local chip = CHIP * math.clamp(math.noise(along / 1.3, down / 1.3, rock.seed % 97) + 0.3, 0, 1)
	return math.clamp(math.min(height, (edge - chip) * BEVEL), 0, rock.proud + 0.3)
end

-- How far the island's wall reaches at `angle` and height z, the rock
-- there and how far the point is from that rock's edge, for painting.
local function wall(angle: number, z: number)
	local k, floor, top = tierAt(z, angle)
	if not k then return 0.05, nil, 0 end
	local tier = tiers[k]
	local reach = GIRTH * outlineScale(angle) * tier.share * (1 - BATTER * (top - z) / (top - floor))
	local girth, down = GIRTH * tier.share, tier.top - z
	local owner, edge = ownerIn(tier, angle, down, girth)
	-- The tier's floor, and below the rim its top, also bound a rock.
	edge = math.min(edge, z - floor)
	if k > 1 then edge = math.min(edge, top - z) end
	return reach + faceHeight(owner, edge, angle * girth, down), owner.rock, edge
end

-- The underside at `angle` and `share` of its radius from the axis: how far
-- its rock hangs below the flat base, the rock, and the rock's edge.
local function undersideAt(angle: number, share: number)
	local girth = UNDERSIDE_RADIUS * math.clamp(share, 0, 1)
	local down = UNDERSIDE_RADIUS - girth
	local owner, edge = ownerIn(underside, angle, down, girth)
	return faceHeight(owner, edge, angle * girth, down), owner.rock, edge
end

-- The soil lip: how far it drapes down the rim at `angle`, in clumps.
local function drape(angle: number): number
	local n = math.noise(angle * 7, 3.7) + 0.5 * math.noise(angle * 23, 9.1)
	return 0.35 + 1.1 * math.clamp(n + 0.4, 0, 1)
end

-- The rock layout above gives the wall's reach per angle and height,
-- sampled once into a table and meshed directly as rings of vertices, bent
-- by a slow 3D warp so the rocks lean and curl a little.
local ANGLES, STEP, FLOOR, LIP = 360, 0.2, -25, 0.35
local RIM_JAGGED, RIM_POKE = 0.166, 0.06
local RIM_BLEND = 1.2
local WARP, CAP_RINGS = 0.7, 8
-- Rows are finer through the soil lip so its edge doesn't step.
local LIP_STEP, LIP_BAND = 0.04, 2.5
-- The shell and its shading are cached under a key hashing every line above
-- "-- cached above", so changes below it skip the rebuild.
local function shade(entries, occluders, gradient: number?)
	for _, entry in entries do
		entry.mesh:paintShading(entry.image, {
			highlight = 0.5,
			highlightRamp = 0.3,
			shadow = 0.75,
			gradient = gradient or GRADIENT,
			blend = 1,
			brushed = true,
			occluders = occluders,
			-- The island paint, cached under the item's key since its code is not hashed.
			paint = entry.paint,
			custom = entry.custom,
			salt = CACHE_KEY,
		})
	end
end

-- The wall's reach per row (stepping down from the top) and angle, with the
-- calm rim easing into the rock faces and the soil lip standing proud of
-- the rock. Rows below the keel all round are empty.
local function reachTable()
	local rim = {}
	for j = 0, ANGLES - 1 do
		-- The rim's jaggedness, its departure from the smooth outline,
		-- exaggerated inward by RIM_JAGGED and tamed outward by RIM_POKE.
		local angle = 2 * math.pi * j / ANGLES
		local smooth = RADIUS * WALL_REACH * outlineScale(angle)
		local departure = wall(angle, CAP_TOP) - smooth
		rim[j] = smooth + departure * (if departure > 0 then RIM_POKE else RIM_JAGGED)
	end
	local rows, heights = {}, {}
	local z = CAP_TOP
	while z > FLOOR do
		local row, any = {}, false
		for j = 0, ANGLES - 1 do
			local angle = 2 * math.pi * j / ANGLES
			local reach = wall(angle, z)
			if reach > 0.3 then any = true end
			local t = math.clamp((CAP_TOP - z) / RIM_BLEND, 0, 1)
			t = t * t * (3 - 2 * t)
			local r = if reach > 0.3 then rim[j] + (reach - rim[j]) * t else -1
			-- The lip tapers over several rows so its lower edge doesn't step.
			local lip = math.clamp((drape(angle) - (CAP_TOP - z)) / 0.8, 0, 1)
			if lip > 0 then
				r = math.max(r, rim[j]) + LIP * lip * lip * (3 - 2 * lip)
			end
			row[j] = r
		end
		if not any then break end
		table.insert(rows, row)
		table.insert(heights, z)
		z -= if CAP_TOP - z < LIP_BAND then LIP_STEP else STEP
	end
	return rows, heights
end

local shell = model.cached(CACHE_KEY, function()
chunkedPart("Island", nil, GROUND, function(mesh)
	local rows, heights = reachTable()
	-- The wall is a grid wrapped round the island: one ring of vertices per
	-- row of the reach table, so every face points outward by construction.
	-- Where a column has no rock the ring pulls in to the axis, closing the
	-- underside. Rows are bent by the same slow warp the paint reads, faded
	-- out toward the top so the rim stays level.
	local function ringPoint(row: number, j: number, r: number)
		local zr = heights[row]
		local angle = 2 * math.pi * j / ANGLES
		local x, y = r * math.cos(angle), r * math.sin(angle)
		-- The warp reads the outline, not the vertex, so a column shifts as
		-- one and its rows never cross where the reach jumps.
		local wx, wy = RADIUS * math.cos(angle), RADIUS * math.sin(angle)
		local fade = math.clamp((CAP_TOP - zr) / 1.5, 0, 1)
		return x, y, zr - fade * WARP * math.noise(wx / 7, wy / 7, zr / 9 + 5)
	end
	local rings = {}
	for row, reach in rows do
		local ring = {}
		for j = 0, ANGLES - 1 do
			local x, y, z = ringPoint(row, j, math.max(reach[j], 0))
			ring[j] = if row == 1 then mesh:exactVertex(x, y, z) else mesh:vertex(x, y, z)
		end
		rings[row] = ring
	end
	for row = 1, #rings - 1 do
		local upper, lower = rings[row], rings[row + 1]
		for j = 0, ANGLES - 1 do
			local l = (j + 1) % ANGLES
			mesh:face({ upper[j], lower[j], lower[l] })
			mesh:face({ upper[j], lower[l], upper[l] })
		end
	end
	-- The top: dead flat rings shrinking from the rim to the centre.
	local outer = rings[1]
	for n = 1, CAP_RINGS do
		local s = 1 - n / CAP_RINGS
		local inner = {}
		for j = 0, ANGLES - 1 do
			local x, y = ringPoint(1, j, math.max(rows[1][j], 0) * s)
			inner[j] = if n == CAP_RINGS then nil else mesh:exactVertex(x, y, CAP_TOP)
		end
		local centre = if n == CAP_RINGS then mesh:exactVertex(0, 0, CAP_TOP) else nil
		for j = 0, ANGLES - 1 do
			local l = (j + 1) % ANGLES
			if centre then
				mesh:face({ centre, outer[j], outer[l] })
			else
				mesh:face({ outer[j], inner[l], inner[j] })
				mesh:face({ outer[j], outer[l], inner[l] })
			end
		end
		outer = inner
	end
	-- The underside: the last ring closes onto a flat base at its average
	-- height, with the underside's rocks hanging below it in rings in to the
	-- axis. Faces wind downward.
	local rim = rows[#rows]
	local base = 0
	for j = 0, ANGLES - 1 do
		local _, _, z = ringPoint(#rows, j, math.max(rim[j], 0))
		base += z / ANGLES
	end
	local edgeRing = rings[#rows]
	for n = 1, UNDERSIDE_RINGS do
		local s = 1 - (1 - UNDERSIDE_CENTRE) * n / UNDERSIDE_RINGS
		local inner = {}
		for j = 0, ANGLES - 1 do
			local angle = 2 * math.pi * j / ANGLES
			local radius = math.max(rim[j], 0) * s
			local hang = select(1, undersideAt(angle, radius / (UNDERSIDE_RADIUS * outlineScale(angle))))
			inner[j] = mesh:vertex(radius * math.cos(angle), radius * math.sin(angle), base - hang)
		end
		for j = 0, ANGLES - 1 do
			local l = (j + 1) % ANGLES
			mesh:face({ edgeRing[j], inner[j], inner[l] })
			mesh:face({ edgeRing[j], inner[l], edgeRing[l] })
		end
		edgeRing = inner
	end
	local centre = mesh:vertex(0, 0, base - select(1, undersideAt(0, 0)))
	for j = 0, ANGLES - 1 do
		local l = (j + 1) % ANGLES
		mesh:face({ centre, edgeRing[l], edgeRing[j] })
	end
end, 45, function(x, y, z)
	-- Paint in the same warped space the mesh was carved from, so rocks,
	-- tints and strata follow the meshed faces.
	local wz = z + WARP * math.noise(x / 7, y / 7, z / 9 + 5)
	local wa = math.atan2(y, x) + 0.02 * math.noise(x / 5, y / 5, z / 5 + 17)
	local _, rock, edge = wall(wa, wz)
	if not rock then
		-- Below the staircase, the underside's rocks paint the flat base.
		local share = math.sqrt(x * x + y * y) / (UNDERSIDE_RADIUS * outlineScale(wa))
		if share <= 1 then _, rock, edge = undersideAt(wa, share) end
	end
	-- The flat top keeps its true height so it paints as even ground.
	local depth = if z > CAP_TOP - 0.01 then 0 else math.min(wz, z) - CAP_TOP
	local r, g, b = islandPaint(x, y, depth, if rock then rock.seed else nil, if rock then rock.tint else nil)
	if not rock or depth > -0.3 then return r, g, b end
	-- The seams between rocks fall into shadow.
	local seam = 0.45 + 0.55 * math.clamp(edge / 0.3, 0, 1)
	return r * seam, g * seam, b * seam
end)

-- Aggressive shading: half-strength edge highlights, ramping 30% stronger
-- toward the bottom, and strong contact shadows, with the shell as its own
-- occluder so the crevices and overhangs darken.
local entries = table.clone(parts)
local meshes = {}
for _, entry in entries do
	table.insert(meshes, entry.mesh)
end
shade(entries, meshes)
table.clear(parts)
return entries
end)
-- cached above

for _, entry in shell do
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
