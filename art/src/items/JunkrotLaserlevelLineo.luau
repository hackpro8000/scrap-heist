-- Laserlevel Lineo: a laser level up on a little tripod, a yellow housing
-- with black rubber bumpers on both ends, two glowing bubble vials set into
-- its top, a red beam shining out of the front end, and a tripod head with
-- three spread legs. 3.4 studs tall, 4.4 long with the beam.
-- include: JunkrotKit
local FACE = { { -0.26, -0.43, 2.45, 0.16 }, { 0.26, -0.43, 2.47, 0.16 } }
local FEET = { 0.9, 0.3 }
local MID = 2.35 -- the housing's middle
part("Body", nil, { 1.0, 0.82, 0.1 }, function(mesh)
	local m = Kit.block(1.4, 0.72, 0.72, 0.1)
	m:translate(0, 0, MID)
	m:emit(mesh)
end, 50, 0.03)
part("Ends", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	for _, side in { -1, 1 } do
		local m = Kit.block(0.24, 0.84, 0.84, 0.14)
		m:translate(side * 0.75, 0, MID)
		m:emit(mesh)
	end
	local head = Kit.lathe({ { 0, 0 }, { 0.22, 0 }, { 0.26, 0.1 }, { 0.16, 0.3 }, { 0, 0.32 } }, 12)
	head:translate(0, 0, MID - 0.66)
	head:emit(mesh)
end, 50, RUBBER)
part("Vials", nil, { 0.6, 1.0, 0.4 }, function(mesh)
	for _, x in { -0.32, 0.32 } do
		local vial = EditMesh.capsule(0.07, 0.3, 8)
		Kit.turn(vial, "y", 90)
		vial:translate(x, 0, MID + 0.37)
		vial:emit(mesh)
	end
end, true, 0, nil, 0.8)
part("Beam", nil, { 1.0, 0.15, 0.1 }, function(mesh)
	Kit.tube({ { 0.86, 0, MID }, { 2.3, 0, MID } }, 0.03, 6):emit(mesh)
end, true, 0, nil, 2.0)
part("Tripod", nil, BARE_METAL, function(mesh)
	for k = 0, 2 do
		local a = math.rad(90 + k * 120)
		Kit.tube({ { 0, 0, MID - 0.62 }, { math.cos(a) * 0.85, math.sin(a) * 0.85, 0.05 } }, 0.045, 6):emit(mesh)
	end
end, true, 0.03)
-- include: JunkrotFace
