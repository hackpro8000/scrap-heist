-- Reactor Core: legendary loot, about 1.2 studs tall. A glowing green-
-- white core held in a gold cage between two heavy end caps.
part("Core", nil, { 0.75, 1.0, 0.55 }, function(mesh)
	sphere(mesh, 0, 0, 0.6, 0.28, 0.28, 0.34, 10, 16)
end, nil, 0)
part("Caps", nil, DARK_STEEL, function(mesh)
	cylinder(mesh, 0, 0, 0.1, 0.38, 0.2, "z", 16)
	cylinder(mesh, 0, 0, 1.1, 0.38, 0.2, "z", 16)
end, nil, 0.45)
part("Cage", nil, LEGENDARY, function(mesh)
	for i = 0, 5 do
		local t = i / 6 * TAU
		cylinder(mesh, math.cos(t) * 0.33, math.sin(t) * 0.33, 0.6, 0.04, 0.8, "z", 6)
	end
	ring(mesh, 0, 0, 0.6, 0.3, 0.37, 0.06, "z", 16)
end, nil, 0.1)
finishParts()
