-- mates: Stack Roof
-- Capsule Loop: the hub's capsule belt and the little factory it runs
-- through, as one model (art/concepts/capsule-loop-sketch.png), at full size
-- in studs. The origin is the middle of the hub at deck level; the layout
-- puts it on the plaza.
-- The belt is one lap of radius BELT_RADIUS. Capsules ride it counter-
-- clockwise: at +X they go in the shed's -Y mouth to be crushed under the
-- press on its roof, and new ones, dropped in through the hopper, come out
-- of its +Y mouth. A black, unlit shade fills each mouth from the inside,
-- so the shed needs no inside.
-- Each mouth is 7 wide and 6.6 tall: a player (4 by 5.5) has 1.5 spare each
-- side and 1.1 overhead, and a riding capsule (3.4 tall, 0.6 up) 2.6.
-- open: Shades, Tread, BeltRails
-- (The belt parts are split into texture chunks, open where the chunks meet.)
-- include: EditMesh
-- include: EditOps
-- include: EditShapes
-- include: HandFinish
useTexelDensity(16)

local BELT_RADIUS, BELT_HALF_WIDTH = 72, 2.5
local BELT_TOP, RAIL_TOP, RAIL_WIDE = 0.6, 0.95, 0.45
-- The shed: its middle out from the hub (so each mouth is centred on the
-- belt where the belt crosses it), half its width and length, its height.
local SHED_X, SHED_HALF_WIDE, SHED_HALF_LONG, SHED_TALL = 71.55, 7, 8, 8.35
local MOUTH_HALF, MOUTH_TALL = 3.5, 6.6
local FRAME = 0.8
-- The roof: its eaves' overhang, the height of its eaves and of its ridge,
-- which runs along the belt.
local ROOF_OVER, EAVES, RIDGE = 0.6, 8.3, 11

local STEEL = { 0.42, 0.5, 0.56 }
local ROOF_STEEL = { 0.3, 0.36, 0.42 }
local DARK_STEEL = { 0.2, 0.21, 0.24 }
local CONCRETE = { 0.62, 0.6, 0.56 }
local YELLOW = { 0.86, 0.64, 0.16 }
local BLACK_PAINT = { 0.08, 0.08, 0.09 }
local RUBBER = { 0.14, 0.14, 0.15 }
local RAIL_STEEL = { 0.36, 0.37, 0.4 }
local ORANGE = { 0.72, 0.4, 0.16 }
local BRASS = { 0.86, 0.68, 0.32 }
local SILVER = { 0.72, 0.74, 0.77 }

-- A steady pseudo-random number in -1..1 for whole numbers a, b.
local function jitter(a: number, b: number): number
	local s = math.sin(a * 127.1 + b * 311.7) * 43758.5453
	return 2 * (s - math.floor(s)) - 1
end
-- Turns a closed mesh's faces outward if they were built facing in.
local function faceOut(m)
	local volume = 0
	for face in m.faces do
		local c, n = m:faceCentre(face), m:faceNormal(face)
		volume += EditMesh.vec.dot(c, n) * m:faceArea(face)
	end
	if volume < 0 then
		m:flip()
	end
end
-- Height of the roof's top `dx` out from the shed's middle.
local function roofAt(dx: number): number
	return RIDGE - math.abs(dx) * (RIDGE - EAVES) / (SHED_HALF_WIDE + ROOF_OVER)
