-- Socketto Sei-Sette: a raccoon sitting up, grey fur, a black mask across
-- its eyes, round ears, a pointed snout with a black nose and its own
-- bright eyes; its belly an open red socket-set case with two rows of
-- chrome sockets; its striped tail curled round behind; holding up a 6 and
-- a 7 cut from yellow number plates, one in each hand. Our own character.
-- No googly face. 3.7 studs tall.
-- include: JunkrotKit
local FUR = { 0.5, 0.5, 0.52 }
local BLACK = { 0.12, 0.12, 0.13 }
local HEAD = { 0, 0, 2.35 }
local HANDS = { { -0.85, -0.32, 2.3 }, { 0.85, -0.32, 2.3 } }
local TAIL = Kit.curve({ { 0, 0.5, 0.42 }, { 0.42, 0.92, 0.6 }, { 0.78, 0.85, 1.2 }, { 0.66, 0.55, 1.8 } }, 5)
part("Body", nil, FUR, function(mesh)
	local body = Kit.lathe({ { 0, 0 }, { 0.55, 0 }, { 0.7, 0.3 }, { 0.72, 0.8 }, { 0.6, 1.3 }, { 0.42, 1.6 }, { 0, 1.68 } }, 20)
	body:translate(0, 0, 0.25)
	body:emit(mesh)
	local head = EditMesh.sphere(0.52, 12)
	Kit.size(head, { 1.05, 0.95, 0.9 })
	head:translate(HEAD[1], HEAD[2], HEAD[3])
	head:emit(mesh)
	local snout = EditMesh.cone(0.2, 0.06, 0.42, 12, 1)
	Kit.turn(snout, "x", 90)
	snout:translate(0, -0.62, HEAD[3] - 0.1)
	snout:emit(mesh)
	for _, side in { -1, 1 } do
		local ear = EditMesh.cone(0.16, 0.05, 0.26, 8, 1)
		Kit.turn(ear, "y", side * 18)
		ear:translate(side * 0.33, 0, HEAD[3] + 0.48)
		ear:emit(mesh)
		Kit.tube(Kit.curve({ { side * 0.55, -0.1, 1.55 }, { side * 0.75, -0.22, 1.85 }, { HANDS[(side + 3) / 2][1], HANDS[1][2], HANDS[1][3] } }, 3), 0.11, 8):emit(mesh)
		local foot = EditMesh.capsule(0.13, 0.2, 8)
		Kit.turn(foot, "x", 90)
		foot:translate(side * 0.35, -0.5, 0.15)
		foot:emit(mesh)
	end
	Kit.tube(TAIL, function(t)
		return 0.18 - 0.06 * t
	end, 10):emit(mesh)
end, true, 0.2)
part("Mask", nil, BLACK, function(mesh)
	local band = EditMesh.sphere(0.53, 16)
	Kit.size(band, { 1.06, 0.97, 0.32 })
	band:translate(HEAD[1], HEAD[2], HEAD[3] + 0.08)
	band:emit(mesh)
	local nose = EditMesh.sphere(0.07, 8)
	nose:translate(0, -0.84, HEAD[3] - 0.08)
	nose:emit(mesh)
	for _, hand in HANDS do
		local paw = EditMesh.sphere(0.12, 8)
		paw:translate(hand[1], hand[2], hand[3])
		paw:emit(mesh)
	end
end, true, 0)
part("Eyes", nil, { 0.95, 0.94, 0.9 }, function(mesh)
	for _, side in { -1, 1 } do
		local eye = EditMesh.sphere(0.09, 8)
		eye:translate(side * 0.2, -0.49, HEAD[3] + 0.08)
		eye:emit(mesh)
	end
end, true, 0)
part("Pupils", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, side in { -1, 1 } do
		local pupil = EditMesh.sphere(0.05, 8)
		pupil:translate(side * 0.2, -0.56, HEAD[3] + 0.08)
		pupil:emit(mesh)
	end
end, true, 0)
part("SocketTray", nil, { 0.82, 0.14, 0.12 }, function(mesh)
	local m = Kit.block(0.8, 0.2, 0.75, 0.08)
	m:translate(0, -0.66, 1.0)
	m:emit(mesh)
end, 50, 0.03)
part("Sockets", nil, BARE_METAL, function(mesh)
	for row = 0, 1 do
		for k = 0, 4 do
			local socket = EditMesh.cylinder(0.055 + k * 0.005, 0.12, 8, 1)
			Kit.turn(socket, "x", 90)
			socket:translate(-0.28 + k * 0.14, -0.78, 0.84 + row * 0.3)
			socket:emit(mesh)
		end
	end
end, true, 0.03)
part("TailRings", nil, BLACK, function(mesh)
	-- Dark bands down the tail: short slices of it, a touch fatter.
	for k = 0, 2 do
		local from = 4 + k * 4
		local slice = { TAIL[from], TAIL[from + 1] }
		local t = (from - 1) / (#TAIL - 1)
		Kit.tube(slice, 0.2 - 0.06 * t, 10):emit(mesh)
	end
end, true, 0)
part("Numbers", nil, { 0.98, 0.86, 0.2 }, function(mesh)
	-- A 7 in the left hand, a 6 in the right, each standing up from the paw.
	local seven = { HANDS[1][1], HANDS[1][2] - 0.05, HANDS[1][3] + 0.5 }
	for _, outline in { { { -0.22, 0.3 }, { 0.22, 0.3 }, { 0.22, 0.42 }, { -0.22, 0.42 } }, { { 0.1, 0.3 }, { 0.22, 0.3 }, { -0.05, -0.38 }, { -0.17, -0.38 } } } do
		local stroke = Kit.plate(outline, 0.05)
		stroke:translate(seven[1], seven[2], seven[3])
		stroke:emit(mesh)
	end
	local six = { HANDS[2][1], HANDS[2][2] - 0.05, HANDS[2][3] + 0.32 }
	local loop = EditMesh.torus(0.14, 0.05, 16, 6)
	Kit.turn(loop, "x", 90)
	loop:translate(six[1], six[2], six[3])
	loop:emit(mesh)
	Kit.tube(Kit.curve({ { six[1] - 0.14, six[2], six[3] }, { six[1] - 0.12, six[2], six[3] + 0.3 }, { six[1] + 0.04, six[2], six[3] + 0.48 }, { six[1] + 0.16, six[2], six[3] + 0.44 } }, 3), 0.05, 6):emit(mesh)
end, 40, 0.05)
finishParts()
