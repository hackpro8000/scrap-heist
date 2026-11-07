-- Grindo Beanbasher: a bean-to-cup coffee machine, glossy black and
-- rounded, a brushed-steel front with a row of buttons under its face, a
-- spout block with two nozzles over a drip tray with a cup on it, a bean
-- hopper with a dark lid on top and the sticker still on its side. 3.6
-- studs tall.
-- include: JunkrotKit
local FACE = { { -0.3, -0.79, 2.65, 0.2 }, { 0.3, -0.79, 2.67, 0.2 } }
local FEET = { 1.0, 0.5 }
local BASE = 0.55
local TALL = 2.45
part("Body", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	local m = Kit.block(1.4, 1.3, TALL, 0.18)
	m:translate(0, 0, BASE + TALL / 2)
	m:emit(mesh)
end, 50, 0)
part("Front", nil, BARE_METAL, function(mesh)
	local plate = Kit.block(1.2, 0.08, 1.15, 0.05)
	plate:translate(0, -0.68, BASE + 1.95)
	plate:emit(mesh)
	local tray = Kit.block(1.0, 0.45, 0.12, 0.04)
	tray:translate(0, -0.78, BASE + 0.12)
	tray:emit(mesh)
	local spout = Kit.block(0.55, 0.4, 0.22, 0.05)
	spout:translate(0, -0.78, BASE + 1.3)
	spout:emit(mesh)
	for _, x in { -0.1, 0.1 } do
		local nozzle = EditMesh.cylinder(0.04, 0.14, 8, 1)
		nozzle:translate(x, -0.85, BASE + 1.14)
		nozzle:emit(mesh)
	end
end, 50, 0.03)
part("Buttons", nil, { 0.16, 0.16, 0.18 }, function(mesh)
	for k = 0, 3 do
		local b = Kit.block(0.16, 0.06, 0.1, 0.03)
		b:translate(-0.36 + k * 0.24, -0.73, BASE + 1.55)
		b:emit(mesh)
	end
end, 50, 0)
part("Cup", nil, { 0.95, 0.94, 0.9 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.16, 0 }, { 0.2, 0.3 }, { 0.17, 0.3 }, { 0.15, 0.05 }, { 0, 0.05 } }, 16)
	m:translate(0, -0.85, BASE + 0.18)
	m:emit(mesh)
	Kit.tube(Kit.curve({ { 0.18, -0.85, BASE + 0.4 }, { 0.32, -0.85, BASE + 0.35 }, { 0.17, -0.85, BASE + 0.25 } }, 3), 0.03, 6):emit(mesh)
end, 40, 0)
part("Hopper", nil, { 0.36, 0.22, 0.12 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.38, 0 }, { 0.48, 0.45 }, { 0, 0.45 } }, 16)
	m:translate(0, 0.1, BASE + TALL)
	m:emit(mesh)
	local lid = Kit.lathe({ { 0, 0 }, { 0.52, 0 }, { 0.5, 0.06 }, { 0.12, 0.09 }, { 0, 0.14 } }, 16)
	lid:translate(0, 0.1, BASE + TALL + 0.45)
	lid:emit(mesh)
end, 40, 0)
part("Sticker", nil, { 0.98, 0.85, 0.2 }, function(mesh)
	local m = Kit.block(0.03, 0.45, 0.32, 0.01)
	m:translate(0.71, 0.1, BASE + 1.2)
	m:emit(mesh)
end, 50, 0)
-- include: JunkrotFace
