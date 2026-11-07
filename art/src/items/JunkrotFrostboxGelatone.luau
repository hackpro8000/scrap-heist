-- Frostbox Gelatone: a little fridge repainted mint, rounded at the edges,
-- a freezer door on top and the big door below, each with a long chrome
-- handle on standoffs and hinges down the left, the one magnet it never
-- lost, and the condenser coil on its back. 3.9 studs tall.
-- include: JunkrotKit
local FACE = { { -0.32, -0.81, 3.1, 0.22 }, { 0.32, -0.81, 3.12, 0.22 } }
local FEET = { 0.9, 0.5 }
local MINT = { 0.66, 0.86, 0.8 }
local BASE = 0.55
local TALL = 3.1
local DOORS = { { BASE + 2.2, BASE + 3.0 }, { BASE + 0.1, BASE + 2.12 } }
part("Cabinet", nil, MINT, function(mesh)
	local m = Kit.block(1.5, 1.3, TALL, 0.16)
	m:translate(0, 0, BASE + TALL / 2)
	m:emit(mesh)
end, 50, 0.15)
part("Doors", nil, MINT, function(mesh)
	for _, d in DOORS do
		local m = Kit.block(1.4, 0.1, d[2] - d[1], 0.06)
		m:translate(0, -0.69, (d[1] + d[2]) / 2)
		m:emit(mesh)
	end
end, 50, 0.12)
part("Chrome", nil, BARE_METAL, function(mesh)
	for _, d in DOORS do
		local low, high = d[1] + 0.15, d[2] - 0.15
		Kit.tube({ { 0.55, -0.85, low }, { 0.55, -0.85, high } }, 0.04, 8):emit(mesh)
		for _, z in { low, high } do
			Kit.tube({ { 0.55, -0.73, z }, { 0.55, -0.86, z } }, 0.03, 6):emit(mesh)
		end
		for _, z in { d[1] + 0.12, d[2] - 0.12 } do
			local hinge = Kit.block(0.08, 0.14, 0.16, 0.02)
			hinge:translate(-0.72, -0.7, z)
			hinge:emit(mesh)
		end
	end
end, true, 0.05)
part("Magnet", nil, { 0.9, 0.3, 0.25 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.12, 0 }, { 0.1, 0.04 }, { 0, 0.05 } }, 12)
	Kit.turn(m, "x", 90)
	m:translate(-0.25, -0.74, BASE + 1.4)
	m:emit(mesh)
end, true, 0.1)
part("Coil", nil, DARK_STEEL, function(mesh)
	for k = 0, 3 do
		Kit.tube({ { -0.5, 0.7, BASE + 0.5 + k * 0.55 }, { 0.5, 0.7, BASE + 0.5 + k * 0.55 } }, 0.04, 6):emit(mesh)
	end
	for _, x in { -0.5, 0.5 } do
		Kit.tube({ { x, 0.7, BASE + 0.5 }, { x, 0.7, BASE + 2.15 } }, 0.04, 6):emit(mesh)
	end
end, true, 0.4)
-- include: JunkrotFace
