-- Headphono Bassimo: studio headphones standing on their ear cups, each
-- cup a deep rounded drum with a soft cushion on its inside face and a
-- ring of light round its outside, yokes up to a brushed band arched
-- overhead with a padded strip under it. 3.6 studs tall.
-- include: JunkrotKit
local FACE = { { -0.86, -0.8, 1.6, 0.22 }, { 0.86, -0.8, 1.62, 0.22 } }
local FEET = { 1.7, 0.5 }
local MID = 1.45 -- the cups' middle
local CUP = 0.62 -- where each cup's inner face stands, out along x
part("Cups", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	for _, side in { -1, 1 } do
		local m = Kit.lathe({ { 0, 0 }, { 0.62, 0 }, { 0.72, 0.08 }, { 0.75, 0.3 }, { 0.72, 0.45 }, { 0, 0.5 } }, 24)
		Kit.turn(m, "y", side * 90)
		m:translate(side * CUP, 0, MID)
		m:emit(mesh)
	end
end, true, 0)
part("Pads", nil, { 0.22, 0.2, 0.2 }, function(mesh)
	for _, side in { -1, 1 } do
		local m = EditMesh.torus(0.45, 0.15, 24, 8)
		Kit.turn(m, "y", 90)
		m:translate(side * (CUP - 0.08), 0, MID)
		m:emit(mesh)
	end
end, true, RUBBER)
part("Glow", nil, { 0.5, 0.4, 1.0 }, function(mesh)
	for _, side in { -1, 1 } do
		local m = EditMesh.torus(0.5, 0.04, 24, 6)
		Kit.turn(m, "y", 90)
		m:translate(side * (CUP + 0.42), 0, MID)
		m:emit(mesh)
	end
end, true, 0, nil, 1.5)
part("Band", nil, BARE_METAL, function(mesh)
	local path = Kit.curve({ { -0.95, 0, MID + 0.7 }, { -0.82, 0, MID + 1.5 }, { 0, 0, MID + 1.95 }, { 0.82, 0, MID + 1.5 }, { 0.95, 0, MID + 0.7 } }, 6)
	EditMesh.sweep({ { -0.03, -0.18 }, { 0.03, -0.18 }, { 0.03, 0.18 }, { -0.03, 0.18 } }, path):emit(mesh)
end, 40, 0.03)
part("BandPad", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	local path = Kit.curve({ { -0.55, 0, MID + 1.66 }, { 0, 0, MID + 1.86 }, { 0.55, 0, MID + 1.66 } }, 6)
	Kit.tube(path, 0.1, 8):emit(mesh)
end, true, RUBBER)
-- include: JunkrotFace
