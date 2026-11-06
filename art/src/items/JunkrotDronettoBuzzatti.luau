-- Dronetto Buzzatti: a quadcopter standing on its skids, matte grey with
-- four rotors up on arms, a camera ball under its chin and nav lights.
-- 3 studs tall, 3.6 across.
local FACE = { { -0.3, -0.62, 1.85, 0.22 }, { 0.3, -0.62, 1.9, 0.24 } }
local FEET = { 0.8, 0.6 }
part("Body", nil, { 0.42, 0.44, 0.48 }, function(mesh)
	sphere(mesh, 0, 0, 1.7, 0.85, 0.7, 0.5, 8, 14)
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			strut(mesh, x * 0.5, y * 0.4, 1.8, x * 1.5, y * 1.2, 2.2, 0.14)
			cylinder(mesh, x * 1.5, y * 1.2, 2.35, 0.14, 0.3, "z", 8)
		end
	end
end, true, 0.03)
part("Rotors", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			sphere(mesh, x * 1.5, y * 1.2, 2.55, 0.6, 0.09, 0.02, 4, 10)
			sphere(mesh, x * 1.5, y * 1.2, 2.56, 0.09, 0.6, 0.02, 4, 10)
		end
	end
end, true, 0)
part("Camera", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	sphere(mesh, 0, -0.45, 1.2, 0.26, 0.26, 0.26, 6, 10)
end, true, 0)
part("NavRed", nil, { 1.0, 0.15, 0.1 }, function(mesh)
	sphere(mesh, -0.8, -0.3, 1.75, 0.08, 0.08, 0.08, 4, 8)
end, nil, 0, nil, 2.0)
part("NavGreen", nil, { 0.2, 1.0, 0.4 }, function(mesh)
	sphere(mesh, 0.8, -0.3, 1.75, 0.08, 0.08, 0.08, 4, 8)
end, nil, 0, nil, 2.0)
-- include: JunkrotFace
