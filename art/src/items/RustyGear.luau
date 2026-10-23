-- Rusty Gear: common loot, about 1 stud across, lying flat on the origin.
part("Gear", nil, STEEL, function(mesh)
	gear(mesh, 0, 0, 0.08, 0.5, 0.14, 12, "z")
end, nil, 0.85)
part("Hub", nil, COMMON, function(mesh)
	ring(mesh, 0, 0, 0.16, 0.12, 0.22, 0.05, "z", 12)
end, nil, 0.3)
finishParts()
