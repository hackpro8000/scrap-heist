-- Pannetto Patchato: a frying pan standing on its rim, its handle up like
-- a tail and a riveted patch over an old hole, 3.3 studs tall.
local FACE = { { -0.38, -0.2, 1.75, 0.27 }, { 0.38, -0.2, 1.8, 0.3 } }
local FEET = { 0.9, 0.55 }
part("Pan", nil, { 0.17, 0.17, 0.18 }, function(mesh)
	cylinder(mesh, 0, 0.1, 1.7, 1.15, 0.16, "y", 20)
	ring(mesh, 0, -0.06, 1.7, 1.05, 1.22, 0.36, "y", 20)
end, nil, 0.6)
part("Handle", nil, { 0.17, 0.17, 0.18 }, function(mesh)
	tube(mesh, { { 0.8, 0, 2.5 }, { 1.4, 0, 3.1 }, { 2.0, 0, 3.35 } }, 0.14, 8)
	ring(mesh, 2.1, 0, 3.4, 0.08, 0.2, 0.1, "y", 10)
end, true, 0.5)
part("Patch", nil, COPPER, function(mesh)
	box(mesh, 0.35, -0.02, 0.95, 0.7, 0.06, 0.55)
	for _, x in { 0.1, 0.6 } do
		bolt(mesh, x, -0.06, 1.05, "y", 0.05)
		bolt(mesh, x, -0.06, 1.4, "y", 0.05)
	end
end, nil, 0.6)
-- include: JunkrotFace
