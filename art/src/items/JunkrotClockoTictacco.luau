-- Clocko Tictacco: a twin-bell alarm clock, hands stuck at ten to two, its
-- hammer mid-swing, 3.2 studs tall.
local FACE = { { -0.36, -0.52, 1.95, 0.22 }, { 0.36, -0.52, 2.0, 0.25 } }
local FEET = { 0.9, 0.55 }
local CLOCK_RED = { 0.78, 0.2, 0.16 }
part("Case", nil, CLOCK_RED, function(mesh)
	cylinder(mesh, 0, 0, 1.7, 1.1, 0.8, "y", 20)
end, nil, 0.4)
part("Dial", nil, { 0.93, 0.9, 0.8 }, function(mesh)
	cylinder(mesh, 0, -0.38, 1.7, 0.95, 0.06, "y", 20)
end, nil, 0.3)
part("Hands", nil, { 0.08, 0.08, 0.09 }, function(mesh)
	strut(mesh, 0, -0.44, 1.7, -0.45, -0.44, 1.2, 0.07)
	strut(mesh, 0, -0.44, 1.7, 0.6, -0.44, 1.25, 0.05)
	cylinder(mesh, 0, -0.44, 1.7, 0.08, 0.06, "y", 8)
end, nil, 0.2)
part("Bells", nil, BARE_METAL, function(mesh)
	for _, side in { -1, 1 } do
		sphere(mesh, side * 0.62, 0, 2.85, 0.42, 0.36, 0.3, 6, 12)
		cylinder(mesh, side * 0.62, 0, 2.6, 0.05, 0.3, "z", 6)
	end
	-- The hammer between them.
	strut(mesh, 0, 0, 2.75, 0.2, 0, 3.15, 0.06)
	sphere(mesh, 0.22, 0, 3.2, 0.12, 0.12, 0.12, 4, 8)
end, true, 0.3)
-- include: JunkrotFace
