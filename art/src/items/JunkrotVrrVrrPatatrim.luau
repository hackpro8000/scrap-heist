-- Vrr Vrr Patatrim: Brr Brr Patapim from scrap. A trunk of rusted pipe for
-- a body, flaring at its foot like roots, on two stumpy pipe legs in a pair
-- of huge boots; wire branches for arms with twigs off them and more for
-- hair; on top a tin monkey's head with its own big drooping nose, round
-- eyes under a heavy brow, a pale muzzle and round ears. No googly face.
-- 4 studs tall.
-- include: JunkrotKit
local TIN = { 0.74, 0.7, 0.6 }
local TRUNK = { 0.42, 0.28, 0.18 }
local PALE = { 0.86, 0.78, 0.62 }
local HEAD = { 0, 0, 3.25 }
-- The head and all on it a quarter bigger, about its middle.
local function big(m)
	return m:transform(function(p)
		return { HEAD[1] + (p[1] - HEAD[1]) * 1.25, HEAD[2] + (p[2] - HEAD[2]) * 1.25, HEAD[3] + (p[3] - HEAD[3]) * 1.25 }
	end)
end
part("Trunk", nil, TRUNK, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.62, 0 }, { 0.55, 0.15 }, { 0.5, 0.4 }, { 0.5, 1.8 }, { 0.56, 1.9 }, { 0.56, 2.0 }, { 0, 2.0 } }, 20)
	m:translate(0, 0, 0.8)
	m:emit(mesh)
	for _, side in { -1, 1 } do
		Kit.tube({ { side * 0.25, 0, 0.95 }, { side * 0.33, -0.08, 0.4 } }, 0.2, 10):emit(mesh)
	end
end, 40, 0.4)
part("Boots", nil, { 0.36, 0.2, 0.12 }, function(mesh)
	for _, side in { -1, 1 } do
		local boot = Kit.shoe(1.1, 0.55, 0.45)
		Kit.turn(boot, "z", -90)
		boot:translate(side * 0.38, -0.15, 0)
		boot:emit(mesh)
	end
end, true, RUBBER)
part("MonkeyFace", nil, TIN, function(mesh)
	local head = EditMesh.sphere(0.5, 12)
	head:translate(HEAD[1], HEAD[2], HEAD[3])
	big(head):emit(mesh)
	local brow = EditMesh.capsule(0.08, 0.42, 8)
	Kit.turn(brow, "y", 90)
	brow:translate(0, -0.4, HEAD[3] + 0.2)
	big(brow):emit(mesh)
	for _, side in { -1, 1 } do
		local ear = Kit.lathe({ { 0, 0 }, { 0.2, 0 }, { 0.18, 0.06 }, { 0, 0.08 } }, 12)
		Kit.turn(ear, "y", side * 90)
		ear:translate(side * 0.48, 0, HEAD[3] + 0.02)
		big(ear):emit(mesh)
	end
end, true, 0.25)
part("Muzzle", nil, PALE, function(mesh)
	local m = EditMesh.sphere(0.3, 12)
	Kit.size(m, { 1.1, 0.6, 0.85 })
	m:translate(0, -0.38, HEAD[3] - 0.08)
	big(m):emit(mesh)
	-- The big drooping nose.
	local nose = Kit.curve({ { 0, -0.5, HEAD[3] + 0.02 }, { 0, -0.66, HEAD[3] - 0.15 }, { 0, -0.64, HEAD[3] - 0.42 } }, 4)
	big(Kit.tube(nose, function(t)
		return 0.11 + 0.07 * t
	end, 10)):emit(mesh)
end, true, 0.25)
part("Eyes", nil, { 0.95, 0.94, 0.9 }, function(mesh)
	for _, side in { -1, 1 } do
		local eye = EditMesh.sphere(0.1, 8)
		eye:translate(side * 0.18, -0.4, HEAD[3] + 0.08)
		big(eye):emit(mesh)
	end
end, true, 0)
part("Pupils", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, side in { -1, 1 } do
		local pupil = EditMesh.sphere(0.055, 8)
		pupil:translate(side * 0.18, -0.48, HEAD[3] + 0.07)
		big(pupil):emit(mesh)
	end
end, true, 0)
part("Branches", nil, DARK_STEEL, function(mesh)
	for _, side in { -1, 1 } do
		Kit.tube(Kit.curve({ { side * 0.5, 0, 2.3 }, { side * 0.9, -0.1, 2.6 }, { side * 1.15, -0.1, 3.05 } }, 3), 0.08, 8):emit(mesh)
		Kit.tube({ { side * 0.98, -0.08, 2.72 }, { side * 1.3, 0, 2.7 } }, 0.05, 6):emit(mesh)
	end
	for k = 0, 4 do
		local a = math.rad(k * 72 + 20)
		local c, s = math.cos(a), math.sin(a)
		big(Kit.tube(Kit.curve({ { c * 0.15, s * 0.15, HEAD[3] + 0.42 }, { c * 0.3, s * 0.3, HEAD[3] + 0.8 }, { c * 0.5, s * 0.5, HEAD[3] + 0.95 } }, 3), 0.025, 4)):emit(mesh)
	end
end, true, 0.3)
part("Bands", nil, RUST_ORANGE, function(mesh)
	for _, z in { 1.55, 2.2 } do
		local band = EditMesh.torus(0.51, 0.05, 20, 6)
		band:translate(0, 0, z)
		band:emit(mesh)
	end
end, true, 0.6)
part("Twigs", nil, DARK_STEEL, function(mesh)
	-- Twig fingers at the end of each branch arm.
	for _, side in { -1, 1 } do
		for k = -1, 1 do
			Kit.tube({ { side * 1.15, -0.1, 3.05 }, { side * (1.25 + 0.05 * k), -0.1 + k * 0.1, 3.3 } }, 0.03, 4):emit(mesh)
		end
	end
end, true, 0.3)
part("Mouth", nil, { 0.25, 0.16, 0.1 }, function(mesh)
	local m = EditMesh.capsule(0.03, 0.16, 6)
	Kit.turn(m, "y", 90)
	m:translate(0, -0.6, HEAD[3] - 0.28)
	big(m):emit(mesh)
end, true, 0)
finishParts()
