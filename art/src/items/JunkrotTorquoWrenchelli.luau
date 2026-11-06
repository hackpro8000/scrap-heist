-- Torquo Wrenchelli: a chrome torque wrench standing on its handle, the
-- ratchet head up top and a dial gauge on its chest. 4.2 studs tall.
local FACE = { { -0.2, -0.3, 3.5, 0.2 }, { 0.2, -0.3, 3.55, 0.22 } }
local FEET = { 0.5, 0.5 }
part("Shaft", nil, BARE_METAL, function(mesh)
	cylinder(mesh, 0, 0, 2.1, 0.16, 2.2, "z", 12)
	sphere(mesh, 0, 0, 3.6, 0.55, 0.28, 0.5, 6, 14)
	cylinder(mesh, 0, -0.34, 3.6, 0.2, 0.3, "y", 6)
end, true, 0.03)
part("Grip", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	cylinder(mesh, 0, 0, 1.05, 0.26, 1.1, "z", 12)
	for k = 0, 4 do
		ring(mesh, 0, 0, 0.65 + k * 0.2, 0.26, 0.3, 0.06, "z", 12)
	end
end, nil, RUBBER)
part("Gauge", nil, { 0.96, 0.96, 0.94 }, function(mesh)
	cylinder(mesh, 0, -0.26, 2.4, 0.42, 0.14, "y", 16)
end, nil, 0)
part("Needle", nil, { 0.95, 0.15, 0.12 }, function(mesh)
	strut(mesh, 0, -0.35, 2.4, 0.22, -0.35, 2.65, 0.04)
	ring(mesh, 0, -0.3, 2.4, 0.42, 0.48, 0.16, "y", 16)
end, nil, 0)
-- include: JunkrotFace
