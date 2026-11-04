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
local HAZARD_YELLOW = { 0.9, 0.72, 0.15 }
local HAZARD_BLACK = { 0.11, 0.11, 0.12 }
-- Motor windings: a deep red copper, well clear of the hazard yellow.
local COIL_COPPER = { 0.55, 0.22, 0.1 }

-- The truss (ring girder and arms) is painted in yellow and black hazard
-- bands. The bands are planes across the model, tilted so no strut runs
-- along them: every member, whichever way it runs, shows stripes.
local HAZARD_BAND = 4
local HAZARD_AXIS = { 1, 0.41, 0.57 }
local paintHazard = rusting(0.6, function(x, y, z)
	local along = x * HAZARD_AXIS[1] + y * HAZARD_AXIS[2] + z * HAZARD_AXIS[3]
	local colour = if math.floor(along / HAZARD_BAND) % 2 == 0 then HAZARD_YELLOW else HAZARD_BLACK
	return colour[1], colour[2], colour[3]
end)
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

-- The grating's rim: a hazard-striped steel channel round the ring's outer
-- edge, its top flush with the grating so the deck walks straight onto it,
-- and deep enough to hide the bar ends and cap the girder below. Mitred at
-- each corner into one closed band; a part per side keeps its stripes sharp.
local RIM_IN, RIM_OUT = RING_OUTER - 0.3, RING_OUTER + 0.4
local RIM_TOP, RIM_BOTTOM = 0, -1.2
local RIM_TEXTURE = 256
for k = 0, 7 do
	part(`GratingRim{k + 1}`, nil, GIRDER, function(mesh)
		local ix0, iy0 = corner(RIM_IN, k)
		local ix1, iy1 = corner(RIM_IN, k + 1)
		local ox0, oy0 = corner(RIM_OUT, k)
		local ox1, oy1 = corner(RIM_OUT, k + 1)
		local along = cells(2 * RIM_OUT * math.tan(math.pi / 8))
		-- Top, outer face, underside and inner face, each anticlockwise seen
		-- from outside.
		patch(mesh, { ix0, iy0, RIM_TOP }, { ox0, oy0, RIM_TOP }, { ox1, oy1, RIM_TOP }, { ix1, iy1, RIM_TOP }, 1, along)
		patch(mesh, { ox0, oy0, RIM_BOTTOM }, { ox1, oy1, RIM_BOTTOM }, { ox1, oy1, RIM_TOP }, { ox0, oy0, RIM_TOP }, along, 1)
		patch(mesh, { ix0, iy0, RIM_BOTTOM }, { ix1, iy1, RIM_BOTTOM }, { ox1, oy1, RIM_BOTTOM }, { ox0, oy0, RIM_BOTTOM }, along, 1)
		patch(mesh, { ix1, iy1, RIM_BOTTOM }, { ix0, iy0, RIM_BOTTOM }, { ix0, iy0, RIM_TOP }, { ix1, iy1, RIM_TOP }, along, 1)
	end, nil, paintHazard, RIM_TEXTURE, nil, nil, 1)
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
	end, nil, paintHazard, GIRDER_TEXTURE, nil, nil, 1)
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
-- it climbs to the collar clamped round the motor.
local ARM_DIRECTIONS = { 45, 135, 225, 315 }
local MOTOR_OUT = 175
local ARM_ROOT = RING_INNER + 1
local ARM_PANEL = 8
local ARM_TEXTURE, MOTOR_TEXTURE = 512, 256
-- Each motor is gripped round its lower body by a steel collar, and the
-- arm's tip is welded to the collar's inner side. The collar's height
-- covers the arm's tip, which ends where its chords meet the collar.
local COLLAR_INNER, COLLAR_OUTER, COLLAR_HEIGHT = 5.3, 6.8, 3.6
local ARM_TIP_TOP, ARM_TIP_BOTTOM, ARM_TIP_HALF = 8, 5, 3
local ARM_END = MOTOR_OUT - math.sqrt(COLLAR_OUTER ^ 2 - ARM_TIP_HALF ^ 2) + 0.3
-- Half width across the arm, and its top and bottom chords' heights, at a
-- distance out from the middle.
local function armShape(r: number): (number, number, number)
	local t = math.clamp((r - ARM_ROOT) / (ARM_END - ARM_ROOT), 0, 1)
	local climb = math.clamp((r - RING_OUTER) / (ARM_END - RING_OUTER), 0, 1)
	return lerp(7, ARM_TIP_HALF, t), lerp(top, ARM_TIP_TOP, climb), lerp(bottom, ARM_TIP_BOTTOM, climb)
