-- Oilcanna Gluglu: a squat oil can with a long bent spout that drips, a
-- thumb pump on top, 3.2 studs tall.
local FACE = { { -0.32, -0.9, 1.3, 0.26 }, { 0.34, -0.9, 1.35, 0.29 } }
local FEET = { 0.9, 0.5 }
local CAN_GREEN = { 0.2, 0.42, 0.3 }
part("Can", nil, CAN_GREEN, function(mesh)
	cylinder(mesh, 0, 0, 1.2, 0.95, 1.3, "z", 16)
	sphere(mesh, 0, 0, 1.85, 0.95, 0.95, 0.5, 6, 16)
end, true, 0.6)
part("Spout", nil, STEEL, function(mesh)
	tube(mesh, { { 0.3, 0, 2.2 }, { 0.8, 0, 2.9 }, { 1.5, 0, 3.15 }, { 2.0, 0, 2.9 } }, 0.09, 8)
	cylinder(mesh, 0, 0, 2.35, 0.26, 0.24, "z", 10)
end, true, 0.5)
part("Pump", nil, STEEL, function(mesh)
	cylinder(mesh, -0.45, 0, 2.5, 0.08, 0.6, "z", 6)
	cylinder(mesh, -0.45, 0, 2.84, 0.24, 0.1, "z", 10)
end, nil, 0.5)
part("Drip", nil, { 0.1, 0.08, 0.05 }, function(mesh)
	sphere(mesh, 2.02, 0, 2.7, 0.1, 0.1, 0.16, 5, 8)
	-- An oily run down the front.
	cylinder(mesh, 0.5, -0.82, 1.5, 0.1, 0.9, "z", 6)
end, true, 0)
-- include: JunkrotFace
