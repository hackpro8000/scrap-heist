-- Microndo Bippetto: a microwave with a dark glass door for a face, a
-- keypad down one side and a turntable plate for a hat, 2.9 studs tall.
local FACE = { { -0.75, -0.95, 1.7, 0.26 }, { -0.1, -0.95, 1.75, 0.3 } }
local FEET = { 1.3, 0.55 }
local CREAM = { 0.9, 0.87, 0.78 }
part("Case", nil, CREAM, function(mesh)
	box(mesh, 0, 0, 0.65, 3.0, 1.8, 1.9)
end, nil, 0.15)
part("Glass", nil, { 0.1, 0.12, 0.14 }, function(mesh)
	box(mesh, -0.42, -0.92, 0.85, 1.9, 0.06, 1.5)
end, nil, 0.05)
part("Keypad", nil, { 0.25, 0.27, 0.3 }, function(mesh)
	box(mesh, 1.05, -0.92, 0.85, 0.7, 0.05, 1.5)
end, nil, 0.1)
part("Keys", nil, { 0.5, 0.9, 0.6 }, function(mesh)
	for row = 0, 3 do
		for column = 0, 1 do
			box(mesh, 0.9 + column * 0.3, -0.96, 1.0 + row * 0.3, 0.2, 0.04, 0.2)
		end
	end
end, nil, 0.05)
part("Plate", nil, { 0.8, 0.88, 0.9 }, function(mesh)
	cylinder(mesh, 0.1, 0, 2.62, 0.9, 0.08, "z", 18)
	ring(mesh, 0.1, 0, 2.68, 0.8, 0.92, 0.08, "z", 18)
end, nil, 0.05)
-- include: JunkrotFace
