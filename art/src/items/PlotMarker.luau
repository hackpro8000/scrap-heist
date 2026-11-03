-- Plot Marker: the post at a yard entrance naming its owner, about 2.2
-- studs tall (3.3 in the yard, 60% of a player's height). A short steel
-- post with a sign board bolted flat to its front, a blank face for the
-- owner's name, and a warning lamp on top that will flash on a raid.
-- Nothing reaches out past the post, so there is nothing to walk into.
local HAZARD_YELLOW = { 0.9, 0.72, 0.15 }
local LAMP_RED = { 0.85, 0.18, 0.12 }

part("Post", nil, DARK_STEEL, function(mesh)
	box(mesh, 0, 0, 0, 0.7, 0.7, 0.12)
	box(mesh, 0, 0, 0.12, 0.25, 0.25, 1.68)
	-- Cap the lamp stands on.
	box(mesh, 0, 0, 1.8, 0.34, 0.34, 0.04)
end, nil, 0.5)
part("Sign", nil, HAZARD_YELLOW, function(mesh)
	box(mesh, 0, -0.22, 0.7, 1.5, 0.1, 0.85)
	box(mesh, 0, -0.28, 0.78, 1.24, 0.04, 0.69)
end, nil, 0.45)
part("Lamp", nil, LAMP_RED, function(mesh)
	cylinder(mesh, 0, 0, 1.96, 0.16, 0.24, "z", 12)
	sphere(mesh, 0, 0, 2.08, 0.15, 0.15, 0.12, 6, 12)
end, nil, 0)
part("Fittings", nil, STEEL, function(mesh)
	-- Anchor bolts on the base, and brackets holding the sign to the post.
	for _, x in { -0.24, 0.24 } do
		for _, y in { -0.24, 0.24 } do
			bolt(mesh, x, y, 0.12, "z", 0.05)
		end
	end
	for _, z in { 0.86, 1.36 } do
		box(mesh, 0, -0.15, z, 0.4, 0.1, 0.1)
		for _, x in { -0.5, 0.5 } do
			bolt(mesh, x, -0.28, z + 0.05, "y", 0.04)
		end
	end
	-- Conduit carrying power up the back of the post to the lamp.
	box(mesh, 0, 0.2, 0.3, 0.2, 0.15, 0.25)
	tube(mesh, { { 0, 0.17, 0.55 }, { 0, 0.16, 1.76 }, { 0, 0.08, 1.86 } }, 0.035, 6)
	-- Wire cage guarding the lamp.
	for i = 0, 3 do
		local a = i * TAU / 4 + TAU / 8
		strut(mesh, math.cos(a) * 0.2, math.sin(a) * 0.2, 1.84, math.cos(a) * 0.2, math.sin(a) * 0.2, 2.16, 0.03)
	end
	ring(mesh, 0, 0, 2.16, 0.17, 0.22, 0.035, "z", 12)
	ring(mesh, 0, 0, 1.86, 0.17, 0.23, 0.05, "z", 12)
end, nil, 0.5)
finishParts()
