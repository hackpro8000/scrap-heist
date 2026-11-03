-- Shipping Container: a 20-foot box, ribbed walls, one door hanging open.
-- Large cover piece. Centered on the origin.
local ORANGE = { 0.65, 0.3, 0.15 }

part("Shell", nil, ORANGE, function(mesh)
	box(mesh, 0, 0, 0, 12, 4.8, 0.2)
	box(mesh, 0, 0, 5.0, 12, 4.8, 0.2)
	for _, y in { -2.4, 2.4 } do
		box(mesh, 0, y, 0, 12, 0.1, 5.2)
		for i = 0, 22 do
			box(mesh, -5.75 + i * 0.5, y + (if y < 0 then -0.08 else 0.08), 0.2, 0.2, 0.08, 4.8)
		end
	end
	box(mesh, -5.95, 0, 0, 0.1, 4.8, 5.2)
	-- Closed right door, open left door swung out.
	box(mesh, 5.95, 1.2, 0, 0.1, 2.4, 5.2)
	box(mesh, 7.1, -2.45, 0, 2.3, 0.1, 5.2)
end, nil, 0.75)

part("Corners", nil, DARK_STEEL, function(mesh)
	for _, x in { -6, 6 } do
		for _, y in { -2.4, 2.4 } do
			box(mesh, x, y, 0, 0.5, 0.5, 0.5)
			box(mesh, x, y, 4.7, 0.5, 0.5, 0.5)
		end
	end
	for i = 0, 1 do
		box(mesh, 6.05, 0.6 + i * 1.2, 0.3, 0.08, 0.08, 4.6)
	end
end, nil, 0.6)

finishParts()
