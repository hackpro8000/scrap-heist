-- Yard Fence: one 8-stud panel of a yard's boundary, about 5 studs tall.
-- Corrugated sheets between two posts, held by rails and a diagonal brace
-- behind. Panels tile end to end along x, centered on the origin.
part("Posts", nil, DARK_STEEL, function(mesh)
	for _, x in { -4, 4 } do
		box(mesh, x, 0, 0, 0.4, 0.4, 5.2)
		box(mesh, x, 0, 5.2, 0.5, 0.5, 0.1)
	end
	for _, z in { 0.8, 4.2 } do
		box(mesh, 0, 0.24, z, 7.6, 0.12, 0.2)
	end
	strut(mesh, -3.7, 0.36, 0.9, 3.7, 0.36, 4.3, 0.14)
end, nil, 0.5)
part("Sheets", nil, STEEL, function(mesh)
	for i = 0, 9 do
		box(mesh, -3.42 + i * 0.76, (i % 2) * 0.1 - 0.05, 0.3, 0.76, 0.06, 4.5)
	end
	for i = 0, 3 do
		bolt(mesh, -3 + i * 2, -0.12, 4.3, "y", 0.07)
		bolt(mesh, -3 + i * 2, -0.12, 0.9, "y", 0.07)
	end
end, nil, 0.7)
part("Fittings", nil, DARK_STEEL, function(mesh)
	-- Base plates anchoring each post, and clamps holding the rails.
	for _, x in { -4, 4 } do
		box(mesh, x, 0, 0, 0.8, 0.8, 0.08)
		for _, dx in { -0.28, 0.28 } do
			for _, dy in { -0.28, 0.28 } do
				bolt(mesh, x + dx, dy, 0.08, "z", 0.05)
			end
		end
		for _, z in { 0.75, 4.15 } do
			box(mesh, x - math.sign(x) * 0.3, 0.24, z, 0.2, 0.2, 0.3)
			bolt(mesh, x - math.sign(x) * 0.3, 0.34, z + 0.15, "y", 0.05)
		end
	end
end, nil, 0.6)
finishParts()
