-- Boltolo Lonelo: one lost bolt standing on its thread, hex head up, 2.8
-- studs tall.
local FACE = { { -0.22, -0.46, 1.5, 0.2 }, { 0.22, -0.46, 1.55, 0.22 } }
local FEET = { 0.5, 0.55 }
part("Shank", nil, STEEL, function(mesh)
	cylinder(mesh, 0, 0, 1.35, 0.42, 1.6, "z", 14)
end, nil, 0.6)
part("Thread", nil, DARK_STEEL, function(mesh)
	for k = 0, 4 do
		ring(mesh, 0, 0, 0.68 + k * 0.14, 0.4, 0.5, 0.07, "z", 14)
	end
end, nil, 0.65)
part("Head", nil, STEEL, function(mesh)
	cylinder(mesh, 0, 0, 2.45, 0.85, 0.6, "z", 6)
	cylinder(mesh, 0, 0, 2.78, 0.6, 0.06, "z", 14)
end, nil, 0.7)
-- include: JunkrotFace
