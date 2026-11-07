-- Grindella Scintilla: an angle grinder in fresh green lying level on its
-- legs, the motor barrel tapering to its tail, a black gear head at the
-- front with the side handle out toward us, the grinding disc under the
-- head tipped toward us behind a half guard, and a spray of sparks flying
-- off it. 2.4 studs tall, 3.6 long.
-- include: JunkrotKit
-- floats: Sparks
local FACE = { { 0.1, -0.47, 1.53, 0.16 }, { 0.45, -0.47, 1.55, 0.16 } }
local FEET = { 1.0, 0.78 }
local TOOL_GREEN = { 0.2, 0.6, 0.36 }
local AXIS = 1.38
local DISC = { 1.1, 0, AXIS - 0.5 } -- the disc's middle
local TIP = 18 -- degrees the disc tips toward us
part("Body", nil, TOOL_GREEN, function(mesh)
	-- Lathed along z, laid along x: the tail end (-x) narrowing.
	local m = Kit.lathe({ { 0, -1.35 }, { 0.12, -1.35 }, { 0.3, -1.1 }, { 0.42, -0.4 }, { 0.44, 0.6 }, { 0.4, 0.75 }, { 0, 0.78 } }, 16)
	Kit.turn(m, "y", 90)
	m:translate(0, 0, AXIS)
	m:emit(mesh)
end, true, 0.15)
part("Head", nil, { 0.13, 0.13, 0.14 }, function(mesh)
	local m = Kit.block(0.55, 0.62, 0.6, 0.1)
	m:translate(1.0, 0, AXIS - 0.05)
	m:emit(mesh)
	local spindle = EditMesh.cylinder(0.08, 0.3, 8, 1)
	spindle:translate(DISC[1], 0, AXIS - 0.4)
	spindle:emit(mesh)
end, 50, 0.1)
part("Handle", nil, { 0.13, 0.13, 0.14 }, function(mesh)
	Kit.tube({ { 1.0, -0.28, AXIS }, { 0.98, -0.7, AXIS + 0.05 }, { 0.96, -1.05, AXIS + 0.1 } }, 0.11, 8):emit(mesh)
end, true, RUBBER)
part("Disc", nil, { 0.5, 0.48, 0.45 }, function(mesh)
	local m = Kit.lathe({ { 0, -0.03 }, { 0.65, -0.03 }, { 0.66, 0 }, { 0.65, 0.03 }, { 0.12, 0.05 }, { 0, 0.05 } }, 24)
	Kit.turn(m, "x", TIP)
	m:translate(DISC[1], DISC[2], DISC[3])
	m:emit(mesh)
end, 40, 0.2)
part("Guard", nil, BARE_METAL, function(mesh)
	-- A curved wall round the back half of the disc, its top folded over.
	local m = EditMesh.spin({ { 0.7, -0.05 }, { 0.7, 0.08 }, { 0.6, 0.12 } }, 16, 180)
	m:solidify(0.03)
	Kit.turn(m, "x", TIP)
	m:translate(DISC[1], DISC[2], DISC[3])
	m:emit(mesh)
end, 40, 0.05)
part("Sparks", nil, { 1.0, 0.7, 0.2 }, function(mesh)
	for k = 0, 7 do
		local a = math.rad(200 + k * 14)
		local from = { DISC[1] + math.cos(a) * 0.66, DISC[2] + math.sin(a) * 0.66, DISC[3] }
		local reach = 0.5 + (k % 3) * 0.25
		local to = { from[1] + math.cos(a) * reach, from[2] + math.sin(a) * reach - 0.1, from[3] - 0.15 - (k % 2) * 0.2 }
		Kit.tube({ from, to }, function(t)
			return 0.025 * (1 - 0.7 * t)
		end, 4):emit(mesh)
	end
end, true, 0, nil, 2.0)
part("Cord", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	Kit.tube(Kit.curve({ { -1.33, 0, AXIS }, { -1.7, 0.05, AXIS - 0.3 }, { -1.95, 0.25, 0.05 } }, 4), 0.06, 6):emit(mesh)
	for _, side in { -1, 1 } do
		for k = 0, 2 do
			local vent = Kit.block(0.06, 0.04, 0.3, 0.01)
			vent:translate(-0.75 + k * 0.14, side * 0.4, AXIS)
			vent:emit(mesh)
		end
	end
end, true, RUBBER)
-- include: JunkrotFace
