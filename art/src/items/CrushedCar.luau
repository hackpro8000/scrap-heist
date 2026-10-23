-- Crushed Car: a single car flattened from above, roof pressed into the
-- cabin and wheels splayed. Centered on the origin.
local PAINT = { 0.45, 0.5, 0.2 }

part("Body", nil, PAINT, function(mesh)
	box(mesh, 0, 0, 0.35, 4.4, 1.9, 0.5)
	box(mesh, -0.2, 0, 0.85, 2.0, 1.7, 0.22)
	box(mesh, 1.7, 0, 0.85, 0.9, 1.8, 0.1)
	box(mesh, -1.9, 0.1, 0.85, 0.7, 1.7, 0.18)
end, nil, 0.75)

part("Glass", nil, DARK_STEEL, function(mesh)
	box(mesh, 0.9, 0, 0.85, 0.5, 1.6, 0.12)
	box(mesh, 0.5, 0.6, 0, 0.3, 0.2, 0.03)
	box(mesh, 0.8, 0.9, 0, 0.2, 0.15, 0.03)
end, nil, 0.3)

part("Wheels", nil, RUBBER_BLACK, function(mesh)
	for _, x in { -1.4, 1.4 } do
		for _, s in { -1, 1 } do
			cylinder(mesh, x, s * 1.0, 0.36, 0.38, 0.28, "y", 12)
		end
	end
end, nil, RUBBER)

part("Bumpers", nil, BARE_METAL, function(mesh)
	box(mesh, 2.25, 0, 0.3, 0.15, 1.8, 0.2)
	strut(mesh, -2.25, -0.9, 0.35, -2.4, 0.9, 0.05, 0.12)
end, nil, 0.4)

finishParts()
