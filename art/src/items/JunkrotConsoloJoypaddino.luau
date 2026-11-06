-- Consolo Joypaddino: a game console standing on end, bright white with a
-- blue light bar down its front, its controller hung round its neck by
-- the cable. 3.7 studs tall.
local FACE = { { -0.3, -0.5, 3.05, 0.24 }, { 0.3, -0.5, 3.1, 0.27 } }
local FEET = { 0.9, 0.5 }
part("Shell", nil, { 0.95, 0.96, 0.98 }, function(mesh)
	box(mesh, -0.42, 0, 0.6, 0.5, 1.5, 3.0)
	box(mesh, 0.42, 0, 0.6, 0.5, 1.5, 3.0)
end, nil, 0)
part("Core", nil, { 0.08, 0.08, 0.1 }, function(mesh)
	box(mesh, 0, 0, 0.7, 0.36, 1.4, 2.8)
end, nil, 0)
part("LightBar", nil, { 0.3, 0.6, 1.0 }, function(mesh)
	box(mesh, 0, -0.72, 0.9, 0.12, 0.04, 1.9)
end, nil, 0)
part("Pad", nil, { 0.95, 0.96, 0.98 }, function(mesh)
	box(mesh, 0, -0.95, 1.7, 1.2, 0.3, 0.6)
	for _, x in { -0.6, 0.6 } do
		sphere(mesh, x, -0.95, 1.6, 0.34, 0.24, 0.5, 6, 10)
	end
end, true, 0)
part("Buttons", nil, { 0.95, 0.3, 0.35 }, function(mesh)
	for _, spot in { { 0.4, 2.0 }, { 0.55, 1.85 }, { 0.25, 1.85 }, { 0.4, 1.7 } } do
		cylinder(mesh, spot[1], -1.12, spot[2], 0.06, 0.05, "y", 8)
	end
	cylinder(mesh, -0.4, -1.12, 1.85, 0.14, 0.06, "y", 10)
end, nil, 0)
part("Cable", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	tube(mesh, { { -0.5, -0.9, 2.3 }, { -0.7, -0.4, 2.9 }, { 0, 0.5, 3.2 }, { 0.7, -0.4, 2.9 }, { 0.5, -0.9, 2.3 } }, 0.035, 5)
end, true, RUBBER)
-- include: JunkrotFace
