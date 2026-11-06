-- Ding Ding Ding Dongo: a snail carrying a bicycle bell for a shell, its
-- eyes up on stalks and the bell's thumb lever cocked to ring. 2.9 studs
-- tall. A stand-in until the look it riffs on is confirmed.
local FACE = { { 0.75, -0.2, 2.75, 0.2 }, { 1.2, -0.2, 2.85, 0.22 } }
local FEET = { 0.9, 0.3 }
local SNAIL = { 0.56, 0.62, 0.5 }
part("Body", nil, SNAIL, function(mesh)
	tube(mesh, { { -1.5, 0, 0.5 }, { -0.6, 0, 0.6 }, { 0.6, 0, 0.65 }, { 1.1, 0, 1.0 }, { 1.2, 0, 1.6 } }, 0.38, 10)
	sphere(mesh, 1.2, 0, 1.75, 0.42, 0.4, 0.4, 6, 12)
	-- Eye stalks.
	tube(mesh, { { 1.05, 0, 2.0 }, { 0.8, 0, 2.6 } }, 0.06, 6)
	tube(mesh, { { 1.3, 0, 2.0 }, { 1.22, 0, 2.7 } }, 0.06, 6)
end, true, RUBBER)
part("Bell", nil, BARE_METAL, function(mesh)
	sphere(mesh, -0.3, 0, 1.2, 1.0, 1.0, 0.85, 8, 18)
	cylinder(mesh, -0.3, 0, 2.02, 0.16, 0.12, "z", 8)
end, true, 0.3)
part("BellBase", nil, DARK_STEEL, function(mesh)
	cylinder(mesh, -0.3, 0, 0.95, 1.02, 0.14, "z", 18)
end, nil, 0.4)
part("Lever", nil, DARK_STEEL, function(mesh)
	tube(mesh, { { -1.1, -0.6, 1.0 }, { -1.5, -0.9, 1.15 }, { -1.6, -1.0, 1.4 } }, 0.07, 6)
	box(mesh, -1.62, -1.02, 1.36, 0.3, 0.2, 0.12)
end, nil, 0.4)
-- include: JunkrotFace
