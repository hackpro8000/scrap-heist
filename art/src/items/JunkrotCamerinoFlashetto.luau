-- Camerino Flashetto: a box camera with a fresh leatherette wrap, one big
-- lens for a nose and a flash cube on top, 3 studs tall.
local FACE = { { -0.75, -0.58, 2.0, 0.22 }, { 0.75, -0.58, 2.05, 0.25 } }
local FEET = { 1.1, 0.55 }
part("Body", nil, { 0.15, 0.15, 0.17 }, function(mesh)
	box(mesh, 0, 0, 0.65, 2.6, 1.1, 1.7)
end, nil, RUBBER)
part("Trim", nil, BARE_METAL, function(mesh)
	box(mesh, 0, 0, 2.15, 2.66, 1.16, 0.3)
	box(mesh, 0, 0, 0.6, 2.66, 1.16, 0.14)
	cylinder(mesh, 0.9, 0, 2.5, 0.16, 0.12, "z", 10)
end, nil, 0.05)
part("Lens", nil, { 0.13, 0.13, 0.15 }, function(mesh)
	cylinder(mesh, 0, -0.8, 1.35, 0.6, 0.6, "y", 18)
	cylinder(mesh, 0, -1.15, 1.35, 0.5, 0.2, "y", 18)
end, nil, 0.1)
part("LensGlass", nil, { 0.35, 0.5, 0.7 }, function(mesh)
	sphere(mesh, 0, -1.22, 1.35, 0.4, 0.12, 0.4, 5, 14)
end, true, 0)
part("Flash", nil, { 0.9, 0.92, 0.95 }, function(mesh)
	box(mesh, -0.6, 0, 2.45, 0.7, 0.6, 0.6)
	box(mesh, -0.6, 0, 2.3, 0.3, 0.3, 0.2)
end, nil, 0.05)
-- include: JunkrotFace
