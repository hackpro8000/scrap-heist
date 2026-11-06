-- La Vacuuma Saturnita: a round vacuum canister for a planet, its hose
-- looped right round it as the ring, a tin cow's head on top with stub
-- horns, on two legs. 4 studs tall. Rebuilt from scrap, in our own look.
local FACE = { { -0.26, -0.78, 3.3, 0.2 }, { 0.26, -0.78, 3.35, 0.22 } }
local FEET = { 0.9, 0.6 }
part("Planet", nil, { 0.9, 0.62, 0.3 }, function(mesh)
	sphere(mesh, 0, 0, 1.75, 1.15, 1.15, 1.1, 10, 18)
end, true, 0)
part("Bands", nil, { 0.98, 0.9, 0.7 }, function(mesh)
	ring(mesh, 0, 0, 2.1, 1.02, 1.1, 0.16, "z", 18)
	ring(mesh, 0, 0, 1.3, 1.05, 1.13, 0.2, "z", 18)
end, nil, 0)
part("HoseRing", nil, { 0.14, 0.14, 0.16 }, function(mesh)
	local points = {}
	for step = 0, 20 do
		local angle = step / 20 * TAU
		table.insert(points, { math.cos(angle) * 1.75, math.sin(angle) * 1.75, 1.75 + math.cos(angle) * 0.4 })
	end
	tube(mesh, points, 0.13, 6)
end, true, RUBBER)
part("CowHead", nil, { 0.9, 0.9, 0.88 }, function(mesh)
	sphere(mesh, 0, -0.2, 3.2, 0.6, 0.62, 0.5, 8, 14)
	sphere(mesh, 0, -0.75, 3.0, 0.36, 0.24, 0.26, 5, 12)
	for _, side in { -1, 1 } do
		sphere(mesh, side * 0.7, -0.1, 3.3, 0.24, 0.05, 0.14, 4, 8)
	end
end, true, 0.05)
part("Spots", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	sphere(mesh, 0.34, -0.36, 3.5, 0.2, 0.2, 0.14, 4, 8)
	sphere(mesh, -0.4, 0.1, 3.5, 0.22, 0.22, 0.14, 4, 8)
end, true, 0)
part("Horns", nil, BARE_METAL, function(mesh)
	for _, side in { -1, 1 } do
		cylinder(mesh, side * 0.4, -0.1, 3.72, 0.1, 0.3, "z", 3)
	end
	sphere(mesh, 0, -0.95, 2.98, 0.05, 0.04, 0.05, 4, 6)
end, nil, 0.03)
part("Glow", nil, { 0.5, 0.9, 1.0 }, function(mesh)
	cylinder(mesh, 0, -1.12, 1.75, 0.2, 0.06, "y", 12)
end, nil, 0, nil, 1.8)
-- include: JunkrotFace
