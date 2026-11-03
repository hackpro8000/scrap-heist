-- Rock Car Cube: a car crushed into a bale and dropped on its side, standing
-- in for a boulder. Layered panel colors show the squashed body, with a
-- wheel, bumper and window frame poking out. Centered on the origin.
local CAR_PAINT = { 0.55, 0.14, 0.12 }
local CAR_PAINT_FADED = { 0.38, 0.42, 0.5 }

part("Panels", nil, CAR_PAINT, function(mesh)
	box(mesh, 0, 0, 0, 3.2, 2.4, 0.5)
	box(mesh, 0.05, -0.04, 1.1, 3.1, 2.36, 0.45)
	box(mesh, -0.05, 0.03, 2.0, 3.15, 2.3, 0.35)
end, nil, 0.55)

part("FadedPanels", nil, CAR_PAINT_FADED, function(mesh)
	box(mesh, 0.02, 0.02, 0.5, 3.12, 2.34, 0.6)
	box(mesh, 0, 0, 1.55, 3.05, 2.32, 0.45)
end, nil, 0.7)

part("Rust", nil, RUST_ORANGE, function(mesh)
	box(mesh, 0, 0, 2.35, 3.0, 2.2, 0.08)
	box(mesh, -1.0, -1.2, 0.3, 0.9, 0.06, 1.4)
	box(mesh, 1.6, 0.3, 0.9, 0.06, 1.0, 0.8)
end, nil, 0.9)

part("Wheel", nil, RUBBER_BLACK, function(mesh)
	ring(mesh, 1.0, -1.24, 0.95, 0.2, 0.42, 0.22, "y", 14)
end, nil, RUBBER)

part("Trim", nil, STEEL, function(mesh)
	cylinder(mesh, 1.0, -1.28, 0.95, 0.2, 0.14, "y", 10)
	-- Bumper bent out of one end.
	tube(mesh, { { -1.6, -1.0, 0.7 }, { -1.75, 0, 0.8 }, { -1.9, 0.9, 1.2 } }, 0.09, 8)
	-- Window frame sticking out of the top.
	strut(mesh, 0.4, 0.6, 2.4, 0.9, 0.9, 2.8, 0.06)
	strut(mesh, 0.9, 0.9, 2.8, 1.3, 0.2, 2.6, 0.06)
end, nil, 0.4)

finishParts()
