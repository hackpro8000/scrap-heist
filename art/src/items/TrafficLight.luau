-- Traffic Light: a traffic light pole knocked flat over a concrete block,
-- the light housing cracked and one lamp still glowing. Centered on the
-- origin, lying along x.
local CONCRETE = { 0.6, 0.59, 0.56 }

part("Pole", nil, DARK_STEEL, function(mesh)
	strut(mesh, -2.4, 0, 0.12, 1.4, 0, 0.75, 0.16)
	box(mesh, -2.6, 0, 0, 0.5, 0.6, 0.6)
end, nil, 0.6)

part("Housing", nil, { 0.9, 0.72, 0.1 }, function(mesh)
	box(mesh, 2.1, 0, 0.55, 1.6, 0.6, 0.5)
end, nil, 0.6)

part("Lamps", nil, DARK_STEEL, function(mesh)
	for i = 0, 1 do
		cylinder(mesh, 1.6 + i * 0.5, -0.32, 0.8, 0.17, 0.06, "y", 10)
	end
end, nil, 0.3)

part("Lit", nil, { 0.2, 0.9, 0.3 }, function(mesh)
	cylinder(mesh, 2.6, -0.32, 0.8, 0.17, 0.06, "y", 10)
end, true, 0)

part("Block", nil, CONCRETE, function(mesh)
	box(mesh, 0.6, 0, 0, 0.8, 1.2, 0.6)
end, nil, 0.4)

finishParts()
