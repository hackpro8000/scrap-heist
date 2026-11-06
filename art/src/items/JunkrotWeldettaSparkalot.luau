-- Weldetta Sparkalot: an inverter welder, a blue box with dials and
-- cooling slots, wearing its welding mask pushed up, torch in hand and a
-- blue-white arc at the tip. 3.6 studs tall.
local FACE = { { -0.4, -0.82, 2.2, 0.24 }, { 0.4, -0.82, 2.25, 0.27 } }
local FEET = { 1.0, 0.5 }
part("Case", nil, { 0.12, 0.3, 0.62 }, function(mesh)
	box(mesh, 0, 0, 0.6, 2.0, 1.6, 2.2)
end, nil, 0.03)
part("Slots", nil, { 0.08, 0.08, 0.1 }, function(mesh)
	for k = 0, 4 do
		box(mesh, 0, -0.81, 0.8 + k * 0.16, 1.4, 0.03, 0.08)
	end
end, nil, 0)
part("Dials", nil, BARE_METAL, function(mesh)
	for _, x in { -0.6, 0.6 } do
		cylinder(mesh, x, -0.84, 1.75, 0.16, 0.1, "y", 12)
	end
end, nil, 0.03)
part("Mask", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	sphere(mesh, 0, -0.2, 3.1, 0.85, 0.7, 0.5, 6, 14)
	box(mesh, 0, -0.85, 2.95, 0.9, 0.06, 0.3)
end, true, 0)
part("Torch", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	tube(mesh, { { 1.0, 0, 1.2 }, { 1.6, -0.3, 1.5 }, { 1.7, -0.6, 2.3 } }, 0.07, 6)
	cylinder(mesh, 1.72, -0.66, 2.55, 0.1, 0.5, "z", 8)
end, true, RUBBER)
part("Arc", nil, { 0.7, 0.9, 1.0 }, function(mesh)
	sphere(mesh, 1.72, -0.66, 2.95, 0.16, 0.16, 0.16, 4, 8)
	for k = 0, 4 do
		local angle = k * TAU / 5
		strut(mesh, 1.72, -0.66, 2.95, 1.72 + math.cos(angle) * 0.4, -0.66 + math.sin(angle) * 0.2, 3.05 + math.sin(angle * 2) * 0.3, 0.03)
	end
end, nil, 0, nil, 2.2)
-- include: JunkrotFace
