-- Chimneyzini Spannerini: Chimpanzini Bananini from scrap. A length of
-- stove pipe painted banana yellow, bent like a banana and standing on its
-- dark stalk end, its top peeled back in four strips curling out and down
-- with dark tips; a tin chimp coming up out of it, hands on the peel, with
-- its own muzzle, brow, ears and eyes, and a spanner in one fist. No
-- googly face. 4 studs tall.
-- include: JunkrotKit
local PIPE_YELLOW = { 0.98, 0.84, 0.18 }
local TIN = { 0.62, 0.56, 0.48 }
local TAN = { 0.86, 0.74, 0.58 }
local DARK = { 0.3, 0.22, 0.1 }
local RIM = 2.3 -- where the peel starts
-- Bends the whole figure like a banana: about a centre off to +x, so each
-- height turns a little further toward +x than the one below.
local BEND = math.rad(16)
local function curl(p)
	local radius = RIM / BEND
	local a = p[3] / radius
	local r = radius - p[1]
	return { radius - r * math.cos(a), p[2], r * math.sin(a) }
end
local function put(m)
	m:transform(curl)
	return m
end
part("Pipe", nil, PIPE_YELLOW, function(mesh)
	local m = Kit.lathe({ { 0, 0.12 }, { 0.22, 0.12 }, { 0.5, 0.38 }, { 0.6, 0.85 }, { 0.62, 1.6 }, { 0.6, RIM }, { 0.52, RIM }, { 0.5, RIM - 0.3 }, { 0, RIM - 0.3 } }, 20)
	put(m):emit(mesh)
end, true, 0.2)
part("Peel", nil, PIPE_YELLOW, function(mesh)
	for k = 0, 3 do
		local a = math.rad(45 + 90 * k)
		local c, s = math.cos(a), math.sin(a)
		local function at(r, z)
			return { c * r, s * r, z }
		end
		local path = Kit.curve({ at(0.56, RIM - 0.05), at(0.68, RIM + 0.25), at(0.95, RIM + 0.36), at(1.15, RIM + 0.06), at(1.2, RIM - 0.4) }, 4)
		local strip = EditMesh.sweep({ { -0.035, -0.22 }, { 0.035, -0.22 }, { 0.035, 0.22 }, { -0.035, 0.22 } }, path, {
			scale = function(t)
				return 1 - 0.45 * t
			end,
		})
		put(strip):emit(mesh)
	end
end, 40, 0.2)
part("PeelTips", nil, DARK, function(mesh)
	for k = 0, 3 do
		local a = math.rad(45 + 90 * k)
		local tip = EditMesh.sphere(0.1, 8)
		tip:translate(math.cos(a) * 1.2, math.sin(a) * 1.2, RIM - 0.4)
		put(tip):emit(mesh)
	end
	local stalk = Kit.lathe({ { 0, 0 }, { 0.2, 0 }, { 0.24, 0.1 }, { 0, 0.14 } }, 12)
	put(stalk):emit(mesh)
end, true, 0.3)
part("Chimp", nil, TIN, function(mesh)
	local torso = EditMesh.capsule(0.36, 0.45, 12)
	torso:translate(0, 0, RIM + 0.05)
	put(torso):emit(mesh)
	local head = EditMesh.sphere(0.42, 12)
	Kit.size(head, { 1, 0.95, 0.95 })
	head:translate(0, 0, RIM + 0.78)
	put(head):emit(mesh)
	-- Brow ridge over the eyes.
	local brow = EditMesh.capsule(0.07, 0.36, 8)
	Kit.turn(brow, "y", 90)
	brow:translate(0, -0.34, RIM + 0.92)
	put(brow):emit(mesh)
	-- Arms down to the rim, hands on the peel.
	for _, side in { -1, 1 } do
		local arm = Kit.curve({ { side * 0.3, -0.05, RIM + 0.3 }, { side * 0.55, -0.2, RIM + 0.25 }, { side * 0.6, -0.3, RIM + 0.05 } }, 3)
		put(Kit.tube(arm, 0.09, 8)):emit(mesh)
		local hand = EditMesh.sphere(0.12, 8)
		hand:translate(side * 0.6, -0.32, RIM + 0.02)
		put(hand):emit(mesh)
	end
end, true, 0.3)
part("Face", nil, TAN, function(mesh)
	local muzzle = EditMesh.sphere(0.24, 12)
	Kit.size(muzzle, { 1.25, 0.8, 0.85 })
	muzzle:translate(0, -0.3, RIM + 0.64)
	put(muzzle):emit(mesh)
	for _, side in { -1, 1 } do
		local ear = Kit.lathe({ { 0, 0 }, { 0.16, 0 }, { 0.14, 0.05 }, { 0, 0.06 } }, 12)
		Kit.turn(ear, "y", side * 90)
		ear:translate(side * 0.4, 0, RIM + 0.82)
		put(ear):emit(mesh)
	end
end, true, 0.25)
part("Eyes", nil, { 0.95, 0.93, 0.88 }, function(mesh)
	for _, side in { -1, 1 } do
		local eye = EditMesh.sphere(0.08, 8)
		eye:translate(side * 0.15, -0.35, RIM + 0.82)
		put(eye):emit(mesh)
	end
end, true, 0)
part("Pupils", nil, { 0.08, 0.05, 0.03 }, function(mesh)
	for _, side in { -1, 1 } do
		local pupil = EditMesh.sphere(0.05, 8)
		pupil:translate(side * 0.15, -0.41, RIM + 0.82)
		put(pupil):emit(mesh)
	end
end, true, 0)
part("Spanner", nil, BARE_METAL, function(mesh)
	local shaft = Kit.block(0.07, 0.12, 0.6, 0.02)
	shaft:translate(0.6, -0.34, RIM + 0.32)
	put(shaft):emit(mesh)
	local jaw = EditMesh.torus(0.11, 0.04, 12, 6)
	Kit.turn(jaw, "x", 90)
	jaw:translate(0.6, -0.34, RIM + 0.7)
	put(jaw):emit(mesh)
end, 40, 0.1)
finishParts()
