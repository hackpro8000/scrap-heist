-- Arena Drone: the storm arena, carried over the map by a scrap-built
-- quadcopter instead of standing on a floating island. An open octagonal
-- ring girder holds the deck: steel grating over the ring, so it can be
-- walked on and still seen through, and solid plating inside it banking
-- down to the fight floor. Four truss arms will carry the motors and
-- propellers, with a battery pack slung under the middle.
-- Built 1.5 times the old arena island's size, as the yards are: the fight
-- floor is 108 studs across and the plating's rim 150. The deck's top
-- stands at z = 0; the ring's outer edge is 90 studs out on a flat side.
useTexelDensity(16)

local GIRDER = { 0.5, 0.24, 0.15 }
local PLATING = { 0.47, 0.47, 0.46 }

-- Octagon sizes, as the distance to the middle of a flat side. A flat side
-- faces each axis, as on the Server Map.
local RING_OUTER, RING_INNER = 90, 75
local FLOOR = 54
-- The floor plating is laid in rings round a small octagon in the middle.
local FLOOR_HUB = 6
-- The bank keeps the old arena's slope: its depth grew with its width.
local BOWL_DEPTH = 8.25
local PLATE_THICK = 0.5
-- The ring girder hangs under the grating.
local GIRDER_TOP, GIRDER_BOTTOM = -0.5, -9
local CHORD = 1.3
local WEB = 0.8
-- Truss panels along each side of the ring.
local PANELS = 8

-- Corner k (0-7) of an octagon, corners sitting between the axes.
local CORNER_SCALE = 1 / math.cos(math.pi / 8)
local function corner(apothem: number, k: number): (number, number)
	local angle = math.pi / 8 + k * math.pi / 4
	return math.cos(angle) * apothem * CORNER_SCALE, math.sin(angle) * apothem * CORNER_SCALE
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- A four-sided patch split into a grid, so the warp can dent it and its
-- texture keeps an even density. Corners run anticlockwise seen from the
-- side the face looks out of.
local function patch(mesh, p00, p10, p11, p01, nu: number, nv: number)
	local rows = {}
	for j = 0, nv do
		rows[j] = {}
		local v = j / nv
		for i = 0, nu do
			local u = i / nu
			local x = lerp(lerp(p00[1], p10[1], u), lerp(p01[1], p11[1], u), v)
			local y = lerp(lerp(p00[2], p10[2], u), lerp(p01[2], p11[2], u), v)
			local z = lerp(lerp(p00[3], p10[3], u), lerp(p01[3], p11[3], u), v)
			rows[j][i] = mesh:vertex(x, y, z)
		end
	end
	for j = 0, nv - 1 do
		for i = 0, nu - 1 do
			mesh:face({ rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i] })
		end
	end
end

local function cells(length: number): number
	return math.clamp(math.ceil(length / 6), 1, 32)
end

-- The deck plating: the bank from the rim down to the floor and the floor
-- itself, each side's panel a plate with a top, an underside and a lip at
-- the rim.
chunkedPart("Plating", nil, PLATING, function(mesh)
	for k = 0, 7 do
		local rx0, ry0 = corner(RING_INNER, k)
		local rx1, ry1 = corner(RING_INNER, k + 1)
		local fx0, fy0 = corner(FLOOR, k)
		local fx1, fy1 = corner(FLOOR, k + 1)
		local side = 2 * RING_INNER * math.tan(math.pi / 8)
		local mx0, my0 = corner(FLOOR_HUB, k)
		local mx1, my1 = corner(FLOOR_HUB, k + 1)
		for _, layer in { { 0, 1 }, { -PLATE_THICK, -1 } } do
			local dz, facing = layer[1], layer[2]
			local floorZ = dz - BOWL_DEPTH
			local rim0, rim1 = { rx0, ry0, dz }, { rx1, ry1, dz }
			local low0, low1 = { fx0, fy0, floorZ }, { fx1, fy1, floorZ }
			local hub0, hub1 = { mx0, my0, floorZ }, { mx1, my1, floorZ }
			-- Faces wind anticlockwise seen from outside, as box() does.
			if facing > 0 then
				patch(mesh, low1, low0, rim0, rim1, cells(side), cells(RING_INNER - FLOOR))
				patch(mesh, hub1, hub0, low0, low1, cells(side), cells(FLOOR - FLOOR_HUB))
			else
				patch(mesh, low0, low1, rim1, rim0, cells(side), cells(RING_INNER - FLOOR))
				patch(mesh, hub0, hub1, low1, low0, cells(side), cells(FLOOR - FLOOR_HUB))
			end
		end
		-- The lip where the plating meets the grating.
		patch(mesh, { rx0, ry0, -PLATE_THICK }, { rx1, ry1, -PLATE_THICK }, { rx1, ry1, 0 }, { rx0, ry0, 0 }, cells(side), 1)
	end
	-- The small octagon in the middle of the floor, top and underside.
	for _, z in { -BOWL_DEPTH, -BOWL_DEPTH - PLATE_THICK } do
		local ring = {}
		for k = 0, 7 do
			local x, y = corner(FLOOR_HUB, k)
			ring[k + 1] = mesh:vertex(x, y, z)
		end
		if z < -BOWL_DEPTH then
			ring = { ring[8], ring[7], ring[6], ring[5], ring[4], ring[3], ring[2], ring[1] }
		end
		mesh:face(ring)
	end
end, nil, 0.3, nil, 1.5)

