-- Chefbot Precisio: an all-in-one kitchen robot, brushed steel jug locked
-- into a white base with a touchscreen and one dial ringed in light. 3.8
-- studs tall.
local FACE = { { -0.36, -0.86, 2.6, 0.23 }, { 0.36, -0.86, 2.65, 0.26 } }
local FEET = { 1.0, 0.5 }
part("Base", nil, { 0.95, 0.96, 0.97 }, function(mesh)
	box(mesh, 0, 0, 0.6, 2.2, 1.9, 1.2)
end, nil, 0)
part("Jug", nil, BARE_METAL, function(mesh)
	cylinder(mesh, 0, 0.1, 2.5, 0.85, 1.5, "z", 18)
	ring(mesh, 0, 0.1, 3.2, 0.8, 0.9, 0.08, "z", 18)
	box(mesh, 1.0, 0.1, 2.2, 0.3, 0.3, 0.9)
end, nil, 0.03)
part("Lid", nil, { 0.14, 0.14, 0.16 }, function(mesh)
	cylinder(mesh, 0, 0.1, 3.35, 0.78, 0.18, "z", 18)
	cylinder(mesh, 0, 0.1, 3.5, 0.3, 0.2, "z", 12)
end, nil, 0)
part("Screen", nil, { 0.3, 0.75, 1.0 }, function(mesh)
	box(mesh, -0.35, -0.96, 0.9, 1.0, 0.03, 0.6)
end, nil, 0, nil, 1.0)
part("DialGlow", nil, { 0.4, 1.0, 0.6 }, function(mesh)
	ring(mesh, 0.65, -0.97, 1.2, 0.2, 0.27, 0.04, "y", 14)
end, nil, 0, nil, 1.2)
part("Dial", nil, BARE_METAL, function(mesh)
	cylinder(mesh, 0.65, -0.99, 1.2, 0.2, 0.1, "y", 14)
end, nil, 0.03)
-- include: JunkrotFace
