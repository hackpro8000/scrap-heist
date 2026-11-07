-- Drillo Trapanino: a cordless drill in fresh yellow standing on its
-- battery, the motor barrel level on top with a rounded back end, a black
-- rubber grip raked down to the battery with a red trigger, and the chuck
-- and tapering bit out front like a nose. 3.3 studs tall.
-- include: JunkrotKit
local FACE = { { -0.2, -0.55, 2.98, 0.16 }, { 0.2, -0.55, 3.0, 0.16 } }
local FEET = { 0.9, 0.5 }
local TOOL_YELLOW = { 0.96, 0.78, 0.1 }
local AXIS = 2.55 -- the motor's axis
part("Motor", nil, TOOL_YELLOW, function(mesh)
	-- Lathed along z, laid along y: the front (-y) narrower.
	local m = Kit.lathe({ { 0, -0.78 }, { 0.3, -0.78 }, { 0.42, -0.6 }, { 0.46, 0.2 }, { 0.44, 0.7 }, { 0.3, 0.85 }, { 0, 0.88 } }, 16)
	Kit.turn(m, "x", -90)
	m:translate(0, 0, AXIS)
	m:emit(mesh)
end, true, 0.15)
part("Grip", nil, { 0.13, 0.13, 0.14 }, function(mesh)
	local m = Kit.block(0.42, 0.55, 1.35, 0.18)
	Kit.turn(m, "x", -12)
	m:translate(0, 0.22, 1.6)
	m:emit(mesh)
end, 50, RUBBER)
part("Battery", nil, TOOL_YELLOW, function(mesh)
	local m = Kit.block(0.95, 1.25, 0.48, 0.1)
	m:translate(0, 0.08, 0.79)
	m:emit(mesh)
end, 50, 0.15)
part("Chuck", nil, BARE_METAL, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.25, 0 }, { 0.26, 0.15 }, { 0.22, 0.32 }, { 0.12, 0.4 }, { 0, 0.42 } }, 16)
	Kit.turn(m, "x", 90)
	m:translate(0, -0.76, AXIS)
	m:emit(mesh)
	local bit = Kit.tube({ { 0, -1.12, AXIS }, { 0, -1.75, AXIS } }, function(t)
		return 0.05 * (1 - 0.8 * t)
	end, 8)
	bit:emit(mesh)
end, 40, 0.05)
part("Trigger", nil, { 0.85, 0.15, 0.12 }, function(mesh)
	local m = Kit.block(0.16, 0.16, 0.26, 0.05)
	m:translate(0, -0.08, 2.0)
	m:emit(mesh)
end, 50, 0.1)
part("Switch", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	local m = Kit.block(0.32, 0.1, 0.08, 0.03)
	m:translate(0, -0.1, 2.27)
	m:emit(mesh)
	for _, side in { -1, 1 } do
		for k = 0, 2 do
			local vent = Kit.block(0.04, 0.06, 0.32, 0.01)
			vent:translate(side * 0.44, 0.35 + k * 0.12, AXIS)
			vent:emit(mesh)
		end
	end
end, 50, 0)
-- include: JunkrotFace
