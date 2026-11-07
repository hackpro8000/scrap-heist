-- Tickworth Pocketti: a gold pocket watch standing on edge, a rounded case
-- with a bezel round its face, a cream dial with two hands, the crown and
-- bow on top, its domed lid swung open on its hinge out to one side, and a
-- chain looping off behind down to its T-bar. 3.5 studs tall.
-- include: JunkrotKit
local FACE = { { -0.3, -0.28, 1.92, 0.2 }, { 0.3, -0.28, 1.94, 0.2 } }
local FEET = { 0.9, 0.55 }
local GOLD = { 0.92, 0.72, 0.25 }
local MID = 1.6
local R = 0.95
local BOW = MID + R + 0.38 -- the bow's middle
part("Case", nil, GOLD, function(mesh)
	local m = Kit.lathe({ { 0, -0.2 }, { 0.86, -0.2 }, { R, -0.1 }, { R + 0.02, 0.02 }, { R - 0.04, 0.16 }, { 0, 0.18 } }, 28)
	Kit.turn(m, "x", 90)
	m:translate(0, 0, MID)
	m:emit(mesh)
	local bezel = EditMesh.torus(R - 0.06, 0.05, 28, 6)
	Kit.turn(bezel, "x", 90)
	bezel:translate(0, -0.17, MID)
	bezel:emit(mesh)
	local crown = Kit.lathe({ { 0, 0 }, { 0.14, 0 }, { 0.16, 0.06 }, { 0.16, 0.2 }, { 0, 0.22 } }, 12)
	crown:translate(0, 0, MID + R - 0.02)
	crown:emit(mesh)
	local bow = EditMesh.torus(0.22, 0.045, 16, 6)
	Kit.turn(bow, "x", 90)
	bow:translate(0, 0, BOW)
	bow:emit(mesh)
end, true, 0.03)
part("Lid", nil, GOLD, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { R, 0 }, { R - 0.05, 0.08 }, { 0.5, 0.15 }, { 0, 0.17 } }, 28)
	Kit.turn(m, "x", 90)
	-- Hinged at its right edge, swung open toward us.
	m:translate(-R, 0, 0)
	Kit.turn(m, "z", 110)
	m:translate(R, -0.12, MID)
	m:emit(mesh)
end, true, 0.03)
part("Dial", nil, { 0.97, 0.96, 0.92 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.84, 0 }, { 0.84, 0.02 }, { 0, 0.02 } }, 28)
	Kit.turn(m, "x", 90)
	m:translate(0, -0.18, MID)
	m:emit(mesh)
end, 40, 0)
part("Hands", nil, { 0.08, 0.08, 0.1 }, function(mesh)
	for _, hand in { { 150, 0.55 }, { 240, 0.4 } } do
		local m = Kit.plate({ { -0.025, -0.06 }, { 0.025, -0.06 }, { 0.015, hand[2] }, { -0.015, hand[2] } }, 0.02)
		Kit.turn(m, "y", hand[1])
		m:translate(0, -0.22, MID)
		m:emit(mesh)
	end
end, 40, 0)
part("Chain", nil, GOLD, function(mesh)
	-- Looping off the bow, round behind and down: a rope of round links.
	local path = Kit.curve({ { 0, 0.05, BOW + 0.2 }, { 0.45, 0.4, BOW }, { 0.8, 0.65, MID + 0.4 }, { 0.75, 0.6, 0.8 }, { 0.55, 0.45, 0.3 } }, 8)
	Kit.tube(path, function(t)
		return 0.035 + 0.02 * math.abs(math.sin(t * math.pi * 28))
	end, 6):emit(mesh)
	local bar = EditMesh.capsule(0.04, 0.3, 6)
	Kit.turn(bar, "y", 90)
	bar:translate(0.55, 0.45, 0.25)
	bar:emit(mesh)
end, true, 0.03)
-- include: JunkrotFace
