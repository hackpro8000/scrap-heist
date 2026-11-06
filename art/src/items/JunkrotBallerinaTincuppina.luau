-- Ballerina Tincuppina: a ballerina bent from fence wire with a dented
-- tin mug for a head and a tutu of crumpled foil, up on one toe. 3.9
-- studs tall. Rebuilt from scrap, in our own look.
local FACE = { { -0.26, -0.62, 3.3, 0.2 }, { 0.26, -0.62, 3.35, 0.23 } }
local FEET = { 0.5, 0.9 }
part("Mug", nil, { 0.85, 0.87, 0.9 }, function(mesh)
	cylinder(mesh, 0, 0, 3.25, 0.6, 0.95, "z", 14)
	ring(mesh, 0.72, 0, 3.25, 0.16, 0.28, 0.12, "y", 10)
	ring(mesh, 0, 0, 3.72, 0.52, 0.64, 0.08, "z", 14)
end, nil, 0.25)
part("Wire", nil, DARK_STEEL, function(mesh)
	tube(mesh, { { 0, 0, 2.8 }, { 0, 0, 1.6 } }, 0.09, 6)
	-- Arms up in a ring over the head.
	tube(mesh, { { 0, 0, 2.55 }, { -0.9, 0, 2.9 }, { -0.8, 0, 3.9 }, { -0.2, 0, 4.3 } }, 0.05, 6)
	tube(mesh, { { 0, 0, 2.55 }, { 0.9, 0, 2.9 }, { 0.8, 0, 3.9 }, { 0.2, 0, 4.3 } }, 0.05, 6)
end, true, 0.3)
part("Tutu", nil, { 0.92, 0.93, 0.95 }, function(mesh)
	for k = 0, 9 do
		local angle = k * TAU / 10
		sphere(mesh, math.cos(angle) * 0.75, math.sin(angle) * 0.75, 1.75 + (k % 2) * 0.1, 0.45, 0.45, 0.1, 4, 8)
	end
end, true, 0.05)
-- include: JunkrotFace
