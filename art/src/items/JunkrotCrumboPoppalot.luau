-- Crumbo Poppalot: a two-slot toaster with a patched side and a slice of
-- burnt toast stuck halfway up, 3.1 studs tall.
local FACE = { { -0.45, -0.72, 1.75, 0.28 }, { 0.45, -0.72, 1.8, 0.32 } }
local FEET = { 1.1, 0.55 }
part("Body", nil, { 0.72, 0.72, 0.7 }, function(mesh)
	box(mesh, 0, 0, 0.65, 2.4, 1.4, 1.7)
	cylinder(mesh, 0, 0, 2.35, 0.7, 2.4, "x", 14)
end, nil, 0.5)
part("Slots", nil, { 0.08, 0.08, 0.09 }, function(mesh)
	for _, y in { -0.3, 0.3 } do
		box(mesh, 0, y, 2.98, 1.7, 0.26, 0.08)
	end
end, nil, 0.2)
part("Toast", nil, { 0.36, 0.22, 0.1 }, function(mesh)
	box(mesh, -0.1, -0.3, 2.7, 1.3, 0.2, 0.9)
end, nil, RUBBER)
part("Lever", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	box(mesh, 1.24, 0, 1.2, 0.1, 0.16, 1.0)
	box(mesh, 1.36, 0, 1.75, 0.26, 0.5, 0.2)
end, nil, 0.4)
part("Patch", nil, RUST_ORANGE, function(mesh)
	box(mesh, -0.75, 0.72, 0.9, 0.8, 0.05, 0.7)
	for _, x in { -1.05, -0.45 } do
		bolt(mesh, x, 0.76, 1.45, "y", 0.05)
		bolt(mesh, x, 0.76, 1.0, "y", 0.05)
	end
end, nil, 0.8)
-- include: JunkrotFace
