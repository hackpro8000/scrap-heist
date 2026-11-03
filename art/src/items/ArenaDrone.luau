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

-- Four truss arms in an X, each a box truss of four chords tapering out
-- from the ring to a motor 175 studs from the middle. Inside the ring the
-- arm runs level under the grating, tied into the girder; past the ring
-- it climbs to the motor mount.
local ARM_DIRECTIONS = { 45, 135, 225, 315 }
local MOTOR_OUT = 175
local ARM_ROOT = RING_INNER + 1
local ARM_PANEL = 8
local ARM_TEXTURE, MOTOR_TEXTURE = 512, 256
-- Half width across the arm, and its top and bottom chords' heights, at a
-- distance out from the middle.
local function armShape(r: number): (number, number, number)
	local t = math.clamp((r - ARM_ROOT) / (MOTOR_OUT - ARM_ROOT), 0, 1)
	local climb = math.clamp((r - RING_OUTER) / (MOTOR_OUT - RING_OUTER), 0, 1)
	return lerp(7, 3, t), lerp(top, 3, climb), lerp(bottom, 0, climb)
end
-- The motors lean in towards the middle, so the propellers on them tilt
-- that way too.
local MOTOR_TILT = math.rad(8)
local MOTOR_MOUNT = 3 + CHORD / 2

