-- Rock Boulder Pile: a pile of brake drums and discs heaped like loose
-- boulders. Centered on the origin.
part("Drums", nil, RUST_DARK, function(mesh)
	for _, d in {
		{ 0, 0, 0.35, "z" }, { 1.0, 0.3, 0.35, "z" }, { -0.9, 0.4, 0.35, "z" },
		{ 0.2, -0.9, 0.35, "z" }, { 0.4, 0.2, 1.05, "z" }, { -0.4, -0.3, 1.0, "y" },
	} do
		cylinder(mesh, d[1], d[2], d[3], 0.55, 0.7, d[4], 14)
	end
end, nil, 0.85)

part("Discs", nil, RUST_ORANGE, function(mesh)
	ring(mesh, 1.5, -0.9, 0.06, 0.2, 0.6, 0.12, "z", 16)
	ring(mesh, -1.6, -0.6, 0.06, 0.2, 0.55, 0.12, "z", 16)
	ring(mesh, 0.4, 0.2, 1.45, 0.15, 0.5, 0.1, "z", 16)
end, nil, 0.8)

part("Hubs", nil, DARK_STEEL, function(mesh)
	for _, d in { { 0, 0 }, { 1.0, 0.3 }, { -0.9, 0.4 }, { 0.2, -0.9 } } do
		cylinder(mesh, d[1], d[2], 0.72, 0.2, 0.06, "z", 10)
	end
	cylinder(mesh, 0.4, 0.2, 1.42, 0.2, 0.06, "z", 10)
end, nil, 0.5)

finishParts()
