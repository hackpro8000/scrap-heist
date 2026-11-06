-- Capsule, Refurbished tier: a steel toolbox with a fresh coat of red paint
-- over its old dents, 2.2 studs tall, 3.2 wide, with bright new latches and
-- a tube handle. Stands on the origin.
local FRESH_RED = { 0.8, 0.14, 0.11 }
part("Box", nil, FRESH_RED, function(mesh)
	box(mesh, 0, 0, 0, 3.2, 1.6, 1.2)
end, nil, 0.15)
part("Lid", nil, FRESH_RED, function(mesh)
	box(mesh, 0, 0, 1.24, 3.2, 1.6, 0.3)
	box(mesh, 0, 0, 1.54, 2.7, 1.1, 0.24)
end, nil, 0.12)
part("Seam", nil, DARK_STEEL, function(mesh)
	box(mesh, 0, 0, 1.19, 3.24, 1.64, 0.06)
end, nil, 0.3)
part("Latches", nil, BARE_METAL, function(mesh)
	for _, x in { -1.0, 1.0 } do
		box(mesh, x, -0.84, 0.95, 0.36, 0.08, 0.5)
		bolt(mesh, x, -0.9, 1.33, "y", 0.07)
	end
	for _, x in { -1.62, 1.62 } do
		box(mesh, x, 0, 0.5, 0.06, 0.5, 0.3)
	end
end, nil, 0.1)
part("Handle", nil, BARE_METAL, function(mesh)
	tube(mesh, { { -0.9, 0, 1.78 }, { -0.9, 0, 2.2 }, { 0.9, 0, 2.2 }, { 0.9, 0, 1.78 } }, 0.09, 8)
end, nil, 0.1)
finishParts()
