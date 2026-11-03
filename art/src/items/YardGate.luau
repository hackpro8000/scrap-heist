-- Yard Gate: the 8-stud fence panel players walk through, two barred doors
-- in a frame with a padlocked hasp where they meet. Matches YardFence so it
-- tiles into a fence line, centered on the origin. The crossbar stands
-- higher than the fence, so in the yard (built 1.5 times its size) it clears
-- a player (5.5 studs) by 4 studs.
local CROSSBAR = 6.5
part("Frame", nil, DARK_STEEL, function(mesh)
	for _, x in { -4, 4 } do
		box(mesh, x, 0, 0, 0.4, 0.4, CROSSBAR + 0.2)
		box(mesh, x, 0, CROSSBAR + 0.2, 0.5, 0.5, 0.1)
	end
	box(mesh, 0, 0, CROSSBAR, 8.4, 0.3, 0.3)
end, nil, 0.5)
part("Doors", nil, STEEL, function(mesh)
	for _, side in { -1, 1 } do
		local cx = side * 1.92
		box(mesh, cx, 0, 0.3, 3.7, 0.14, 0.16)
		box(mesh, cx, 0, 4.4, 3.7, 0.14, 0.16)
		box(mesh, cx, 0, 2.3, 3.7, 0.12, 0.12)
		box(mesh, cx - side * 1.78, 0, 0.3, 0.16, 0.14, 4.26)
		box(mesh, cx + side * 1.78, 0, 0.3, 0.16, 0.14, 4.26)
		for i = 1, 6 do
			box(mesh, cx - 1.8 + i * 0.52, 0, 0.46, 0.06, 0.06, 3.94)
		end
		strut(mesh, cx - side * 1.7, 0.08, 0.45, cx + side * 1.7, 0.08, 4.4, 0.1)
	end
end, nil, 0.6)
part("Padlock", nil, COPPER, function(mesh)
	box(mesh, 0, -0.12, 2.1, 0.5, 0.06, 0.4)
	box(mesh, 0, -0.22, 1.7, 0.26, 0.14, 0.3)
	ring(mesh, 0, -0.22, 2.08, 0.06, 0.11, 0.05, "y", 8)
end, nil, 0.4)
part("Hardware", nil, DARK_STEEL, function(mesh)
	for _, side in { -1, 1 } do
		local hingeX = side * 3.72
		-- Hinge barrels joining each door to its post.
		for _, z in { 0.6, 3.9 } do
			cylinder(mesh, hingeX, 0, z, 0.1, 0.5, "z", 8)
			box(mesh, hingeX - side * 0.3, 0, z + 0.1, 0.5, 0.18, 0.3)
			bolt(mesh, hingeX - side * 0.4, -0.1, z + 0.25, "y", 0.04)
		end
		-- Caster wheel under the free end so the door doesn't sag.
		box(mesh, side * 0.5, 0, 0.12, 0.16, 0.2, 0.2)
		cylinder(mesh, side * 0.5, -0.06, 0.12, 0.12, 0.12, "y", 10)
		-- Post base plates.
		box(mesh, side * 4, 0, 0, 0.8, 0.8, 0.08)
	end
	-- Drop rod on the left door that pins into the ground.
	box(mesh, -0.35, 0.12, 0.2, 0.08, 0.08, 1.4)
	box(mesh, -0.35, 0.12, 0.6, 0.2, 0.12, 0.08)
	box(mesh, -0.35, 0.12, 1.3, 0.2, 0.12, 0.08)
	box(mesh, -0.35, 0.12, 1.6, 0.18, 0.08, 0.06)
end, nil, 0.55)
finishParts()
