-- Holofono Shimmerra: a hologram phone, a glass-black slab standing on
-- end with a cone of light fanning up out of its top and a little glowing
-- figure turning in it. 4.2 studs tall.
local FACE = { { -0.26, -0.16, 2.2, 0.2 }, { 0.26, -0.16, 2.25, 0.22 } }
local FEET = { 0.6, 0.5 }
part("Slab", nil, { 0.05, 0.05, 0.07 }, function(mesh)
	box(mesh, 0, 0, 0.6, 1.3, 0.22, 2.3)
end, nil, 0, nil, nil, true)
part("Edge", nil, BARE_METAL, function(mesh)
	box(mesh, 0, 0, 0.56, 1.36, 0.28, 0.06)
	box(mesh, 0, 0, 2.88, 1.36, 0.28, 0.06)
	for _, x in { -0.67, 0.67 } do
		box(mesh, x, 0, 0.6, 0.05, 0.28, 2.3)
	end
end, nil, 0.03)
part("Cone", nil, { 0.5, 0.8, 1.0 }, function(mesh)
	for k = 0, 7 do
		local angle = k * TAU / 8
		strut(mesh, 0, 0, 2.95, math.cos(angle) * 0.9, math.sin(angle) * 0.9, 4.1, 0.03)
	end
	ring(mesh, 0, 0, 4.1, 0.86, 0.92, 0.03, "z", 16)
end, nil, 0, nil, 1.4)
part("Figure", nil, { 0.9, 0.6, 1.0 }, function(mesh)
	sphere(mesh, 0, 0, 3.9, 0.16, 0.16, 0.16, 5, 8)
	sphere(mesh, 0, 0, 3.5, 0.2, 0.14, 0.3, 5, 8)
end, true, 0, nil, 2.0)
-- include: JunkrotFace
