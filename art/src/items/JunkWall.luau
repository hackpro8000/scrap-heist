-- Junk Wall: an 8-stud stretch of wall stacked from fridges, car doors and
-- drums, tall enough to block sight lines. Runs along x, centered.
local FRIDGE = { 0.82, 0.8, 0.74 }
local DOOR = { 0.38, 0.42, 0.5 }

part("Fridges", nil, FRIDGE, function(mesh)
	box(mesh, -3, 0, 0, 1.6, 1.4, 3.0)
	box(mesh, 2.8, 0.1, 0, 1.8, 1.4, 2.4)
end, nil, 0.6)

part("Doors", nil, DOOR, function(mesh)
	box(mesh, -0.8, 0, 0, 2.6, 1.2, 1.4)
	box(mesh, 0.6, -0.05, 2.4, 3.6, 1.0, 1.4)
	box(mesh, -2.8, 0.05, 3.0, 2.4, 1.0, 1.0)
end, nil, 0.7)

part("Drums", nil, RUST_DARK, function(mesh)
	cylinder(mesh, 1.0, 0, 1.0, 0.55, 2.0, "z", 14)
	cylinder(mesh, -0.7, 0, 1.95, 0.5, 2.2, "x", 14)
	cylinder(mesh, 3.0, 0, 2.95, 0.5, 1.1, "z", 14)
end, nil, 0.85)

part("Handles", nil, STEEL, function(mesh)
	box(mesh, -2.5, -0.74, 1.4, 0.08, 0.08, 1.0)
	box(mesh, 3.3, -0.74, 1.2, 0.08, 0.08, 0.8)
	box(mesh, -0.2, -0.65, 0.8, 0.4, 0.08, 0.1)
end, nil, 0.4)

finishParts()
