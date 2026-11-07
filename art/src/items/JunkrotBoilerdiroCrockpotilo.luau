-- Boilerdiro Crockpotilo: Bombardiro Crocodilo riveted from scrap. A
-- four-engined bomber in bare tin whose whole nose, from the cockpit glass
-- forward, is a crocodile's head in green plate: the skull as fat as the
-- fuselage, long flat jaws hanging open on a hinge at the corners, big
-- sheet teeth top and bottom, green slit eyes up on bumps behind the jaw
-- corners, a nostril bump at the tip. Straight wings with two engine
-- lofts under each, a three-bladed propeller on every one, a tall fin and
-- tailplanes in sheet-metal pieces. Nose +x, resting on its belly. About
-- 3.4 studs tall, 6.5 long.
-- include: JunkrotScrap
local MID = 0.95 -- the fuselage's axis
local DARK = { 0.18, 0.19, 0.21 }
local GREEN = { 0.3, 0.44, 0.3 }
local JOIN = 0.35 -- where the tin ends and the crocodile begins
local GLASS = { 0.6, 0.78, 0.86 }

-- The body: tail cone, round fuselage, then the head: the skull as big as
-- the fuselage, the top dropping behind the eyes to the long straight
-- snout, the underside nearly flat, a bump at the nostrils.
local STATIONS = { -- x, top, bottom, half width
	{ -3.1, 0.14, -0.04, 0.08 },
	{ -2.5, 0.32, -0.22, 0.26 },
	{ -1.8, 0.52, -0.44, 0.46 },
	{ -1.0, 0.6, -0.58, 0.58 },
	{ 0.0, 0.6, -0.6, 0.6 },
	{ 0.45, 0.58, -0.6, 0.6 },
	{ 0.9, 0.52, -0.56, 0.58 },
	{ 1.3, 0.36, -0.5, 0.5 },
	{ 1.8, 0.26, -0.42, 0.42 },
	{ 2.4, 0.2, -0.34, 0.34 },
	{ 2.9, 0.16, -0.3, 0.27 },
	{ 3.2, 0.19, -0.28, 0.21 },
	{ 3.4, 0.06, -0.12, 0.1 },
}
local STRAIGHT = 1.3
-- The mouth: its corners under the eyes, the rim running level along the
-- flank at RIM_Z below the axis, sweeping round under the snout tip.
local CORNER = 1.05
local TIP = 3.4
local REACH = TIP - CORNER - 0.02
local RIM_Z = -0.17
local NOMINAL = 105
local function sideAngle(x) -- the rim's angle round the section for a level rim
	local top, bottom = Scrap.tableAt(STATIONS, x, STRAIGHT)
	local mid = (top + bottom) / 2
	local c = math.clamp((RIM_Z - mid) / (mid - bottom), -0.95, -0.02)
	return math.deg(math.acos(c))
end
local function mouthAngle(x)
	local u = (x - CORNER) / REACH
	if u <= 0 or u >= 1 then
		return nil
	end
	local s = (1 - u ^ 5) ^ 0.2
	return 180 - math.deg(math.asin(math.sin(math.rad(sideAngle(x))) * s))
end
local L = Scrap.loft({
	stations = STATIONS,
	straightFrom = STRAIGHT,
	steps = 100,
	at = { 0, 0, MID },
	splits = {
		{ nominal = NOMINAL, tag = "mouth", angle = mouthAngle },
	},
})
-- Eye bumps raised out of the skull's top corners, nostrils sunk at the tip.
for _, side in { -1, 1 } do
	local bump = L.mesh:select("face", "facing", { 0, side * 0.75, 0.66 }, 26):filter(function(p)
		return p[1] > 0.82 and p[1] < 1.22 and p[3] > MID + 0.22
	end)
	if bump:count() > 0 then
		L.mesh:extrude(L.mesh:inset(bump, 0.02, 0), 0.11)
	end
	local nare = L.mesh:select("face", "facing", { 0, 0, 1 }, 45):filter(function(p)
		return p[1] > 3.08 and p[1] < 3.26 and p[2] * side > 0.02 and p[2] * side < 0.1
	end)
	if nare:count() > 0 then
		Kit.recess(L.mesh, nare, 0.008, 0.02)
	end
end
local ROOF = L.skin(CORNER + 0.001, NOMINAL)[3] + 0.03
local GAPE = 18

part("Body", nil, DARK, function(mesh)
	Scrap.skinPart(L, { drop = { "mouth" } }):emit(mesh)
end, true, 0.4)

