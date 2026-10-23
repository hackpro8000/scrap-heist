-- Machine Pad: the fixed spot in a yard where a salvage machine is placed,
-- 6x6 studs. A steel plate with a hazard-striped border, an inset bay for
-- the machine and a bolt in each corner. Built flat with the top at z 0.36.
local HAZARD_YELLOW = { 0.9, 0.72, 0.15 }

part("Plate", nil, DARK_STEEL, function(mesh)
	box(mesh, 0, 0, 0, 6, 6, 0.3)
	box(mesh, 0, 0, 0.3, 3.6, 3.6, 0.04)
	for _, x in { -2.65, 2.65 } do
		for _, y in { -2.65, 2.65 } do
			bolt(mesh, x, y, 0.33, "z", 0.12)
		end
	end
end, nil, 0.5)
part("Stripes", nil, HAZARD_YELLOW, function(mesh)
	for _, side in { -1, 1 } do
		box(mesh, side * 2.3, 0, 0.3, 0.5, 4.1, 0.06)
		box(mesh, 0, side * 2.3, 0.3, 4.1, 0.5, 0.06)
	end
end, nil, 0.35)
finishParts()
