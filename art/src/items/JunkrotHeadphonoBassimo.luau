-- Headphono Bassimo: a pair of studio headphones standing on their ear
-- cups, brushed band arched overhead, a ring of light round each cup.
-- 3.6 studs tall.
local FACE = { { -0.86, -0.42, 1.55, 0.2 }, { 0.86, -0.42, 1.6, 0.22 } }
local FEET = { 1.7, 0.5 }
part("Cups", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	for _, x in { -0.9, 0.9 } do
		cylinder(mesh, x, 0, 1.5, 0.8, 0.7, "x", 18)
	end
end, nil, 0)
part("Pads", nil, { 0.22, 0.2, 0.2 }, function(mesh)
	for _, x in { -0.5, 0.5 } do
		ring(mesh, x, 0, 1.5, 0.4, 0.78, 0.2, "x", 18)
	end
end, nil, RUBBER)
part("Band", nil, BARE_METAL, function(mesh)
	local points = {}
	for step = 0, 10 do
		local angle = math.rad(step * 18)
		table.insert(points, { math.cos(angle) * 1.2, 0, 2.0 + math.sin(angle) * 1.6 })
	end
	tube(mesh, points, 0.1, 8)
end, true, 0.03)
part("BandPad", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	sphere(mesh, 0, 0, 3.6, 0.7, 0.24, 0.14, 5, 10)
end, true, RUBBER)
part("Glow", nil, { 0.5, 0.4, 1.0 }, function(mesh)
	for _, x in { -1.27, 1.27 } do
		ring(mesh, x, 0, 1.5, 0.5, 0.62, 0.04, "x", 18)
	end
end, nil, 0, nil, 1.5)
-- include: JunkrotFace
