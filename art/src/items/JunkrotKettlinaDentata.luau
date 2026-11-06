-- Kettlina Dentata: a dented stovetop kettle with a crooked spout and a
-- wire handle, 2.9 studs tall.
local FACE = { { -0.34, -0.92, 1.55, 0.27 }, { 0.36, -0.9, 1.6, 0.3 } }
local FEET = { 0.9, 0.55 }
part("Body", nil, { 0.5, 0.56, 0.6 }, function(mesh)
	sphere(mesh, 0, 0, 1.4, 1.05, 1.05, 0.9, 8, 16)
	cylinder(mesh, 0, 0, 0.62, 0.8, 0.16, "z", 16)
end, true, 0.7)
part("Lid", nil, DARK_STEEL, function(mesh)
	cylinder(mesh, 0, 0, 2.26, 0.5, 0.12, "z", 14)
	sphere(mesh, 0, 0, 2.42, 0.16, 0.16, 0.16, 5, 8)
end, nil, 0.5)
part("Spout", nil, { 0.5, 0.56, 0.6 }, function(mesh)
	tube(mesh, { { 0.8, 0, 1.3 }, { 1.3, 0, 1.6 }, { 1.5, 0.1, 2.1 } }, 0.16, 8)
end, true, 0.75)
part("Handle", nil, DARK_STEEL, function(mesh)
	tube(mesh, { { -0.7, 0, 2.0 }, { -0.6, 0, 2.7 }, { 0, 0, 2.9 }, { 0.6, 0, 2.7 }, { 0.7, 0, 2.0 } }, 0.07, 6)
end, nil, 0.5)
-- include: JunkrotFace
