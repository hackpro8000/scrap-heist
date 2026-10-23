-- Bush (Wire): a round tangle of stripped copper and steel cable, balled up
-- like a tumbleweed caught against something, with a few loose ends trailing.
part("Copper", nil, COPPER, function(mesh)
	for i = 0, 9 do
		local a, b = i * 2.4, i * 1.3
		local points = {}
		for step = 0, 5 do
			local t = a + step * 1.1
			local u = b + step * 0.7
			local r = 1.1 + math.sin(step + i) * 0.2
			points[step + 1] = { math.cos(t) * math.cos(u) * r, math.sin(t) * math.cos(u) * r, 1.1 + math.sin(u) * r * 0.85 }
		end
		tube(mesh, points, 0.035, 4)
	end
end, nil, 0.3)

part("Steel", nil, DARK_STEEL, function(mesh)
	for i = 0, 7 do
		local a, b = i * 1.9 + 0.5, i * 2.1
		local points = {}
		for step = 0, 5 do
			local t = a - step * 1.2
			local u = b + step * 0.9
			points[step + 1] = { math.cos(t) * math.cos(u), math.sin(t) * math.cos(u), 1.1 + math.sin(u) * 0.85 }
		end
		tube(mesh, points, 0.045, 4)
	end
	-- Loose ends dragging on the ground.
	tube(mesh, { { 0.8, 0.4, 0.4 }, { 1.6, 0.9, 0.05 }, { 2.3, 0.7, 0.04 } }, 0.04, 4)
	tube(mesh, { { -0.7, -0.6, 0.3 }, { -1.5, -1.2, 0.04 } }, 0.04, 4)
end, nil, 0.5)

finishParts()
