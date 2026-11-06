-- Boilerdiro Crockpotilo: a crocodile of riveted plate with a boiler tank
-- for a belly, stub wings with a propeller on each and a row of teeth cut
-- from a saw blade. 3.2 studs tall, 5 long. Rebuilt from scrap, in our
-- own look.
local FACE = { { 0.9, -0.5, 2.5, 0.2 }, { 1.4, -0.5, 2.45, 0.2 } }
local FEET = { 1.0, 0.55 }
local PLATE_GREEN = { 0.3, 0.44, 0.3 }
part("Boiler", nil, { 0.5, 0.42, 0.3 }, function(mesh)
	cylinder(mesh, -0.2, 0, 1.6, 0.9, 2.4, "x", 16)
	for _, x in { -1.1, -0.2, 0.7 } do
		ring(mesh, x, 0, 1.6, 0.9, 0.97, 0.1, "x", 16)
	end
end, nil, 0.1)
part("Croc", nil, PLATE_GREEN, function(mesh)
	-- Head and snout forward (+x), tail back.
	box(mesh, 1.2, 0, 1.9, 1.0, 1.0, 0.7)
	box(mesh, 2.2, 0, 2.0, 1.2, 0.8, 0.35)
	box(mesh, 2.1, 0, 1.7, 1.1, 0.7, 0.2)
	tube(mesh, { { -1.4, 0, 1.6 }, { -2.2, 0, 1.5 }, { -2.9, 0, 1.9 } }, 0.3, 8)
end, nil, 0.1)
part("Teeth", nil, BARE_METAL, function(mesh)
	for k = 0, 5 do
		for _, y in { -0.33, 0.33 } do
			cylinder(mesh, 1.75 + k * 0.17, y, 1.92, 0.05, 0.14, "z", 3)
		end
	end
end, nil, 0.03)
part("Wings", nil, PLATE_GREEN, function(mesh)
	for _, side in { -1, 1 } do
		box(mesh, -0.2, side * 1.5, 2.0, 1.1, 1.4, 0.12)
		cylinder(mesh, 0.5, side * 1.6, 2.0, 0.2, 0.5, "x", 10)
	end
end, nil, 0.1)
part("Props", nil, DARK_STEEL, function(mesh)
	for _, side in { -1, 1 } do
		sphere(mesh, 0.8, side * 1.6, 2.0, 0.03, 0.08, 0.6, 4, 8)
		sphere(mesh, 0.8, side * 1.6, 2.0, 0.03, 0.6, 0.08, 4, 8)
	end
end, true, 0.05)
part("Rivets", nil, BARE_METAL, function(mesh)
	for k = 0, 5 do
		bolt(mesh, -1.0 + k * 0.36, 0, 2.52, "z", 0.07)
	end
end, nil, 0.03)
-- include: JunkrotFace
