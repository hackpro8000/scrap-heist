-- Socketto Sei-Sette: a raccoon sitting up on its haunches, built of
-- scrap after the real animal: a pear of a body, wide at the hips,
-- narrowing to the shoulders, a broad head with round ears, a pointed
-- enamel snout with a rubber nose, little hands held up at the chest,
-- flat feet splayed forward, a ringed tail curled round on the ground.
-- The skin is mismatched plates (JunkrotScrap), a band of soot-black
-- plates across the eyes for the mask, googly eyes in it; its belly is an
-- open socket-set case, chrome sockets in rows, the lid lying open in its
-- lap. Nose +x, z up. 3.5 studs tall to the ear tips. Our own character.
-- include: JunkrotScrap
local SOOT = { 0.1, 0.1, 0.11 }
local DARK = { 0.18, 0.19, 0.21 }
local ENAMEL = { 0.86, 0.86, 0.82 }
local GALV = { 0.6, 0.63, 0.62 }
local CASE_RED = { 0.62, 0.12, 0.1 }

-- Turns a mesh so its z axis points along d, then sets it at p.
local function aim(m, p, d)
	local len = math.sqrt(d[1] ^ 2 + d[2] ^ 2 + d[3] ^ 2)
	local n = { d[1] / len, d[2] / len, d[3] / len }
	Kit.turn(m, "y", math.deg(math.acos(math.clamp(n[3], -1, 1))))
	Kit.turn(m, "z", math.deg(math.atan2(n[2], n[1])))
	return m:translate(p[1], p[2], p[3])
end

-- The body: lofted along x from the seat to the crown, then stood upright
-- (loft x -> z, loft top -> the back, -x). Stations: height, how far back,
-- how far forward (negative), half width.
local L0 = Scrap.loft({
	stations = {
		{ 0.0, 0.14, -0.16, 0.16 },
		{ 0.18, 0.56, -0.62, 0.74 },
		{ 0.55, 0.62, -0.72, 0.86 },
		{ 1.0, 0.56, -0.7, 0.74 },
		{ 1.45, 0.47, -0.58, 0.6 },
		{ 1.85, 0.4, -0.42, 0.5 },
		{ 2.1, 0.34, -0.3, 0.42 },
		{ 2.35, 0.48, -0.42, 0.56 },
		{ 2.7, 0.52, -0.46, 0.6 },
		{ 3.0, 0.42, -0.36, 0.5 },
		{ 3.18, 0.2, -0.16, 0.26 },
		{ 3.25, 0.03, -0.03, 0.04 },
	},
	sides = 28,
	steps = 90,
})
local function up(p)
	return { -p[3], p[2], p[1] }
end
local L = { x0 = L0.x0, x1 = L0.x1, at = { 0, 0, 0 }, station = L0.station }
L.mesh = L0.mesh:transform(up)
function L.skin(x, a)
	return up(L0.skin(x, a))
end
function L.normal(x, a)
	local p, n = L0.normal(x, a)
	return up(p), up(n)
end
function L.on(x, a, lift)
	return up(L0.on(x, a, lift))
end
-- The angle round the section a point of the skin sits at, from the back.
local function roundAngle(p)
	return math.deg(math.atan2(math.abs(p[2]), -p[1]))
end

-- The snout, pulled out of the face in three steps, narrowing and dipping
-- a little; its end is the nose.
local M = L.mesh
local nose
M:tagging("snout", function()
	local face = M:select("face", "facing", { 1, 0, -0.1 }, 32):filter(function(p)
		return p[3] > 2.3 and p[3] < 2.62 and math.abs(p[2]) < 0.2
	end)
	local top = M:extrude(face, { 0.2, 0, -0.03 })
	top:scale({ 1, 0.75, 0.72 })
	top = M:extrude(top, { 0.18, 0, -0.03 })
	top:scale({ 1, 0.66, 0.66 })
	top = M:extrude(top, { 0.1, 0, -0.02 })
	top:scale({ 1, 0.6, 0.6 })
	nose = top
end)
M:tagging("nose", function()
	nose:tag("nose")
end)
-- The ears: the top corners of the skull pulled up and out, rounding in.
M:tagging("ear", function()
	for _, side in { -1, 1 } do
		local root = M:select("face", "facing", { 0, side * 0.55, 0.84 }, 36):filter(function(p)
			local a = roundAngle(p)
			return p[3] > 2.9 and p[3] < 3.17 and a > 52 and a < 98 and p[2] * side > 0
		end)
		if root:count() > 0 then
			local top = M:extrude(root, 0.2)
			top:scale(0.78)
			top = M:extrude(top, 0.14)
			top:scale(0.5)
			top:tag("ear")
		end
	end
end)

