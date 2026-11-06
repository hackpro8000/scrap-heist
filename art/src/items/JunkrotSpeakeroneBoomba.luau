-- Speakerone Boomba: a party speaker, a tall black cabinet with two
-- woofers ringed in colour, a tweeter between its eyes and a carry handle
-- on top. 3.9 studs tall.
local FACE = { { -0.45, -0.72, 3.2, 0.22 }, { 0.45, -0.72, 3.25, 0.25 } }
local FEET = { 1.0, 0.5 }
part("Cabinet", nil, { 0.09, 0.09, 0.1 }, function(mesh)
	box(mesh, 0, 0, 0.6, 2.0, 1.4, 3.1)
end, nil, 0)
part("Cones", nil, { 0.2, 0.2, 0.22 }, function(mesh)
	for _, z in { 1.3, 2.5 } do
		sphere(mesh, 0, -0.66, z, 0.5, 0.14, 0.5, 6, 14)
	end
	sphere(mesh, 0, -0.68, 3.25, 0.14, 0.08, 0.14, 4, 8)
end, true, 0)
part("RingPink", nil, { 1.0, 0.25, 0.7 }, function(mesh)
	ring(mesh, 0, -0.72, 2.5, 0.52, 0.64, 0.06, "y", 18)
end, nil, 0)
part("RingCyan", nil, { 0.2, 0.9, 1.0 }, function(mesh)
	ring(mesh, 0, -0.72, 1.3, 0.52, 0.64, 0.06, "y", 18)
end, nil, 0)
part("Handle", nil, BARE_METAL, function(mesh)
	tube(mesh, { { -0.6, 0, 3.7 }, { -0.6, 0, 4.0 }, { 0.6, 0, 4.0 }, { 0.6, 0, 3.7 } }, 0.08, 6)
end, nil, 0.03)
-- include: JunkrotFace
