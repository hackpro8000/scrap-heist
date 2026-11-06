-- Leafblowa Whooshini: a leaf blower in hi-vis orange, a round fan
-- housing with a long nozzle out one side and a couple of leaves caught in
-- its draught. 3 studs tall, 4 long.
local FACE = { { -0.75, -0.72, 1.85, 0.25 }, { -0.1, -0.72, 1.9, 0.28 } }
local FEET = { 1.0, 0.6 }
local HIVIS = { 1.0, 0.5, 0.08 }
part("Housing", nil, HIVIS, function(mesh)
	cylinder(mesh, -0.4, 0, 1.7, 1.05, 1.4, "y", 18)
end, nil, 0.03)
part("Nozzle", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	tube(mesh, { { 0.4, 0, 1.5 }, { 1.4, 0, 1.4 }, { 2.6, 0, 1.2 } }, 0.3, 12)
	ring(mesh, 2.62, 0, 1.2, 0.26, 0.36, 0.14, "x", 12)
end, true, 0)
part("Grille", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	cylinder(mesh, -0.4, 0.72, 1.7, 0.6, 0.06, "y", 14)
end, nil, 0)
part("Handle", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	tube(mesh, { { -1.0, 0, 2.6 }, { -0.8, 0, 3.05 }, { 0.2, 0, 3.05 }, { 0.4, 0, 2.6 } }, 0.12, 8)
end, true, RUBBER)
part("Leaves", nil, { 0.55, 0.7, 0.2 }, function(mesh)
	sphere(mesh, 3.1, 0.2, 1.5, 0.22, 0.03, 0.14, 4, 8)
	sphere(mesh, 3.4, -0.2, 1.0, 0.2, 0.03, 0.13, 4, 8)
	sphere(mesh, 3.0, -0.1, 0.8, 0.18, 0.03, 0.12, 4, 8)
end, true, 0)
-- include: JunkrotFace
