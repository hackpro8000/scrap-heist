-- Hubcappa Wobbla: a chrome hubcap standing on edge, a little buckled, 2.9
-- studs tall.
local FACE = { { -0.36, -0.3, 1.95, 0.26 }, { 0.36, -0.3, 2.0, 0.3 } }
local FEET = { 0.9, 0.55 }
part("Disc", nil, BARE_METAL, function(mesh)
	cylinder(mesh, 0, 0, 1.75, 1.2, 0.22, "y", 20)
	ring(mesh, 0, -0.06, 1.75, 1.05, 1.24, 0.3, "y", 20)
end, nil, 0.55)
part("Spokes", nil, DARK_STEEL, function(mesh)
	for k = 0, 5 do
		local angle = k * TAU / 6
		local x, z = math.cos(angle), math.sin(angle)
		strut(mesh, x * 0.3, -0.13, 1.75 + z * 0.3, x * 1.0, -0.13, 1.75 + z * 1.0, 0.12)
	end
end, nil, 0.5)
part("Cap", nil, { 0.75, 0.18, 0.14 }, function(mesh)
	sphere(mesh, 0, -0.12, 1.2, 0.3, 0.14, 0.3, 5, 12)
end, true, 0.4)
-- include: JunkrotFace
