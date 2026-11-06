-- Trashalero Trashala: a shark riveted from tin sheet, standing on three
-- pipe legs in sneakers cut from tyre rubber. 3.4 studs tall, 4 long.
-- Rebuilt from scrap, in our own look.
local FACE = { { 0.9, -0.62, 2.35, 0.2 }, { 1.45, -0.55, 2.3, 0.2 } }
local FEET = { 1.0, 0.9 }
local TIN_BLUE = { 0.5, 0.62, 0.72 }
part("Body", nil, TIN_BLUE, function(mesh)
	sphere(mesh, 0, 0, 2.1, 1.9, 0.7, 0.8, 8, 16)
end, true, 0.3)
part("Belly", nil, { 0.86, 0.87, 0.85 }, function(mesh)
	sphere(mesh, 0.2, 0, 1.85, 1.5, 0.62, 0.5, 6, 14)
end, true, 0.25)
part("Fins", nil, TIN_BLUE, function(mesh)
	-- Dorsal fin, tail, and one fin a side.
	plate(mesh, { { -0.5, 2.7 }, { -0.4, 3.5 }, { 0.3, 2.75 } }, 0, 0.08, 0.01)
	plate(mesh, { { -1.7, 2.1 }, { -2.5, 1.3 }, { -2.2, 2.1 }, { -2.5, 3.0 } }, 0, 0.08, 0.01)
	for _, side in { -1, 1 } do
		sphere(mesh, 0.3, side * 0.75, 1.8, 0.4, 0.3, 0.07, 4, 8)
	end
end, nil, 0.3)
part("Teeth", nil, { 0.95, 0.95, 0.9 }, function(mesh)
	for k = 0, 4 do
		cylinder(mesh, 1.2 + k * 0.13, -0.3 + k * 0.05, 1.82, 0.06, 0.16, "z", 3)
	end
end, nil, 0)
part("ThirdLeg", nil, DARK_STEEL, function(mesh)
	cylinder(mesh, -1.0, 0, 0.75, 0.11, 1.3, "z", 8)
end, nil, 0.4)
part("Sneakers", nil, { 0.9, 0.2, 0.2 }, function(mesh)
	box(mesh, -1.0, -0.16, 0, 0.42, 0.72, 0.3)
	for _, side in { -1, 1 } do
		box(mesh, side * 0.5, -0.16, 0.22, 0.44, 0.74, 0.1)
	end
end, nil, RUBBER)
-- include: JunkrotFace
