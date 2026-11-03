-- Junk Mound: a low, wide heap of mixed scrap players can walk over, built
-- from layered rusted plates with a few recognisable bits on top. Centered
-- on the origin.
part("Heap", nil, RUST_DARK, function(mesh)
	for i = 0, 4 do
		local s = 6 - i * 1.15
		box(mesh, (i % 2) * 0.2, -(i % 3) * 0.15, i * 0.3, s, s * 0.8, 0.32)
	end
end, nil, 0.9)

part("Plates", nil, RUST_ORANGE, function(mesh)
	strut(mesh, -2.4, -1.0, 0.2, -1.2, -0.4, 0.8, 0.08)
	box(mesh, 1.5, 1.0, 0.6, 1.2, 0.9, 0.08)
	box(mesh, -0.8, 1.3, 0.9, 0.9, 0.7, 0.08)
end, nil, 0.8)

part("Bits", nil, DARK_STEEL, function(mesh)
	ring(mesh, 0.6, -0.6, 1.55, 0.2, 0.45, 0.2, "y", 12)
	cylinder(mesh, -1.6, 0.4, 0.75, 0.25, 1.2, "x", 10)
	tube(mesh, { { 1.8, -1.4, 0.3 }, { 1.2, -0.8, 1.0 }, { 0.4, 0.2, 1.4 } }, 0.06, 6)
end, nil, 0.6)

part("Tyre", nil, RUBBER_BLACK, function(mesh)
	ring(mesh, -0.4, 0.2, 1.5, 0.25, 0.5, 0.25, "z", 14)
end, nil, RUBBER)

finishParts()
