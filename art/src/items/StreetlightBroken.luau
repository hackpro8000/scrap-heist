-- Streetlight Broken: a tall streetlight snapped halfway, its top bent over
-- and hanging, the lamp head smashed. Centered on the origin.
part("Pole", nil, DARK_STEEL, function(mesh)
	cylinder(mesh, 0, 0, 2.5, 0.16, 5.0, "z", 10)
	box(mesh, 0, 0, 0, 0.6, 0.6, 0.2)
	tube(mesh, { { 0, 0, 5.0 }, { 0.15, 0, 5.5 }, { 0.8, 0, 5.8 }, { 1.6, 0, 5.3 }, { 1.9, 0, 4.4 } }, 0.13, 8)
end, nil, 0.6)

part("Head", nil, STEEL, function(mesh)
	box(mesh, 1.9, 0, 3.8, 0.4, 0.6, 0.55)
end, nil, 0.5)

part("Glass", nil, { 0.95, 0.9, 0.62 }, function(mesh)
	box(mesh, 1.9, 0, 3.7, 0.3, 0.45, 0.1)
	box(mesh, 0.4, 0.5, 0, 0.2, 0.15, 0.04)
	box(mesh, -0.3, 0.6, 0, 0.15, 0.2, 0.04)
end, true, 0)

part("Wires", nil, COPPER, function(mesh)
	tube(mesh, { { 1.9, 0.1, 3.8 }, { 1.85, 0.2, 3.2 }, { 2.0, 0.1, 2.8 } }, 0.02, 4)
end, nil, 0.3)

finishParts()
