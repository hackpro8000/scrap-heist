-- Pressurwasho Sprizzo: an upright pressure washer in bright yellow, a
-- rounded body tapering to its top with a carry handle over it, two black
-- wheels at its heels, the hose coiled on a hook on its side, the spray
-- gun and lance stood up beside it like a spear and a black badge on its
-- front. 3.7 studs tall.
-- include: JunkrotKit
local FACE = { { -0.3, -0.53, 2.55, 0.2 }, { 0.3, -0.53, 2.57, 0.2 } }
local FEET = { 0.9, 0.45 }
local WASH_YELLOW = { 1.0, 0.84, 0.1 }
local BASE = 0.55
local TALL = 2.4
part("Body", nil, WASH_YELLOW, function(mesh)
	local m = Kit.block(1.3, 1.05, TALL, 0.28)
	m:taper("z", 1, 0.86)
	m:translate(0, 0, BASE + TALL / 2)
	m:emit(mesh)
	local handle = Kit.curve({ { -0.4, 0.2, BASE + TALL - 0.05 }, { -0.35, 0.25, BASE + TALL + 0.35 }, { 0.35, 0.25, BASE + TALL + 0.35 }, { 0.4, 0.2, BASE + TALL - 0.05 } }, 3)
	Kit.tube(handle, 0.07, 8):emit(mesh)
	local hook = Kit.block(0.2, 0.12, 0.1, 0.03)
	hook:translate(0.72, 0, BASE + 1.62)
	hook:emit(mesh)
end, 50, 0.03)
part("Wheels", nil, RUBBER_BLACK, function(mesh)
	for _, side in { -1, 1 } do
		local m = Kit.lathe({ { 0, -0.1 }, { 0.3, -0.1 }, { 0.38, -0.06 }, { 0.4, 0 }, { 0.38, 0.06 }, { 0.3, 0.1 }, { 0, 0.1 } }, 16)
		Kit.turn(m, "y", 90)
		m:translate(side * 0.75, 0.32, 0.4)
		m:emit(mesh)
	end
end, true, RUBBER)
part("Hose", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	local coil = EditMesh.coil(0.35, 0.05, 3, 0.11, 8, 24)
	Kit.turn(coil, "y", 90)
	coil:translate(0.74, 0, BASE + 1.3)
	coil:emit(mesh)
	Kit.tube(Kit.curve({ { -0.55, -0.4, BASE + 0.5 }, { -0.85, -0.45, BASE + 0.6 }, { -0.85, -0.3, 1.45 } }, 3), 0.05, 6):emit(mesh)
end, true, RUBBER)
part("Lance", nil, BARE_METAL, function(mesh)
	local grip = Kit.block(0.12, 0.2, 0.35, 0.04)
	grip:translate(-0.85, -0.3, 1.55)
	grip:emit(mesh)
	Kit.tube({ { -0.85, -0.32, 1.7 }, { -0.9, -0.35, 3.55 } }, 0.04, 6):emit(mesh)
	local nozzle = EditMesh.cone(0.06, 0.03, 0.15, 8, 1)
	nozzle:translate(-0.9, -0.35, 3.62)
	nozzle:emit(mesh)
end, true, 0.03)
part("Badge", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	local m = Kit.block(0.5, 0.04, 0.3, 0.05)
	m:translate(0, -0.52, BASE + 1.2)
	m:emit(mesh)
end, 50, 0)
-- include: JunkrotFace
