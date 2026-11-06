-- Capsule, Secret tier: a black monolith case with no markings, 3.4 studs
-- tall, split by one faint glowing seam. Stands on the origin.
local VOID_BLACK = { 0.035, 0.035, 0.05 }
local SEAM_GLOW = { 0.62, 0.38, 1.0 }
part("Slab", nil, VOID_BLACK, function(mesh)
	box(mesh, 0, 0, 0, 1.7, 0.7, 1.66)
	box(mesh, 0, 0, 1.74, 1.7, 0.7, 1.66)
end, nil, 0, nil, nil, true)
part("Seam", nil, SEAM_GLOW, function(mesh)
	box(mesh, 0, 0, 1.66, 1.62, 0.62, 0.08)
end, nil, 0, nil, 2.2, true)
finishParts()
