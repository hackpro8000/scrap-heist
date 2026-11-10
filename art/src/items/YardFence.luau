-- Yard Fence: one 8-stud panel of a yard's boundary, about 5 studs tall.
-- Corrugated sheets between two posts, held by rails and a diagonal brace
-- behind. Panels tile end to end along x, centered on the origin.
-- include: HandFinish
part("Posts", nil, DARK_STEEL, function(mesh)
	for _, x in { -4, 4 } do
		box(mesh, x, 0, 0, 0.4, 0.4, 5.2)
		box(mesh, x, 0, 5.2, 0.5, 0.5, 0.1)
	end
	for _, z in { 0.8, 4.2 } do
		box(mesh, 0, 0.18, z, 7.6, 0.12, 0.2)
	end
	strut(mesh, -3.7, 0.28, 0.9, 3.7, 0.28, 4.3, 0.14)
	-- Rails over the sheets' top and bottom edges, on the face, so it reads as built.
	box(mesh, 0, -0.08, 4.72, 7.6, 0.14, 0.16)
	box(mesh, 0, -0.08, 0.2, 7.6, 0.14, 0.16)
	-- A stiffening rail across the sheets' middle.
	box(mesh, 0, -0.1, 2.5, 7.6, 0.16, 0.18)
end, nil, 0.5)
part("Sheets", nil, STEEL, function(mesh)
	for i = 0, 9 do
		-- Thick enough that neighbouring sheets overlap at their laps.
		box(mesh, -3.42 + i * 0.76, (i % 2) * 0.1 - 0.05, 0.3, 0.76, 0.14, 4.5)
	end
	for i = 0, 3 do
		-- Each bolt sits on the face of whichever sheet it lands on.
		local x = -3 + i * 2
		local y = if math.floor((x + 3.8) / 0.76) % 2 == 0 then -0.14 else -0.04
		bolt(mesh, x, y, 4.3, "y", 0.07)
		bolt(mesh, x, y, 0.9, "y", 0.07)
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
			box(mesh, x - math.sign(x) * 0.3, 0.2, z, 0.2, 0.2, 0.3)
			bolt(mesh, x - math.sign(x) * 0.3, 0.3, z + 0.15, "y", 0.05)
		end
	end
end, nil, 0.6)
handFinish({
	Posts = "metal",
	Sheets = "metal",
	Fittings = "metal",
}, {}, PROP_FINISH)
-- Thin sheets outline hard under a heavy contact shadow.
for _, entry in parts do
	if entry.name == "Sheets" then
		-- Seams darken in a narrow, lighter line, so the panels aren't inked.
		entry.shade, entry.edge = 1.2, 0.2
	end
end
finishParts()
