-- Gascanini Honkini: a goose beaten out of chrome tin, a jerry-can jet
-- engine slung under each wing and its beak wide open mid-honk. 3.7
-- studs tall. Rebuilt from scrap, in our own look.
local FACE = { { -0.22, -1.0, 3.2, 0.18 }, { 0.22, -1.0, 3.25, 0.2 } }
local FEET = { 0.7, 0.7 }
part("Body", nil, BARE_METAL, function(mesh)
	sphere(mesh, 0, 0.2, 1.6, 0.8, 1.3, 0.75, 8, 16)
	tube(mesh, { { 0, -0.6, 1.9 }, { 0, -0.9, 2.6 }, { 0, -0.75, 3.1 } }, 0.24, 10)
	sphere(mesh, 0, -0.8, 3.2, 0.34, 0.4, 0.32, 6, 12)
end, true, 0.05)
part("Wings", nil, BARE_METAL, function(mesh)
	for _, side in { -1, 1 } do
		sphere(mesh, side * 1.5, 0.2, 1.9, 0.9, 0.55, 0.07, 5, 12)
	end
end, true, 0.05)
part("Beak", nil, { 1.0, 0.6, 0.1 }, function(mesh)
	strut(mesh, 0, -1.1, 3.25, 0, -1.6, 3.4, 0.16)
	strut(mesh, 0, -1.1, 3.1, 0, -1.55, 2.95, 0.14)
end, nil, 0.03)
part("JerryCans", nil, { 0.8, 0.14, 0.12 }, function(mesh)
	for _, side in { -1, 1 } do
		box(mesh, side * 1.5, 0.2, 1.2, 0.5, 1.1, 0.6)
		cylinder(mesh, side * 1.5, -0.45, 1.5, 0.22, 0.3, "y", 10)
	end
end, nil, 0.05)
part("Jets", nil, { 0.5, 0.8, 1.0 }, function(mesh)
	for _, side in { -1, 1 } do
		cylinder(mesh, side * 1.5, 1.0, 1.5, 0.2, 0.5, "y", 10)
	end
end, nil, 0, nil, 1.8)
-- include: JunkrotFace
