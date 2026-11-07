-- Cablo Tanglino: a knot of black cable that got up and walked, loops of
-- the same cable wound every which way into a ball, one end hanging off as
-- a tail with its plug still on it, prongs up. 2.6 studs tall.
-- include: JunkrotKit
local FACE = { { -0.28, -0.86, 1.6, 0.24 }, { 0.3, -0.84, 1.65, 0.27 } }
local FEET = { 0.8, 0.55 }
local MID = 1.45
part("Knot", nil, { 0.14, 0.14, 0.16 }, function(mesh)
	-- Loops of cable, each turned a different way about the middle.
	local turns = { { 0, 0, 0 }, { 62, 18, 0 }, { -48, 42, 30 }, { 88, -28, 64 }, { 22, 80, -40 }, { -70, -58, 14 } }
	for index, t in turns do
		local m = EditMesh.torus(0.72 - index * 0.02, 0.1, 20, 8)
		Kit.turn(m, "x", t[1])
		Kit.turn(m, "y", t[2])
		Kit.turn(m, "z", t[3])
		m:translate(0, 0, MID)
		m:emit(mesh)
	end
end, true, RUBBER)
part("Tail", nil, { 0.14, 0.14, 0.16 }, function(mesh)
	local path = Kit.curve({ { 0.6, 0.1, MID - 0.3 }, { 1.05, 0.15, MID - 0.55 }, { 1.35, 0.05, MID - 0.25 }, { 1.4, 0, MID + 0.3 } }, 4)
	Kit.tube(path, 0.08, 8):emit(mesh)
end, true, RUBBER)
part("Plug", nil, { 0.85, 0.83, 0.78 }, function(mesh)
	local m = Kit.block(0.34, 0.22, 0.4, 0.07)
	m:translate(1.4, 0, MID + 0.5)
	m:emit(mesh)
end, 50, 0.3)
part("Prongs", nil, BARE_METAL, function(mesh)
	for _, x in { -0.08, 0.08 } do
		local prong = Kit.block(0.05, 0.12, 0.2, 0.01)
		prong:translate(1.4 + x, 0, MID + 0.78)
		prong:emit(mesh)
	end
end, 50, 0.1)
-- include: JunkrotFace
