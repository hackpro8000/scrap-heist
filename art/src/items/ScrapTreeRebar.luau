-- Scrap Tree (Rebar): rebar rods twisted together into a gnarled trunk that
-- forks into bare branches, rooted in a broken concrete footing. A dead
-- winter tree for the bleaker corners of the yard.
local CONCRETE = { 0.6, 0.59, 0.56 }

part("Rebar", nil, RUST_DARK, function(mesh)
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		local r = 0.22
		local points = {}
		for step = 0, 6 do
			local t = a + step * 0.5
			points[step + 1] = { math.cos(t) * r, math.sin(t) * r, 0.3 + step * 1 }
		end
		-- Each rod leaves the trunk as its own branch.
		local out = a + 3
		points[8] = { math.cos(out) * 1.6, math.sin(out) * 1.6, 7.6 + (i % 2) * 0.8 }
		points[9] = { math.cos(out + 0.4) * 2.6, math.sin(out + 0.4) * 2.6, 8.8 + (i % 3) * 0.5 }
		tube(mesh, points, 0.08, 6)
		strut(mesh, points[8][1], points[8][2], points[8][3], points[8][1] * 0.6 + 0.4, points[8][2] * 0.6, points[8][3] + 1.4, 0.06)
	end
end, true, 0.8)

part("Footing", nil, CONCRETE, function(mesh)
	box(mesh, 0, 0, 0, 1.6, 1.4, 0.45)
	box(mesh, 0.9, -0.5, 0, 0.6, 0.5, 0.25)
	box(mesh, -0.8, 0.6, 0, 0.5, 0.6, 0.2)
end, nil, 0.25)

part("Ties", nil, DARK_STEEL, function(mesh)
	for _, z in { 1.2, 2.8, 4.4 } do
		ring(mesh, 0, 0, z, 0.28, 0.34, 0.08, "z", 8)
	end
end, nil, 0.6)

finishParts()
