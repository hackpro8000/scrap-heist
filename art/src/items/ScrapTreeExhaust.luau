-- Scrap Tree (Exhaust): a trunk of exhaust pipes bundled with wire, splaying
-- at the top into branches, each tipped with a muffler-can cluster for leaves.
part("Pipes", nil, DARK_STEEL, function(mesh)
	for i = 0, 3 do
		local a = i * math.pi / 2
		local ox, oy = math.cos(a) * 0.25, math.sin(a) * 0.25
		local tx, ty = math.cos(a) * 2.2, math.sin(a) * 2.2
		exhaust(mesh, { { ox * 2, oy * 2, 0 }, { ox, oy, 2 }, { ox, oy, 5 }, { tx, ty, 7.5 } }, 0.16)
	end
end, true, 0.7)

part("Mufflers", nil, STEEL, function(mesh)
	for i = 0, 3 do
		local a = i * math.pi / 2
		local x, y = math.cos(a) * 2.2, math.sin(a) * 2.2
		cylinder(mesh, x, y, 7.4, 0.55, 1.6, "z", 10)
		cylinder(mesh, x * 0.6, y * 0.6, 8.2, 0.45, 1.3, "z", 10)
	end
	cylinder(mesh, 0, 0, 8.6, 0.6, 1.4, "z", 10)
end, nil, 0.6)

part("Lashing", nil, COPPER, function(mesh)
	for _, z in { 1.5, 3, 4.5 } do
		ring(mesh, 0, 0, z, 0.38, 0.48, 0.12, "z", 10)
	end
end, nil, 0.3)

finishParts()
