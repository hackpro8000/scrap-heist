-- Big Spanner: the starter weapon upgrade, about 4.5 studs long. A heavy
-- steel shaft with taped grip, an open jaw on top and a ring end below.
-- Built along +Z with the grip end at the origin.
part("Shaft", nil, STEEL, function(mesh)
	box(mesh, 0, 0, 0.5, 0.32, 0.14, 3.2)
	ring(mesh, 0, 0, 0.3, 0.13, 0.32, 0.16, "y", 12)
end, nil, 0.45)
part("Jaw", nil, DARK_STEEL, function(mesh)
	box(mesh, 0, 0, 3.6, 0.9, 0.18, 0.3)
	box(mesh, -0.32, 0, 3.9, 0.26, 0.18, 0.6)
	box(mesh, 0.32, 0, 3.9, 0.26, 0.18, 0.45)
	cylinder(mesh, 0.32, 0, 3.75, 0.08, 0.24, "y", 10)
end, nil, 0.55)
part("Grip", nil, TAPE, function(mesh)
	box(mesh, 0, 0, 0.6, 0.38, 0.2, 1.1)
	for i = 0, 3 do
		box(mesh, 0, 0, 0.65 + i * 0.27, 0.42, 0.24, 0.06)
	end
end, nil, RUBBER)
finishParts()
