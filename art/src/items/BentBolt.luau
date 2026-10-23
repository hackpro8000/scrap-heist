-- Bent Bolt: common loot, about 1 stud long, lying on its side with a
-- hex head, a kinked shank and a seized nut.
part("Shank", nil, STEEL, function(mesh)
	tube(mesh, { { -0.35, 0, 0.12 }, { 0.05, 0, 0.12 }, { 0.45, 0.15, 0.16 } }, 0.07, 8)
end, nil, 0.7)
part("Head", nil, COMMON, function(mesh)
	cylinder(mesh, -0.42, 0, 0.12, 0.14, 0.12, "x", 6)
	-- Nut threaded on the straight run before the kink, hugging the shank.
	ring(mesh, -0.12, 0, 0.12, 0.07, 0.13, 0.1, "x", 6)
end, nil, 0.6)
finishParts()
