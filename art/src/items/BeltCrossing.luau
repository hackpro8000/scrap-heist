-- Belt Crossing: a footbridge over the capsule belt, with stairs both ways
-- (art/concepts/town-pieces-sketch.png, plan in BeltCrossing.plan.luau). Local x
-- runs across the belt, whose middle is at x = 0. A riding capsule reaches 4.0
-- and the deck's underside is at 4.75.
-- include: HandFinish
-- include: TownClutter
useTexelDensity(32)

local STEEL = { 0.44, 0.5, 0.56 }
local TREAD = { 0.36, 0.38, 0.41 }
local CHEQUER = { 0.5, 0.53, 0.57 }
local SEAM = { 0.15, 0.16, 0.19 }
local YELLOW = { 0.86, 0.66, 0.18 }
local PIPE = { 0.23, 0.24, 0.28 }

local SPAN_HALF, HALF_WIDE = 3.5, 4
local UNDERSIDE, DECK_TOP = 4.75, 5.25
local FLIGHT, STEPS = 7, 10
local RAIL_Y, DECK_RAIL, STAIR_RAIL = 3.8, 3.2, 2.8
local LEG_X, LEG_Y, BEAM_DEEP = 3.7, 3.5, 0.5
local GOING = FLIGHT / STEPS

-- Raised diamonds on a chequer plate.
local function onChequer(u: number, v: number): boolean
	local size = 0.34
	local fu, fv = (u / size) % 2, (v / size) % 2
	local cellU, cellV = math.floor(fu), math.floor(fv)
	local a, b = math.abs(fu - cellU - 0.5), math.abs(fv - cellV - 0.5)
	if (cellU + cellV) % 2 == 0 then
		return a < 0.4 and b < 0.14
	end
	return a < 0.14 and b < 0.4
end

