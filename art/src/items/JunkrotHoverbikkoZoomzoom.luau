-- Hoverbikko Zoomzoom: a hoverbike with no wheels, a sleek white body
-- over two glowing lift pads, a low screen and a seat with one stripe.
-- 3 studs tall, 4.6 long.
local FACE = { { 0.9, -0.52, 2.0, 0.22 }, { 1.5, -0.5, 1.95, 0.22 } }
local FEET = { 1.2, 0.5 }
part("Body", nil, { 0.95, 0.96, 0.98 }, function(mesh)
	sphere(mesh, 0.2, 0, 1.7, 2.1, 0.55, 0.5, 8, 18)
	sphere(mesh, -1.4, 0, 1.9, 0.9, 0.42, 0.34, 6, 12)
end, true, 0)
part("Pads", nil, { 0.4, 0.9, 1.0 }, function(mesh)
	for _, x in { -1.1, 1.3 } do
		cylinder(mesh, x, 0, 1.12, 0.6, 0.14, "z", 18)
	end
end, nil, 0, nil, 2.0)
part("PadRims", nil, { 0.25, 0.27, 0.3 }, function(mesh)
	for _, x in { -1.1, 1.3 } do
		ring(mesh, x, 0, 1.22, 0.6, 0.72, 0.2, "z", 18)
	end
end, nil, 0)
part("Seat", nil, { 0.12, 0.12, 0.14 }, function(mesh)
	sphere(mesh, -0.6, 0, 2.15, 0.8, 0.4, 0.16, 5, 12)
end, true, RUBBER)
part("Stripe", nil, { 1.0, 0.45, 0.1 }, function(mesh)
	box(mesh, 0.2, -0.56, 1.66, 2.6, 0.03, 0.12)
end, nil, 0)
part("Screen", nil, { 0.5, 0.85, 1.0 }, function(mesh)
	strut(mesh, 1.3, 0, 2.05, 1.0, 0, 2.6, 0.5)
end, nil, 0, nil, 0.8)
part("Bars", nil, BARE_METAL, function(mesh)
	cylinder(mesh, 0.9, 0, 2.5, 0.05, 1.3, "y", 8)
end, nil, 0.03)
-- include: JunkrotFace
