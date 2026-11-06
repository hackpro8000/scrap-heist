-- Dishwashino Splashetto: a slimline dishwasher, bright white, its door
-- ajar with plates in the rack and a row of green lights on top. 3.5
-- studs tall.
local FACE = { { -0.4, -1.0, 2.55, 0.25 }, { 0.4, -1.0, 2.6, 0.28 } }
local FEET = { 1.0, 0.5 }
local WHITE = { 0.95, 0.96, 0.97 }
part("Cabinet", nil, WHITE, function(mesh)
	box(mesh, 0, 0.1, 0.6, 2.2, 1.9, 2.9)
end, nil, 0)
part("Door", nil, WHITE, function(mesh)
	-- Hinged at the bottom, leaning open.
	for k = 0, 5 do
		box(mesh, 0, -0.9 - k * 0.07, 0.7 + k * 0.36, 2.1, 0.1, 0.38)
	end
end, nil, 0)
part("Panel", nil, { 0.15, 0.16, 0.18 }, function(mesh)
	box(mesh, 0, -0.88, 3.05, 2.2, 0.06, 0.4)
end, nil, 0)
part("Lights", nil, { 0.35, 0.95, 0.5 }, function(mesh)
	for k = -2, 2 do
		cylinder(mesh, k * 0.3, -0.92, 3.25, 0.07, 0.04, "y", 8)
	end
end, nil, 0)
part("Plates", nil, { 0.8, 0.9, 0.95 }, function(mesh)
	for k = -2, 2 do
		cylinder(mesh, k * 0.32, -0.75, 2.75, 0.5, 0.05, "x", 14)
	end
end, nil, 0)
part("Handle", nil, BARE_METAL, function(mesh)
	cylinder(mesh, 0, -1.4, 2.6, 0.07, 1.6, "x", 8)
end, nil, 0.03)
-- include: JunkrotFace
