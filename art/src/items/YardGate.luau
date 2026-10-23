-- Yard Gate: the 8-stud fence panel players walk through, two barred doors
-- in a frame with a padlocked hasp where they meet. Matches YardFence so it
-- tiles into a fence line, centered on the origin.
part("Frame", nil, DARK_STEEL, function(mesh)
	for _, x in { -4, 4 } do
		box(mesh, x, 0, 0, 0.4, 0.4, 5.2)
		box(mesh, x, 0, 5.2, 0.5, 0.5, 0.1)
	end
	box(mesh, 0, 0, 5, 8.4, 0.3, 0.3)
end, nil, 0.5)
part("Doors", nil, STEEL, function(mesh)
	for _, side in { -1, 1 } do
		local cx = side * 1.92
		box(mesh, cx, 0, 0.3, 3.7, 0.14, 0.16)
		box(mesh, cx, 0, 4.4, 3.7, 0.14, 0.16)
		box(mesh, cx, 0, 2.3, 3.7, 0.12, 0.12)
		box(mesh, cx - side * 1.78, 0, 0.3, 0.16, 0.14, 4.26)
		box(mesh, cx + side * 1.78, 0, 0.3, 0.16, 0.14, 4.26)
		for i = 1, 6 do
			box(mesh, cx - 1.8 + i * 0.52, 0, 0.46, 0.06, 0.06, 3.94)
		end
		strut(mesh, cx - side * 1.7, 0.08, 0.45, cx + side * 1.7, 0.08, 4.4, 0.1)
	end
end, nil, 0.6)
part("Padlock", nil, COPPER, function(mesh)
	box(mesh, 0, -0.12, 2.1, 0.5, 0.06, 0.4)
	box(mesh, 0, -0.22, 1.7, 0.26, 0.14, 0.3)
	ring(mesh, 0, -0.22, 2.08, 0.06, 0.11, 0.05, "y", 8)
end, nil, 0.4)
finishParts()
