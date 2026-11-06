-- Rusteli Rustela: an elephant built on an oil barrel, studded with rebar
-- spikes like a cactus, with sheet-tin ears, a hose trunk and flip-flops
-- cut from tyre rubber. 3.6 studs tall. Rebuilt from scrap, in our own
-- look.
local FACE = { { -0.34, -1.5, 2.4, 0.22 }, { 0.34, -1.5, 2.45, 0.25 } }
local FEET = { 1.0, 0.7 }
local BARREL_GREEN = { 0.3, 0.52, 0.36 }
part("Barrel", nil, BARREL_GREEN, function(mesh)
	cylinder(mesh, 0, 0.3, 1.9, 1.05, 2.4, "y", 16)
	for _, y in { -0.5, 0.3, 1.1 } do
		ring(mesh, 0, y, 1.9, 1.04, 1.12, 0.1, "y", 16)
	end
end, nil, 0.3)
part("Head", nil, BARREL_GREEN, function(mesh)
	sphere(mesh, 0, -1.05, 2.2, 0.7, 0.6, 0.7, 8, 14)
end, true, 0.3)
part("Trunk", nil, { 0.16, 0.16, 0.17 }, function(mesh)
	tube(mesh, { { 0, -1.55, 2.0 }, { 0, -1.95, 1.6 }, { 0, -1.95, 1.0 }, { 0, -1.7, 0.7 } }, 0.16, 8)
end, true, RUBBER)
part("Ears", nil, { 0.72, 0.7, 0.66 }, function(mesh)
	for _, side in { -1, 1 } do
		sphere(mesh, side * 0.95, -0.95, 2.3, 0.5, 0.06, 0.6, 5, 12)
	end
end, true, 0.3)
part("Spikes", nil, DARK_STEEL, function(mesh)
	for row = 0, 2 do
		for k = -2, 2 do
			local angle = math.rad(90 + k * 32)
			local y = -0.3 + row * 0.75
			strut(mesh, math.cos(angle) * 1.0, y, 1.9 + math.sin(angle) * 1.0, math.cos(angle) * 1.4, y, 1.9 + math.sin(angle) * 1.4, 0.06)
		end
	end
end, nil, 0.4)
part("BackLegs", nil, BARREL_GREEN, function(mesh)
	for _, side in { -1, 1 } do
		cylinder(mesh, side * 0.5, 1.1, 0.5, 0.26, 1.0, "z", 10)
	end
end, nil, 0.3)
part("FlipFlops", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	for _, side in { -1, 1 } do
		box(mesh, side * 0.5, -0.25, 0, 0.6, 1.0, 0.1)
		box(mesh, side * 0.5, 1.05, 0, 0.6, 0.9, 0.1)
	end
end, nil, RUBBER)
-- include: JunkrotFace