-- The cockpit glass: a glazed hump on the fuselage top just behind the
-- eyes, ribbed with frames.
local C = Scrap.loft({
	stations = { { -0.2, 0.0, -0.3, 0.2 }, { 0.0, 0.22, -0.3, 0.3 }, { 0.4, 0.25, -0.3, 0.3 }, { 0.8, 0.02, -0.3, 0.18 } },
	sides = 16,
	steps = 20,
	at = { 0, 0, MID + 0.56 },
})
part("Canopy", nil, GLASS, function(mesh)
	C.mesh:emit(mesh)
end, true, 0)
part("CanopyFrames", nil, DARK, function(mesh)
	for _, x in { 0.02, 0.28, 0.54, 0.76 } do
		local path = {}
		for k = 0, 16 do
			table.insert(path, C.on(x, -95 + 190 * k / 16, 0.01))
		end
		Kit.tube(path, 0.018, 6):emit(mesh)
	end
	local spine = {}
	for k = 0, 12 do
		table.insert(spine, C.on(-0.15 + 0.92 * k / 12, 0, 0.01))
	end
	Kit.tube(spine, 0.018, 6):emit(mesh)
end, 40, 0.3)

-- Wings, tailplanes and fin: sheet metal in pieces over a dark core. The
-- wings straight with a slight dihedral, set low on the fuselage.
local WING = { { 0.55, -0.25 }, { 0.55, 0.45 }, { 0.15, 3.0 }, { -0.45, 3.0 }, { -0.95, 0.45 }, { -0.95, -0.25 } }
local WING_Z = MID - 0.12
local DIHEDRAL = 4
part("Wings", nil, DARK, function(mesh)
	for n, side in { -1, 1 } do
		Scrap.metalFin(WING, 0.24, 3.0, { 0.8, 1.55, 2.3 }, function(m)
			Kit.turn(m, "x", -side * (90 - DIHEDRAL))
			return m:translate(0, 0, WING_Z)
		end, n):emit(mesh)
	end
end, 40, 0.4)
part("Tail", nil, DARK, function(mesh)
	Scrap.metalFin({ { -3.1, -0.3 }, { -1.75, -0.3 }, { -2.55, 2.1 }, { -2.9, 2.15 }, { -3.1, 1.4 } }, 0.16, 2.15, { 0.55, 1.3 }, function(m)
		return m:translate(0, 0, MID + 0.15)
	end, 3):emit(mesh)
	for n, side in { -1, 1 } do
		Scrap.metalFin({ { -3.05, -0.2 }, { -2.0, -0.2 }, { -2.35, 1.3 }, { -2.9, 1.35 } }, 0.12, 1.35, { 0.6 }, function(m)
			Kit.turn(m, "x", -side * 90)
			return m:translate(0, 0, MID + 0.1)
		end, 4 + n):emit(mesh)
	end
end, 40, 0.4)

-- Engines: a nacelle lofted along x slung under each wing, two a side,
-- its nose ahead of the leading edge; a hub and three sheet blades.
local ENGINES = { { y = 1.0, x0 = -0.6, x1 = 1.0 }, { y = 1.95, x0 = -0.5, x1 = 0.85 } }
local function engineZ(e)
	return WING_Z + math.tan(math.rad(DIHEDRAL)) * e.y - 0.2
end
part("Engines", nil, { 0.3, 0.33, 0.37 }, function(mesh)
	for _, e in ENGINES do
		for _, side in { -1, 1 } do
			local N = Scrap.loft({
				stations = { { e.x0, 0.08, -0.08, 0.08 }, { e.x0 + 0.25, 0.24, -0.24, 0.24 }, { e.x0 + 0.6, 0.28, -0.28, 0.28 }, { e.x1 - 0.35, 0.27, -0.27, 0.27 }, { e.x1 - 0.05, 0.22, -0.22, 0.22 }, { e.x1, 0.1, -0.1, 0.1 } },
				sides = 16,
				steps = 24,
				at = { 0, side * e.y, engineZ(e) },
			})
			N.mesh:emit(mesh)
		end
	end
end, true, 0.5)
part("Cowls", nil, { 0.55, 0.35, 0.16 }, function(mesh)
	for _, e in ENGINES do
		for _, side in { -1, 1 } do
			local ring = EditMesh.torus(0.255, 0.035, 16, 6)
			Kit.turn(ring, "y", 90)
			ring:translate(e.x1 - 0.22, side * e.y, engineZ(e))
			ring:emit(mesh)
		end
	end
end, true, 0.6)
part("Hubs", nil, BARE_METAL, function(mesh)
	for _, e in ENGINES do
		for _, side in { -1, 1 } do
			local hub = EditMesh.cone(0.1, 0.03, 0.2, 8, 1)
			Kit.turn(hub, "y", 90)
			hub:translate(e.x1 + 0.08, side * e.y, engineZ(e))
			hub:emit(mesh)
		end
	end
end, true, 0.2)
part("Props", nil, DARK, function(mesh)
	-- Blades rooted on the hub's side, where it is 0.06 across.
	for _, e in ENGINES do
		for _, side in { -1, 1 } do
			local z = engineZ(e)
			for k = 0, 2 do
				local blade = Kit.plate({ { -0.05, 0.05 }, { 0.05, 0.05 }, { 0.065, 0.42 }, { -0.03, 0.5 } }, 0.03)
				blade:translate(0, -0.015, 0)
				Kit.turn(blade, "z", 90)
				Kit.turn(blade, "x", 120 * k + 20 * side)
				blade:translate(e.x1 + 0.1, side * e.y, z)
				blade:emit(mesh)
			end
		end
	end
end, 40, 0.35)

