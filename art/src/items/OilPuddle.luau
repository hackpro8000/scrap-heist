-- Oil Puddle: a flat black slick with a rainbow sheen and a tipped oil can
-- leaking into it. Sits just above z 0, centered on the origin.
local OIL = { 0.06, 0.06, 0.08 }
local SHEEN = { 0.3, 0.2, 0.45 }

part("Slick", nil, OIL, function(mesh)
	cylinder(mesh, 0, 0, 0.01, 1.6, 0.02, "z", 20)
	cylinder(mesh, 1.2, 0.8, 0.01, 0.9, 0.02, "z", 16)
	cylinder(mesh, -1.1, -0.7, 0.01, 0.8, 0.02, "z", 16)
end, true, 0)

part("Sheen", nil, SHEEN, function(mesh)
	ring(mesh, 0.2, 0.1, 0.022, 0.6, 0.85, 0.01, "z", 18)
end, true, 0)

part("Can", nil, RUST_ORANGE, function(mesh)
	cylinder(mesh, 1.9, 1.1, 0.25, 0.25, 0.7, "x", 12)
	cylinder(mesh, 1.5, 1.1, 0.3, 0.06, 0.15, "x", 6)
end, nil, 0.7)

finishParts()
