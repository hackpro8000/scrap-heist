-- Capsule, Salvaged tier: a dented tin lunchbox with a domed lid, 2.3 studs
-- tall, 3 wide, patched with a riveted plate. Stands on the origin.
local TIN_GREEN = { 0.36, 0.5, 0.42 }
part("Box", nil, TIN_GREEN, function(mesh)
	box(mesh, 0, 0, 0, 3.0, 1.7, 1.25)
end, nil, 0.6)
part("Lid", nil, TIN_GREEN, function(mesh)
	-- A barrel lid: the top half of a cylinder lying along the box.
	cylinder(mesh, 0, 0, 1.25, 0.85, 3.0, "x", 16)
end, true, 0.55)
part("Trim", nil, STEEL, function(mesh)
	box(mesh, 0, 0, 1.18, 3.08, 1.78, 0.14)
	for _, x in { -0.9, 0.9 } do
		box(mesh, x, -0.9, 0.85, 0.3, 0.1, 0.5)
		bolt(mesh, x, -0.96, 1.2, "y", 0.07)
	end
end, nil, 0.5)
part("Patch", nil, RUST_ORANGE, function(mesh)
	box(mesh, 0.75, -0.87, 0.2, 0.9, 0.06, 0.6)
	for _, x in { 0.4, 1.1 } do
		for _, z in { 0.28, 0.72 } do
			bolt(mesh, x, -0.9, z, "y", 0.05)
		end
	end
end, nil, 0.8)
part("Handle", nil, DARK_STEEL, function(mesh)
	tube(mesh, { { -0.7, 0, 2.05 }, { -0.7, 0, 2.45 }, { 0.7, 0, 2.45 }, { 0.7, 0, 2.05 } }, 0.08, 6)
end, nil, 0.5)
finishParts()
