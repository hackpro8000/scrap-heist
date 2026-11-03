-- Rock Gearbox: a cracked gearbox casing lying on its side like a lumpy
-- rock, with the bell housing, a stub shaft and loose gears beside it.
-- Centered on the origin.
part("Casing", nil, RUST_DARK, function(mesh)
	cylinder(mesh, 0, 0, 0.9, 0.9, 2.4, "x", 12)
	cylinder(mesh, 1.5, 0, 1.0, 1.0, 0.6, "x", 14)
	box(mesh, -0.3, 0, 0, 1.6, 1.2, 0.3)
end, nil, 0.85)

part("Ribs", nil, RUST_ORANGE, function(mesh)
	for i = 0, 3 do
		ring(mesh, -1.0 + i * 0.6, 0, 0.9, 0.85, 0.97, 0.1, "x", 12)
	end
end, nil, 0.8)

part("Gears", nil, STEEL, function(mesh)
	cylinder(mesh, -1.5, 0, 0.9, 0.12, 0.8, "x", 8)
	gear(mesh, 0.4, -1.5, 0.08, 0.5, 0.14, 12, "z")
	gear(mesh, -0.6, 1.4, 0.07, 0.35, 0.12, 9, "z")
	gear(mesh, -0.4, 1.55, 0.18, 0.2, 0.1, 7, "z")
end, nil, 0.45)

finishParts()
