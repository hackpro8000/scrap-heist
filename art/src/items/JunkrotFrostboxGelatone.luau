-- Frostbox Gelatone: a little fridge, repainted mint, with a freezer door
-- on top, chrome handles and one magnet it never lost, 3.9 studs tall.
local FACE = { { -0.36, -0.8, 3.15, 0.26 }, { 0.36, -0.8, 3.2, 0.3 } }
local FEET = { 0.9, 0.5 }
local MINT = { 0.66, 0.86, 0.8 }
part("Cabinet", nil, MINT, function(mesh)
	box(mesh, 0, 0, 0.6, 1.9, 1.5, 3.3)
end, nil, 0.15)
part("Doors", nil, MINT, function(mesh)
	box(mesh, 0, -0.78, 0.7, 1.8, 0.1, 1.9)
	box(mesh, 0, -0.78, 2.7, 1.8, 0.1, 1.1)
end, nil, 0.12)
part("Chrome", nil, BARE_METAL, function(mesh)
	box(mesh, -0.7, -0.88, 1.9, 0.1, 0.08, 0.6)
	box(mesh, -0.7, -0.88, 2.8, 0.1, 0.08, 0.4)
	box(mesh, 0, -0.76, 2.6, 1.84, 0.08, 0.08)
end, nil, 0.05)
part("Magnet", nil, { 0.9, 0.3, 0.25 }, function(mesh)
	cylinder(mesh, 0.5, -0.85, 1.6, 0.16, 0.06, "y", 10)
end, nil, 0.1)
-- include: JunkrotFace
