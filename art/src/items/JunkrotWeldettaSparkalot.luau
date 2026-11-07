-- Weldetta Sparkalot: an inverter welder, a blue box with rounded edges,
-- cooling slots down its sides, a front panel with two dials and a socket,
-- a carry strap over its top, its welding mask pushed up on its head like
-- a cap, the cable out to a torch held up beside it and a blue-white arc
-- crackling at the tip. 3.4 studs tall.
-- include: JunkrotKit
local FACE = { { -0.32, -0.62, 1.95, 0.2 }, { 0.32, -0.62, 1.97, 0.2 } }
local FEET = { 1.0, 0.5 }
local BASE = 0.55
local TALL = 1.8
local TOP = BASE + TALL
local TIP = { 1.27, -1.02, 1.88 } -- the torch's tip
part("Case", nil, { 0.12, 0.3, 0.62 }, function(mesh)
	local m = Kit.block(1.5, 1.1, TALL, 0.14)
	m:translate(0, 0, BASE + TALL / 2)
	m:emit(mesh)
end, 50, 0.03)
part("Slots", nil, { 0.08, 0.08, 0.1 }, function(mesh)
	for _, side in { -1, 1 } do
		for k = 0, 4 do
			local slot = Kit.block(0.04, 0.6, 0.08, 0.02)
			slot:translate(side * 0.75, 0, BASE + 0.5 + k * 0.2)
			slot:emit(mesh)
		end
	end
	local panel = Kit.block(1.2, 0.05, 0.6, 0.05)
	panel:translate(0, -0.56, BASE + 0.55)
	panel:emit(mesh)
end, 50, 0)
part("Dials", nil, BARE_METAL, function(mesh)
	for _, x in { -0.32, 0.05 } do
		local knob = Kit.lathe({ { 0, 0 }, { 0.12, 0 }, { 0.1, 0.08 }, { 0, 0.1 } }, 12)
		Kit.turn(knob, "x", 90)
		knob:translate(x, -0.58, BASE + 0.62)
		knob:emit(mesh)
	end
	local socket = EditMesh.cylinder(0.07, 0.08, 8, 1)
	Kit.turn(socket, "x", 90)
	socket:translate(0.38, -0.6, BASE + 0.45)
	socket:emit(mesh)
end, true, 0.03)
part("Mask", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	local shell = EditMesh.sphere(1, 12)
	Kit.size(shell, { 0.62, 0.68, 0.38 })
	Kit.turn(shell, "x", -25)
	shell:translate(0, 0.08, TOP + 0.18)
	shell:emit(mesh)
end, true, 0)
part("Visor", nil, { 0.2, 0.25, 0.15 }, function(mesh)
	local m = Kit.block(0.6, 0.06, 0.24, 0.05)
	Kit.turn(m, "x", -25)
	m:translate(0, -0.5, TOP + 0.32)
	m:emit(mesh)
end, 50, 0)
part("Torch", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	Kit.tube(Kit.curve({ { -0.5, 0.2, TOP - 0.05 }, { -0.45, 0.25, TOP + 0.05 }, { 0.45, 0.25, TOP + 0.05 }, { 0.5, 0.2, TOP - 0.05 } }, 3), 0.04, 6):emit(mesh)
	Kit.tube(Kit.curve({ { 0.38, -0.62, BASE + 0.45 }, { 0.9, -0.65, 0.75 }, { 1.12, -0.5, 1.25 }, { 1.15, -0.45, 1.42 } }, 4), 0.05, 6):emit(mesh)
	Kit.tube({ { 1.15, -0.45, 1.4 }, { 1.15, -0.5, 1.9 } }, 0.08, 8):emit(mesh)
end, true, RUBBER)
part("Nozzle", nil, BARE_METAL, function(mesh)
	Kit.tube(Kit.curve({ { 1.15, -0.5, 1.88 }, { 1.18, -0.82, 2.02 }, { TIP[1], TIP[2], TIP[3] + 0.05 } }, 3), 0.045, 6):emit(mesh)
end, true, 0.1)
part("Arc", nil, { 0.7, 0.9, 1.0 }, function(mesh)
	local core = EditMesh.sphere(0.07, 8)
	core:translate(TIP[1], TIP[2] - 0.05, TIP[3] - 0.04)
	core:emit(mesh)
	for k = 0, 2 do
		local spark = Kit.block(0.32, 0.02, 0.02, 0.005)
		Kit.turn(spark, "y", k * 60)
		Kit.turn(spark, "z", k * 40)
		spark:translate(TIP[1], TIP[2] - 0.05, TIP[3] - 0.04)
		spark:emit(mesh)
	end
end, 40, 0, nil, 2.2)
-- include: JunkrotFace
