-- Rock Engine: a seized V engine block half sunk into the ground like a
-- boulder, with its cylinder heads, rocker covers, pulley and stubs of
-- manifold showing. Centered on the origin.
part("Block", nil, RUST_DARK, function(mesh)
	box(mesh, 0, 0, -0.2, 3.0, 1.8, 1.4)
	-- Cylinder banks leaning out in a V.
	for _, side in { -1, 1 } do
		for i = 0, 3 do
			local x = -1.05 + i * 0.7
			cylinder(mesh, x, side * 0.65, 1.35, 0.3, 0.6, "z", 10)
		end
	end
end, nil, 0.85)

part("Heads", nil, DARK_STEEL, function(mesh)
	for _, side in { -1, 1 } do
		box(mesh, 0, side * 0.65, 1.62, 2.9, 0.8, 0.3)
	end
end, nil, 0.6)

part("RockerCovers", nil, RUST_ORANGE, function(mesh)
	for _, side in { -1, 1 } do
		box(mesh, 0, side * 0.65, 1.9, 2.6, 0.55, 0.22)
	end
end, nil, 0.7)

part("Pulleys", nil, STEEL, function(mesh)
	cylinder(mesh, 1.62, 0, 0.6, 0.45, 0.14, "x", 16)
	cylinder(mesh, 1.62, 0.5, 1.15, 0.22, 0.12, "x", 12)
	cylinder(mesh, 1.62, -0.55, 1.1, 0.18, 0.12, "x", 12)
	bolt(mesh, 1.7, 0, 0.6, "x", 0.08)
end, nil, 0.4)

part("Belt", nil, RUBBER_BLACK, function(mesh)
	strut(mesh, 1.66, 0.42, 0.45, 1.66, 0.65, 1.1, 0.06)
	strut(mesh, 1.66, -0.4, 0.5, 1.66, -0.68, 1.05, 0.06)
end, nil, RUBBER)

part("Manifold", nil, RUST_FLAKE, function(mesh)
	for i = 0, 3 do
		local x = -1.05 + i * 0.7
		tube(mesh, { { x, 1.05, 1.45 }, { x, 1.35, 1.1 }, { x + 0.2, 1.4, 0.6 } }, 0.09, 8)
	end
	cylinder(mesh, -0.95 + 0.85 * 1, 1.4, 0.5, 0.14, 2.2, "x", 10)
end, nil, 0.9)

finishParts()
