-- Pallets: a stack of wooden shipping pallets, the top one slid off and
-- missing slats. Centered on the origin.
local WOOD = { 0.55, 0.4, 0.25 }

local function pallet(mesh, x, y, z, missing)
	for i = 0, 2 do
		box(mesh, x, y - 0.8 + i * 0.8, z, 2.4, 0.2, 0.18)
	end
	for i = 0, 6 do
		if i ~= missing then
			box(mesh, x - 1.1 + i * 0.37, y, z + 0.18, 0.28, 1.8, 0.06)
		end
	end
end

part("Wood", nil, WOOD, function(mesh)
	pallet(mesh, 0, 0, 0, -1)
	pallet(mesh, 0.05, 0.05, 0.24, -1)
	pallet(mesh, -0.1, 0, 0.48, 4)
	pallet(mesh, 0.5, 0.3, 0.72, 2)
end, nil, 0.1)

part("Nails", nil, DARK_STEEL, function(mesh)
	for i = 0, 6 do
		bolt(mesh, 0.5 - 1.1 + i * 0.37, 0.3, 0.98, "z", 0.03)
	end
end, nil, 0.7)

finishParts()
