-- Gascanini Honkini: Bombombini Gusini from scrap. A goose beaten out of
-- chrome tin, plump in the breast, its long neck curved up in an S to a
-- head with its orange beak wide open mid-honk; swept-back wings with a
-- red jerry can slung under each for a jet engine, glowing blue out of
-- the back; a short upturned tail and its own orange legs and webbed
-- feet. Small black goose eyes, no googly face. 3.7 studs tall.
-- include: JunkrotKit
local ORANGE = { 1.0, 0.6, 0.1 }
local MID = 1.75 -- the body's middle
local HEAD = { 1.0, 0, MID + 1.62 }
local CANS = { -1.0, 1.0 } -- the jerry cans' y
part("Body", nil, BARE_METAL, function(mesh)
	local m = EditMesh.sphere(1, 16)
	Kit.size(m, { 1.0, 0.62, 0.58 })
	-- A plump breast, the tail end drawn up and narrower.
	m:transform(function(p)
		local back = math.clamp(-p[1], 0, 1)
		return { p[1] * (1 + 0.15 * back), p[2] * (1 - 0.3 * back), p[3] + 0.25 * back * back }
	end)
	m:translate(-0.1, 0, MID)
	m:emit(mesh)
	local neck = Kit.curve({ { 0.62, 0, MID + 0.15 }, { 0.86, 0, MID + 0.6 }, { 0.78, 0, MID + 1.1 }, { HEAD[1] - 0.1, 0, HEAD[3] - 0.1 } }, 4)
	Kit.tube(neck, function(t)
		return 0.2 - 0.07 * t
	end, 10):emit(mesh)
	local head = EditMesh.sphere(0.27, 12)
	Kit.size(head, { 1.25, 0.9, 0.95 })
	head:translate(HEAD[1], HEAD[2], HEAD[3])
	head:emit(mesh)
	-- The tail: a short fan, pointing back and turned up.
	local tail = Kit.plate({ { -0.22, -0.1 }, { 0.22, -0.1 }, { 0.2, 0.35 }, { -0.2, 0.35 } }, 0.06)
	Kit.turn(tail, "x", 90)
	Kit.turn(tail, "z", -90)
	Kit.turn(tail, "y", 25)
	tail:translate(-1.05, 0, MID + 0.3)
	tail:emit(mesh)
end, true, 0.05)
part("Wings", nil, BARE_METAL, function(mesh)
	local outline = { { -0.45, 0 }, { 0.35, 0 }, { -0.35, 1.25 }, { -0.85, 1.15 } }
	local near = Kit.plate(outline, 0.07)
	Kit.turn(near, "x", 90)
	near:translate(-0.1, -0.42, MID + 0.08)
	near:emit(mesh)
	local far = Kit.plate(outline, 0.07)
	Kit.turn(far, "x", -90)
	far:translate(-0.1, 0.42, MID + 0.15)
	far:emit(mesh)
end, 40, 0.05)
part("JerryCans", nil, { 0.8, 0.14, 0.12 }, function(mesh)
	for _, y in CANS do
		local can = Kit.block(0.6, 0.28, 0.4, 0.05)
		can:translate(-0.3, y, MID - 0.22)
		can:emit(mesh)
		local pylon = Kit.block(0.15, 0.1, 0.16, 0.02)
		pylon:translate(-0.3, y, MID + 0.02)
		pylon:emit(mesh)
		local spout = EditMesh.cylinder(0.05, 0.1, 8, 1)
		spout:translate(-0.08, y, MID + 0.02)
		spout:emit(mesh)
	end
end, 50, 0.05)
part("Jets", nil, { 0.5, 0.8, 1.0 }, function(mesh)
	for _, y in CANS do
		local glow = EditMesh.cylinder(0.12, 0.06, 12, 1)
		Kit.turn(glow, "y", 90)
		glow:translate(-0.62, y, MID - 0.22)
		glow:emit(mesh)
	end
end, true, 0, nil, 1.8)
part("Beak", nil, ORANGE, function(mesh)
	-- Open mid-honk: the upper half tipped up, the lower down.
	for _, tip in { { 75, 0.06 }, { 105, -0.04 } } do
		local half = EditMesh.cone(0.12, 0.02, 0.36, 8, 1)
		Kit.size(half, { 1, 0.8, 0.6 })
		Kit.turn(half, "y", tip[1])
		half:translate(HEAD[1] + 0.45, 0, HEAD[3] + tip[2])
		half:emit(mesh)
	end
end, true, 0.03)
part("Eyes", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, side in { -1, 1 } do
		local eye = EditMesh.sphere(0.05, 8)
		eye:translate(HEAD[1] + 0.1, side * 0.22, HEAD[3] + 0.08)
		eye:emit(mesh)
	end
end, true, 0)
part("Feet", nil, ORANGE, function(mesh)
	for _, side in { -1, 1 } do
		Kit.tube(Kit.curve({ { -0.05, side * 0.22, MID - 0.4 }, { 0.02, side * 0.25, 0.55 }, { 0.05, side * 0.25, 0.05 } }, 3), 0.06, 8):emit(mesh)
		local web = Kit.plate({ { 0, -0.18 }, { 0.45, 0 }, { 0, 0.18 } }, 0.04)
		Kit.turn(web, "x", 90)
		web:translate(0.0, side * 0.25, 0.04)
		web:emit(mesh)
	end
end, 40, 0.03)
finishParts()
