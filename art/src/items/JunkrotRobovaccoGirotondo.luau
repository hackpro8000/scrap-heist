-- Robovacco Girotondo: a robot vacuum up on its side like a wheel, glossy
-- white with a grey bumper, its sensor turret for a nose and one side
-- brush still spinning. 3.3 studs tall.
local FACE = { { -0.45, -0.34, 2.3, 0.24 }, { 0.45, -0.34, 2.35, 0.27 } }
local FEET = { 0.9, 0.55 }
part("Disc", nil, { 0.94, 0.95, 0.97 }, function(mesh)
	cylinder(mesh, 0, 0, 1.95, 1.3, 0.5, "y", 22)
end, nil, 0)
part("Bumper", nil, { 0.4, 0.42, 0.45 }, function(mesh)
	ring(mesh, 0, 0, 1.95, 1.26, 1.36, 0.36, "y", 22)
end, nil, 0)
part("Turret", nil, { 0.12, 0.12, 0.14 }, function(mesh)
	cylinder(mesh, 0, -0.32, 1.75, 0.3, 0.2, "y", 12)
end, nil, 0)
part("Button", nil, { 0.3, 0.9, 0.5 }, function(mesh)
	cylinder(mesh, 0, -0.28, 1.1, 0.14, 0.06, "y", 10)
end, nil, 0)
part("Brush", nil, { 0.95, 0.75, 0.1 }, function(mesh)
	for k = 0, 2 do
		local angle = k * TAU / 3 + 0.5
		strut(mesh, 1.2, -0.2, 0.9, 1.2 + math.cos(angle) * 0.45, -0.2, 0.9 + math.sin(angle) * 0.45, 0.05)
	end
end, nil, 0)
-- include: JunkrotFace
