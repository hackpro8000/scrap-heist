-- Junkrot Face: the bits every junkrot shares. An item sets FACE, a list of
-- eyes { x, y, z, size } on its front (-y), and FEET { spread, height }: how
-- far apart its two legs stand and how tall they are (the body starts at
-- that height). It includes this after its own parts.
--
-- Eyes are googly: a white ball with a black pupil looking a little off to
-- one side, so no two junkrots stare the same way.
part("Eyes", nil, { 0.96, 0.96, 0.92 }, function(mesh)
	for _, eye in FACE do
		sphere(mesh, eye[1], eye[2], eye[3], eye[4], eye[4] * 0.6, eye[4], 6, 12)
	end
end, true, 0)
part("Pupils", nil, { 0.05, 0.05, 0.06 }, function(mesh)
	for index, eye in FACE do
		local size = eye[4]
		local drift = (if index % 2 == 0 then 0.25 else -0.15) * size
		sphere(mesh, eye[1] + drift, eye[2] - size * 0.5, eye[3] - size * 0.15, size * 0.45, size * 0.2, size * 0.45, 5, 10)
	end
end, true, 0)
part("Legs", nil, RUBBER_BLACK, function(mesh)
	local spread, height = FEET[1], FEET[2]
	for _, side in { -1, 1 } do
		cylinder(mesh, side * spread / 2, 0, height / 2 + 0.1, 0.11, height, "z", 8)
		-- A stubby boot, toe forward.
		box(mesh, side * spread / 2, -0.16, 0, 0.42, 0.72, 0.24)
	end
end, nil, RUBBER)
finishParts()
