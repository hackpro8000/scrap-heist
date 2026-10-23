-- Copper Coil: uncommon loot, about 0.9 studs long, lying on its side.
-- Copper wire wound round an iron core between green end flanges.
part("Core", nil, DARK_STEEL, function(mesh)
	cylinder(mesh, 0, 0, 0.3, 0.12, 0.9, "x", 10)
end, nil, 0.5)
part("Winding", nil, COPPER, function(mesh)
	local points = {}
	for i = 0, 96 do
		local t = i / 8 * TAU
		table.insert(points, { -0.28 + i / 96 * 0.56, math.cos(t) * 0.18, 0.3 + math.sin(t) * 0.18 })
	end
	tube(mesh, points, 0.035, 6)
end, 20, 0.15)
part("Flanges", nil, UNCOMMON, function(mesh)
	for _, s in { -1, 1 } do
		cylinder(mesh, s * 0.34, 0, 0.3, 0.29, 0.06, "x", 16)
	end
end, nil, 0.3)
finishParts()
