-- Drippi Droppi: a shrimp bent out of copper tube, curled over its tail
-- fan, with a tin cat's head: pointed ears, wire whiskers and an oil drip
-- off its chin. 3.2 studs tall. Rebuilt from scrap, in our own look.
local FACE = { { -0.3, -1.15, 2.55, 0.22 }, { 0.3, -1.15, 2.6, 0.25 } }
local FEET = { 0.7, 0.5 }
local TIN = { 0.7, 0.72, 0.72 }
part("Tail", nil, COPPER, function(mesh)
	-- The body curls from behind the head down and under to the tail fan.
	local points = {}
	for step = 0, 10 do
		local angle = math.rad(70 - step * 24)
		table.insert(points, { 0, 0.35 + math.cos(angle) * 0.9, 1.6 + math.sin(angle) * 0.9 })
	end
	tube(mesh, points, 0.34, 10)
end, true, 0.5)
part("Bands", nil, { 0.5, 0.3, 0.16 }, function(mesh)
	for step = 1, 8 do
		local angle = math.rad(70 - step * 24)
		sphere(mesh, 0, 0.35 + math.cos(angle) * 0.9, 1.6 + math.sin(angle) * 0.9, 0.4, 0.14, 0.4, 5, 10)
	end
end, true, 0.6)
part("Fan", nil, COPPER, function(mesh)
	for k = -1, 1 do
		box(mesh, k * 0.34, -0.35, 0.72, 0.3, 0.6, 0.06)
	end
end, nil, 0.5)
part("Head", nil, TIN, function(mesh)
	sphere(mesh, 0, -0.55, 2.5, 0.72, 0.68, 0.62, 8, 14)
	for _, side in { -1, 1 } do
		-- Ears: three-sided cones of bent tin.
		cylinder(mesh, side * 0.42, -0.45, 3.1, 0.24, 0.4, "z", 3)
	end
end, nil, 0.45)
part("Whiskers", nil, DARK_STEEL, function(mesh)
	for _, side in { -1, 1 } do
		for k = -1, 1 do
			strut(mesh, side * 0.3, -1.15, 2.3, side * 1.05, -1.2, 2.3 + k * 0.16, 0.025)
		end
	end
	sphere(mesh, 0, -1.22, 2.36, 0.08, 0.06, 0.06, 4, 8)
end, nil, 0.3)
part("Drip", nil, { 0.1, 0.08, 0.05 }, function(mesh)
	sphere(mesh, 0, -1.0, 1.82, 0.08, 0.08, 0.14, 5, 8)
end, true, 0)
-- include: JunkrotFace
