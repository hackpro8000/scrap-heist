-- Drippi Droppi: Trippi Troppi from scrap. A shrimp bent from copper tube,
-- its segmented body arching up from a fanned tail on the ground to a tin
-- cat's head: pointed ears, a muzzle with wire whiskers, its own green cat
-- eyes, and an oil drip off its chin. Little copper swimmerets under the
-- body, two walking legs in front and long antennae swept back. No googly
-- face. 3.2 studs tall.
-- include: JunkrotKit
local TIN = { 0.7, 0.72, 0.72 }
local HEAD = { 0.5, 0, 2.25 } -- the cat head's middle
local SPINE = Kit.curve({ { -1.15, 0, 0.08 }, { -1.05, 0, 0.95 }, { -0.7, 0, 1.55 }, { -0.15, 0, 1.9 }, { 0.35, 0, 1.98 } }, 4)
local function girth(t)
	return 0.16 + 0.26 * t
end
-- A point a share t of the way along the spine, and the way it runs there.
local function along(t)
	local i = 1 + t * (#SPINE - 1)
	local k = math.min(#SPINE - 1, math.floor(i))
	local a, b = SPINE[k], SPINE[k + 1]
	local f = i - k
	return { a[1] + (b[1] - a[1]) * f, a[2], a[3] + (b[3] - a[3]) * f }, math.deg(math.atan2(b[1] - a[1], b[3] - a[3]))
end
part("Tail", nil, COPPER, function(mesh)
	Kit.tube(SPINE, girth, 12):emit(mesh)
	-- Swimmerets under the body, legs to stand on in front.
	for k = 1, 5 do
		local p = along(0.1 + k * 0.11)
		local z = p[3] - girth(0.1 + k * 0.11) - 0.22
		if z > 0.12 then
			for _, side in { -1, 1 } do
				Kit.tube({ { p[1], side * 0.12, p[3] - 0.1 }, { p[1] + 0.12, side * 0.2, z } }, 0.035, 6):emit(mesh)
			end
		end
	end
	for _, side in { -1, 1 } do
		Kit.tube(Kit.curve({ { 0.1, side * 0.15, 1.8 }, { 0.22, side * 0.3, 0.9 }, { 0.3, side * 0.32, 0.08 } }, 3), 0.045, 6):emit(mesh)
	end
end, true, 0.5)
part("Bands", nil, { 0.5, 0.3, 0.16 }, function(mesh)
	-- A ring at each joint, a little proud of the body.
	for k = 1, 6 do
		local t = k / 7
		local p, heading = along(t)
		local ring = EditMesh.torus(girth(t) + 0.015, 0.045, 16, 6)
		Kit.turn(ring, "y", heading)
		ring:translate(p[1], p[2], p[3])
		ring:emit(mesh)
	end
end, true, 0.6)
part("Fan", nil, COPPER, function(mesh)
	-- Five plates fanned flat on the ground behind the tail.
	for k = -2, 2 do
		local plate = Kit.plate({ { 0, -0.12 }, { 0.55, -0.2 }, { 0.62, 0 }, { 0.55, 0.2 }, { 0, 0.12 } }, 0.05)
		Kit.turn(plate, "x", 90)
		Kit.turn(plate, "z", 180 + k * 28)
		plate:translate(-1.15, 0, 0.06)
		plate:emit(mesh)
	end
end, 40, 0.5)
part("Head", nil, TIN, function(mesh)
	local head = EditMesh.sphere(0.48, 12)
	Kit.size(head, { 0.95, 0.9, 0.85 })
	head:translate(HEAD[1], HEAD[2], HEAD[3])
	head:emit(mesh)
	for _, side in { -1, 1 } do
		local ear = EditMesh.cone(0.16, 0.02, 0.32, 4, 1)
		Kit.turn(ear, "y", side * 15)
		ear:translate(HEAD[1] + side * 0.25, -0.05, HEAD[3] + 0.42)
		ear:emit(mesh)
	end
	local muzzle = EditMesh.sphere(0.2, 8)
	Kit.size(muzzle, { 1.2, 0.7, 0.8 })
	muzzle:translate(HEAD[1], -0.38, HEAD[3] - 0.12)
	muzzle:emit(mesh)
end, true, 0.45)
part("Whiskers", nil, DARK_STEEL, function(mesh)
	local nose = EditMesh.sphere(0.06, 8)
	nose:translate(HEAD[1], -0.52, HEAD[3] - 0.06)
	nose:emit(mesh)
	for _, side in { -1, 1 } do
		for k = -1, 1 do
			Kit.tube({ { HEAD[1] + side * 0.16, -0.46, HEAD[3] - 0.12 }, { HEAD[1] + side * 0.75, -0.52, HEAD[3] - 0.12 + k * 0.08 } }, 0.012, 4):emit(mesh)
		end
	end
end, true, 0.3)
part("Antennae", nil, COPPER, function(mesh)
	for _, side in { -1, 1 } do
		local path = Kit.curve({ { HEAD[1] - 0.05, side * 0.1, HEAD[3] + 0.35 }, { HEAD[1] - 0.3, side * 0.3, HEAD[3] + 0.85 }, { HEAD[1] - 1.1, side * 0.45, HEAD[3] + 0.75 } }, 4)
		Kit.tube(path, 0.022, 4):emit(mesh)
	end
end, true, 0.5)
part("Eyes", nil, { 0.75, 0.85, 0.3 }, function(mesh)
	for _, side in { -1, 1 } do
		local eye = EditMesh.sphere(0.12, 8)
		Kit.size(eye, { 1, 0.5, 1 })
		eye:translate(HEAD[1] + side * 0.2, -0.36, HEAD[3] + 0.1)
		eye:emit(mesh)
	end
end, true, 0)
part("Pupils", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, side in { -1, 1 } do
		local slit = EditMesh.sphere(0.1, 8)
		Kit.size(slit, { 0.25, 0.4, 0.85 })
		slit:translate(HEAD[1] + side * 0.2, -0.41, HEAD[3] + 0.1)
		slit:emit(mesh)
	end
end, true, 0)
part("Drip", nil, { 0.1, 0.08, 0.05 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.07, 0.04 }, { 0.08, 0.1 }, { 0.04, 0.2 }, { 0, 0.26 } }, 12)
	m:translate(HEAD[1], -0.3, HEAD[3] - 0.68)
	m:emit(mesh)
end, true, 0)
part("Mouth", nil, { 0.2, 0.12, 0.1 }, function(mesh)
	local m = EditMesh.capsule(0.025, 0.12, 6)
	Kit.turn(m, "y", 90)
	m:translate(HEAD[1], -0.48, HEAD[3] - 0.22)
	m:emit(mesh)
end, true, 0)
finishParts()
