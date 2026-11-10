-- Yard Gate: the 8-stud fence panel players walk through, two barred doors
-- in a frame with a padlocked hasp where they meet. Matches YardFence so it
-- tiles into a fence line, centered on the origin. The crossbar stands
-- higher than the fence, so in the yard (built 1.5 times its size) it clears
-- a player (5.5 studs) by 4 studs.
-- include: HandFinish
local CROSSBAR = 6.5
-- The doors stop just under the crossbar, leaving no empty band above them.
local DOOR_TOP = 6.25
part("Frame", nil, DARK_STEEL, function(mesh)
	for _, x in { -4, 4 } do
		box(mesh, x, 0, 0, 0.4, 0.4, CROSSBAR + 0.2)
		box(mesh, x, 0, CROSSBAR + 0.2, 0.5, 0.5, 0.1)
	end
	box(mesh, 0, 0, CROSSBAR, 8.4, 0.3, 0.3)
end, nil, 0.5)
part("Doors", nil, { STEEL[1] * 0.72, STEEL[2] * 0.72, STEEL[3] * 0.72 }, function(mesh)
	for _, side in { -1, 1 } do
		local cx = side * 1.92
		box(mesh, cx, 0, 0.3, 3.7, 0.14, 0.16)
		box(mesh, cx, 0, DOOR_TOP - 0.16, 3.7, 0.14, 0.16)
		box(mesh, cx, 0, 2.3, 3.7, 0.12, 0.12)
		box(mesh, cx - side * 1.78, 0, 0.3, 0.16, 0.14, DOOR_TOP - 0.3)
		box(mesh, cx + side * 1.78, 0, 0.3, 0.16, 0.14, DOOR_TOP - 0.3)
		for i = 1, 6 do
			box(mesh, cx - 1.8 + i * 0.52, 0, 0.46, 0.06, 0.06, DOOR_TOP - 0.62)
		end
		strut(mesh, cx - side * 1.7, 0.08, 0.45, cx + side * 1.7, 0.08, DOOR_TOP - 0.2, 0.1)
	end
end, nil, 0.6, 1024)
part("Padlock", nil, COPPER, function(mesh)
	box(mesh, 0, -0.1, 2.1, 0.5, 0.06, 0.4)
	box(mesh, 0, -0.2, 1.7, 0.26, 0.14, 0.42)
	ring(mesh, 0, -0.14, 2.08, 0.06, 0.11, 0.05, "y", 8)
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
-- Thin bars are all edge, so full rust freckles them evenly.
for _, entry in parts do
	if entry.name == "Doors" then
		entry.rust *= 0.4
		-- Bars cross the rails evenly, so full contact shadow would dash them.
		entry.shade = 1
		-- Thin bars fleck under full highlights.
		entry.lit = 1.1
	elseif entry.name == "Padlock" then
		entry.rust = 0.8
	end
end
handFinish({
	Frame = "metal",
	Doors = "metal",
	Padlock = "metal",
	Hardware = "metal",
}, {}, PROP_FINISH)
finishParts()
