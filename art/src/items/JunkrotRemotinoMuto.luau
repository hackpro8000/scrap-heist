-- Remotino Muto: a dead TV remote standing on end, battery door missing,
-- 3 studs tall.
local FACE = { { -0.2, -0.24, 2.45, 0.18 }, { 0.2, -0.24, 2.5, 0.2 } }
local FEET = { 0.5, 0.55 }
part("Body", nil, { 0.16, 0.16, 0.18 }, function(mesh)
	box(mesh, 0, 0, 0.6, 0.95, 0.4, 2.4)
end, nil, 0.5)
part("Buttons", nil, { 0.55, 0.55, 0.58 }, function(mesh)
	for row = 0, 3 do
		for column = -1, 1 do
			box(mesh, column * 0.26, -0.23, 0.9 + row * 0.3, 0.16, 0.06, 0.16)
		end
	end
end, nil, 0.4)
part("Power", nil, { 0.9, 0.16, 0.12 }, function(mesh)
	cylinder(mesh, 0, -0.22, 2.82, 0.11, 0.08, "y", 10)
end, nil, 0.2)
part("Battery", nil, COPPER, function(mesh)
	-- One cell hangs out of the open back.
	cylinder(mesh, 0.1, 0.26, 1.0, 0.14, 0.7, "z", 10)
end, nil, 0.7)
-- include: JunkrotFace
