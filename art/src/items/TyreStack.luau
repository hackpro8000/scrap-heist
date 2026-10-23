-- Tyre Stack: a leaning column of tyres beside a toppled pair, one with a
-- rusty rim still in it. Centered on the origin.
part("Tyres", nil, RUBBER_BLACK, function(mesh)
	for i = 0, 4 do
		ring(mesh, -0.4 + i * 0.06, (i % 2) * 0.05, 0.18 + i * 0.36, 0.32, 0.6, 0.36, "z", 16)
	end
	ring(mesh, 0.9, 0.4, 0.6, 0.32, 0.6, 0.36, "y", 16)
	ring(mesh, 0.85, -0.6, 0.18, 0.32, 0.6, 0.36, "z", 16)
end, nil, RUBBER)

part("Rim", nil, RUST_DARK, function(mesh)
	cylinder(mesh, 0.85, -0.6, 0.18, 0.34, 0.24, "z", 12)
	cylinder(mesh, -0.16, 0.0, 1.62, 0.34, 0.06, "z", 12)
end, nil, 0.8)

finishParts()