end
-- The motors lean in towards the middle, so the propellers on them tilt
-- that way too. Each motor and its collar lean about the point where the
-- collar meets the arm's tip, so the weld stays put.
local MOTOR_TILT = math.rad(8)
local MOTOR_PIVOT = COLLAR_OUTER
local MOTOR_PIVOT_Z = (ARM_TIP_TOP + ARM_TIP_BOTTOM) / 2
-- The motor's bottom hangs a stud below the collar.
local MOTOR_BASE = MOTOR_PIVOT_Z - COLLAR_HEIGHT / 2 - 1

-- Where (x, y, z) ends up tipped about a level axis through (px, py, pz),
-- so whatever stands up from the pivot leans `angle` towards (-dx, -dy).
local function tipped(px: number, py: number, pz: number, dx: number, dy: number, angle: number, x: number, y: number, z: number)
	local c, s = math.cos(angle), math.sin(angle)
	local ox, oy, oz = x - px, y - py, z - pz
	local out = ox * dx + oy * dy
	local across = -ox * dy + oy * dx
	out, oz = out * c - oz * s, out * s + oz * c
	return px + out * dx - across * dy, py + out * dy + across * dx, pz + oz
end

-- Builds into a mesh tipped about a level axis through (px, py, pz), so
-- whatever stands up from the pivot leans `angle` towards (-dx, -dy).
local function leaning(mesh, px: number, py: number, pz: number, dx: number, dy: number, angle: number)
	return setmetatable({
		vertex = function(_, x, y, z)
			return mesh:vertex(tipped(px, py, pz, dx, dy, angle, x, y, z))
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

-- Blur discs: what a propeller looks like spinning, for the game to show in
-- place of the blades once they're up to speed. A thin see-through disc in
-- the blades' plane, painted with alpha: two faint smears trailing the
-- blades, circular streaks, and a yellow ring where the tips pass. It is
-- painted flat, with no shading or wear.
local DISC_RINGS, DISC_SECTORS = 24, 64
local DISC_TEXTURE = 512
local DISC_SMEAR = 1.1
local DISC_TINT = { 0.2, 0.2, 0.22 }
local function blurDisc(name: string, mx: number, my: number, ux: number, uy: number, hubZ: number, phase: number)
	local mesh = Mesh.new()
	local lean = leaning(mesh, mx - ux * MOTOR_PIVOT, my - uy * MOTOR_PIVOT, MOTOR_PIVOT_Z, ux, uy, MOTOR_TILT)
	local rows = {}
	for j = 0, DISC_RINGS do
		local r = lerp(PROP_HUB, PROP_RADIUS, j / DISC_RINGS)
		rows[j] = {}
		for k = 0, DISC_SECTORS - 1 do
			local a = k / DISC_SECTORS * TAU
			rows[j][k] = lean:vertex(mx + math.cos(a) * r, my + math.sin(a) * r, hubZ)
		end
	end
	for j = 0, DISC_RINGS - 1 do
		for k = 0, DISC_SECTORS - 1 do
			local l = (k + 1) % DISC_SECTORS
			mesh:face({ rows[j][k], rows[j][l], rows[j + 1][l], rows[j + 1][k] })
		end
	end
	mesh:setSmooth(true)
	mesh:unwrap()
	local image = Image.new(DISC_TEXTURE, DISC_TEXTURE, DISC_TINT[1], DISC_TINT[2], DISC_TINT[3])
	-- Back from world space into the disc's own plane (see leaning()).
	local c, s = math.cos(MOTOR_TILT), math.sin(MOTOR_TILT)
	mesh:paint(image, function(x, y, z)
		local wx, wy, wz = x - (mx - ux * MOTOR_PIVOT), y - (my - uy * MOTOR_PIVOT), z - MOTOR_PIVOT_Z
		local out = wx * ux * c + wy * uy * c + wz * s - MOTOR_PIVOT
		local across = -wx * uy + wy * ux
		local r = math.sqrt(out * out + across * across)
		-- Angle measured in the same frame the blades were placed in.
		local angle = math.atan2(ux * across + uy * out, ux * out - uy * across)
		-- Each blade smears back against the spin (anticlockwise from above).
		local smear = 0
		for b = 0, 1 do
			local behind = (phase + b * math.pi - angle) % TAU
			smear = math.max(smear, math.exp(-behind / DISC_SMEAR))
		end
		local span = math.clamp((r - PROP_HUB) / (PROP_RADIUS - PROP_HUB), 0, 1)
		-- Wider blades near the root leave a denser smear there.
		local body = bladeChord(math.clamp(r, PROP_HUB, PROP_RADIUS)) / 7
		local streak = 0.85 + 0.15 * math.sin(r * 2.3) * math.sin(r * 0.37 + 1.1)
		local opacity = (0.08 + 0.32 * smear) * body * streak
		local colour = DISC_TINT
		if r > PROP_RADIUS - PROP_TIP then
			colour = HAZARD_YELLOW
			opacity = 0.3 + 0.35 * smear
		end
		-- Soft at the rim, and clear over the hub.
		opacity *= math.clamp((PROP_RADIUS - r) / 1.2, 0, 1) * math.clamp((r - PROP_HUB) / 1.5, 0, 1)
		local k = streak * (0.9 + 0.2 * span)
		return colour[1] * k, colour[2] * k, colour[3] * k, opacity
	end)
	model.part(name, mesh, image, { preview = true })
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
	while r < ARM_END - 1 do
		local nextR = math.min(r + ARM_PANEL, ARM_END)
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
	end, nil, paintHazard, ARM_TEXTURE, nil, nil, 1)

	-- The motor: finned copper coils, gripped by a hazard-striped collar,
	-- with a striped spinning bell on top, leaning in towards the middle.
	local mx, my = ux * MOTOR_OUT, uy * MOTOR_OUT
	local base = MOTOR_BASE
	local px, py, pz = mx - ux * MOTOR_PIVOT, my - uy * MOTOR_PIVOT, MOTOR_PIVOT_Z
	-- The collar: a split band round the motor, with a lip at top and
	-- bottom, and two lugs on the outer side drawn together by clamp bolts.
	part(`MotorCollar{i}`, nil, STEEL, function(mesh)
		local lean = leaning(mesh, px, py, pz, ux, uy, MOTOR_TILT)
		ring(lean, mx, my, pz, COLLAR_INNER, COLLAR_OUTER, COLLAR_HEIGHT, "z", 24)
		for _, side in { -1, 1 } do
			ring(lean, mx, my, pz + side * (COLLAR_HEIGHT / 2 - 0.3), COLLAR_OUTER - 0.2, COLLAR_OUTER + 0.35, 0.6, "z", 24)
		end
		local vx, vy = -uy, ux
		for _, side in { -1, 1 } do
			local gap = side * 0.8
			strut(lean, mx + ux * (COLLAR_OUTER - 0.4) + vx * gap, my + uy * (COLLAR_OUTER - 0.4) + vy * gap, pz,
				mx + ux * (COLLAR_OUTER + 3) + vx * gap, my + uy * (COLLAR_OUTER + 3) + vy * gap, pz, 1.2)
		end
		for _, along in { 1.2, 2.4 } do
			local cx, cy = mx + ux * (COLLAR_OUTER + along), my + uy * (COLLAR_OUTER + along)
			for _, height in { -0.9, 0.9 } do
				strut(lean, cx - vx * 1.9, cy - vy * 1.9, pz + height, cx + vx * 1.9, cy + vy * 1.9, pz + height, 0.5)
			end
		end
	end, 30, paintHazard, MOTOR_TEXTURE)
	part(`Motor{i}`, nil, COIL_COPPER, function(mesh)
		local lean = leaning(mesh, px, py, pz, ux, uy, MOTOR_TILT)
		cylinder(lean, mx, my, base + 4.75, 5.2, 8.5, "z", 20)
		cylinder(lean, mx, my, base + 0.5, 4.4, 1, "z", 20)
		for f = 0, 2 do
			ring(lean, mx, my, base + 5.6 + f * 1.2, 5.1, 6, 0.45, "z", 20)
		end
	end, 30, 0.3, MOTOR_TEXTURE)
	part(`MotorTrim{i}`, nil, STEEL, function(mesh)
		local lean = leaning(mesh, px, py, pz, ux, uy, MOTOR_TILT)
		-- The bell in hazard stripes, with the shaft the propeller will sit on.
		cylinder(lean, mx, my, base + 9.9, 6, 1.8, "z", 20)
		cylinder(lean, mx, my, base + 11.3, 1.2, 1.4, "z", 12)
	end, 30, paintHazard, MOTOR_TEXTURE)

	local hubZ = base + 12.8
	-- Each propeller stopped at its own angle, so the four don't match.
	local phase = math.rad(degrees + 30 * i)
	part(`Prop{i}`, nil, DARK_STEEL, function(mesh)
		local lean = leaning(mesh, px, py, pz, ux, uy, MOTOR_TILT)
		for b = 0, 1 do
			blade(lean, mx, my, hubZ, phase + b * math.pi, PROP_HUB, PROP_RADIUS - PROP_TIP)
		end
	end, 30, 0.35, PROP_TEXTURE)
	part(`PropTips{i}`, nil, HAZARD_YELLOW, function(mesh)
		local lean = leaning(mesh, px, py, pz, ux, uy, MOTOR_TILT)
		for b = 0, 1 do
			blade(lean, mx, my, hubZ, phase + b * math.pi, PROP_RADIUS - PROP_TIP, PROP_RADIUS)
		end
	end, 30, 0.35, 128)
	blurDisc(`PropDisc{i}`, mx, my, ux, uy, hubZ, phase)
	part(`PropHub{i}`, nil, STEEL, function(mesh)
		local lean = leaning(mesh, px, py, pz, ux, uy, MOTOR_TILT)
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
		-- Up into the middle of the motor's underside.
		table.insert(points, { tipped(px, py, pz, ux, uy, MOTOR_TILT, mx - ux * 1.5, my - uy * 1.5, base + 0.2) })
		tube(mesh, points, 0.45, 8)
	end, true, RUBBER, 256)
end

-- The battery pack, slung under the middle of the deck: a row of cell
-- modules in an olive casing, held in a girder cradle that hangs from the
-- joists, with copper terminals on top feeding a heavy cable out to each
-- arm.
local BATTERY_OLIVE = { 0.33, 0.36, 0.25 }
local BATTERY_TOP, BATTERY_BOTTOM = -14.5, -28
local BATTERY_HALF_X, BATTERY_HALF_Y = 28, 20
local BATTERY_CELLS = 6
local CELL_GAP = 0.5
local CRADLE_GAP = 1.2
local JOIST_BOTTOM = -PLATE_THICK - 1.6 - BOWL_DEPTH
part("Battery", nil, BATTERY_OLIVE, function(mesh)
	local cell = (2 * BATTERY_HALF_X - (BATTERY_CELLS - 1) * CELL_GAP) / BATTERY_CELLS
	for c = 0, BATTERY_CELLS - 1 do
		local x = -BATTERY_HALF_X + cell / 2 + c * (cell + CELL_GAP)
		box(mesh, x, 0, BATTERY_BOTTOM, cell, 2 * BATTERY_HALF_Y, BATTERY_TOP - BATTERY_BOTTOM)
		-- A raised lid on each module.
		box(mesh, x, 0, BATTERY_TOP, cell - 1, 2 * BATTERY_HALF_Y - 2, 0.6)
	end
	-- The spine the modules are bolted to, running underneath.
	box(mesh, 0, 0, BATTERY_BOTTOM - 0.8, 2 * BATTERY_HALF_X + 1, 6, 0.8)
end, nil, 0.45, 512, nil, nil, 1.2)
part("BatteryWarning", nil, HAZARD_YELLOW, function(mesh)
	-- A warning plate on each long side.
	for _, side in { -1, 1 } do
		box(mesh, 0, side * (BATTERY_HALF_Y + 0.1), BATTERY_BOTTOM + 4, 20, 0.3, 5.5)
	end
end, nil, 0.35, 128)
part("BatteryStraps", nil, RUBBER_BLACK, function(mesh)
	for _, x in { -18, 0, 18 } do
		local h = BATTERY_HALF_Y + CRADLE_GAP * 0.5
		box(mesh, x, 0, BATTERY_TOP + 0.6, 2, 2 * h, 0.3)
		box(mesh, x, 0, BATTERY_BOTTOM - 1.1, 2, 2 * h, 0.3)
		for _, side in { -1, 1 } do
			box(mesh, x, side * h, BATTERY_BOTTOM - 1.1, 2, 0.3, BATTERY_TOP - BATTERY_BOTTOM + 2)
		end
	end
end, nil, RUBBER, 256)
part("Terminals", nil, COPPER, function(mesh)
	for i, degrees in ARM_DIRECTIONS do
		local angle = math.rad(degrees)
		local tx, ty = math.cos(angle) * 13 * math.sqrt(2), math.sin(angle) * 10 * math.sqrt(2)
		cylinder(mesh, tx, ty, BATTERY_TOP + 1.4, 1.4, 1.6, "z", 10)
		cylinder(mesh, tx, ty, BATTERY_TOP + 2.4, 0.9, 0.8, "z", 8)
	end
end, nil, 0.5, 128)
part("Cradle", nil, GIRDER, function(mesh)
	local hx, hy = BATTERY_HALF_X + CRADLE_GAP, BATTERY_HALF_Y + CRADLE_GAP
	local low, high = BATTERY_BOTTOM - 1.6, BATTERY_TOP - 1
	local corners = { { -hx, -hy }, { hx, -hy }, { hx, hy }, { -hx, hy } }
	for k, c in corners do
		local n = corners[k % 4 + 1]
		-- A frame round the bottom and one round the top, joined at the corners.
		strut(mesh, c[1], c[2], low, n[1], n[2], low, CHORD)
		strut(mesh, c[1], c[2], high, n[1], n[2], high, WEB)
		strut(mesh, c[1], c[2], low, c[1], c[2], high, CHORD)
	end
	-- Cross members under the pack.
	for _, x in { -18, 0, 18 } do
		strut(mesh, x, -hy, low, x, hy, low, WEB)
	end
	-- Hangers from the top corners up to the joists, splayed so they meet
	-- the joists running out to the octagon's corners.
	for k, c in corners do
		local jx, jy = corner(40, ({ 4, 7, 0, 3 })[k])
		strut(mesh, c[1], c[2], high, jx, jy, JOIST_BOTTOM, CHORD)
	end
end, nil, paintHazard, GIRDER_TEXTURE, nil, nil, 1)
part("MainCables", nil, RUBBER_BLACK, function(mesh)
	for _, degrees in ARM_DIRECTIONS do
		local angle = math.rad(degrees)
		local ux, uy = math.cos(angle), math.sin(angle)
		local tx, ty = ux * 13 * math.sqrt(2), uy * 10 * math.sqrt(2)
		local _, _, zb = armShape(ARM_ROOT)
		tube(mesh, {
			{ tx, ty, BATTERY_TOP + 2.8 },
			{ tx * 1.3, ty * 1.3, BATTERY_TOP + 4.5 },
			{ ux * 40, uy * 40, JOIST_BOTTOM - 1.5 },
			{ ux * (ARM_ROOT - 2), uy * (ARM_ROOT - 2), zb - 0.9 },
		}, 0.7, 8)
	end
end, true, RUBBER, 256)

-- Landing skids: a steel rail under the north and south sides of the ring,
-- each on two legs that splay out from the ring girder's bottom chord,
-- low enough to clear the battery cradle. The rails turn up at both ends.
local SKID_Z = BATTERY_BOTTOM - 6
local SKID_Y = RING_INNER + 9
local SKID_HALF = 72
local SKID_LEGS = { -42, 42 }
local LEG_THICK = 1.8
local CHORD_BOTTOM = GIRDER_BOTTOM + CHORD / 2
part("SkidLegs", nil, GIRDER, function(mesh)
	for _, side in { -1, 1 } do
		for _, x in SKID_LEGS do
			strut(mesh, x, side * (RING_INNER + 1), CHORD_BOTTOM, x, side * SKID_Y, SKID_Z + 1, LEG_THICK)
			-- A brace from the outer wall down to the leg's middle.
			local midY, midZ = lerp(RING_INNER + 1, SKID_Y, 0.5), lerp(CHORD_BOTTOM, SKID_Z + 1, 0.5)
			strut(mesh, x - math.sign(x) * 10, side * (RING_OUTER - 1), CHORD_BOTTOM, x, side * midY, midZ, WEB)
		end
		-- A tie between the two legs, so each skid stands as one frame.
		local tieY, tieZ = lerp(RING_INNER + 1, SKID_Y, 0.7), lerp(CHORD_BOTTOM, SKID_Z + 1, 0.7)
		strut(mesh, SKID_LEGS[1], side * tieY, tieZ, SKID_LEGS[2], side * tieY, tieZ, WEB)
	end
end, nil, paintHazard, GIRDER_TEXTURE, nil, nil, 1)
part("Skids", nil, DARK_STEEL, function(mesh)
	for _, side in { -1, 1 } do
		local points = {}
		for j = 0, 4 do
			local a = j / 4 * math.pi / 2
			table.insert(points, 1, { -SKID_HALF - math.sin(a) * 6, side * SKID_Y, SKID_Z + (1 - math.cos(a)) * 6 })
		end
		for j = 1, 4 do
			local a = j / 4 * math.pi / 2
			table.insert(points, { SKID_HALF + math.sin(a) * 6, side * SKID_Y, SKID_Z + (1 - math.cos(a)) * 6 })
		end
		tube(mesh, points, 1.3, 12)
		-- Clamps where the legs meet the rail.
		for _, x in SKID_LEGS do
			cylinder(mesh, x, side * SKID_Y, SKID_Z, 1.7, 3, "x", 12)
		end
	end
end, 40, 0.5, 256)

finishParts()
