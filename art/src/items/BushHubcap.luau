-- Bush (Hubcap): a waist-high mound of hubcaps leaning on each other at odd
-- angles, chrome ones on top and rusted ones sunk into the bottom of the pile.
part("Chrome", nil, STEEL, function(mesh)
	local spots = {
		{ 0, 0, 1.6, "z" }, { 0.8, 0.3, 1.0, "z" }, { -0.7, 0.4, 1.3, "y" },
		{ 0.2, -0.8, 1.2, "y" }, { -0.3, 0.7, 1.8, "x" }, { 0.6, -0.4, 1.9, "z" },
	}
	for _, p in spots do
		ring(mesh, p[1], p[2], p[3], 0.15, 0.7, 0.1, p[4], 12)
		cylinder(mesh, p[1], p[2], p[3], 0.25, 0.14, p[4], 8)
	end
end, nil, 0.2)

part("Rusted", nil, RUST_ORANGE, function(mesh)
	local spots = {
		{ 1.1, -0.6, 0.1, "z" }, { -1.1, -0.3, 0.15, "z" }, { -0.2, 1.1, 0.1, "z" },
		{ 0.9, 0.9, 0.2, "z" }, { -0.9, -1, 0.1, "z" }, { 0, 0, 0.4, "z" },
		{ 0.3, -1.1, 0.45, "y" }, { -1.2, 0.6, 0.5, "x" },
	}
	for _, p in spots do
		ring(mesh, p[1], p[2], p[3], 0.15, 0.7, 0.1, p[4], 12)
	end
end, nil, 0.8)

finishParts()
