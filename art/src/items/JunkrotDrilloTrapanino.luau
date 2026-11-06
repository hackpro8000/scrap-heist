-- Drillo Trapanino: a cordless drill in fresh yellow, standing on its
-- battery, chuck and bit out front like a nose, 3.3 studs tall.
local FACE = { { -0.5, -0.5, 2.75, 0.24 }, { 0.1, -0.5, 2.8, 0.27 } }
local FEET = { 0.9, 0.5 }
local TOOL_YELLOW = { 0.96, 0.78, 0.1 }
part("Motor", nil, TOOL_YELLOW, function(mesh)
	cylinder(mesh, -0.2, 0, 2.7, 0.55, 2.0, "x", 14)
end, nil, 0.15)
part("Grip", nil, { 0.13, 0.13, 0.14 }, function(mesh)
	box(mesh, -0.6, 0, 1.1, 0.7, 0.8, 1.3)
end, nil, RUBBER)
part("Battery", nil, TOOL_YELLOW, function(mesh)
	box(mesh, -0.5, 0, 0.55, 1.5, 1.0, 0.6)
end, nil, 0.15)
part("Chuck", nil, BARE_METAL, function(mesh)
	cylinder(mesh, 1.05, 0, 2.7, 0.36, 0.6, "x", 12)
	cylinder(mesh, 1.5, 0, 2.7, 0.22, 0.3, "x", 10)
	cylinder(mesh, 2.0, 0, 2.7, 0.07, 0.8, "x", 6)
end, nil, 0.05)
part("Trigger", nil, { 0.85, 0.15, 0.12 }, function(mesh)
	box(mesh, -0.15, 0, 1.95, 0.25, 0.4, 0.35)
end, nil, 0.1)
-- include: JunkrotFace
