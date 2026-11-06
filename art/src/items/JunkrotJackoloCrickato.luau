-- Jackolo Crickato: a scissor car jack cranked halfway up, a saddle for a
-- hat and its crank handle sticking out one side, 3.2 studs tall.
local FACE = { { -0.3, -0.3, 2.62, 0.24 }, { 0.3, -0.3, 2.67, 0.27 } }
local FEET = { 1.2, 0.5 }
local JACK_RED = { 0.7, 0.16, 0.12 }
part("Arms", nil, JACK_RED, function(mesh)
	-- A diamond of four arms between the base and the saddle.
	for _, side in { -1, 1 } do
		strut(mesh, side * 0.3, 0, 0.75, side * 1.1, 0, 1.6, 0.22)
		strut(mesh, side * 1.1, 0, 1.6, side * 0.3, 0, 2.45, 0.22)
	end
	box(mesh, 0, 0, 0.55, 1.6, 0.6, 0.2)
end, nil, 0.6)
part("Saddle", nil, JACK_RED, function(mesh)
	box(mesh, 0, 0, 2.4, 1.1, 0.62, 0.5)
	box(mesh, 0, 0, 2.9, 0.7, 0.5, 0.14)
end, nil, 0.55)
part("Screw", nil, STEEL, function(mesh)
	cylinder(mesh, 0, 0, 1.6, 0.09, 2.9, "x", 8)
	for _, x in { -1.1, 1.1 } do
		cylinder(mesh, x, 0, 1.6, 0.2, 0.34, "y", 10)
	end
	-- The crank.
	tube(mesh, { { 1.45, 0, 1.6 }, { 1.75, 0, 1.6 }, { 1.75, 0, 2.0 }, { 2.1, 0, 2.0 } }, 0.07, 6)
end, nil, 0.5)
-- include: JunkrotFace
