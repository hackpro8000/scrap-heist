-- Scrap Tree (Antenna): a rooftop TV antenna mast planted in a tyre, its
-- crossbars stacked like the tiers of a pine, narrowing toward the top.
part("Mast", nil, DARK_STEEL, function(mesh)
	cylinder(mesh, 0, 0, 5.5, 0.14, 11, "z", 8)
	for _, a in { 0, 2.1, 4.2 } do
		strut(mesh, 0, 0, 6, math.cos(a) * 1.6, math.sin(a) * 1.6, 0.4, 0.06)
	end
end, nil, 0.5)

part("Elements", nil, STEEL, function(mesh)
	for tier = 0, 7 do
		local z = 3 + tier * 1
		local half = 2.6 - tier * 0.3
		local turn = tier * 0.5
		local dx, dy = math.cos(turn) * half, math.sin(turn) * half
		strut(mesh, -dx, -dy, z, dx, dy, z - 0.3, 0.07)
		strut(mesh, -dy, dx, z + 0.3, dy, -dx, z, 0.05)
	end
	ring(mesh, 0, 0, 11, 0.2, 0.5, 0.08, "z", 10)
end, nil, 0.4)

part("Tyre", nil, RUBBER_BLACK, function(mesh)
	ring(mesh, 0, 0, 0.3, 0.6, 1.2, 0.6, "z", 14)
end, nil, RUBBER)

part("Cable", nil, COPPER, function(mesh)
	tube(mesh, { { 0.1, 0.1, 10.5 }, { 0.3, 0.2, 6 }, { 0.6, 0.4, 1 }, { 1.4, 0.8, 0.05 } }, 0.04, 5)
end, nil, 0.2)

finishParts()
