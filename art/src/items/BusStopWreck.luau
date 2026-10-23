-- Bus Stop Wreck: a bus shelter frame with its roof caved in, one glass
-- panel missing and a bench inside. Runs along x, centered.
part("Frame", nil, DARK_STEEL, function(mesh)
	for _, x in { -2, 2 } do
		box(mesh, x, 0.8, 0, 0.14, 0.14, 2.6)
		box(mesh, x, -0.8, 0, 0.14, 0.14, if x < 0 then 2.6 else 1.8)
	end
	box(mesh, 0, 0.8, 2.6, 4.2, 0.12, 0.12)
end, nil, 0.6)

part("Roof", nil, RUST_ORANGE, function(mesh)
	strut(mesh, -2.1, 0, 2.7, 2.1, 0, 1.9, 0.05)
	box(mesh, -1.0, 0, 2.48, 2.2, 1.8, 0.05)
end, nil, 0.75)

part("Glass", nil, { 0.55, 0.7, 0.75 }, function(mesh)
	box(mesh, -1.0, 0.82, 0.3, 1.8, 0.03, 2.0)
	box(mesh, 1.2, 0.5, 0, 0.5, 0.3, 0.03)
end, true, 0)

part("Bench", nil, STEEL, function(mesh)
	box(mesh, 0, 0.5, 0.45, 2.4, 0.4, 0.06)
	for _, x in { -1, 1 } do
		box(mesh, x, 0.5, 0, 0.08, 0.3, 0.45)
	end
end, nil, 0.5)

part("Sign", nil, { 0.18, 0.3, 0.55 }, function(mesh)
	box(mesh, -2.0, -0.8, 2.2, 0.6, 0.03, 0.4)
end, nil, 0.5)

finishParts()
