-- Circuit Board: rare loot, about 1.1 studs across, lying flat. A green
-- board with copper traces, chips and a blue processor.
part("Board", nil, { 0.18, 0.4, 0.22 }, function(mesh)
	box(mesh, 0, 0, 0, 1.1, 0.75, 0.05)
end, nil, 0.25)
part("Traces", nil, COPPER, function(mesh)
	for i = -2, 2 do
		box(mesh, -0.1, i * 0.12, 0.05, 0.7, 0.02, 0.01)
	end
end, nil, 0.1)
part("Chips", nil, { 0.12, 0.12, 0.14 }, function(mesh)
	box(mesh, -0.38, -0.2, 0.05, 0.16, 0.22, 0.06)
	box(mesh, -0.38, 0.2, 0.05, 0.16, 0.22, 0.06)
	cylinder(mesh, 0.42, 0.25, 0.17, 0.07, 0.24, "z", 10)
end, nil, RUBBER)
part("Processor", nil, RARE, function(mesh)
	box(mesh, 0.15, 0, 0.05, 0.32, 0.32, 0.08)
end, nil, 0.15)
finishParts()