part("Body", nil, DARK, function(mesh)
	Scrap.skinPart(L, { drop = { "snout", "nose", "ear" } }):emit(mesh)
end, true, 0.4)
part("Snout", nil, ENAMEL, function(mesh)
	Scrap.skinPart(L, { keep = "snout" }, 0.03):emit(mesh)
end, 40, 0.3)
part("Nose", nil, SOOT, function(mesh)
	Scrap.skinPart(L, { keep = "nose" }, 0.04):emit(mesh)
end, true, RUBBER)
part("Ears", nil, GALV, function(mesh)
	Scrap.skinPart(L, { keep = "ear" }, 0.03):emit(mesh)
end, 40, 0.5)

-- The tail: a dark core along a curve from the rump, round the right
-- side on the ground and forward, its tip lifted; over it eight rings of
-- sheet, light and dark by turns, gaps between showing the core.
local TAIL = Kit.curve({ { -0.3, 0.15, 0.3 }, { -0.8, 0.5, 0.24 }, { -0.75, 1.0, 0.2 }, { -0.25, 1.3, 0.18 }, { 0.35, 1.25, 0.2 }, { 0.8, 0.95, 0.3 } }, 10)
local RINGS = 8
local function tailRadius(t)
	return 0.21 - 0.08 * t
end
local function tailRing(k)
	local n = #TAIL
	local a = math.floor((k - 1) / RINGS * (n - 1) + 0.5) + 1
	local b = math.floor(k / RINGS * (n - 1) + 0.5) + 1
	if k > 1 then
		a += 1
	end
	if k < RINGS then
		b -= 1
	end
	local path = {}
	for i = a, b do
		table.insert(path, TAIL[i])
	end
	local oct = {}
	for i = 0, 7 do
		local r = math.rad(i * 45 + 22.5)
		table.insert(oct, { math.cos(r), math.sin(r) })
	end
	return EditMesh.sweep(oct, path, { scale = function(t)
		return tailRadius((a - 1 + t * (b - a)) / (n - 1)) * 1.08
	end })
end
part("TailCore", nil, DARK, function(mesh)
	Kit.tube(TAIL, function(t)
		return tailRadius(t) * 0.92
	end, 10):emit(mesh)
end, true, 0.4)
part("TailLight", nil, { 0.78, 0.8, 0.8 }, function(mesh)
	for k = 1, RINGS, 2 do
		tailRing(k):emit(mesh)
	end
end, 40, 0.5)
part("TailDark", nil, { 0.22, 0.23, 0.25 }, function(mesh)
	for k = 2, RINGS, 2 do
		tailRing(k):emit(mesh)
	end
end, 40, 0.5)

-- Arms: pipes from the shoulders, elbows out, forearms in to the hands
-- held together at the chest, over the case; collars at the joints.
local SHOULDER = { 0.08, 0.38, 1.92 }
local ELBOW = { 0.5, 0.58, 1.5 }
local WRIST = { 0.78, 0.28, 1.72 }
local function sided(p, side)
	return { p[1], p[2] * side, p[3] }
