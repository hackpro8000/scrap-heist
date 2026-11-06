-- Capsule, Precision tier: a brushed-aluminium flight case, 2.2 studs tall,
-- 3.2 wide, with black edge extrusions, ball corners, butterfly clasps and
-- a recessed handle. Stands on the origin.
local ALUMINIUM = { 0.8, 0.82, 0.84 }
local EXTRUSION = { 0.13, 0.13, 0.15 }
part("Shell", nil, ALUMINIUM, function(mesh)
	box(mesh, 0, 0, 0.1, 3.1, 1.9, 2.0)
end, nil, 0.05)
part("Edges", nil, EXTRUSION, function(mesh)
	for _, z in { 0.02, 2.02 } do
		for _, y in { -0.95, 0.95 } do
			box(mesh, 0, y, z, 3.2, 0.16, 0.16)
		end
		for _, x in { -1.55, 1.55 } do
			box(mesh, x, 0, z, 0.16, 1.9, 0.16)
		end
	end
	for _, x in { -1.55, 1.55 } do
		for _, y in { -0.95, 0.95 } do
			box(mesh, x, y, 0.1, 0.16, 0.16, 2.0)
		end
	end
	-- The seam where the lid meets the base.
	box(mesh, 0, 0, 1.38, 3.16, 1.96, 0.07)
end, nil, 0.05)
part("Corners", nil, BARE_METAL, function(mesh)
	for _, x in { -1.55, 1.55 } do
		for _, y in { -0.95, 0.95 } do
			for _, z in { 0.12, 2.1 } do
				sphere(mesh, x, y, z, 0.2, 0.2, 0.2, 6, 10)
			end
		end
	end
end, true, 0.05)
part("Clasps", nil, BARE_METAL, function(mesh)
	for _, x in { -0.95, 0.95 } do
		box(mesh, x, -0.99, 1.1, 0.44, 0.08, 0.6)
		ring(mesh, x, -1.05, 1.42, 0.07, 0.17, 0.05, "y", 10)
	end
	box(mesh, 0, -0.99, 1.62, 0.9, 0.06, 0.2)
end, nil, 0.05)
finishParts()
