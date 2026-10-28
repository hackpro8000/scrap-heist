-- Gear Panel: a steampunk wall panel about 8 studs square and 0.6 deep, built from the approved
-- sketch. A copper pipe frame round the edge, nine brass and steel gears stacked at different
-- depths, two riveted steel boilers down the right side and a brass dial bottom left. Centred on
-- the origin, facing -y, with z up.
local BRASS = { 0.78, 0.6, 0.3 }
local PIPE_RADIUS = 0.13
local PIPE_AT = 3.25
local PANEL_HALF = PIPE_AT + PIPE_RADIUS

-- The dark back plate the gears and frame are mounted on.
part("BackPlate", nil, DARK_STEEL, function(mesh)
	box(mesh, 0, 0.42, 0, PANEL_HALF * 2, 0.06, PANEL_HALF * 2)
end, nil, 0.8)

-- Four straight copper pipes and a joint at each corner, along the edges of the panel.
part("Frame", nil, COPPER, function(mesh)
	local corners = { { -PIPE_AT, 0.3, PIPE_AT }, { PIPE_AT, 0.3, PIPE_AT }, { PIPE_AT, 0.3, -PIPE_AT }, { -PIPE_AT, 0.3, -PIPE_AT } }
	for i, a in corners do
		local b = corners[i % 4 + 1]
		tube(mesh, { a, b }, PIPE_RADIUS, 10)
		sphere(mesh, a[1], a[2], a[3], PIPE_RADIUS * 1.5, PIPE_RADIUS * 1.5, PIPE_RADIUS * 1.5, 6, 10)
	end
end, nil, 0.7)

-- Large brass gears, the top two and the bottom right.
part("LargeGears", nil, BRASS, function(mesh)
	gear(mesh, -1.42, 0.1, 1.97, 1.48, 0.3, 14, "y")
	gear(mesh, 0.66, 0.0, 2.44, 1.64, 0.3, 16, "y")
	gear(mesh, 1.6, -0.1, -1.07, 1.41, 0.3, 14, "y")
end, nil, 0.5)

-- Medium brass gears through the middle and bottom left.
part("MediumGears", nil, BRASS, function(mesh)
	gear(mesh, -1.19, 0.05, -2.1, 1.17, 0.26, 12, "y")
	gear(mesh, 0.61, -0.05, 0.09, 0.94, 0.26, 12, "y")
	gear(mesh, 0.45, 0.1, -1.3, 0.86, 0.24, 10, "y")
	gear(mesh, -0.56, -0.1, 0.33, 0.7, 0.22, 9, "y")
	gear(mesh, 1.45, 0.0, 0.7, 0.63, 0.2, 9, "y")
end, nil, 0.5)

-- The steel-rimmed gear at the bottom, with a rim standing proud of its teeth.
part("SteelGear", nil, STEEL, function(mesh)
	gear(mesh, 0.38, -0.15, -3.0, 0.7, 0.24, 9, "y")
	ring(mesh, 0.38, -0.15, -3.0, 0.62, 0.8, 0.14, "y", 14)
end, nil, 0.4)

-- Two riveted steel boilers on the right: a tall one above and a longer one below.
part("Boilers", nil, STEEL, function(mesh)
	cylinder(mesh, 2.6, -0.2, 2.2, 0.6, 1.8, "z", 14)
	sphere(mesh, 2.6, -0.2, 3.1, 0.6, 0.6, 0.5, 6, 14)
	cylinder(mesh, 2.6, -0.2, -0.4, 0.75, 2.8, "z", 14)
	ring(mesh, 2.6, -0.2, -0.4, 0.75, 0.85, 0.12, "z", 14)
	ring(mesh, 2.6, -0.2, -1.0, 0.75, 0.85, 0.12, "z", 14)
end, nil, 0.6)

-- Brass dial at the bottom left: a rim, a face and a centre pin.
part("Dial", nil, BRASS, function(mesh)
	ring(mesh, -2.35, -0.2, -1.6, 0.8, 0.95, 0.16, "y", 16)
	cylinder(mesh, -2.35, -0.1, -1.6, 0.8, 0.1, "y", 16)
	cylinder(mesh, -2.35, -0.3, -1.6, 0.12, 0.1, "y", 8)
end, nil, 0.45)

finishParts()
