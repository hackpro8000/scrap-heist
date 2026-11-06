-- Knifeblock Slicetta: a walnut knife block raked back at an angle, five
-- steel-capped handles sticking out of its top like a quiff. 3.5 studs
-- tall.
local FACE = { { -0.35, -0.75, 1.9, 0.24 }, { 0.35, -0.75, 1.95, 0.27 } }
local FEET = { 0.9, 0.5 }
part("Block", nil, { 0.36, 0.22, 0.13 }, function(mesh)
	for k = 0, 5 do
		box(mesh, 0, -0.15 + k * 0.08, 0.6 + k * 0.38, 1.6, 1.2, 0.4)
	end
end, nil, 0.03)
part("Handles", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	for k = -2, 2 do
		strut(mesh, k * 0.3, 0.35, 2.85, k * 0.3, 0.6 + math.abs(k) * 0.05, 3.7 - math.abs(k) * 0.15, 0.2)
	end
end, nil, 0)
part("Caps", nil, BARE_METAL, function(mesh)
	for k = -2, 2 do
		sphere(mesh, k * 0.3, 0.62 + math.abs(k) * 0.05, 3.76 - math.abs(k) * 0.15, 0.13, 0.13, 0.1, 4, 8)
	end
	box(mesh, 0, -0.78, 1.2, 0.5, 0.03, 0.2)
end, nil, 0.03)
-- include: JunkrotFace
