-- Canetto Rustini: a rusty tin can with a torn label and its lid bent up
-- like a cap, 2.7 studs tall.
local FACE = { { -0.3, -0.72, 1.75, 0.26 }, { 0.32, -0.72, 1.8, 0.3 } }
local FEET = { 0.8, 0.6 }
part("Can", nil, BARE_METAL, function(mesh)
	cylinder(mesh, 0, 0, 1.5, 0.78, 1.8, "z", 16)
	ring(mesh, 0, 0, 0.66, 0.7, 0.82, 0.12, "z", 16)
	ring(mesh, 0, 0, 2.36, 0.7, 0.82, 0.12, "z", 16)
end, nil, 0.9)
part("Label", nil, { 0.72, 0.2, 0.16 }, function(mesh)
	ring(mesh, 0, 0, 1.2, 0.78, 0.81, 0.7, "z", 16)
end, nil, 0.6)
part("Lid", nil, RUST_ORANGE, function(mesh)
	-- Peeled back on one hinge of tin.
	strut(mesh, -0.6, 0.3, 2.4, 0.5, 0.5, 2.95, 0.07)
	cylinder(mesh, 0.1, 0.45, 2.78, 0.62, 0.07, "y", 14)
end, nil, 0.85)
-- include: JunkrotFace
