-- Capsule, Factory tier: a cardboard shipping box, 2.5 studs tall, sealed
-- with packing tape, with a red stencil block and a shipping label. Stands
-- on the origin.
local CARDBOARD = { 0.74, 0.58, 0.4 }
local PACKING_TAPE = { 0.86, 0.78, 0.55 }
local STENCIL_RED = { 0.75, 0.16, 0.12 }
local LABEL_WHITE = { 0.93, 0.92, 0.88 }
part("Box", nil, CARDBOARD, function(mesh)
	box(mesh, 0, 0, 0, 2.8, 2.6, 2.4)
	-- Flap edges standing a hair proud along the top.
	box(mesh, 0, -0.66, 2.4, 2.8, 1.28, 0.05)
	box(mesh, 0, 0.66, 2.4, 2.8, 1.28, 0.05)
end, nil, RUBBER)
part("Tape", nil, PACKING_TAPE, function(mesh)
	box(mesh, 0, 0, 2.44, 2.86, 0.5, 0.03)
	box(mesh, -1.41, 0, 1.5, 0.03, 0.5, 0.96)
	box(mesh, 1.41, 0, 1.5, 0.03, 0.5, 0.96)
end, nil, 0)
part("Stencil", nil, STENCIL_RED, function(mesh)
	-- "FRAGILE": a bar over two this-way-up arrows.
	box(mesh, -0.5, -1.31, 1.5, 1.3, 0.03, 0.34)
	for _, x in { 0.6, 1.0 } do
		box(mesh, x, -1.31, 0.5, 0.12, 0.03, 0.9)
		strut(mesh, x - 0.2, -1.32, 1.15, x, -1.32, 1.45, 0.08)
		strut(mesh, x + 0.2, -1.32, 1.15, x, -1.32, 1.45, 0.08)
	end
end, nil, 0)
part("Label", nil, LABEL_WHITE, function(mesh)
	box(mesh, -0.6, -1.31, 0.4, 1.0, 0.03, 0.7)
end, nil, 0)
finishParts()
