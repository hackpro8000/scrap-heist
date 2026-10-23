-- Vending Machine: a gutted vending machine with its glass front smashed,
-- a few cans spilled. Centered on the origin.
local CASE = { 0.18, 0.3, 0.55 }

part("Case", nil, CASE, function(mesh)
	box(mesh, 0, 0, 0, 1.4, 1.0, 2.8)
end, nil, 0.6)

part("Window", nil, DARK_STEEL, function(mesh)
	box(mesh, -0.2, -0.51, 0.9, 0.85, 0.02, 1.6)
	for i = 0, 3 do
		box(mesh, -0.2, -0.45, 1.0 + i * 0.4, 0.8, 0.1, 0.03)
	end
	box(mesh, 0.45, -0.52, 1.3, 0.25, 0.04, 0.6)
	box(mesh, -0.2, -0.52, 0.3, 0.8, 0.04, 0.25)
end, nil, 0.5)

part("Cans", nil, { 0.62, 0.16, 0.12 }, function(mesh)
	for i = 0, 2 do
		cylinder(mesh, -0.5 + i * 0.25, -0.4, 1.53, 0.08, 0.22, "z", 8)
	end
	cylinder(mesh, 0.2, -0.9, 0.08, 0.08, 0.22, "x", 8)
	cylinder(mesh, -0.4, -1.1, 0.08, 0.08, 0.22, "y", 8)
end, nil, 0.4)

part("Glass", nil, { 0.55, 0.7, 0.75 }, function(mesh)
	box(mesh, 0.3, -0.8, 0, 0.2, 0.15, 0.03)
	box(mesh, -0.3, -0.7, 0, 0.15, 0.2, 0.03)
end, true, 0)

finishParts()
