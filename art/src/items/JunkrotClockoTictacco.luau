-- Clocko Tictacco: a twin-bell alarm clock, a drum of red-painted case
-- with rounded edges and a chrome bezel round its face, hands stuck at ten
-- to two, two domed bells on posts up top tipped outward with the hammer
-- between them mid-swing, and two butterfly winding keys out the back.
-- 3.2 studs tall.
-- include: JunkrotKit
local FACE = { { -0.3, -0.4, 1.95, 0.2 }, { 0.3, -0.4, 1.97, 0.21 } }
local FEET = { 0.9, 0.55 }
local CLOCK_RED = { 0.78, 0.2, 0.16 }
local MID = 1.55 -- the face's middle
part("Case", nil, CLOCK_RED, function(mesh)
	local m = Kit.lathe({ { 0, -0.3 }, { 0.82, -0.3 }, { 0.92, -0.22 }, { 0.95, 0 }, { 0.92, 0.22 }, { 0.82, 0.3 }, { 0, 0.3 } }, 24)
	Kit.turn(m, "x", 90)
	m:translate(0, 0, MID)
	m:emit(mesh)
end, true, 0.4)
part("Dial", nil, { 0.93, 0.9, 0.8 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.8, 0 }, { 0.8, 0.02 }, { 0, 0.02 } }, 24)
	Kit.turn(m, "x", 90)
	m:translate(0, -0.3, MID)
	m:emit(mesh)
end, 40, 0.3)
part("Hands", nil, { 0.08, 0.08, 0.09 }, function(mesh)
	-- Ten to two: the minute hand up-left, the hour hand up-right.
	for _, hand in { { -60, 0.62 }, { 55, 0.42 } } do
		local m = Kit.plate({ { -0.035, -0.08 }, { 0.035, -0.08 }, { 0.02, hand[2] }, { -0.02, hand[2] } }, 0.02)
		Kit.turn(m, "y", hand[1])
		m:translate(0, -0.35, MID)
		m:emit(mesh)
	end
	local pin = EditMesh.cylinder(0.05, 0.06, 8, 1)
	Kit.turn(pin, "x", 90)
	pin:translate(0, -0.35, MID)
	pin:emit(mesh)
end, 40, 0.2)
part("Bells", nil, BARE_METAL, function(mesh)
	local bezel = EditMesh.torus(0.84, 0.06, 32, 6)
	Kit.turn(bezel, "x", 90)
	bezel:translate(0, -0.3, MID)
	bezel:emit(mesh)
	for _, side in { -1, 1 } do
		local bell = Kit.lathe({ { 0, 0 }, { 0.42, 0 }, { 0.4, 0.12 }, { 0.3, 0.28 }, { 0, 0.34 } }, 16)
		Kit.turn(bell, "y", side * 28)
		bell:translate(side * 0.5, 0, MID + 0.95)
		bell:emit(mesh)
		Kit.tube({ { side * 0.3, 0, MID + 0.8 }, { side * 0.5, 0, MID + 1.0 } }, 0.04, 8):emit(mesh)
	end
	-- The hammer, mid-swing between the bells.
	Kit.tube({ { 0, 0, MID + 0.9 }, { 0.12, 0, MID + 1.32 } }, 0.03, 8):emit(mesh)
	local knob = EditMesh.sphere(0.07, 8)
	knob:translate(0.13, 0, MID + 1.36)
	knob:emit(mesh)
	-- Winding keys out the back.
	for _, x in { -0.35, 0.35 } do
		Kit.tube({ { x, 0.28, MID - 0.1 }, { x, 0.5, MID - 0.1 } }, 0.04, 8):emit(mesh)
		local wing = Kit.plate({ { -0.18, -0.1 }, { 0.18, -0.1 }, { 0.14, 0.1 }, { -0.14, 0.1 } }, 0.03)
		wing:translate(x, 0.5, MID - 0.1)
		wing:emit(mesh)
	end
end, true, 0.3)
part("Marks", nil, { 0.08, 0.08, 0.09 }, function(mesh)
	for k = 0, 3 do
		local mark = Kit.block(0.06, 0.02, 0.15, 0.01)
		mark:translate(0, 0, 0.62)
		Kit.turn(mark, "y", k * 90)
		mark:translate(0, -0.33, MID)
		mark:emit(mesh)
	end
end, 40, 0.2)
-- include: JunkrotFace
