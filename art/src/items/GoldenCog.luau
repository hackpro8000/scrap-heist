-- Golden Cog: legendary loot, about 1 stud across, standing on edge. A
-- polished gold gear with a steel hub.
part("Cog", nil, LEGENDARY, function(mesh)
	gear(mesh, 0, 0, 0.5, 0.5, 0.16, 10, "y")
end, nil, 0.05)
part("Hub", nil, STEEL, function(mesh)
	ring(mesh, 0, 0, 0.5, 0.1, 0.2, 0.2, "y", 12)
end, nil, 0.3)
finishParts()
