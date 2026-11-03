-- Old Battery: uncommon loot, about 0.9 studs tall. A dented cell with a
-- green label band and a crusted terminal.
part("Cell", nil, DARK_STEEL, function(mesh)
	cylinder(mesh, 0, 0, 0.4, 0.28, 0.8, "z", 16)
end, nil, 0.6)
part("Label", nil, UNCOMMON, function(mesh)
	cylinder(mesh, 0, 0, 0.42, 0.295, 0.36, "z", 16)
end, nil, 0.25)
part("Terminal", nil, STEEL, function(mesh)
	cylinder(mesh, 0, 0, 0.86, 0.09, 0.12, "z", 10)
	ring(mesh, 0, 0, 0.81, 0.1, 0.24, 0.03, "z", 16)
end, nil, 0.5)
finishParts()
