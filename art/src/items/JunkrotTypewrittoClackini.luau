-- Typewritto Clackini: a typewriter in fresh teal, round keys in rows down
-- its front, a sheet of paper curling out of the roller, 3 studs tall.
local FACE = { { -0.45, -0.72, 2.05, 0.24 }, { 0.45, -0.72, 2.1, 0.27 } }
local FEET = { 1.2, 0.5 }
local TEAL = { 0.16, 0.56, 0.58 }
part("Body", nil, TEAL, function(mesh)
	box(mesh, 0, 0.4, 0.6, 2.8, 1.5, 1.6)
	box(mesh, 0, -0.75, 0.6, 2.8, 1.0, 0.6)
end, nil, 0.15)
part("Keys", nil, { 0.93, 0.9, 0.82 }, function(mesh)
	for row = 0, 2 do
		for column = -4, 4 do
			cylinder(mesh, column * 0.28 + (row % 2) * 0.14, -1.05 + row * 0.3, 1.26 + row * 0.12, 0.1, 0.08, "z", 8)
		end
	end
end, nil, 0.05)
part("Roller", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	cylinder(mesh, 0, 0.6, 2.4, 0.3, 3.2, "x", 12)
end, nil, RUBBER)
part("Paper", nil, { 0.96, 0.95, 0.9 }, function(mesh)
	box(mesh, 0, 0.75, 2.5, 1.8, 0.04, 1.1)
	box(mesh, 0, 0.9, 3.55, 1.8, 0.3, 0.04)
end, nil, 0, nil, nil, true)
part("Lever", nil, BARE_METAL, function(mesh)
	tube(mesh, { { -1.6, 0.6, 2.4 }, { -2.0, 0.4, 2.7 }, { -2.0, 0.0, 2.8 } }, 0.06, 6)
	for _, x in { -1.65, 1.65 } do
		cylinder(mesh, x, 0.6, 2.4, 0.22, 0.12, "x", 10)
	end
end, nil, 0.05)
-- include: JunkrotFace
