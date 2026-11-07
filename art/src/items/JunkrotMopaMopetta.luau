-- Mopa Mopetta: a little moped in fresh sky blue seen side on, two fat
-- wheels with chrome hubs under mudguards, a floorboard, a leg shield and a
-- rounded rear body under a seat on a spring, the front fork up to a
-- headset with handlebars and a round chrome headlamp. 3.3 studs tall,
-- 3.8 long.
-- include: JunkrotKit
local FACE = { { 0.85, -0.32, 2.12, 0.15 }, { 1.07, -0.32, 2.14, 0.15 } }
local FEET = { 1.2, 0.5 }
local SKY = { 0.35, 0.68, 0.88 }
local WHEEL = 0.48
local FRONT, BACK = 1.35, -1.25 -- the axles along x
part("Wheels", nil, RUBBER_BLACK, function(mesh)
	for _, x in { FRONT, BACK } do
		local m = Kit.lathe({ { 0, -0.13 }, { 0.32, -0.13 }, { 0.44, -0.09 }, { WHEEL, 0 }, { 0.44, 0.09 }, { 0.32, 0.13 }, { 0, 0.13 } }, 20)
		Kit.turn(m, "x", 90)
		m:translate(x, 0, WHEEL)
		m:emit(mesh)
	end
end, true, RUBBER)
part("Hubs", nil, BARE_METAL, function(mesh)
	for _, x in { FRONT, BACK } do
		for _, side in { -1, 1 } do
			local m = Kit.lathe({ { 0, 0 }, { 0.2, 0 }, { 0.16, 0.06 }, { 0, 0.08 } }, 12)
			Kit.turn(m, "x", side * 90)
			m:translate(x, side * 0.12, WHEEL)
			m:emit(mesh)
		end
	end
	local lamp = Kit.lathe({ { 0, 0 }, { 0.2, 0 }, { 0.22, 0.1 }, { 0.18, 0.16 }, { 0, 0.16 } }, 16)
	Kit.turn(lamp, "y", 90)
	lamp:translate(1.1, 0, 2.05)
	lamp:emit(mesh)
end, true, 0.05)
part("Body", nil, SKY, function(mesh)
	local floor = Kit.block(1.3, 0.6, 0.12, 0.04)
	floor:translate(0, 0, 0.75)
	floor:emit(mesh)
	local rear = Kit.block(1.3, 0.75, 0.75, 0.3)
	rear:translate(-0.9, 0, 1.25)
	rear:emit(mesh)
	local shield = Kit.block(0.12, 0.75, 1.25, 0.05)
	Kit.turn(shield, "y", -15)
	shield:translate(0.72, 0, 1.4)
	shield:emit(mesh)
	local headset = Kit.block(0.35, 0.5, 0.35, 0.1)
	headset:translate(0.95, 0, 2.1)
	headset:emit(mesh)
	for _, x in { FRONT, BACK } do
		local guard = EditMesh.arch(WHEEL + 0.04, 0.06, 0.32, 8)
		guard:translate(x, 0, WHEEL)
		guard:emit(mesh)
	end
end, 50, 0.15)
part("Seat", nil, { 0.2, 0.14, 0.1 }, function(mesh)
	local m = Kit.block(0.9, 0.5, 0.16, 0.07)
	m:translate(-0.85, 0, 1.9)
	m:emit(mesh)
end, 50, RUBBER)
part("Bars", nil, BARE_METAL, function(mesh)
	Kit.tube({ { 0.95, 0, 2.05 }, { FRONT, 0, WHEEL } }, 0.06, 8):emit(mesh)
	Kit.tube({ { 0.92, -0.5, 2.38 }, { 0.95, 0, 2.3 }, { 0.92, 0.5, 2.38 } }, 0.04, 6):emit(mesh)
	EditMesh.coil(0.12, 0.025, 3, 0.08, 6, 12):translate(-0.85, 0, 1.6):emit(mesh)
end, true, 0.05)
part("Exhaust", nil, BARE_METAL, function(mesh)
	Kit.tube({ { -0.4, 0.38, 0.68 }, { -1.55, 0.38, 0.78 } }, 0.06, 8):emit(mesh)
	Kit.tube({ { -1.52, 0.38, 0.78 }, { -1.7, 0.38, 0.8 } }, 0.08, 8):emit(mesh)
	-- The rack behind the seat.
	Kit.tube({ { -1.3, -0.25, 1.65 }, { -1.65, -0.25, 1.65 }, { -1.65, 0.25, 1.65 }, { -1.3, 0.25, 1.65 } }, 0.03, 4):emit(mesh)
end, true, 0.05)
part("TailLight", nil, { 1.0, 0.2, 0.15 }, function(mesh)
	local m = Kit.block(0.06, 0.2, 0.12, 0.02)
	m:translate(-1.56, 0, 1.42)
	m:emit(mesh)
end, 50, 0, nil, 1.5)
-- include: JunkrotFace