end
-- The last part added gets bold painted rims with a wide soft highlight
-- under them.
local function paintedRims()
	parts[#parts].painted = true
	parts[#parts].blend = 0.7
	parts[#parts].taper = 0.8
	parts[#parts].softLit = 0.18
	parts[#parts].softEdge = 1.2
	parts[#parts].softUneven = 0.6
	parts[#parts].softTaper = 1.5
end
-- Machine finishes (hazard tape, ribbed rubber) go on crisp, texel by
-- texel, instead of as brush strokes that would smear them: the last part,
-- or every chunk of the chunked part `group`.
local function crisp(group: string?)
	for _, entry in parts do
		if (group == nil and entry == parts[#parts]) or (group ~= nil and entry.group == group) then
			entry.crisp = true
		end
	end
end

-- ---------------------------------------------------------- the factory

-- Corrugated steel on a concrete footing: each sheet its own tone, a dark
-- seam with rivets halfway up, rust weeping down from the rivets.
local function shedPaint(x: number, y: number, z: number): (number, number, number)
	if z < 0.5 then
		local k = 0.92 + 0.08 * math.noise(x * 0.8, y * 0.8, 3.1)
		return CONCRETE[1] * k, CONCRETE[2] * k, CONCRETE[3] * k
	end
	local along = if math.abs(x - SHED_X) > SHED_HALF_WIDE - 0.5 then y else x
	local sheet = math.floor(along / 2)
	local k = 0.94 + 0.09 * jitter(sheet, if z > SHED_TALL / 2 then 1 else 2) + 0.09 * math.sin(along * math.pi * 2.5)
	local seam = math.abs(z - SHED_TALL / 2)
	-- The upper sheets lap the lower ones: a row of rivet heads along the
	-- lap, a little rust streaking down from it, no open seam line.
	local rust = math.clamp(0.2 + math.noise(along * 0.5, z * 0.25, 7.3) - 0.3 * seam, 0, 1) * (if seam < 1.5 and z < SHED_TALL / 2 then 0.3 else 0.1)
	local rivet = (along - math.floor(along)) - 0.5
	if seam < 0.12 and math.abs(rivet) < 0.08 then
		k *= 0.72
	end
	return STEEL[1] * k + (0.46 - STEEL[1] * k) * rust, STEEL[2] * k + (0.27 - STEEL[2] * k) * rust, STEEL[3] * k + (0.16 - STEEL[3] * k) * rust
end
part("Shed", nil, STEEL, function(mesh)
	-- The long walls.
	for _, flank in { -1, 1 } do
		box(mesh, SHED_X + flank * (SHED_HALF_WIDE - 0.2), 0, 0, 0.4, 2 * SHED_HALF_LONG, SHED_TALL)
		box(mesh, SHED_X + flank * SHED_HALF_WIDE, 0, 0, 0.9, 2 * SHED_HALF_LONG + 0.9, 0.5)
	end
	-- The end walls, either side of each mouth and over it.
	for _, side in { -1, 1 } do
		local y = side * (SHED_HALF_LONG - 0.2)
		-- Each end panel runs a little into the long wall beside it.
		local wide = SHED_HALF_WIDE - MOUTH_HALF - 0.2
		for _, flank in { -1, 1 } do
			box(mesh, SHED_X + flank * (MOUTH_HALF + wide / 2), y, 0, wide, 0.38, SHED_TALL - 0.02)
			box(mesh, SHED_X + flank * (MOUTH_HALF + wide / 2), side * SHED_HALF_LONG, 0, wide, 0.86, 0.46)
			-- A concrete sill from the jamb to the belt's rail.
			box(mesh, SHED_X + flank * (MOUTH_HALF - 0.45), y, 0, 0.9, 0.3, 0.26)
		end
		box(mesh, SHED_X, y, MOUTH_TALL, 2 * MOUTH_HALF + 0.1, 0.36, SHED_TALL - MOUTH_TALL)
	end
end, nil, shedPaint, nil, nil, true, 0.35)
paintedRims()

part("Roof", nil, ROOF_STEEL, function(mesh)
	local x0, x1 = SHED_X - SHED_HALF_WIDE - ROOF_OVER, SHED_X + SHED_HALF_WIDE + ROOF_OVER
	local y0, y1 = -SHED_HALF_LONG - ROOF_OVER, SHED_HALF_LONG + ROOF_OVER
	local a, b, c = mesh:vertex(x0, y0, EAVES), mesh:vertex(x1, y0, EAVES), mesh:vertex(SHED_X, y0, RIDGE)
	local d, e, f = mesh:vertex(x0, y1, EAVES), mesh:vertex(x1, y1, EAVES), mesh:vertex(SHED_X, y1, RIDGE)
	mesh:face({ a, b, c })
	mesh:face({ d, f, e })
	mesh:face({ a, c, f, d })
	mesh:face({ b, e, f, c })
	mesh:face({ a, d, e, b })
end, nil, function(x, y, z)
	-- Standing seams up each slope, a little rust along the eaves.
	local sheet = math.floor(y / 1.6)
	local k = 0.93 + 0.08 * jitter(sheet, 5) + (if y / 1.6 - sheet < 0.09 then 0.22 else 0)
	local rust = math.clamp(0.55 + 0.7 * math.noise(x * 0.4, y * 0.4, 2.2) - (z - EAVES) * 0.5, 0, 1) * 0.3
	return ROOF_STEEL[1] * k + (0.42 - ROOF_STEEL[1] * k) * rust, ROOF_STEEL[2] * k + (0.25 - ROOF_STEEL[2] * k) * rust, ROOF_STEEL[3] * k + (0.16 - ROOF_STEEL[3] * k) * rust
end, nil, nil, true, 0.35)
paintedRims()

part("Frames", nil, YELLOW, function(mesh)
	for _, side in { -1, 1 } do
		local y = side * (SHED_HALF_LONG + 0.1)
		for _, flank in { -1, 1 } do
			box(mesh, SHED_X + flank * (MOUTH_HALF + FRAME / 2), y, 0, FRAME, 0.6, MOUTH_TALL + FRAME)
		end
		box(mesh, SHED_X, y, MOUTH_TALL + 0.01, 2 * MOUTH_HALF + 0.1, 0.56, FRAME - 0.06)
	end
end, nil, function(x, _y, z)
	-- Factory hazard tape down the uprights: crisp even 45-degree stripes,
	-- no brush marks; the top beam stays yellow.
	if z < MOUTH_TALL and (z + math.abs(x - SHED_X)) % 1.1 < 0.55 then
		return BLACK_PAINT[1], BLACK_PAINT[2], BLACK_PAINT[3]
	end
	return YELLOW[1], YELLOW[2], YELLOW[3]
end, nil, nil, true, 0.12, nil, 0.35)
crisp()

-- Over the -Y mouth a red plate with a capsule squashed flat, over the +Y
-- mouth a green one with a fresh capsule.
local SIGN_Z, SIGN_WIDE, SIGN_TALL = 7.85, 4.5, 1.1
part("Signs", nil, CONCRETE, function(mesh)
	for _, side in { -1, 1 } do
		box(mesh, SHED_X, side * (SHED_HALF_LONG + 0.08), SIGN_Z - SIGN_TALL / 2, SIGN_WIDE, 0.16, SIGN_TALL)
	end
end, nil, function(x, y, z)
	-- A capsule icon about 60% of the plate's height with a dark outline:
	-- whole on the green plate, squashed flat on the red one.
	local u, v = x - SHED_X, z - SIGN_Z
	local fresh = y > 0
	local halfLong, halfTall = if fresh then 0.95 else 1.3, if fresh then 0.33 else 0.17
	local dx = math.max(math.abs(u) - halfLong + halfTall, 0)
	local d = math.sqrt(dx * dx + v * v) - halfTall
	if d < 0 then
		if fresh and u > 0.1 then
			return 0.9, 0.55, 0.15
		end
		return 0.94, 0.92, 0.85
	elseif d < 0.09 then
		return 0.1, 0.1, 0.1
	end
	-- Bold arrows pressing the crushed one flat from above and below.
	if not fresh then
		local av = math.abs(v)
		if av > 0.28 and av < 0.5 and math.abs(u) < (0.5 - av) * 1.6 + 0.08 then
			return 0.94, 0.92, 0.85
		end
	end
	if fresh then
		return 0.2, 0.42, 0.26
	end
	return 0.55, 0.16, 0.13
end, nil, nil, true, 0.1)
crisp()

part("Curtains", nil, RUBBER, function(mesh)
	-- Strips over each mouth, from the frame down to just over the rails.
	for _, side in { -1, 1 } do
		for k = -6, 6 do
			local long = 0.25 * jitter(k, side)
			-- Alternate strips hang a hair further out, overlapping their
			-- neighbours like a real strip curtain.
			local y = side * (SHED_HALF_LONG - 0.15 - 0.06 * (k % 2))
			box(mesh, SHED_X + k * 0.54, y, RAIL_TOP + 0.1 + long, 0.62, 0.08, MOUTH_TALL - RAIL_TOP - 0.1 - long)
		end
	end
end, nil, function(x, _y, z)
	local k = 0.75 + 0.3 * math.noise(x * 3.1, z * 0.6, 8.2)
	return RUBBER[1] * k, RUBBER[2] * k, RUBBER[3] * k
end, nil, nil, true, 0.08)

-- Each mouth's shade: the opening's own shape drawn in a hair, from just
-- inside the frame SHADE_DEPTH in, closed at the far end and open at the
-- mouth, its faces turned inward. Black and unlit, clear at the mouth and
-- fully black SHADE_OPAQUE in.
local SHADE_DEPTH, SHADE_OPAQUE = 6, 4.5
local SHADE_MOUTH = SHED_HALF_LONG - 0.25
part("Shades", nil, { 0, 0, 0 }, function(mesh)
	for _, side in { -1, 1 } do
		local m = EditMesh.new()
		local half, top = MOUTH_HALF - 0.04, MOUTH_TALL - 0.04
		local outline = { { -half, 0.02 }, { -half, top }, { half, top }, { half, 0.02 } }
		local STEPS = 6
		local rings = {}
		for k = 0, STEPS do
			local ring = {}
			for i, p in outline do
				ring[i] = m:addVertex(SHED_X + p[1], side * (SHADE_MOUTH - SHADE_DEPTH * k / STEPS), p[2])
			end
			rings[k] = ring
		end
		for k = 0, STEPS - 1 do
			for i = 1, 4 do
				local j = i % 4 + 1
				m:addFace({ rings[k][j], rings[k][i], rings[k + 1][i], rings[k + 1][j] })
			end
		end
		local back = rings[STEPS]
		m:addFace({ back[4], back[3], back[2], back[1] })
		faceOut(m)
		m:flip()
		m:emit(mesh)
	end
end, nil, function(_x, y)
	return 0, 0, 0, math.clamp((SHADE_MOUTH - math.abs(y)) / SHADE_OPAQUE, 0, 1)
end, nil, 1, true)

-- The crusher: a squat housing on four legs, its ram going down through the
-- ridge over the -Y mouth.
local PRESS_Y, PRESS_HALF, PRESS_BASE, PRESS_TOP = -4, 2.25, 12.4, 15.5
part("Press", nil, DARK_STEEL, function(mesh)
	box(mesh, SHED_X, PRESS_Y, PRESS_BASE, 2 * PRESS_HALF, 2 * PRESS_HALF, PRESS_TOP - PRESS_BASE - 1)
	-- A shallow hip cap.
	local z0, z1 = PRESS_TOP - 1, PRESS_TOP + 0.45
	local lo, hi = PRESS_HALF + 0.15, PRESS_HALF - 1.4
	local a1, a2, a3, a4 = mesh:vertex(SHED_X - lo, PRESS_Y - lo, z0), mesh:vertex(SHED_X + lo, PRESS_Y - lo, z0), mesh:vertex(SHED_X + lo, PRESS_Y + lo, z0), mesh:vertex(SHED_X - lo, PRESS_Y + lo, z0)
	local b1, b2, b3, b4 = mesh:vertex(SHED_X - hi, PRESS_Y - hi, z1), mesh:vertex(SHED_X + hi, PRESS_Y - hi, z1), mesh:vertex(SHED_X + hi, PRESS_Y + hi, z1), mesh:vertex(SHED_X - hi, PRESS_Y + hi, z1)
	mesh:face({ a1, a2, b2, b1 })
	mesh:face({ a2, a3, b3, b2 })
	mesh:face({ a3, a4, b4, b3 })
	mesh:face({ a4, a1, b1, b4 })
	mesh:face({ b1, b2, b3, b4 })
	mesh:face({ a4, a3, a2, a1 })
	-- Stiffening ribs up each face of the housing.
	for _, offset in { -1.5, 1.5 } do
		for _, side in { -1, 1 } do
			box(mesh, SHED_X + offset, PRESS_Y + side * (PRESS_HALF + 0.05), PRESS_BASE, 0.55, 0.2, PRESS_TOP - PRESS_BASE - 1)
			box(mesh, SHED_X + side * (PRESS_HALF + 0.05), PRESS_Y + offset, PRESS_BASE, 0.2, 0.55, PRESS_TOP - PRESS_BASE - 1)
		end
	end
	-- The ram, down through the ridge, with a collar where it enters the housing.
	cylinder(mesh, SHED_X, PRESS_Y, (PRESS_BASE + roofAt(0)) / 2, 0.95, PRESS_BASE - roofAt(0), "z", 16)
	ring(mesh, SHED_X, PRESS_Y, PRESS_BASE - 0.2, 0.9, 1.35, 0.4, "z", 16)
	-- A skirt where the housing meets the roof's slope.
	for _, a in { -1, 1 } do
		box(mesh, SHED_X + a * PRESS_HALF, PRESS_Y, roofAt(PRESS_HALF) + 0.02, 0.5, 2 * PRESS_HALF + 0.3, PRESS_BASE - roofAt(PRESS_HALF) - 0.02)
		box(mesh, SHED_X, PRESS_Y + a * PRESS_HALF, roofAt(0) + 0.02, 2 * PRESS_HALF + 0.3, 0.5, PRESS_BASE - roofAt(0) - 0.02)
	end
	-- The housing's frame: corner angles, a band round its middle and a
	-- hydraulic cylinder bolted to each side.
	local middle = (PRESS_BASE + PRESS_TOP - 1) / 2
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			box(mesh, SHED_X + a * (PRESS_HALF + 0.05), PRESS_Y + b * (PRESS_HALF + 0.05), PRESS_BASE, 0.34, 0.34, PRESS_TOP - 1 - PRESS_BASE)
		end
		cylinder(mesh, SHED_X + a * (PRESS_HALF + 0.42), PRESS_Y, middle, 0.34, 2.4, "z", 12)
		box(mesh, SHED_X + a * (PRESS_HALF + 0.14), PRESS_Y, middle + 1, 0.3, 0.9, 0.22)
		box(mesh, SHED_X + a * (PRESS_HALF + 0.14), PRESS_Y, middle - 1.2, 0.3, 0.9, 0.22)
		box(mesh, SHED_X, PRESS_Y + a * (PRESS_HALF + 0.05), middle - 0.12, 2 * PRESS_HALF + 0.6, 0.22, 0.26)
		box(mesh, SHED_X + a * (PRESS_HALF + 0.05), PRESS_Y, middle - 0.12, 0.22, 2 * PRESS_HALF + 0.6, 0.26)
	end
end, nil, function(x, y, z)
	if z < PRESS_BASE - 0.2 and math.sqrt((x - SHED_X) ^ 2 + (y - PRESS_Y) ^ 2) < 1 then
		local k = 0.9 + 0.12 * math.sin(z * 9)
		return SILVER[1] * k, SILVER[2] * k, SILVER[3] * k
	end
	-- The cap lighter than the housing, so its pitch shows from below.
	if z > PRESS_TOP - 1.02 then
		local k = 1 + 0.08 * math.noise(x * 0.8, y * 0.8, 2.6)
		return RAIL_STEEL[1] * k, RAIL_STEEL[2] * k, RAIL_STEEL[3] * k
	end
	-- A hazard tape band round the housing's foot, crisp like the frames'.
	if z > PRESS_BASE + 0.3 and z < PRESS_BASE + 0.8 and (x + y) % 1 < 0.5 then
		return YELLOW[1], YELLOW[2], YELLOW[3]
	end
	local k = 0.95 + 0.12 * math.noise(x * 0.8, y * 0.8, z * 0.8)
	return DARK_STEEL[1] * k, DARK_STEEL[2] * k, DARK_STEEL[3] * k
end, nil, nil, true, 0.3, nil, 0.6)
crisp()

-- The maker: a funnel on legs, a chute going down through the ridge over
-- the +Y mouth.
local HOPPER_Y, HOPPER_HALF, CHUTE_HALF, HOPPER_FOOT, HOPPER_TOP = 4, 2.75, 0.8, 11.6, 15
part("Hopper", nil, ORANGE, function(mesh)
	local function square(half, z)
		return {
			mesh:vertex(SHED_X - half, HOPPER_Y - half, z), mesh:vertex(SHED_X + half, HOPPER_Y - half, z),
			mesh:vertex(SHED_X + half, HOPPER_Y + half, z), mesh:vertex(SHED_X - half, HOPPER_Y + half, z),
		}
	end
	local low, high = square(CHUTE_HALF, HOPPER_FOOT), square(HOPPER_HALF, HOPPER_TOP)
	for i = 1, 4 do
		local j = i % 4 + 1
		mesh:face({ low[i], low[j], high[j], high[i] })
	end
	mesh:face({ high[1], high[2], high[3], high[4] })
	mesh:face({ low[4], low[3], low[2], low[1] })
	box(mesh, SHED_X, HOPPER_Y, roofAt(0) - 0.3, 1.5, 1.5, HOPPER_FOOT - roofAt(0) + 0.3)
	-- The collar where the chute goes through the ridge.
	box(mesh, SHED_X, HOPPER_Y, roofAt(0) - 0.05, 2.7, 2.7, 0.42)
	-- The rim round its mouth.
	for _, a in { -1, 1 } do
		box(mesh, SHED_X + a * HOPPER_HALF, HOPPER_Y, HOPPER_TOP - 0.15, 0.3, 2 * HOPPER_HALF + 0.3, 0.3)
		box(mesh, SHED_X, HOPPER_Y + a * HOPPER_HALF, HOPPER_TOP - 0.14, 2 * HOPPER_HALF - 0.2, 0.28, 0.28)
	end
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			local dx, dy = a * 2.1, b * 2.1
			strut(mesh, SHED_X + dx, HOPPER_Y + dy, roofAt(dx) - 0.15, SHED_X + dx * 0.95, HOPPER_Y + dy * 0.95, 14.1, 0.3)
			-- A foot plate bolted to the roof under each leg.
			box(mesh, SHED_X + dx, HOPPER_Y + dy, roofAt(dx) - 0.06, 1.0, 1.0, 0.18)
		end
	end
end, nil, function(x, y, z)
	-- The hopper's mouth is dark inside.
	if z > HOPPER_TOP - 0.05 and math.max(math.abs(x - SHED_X), math.abs(y - HOPPER_Y)) < HOPPER_HALF - 0.12 then
		return 0.05, 0.05, 0.06
	end
	local k = 0.92 + 0.14 * math.noise(x * 0.7, y * 0.7, z * 0.7)
	return ORANGE[1] * k, ORANGE[2] * k, ORANGE[3] * k
end, nil, nil, true, 0.3)
paintedRims()

local STACK_X, STACK_Y, STACK_R, STACK_TOP = SHED_X + 4.9, 5, 1, 16
part("Stack", nil, DARK_STEEL, function(mesh)
	local foot = roofAt(4.9) + 0.02
	cylinder(mesh, STACK_X, STACK_Y, (foot + STACK_TOP) / 2, STACK_R, STACK_TOP - foot, "z", 16)
	ring(mesh, STACK_X, STACK_Y, STACK_TOP - 0.45, STACK_R * 0.8, STACK_R + 0.18, 0.7, "z", 16)
	ring(mesh, STACK_X, STACK_Y, roofAt(4.9) + 0.15, STACK_R * 0.8, STACK_R + 0.3, 0.3, "z", 16)
end, nil, function(x, y, z)
	-- A banded top, sooty over it, and dark inside the lip.
	if z > STACK_TOP - 0.05 and math.sqrt((x - STACK_X) ^ 2 + (y - STACK_Y) ^ 2) < STACK_R then
		return 0.03, 0.03, 0.04
	end
	if z > STACK_TOP - 0.8 then
		return YELLOW[1], YELLOW[2], YELLOW[3]
	end
	local soot = math.clamp((z - 12) / 3, 0, 1) * 0.5
	local k = (0.95 + 0.1 * math.noise(x * 0.8, y * 0.8, z * 0.8)) * (1 - soot)
	return DARK_STEEL[1] * k, DARK_STEEL[2] * k, DARK_STEEL[3] * k
end, nil, nil, true, 0.3)
paintedRims()

part("Pipes", nil, RAIL_STEEL, function(mesh)
	-- Press to hopper along the ridge's far slope, hopper to stack.
	local function clip(dx, y, z)
		box(mesh, SHED_X + dx, y, roofAt(dx) - 0.1, 0.3, 0.3, z - roofAt(dx) + 0.1)
	end
	tube(mesh, { { SHED_X + PRESS_HALF - 0.1, PRESS_Y, 13.4 }, { SHED_X + 3.3, PRESS_Y, 13.4 }, { SHED_X + 3.5, PRESS_Y + 0.5, 11.2 }, { SHED_X + 3.5, HOPPER_Y - 0.9, 11.2 }, { SHED_X + 3.2, HOPPER_Y - 0.2, 13.2 }, { SHED_X + 1.75, HOPPER_Y, 13.2 } }, 0.2, 8)
	tube(mesh, { { SHED_X + 2.2, HOPPER_Y + 0.6, 14.1 }, { SHED_X + 3.3, HOPPER_Y + 0.8, 14.1 }, { STACK_X - 0.9, STACK_Y, 14.1 } }, 0.24, 8)
	-- A flanged elbow into the stack, on a bracket, and one at the hopper.
	cylinder(mesh, STACK_X - STACK_R - 0.05, STACK_Y, 14.1, 0.36, 0.3, "x", 10)
	cylinder(mesh, SHED_X + 2.25, HOPPER_Y + 0.6, 14.1, 0.36, 0.3, "x", 10)
	box(mesh, STACK_X - STACK_R - 0.05, STACK_Y, roofAt(STACK_X - STACK_R - 0.05 - SHED_X) - 0.1, 0.3, 0.3, 14.1 - roofAt(STACK_X - STACK_R - 0.05 - SHED_X) + 0.1)
	for _, y in { PRESS_Y + 2, 0, HOPPER_Y - 2 } do
		clip(3.5, y, 11.2)
	end
end, nil, 0.4, nil, nil, true, 0.15)

-- The sketch's cogs, on the shed's outer wall: a big gear and a small one
-- meshing with it on a riveted backing plate, each on a bossed hub.
local DRIVE_X = SHED_X + SHED_HALF_WIDE + 0.32
local BIG_Y, BIG_Z, BIG_R = -1.5, 3.8, 2.3
local SMALL_Y, SMALL_Z, SMALL_R = 1.6, 3.8, 1.05
part("DrivePlate", nil, DARK_STEEL, function(mesh)
	box(mesh, DRIVE_X - 0.2, (BIG_Y + SMALL_Y) / 2, 1.2, 0.18, 7.6, 5.6)
	for _, y in { -3.1, 0.25, 3.6 } do
		for _, z in { 1.5, 6.4 } do
			bolt(mesh, DRIVE_X - 0.08, y, z, "x", 0.14)
		end
	end
end, nil, 0.3, nil, nil, true, 0.2)
part("DriveGears", nil, BRASS, function(mesh)
	gear(mesh, DRIVE_X, BIG_Y, BIG_Z, BIG_R, 0.4, 14, "x")
	gear(mesh, DRIVE_X, SMALL_Y, SMALL_Z, SMALL_R, 0.4, 9, "x")
	for _, spot in { { BIG_Y, BIG_Z, 0.55 }, { SMALL_Y, SMALL_Z, 0.32 } } do
		cylinder(mesh, DRIVE_X + 0.1, spot[1], spot[2], spot[3], 0.7, "x", 14)
	end
	-- The bar that ties the two axles together, over the hubs.
	box(mesh, DRIVE_X + 0.48, (BIG_Y + SMALL_Y) / 2, BIG_Z - 0.17, 0.16, SMALL_Y - BIG_Y + 0.7, 0.34)
end, nil, 0.3, nil, nil, true, 0.14)

-- The drive on the shed's outer wall: a big spoked gear and a small one
-- meshing with it on a riveted backing plate, each on a bossed hub, a
-- guard bar over the top of the big one.
part("Beacons", nil, { 1, 0.6, 0.15 }, function(mesh)
	for _, side in { -1, 1 } do
		for _, flank in { -1, 1 } do
			sphere(mesh, SHED_X + flank * (MOUTH_HALF + FRAME / 2), side * (SHED_HALF_LONG + 0.1), MOUTH_TALL + FRAME + 0.3, 0.32, 0.32, 0.32, 6, 10)
		end
	end
end, true, 0, nil, 1.5)

-- ------------------------------------------------------------- the belt

-- A flat ring round the hub, from radius `inner` to `outer`, between heights
-- `base` and `top`: one closed lap in BELT_STEP-degree quads.
local BELT_STEP = 2
local function ringStrip(mesh, inner: number, outer: number, base: number, top: number)
	local rows = {}
	for d = 0, 360 - BELT_STEP, BELT_STEP do
		local c, s = math.cos(math.rad(d)), math.sin(math.rad(d))
		table.insert(rows, { mesh:vertex(c * inner, s * inner, base), mesh:vertex(c * outer, s * outer, base), mesh:vertex(c * outer, s * outer, top), mesh:vertex(c * inner, s * inner, top) })
	end
	for i, a in rows do
		local b = rows[i % #rows + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[l], a[k], b[k], b[l] })
		end
	end
end
chunkedPart("Tread", nil, RUBBER, function(mesh)
	ringStrip(mesh, BELT_RADIUS - BELT_HALF_WIDTH, BELT_RADIUS + BELT_HALF_WIDTH, 0.3, BELT_TOP)
end, nil, function(x, y)
	-- Hard cross ribs every stud (the texture holds about 16 texels a stud,
	-- so each rib is a few texels wide), a clear lighter band down the middle
	-- where capsules ride, and a few faint scuffs.
	local out = math.sqrt(x * x + y * y) - BELT_RADIUS
	local along = math.atan2(y, x) * BELT_RADIUS
	local rib = along % 1
	local k = if rib < 0.4 then 1.25 else 1
	if math.abs(out) < 1.1 then
		k += 0.12
	end
	local scuff = math.noise(along * 0.4, out * 1.3, 6.1)
	if scuff > 0.45 then
		k += 0.08
	end
	return RUBBER[1] * k, RUBBER[2] * k, RUBBER[3] * k
end, true, 0.2)
crisp("Tread")
chunkedPart("BeltRails", nil, RAIL_STEEL, function(mesh)
	for _, flank in { -1, 1 } do
		local r = BELT_RADIUS + flank * (BELT_HALF_WIDTH + RAIL_WIDE / 2)
		ringStrip(mesh, r - RAIL_WIDE / 2, r + RAIL_WIDE / 2, 0, RAIL_TOP)
	end
end, nil, function(x, y, z)
	local along = math.atan2(y, x) * BELT_RADIUS
	local k = 0.74 + 0.1 * math.noise(along * 0.3, z * 2, 5.5) + (if z > RAIL_TOP - 0.05 then 0.5 else 0)
	local rust = math.clamp(0.3 + math.noise(along * 0.12, z, 9.9), 0, 1) * (if z > RAIL_TOP - 0.05 then 0.05 else 0.35)
	return RAIL_STEEL[1] * k + (0.42 - RAIL_STEEL[1] * k) * rust, RAIL_STEEL[2] * k + (0.25 - RAIL_STEEL[2] * k) * rust, RAIL_STEEL[3] * k + (0.16 - RAIL_STEEL[3] * k) * rust
end, true, 0.15)
crisp("BeltRails")
part("BeltFeet", nil, DARK_STEEL, function(mesh)
	-- A little anchor plate outside each rail every FOOT_STEP degrees.
	local FOOT_STEP = 5
	for d = 0, 360 - FOOT_STEP, FOOT_STEP do
		local a = math.rad(d)
		for _, flank in { -1, 1 } do
			local r = BELT_RADIUS + flank * (BELT_HALF_WIDTH + RAIL_WIDE + 0.2)
			local cx, cy = math.cos(a) * r, math.sin(a) * r
			-- Skipped under the shed, where it would stand in the footing.
			if math.abs(cy) > SHED_HALF_LONG + 0.5 or cx < 0 then
				local tx, ty = -math.sin(a) * 0.3, math.cos(a) * 0.3
				local ox, oy = math.cos(a) * 0.35, math.sin(a) * 0.35
				local p = {
					mesh:vertex(cx - ox - tx, cy - oy - ty, 0), mesh:vertex(cx + ox - tx, cy + oy - ty, 0), mesh:vertex(cx + ox + tx, cy + oy + ty, 0), mesh:vertex(cx - ox + tx, cy - oy + ty, 0),
					mesh:vertex(cx - ox - tx, cy - oy - ty, 0.22), mesh:vertex(cx + ox - tx, cy + oy - ty, 0.22), mesh:vertex(cx + ox + tx, cy + oy + ty, 0.22), mesh:vertex(cx - ox + tx, cy - oy + ty, 0.22),
				}
				mesh:face({ p[5], p[6], p[7], p[8] })
				mesh:face({ p[4], p[3], p[2], p[1] })
				mesh:face({ p[1], p[2], p[6], p[5] })
				mesh:face({ p[2], p[3], p[7], p[6] })
				mesh:face({ p[3], p[4], p[8], p[7] })
				mesh:face({ p[4], p[1], p[5], p[8] })
			end
		end
	end
end, nil, 0.3, nil, nil, true)
-- The shed's seams are its look; a full contact shadow would outline every
-- panel, and the belt's ribs would dash the rails.
for _, entry in parts do
	if entry.name == "Shed" or entry.name == "Roof" then
		entry.shade = 1
	elseif string.match(entry.name, "^BeltRails") then
		entry.shade = 0.5
	end
end
handFinish({
	Shed = "metal",
	Roof = "metal",
	Frames = "metal",
	Signs = "rock",
	Curtains = "rock",
	Press = "metal",
	Hopper = "metal",
	Stack = "metal",
	Pipes = "metal",
	DrivePlate = "metal",
	DriveGears = "metal",
	Tread = "rock",
	BeltRails = "metal",
	BeltFeet = "metal",
}, {
	Shades = true,
	Beacons = true,
}, PROP_FINISH)
-- Seam rust on the crisp rails dashes their edges.
for _, entry in parts do
	if string.match(entry.name, "^BeltRails") then
		entry.rustEdges = false
	end
end
finishParts()
