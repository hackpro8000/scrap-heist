-- Pressurwasho Sprizzo: an upright pressure washer in bright yellow on two
-- wheels, its black hose coiled on a hook and the lance held up like a
-- spear. 3.9 studs tall.
local FACE = { { -0.38, -0.72, 2.3, 0.25 }, { 0.38, -0.72, 2.35, 0.28 } }
local FEET = { 0.9, 0.45 }
local WASH_YELLOW = { 1.0, 0.84, 0.1 }
part("Body", nil, WASH_YELLOW, function(mesh)
	box(mesh, 0, 0, 0.6, 1.7, 1.3, 2.4)
	cylinder(mesh, 0, 0, 3.0, 0.65, 1.7, "x", 14)
end, nil, 0.03)
part("Wheels", nil, RUBBER_BLACK, function(mesh)
	for _, x in { -1.0, 1.0 } do
		cylinder(mesh, x, 0.5, 0.95, 0.55, 0.3, "x", 14)
	end
end, nil, RUBBER)
part("Hose", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	for k = 0, 2 do
		ring(mesh, 0.9 + k * 0.08, -0.1, 2.0, 0.42, 0.6, 0.1, "x", 14)
	end
end, nil, RUBBER)
part("Lance", nil, BARE_METAL, function(mesh)
	strut(mesh, -0.95, -0.2, 1.4, -1.25, -0.4, 3.9, 0.09)
	box(mesh, -0.95, -0.2, 1.1, 0.24, 0.3, 0.6)
end, nil, 0.03)
part("Badge", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	box(mesh, 0, -0.66, 1.0, 1.0, 0.03, 0.5)
end, nil, 0)
-- include: JunkrotFace
