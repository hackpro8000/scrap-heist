-- Ground Tile: one 8x8 stud square of yard floor. Packed dirt with a few
-- sunken concrete slabs and scattered scrap so a grid of
-- tiles doesn't read as one flat sheet. Top surface sits at z 0.
BRUSHED = true
local DIRT = { 0.42, 0.36, 0.28 }
local CONCRETE = { 0.56, 0.55, 0.52 }

part("Dirt", nil, DIRT, function(mesh)
	box(mesh, 0, 0, -0.4, 8, 8, 0.4)
end, nil, 0.25)
part("Slabs", nil, CONCRETE, function(mesh)
	box(mesh, -2, 1.6, -0.02, 2.6, 2.2, 0.06)
	box(mesh, 2.3, -2.4, -0.02, 2.0, 1.6, 0.06)
	box(mesh, 0.6, 2.9, -0.02, 1.2, 1.0, 0.05)
end, nil, 0.3)
part("Scrap", nil, DARK_STEEL, function(mesh)
	box(mesh, -2.8, -2.2, 0, 0.5, 0.3, 0.08)
	bolt(mesh, -1.2, -3.1, 0, "z", 0.08)
	bolt(mesh, 3.1, 2.8, 0, "z", 0.06)
	strut(mesh, -3.2, 3.0, 0.04, -2.2, 3.4, 0.04, 0.06)
	ring(mesh, 0.2, -1.0, 0, 0.08, 0.16, 0.05, "z", 8)
end, nil, 0.7)
finishParts()
