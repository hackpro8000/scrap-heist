-- Sousvide Silvano: a sous-vide wand, a slim steel column with a black
-- head, a temperature readout and its clamp out to one side like an arm.
-- 4 studs tall.
local FACE = { { -0.2, -0.52, 2.5, 0.2 }, { 0.2, -0.52, 2.55, 0.22 } }
local FEET = { 0.5, 0.5 }
part("Column", nil, BARE_METAL, function(mesh)
	cylinder(mesh, 0, 0, 1.7, 0.45, 2.3, "z", 16)
	for k = 0, 3 do
		ring(mesh, 0, 0, 0.8 + k * 0.14, 0.44, 0.47, 0.05, "z", 16)
	end
end, nil, 0.03)
part("Head", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	cylinder(mesh, 0, 0, 3.4, 0.55, 1.1, "z", 16)
	sphere(mesh, 0, 0, 3.95, 0.55, 0.55, 0.2, 5, 16)
end, true, 0)
part("Readout", nil, { 1.0, 0.45, 0.2 }, function(mesh)
	box(mesh, 0, -0.54, 3.3, 0.6, 0.03, 0.34)
end, nil, 0, nil, 1.2)
part("Clamp", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	box(mesh, 0.75, 0, 2.2, 0.7, 0.4, 0.3)
	box(mesh, 1.05, 0, 1.5, 0.14, 0.4, 0.8)
	cylinder(mesh, 0.8, 0, 1.6, 0.1, 0.5, "x", 8)
end, nil, 0)
-- include: JunkrotFace