-- Builds into a mesh tipped about a level axis through (px, py, pz), so
-- whatever stands up from the pivot leans `angle` towards (-dx, -dy).
local function leaning(mesh, px: number, py: number, pz: number, dx: number, dy: number, angle: number)
	local c, s = math.cos(angle), math.sin(angle)
	return setmetatable({
		vertex = function(_, x, y, z)
			local ox, oy, oz = x - px, y - py, z - pz
			local out = ox * dx + oy * dy
			local across = -ox * dy + oy * dx
			out, oz = out * c - oz * s, out * s + oz * c
			return mesh:vertex(px + out * dx - across * dy, py + out * dy + across * dx, pz + oz)
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

-- Propellers: two twisted blades 100 studs tip to tip on a hub over each
-- motor's shaft, tilted with the motor. Each blade is lofted through
-- sections that narrow and flatten their pitch towards the tip. The last
-- stretch of each blade is painted hazard yellow.
local PROP_RADIUS, PROP_HUB = 50, 3
local PROP_TIP = 6
local PROP_SECTIONS = 16
local PROP_TEXTURE = 512
local HAZARD_YELLOW = { 0.9, 0.72, 0.15 }
local function bladeChord(s: number): number
	local t = (s - PROP_HUB) / (PROP_RADIUS - PROP_HUB)
	return if t < 0.3 then lerp(4.5, 7, t / 0.3) else lerp(7, 3, (t - 0.3) / 0.7)
end
local function bladePitch(s: number): number
	return math.rad(lerp(24, 8, (s - PROP_HUB) / (PROP_RADIUS - PROP_HUB)))
end
-- One blade from `from` to `to` studs out, pointing at `heading`, around
-- the hub at (hx, hy, hz).
local function blade(mesh, hx: number, hy: number, hz: number, heading: number, from: number, to: number)
	local sx, sy = math.cos(heading), math.sin(heading)
	local cx, cy = -sy, sx
	local sections = {}
	local count = math.max(2, math.round(PROP_SECTIONS * (to - from) / (PROP_RADIUS - PROP_HUB)))
	for j = 0, count do
		local span = lerp(from, to, j / count)
		local chord, pitch = bladeChord(span), bladePitch(span)
		local thick = lerp(1.1, 0.4, (span - PROP_HUB) / (PROP_RADIUS - PROP_HUB))
		-- A thin wing section, leading edge first, round under then over.
		local profile = {
			{ -chord / 2, 0 },
			{ -chord / 4, -thick * 0.35 },
			{ chord / 4, -thick * 0.25 },
			{ chord / 2, 0 },
			{ chord / 4, thick * 0.35 },
			{ -chord / 4, thick * 0.5 },
		}
		local ring = {}
		for k, point in profile do
			local y = point[1] * math.cos(pitch) - point[2] * math.sin(pitch)
			local z = point[1] * math.sin(pitch) + point[2] * math.cos(pitch)
			ring[k] = mesh:vertex(hx + sx * span + cx * y, hy + sy * span + cy * y, hz + z)
		end
		sections[j] = ring
	end
	for j = 0, count - 1 do
		local a, b = sections[j], sections[j + 1]
		for k = 1, 6 do
			local l = k % 6 + 1
			mesh:face({ a[k], a[l], b[l], b[k] })
		end
	end
	local root = {}
	for k = 6, 1, -1 do
		table.insert(root, sections[0][k])
	end
	mesh:face(root)
	mesh:face(sections[count])
end

for i, degrees in ARM_DIRECTIONS do
	local angle = math.rad(degrees)
	local ux, uy = math.cos(angle), math.sin(angle)
	local function at(r: number, side: number, z: number): (number, number, number)
		return ux * r - uy * side, uy * r + ux * side, z
	end
	-- Panel points along the arm, with one at the ring's outer wall where
	-- the arm starts to climb.
	local stations = { ARM_ROOT }
	local r = ARM_ROOT
	while r < MOTOR_OUT - 1 do
		local nextR = math.min(r + ARM_PANEL, MOTOR_OUT)
		if r < RING_OUTER - 1 and nextR > RING_OUTER - 1 then
			nextR = RING_OUTER - 1
		end
		table.insert(stations, nextR)
		r = nextR
	end
	part(`Arm{i}`, nil, GIRDER, function(mesh)
		local function corners(r: number)
			local w, zt, zb = armShape(r)
			return { { at(r, -w, zt) }, { at(r, w, zt) }, { at(r, w, zb) }, { at(r, -w, zb) } }
		end
		local function beam(p, q, thick)
			strut(mesh, p[1], p[2], p[3], q[1], q[2], q[3], thick)
		end
		for n, station in stations do
			local frame = corners(station)
			-- A square frame at every panel point.
			for k = 1, 4 do
				beam(frame[k], frame[k % 4 + 1], WEB)
			end
			if n < #stations then
				local nextFrame = corners(stations[n + 1])
				for k = 1, 4 do
					beam(frame[k], nextFrame[k], CHORD)
					-- A diagonal on each face, alternating direction.
					local l = k % 4 + 1
					if n % 2 == 0 then
						beam(frame[k], nextFrame[l], WEB)
					else
						beam(frame[l], nextFrame[k], WEB)
					end
				end
			end
		end
		-- The mount plate the motor stands on.
		local mx, my = ux * MOTOR_OUT, uy * MOTOR_OUT
		box(mesh, mx, my, 3, 15, 15, CHORD)
	end, nil, 0.6, ARM_TEXTURE, nil, nil, 1)

	-- The motor: a flanged base, a finned stator and a spinning bell on
	-- top, leaning in towards the middle.
	local mx, my = ux * MOTOR_OUT, uy * MOTOR_OUT
	local base = MOTOR_MOUNT
	part(`Motor{i}`, nil, DARK_STEEL, function(mesh)
		local lean = leaning(mesh, mx, my, base, ux, uy, MOTOR_TILT)
		cylinder(lean, mx, my, base + 4, 5.2, 7, "z", 20)
		for f = 0, 4 do
			ring(lean, mx, my, base + 1.6 + f * 1.25, 5.1, 6, 0.45, "z", 20)
		end
	end, 30, 0.45, MOTOR_TEXTURE)
	part(`MotorTrim{i}`, nil, STEEL, function(mesh)
		local lean = leaning(mesh, mx, my, base, ux, uy, MOTOR_TILT)
		cylinder(lean, mx, my, base + 0.5, 7, 1, "z", 20)
		for b = 0, 7 do
			local a = b * TAU / 8
			bolt(lean, mx + math.cos(a) * 6.3, my + math.sin(a) * 6.3, base + 1.05, "z", 0.35)
		end
		-- The bell, with the shaft the propeller will sit on.
		cylinder(lean, mx, my, base + 8.4, 6, 1.8, "z", 20)
		cylinder(lean, mx, my, base + 9.8, 1.2, 1.4, "z", 12)
	end, 30, 0.3, MOTOR_TEXTURE)

	local hubZ = base + 11.3
	-- Each propeller stopped at its own angle, so the four don't match.
	local phase = math.rad(degrees + 30 * i)
	part(`Prop{i}`, nil, DARK_STEEL, function(mesh)
		local lean = leaning(mesh, mx, my, base, ux, uy, MOTOR_TILT)
		for b = 0, 1 do
			blade(lean, mx, my, hubZ, phase + b * math.pi, PROP_HUB, PROP_RADIUS - PROP_TIP)
		end
	end, 30, 0.35, PROP_TEXTURE)
	part(`PropTips{i}`, nil, HAZARD_YELLOW, function(mesh)
		local lean = leaning(mesh, mx, my, base, ux, uy, MOTOR_TILT)
		for b = 0, 1 do
			blade(lean, mx, my, hubZ, phase + b * math.pi, PROP_RADIUS - PROP_TIP, PROP_RADIUS)
		end
	end, 30, 0.35, 128)
	part(`PropHub{i}`, nil, STEEL, function(mesh)
		local lean = leaning(mesh, mx, my, base, ux, uy, MOTOR_TILT)
		cylinder(lean, mx, my, hubZ, PROP_HUB + 0.6, 2.4, "z", 16)
		cylinder(lean, mx, my, hubZ + 1.6, 1.6, 0.8, "z", 12)
		for b = 0, 3 do
			local a = phase + b * TAU / 4 + TAU / 8
			bolt(lean, mx + math.cos(a) * 2.4, my + math.sin(a) * 2.4, hubZ + 1.2, "z", 0.3)
		end
	end, 30, 0.3, 128)

	-- Power cable along the underside of the arm, out to the motor.
	part(`Cable{i}`, nil, RUBBER_BLACK, function(mesh)
		local points = {}
		for _, station in stations do
			local _, _, zb = armShape(station)
			table.insert(points, { at(station, 0, zb - 0.9) })
		end
		local last = points[#points]
		table.insert(points, { last[1] - ux * 2, last[2] - uy * 2, MOTOR_MOUNT + 2 })
		tube(mesh, points, 0.45, 8)
	end, true, RUBBER, 256)
end

finishParts()
