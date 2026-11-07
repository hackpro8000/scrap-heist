-- Pannetto Patchato: a frying pan standing on its rim with its bottom to
-- us, flared walls rolled at the lip, its long handle up behind like a
-- tail with a hanging ring at the end, and a copper patch over an old hole
-- low on its bottom. 3.3 studs tall.
-- include: JunkrotKit
local FACE = { { -0.32, -0.08, 1.95, 0.22 }, { 0.32, -0.08, 1.97, 0.23 } }
local FEET = { 0.9, 0.55 }
local MID = 1.65
part("Pan", nil, { 0.17, 0.17, 0.18 }, function(mesh)
	-- Lathed with its bottom down, then turned to face us.
	local m = Kit.lathe({ { 0, 0 }, { 0.82, 0 }, { 0.9, 0.04 }, { 1.08, 0.36 }, { 1.12, 0.4 }, { 1.06, 0.42 }, { 0.88, 0.1 }, { 0, 0.07 } }, 24)
	Kit.turn(m, "x", -90)
	m:translate(0, 0, MID)
	m:emit(mesh)
end, 40, 0.6)
part("Handle", nil, { 0.17, 0.17, 0.18 }, function(mesh)
	local path = Kit.curve({ { 0, 0.32, MID + 1.0 }, { 0, 0.62, MID + 1.42 }, { 0, 1.05, MID + 1.72 } }, 4)
	Kit.tube(path, 0.08, 8):emit(mesh)
	local ring = EditMesh.torus(0.12, 0.035, 12, 6)
	Kit.turn(ring, "y", 90)
	ring:translate(0, 1.18, MID + 1.8)
	ring:emit(mesh)
end, true, 0.5)
part("Patch", nil, COPPER, function(mesh)
	local m = Kit.block(0.45, 0.04, 0.35, 0.03)
	Kit.turn(m, "y", 12)
	m:translate(0.32, -0.01, MID - 0.5)
	m:emit(mesh)
end, 50, 0.6)
part("Grip", nil, { 0.45, 0.28, 0.15 }, function(mesh)
	Kit.tube(Kit.curve({ { 0, 0.72, MID + 1.48 }, { 0, 0.9, MID + 1.62 }, { 0, 1.05, MID + 1.72 } }, 3), 0.11, 8):emit(mesh)
end, true, 0.3)
-- include: JunkrotFace
