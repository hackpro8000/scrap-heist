-- Airfryo Croccante: an egg-shaped air fryer in glossy black, a basket
-- drawer with a chunky handle for a mouth and a glowing-green dial on its
-- brow. 3.5 studs tall.
local FACE = { { -0.38, -0.95, 2.6, 0.25 }, { 0.38, -0.95, 2.65, 0.28 } }
local FEET = { 1.0, 0.5 }
part("Body", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	sphere(mesh, 0, 0, 2.1, 1.15, 1.15, 1.55, 10, 18)
end, true, 0)
part("Drawer", nil, { 0.2, 0.2, 0.22 }, function(mesh)
	box(mesh, 0, -1.0, 1.0, 1.5, 0.2, 1.1)
end, nil, 0)
part("Handle", nil, BARE_METAL, function(mesh)
	box(mesh, 0, -1.3, 1.4, 0.5, 0.5, 0.3)
end, nil, 0.03)
part("Dial", nil, { 0.4, 0.95, 0.55 }, function(mesh)
	cylinder(mesh, 0, -0.82, 3.15, 0.26, 0.1, "y", 14)
end, nil, 0)
part("Sticker", nil, { 0.95, 0.3, 0.25 }, function(mesh)
	box(mesh, 0.75, -0.9, 1.9, 0.4, 0.04, 0.3)
end, nil, 0)
-- include: JunkrotFace
