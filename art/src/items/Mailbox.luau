-- Mailbox: a blue street mailbox knocked askew on its legs, slot flap
-- hanging, a few letters on the ground. Centered on the origin.
local BLUE = { 0.15, 0.25, 0.5 }
local PAPER = { 0.88, 0.86, 0.8 }

part("Box", nil, BLUE, function(mesh)
	box(mesh, 0.05, 0, 0.6, 1.1, 1.0, 1.4)
	cylinder(mesh, 0.05, 0, 2.0, 0.5, 1.1, "x", 12)
	box(mesh, 0.05, -0.52, 1.6, 0.6, 0.06, 0.08)
end, nil, 0.65)

part("Legs", nil, DARK_STEEL, function(mesh)
	for _, x in { -0.45, 0.5 } do
		for _, y in { -0.4, 0.4 } do
			box(mesh, x, y, 0, 0.1, 0.1, 0.62)
		end
	end
	box(mesh, 0.05, -0.56, 1.45, 0.5, 0.04, 0.15)
end, nil, 0.6)

part("Letters", nil, PAPER, function(mesh)
	box(mesh, 0.3, -1.0, 0, 0.4, 0.25, 0.02)
	box(mesh, -0.4, -0.9, 0, 0.35, 0.22, 0.02)
	box(mesh, 0.7, -0.7, 0.02, 0.35, 0.22, 0.02)
end, nil, 0)

finishParts()
