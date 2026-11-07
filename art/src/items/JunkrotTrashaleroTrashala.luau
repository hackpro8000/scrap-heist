-- Trashalero Trashala: Tralalero Tralala riveted from tin sheet. A
-- grey-blue shark with a white belly, nose forward (+x), in blue sneakers
-- on its three bottom fins, the two pectorals and the fin under its tail,
-- so it sits low on them. Built after the picture: a slim torpedo body,
-- a smooth conical snout, the back sloping down to it over a flat belly
-- line; the whole skin is mismatched scrap plates (JunkrotScrap), the
-- fins sheet metal in pieces, googly eyes, a toothy grin. 3 studs tall.
-- include: JunkrotScrap
local MIDDLE = 1.3 -- the body's axis: it sits low, on its fins
local BELLY = { 0.88, 0.89, 0.86 }

-- The three bottom fins wear the sneakers: the two pectorals and the fin
-- under the tail, ordinary fins angled down so their tips reach the
-- ground. Each: where its root sits on the body, its outline's chord and
-- span, which side it points to (0 for the middle), how far it points
-- down (degrees below level) and how far it sweeps back.
local SHOD = {
	{ root = { 1.0, -0.3, -0.3 }, chord = 0.55, span = 0.95, side = -1, down = 68, back = 15 },
	{ root = { 1.0, 0.3, -0.3 }, chord = 0.55, span = 0.95, side = 1, down = 68, back = 15 },
	{ root = { -0.7, 0, -0.22 }, chord = 0.4, span = 0.62, side = 0, down = 82, back = 12 },
}
-- Turns a point as a shod fin is turned (Kit.turn's rotations): the span
-- runs up +z on the outline; it is tipped over to point down, tilted out
-- to its side and swept back.
local function finTurn(f, p)
	local function turnX(q, deg)
		local c, s = math.cos(math.rad(deg)), math.sin(math.rad(deg))
		return { q[1], q[2] * c - q[3] * s, q[2] * s + q[3] * c }
	end
	local function turnY(q, deg)
		local c, s = math.cos(math.rad(deg)), math.sin(math.rad(deg))
		return { q[1] * c + q[3] * s, q[2], -q[1] * s + q[3] * c }
	end
	local out = (90 - f.down) * (if f.side == 0 then 1 else f.side)
	local q = turnX(p, 180)
	q = turnX(q, out)
	q = turnY(q, f.back)
	return { q[1] + f.root[1], q[2] + f.root[2], q[3] + MIDDLE + f.root[3] }
end

-- How far up the section the white belly reaches, in degrees from the
-- bottom, along x: to the mid flank at the chest, lower toward the tail
-- root, and nearly to the eye on the head.
local REACH = { { -1.7, 25 }, { -1.0, 55 }, { -0.3, 85 }, { 0.5, 100 }, { 1.3, 100 }, { 2.0, 102 }, { 2.3, 95 } }
-- The mouth: a parabola on the underside of the head from its corners,
-- back under the eyes, round the front short of the snout tip. Its rim
-- sits on the skin at mouthAngle(x) round the section; the lower jaw is
-- the head's bottom slice under it, split off along a flat plane at the
-- corners' height and hinged there.
local CORNER = { x = 1.5, spread = 0.85 } -- the corners: x, and y as a share of the width there
local MOUTH_REACH = 0.6 -- how far ahead of the corners the rim goes
local function mouthAngle(x) -- the rim's angle round the section, from the top; nil outside
	local along = (x - CORNER.x) / MOUTH_REACH
	if along <= 0 or along >= 1 then
		return nil
	end
	local a = math.acos(along ^ 1.25)
	return 180 - math.deg(math.asin(CORNER.spread * math.sin(a)))
end
-- The body: a loft along x, the back arching over a belly that runs
-- nearly level, deepest forward, the snout a straight cone to a rounded
-- tip a little below the axis. The belly line and the mouth's rim are
-- warped onto ring vertices, so their splits are true edge loops.
local L = Scrap.loft({
	stations = { -- x, top, bottom, half width
		{ -1.7, 0.1, -0.08, 0.07 },
		{ -1.3, 0.2, -0.14, 0.13 },
		{ -0.8, 0.36, -0.24, 0.23 },
		{ -0.3, 0.48, -0.34, 0.33 },
		{ 0.2, 0.56, -0.4, 0.4 },
		{ 0.7, 0.58, -0.42, 0.43 },
		{ 1.1, 0.52, -0.42, 0.42 },
		{ 1.4, 0.47, -0.42, 0.4 },
		{ 1.7, 0.34, -0.37, 0.33 },
		{ 2.0, 0.16, -0.28, 0.22 },
		{ 2.2, -0.02, -0.16, 0.09 },
		{ 2.3, -0.08, -0.12, 0.03 },
	},
	straightFrom = 1.4,
	at = { 0, 0, MIDDLE },
	splits = {
		{ nominal = 90, tag = "belly", angle = function(x)
			return 180 - Scrap.tableAt(REACH, x)
		end },
		{ nominal = 150, tag = "mouth", angle = mouthAngle },
	},
})
-- Eye sockets, sunk into the sides of the head over the mouth's front,
-- and the nostrils under the snout, recessed.
for _, side in { -1, 1 } do
	local socket = L.mesh:select("face", "facing", { 0, side, 0.35 }, 24):filter(function(p)
		return p[1] > 1.66 and p[1] < 1.88 and p[3] > MIDDLE - 0.06 and p[3] < MIDDLE + 0.22
	end)
	if socket:count() > 0 then
		L.mesh:extrude(L.mesh:inset(socket, 0.015, 0), -0.05)
	end
	local nare = L.mesh:select("face", "facing", { 0, 0, -1 }, 50):filter(function(p)
		return p[1] > 2.1 and p[1] < 2.17 and p[2] * side > 0.02 and p[2] * side < 0.08
	end)
	if nare:count() > 0 then
		Kit.recess(L.mesh, nare, 0.008, 0.02)
	end
end
-- The roof of the mouth, the plane the jaw splits off along: the rim's
-- height at the corners, a touch up.
local ROOF = L.skin(CORNER.x + 0.001, 150)[3] + 0.03
local GAPE = 14 -- degrees the jaw hangs open: a grin, the teeth showing

-- The skin under the plates: dark steel, showing in the seams.
part("Body", nil, { 0.18, 0.19, 0.21 }, function(mesh)
	Scrap.skinPart(L, { drop = { "belly", "mouth" } }):emit(mesh)
end, true, 0.4)
part("Belly", nil, { 0.3, 0.3, 0.3 }, function(mesh)
	Scrap.skinPart(L, { keep = "belly", drop = { "mouth" } }):emit(mesh)
end, true, 0.3)

-- Fins: the first dorsal over the back's high point, a small second
-- dorsal near the tail, the tail with a long upper lobe and a shorter
-- lower one; each sheet metal in pieces over a dark core.
part("Fins", nil, { 0.18, 0.19, 0.21 }, function(mesh)
	Scrap.metalFin({ { 0.95, -0.15 }, { 0.6, 0.4 }, { 0.2, 0.9 }, { 0.05, 0.98 }, { 0.12, 0.6 }, { 0.2, 0.25 }, { 0.1, -0.15 } }, 0.14, 0.98, { 0.3, 0.62 }, function(m)
		return m:translate(0, 0, MIDDLE + 0.46)
	end, 1):emit(mesh)
	Scrap.metalFin({ { 0.25, -0.1 }, { 0.08, 0.16 }, { -0.02, 0.2 }, { 0.0, 0.06 }, { -0.06, -0.1 } }, 0.08, 0.2, {}, function(m)
		return m:translate(-0.95, 0, MIDDLE + 0.22)
	end, 4):emit(mesh)
	Scrap.metalFin({ { 0.12, 0.12 }, { -0.55, 1.0 }, { -0.75, 1.08 }, { -0.5, 0.4 }, { -0.32, 0.12 }, { -0.5, -0.38 }, { -0.62, -0.55 }, { -0.1, -0.16 }, { 0.12, -0.1 } }, 0.12, 1.08, { -0.2, 0.3, 0.7 }, function(m)
		m:transform(function(p)
			-- Thinning the lower lobe too, which the span rule leaves.
			local down = math.clamp(-p[3] / 0.55, 0, 1)
			return { p[1], p[2] * math.max(0.15, 1 - 0.85 * down), p[3] }
		end)
		return m:translate(-1.62, 0, MIDDLE + 0.01)
	end, 2):emit(mesh)
end, 40, 0.35)
part("ShodFins", nil, { 0.18, 0.19, 0.21 }, function(mesh)
	-- The pectorals and the fin under the tail, turned down to the ground,
	-- narrowing fast in the lower half so only a slim tip goes into the
	-- sneaker's collar.
	for n, f in SHOD do
		local c = f.chord / 2
		local out = (90 - f.down) * (if f.side == 0 then 1 else f.side)
		Scrap.metalFin({ { c, -0.12 }, { c * 0.34, f.span * 0.5 }, { c * 0.15, f.span }, { -c * 0.15, f.span }, { -c * 0.4, f.span * 0.45 }, { -c, -0.12 } }, 0.12, f.span, { f.span * 0.42 }, function(m)
			Kit.turn(m, "x", 180)
			Kit.turn(m, "x", out)
			Kit.turn(m, "y", f.back)
			return m:translate(f.root[1], f.root[2], MIDDLE + f.root[3])
		end, 2 + n):emit(mesh)
	end
end, 40, 0.4)

-- The sneakers, each collar where its fin's axis crosses collar height.
local collars = {}
for _, f in SHOD do
	table.insert(collars, Scrap.collarCrossing(finTurn(f, { 0, 0, f.span }), finTurn(f, { 0, 0, f.span - 0.5 })))
end
Scrap.sneakers(collars)

-- The mouth's rim, walked from one corner (t = -1) round the front (0) to
-- the other (1), on the skin; out lifts it off.
local function rimPoint(t, out)
	local a = math.rad(t * 90)
	local x = CORNER.x + MOUTH_REACH * math.abs(math.cos(a)) ^ 0.8
	local p = L.skin(x, (if t < 0 then -1 else 1) * 150)
	return { p[1], p[2], p[3] + (out or 0) }
end
-- Places a piece built round the mouth onto the hanging jaw: turned open
-- about the hinge line through the corners.
local function onJaw(m)
	m:translate(-CORNER.x, 0, -ROOF)
	Kit.turn(m, "y", GAPE)
	return m:translate(CORNER.x, 0, ROOF)
end
-- The lower jaw: the head's bottom slice under the mouth's rim, rings of
-- the skin between the rim's sides, flat across the top at the roof.
local function jaw()
	local m = EditMesh.new()
	local rings = {}
	for i = 0, 16 do
		local t = 1 - i / 16
		local a = math.rad(t * 90)
		local x = CORNER.x + MOUTH_REACH * math.cos(a) ^ 0.8
		if i == 16 then
			x = CORNER.x + MOUTH_REACH - 0.02
		end
		local ring = {}
		for k = 0, 12 do
			local n = 150 + 60 * k / 12
			local p = L.skin(x, if n <= 180 then n else n - 360)
			table.insert(ring, m:addVertex(p[1], p[2], math.min(p[3], ROOF - 0.012)))
		end
		for k = 11, 1, -1 do
			local n = 150 + 60 * k / 12
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
part("Jaw", nil, BELLY, function(mesh)
	onJaw(jaw()):emit(mesh)
end, true, 0.25)
part("Mouth", nil, { 0.3, 0.07, 0.09 }, function(mesh)
	-- The roof of the mouth, a plate across the hole in the skin at the
	-- roof plane, and the jaw's top in the same dark red.
	local outline = {}
	for k = 0, 24 do
		local p = rimPoint(-1 + k / 12)
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
-- Googly eyes on the sockets.
local eyes = {}
for _, side in { -1, 1 } do
	local p, n = L.normal(1.77, side * 72)
	table.insert(eyes, { p, n })
end
Scrap.googlyEyes(eyes)
part("Lips", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	-- Dark rubber beading round the mouth's rim above, and along the jaw's
	-- edge below: the grin stands out dark against the enamel head, the
	-- white teeth between.
	local path = {}
	for k = 0, 24 do
		table.insert(path, rimPoint(-1 + k / 12, 0.02))
	end
	Kit.tube(path, 0.036, 8):emit(mesh)
	local lower = {}
	for k = 0, 24 do
		local q = rimPoint(-1 + k / 12)
		table.insert(lower, { q[1] * 0.985 + CORNER.x * 0.015, q[2] * 0.95, ROOF - 0.03 })
	end
	onJaw(Kit.tube(lower, 0.03, 8)):emit(mesh)
end, true, 0.1)
part("NostrilPits", nil, { 0.05, 0.05, 0.06 }, function(mesh)
	for _, side in { -1, 1 } do
		local o = L.on(2.1, side * 165, 0.03)
		local pit = EditMesh.sphere(0.03, 6)
		Kit.size(pit, { 1.4, 1, 0.6 })
		pit:translate(o[1], o[2], o[3])
		pit:emit(mesh)
	end
end, true, 0)
-- A tooth: a flat triangle standing up from the origin, facing +-y, its
-- point up; turned to face along its rim.
local function tooth(wide, tall, facing)
	local m = Kit.plate({ { -wide / 2, 0 }, { wide / 2, 0 }, { 0, tall } }, 0.025)
	m:translate(0, -0.0125, 0)
	Kit.turn(m, "z", facing)
	return m
end
local function rimFacing(t)
	local p, q = rimPoint(t - 0.02), rimPoint(t + 0.02)
	return math.deg(math.atan2(q[2] - p[2], q[1] - p[1]))
end
part("Teeth", nil, { 0.97, 0.97, 0.93 }, function(mesh)
	-- Hanging from the upper rim, a second smaller row behind; standing
	-- along the jaw's edge.
	for k = 1, 17 do
		local t = -1 + k / 9
		local p = rimPoint(t)
		local tip = tooth(0.065, 0.13, rimFacing(t))
		Kit.turn(tip, "y", 180)
		tip:translate(p[1] - 0.02, p[2] * 0.92, p[3] + 0.015)
		tip:emit(mesh)
	end
	for k = 1, 16 do
		local t = -1 + (k - 0.5) / 9 + 1 / 18
		local p = rimPoint(t)
		local tip = tooth(0.05, 0.1, rimFacing(t))
		Kit.turn(tip, "y", 180)
		tip:translate(p[1] - 0.06, p[2] * 0.82, ROOF - 0.004)
		tip:emit(mesh)
	end
	for k = 1, 17 do
		local t = -1 + k / 9
		local p = rimPoint(t)
		local tip = tooth(0.06, 0.12, rimFacing(t))
		tip:translate(p[1] - 0.015, p[2] * 0.9, ROOF - 0.015)
		onJaw(tip):emit(mesh)
	end
end, 40, 0)

-- The plating: bands round the section with cuts of very different
-- lengths, some cells split, darker metals over the back and pale ones
-- under the belly; the head plainer, gunmetal above and enamel below, so
-- the face reads; openings for the eyes and the mouth.
local panels = Scrap.panels(L, {
	bands = {
		{ 0, 32, { -1.7, -1.3, -0.2, 0.1, 1.2, 1.45, 2.05, 2.3 } },
		{ 32, 65, { -1.7, -0.75, -0.5, 0.65, 0.9, 1.75, 2.3 } },
		{ 65, 80, { -1.7, -1.4, -0.3, 0.95, 1.25, 1.6, 1.9, 2.3 } },
		{ 80, 118, { -1.7, -0.95, 0.15, 0.4, 1.3, 1.6, 2.3 } },
		{ 118, 150, { -1.7, -1.45, -0.55, 0.0, 0.25, 1.15, 1.55, 2.3 } },
		{ 150, 180, { -1.7, -0.6, -0.35, 0.85, 1.5, 2.1, 2.3 } },
	},
	paleFrom = 80,
	splits = { [3] = 0.45, [7] = 0.6, [12] = 0.35, [18] = 0.55, [23] = 0.4, [29] = 0.65, [34] = 0.5, [40] = 0.3 },
	noSplitFrom = 1.45,
	open = function(band, x0, x1)
		return (band == 3 and x0 < 1.9 and x1 > 1.6) or (band == 6 and x1 > 1.5 and x0 < 2.1)
	end,
	metal = function(_, _, _, _, x0, _, pale)
		if x0 >= 1.45 then
			return if pale then Scrap.BELLY_METALS[3] else Scrap.BACK_METALS[4]
		end
		return nil
	end,
})
Scrap.panelParts(L, panels, { rivetsUpTo = 1.95 })
finishParts()
