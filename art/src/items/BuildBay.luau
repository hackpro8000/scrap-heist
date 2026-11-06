-- Build Bay: where a capsule is hatched, 10 x 10 studs. A steel work deck
-- with a hazard-striped border, a round cradle in the middle for the
-- capsule, a lamp post at each corner and a tool rack along the back edge
-- (+y). Low enough to walk onto: the deck's top is at z 0.4.
local HAZARD_YELLOW = { 0.95, 0.76, 0.12 }
local LAMP_AMBER = { 1.0, 0.72, 0.25 }
part("Deck", nil, DARK_STEEL, function(mesh)
	box(mesh, 0, 0, 0, 10, 10, 0.34)
	box(mesh, 0, 0, 0.34, 7.6, 7.6, 0.06)
end, nil, 0.5)
part("Border", nil, HAZARD_YELLOW, function(mesh)
	for _, side in { -1, 1 } do
		box(mesh, side * 4.35, 0, 0.34, 0.7, 8.0, 0.07)
		box(mesh, 0, side * 4.35, 0.34, 8.0, 0.7, 0.07)
	end
end, nil, 0.35)
part("Chevrons", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	for _, side in { -1, 1 } do
		for k = -3, 3 do
			box(mesh, side * 4.35, k * 1.1, 0.4, 0.72, 0.3, 0.03)
			box(mesh, k * 1.1, side * 4.35, 0.4, 0.3, 0.72, 0.03)
		end
	end
end, nil, 0.3)
part("Cradle", nil, STEEL, function(mesh)
	ring(mesh, 0, 0, 0.5, 1.7, 2.3, 0.2, "z", 20)
	for k = 0, 3 do
		local angle = k * TAU / 4 + TAU / 8
		box(mesh, math.cos(angle) * 2.0, math.sin(angle) * 2.0, 0.4, 0.5, 0.5, 0.5)
	end
end, nil, 0.4)
part("Posts", nil, STEEL, function(mesh)
	for _, x in { -4.6, 4.6 } do
		for _, y in { -4.6, 4.6 } do
			box(mesh, x, y, 0.34, 0.5, 0.5, 0.2)
			cylinder(mesh, x, y, 1.9, 0.14, 3.0, "z", 8)
		end
	end
end, nil, 0.45)
part("Lamps", nil, LAMP_AMBER, function(mesh)
	for _, x in { -4.6, 4.6 } do
		for _, y in { -4.6, 4.6 } do
			sphere(mesh, x, y, 3.55, 0.3, 0.3, 0.3, 6, 10)
		end
	end
end, true, 0, nil, 1.4)
part("Rack", nil, RUST_ORANGE, function(mesh)
	box(mesh, 0, 4.75, 0.34, 3.2, 0.3, 1.5)
	for k = -1, 1 do
		strut(mesh, k * 0.9, 4.55, 0.7, k * 0.9, 4.55, 1.7, 0.12)
	end
end, nil, 0.7)
finishParts()
