-- Vrr Vrr Patatrim: a trunk of rusted pipe with wire branches for hair, a
-- tin monkey's face riveted on the front, round ears and a pair of huge
-- boots. 4 studs tall. Rebuilt from scrap, in our own look.
local FACE = { { -0.3, -0.92, 2.5, 0.24 }, { 0.3, -0.92, 2.55, 0.27 } }
local FEET = { 1.0, 0.5 }
local TIN = { 0.74, 0.7, 0.6 }
part("Trunk", nil, { 0.42, 0.28, 0.18 }, function(mesh)
	cylinder(mesh, 0, 0, 2.0, 0.75, 2.9, "z", 14)
	for k = 0, 2 do
		ring(mesh, 0, 0, 1.0 + k * 0.9, 0.74, 0.82, 0.1, "z", 14)
	end
end, nil, 0.4)
part("MonkeyFace", nil, TIN, function(mesh)
	sphere(mesh, 0, -0.72, 2.4, 0.62, 0.22, 0.6, 6, 14)
	sphere(mesh, 0, -0.86, 2.0, 0.4, 0.2, 0.3, 5, 12)
	for _, side in { -1, 1 } do
		cylinder(mesh, side * 0.82, -0.3, 2.5, 0.3, 0.12, "y", 12)
	end
end, true, 0.25)
part("Branches", nil, DARK_STEEL, function(mesh)
	for k = 0, 6 do
		local angle = k * TAU / 7
		local reach = 0.6 + (k % 3) * 0.25
		tube(mesh, { { math.cos(angle) * 0.4, math.sin(angle) * 0.4, 3.4 }, { math.cos(angle) * reach, math.sin(angle) * reach, 3.9 + (k % 2) * 0.3 } }, 0.04, 5)
	end
end, nil, 0.3)
part("Boots", nil, { 0.36, 0.2, 0.12 }, function(mesh)
	for _, side in { -1, 1 } do
		box(mesh, side * 0.55, -0.4, 0, 0.8, 1.5, 0.5)
		box(mesh, side * 0.55, 0.05, 0.5, 0.7, 0.6, 0.4)
	end
end, nil, RUBBER)
-- include: JunkrotFace