-- The mouth's rim, walked from one corner (t = -1) round the front (0) to
-- the other (1), on the skin; out lifts it off.
local function rimX(t)
	return CORNER + REACH * (1 - math.abs(t) ^ 1.3)
end
local function rimPoint(t, out)
	local p = L.skin(rimX(t), (if t < 0 then -1 else 1) * NOMINAL)
	return { p[1], p[2], p[3] + (out or 0) }
end
local function rimFacing(t)
	local p, q = rimPoint(t - 0.02), rimPoint(t + 0.02)
	return math.deg(math.atan2(q[2] - p[2], q[1] - p[1]))
end
-- Places a piece built round the mouth onto the hanging jaw: turned open
-- about the hinge line through the corners.
local function onJaw(m)
	m:translate(-CORNER, 0, -ROOF)
	Kit.turn(m, "y", GAPE)
	return m:translate(CORNER, 0, ROOF)
end
-- The lower jaw: the head's bottom slice under the rim, rings of the skin
-- between the rim's sides, flat across the top at the roof.
local function jaw()
	local m = EditMesh.new()
	local rings = {}
	local STEPS = 20
	for i = 0, STEPS do
		local t = 1 - i / STEPS
		local x = rimX(t)
		if i == STEPS then
			x = CORNER + REACH - 0.1 -- short of the tip, where the underside rises past the roof
		end
		local ring = {}
		for k = 0, 12 do
			local n = NOMINAL + (360 - 2 * NOMINAL) * k / 12
			local p = L.skin(x, if n <= 180 then n else n - 360)
			table.insert(ring, m:addVertex(p[1], p[2], math.min(p[3], ROOF - 0.012)))
		end
		for k = 11, 1, -1 do
			local n = NOMINAL + (360 - 2 * NOMINAL) * k / 12
			local p = L.skin(x, if n <= 180 then n else n - 360)
			table.insert(ring, m:addVertex(p[1], p[2], ROOF - 0.012))
		end
		table.insert(rings, ring)
	end
	for i = 1, #rings - 1 do
		local a, b = rings[i], rings[i + 1]
		for k = 1, #a do
			local k2 = k % #a + 1
			m:addFace({ a[k], b[k], b[k2], a[k2] })
		end
	end
	local front = {}
	for k = #rings[#rings], 1, -1 do
		table.insert(front, rings[#rings][k])
	end
	m:addFace(rings[1])
	m:addFace(front)
	return m
end
part("Jaw", nil, GREEN, function(mesh)
	onJaw(jaw()):emit(mesh)
end, true, 0.35)
part("Mouth", nil, { 0.42, 0.18, 0.14 }, function(mesh)
	local outline = {}
	for k = 0, 40 do
		local p = rimPoint(-1 + k / 20)
		table.insert(outline, { p[1], p[2] })
	end
	local roof = Kit.plate(outline, 0.02)
	Kit.turn(roof, "x", -90)
	roof:translate(0, 0, ROOF - 0.005)
	roof:emit(mesh)
	local floor = jaw()
	local keep = floor:select("face", "where", function(p)
		return p[3] > ROOF - 0.03
	end)
	for _, id in floor:select("face", "all"):minus(keep):list() do
		floor:removeFace(id)
	end
	floor:push(floor:select("vertex", "all"), 0.006)
	floor:solidify(0.012)
	onJaw(floor):emit(mesh)
end, true, 0)
-- A tooth: a flat triangle standing up from the origin, facing +-y, its
-- point up; turned to face along its rim.
local function tooth(wide, tall, facing)
	local m = Kit.plate({ { -wide / 2, 0 }, { wide / 2, 0 }, { 0, tall } }, 0.03)
	m:translate(0, -0.015, 0)
	Kit.turn(m, "z", facing)
	return m
end
part("Teeth", nil, { 0.95, 0.93, 0.86 }, function(mesh)
	-- Hanging from the upper rim, big ones every third; standing along the
	-- jaw's edge between them.
	local N = 11
	for k = 1, 2 * N - 1 do
		local t = -1 + k / N
		local p = rimPoint(t)
		local big = k % 3 == 1
		local tip = tooth(if big then 0.09 else 0.065, if big then 0.2 else 0.13, rimFacing(t))
		Kit.turn(tip, "y", 180)
		tip:translate(p[1] - 0.01, p[2] * 0.93, p[3] + 0.015)
		tip:emit(mesh)
	end
	for k = 1, 2 * N - 2 do
		local t = -1 + (k + 0.5) / N
		if math.abs(t) > 0.12 then -- the jaw stops short of the tip
			local p = rimPoint(t)
			local big = k % 3 == 2
			local tip = tooth(if big then 0.085 else 0.06, if big then 0.19 else 0.12, rimFacing(t))
			tip:translate(p[1] - 0.015, p[2] * 0.9, ROOF - 0.015)
			onJaw(tip):emit(mesh)
		end
	end
end, 40, 0)

-- The crocodile's own eyes: green domes with a slit pupil, on the bumps.
local eyes = {}
for _, side in { -1, 1 } do
	local p, n = L.normal(1.02, side * 38)
	table.insert(eyes, { { p[1] + n[1] * 0.1, p[2] + n[2] * 0.1, p[3] + n[3] * 0.1 }, n })
end
part("Eyes", nil, { 0.4, 0.62, 0.22 }, function(mesh)
	for _, e in eyes do
		local dome = EditMesh.sphere(0.13, 12)
		dome:translate(e[1][1], e[1][2], e[1][3])
		dome:emit(mesh)
	end
end, true, 0)
part("Pupils", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, e in eyes do
		local c, n = e[1], e[2]
		local slit = EditMesh.sphere(0.07, 8)
		Kit.size(slit, { 0.35, 0.45, 1 })
		slit:translate(c[1] + n[1] * 0.1, c[2] + n[2] * 0.1, c[3] + n[3] * 0.1)
		slit:emit(mesh)
	end
end, true, 0)

-- The plating: pale tin along the fuselage, greens over the head, cells
-- of very different lengths with a seam at the join; openings for the
-- cockpit glass, the eye bumps and the hanging jaw.
local GREENS = { { "MOSS", GREEN }, { "SWAMP", { 0.24, 0.36, 0.25 } }, { "OLIVE", { 0.42, 0.45, 0.36 } }, { "VERDIGRIS", { 0.34, 0.5, 0.42 } }, { "MOSS", GREEN } }
local TINS = { Scrap.BELLY_METALS[4], Scrap.BELLY_METALS[1], Scrap.BELLY_METALS[2], Scrap.BELLY_METALS[4], Scrap.BACK_METALS[1], Scrap.BELLY_METALS[3], Scrap.BELLY_METALS[4], Scrap.BACK_METALS[3] }
local panels = Scrap.panels(L, {
	bands = {
		{ 0, 30, { -3.1, -2.6, -1.9, -1.0, -0.2, JOIN, 0.8, 1.3, 2.0, 2.6, 3.4 } },
		{ 30, 60, { -3.1, -2.2, -1.4, -0.6, JOIN, 1.25, 1.7, 2.35, 3.0, 3.4 } },
		{ 60, 85, { -3.1, -2.7, -1.7, -1.2, 0.0, JOIN, 0.9, 1.5, 2.2, 2.8, 3.4 } },
		{ 85, NOMINAL, { -3.1, -2.4, -1.5, -0.4, JOIN, 1.05, 1.6, 2.1, 2.7, 3.4 } },
		{ NOMINAL, 140, { -3.1, -2.1, -1.3, -0.8, 0.1, JOIN, 1.05, 3.4 } },
		{ 140, 180, { -3.1, -2.5, -1.6, -0.5, JOIN, 1.05, 3.4 } },
	},
	splits = { [3] = 0.45, [8] = 0.6, [13] = 0.35, [19] = 0.55, [24] = 0.4, [30] = 0.65, [36] = 0.5 },
	noSplitFrom = JOIN,
	open = function(band, x0, x1)
		return (band == 1 and x1 > -0.2 and x0 < 0.8) or (band == 2 and x1 > 0.8 and x0 < 1.25) or (band >= 5 and x0 >= CORNER - 0.01)
	end,
	metal = function(band, seg, cell, side, x0)
		if x0 >= JOIN - 0.01 then
			return GREENS[(band * 2 + seg * 3 + (if side < 0 then 1 else 0)) % #GREENS + 1]
		end
		return TINS[(band * 3 + seg * 5 + cell * 2 + (if side < 0 then 2 else 0)) % #TINS + 1]
	end,
})
Scrap.panelParts(L, panels, { rivetsUpTo = 3.1 })
finishParts()
