-- Mopa Mopetta: a little moped in fresh sky blue, seen side on: two fat
-- wheels, a step-through frame, a sprung seat and a round headlamp, 3.3
-- studs tall and 3.8 long.
local FACE = { { 0.35, -0.5, 2.25, 0.24 }, { 0.95, -0.5, 2.3, 0.27 } }
local FEET = { 1.2, 0.35 }
local SKY = { 0.35, 0.68, 0.88 }
part("Wheels", nil, RUBBER_BLACK, function(mesh)
	for _, x in { -1.25, 1.25 } do
		ring(mesh, x, 0, 1.05, 0.35, 0.7, 0.4, "y", 16)
	end
end, nil, RUBBER)
part("Hubs", nil, BARE_METAL, function(mesh)
	for _, x in { -1.25, 1.25 } do
		cylinder(mesh, x, 0, 1.05, 0.36, 0.3, "y", 12)
	end
end, nil, 0.05)
part("Body", nil, SKY, function(mesh)
	box(mesh, -0.9, 0, 1.3, 1.5, 0.7, 0.9)
	box(mesh, 0.1, 0, 1.2, 0.9, 0.6, 0.3)
	-- The leg shield and the fork up to the bars.
	box(mesh, 0.9, 0, 1.3, 0.2, 0.8, 1.3)
	strut(mesh, 1.25, 0, 1.1, 0.95, 0, 2.7, 0.2)
end, nil, 0.15)
part("Seat", nil, { 0.2, 0.14, 0.1 }, function(mesh)
	box(mesh, -0.85, 0, 2.2, 1.3, 0.6, 0.3)
end, nil, RUBBER)
part("Bars", nil, BARE_METAL, function(mesh)
	cylinder(mesh, 0.92, 0, 2.85, 0.07, 1.5, "y", 8)
	sphere(mesh, 1.25, 0, 2.5, 0.3, 0.3, 0.3, 6, 12)
	tube(mesh, { { -1.6, 0.3, 1.2 }, { -2.0, 0.3, 1.1 } }, 0.1, 8)
end, nil, 0.05)
-- include: JunkrotFace
