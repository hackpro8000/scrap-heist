-- Chefbot Precisio: an all-in-one kitchen robot, a brushed-steel jug with
-- a handle locked into a rounded white base whose front leans back to
-- carry a glowing touchscreen and one dial ringed in light, a lid with its
-- measuring-cup cap on top. 3.6 studs tall.
-- include: JunkrotKit
local FACE = { { -0.24, -0.68, 2.6, 0.2 }, { 0.24, -0.68, 2.62, 0.2 } }
local FEET = { 1.0, 0.5 }
local BASE = 0.55
local JUG = BASE + 1.35 -- where the jug sits
local SLOPE = 19 -- degrees the base's upper front leans back
part("Base", nil, { 0.95, 0.96, 0.97 }, function(mesh)
	local m = Kit.block(1.7, 1.55, 1.35, 0.22, { 2, 3, 2 })
	-- The front leans back from half height up.
	m:transform(function(p)
		local up = math.clamp((p[3] + 0.1) / 0.775, 0, 1)
		return { p[1], if p[2] < 0 then p[2] * (1 - 0.35 * up) else p[2], p[3] }
	end)
	m:translate(0, 0, BASE + 0.675)
	m:emit(mesh)
end, 50, 0)
part("Screen", nil, { 0.3, 0.75, 1.0 }, function(mesh)
	local m = Kit.block(0.75, 0.05, 0.42, 0.04)
	Kit.turn(m, "x", -SLOPE)
	m:translate(-0.27, -0.66, BASE + 0.97)
	m:emit(mesh)
end, 50, 0, nil, 1.0)
part("DialGlow", nil, { 0.4, 1.0, 0.6 }, function(mesh)
	local m = EditMesh.torus(0.19, 0.035, 16, 6)
	Kit.turn(m, "x", 90 - SLOPE)
	m:translate(0.45, -0.67, BASE + 0.97)
	m:emit(mesh)
end, true, 0, nil, 1.2)
part("Dial", nil, BARE_METAL, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.15, 0 }, { 0.15, 0.1 }, { 0.11, 0.13 }, { 0, 0.13 } }, 16)
	Kit.turn(m, "x", 90 - SLOPE)
	m:translate(0.45, -0.64, BASE + 0.97)
	m:emit(mesh)
end, 40, 0.03)
part("Jug", nil, BARE_METAL, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.55, 0 }, { 0.6, 0.08 }, { 0.68, 1.15 }, { 0.72, 1.25 }, { 0.66, 1.25 }, { 0.63, 1.15 }, { 0, 1.12 } }, 20)
	m:translate(0, 0, JUG)
	m:emit(mesh)
	local handle = Kit.curve({ { 0.64, 0, JUG + 1.08 }, { 1.0, 0, JUG + 0.95 }, { 1.0, 0, JUG + 0.3 }, { 0.6, 0, JUG + 0.2 } }, 4)
	Kit.tube(handle, 0.08, 8):emit(mesh)
end, 40, 0.03)
part("Lid", nil, { 0.14, 0.14, 0.16 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.72, 0 }, { 0.72, 0.08 }, { 0.32, 0.13 }, { 0.3, 0.3 }, { 0, 0.3 } }, 20)
	m:translate(0, 0, JUG + 1.24)
	m:emit(mesh)
end, 40, 0)
part("Spatula", nil, { 0.92, 0.92, 0.9 }, function(mesh)
	-- Left standing in the lid's cap.
	Kit.tube({ { 0.05, 0, JUG + 1.45 }, { 0.12, 0.03, JUG + 1.8 }, { 0.2, 0.06, JUG + 2.1 } }, 0.045, 6):emit(mesh)
	local loop = EditMesh.torus(0.07, 0.025, 10, 4)
	Kit.turn(loop, "x", 90)
	loop:translate(0.22, 0.06, JUG + 2.2)
	loop:emit(mesh)
end, true, 0.03)
-- include: JunkrotFace
