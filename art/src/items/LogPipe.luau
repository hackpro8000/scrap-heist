-- Log Pipe: a fallen length of rusted culvert pipe lying like a log, with
-- flanged ends, a split along its side and a rubble bed. Centered on the
-- origin, running along x.
part("Pipe", nil, RUST_ORANGE, function(mesh)
	ring(mesh, 0, 0, 0.55, 0.42, 0.55, 5.0, "x", 14)
end, nil, 0.8)

part("Flanges", nil, RUST_DARK, function(mesh)
	for _, x in { -2.5, 2.5 } do
		ring(mesh, x, 0, 0.55, 0.42, 0.7, 0.14, "x", 14)
	end
	ring(mesh, 0.4, 0, 0.55, 0.5, 0.6, 0.12, "x", 14)
end, nil, 0.85)

part("Rubble", nil, DARK_STEEL, function(mesh)
	box(mesh, -1.2, 0.6, 0, 0.4, 0.3, 0.15)
	box(mesh, 1.6, -0.6, 0, 0.3, 0.3, 0.12)
	bolt(mesh, 2.5, 0.62, 0.55, "x", 0.06)
end, nil, 0.6)

finishParts()
