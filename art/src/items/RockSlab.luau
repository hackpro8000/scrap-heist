-- Rock Slab: a broken pavement slab heaved up on one edge over a smaller
-- piece, standing in for a flat rock outcrop. Centered on the origin.
local CONCRETE = { 0.6, 0.59, 0.56 }
local KERB_PAINT = { 0.9, 0.72, 0.1 }

part("Slabs", nil, CONCRETE, function(mesh)
	-- Tilted main slab built from thin steps so it reads as a leaning plate.
	for i = 0, 9 do
		box(mesh, -1.6 + i * 0.34, 0, i * 0.09, 0.36, 2.6, 0.3)
	end
	box(mesh, 1.9, 0.6, 0, 1.2, 1.3, 0.25)
	box(mesh, -2.1, -0.9, 0, 0.7, 0.8, 0.18)
end, nil, 0.3)

part("Kerb", nil, KERB_PAINT, function(mesh)
	box(mesh, -0.2, 1.36, 0, 3.6, 0.2, 0.55)
end, nil, 0.6)

part("Grit", nil, DARK_STEEL, function(mesh)
	box(mesh, 0, 0, 0, 3.6, 2.4, 0.04)
	bolt(mesh, 1.6, 0.3, 0.26, "z", 0.06)
end, nil, 0.7)

finishParts()