part("Span", nil, STEEL, function(mesh)
	box(mesh, 0, 0, UNDERSIDE, SPAN_HALF * 2, HALF_WIDE * 2, DECK_TOP - UNDERSIDE)
	-- A splice bearer under the join, clear of riding capsules.
	box(mesh, 0, 0, UNDERSIDE - 0.2, 1, 7.8, 0.22)
	-- Cross stiffeners and edge beams, the lowest at 4.5.
	for _, x in { -1.9, 1.9 } do
		box(mesh, x, 0, UNDERSIDE - 0.24, 0.3, 7.8, 0.26)
	end
	for _, y in { -3.8, 3.8 } do
		box(mesh, 0, y, UNDERSIDE - 0.24, 6.8, 0.3, 0.26)
	end
	-- Shallow ribs across the middle, and the frames of the two deck plates.
	for _, y in { -2.4, -1, 1, 2.4 } do
		box(mesh, 0, y, UNDERSIDE - 0.2, 6.4, 0.2, 0.22)
	end
	box(mesh, -1.8, 1.4, UNDERSIDE - 0.1, 1.7, 1.4, 0.12)
	box(mesh, 1.3, -0.7, UNDERSIDE - 0.1, 2.2, 1.8, 0.12)
	for y = -3.4, 3.4, 1.7 do
		for _, x in { -3.1, 0.22, 3.1 } do
			bolt(mesh, x, y, DECK_TOP, "z", 0.08)
		end
	end
end, nil, function(x, y, z)
	if z < DECK_TOP - 0.1 then
		return STEEL[1], STEEL[2], STEEL[3]
	end
	if math.abs(x) < 0.05 then
		return SEAM[1], SEAM[2], SEAM[3]
	end
	-- Worn bright along the walked line from one stair head to the other.
	local walked = math.abs(y) < 2.1 and math.noise(x * 0.9, y * 1.2, 2) + (2.1 - math.abs(y)) * 0.35 > 0.25
	if onChequer(x, y) then
		if walked then
			return 0.5, 0.52, 0.54
		end
		return CHEQUER[1], CHEQUER[2], CHEQUER[3]
	end
	if walked then
		return 0.46, 0.48, 0.51
	end
	return TREAD[1], TREAD[2], TREAD[3]
end)
parts[#parts].crisp = true

part("Stairs", nil, TREAD, function(mesh)
	local rise = DECK_TOP / STEPS
	for _, side in { -1, 1 } do
		for step = 1, STEPS do
			local x = side * (SPAN_HALF + FLIGHT - (step - 0.5) * GOING)
			box(mesh, x, 0, rise * step - 0.2, GOING, HALF_WIDE * 2 - 0.3, 0.2)
		end
		for _, y in { -3.9, 3.9 } do
			strut(mesh, side * (SPAN_HALF + FLIGHT), y, 0, side * SPAN_HALF, y, DECK_TOP - 0.1, 0.22)
			-- A bolted foot, and a bracket onto the deck edge.
			box(mesh, side * (SPAN_HALF + FLIGHT - 0.15), y, 0, 0.9, 0.5, 0.1)
			box(mesh, side * (SPAN_HALF + 0.05), y, DECK_TOP - 0.75, 0.4, 0.34, 0.6)
			-- A post under the middle of the flight, footed and bracketed to the stringer.
			local midX = side * (SPAN_HALF + FLIGHT * 0.5)
			box(mesh, midX, y, 0, 0.26, 0.26, DECK_TOP * 0.5 - 0.02)
			box(mesh, midX, y, 0, 0.7, 0.5, 0.1)
			box(mesh, midX, y, DECK_TOP * 0.5 - 0.3, 0.46, 0.34, 0.34)
		end
	end
end, nil, function(x, y, z)
	if math.abs(y) > 3.72 then
		return TREAD[1], TREAD[2], TREAD[3]
	end
	-- The treads' undersides are bare, darker steel.
	local phase = z % (DECK_TOP / STEPS)
	if phase > 0.14 and phase < 0.42 then
		return 0.24, 0.25, 0.28
	end
	-- Yellow painted nosing along each tread, worn through where feet land.
	local along = (math.abs(x) - SPAN_HALF) % GOING
	if along > GOING - 0.16 or along < 0.02 then
		local worn = math.abs(y) < 2.3 and math.noise(x * 4, y * 2.5, 3) + (2.3 - math.abs(y)) * 0.18 > 0.15
		if worn then
			return 0.58, 0.6, 0.63
		end
		return YELLOW[1], YELLOW[2], YELLOW[3]
	end
	if onChequer(x, y) then
		return CHEQUER[1], CHEQUER[2], CHEQUER[3]
	end
	return TREAD[1], TREAD[2], TREAD[3]
end)
parts[#parts].crisp = true

part("Railings", nil, PIPE, function(mesh)
	local outer = SPAN_HALF + FLIGHT
	-- The rail's height at a point along it, and the floor beneath it.
	local function floorAt(x: number): number
		local out = math.abs(x)
		return if out <= SPAN_HALF then DECK_TOP else DECK_TOP * (1 - (out - SPAN_HALF) / FLIGHT)
	end
	for _, y in { -RAIL_Y, RAIL_Y } do
		for _, share in { 1, 0.52 } do
			local points = {
				{ -outer, y, STAIR_RAIL * share },
				{ -SPAN_HALF, y, DECK_TOP + DECK_RAIL * share },
				{ SPAN_HALF, y, DECK_TOP + DECK_RAIL * share },
				{ outer, y, STAIR_RAIL * share },
			}
			tube(mesh, roundedPath(points, 0.5, 3), if share == 1 then 0.1 else 0.06, 8)
		end
		for _, side in { -1, 1 } do
			for k = 0, 3 do
				local x = side * (SPAN_HALF + FLIGHT * k / 3)
				local floor = floorAt(x)
				local high = STAIR_RAIL + (DECK_RAIL - STAIR_RAIL) * (1 - k / 3)
				local thick = if k == 0 then 0.2 else 0.12
				box(mesh, x, y, floor - 0.02, thick, thick, high)
			end
		end
	end
end, nil, 0.1)

part("Legs", nil, PIPE, function(mesh)
	for _, x in { -LEG_X, LEG_X } do
		for _, y in { -LEG_Y, LEG_Y } do
			box(mesh, x + math.sign(x) * 0.15, y, 0, 1, 1.3, 0.12)
			for _, cx in { -0.3, 0.6 } do
				for _, cy in { -0.48, 0.48 } do
					bolt(mesh, x + math.sign(x) * cx, y + cy, 0.12, "z", 0.08)
				end
			end
			box(mesh, x, y, 0.1, 0.6, 0.6, UNDERSIDE - BEAM_DEEP - 0.08)
			strut(mesh, x, y, UNDERSIDE - BEAM_DEEP - 0.9, x, y - math.sign(y) * 0.9, UNDERSIDE - BEAM_DEEP - 0.02, 0.16)
		end
		-- A beam across each pair of legs carries the deck edge and the stair
		-- head, and a brace between the legs stops them racking.
		box(mesh, x, 0, UNDERSIDE - BEAM_DEEP, 0.72, 7.9, BEAM_DEEP + 0.02)
		strut(mesh, x, -LEG_Y, 0.6, x, LEG_Y, UNDERSIDE - BEAM_DEEP - 0.1, 0.16)
	end
end, nil, function(_x, y, z)
	-- Hazard bands round the feet, where a capsule might clip them.
	if z < 1.4 and z > 0.13 and math.abs(y) > 2.9 then
		if (z + y) % 0.7 < 0.35 then
			return 0.08, 0.08, 0.09
		end
		return 0.86, 0.66, 0.18
	end
	return PIPE[1], PIPE[2], PIPE[3]
end)
parts[#parts].crisp = true

-- The lived-in layer: kick plates, a cable tray under the deck, a warning sign
-- and lamps at the deck corners.
part("Fittings", nil, { 0.3, 0.32, 0.36 }, function(mesh)
	for _, y in { -3.68, 3.68 } do
		box(mesh, 0, y, DECK_TOP, SPAN_HALF * 2, 0.1, 0.32)
	end
	-- A cable tray along the deck's underside, clear of riding capsules.
	box(mesh, 2.6, 0, UNDERSIDE - 0.22, 0.6, 7.6, 0.24)
	cylinder(mesh, 2.6, 0, UNDERSIDE - 0.12, 0.09, 7.6, "y", 6)
	-- A junction box on one leg, with conduit up to the deck and out to both
	-- lamp posts, and one patched tread plate.
	box(mesh, LEG_X, -LEG_Y + 0.56, 2.1, 0.5, 0.5, 0.8)
	cylinder(mesh, LEG_X, -LEG_Y + 0.56, 3.6, 0.07, 2.2, "z", 6)
	cylinder(mesh, 0, 3.66, DECK_TOP + 0.5, 0.06, 7, "x", 6)
	cylinder(mesh, 0, -3.66, DECK_TOP + 0.5, 0.06, 7, "x", 6)
	box(mesh, -1.8, 1.4, DECK_TOP, 1.5, 1.2, 0.05)
	for _, cx in { -0.6, 0.6 } do
		for _, cy in { -0.45, 0.45 } do
			bolt(mesh, -1.8 + cx, 1.4 + cy, DECK_TOP + 0.05, "z", 0.08)
		end
	end
	-- A welded repair in the walked lane, and stiffeners along each fascia.
	box(mesh, 1.3, -0.7, DECK_TOP, 2, 1.6, 0.04)
	for _, y in { -4.05, 4.05 } do
		for x = -3, 3, 1.5 do
			box(mesh, x, y, UNDERSIDE - 0.02, 0.18, 0.14, 0.54)
		end
		box(mesh, 0, y, UNDERSIDE + 0.2, 6.8, 0.14, 0.14)
	end
	cylinder(mesh, -2.6, 0, UNDERSIDE - 0.16, 0.08, 7.6, "y", 6)
	-- Clamps holding the warning sign to the mid rail.
	for _, x in { -1.2, 1.2 } do
		box(mesh, x, -RAIL_Y - 0.1, DECK_TOP + 1.55, 0.3, 0.3, 0.4)
	end
	-- Lamp posts on two deck corners.
	for _, x in { -SPAN_HALF, SPAN_HALF } do
		cylinder(mesh, x, x * 1.086, DECK_TOP + 2.3, 0.1, 4.6, "z", 6)
		cylinder(mesh, x, x * 1.086, DECK_TOP + 0.12, 0.2, 0.24, "z", 8)
		box(mesh, x, x * 1.086, DECK_TOP + 4.6, 0.7, 0.7, 0.14)
		box(mesh, x, x * 1.086, DECK_TOP + 5.36, 0.7, 0.7, 0.14)
		for _, cx in { -0.3, 0.3 } do
			box(mesh, x + cx, x * 1.086 + cx, DECK_TOP + 4.7, 0.06, 0.06, 0.7)
		end
	end
end, nil, 0.1)

part("WarningSign", nil, YELLOW, function(mesh)
	box(mesh, 0, -RAIL_Y - 0.12, DECK_TOP + 1.3, 3, 0.1, 1.1)
end, nil, function(x, y, z)
	-- A printed warning triangle with its bar and dot, on the front only.
	if y > -RAIL_Y - 0.1 then
		return 0.44, 0.46, 0.5
	end
	local v = z - (DECK_TOP + 1.42)
	local inside = v > 0 and v < 0.86 and math.abs(x) < 0.5 * (1 - v / 0.86)
	local outer = v > -0.06 and v < 0.96 and math.abs(x) < 0.62 * (1 - (v + 0.06) / 1.02)
	if outer and not inside then
		return 0.08, 0.08, 0.09
	end
	if inside and math.abs(x) < 0.06 and ((v > 0.28 and v < 0.62) or (v > 0.12 and v < 0.22)) then
		return 0.08, 0.08, 0.09
	end
	return YELLOW[1], YELLOW[2], YELLOW[3]
end)
parts[#parts].crisp = true


part("Bulbs", nil, { 1, 0.84, 0.48 }, function(mesh)
	for _, x in { -SPAN_HALF, SPAN_HALF } do
		cylinder(mesh, x, x * 1.086, DECK_TOP + 5.05, 0.26, 0.62, "z", 10)
	end
end, true, 0, nil, 0.9)

handFinish({ Fittings = "metal", Span = "metal", Railings = "metal", Legs = "metal", Stairs = "metal" }, { WarningSign = true, Bulbs = true })

finishParts()
