-- Laserlevel Lineo: a laser level on a little tripod, yellow and black,
-- two bubble vials on top and a red beam shining out of one end. 3.4
-- studs tall, 4.4 long with the beam.
local FACE = { { -0.4, -0.52, 2.3, 0.22 }, { 0.2, -0.52, 2.35, 0.24 } }
local FEET = { 0.9, 0.3 }
part("Body", nil, { 1.0, 0.82, 0.1 }, function(mesh)
	box(mesh, 0, 0, 1.9, 2.2, 0.9, 0.9)
end, nil, 0.03)
part("Ends", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	for _, x in { -1.2, 1.2 } do
		box(mesh, x, 0, 1.85, 0.3, 1.0, 1.0)
	end
end, nil, RUBBER)
part("Vials", nil, { 0.6, 1.0, 0.4 }, function(mesh)
	cylinder(mesh, -0.4, 0, 2.85, 0.12, 0.6, "x", 10)
	cylinder(mesh, 0.5, 0, 2.95, 0.12, 0.3, "z", 10)
end, nil, 0, nil, 0.8)
part("Beam", nil, { 1.0, 0.15, 0.1 }, function(mesh)
	cylinder(mesh, 2.3, 0, 2.35, 0.04, 1.9, "x", 6)
	sphere(mesh, 1.36, 0, 2.35, 0.1, 0.1, 0.1, 4, 8)
end, nil, 0, nil, 2.0)
part("Tripod", nil, BARE_METAL, function(mesh)
	cylinder(mesh, 0, 0, 1.6, 0.14, 0.6, "z", 8)
	for k = 0, 2 do
		local angle = k * TAU / 3 + 0.5
		strut(mesh, 0, 0, 1.4, math.cos(angle) * 0.9, math.sin(angle) * 0.9, 0.35, 0.07)
	end
end, nil, 0.03)
-- include: JunkrotFace
