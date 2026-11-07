-- Blendro Cigolante: a squeaky blender, a cloudy jug with a handle and a
-- pouring lip on a base that tapers to its top, one big red dial on the
-- base for a mouth between two press buttons, and the lid knocked askew.
-- 3.5 studs tall.
-- include: JunkrotKit
local FACE = { { -0.34, -0.65, 1.32, 0.2 }, { 0.34, -0.65, 1.34, 0.2 } }
local FEET = { 0.9, 0.5 }
local BASE = 0.55
local JUG = BASE + 1.05 -- where the jug sits
part("Base", nil, { 0.78, 0.74, 0.62 }, function(mesh)
	local m = Kit.block(1.5, 1.3, 1.05, 0.14)
	m:taper("z", 1, 0.84)
	m:translate(0, 0, BASE + 0.525)
	m:emit(mesh)
end, 50, 0.5)
part("Jug", nil, { 0.62, 0.74, 0.76 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.5, 0 }, { 0.52, 0.05 }, { 0.62, 1.6 }, { 0.65, 1.68 }, { 0.6, 1.68 }, { 0.57, 1.58 }, { 0, 1.55 } }, 16)
	-- The pouring lip, pulled out at the front of the rim.
	m:select("vertex", "where", function(p)
		return p[2] < -0.45 and p[3] > 1.5
	end):move({ 0, -0.08, 0.04 }, 0.15)
	m:translate(0, 0, JUG)
	m:emit(mesh)
	local handle = Kit.curve({ { 0.56, 0, JUG + 1.42 }, { 0.95, 0, JUG + 1.3 }, { 0.98, 0, JUG + 0.6 }, { 0.5, 0, JUG + 0.35 } }, 4)
	Kit.tube(handle, 0.08, 8):emit(mesh)
end, 40, 0.2)
part("Lid", nil, { 0.14, 0.14, 0.15 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.67, 0 }, { 0.67, 0.1 }, { 0.22, 0.13 }, { 0.2, 0.28 }, { 0, 0.3 } }, 16)
	Kit.turn(m, "y", 9)
	m:translate(0.03, 0, JUG + 1.66)
	m:emit(mesh)
	for _, x in { -0.5, 0.5 } do
		local button = Kit.block(0.2, 0.1, 0.12, 0.04)
		button:translate(x, -0.62, BASE + 0.32)
		button:emit(mesh)
	end
end, 40, 0.4)
part("Dial", nil, { 0.85, 0.2, 0.15 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.24, 0 }, { 0.22, 0.08 }, { 0.12, 0.12 }, { 0.1, 0.2 }, { 0, 0.2 } }, 16)
	Kit.turn(m, "x", 90)
	m:translate(0, -0.6, BASE + 0.36)
	m:emit(mesh)
end, true, 0.3)
part("Gasket", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	local ring = EditMesh.torus(0.53, 0.05, 20, 6)
	ring:translate(0, 0, JUG + 0.03)
	ring:emit(mesh)
	Kit.tube(Kit.curve({ { 0, 0.55, BASE + 0.22 }, { 0.2, 0.95, BASE + 0.1 }, { 0.5, 1.15, 0.04 } }, 4), 0.05, 6):emit(mesh)
end, true, RUBBER)
-- include: JunkrotFace
