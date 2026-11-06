-- Lawnmowo Ruggito: a push mower in showroom red: a low deck on four
-- wheels, an engine with a pull cord on top, tall handlebars and a grass
-- bag behind. 3.6 studs tall.
local FACE = { { -0.42, -1.3, 1.2, 0.25 }, { 0.42, -1.3, 1.25, 0.28 } }
local FEET = { 1.0, 0.35 }
local SHOW_RED = { 0.88, 0.1, 0.1 }
part("Deck", nil, SHOW_RED, function(mesh)
	box(mesh, 0, -0.2, 0.7, 2.2, 2.4, 0.7)
end, nil, 0.03)
part("Wheels", nil, RUBBER_BLACK, function(mesh)
	for _, x in { -1.2, 1.2 } do
		for _, y in { -1.0, 0.7 } do
			cylinder(mesh, x, y, 0.75, 0.42, 0.3, "x", 14)
		end
	end
end, nil, RUBBER)
part("Engine", nil, { 0.14, 0.14, 0.16 }, function(mesh)
	cylinder(mesh, 0, -0.2, 1.75, 0.65, 0.7, "z", 14)
	cylinder(mesh, 0, -0.2, 2.15, 0.4, 0.14, "z", 10)
end, nil, 0.03)
part("Cord", nil, { 0.98, 0.8, 0.15 }, function(mesh)
	box(mesh, 0.45, -0.75, 2.05, 0.3, 0.14, 0.14)
end, nil, 0)
part("Bars", nil, BARE_METAL, function(mesh)
	for _, x in { -0.9, 0.9 } do
		tube(mesh, { { x, 0.9, 1.2 }, { x, 1.9, 2.8 }, { x, 2.0, 3.5 } }, 0.07, 6)
	end
	cylinder(mesh, 0, 2.0, 3.5, 0.08, 1.9, "x", 8)
end, nil, 0.03)
part("Bag", nil, { 0.2, 0.36, 0.22 }, function(mesh)
	sphere(mesh, 0, 1.5, 1.4, 0.95, 0.7, 0.75, 6, 12)
end, true, RUBBER)
-- include: JunkrotFace
