-- Barrels: a cluster of oil drums, two standing, one on its side leaking a
-- small slick. Centered on the origin.
local BLUE = { 0.18, 0.3, 0.5 }
local HAZARD = { 0.9, 0.72, 0.1 }
local OIL = { 0.04, 0.04, 0.05 }

part("RustDrums", nil, RUST_DARK, function(mesh)
	cylinder(mesh, -0.6, 0.3, 0.7, 0.5, 1.4, "z", 16)
	cylinder(mesh, 0.9, -0.2, 0.5, 0.5, 1.4, "x", 16)
end, nil, 0.85)

part("BlueDrum", nil, BLUE, function(mesh)
	cylinder(mesh, 0.3, 0.8, 0.7, 0.5, 1.4, "z", 16)
end, nil, 0.5)

part("Hoops", nil, HAZARD, function(mesh)
	for _, z in { 0.45, 0.95 } do
		ring(mesh, -0.6, 0.3, z, 0.5, 0.53, 0.06, "z", 16)
		ring(mesh, 0.3, 0.8, z, 0.5, 0.53, 0.06, "z", 16)
	end
	for _, x in { 0.65, 1.15 } do
		ring(mesh, x, -0.2, 0.5, 0.5, 0.53, 0.06, "x", 16)
	end
end, nil, 0.5)

part("Slick", nil, OIL, function(mesh)
	cylinder(mesh, 1.9, -0.4, 0.01, 0.6, 0.02, "z", 14)
	cylinder(mesh, 2.4, -0.1, 0.01, 0.35, 0.02, "z", 12)
end, nil, 0)

finishParts()