end
part("Arms", nil, GALV, function(mesh)
	for _, side in { -1, 1 } do
		local s, e, w = sided(SHOULDER, side), sided(ELBOW, side), sided(WRIST, side)
		Kit.tube({ s, e }, 0.1, 8):emit(mesh)
		Kit.tube({ e, w }, 0.085, 8):emit(mesh)
	end
end, true, 0.5)
part("ArmCollars", nil, { 0.3, 0.33, 0.37 }, function(mesh)
	for _, side in { -1, 1 } do
		local s, e, w = sided(SHOULDER, side), sided(ELBOW, side), sided(WRIST, side)
		aim(EditMesh.tube(0.125, 0.1, 0.12, 8), e, { w[1] - e[1], w[2] - e[2], w[3] - e[3] }):emit(mesh)
		aim(EditMesh.tube(0.14, 0.1, 0.06, 10), { s[1] * 0.4 + e[1] * 0.6, s[2] * 0.4 + e[2] * 0.6, s[3] * 0.4 + e[3] * 0.6 }, { e[1] - s[1], e[2] - s[2], e[3] - s[3] }):emit(mesh)
	end
end, true, 0.5)
-- Hands: a small palm block hanging from the wrist, four finger plates.
part("Hands", nil, SOOT, function(mesh)
	for _, side in { -1, 1 } do
		local w = sided(WRIST, side)
		local palm = Kit.block(0.12, 0.17, 0.14, 0.025)
		palm:translate(w[1] + 0.04, w[2], w[3] - 0.1)
		palm:emit(mesh)
		for k = 0, 3 do
			local finger = Kit.block(0.04, 0.03, 0.14, 0.01)
			Kit.turn(finger, "y", 12)
			finger:translate(w[1] + 0.03, w[2] - 0.06 + k * 0.04, w[3] - 0.2)
			finger:emit(mesh)
		end
	end
end, 40, RUBBER)
-- Feet: flat soles out in front of the haunches, toes on the end.
part("Feet", nil, SOOT, function(mesh)
	for _, side in { -1, 1 } do
		local foot = Kit.block(0.62, 0.26, 0.1, 0.04)
		Kit.turn(foot, "z", side * 10)
		foot:translate(0.5, side * 0.42, 0.05)
		foot:emit(mesh)
		for k = 0, 3 do
			local toe = Kit.block(0.16, 0.05, 0.07, 0.015)
			toe:translate(0.84 - side * (k - 1.5) * 0.012, side * 0.42 + (k - 1.5) * 0.065 - side * 0.05, 0.035)
			toe:emit(mesh)
		end
	end
end, 40, RUBBER)

-- The socket set: a red case set into the belly, tilted back with it,
-- its tray sunk in the front and three rows of chrome sockets standing
-- in black foam; the lid hinged at its bottom edge, lying open over the
-- lap with a ratchet and a few sockets of its own.
local CASE = { x = 0.6, z = 1.15, tilt = -12 }
local LID_OPEN = 100
local function caseLocal(m)
	Kit.turn(m, "y", CASE.tilt)
	return m:translate(CASE.x, 0, CASE.z)
end
-- Puts a thing built in the lid's closed frame into its open position.
local function onLid(m)
	m:translate(-0.15, 0, 0.425)
	Kit.turn(m, "y", LID_OPEN)
	m:translate(0.15, 0, -0.425)
	return caseLocal(m)
end
local function tray(m, rim, depth)
	local front = m:select("face", "facing", { 1, 0, 0 }, 10)
	m:inset(front, rim, -depth)
	return m
end
part("Case", nil, CASE_RED, function(mesh)
	caseLocal(tray(Kit.block(0.3, 1.1, 0.85, 0.03, { 1, 4, 3 }), 0.06, 0.13)):emit(mesh)
	local lid = tray(Kit.block(0.2, 1.1, 0.85, 0.03, { 1, 4, 3 }), 0.06, 0.08)
	Kit.turn(lid, "z", 180)
	lid:translate(0.25, 0, 0)
	onLid(lid):emit(mesh)
	-- The hinge: a bar along the bottom front edge.
	local hinge = EditMesh.cylinder(0.04, 1.0, 8, 1)
	Kit.turn(hinge, "x", 90)
	hinge:translate(0.15, 0, -0.425)
	caseLocal(hinge):emit(mesh)
end, 40, 0.2)
part("Foam", nil, SOOT, function(mesh)
	local pad = Kit.block(0.03, 0.98, 0.73, 0.01)
	pad:translate(0.035, 0, 0)
	caseLocal(pad):emit(mesh)
	local lidPad = Kit.block(0.03, 0.98, 0.73, 0.01)
	lidPad:translate(0.25 - 0.085, 0, 0)
	onLid(lidPad):emit(mesh)
end, 40, RUBBER)
local function socket(outer, long)
	local s = EditMesh.tube(outer, outer * 0.62, long, 12)
	Kit.turn(s, "y", 90)
	return s
