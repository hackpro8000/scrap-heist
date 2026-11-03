-- Park Bench: a cast-iron bench with half its slats gone and one leg
-- buckled, so it slumps. Runs along x, centered.
local WOOD = { 0.45, 0.3, 0.18 }

part("Frame", nil, DARK_STEEL, function(mesh)
	for _, x in { -1.3, 1.3 } do
		local drop = if x > 0 then 0.15 else 0
		box(mesh, x, 0, 0, 0.1, 0.7, 0.08)
		box(mesh, x, 0.25, 0, 0.1, 0.08, 0.6 - drop)
		box(mesh, x, -0.25, 0, 0.1, 0.08, 0.6 - drop)
		strut(mesh, x, 0.3, 0.6 - drop, x, 0.4, 1.3 - drop, 0.08)
	end
end, nil, 0.6)

part("Slats", nil, WOOD, function(mesh)
	for i, y in { -0.25, -0.05, 0.15 } do
		if i == 2 then
			continue
		end
		strut(mesh, -1.5, y, 0.62, 1.5, y, 0.47, 0.12)
	end
	strut(mesh, -1.5, 0.36, 1.1, 1.5, 0.36, 0.95, 0.12)
	strut(mesh, 0.4, -0.6, 0.04, 1.4, -0.3, 0.04, 0.1)
end, nil, 0.7)

finishParts()