-- Steel grating over the ring girder: flat bars running round the ring,
-- crossed by thin bars every stud, open between them so the girders and
-- the sky show through.
local GRATE_BAR, GRATE_HEIGHT = 0.25, 0.3
local GRATE_ROWS = 6
local GRATE_PITCH = 1
-- Thin bars unwrap into many small islands, so at the deck's texel density
-- they would need hundreds of textures; each side's bars and girders are
-- one part with a fixed texture instead.
local GRATE_TEXTURE, GIRDER_TEXTURE = 256, 512
for k = 0, 7 do
	part(`Grating{k + 1}`, nil, DARK_STEEL, function(mesh)
		local z = -GRATE_HEIGHT / 2
		local ix0, iy0 = corner(RING_INNER, k)
		local ix1, iy1 = corner(RING_INNER, k + 1)
		local ox0, oy0 = corner(RING_OUTER, k)
		local ox1, oy1 = corner(RING_OUTER, k + 1)
		-- Bearing bars round the ring, inner edge to outer edge.
		for r = 0, GRATE_ROWS do
			local t = r / GRATE_ROWS
			strut(mesh, lerp(ix0, ox0, t), lerp(iy0, oy0, t), z, lerp(ix1, ox1, t), lerp(iy1, oy1, t), z, GRATE_BAR)
		end
		-- Cross bars, across the ring at a stud's spacing.
		local length = 2 * RING_OUTER * math.tan(math.pi / 8)
		local count = math.floor(length / GRATE_PITCH)
		for c = 1, count - 1 do
			local t = c / count
			local ax, ay = lerp(ix0, ix1, t), lerp(iy0, iy1, t)
			local bx, by = lerp(ox0, ox1, t), lerp(oy0, oy1, t)
			strut(mesh, ax, ay, z + GRATE_HEIGHT * 0.15, bx, by, z + GRATE_HEIGHT * 0.15, GRATE_BAR * 0.6)
		end
	end, nil, 0.5, GRATE_TEXTURE, nil, true)
end

-- The ring girder: an inner and an outer truss wall round the octagon,
-- top and bottom chords with a zigzag web between, tied across the ring
-- at every panel point.
local inner, outer = RING_INNER + 1, RING_OUTER - 1
local top, bottom = GIRDER_TOP - CHORD / 2, GIRDER_BOTTOM + CHORD / 2
for k = 0, 7 do
	part(`Girder{k + 1}`, nil, GIRDER, function(mesh)
		local ix0, iy0 = corner(inner, k)
		local ix1, iy1 = corner(inner, k + 1)
		local ox0, oy0 = corner(outer, k)
		local ox1, oy1 = corner(outer, k + 1)
		for _, wall in { { ix0, iy0, ix1, iy1 }, { ox0, oy0, ox1, oy1 } } do
			local x0, y0, x1, y1 = wall[1], wall[2], wall[3], wall[4]
			strut(mesh, x0, y0, top, x1, y1, top, CHORD)
			strut(mesh, x0, y0, bottom, x1, y1, bottom, CHORD)
			for p = 0, PANELS - 1 do
				local a, b = p / PANELS, (p + 1) / PANELS
				local ax, ay, bx, by = lerp(x0, x1, a), lerp(y0, y1, a), lerp(x0, x1, b), lerp(y0, y1, b)
				strut(mesh, ax, ay, top, ax, ay, bottom, WEB)
				if p % 2 == 0 then
					strut(mesh, ax, ay, top, bx, by, bottom, WEB)
				else
					strut(mesh, ax, ay, bottom, bx, by, top, WEB)
				end
			end
		end
		-- Ties across the ring at each panel point, top and bottom, with a
		-- diagonal brace in every other bay.
		for p = 0, PANELS - 1 do
			local t = p / PANELS
			local ax, ay = lerp(ix0, ix1, t), lerp(iy0, iy1, t)
			local bx, by = lerp(ox0, ox1, t), lerp(oy0, oy1, t)
			strut(mesh, ax, ay, top, bx, by, top, WEB)
			strut(mesh, ax, ay, bottom, bx, by, bottom, WEB)
			if p % 2 == 0 then
				strut(mesh, ax, ay, top, bx, by, bottom, WEB)
			end
		end
	end, nil, 0.6, GIRDER_TEXTURE, nil, nil, 1)
end

-- Radial beams from the ring's inner wall to the middle, holding the
-- plating up from underneath.
part("Joists", nil, GIRDER, function(mesh)
	local depth = 1.6
	for k = 0, 7 do
		local x, y = corner(RING_INNER + 1, k)
		local fx, fy = corner(FLOOR, k)
		local under = -PLATE_THICK - depth / 2
		-- Along the bank, then flat under the floor.
		strut(mesh, x, y, GIRDER_TOP - CHORD, fx, fy, under - BOWL_DEPTH, depth)
		strut(mesh, fx, fy, under - BOWL_DEPTH, 0, 0, under - BOWL_DEPTH, depth)
	end
end, nil, 0.6, GIRDER_TEXTURE)

finishParts()