end
part("Sockets", nil, BARE_METAL, function(mesh)
	local rows = { { 0.26, 6, 0.05, 0.07 }, { 0.0, 5, 0.075, 0.1 }, { -0.26, 4, 0.1, 0.12 } }
	for _, row in rows do
		local z, count, r0, r1 = row[1], row[2], row[3], row[4]
		local pitch = 0.95 / count
		for k = 0, count - 1 do
			local r = r0 + (r1 - r0) * k / math.max(count - 1, 1)
			local s = socket(r, 0.2)
			s:translate(0.05 + 0.1, -0.475 + pitch * (k + 0.5), z)
			caseLocal(s):emit(mesh)
		end
	end
	-- In the lid: four small sockets along the hinge side and a ratchet.
	for k = 0, 3 do
		local s = socket(0.055, 0.14)
		Kit.turn(s, "y", 180)
		s:translate(0.25 - 0.1 + 0.07, -0.33 + k * 0.1, 0.25)
		onLid(s):emit(mesh)
	end
	local handle = EditMesh.cylinder(0.035, 0.62, 8, 1)
	Kit.turn(handle, "x", 90)
	handle:translate(0.25 - 0.1 + 0.035, 0.08, -0.08)
	onLid(handle):emit(mesh)
	local head = EditMesh.cylinder(0.09, 0.06, 12, 1)
	Kit.turn(head, "y", 90)
	head:translate(0.25 - 0.1 + 0.035, 0.42, -0.08)
	onLid(head):emit(mesh)
end, true, 0)

-- Googly eyes in the mask band, either side of the snout's root.
local eyes = {}
for _, side in { -1, 1 } do
	local p, n = L.normal(2.73, side * 143)
	table.insert(eyes, { { p[1] + n[1] * 0.03, p[2] + n[2] * 0.03, p[3] + n[3] * 0.03 }, n })
end
Scrap.googlyEyes(eyes, 0.12)

-- The plating: bands round the section (0 the back, 180 the front) with
-- cuts up the height; pale metals on the belly, the mask a band of soot
-- plates across the eyes with the dark stripe up the forehead, enamel
-- cheeks and brow; openings for the case, the snout and the ears.
local panels = Scrap.panels(L, {
	bands = {
		{ 0, 55, { 0.05, 0.55, 1.3, 1.9, 2.3, 2.85, 3.2 } },
		{ 55, 95, { 0.05, 0.35, 1.0, 1.6, 2.1, 2.3, 2.62, 2.9, 3.2 } },
		{ 95, 135, { 0.05, 0.7, 1.15, 1.6, 2.0, 2.3, 2.62, 2.85, 3.05, 3.2 } },
		{ 135, 160, { 0.05, 0.4, 0.7, 1.6, 1.95, 2.3, 2.62, 2.85, 3.05, 3.2 } },
		{ 160, 180, { 0.05, 0.7, 1.6, 2.0, 2.3, 2.62, 2.85, 3.05, 3.2 } },
	},
	paleFrom = 135,
	splits = { [3] = 0.45, [7] = 0.6, [12] = 0.35, [18] = 0.55, [23] = 0.4, [29] = 0.65, [34] = 0.5, [40] = 0.3 },
	noSplitFrom = 2.3,
	open = function(band, x0, x1)
		if band >= 4 and x0 >= 0.7 and x1 <= 1.6 then
			return true -- the case
		end
		if band == 5 and x0 >= 2.3 and x1 <= 2.62 then
			return true -- the snout
		end
		return band == 2 and x0 >= 2.9 -- the ears
	end,
	metal = function(band, _, _, _, x0, x1)
		if band >= 3 and x0 >= 2.62 and x1 <= 2.85 then
			return { "SOOT", SOOT }
		end
		if band == 5 and x0 >= 2.85 and x0 < 3.05 then
			return { "SOOT", SOOT }
		end
		if band >= 3 and x0 >= 2.3 and x1 <= 2.62 then
			return { "ENAMEL", ENAMEL }
		end
		if band >= 3 and band <= 4 and x0 >= 2.85 then
			return { "ENAMEL", ENAMEL }
		end
		return nil
	end,
})
Scrap.panelParts(L, panels, { rivetsUpTo = 3.0 })
finishParts()
