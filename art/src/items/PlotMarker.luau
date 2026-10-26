-- Plot Marker: the post at a yard entrance naming its owner, about 7.5
-- studs tall. A steel post with an arm, a hanging sign with a blank face
-- for the owner's name, and a warning lamp on top that will flash on a raid.
BRUSHED = true
local HAZARD_YELLOW = { 0.9, 0.72, 0.15 }
local LAMP_RED = { 0.85, 0.18, 0.12 }

part("Post", nil, DARK_STEEL, function(mesh)
	box(mesh, 0, 0, 0, 0.9, 0.9, 0.2)
	box(mesh, 0, 0, 0.2, 0.35, 0.35, 6.8)
	box(mesh, 1.2, 0, 6.6, 2.6, 0.2, 0.2)
	strut(mesh, 0.1, 0, 5.6, 1.1, 0, 6.6, 0.12)
	for _, x in { 0.6, 2.2 } do
		cylinder(mesh, x, 0, 6.35, 0.03, 0.5, "z", 6)
	end
end, nil, 0.5)
part("Sign", nil, HAZARD_YELLOW, function(mesh)
	box(mesh, 1.4, 0, 4.1, 2.2, 0.1, 2.0)
	box(mesh, 1.4, -0.06, 4.3, 1.8, 0.04, 1.6)
end, nil, 0.45)
part("Lamp", nil, LAMP_RED, function(mesh)
	cylinder(mesh, 0, 0, 7.2, 0.26, 0.4, "z", 12)
	sphere(mesh, 0, 0, 7.4, 0.24, 0.24, 0.2, 6, 12)
end, nil, 0)
part("Fittings", nil, STEEL, function(mesh)
	-- Anchor bolts on the base and a conduit carrying power to the lamp.
	for _, x in { -0.32, 0.32 } do
		for _, y in { -0.32, 0.32 } do
			bolt(mesh, x, y, 0.2, "z", 0.06)
		end
	end
	box(mesh, 0, -0.32, 1.0, 0.4, 0.3, 0.5)
	tube(mesh, { { 0, -0.27, 1.5 }, { 0, -0.24, 6.8 }, { 0, -0.12, 7.1 } }, 0.05, 6)
	-- Wire cage guarding the lamp.
	for i = 0, 3 do
		local a = i * TAU / 4 + TAU / 8
		strut(mesh, math.cos(a) * 0.3, math.sin(a) * 0.3, 7.15, math.cos(a) * 0.3, math.sin(a) * 0.3, 7.6, 0.04)
	end
	ring(mesh, 0, 0, 7.6, 0.26, 0.32, 0.05, "z", 12)
	ring(mesh, 0, 0, 7.15, 0.26, 0.34, 0.08, "z", 12)
	-- Shackles where the sign hangs.
	for _, x in { 0.6, 2.2 } do
		ring(mesh, x, 0, 6.15, 0.04, 0.09, 0.04, "y", 8)
	end
end, nil, 0.5)
finishParts()
