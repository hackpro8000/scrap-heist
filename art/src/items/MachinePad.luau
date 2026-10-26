-- Machine Pad: the fixed spot in a yard where a salvage machine is placed,
-- 6x6 studs. A steel plate with a hazard-striped border, an inset bay for
-- the machine and a bolt in each corner. Built flat with the top at z 0.36.
BRUSHED = true
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
part("Hardware", nil, STEEL, function(mesh)
	-- Mounting rails in the bay that the machine's feet lock onto.
	for _, x in { -1, 1 } do
		box(mesh, x, 0, 0.34, 0.24, 3.2, 0.1)
		for _, y in { -1.2, 0, 1.2 } do
			bolt(mesh, x, y, 0.44, "z", 0.06)
		end
	end
	-- Power junction box on the back edge with a conduit into the bay.
	box(mesh, 0, 2.75, 0.3, 1.0, 0.4, 0.5)
	box(mesh, 0, 2.53, 0.5, 0.6, 0.04, 0.22)
	tube(mesh, { { 0, 2.55, 0.42 }, { 0, 2.1, 0.42 }, { 0, 1.8, 0.36 } }, 0.07, 6)
	for _, x in { -0.4, 0.4 } do
		bolt(mesh, x, 2.75, 0.8, "z", 0.05)
	end
end, nil, 0.45)
finishParts()
