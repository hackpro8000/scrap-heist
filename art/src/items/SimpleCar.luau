-- Simple Car: a boxy lower body with a smaller glass cabin on top and four
-- wheels, one at each corner. Centered on the origin.
local PAINT = { 0.6, 0.15, 0.15 }

part("Body", nil, PAINT, function(mesh)
	box(mesh, 0, 0, 0.35, 4.2, 1.9, 0.5)
	box(mesh, -0.2, 0, 0.85, 2.2, 1.7, 0.4)
end, nil, 0.75)

part("Glass", nil, DARK_STEEL, function(mesh)
	box(mesh, -0.2, 0, 1.05, 2.0, 1.72, 0.2)
end, nil, 0.3)

part("Wheels", nil, RUBBER_BLACK, function(mesh)
	for _, x in { -1.4, 1.4 } do
		for _, s in { -1, 1 } do
			cylinder(mesh, x, s * 1.0, 0.36, 0.38, 0.28, "y", 12)
		end
	end
end, nil, RUBBER)

finishParts()
