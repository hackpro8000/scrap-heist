-- Fanetto Wobblino: a desk fan with a bent cage and three blades, nodding
-- on a short neck, 3.5 studs tall.
local FACE = { { -0.28, -0.5, 1.05, 0.22 }, { 0.28, -0.5, 1.1, 0.25 } }
local FEET = { 0.9, 0.5 }
local FAN_BLUE = { 0.36, 0.56, 0.66 }
part("Base", nil, FAN_BLUE, function(mesh)
	cylinder(mesh, 0, 0, 0.9, 0.8, 0.6, "z", 16)
	cylinder(mesh, 0, 0.1, 1.55, 0.2, 0.9, "z", 10)
end, nil, 0.5)
part("Motor", nil, FAN_BLUE, function(mesh)
	cylinder(mesh, 0, 0.3, 2.4, 0.42, 0.9, "y", 12)
end, nil, 0.5)
part("Cage", nil, BARE_METAL, function(mesh)
	ring(mesh, 0, -0.3, 2.4, 1.02, 1.1, 0.5, "y", 20)
	for k = 0, 7 do
		local angle = k * TAU / 8
		strut(mesh, 0, -0.56, 2.4, math.cos(angle) * 1.05, -0.56, 2.4 + math.sin(angle) * 1.05, 0.04)
	end
	cylinder(mesh, 0, -0.58, 2.4, 0.2, 0.06, "y", 10)
end, nil, 0.4)
part("Blades", nil, { 0.85, 0.83, 0.75 }, function(mesh)
	for k = 0, 2 do
		local angle = k * TAU / 3 + 0.4
		sphere(mesh, math.cos(angle) * 0.5, -0.3, 2.4 + math.sin(angle) * 0.5, 0.42, 0.05, 0.42, 5, 10)
	end
end, true, 0.3)
-- include: JunkrotFace
