-- Trashalero Trashala: Tralalero Tralala riveted from tin sheet. A
-- grey-blue shark with a white belly, nose forward (+x), in blue sneakers
-- on its three bottom fins, the two pectorals and the fin under its tail,
-- so it sits low on them. Built after the picture: a slim torpedo body, a smooth conical
-- snout, the back sloping down to it over a flat belly line. No googly
-- face.
-- include: JunkrotKit
local TIN_BLUE = { 0.4, 0.5, 0.6 }
local BELLY = { 0.88, 0.89, 0.86 }
local MIDDLE = 1.3 -- the body's axis: it sits low, on its fins
local SNEAKER_BLUE = { 0.14, 0.46, 0.92 }
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
local function shodTip(f)
	return finTurn(f, { 0, 0, f.span })
end
-- The body's lines along x, tail root to nose tip: the back's height, the
-- belly's depth and the half width, read off these stations between;
-- eased, except along the snout, which runs straight to its rounded tip.
-- The back arches over a belly that runs nearly level, and the snout
-- tapers to a point a little below the axis.
local STATIONS = { -- x, top, bottom, half width
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
}
local SNOUT = 1.4
local function station(x)
	local function mix(a, b, t)
		return { a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t }
	end
	for k = 1, #STATIONS - 1 do
		local a, b = STATIONS[k], STATIONS[k + 1]
		if x <= b[1] then
			local t = math.clamp((x - a[1]) / (b[1] - a[1]), 0, 1)
			if a[1] < SNOUT then
				t = t * t * (3 - 2 * t)
			end
			return table.unpack(mix(a, b, t))
		end
	end
	local last = STATIONS[#STATIONS]
	return last[2], last[3], last[4]
end
-- How far up the section the white belly reaches, in degrees from the
-- bottom, along x: to the mid flank at the chest, lower toward the tail
-- root, and nearly to the eye on the head.
local REACH = { { -1.7, 25 }, { -1.0, 55 }, { -0.3, 85 }, { 0.5, 100 }, { 1.3, 100 }, { 2.0, 102 }, { 2.3, 95 } }
local function reach(x)
	for k = 1, #REACH - 1 do
		local a, b = REACH[k], REACH[k + 1]
		if x <= b[1] then
			local t = math.clamp((x - a[1]) / (b[1] - a[1]), 0, 1)
			return a[2] + (b[2] - a[2]) * (t * t * (3 - 2 * t))
		end
	end
	return REACH[#REACH][2]
end
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
-- A point of the skin: x along, a the ring's nominal angle round the
-- section (0 at the top, 180 at the bottom, either sign for the side),
-- from the body's axis. The ring's spacing is warped so that its vertex at
-- nominal 90 sits exactly on the belly line, whatever the reach there, and
-- the one at nominal 150 on the mouth's rim where there is one: the
-- splits along both then follow true edge loops.
local function skin(x, a)
	local top, bottom, w = station(x)
	local side = if a < 0 then -1 else 1
	local n = math.abs(a)
	local line = 180 - reach(x)
	local rim = mouthAngle(x) or (line + 150 / 180 * (180 - line) - line) -- without a mouth, 150 stays in its natural place
	if not mouthAngle(x) then
		rim = line + (150 - 90) / 90 * (180 - line)
	end
	local actual
	if n <= 90 then
		actual = n / 90 * line
	elseif n <= 150 then
		actual = line + (n - 90) / 60 * (rim - line)
	else
		actual = rim + (n - 150) / 30 * (180 - rim)
	end
	local r = math.rad(actual)
	local c = math.cos(r)
	local mid = (top + bottom) / 2
	return { x, side * math.sin(r) * w, mid + c * (if c > 0 then top - mid else mid - bottom) }
end
local function skinZ(x, a) -- from the axis, in the model's frame
	return skin(x, a)[3]
end
-- The roof of the mouth, the plane the jaw splits off along: the rim's
-- height at the corners, a touch up.
local ROOF = skinZ(CORNER.x + 0.001, 150) + 0.03
local GAPE = 14 -- degrees the jaw hangs open: a grin, the teeth showing

local function shark()
	local ring, path = {}, {}
	for k = 0, 23 do
		local r = math.rad(k * 15)
		table.insert(ring, { -math.sin(r), math.cos(r) })
	end
	for k = 0, 80 do
		table.insert(path, { -1.7 + 4.0 * k / 80, 0, 0 })
	end
	local m = EditMesh.sweep(ring, path)
	-- The belly's faces: those below the ring's equator, picked on the bare
	-- tube so the split is exactly along its vertex row.
	m:tagging("belly", function()
		m:select("face", "where", function(p)
			return p[3] < 0 and p[1] > -1.69 and p[1] < 2.29
		end):tag("belly")
	end)
	-- The mouth's faces: below the ring's vertex at nominal 150, between the
	-- corners and the front, picked on the bare tube too.
	m:tagging("mouth", function()
		m:select("face", "where", function(p)
			return p[3] < math.cos(math.rad(150)) and mouthAngle(p[1]) ~= nil and mouthAngle(p[1] - 0.025) ~= nil and mouthAngle(p[1] + 0.025) ~= nil
		end):tag("mouth")
	end)
	m:transform(function(p)
		local a = math.deg(math.atan2(p[2], p[3]))
		return skin(p[1], a)
	end)
	-- Eye sockets, sunk into the sides of the head over the mouth's front.
	for _, side in { -1, 1 } do
		local socket = m:select("face", "facing", { 0, side, 0.35 }, 24):filter(function(p)
			return p[1] > 1.7 and p[1] < 1.85 and p[3] > -0.05 and p[3] < 0.2
		end)
		if socket:count() > 0 then
			m:extrude(m:inset(socket, 0.015, 0), -0.04)
		end
	end
	-- The nostrils under the snout, recessed.
	for _, side in { -1, 1 } do
		local nare = m:select("face", "facing", { 0, 0, -1 }, 50):filter(function(p)
			return p[1] > 2.1 and p[1] < 2.17 and p[2] * side > 0.02 and p[2] * side < 0.08
		end)
		if nare:count() > 0 then
			Kit.recess(m, nare, 0.008, 0.02)
		end
	end
	m:translate(0, 0, MIDDLE)
	return m
end
local body = shark()
-- The belly line: the skin is split along it into the white belly and the
-- grey-blue back, each given its own thickness inward.
local function skinPart(m, belly)
	local keep = m:select("face", "tag", "belly")
	if not belly then
		keep = m:select("face", "all"):minus(keep)
	end
	keep = keep:minus(m:select("face", "tag", "mouth"))
	for _, id in m:select("face", "all"):minus(keep):list() do
		m:removeFace(id)
	end
	m:solidify(0.03)
	return m
end

part("Body", nil, TIN_BLUE, function(mesh)
	skinPart(body:copy(), false):emit(mesh)
end, true, 0.35)
part("Belly", nil, BELLY, function(mesh)
	skinPart(body:copy(), true):emit(mesh)
end, true, 0.25)
-- A fin from its outline in x (along the body) and z (out from the root
-- at 0), thick at the root and thinning toward its edges and tip.
local function fin(outline, thick, span)
	local m = Kit.plate(outline, thick)
	m:translate(0, -thick / 2, 0)
	-- How far from the root, and how near an edge, each point is.
	m:transform(function(p)
		local out = math.clamp(p[3] / span, 0, 1)
		return { p[1], p[2] * math.max(0.12, 1 - 0.85 * out), p[3] }
	end)
	return m
end
part("Fins", nil, TIN_BLUE, function(mesh)
	-- The first dorsal, over the back's high point: a straight leading edge
	-- raked back to the tip, a concave trailing edge down to a free tip.
	local dorsal = fin({ { 0.95, -0.15 }, { 0.6, 0.4 }, { 0.2, 0.9 }, { 0.05, 0.98 }, { 0.12, 0.6 }, { 0.2, 0.25 }, { 0.1, -0.15 } }, 0.14, 0.98)
	dorsal:translate(0, 0, MIDDLE + 0.46)
	dorsal:emit(mesh)
	-- The second dorsal, small, near the tail.
	local second = fin({ { 0.25, -0.1 }, { 0.08, 0.16 }, { -0.02, 0.2 }, { 0.0, 0.06 }, { -0.06, -0.1 } }, 0.08, 0.2)
	second:translate(-0.95, 0, MIDDLE + 0.22)
	second:emit(mesh)
	-- The tail: a long upper lobe sweeping up and back, a shorter lower
	-- one, both from the tail root.
	local tail = fin({ { 0.12, 0.12 }, { -0.55, 1.0 }, { -0.75, 1.08 }, { -0.5, 0.4 }, { -0.32, 0.12 }, { -0.5, -0.38 }, { -0.62, -0.55 }, { -0.1, -0.16 }, { 0.12, -0.1 } }, 0.12, 1.08)
	tail:transform(function(p)
		-- Thinning the lower lobe too, which the span rule above leaves.
		local down = math.clamp(-p[3] / 0.55, 0, 1)
		return { p[1], p[2] * math.max(0.15, 1 - 0.85 * down), p[3] }
	end)
	tail:translate(-1.62, 0, MIDDLE + 0.01)
	tail:emit(mesh)
end, 40, 0.35)
part("ShodFins", nil, TIN_BLUE, function(mesh)
	-- The pectorals and the fin under the tail, from fin outlines like the
	-- rest, turned down to the ground.
	for _, f in SHOD do
		local c = f.chord / 2
		-- Narrowing fast in the lower half, so only a slim tip goes into the
		-- sneaker's collar.
		local m = fin({ { c, -0.12 }, { c * 0.42, f.span * 0.5 }, { c * 0.18, f.span }, { -c * 0.18, f.span }, { -c * 0.5, f.span * 0.45 }, { -c, -0.12 } }, 0.12, f.span)
		local out = (90 - f.down) * (if f.side == 0 then 1 else f.side)
		Kit.turn(m, "x", 180)
		Kit.turn(m, "x", out)
		Kit.turn(m, "y", f.back)
		m:translate(f.root[1], f.root[2], MIDDLE + f.root[3])
		m:emit(mesh)
	end
end, 40, 0.35)
-- Each sneaker stands on the ground with its collar over its fin's tip:
-- the shoe's own origin is the middle of its sole, the collar sits back
-- from it. Kit.shoe's proportions: toe +x, collar over the heel third.
local SHOE = { long = 1.05, wide = 0.56, high = 0.38 }
local function shoeAt(f)
	local tip = shodTip(f)
	return { tip[1] + SHOE.long * 0.32, tip[2] }
end
local SOLE = 0.14 -- the sole's height: outsole and midsole
-- The upper's top at x from the shoe's middle: level over the instep,
-- sloping down over the toe.
local function instep(x)
	local hx = SHOE.long / 2
	local toe = math.clamp((x - hx * 0.25) / (hx * 0.75), 0, 1)
	return SOLE - 0.04 + SHOE.high * (1 - 0.45 * toe)
end
part("Sneakers", nil, SNEAKER_BLUE, function(mesh)
	for _, f in SHOD do
		local at = shoeAt(f)
		local shoe = Kit.shoe(SHOE.long, SHOE.wide, SHOE.high)
		shoe:translate(at[1], at[2], SOLE - 0.04)
		shoe:emit(mesh)
		-- The tongue, padded, rising out of the collar's front.
		local tongue = Kit.block(0.18, 0.22, 0.24, 0.05)
		Kit.turn(tongue, "y", 28)
		tongue:translate(at[1] - 0.1, at[2], instep(-0.1) + 0.02)
		tongue:emit(mesh)
	end
end, true, RUBBER)
part("Soles", nil, { 0.95, 0.95, 0.93 }, function(mesh)
	-- The midsole, white, standing a little proud of the upper.
	for _, f in SHOD do
		local at = shoeAt(f)
		local midsole = Kit.block(SHOE.long + 0.05, SHOE.wide + 0.05, 0.1, 0.04)
		midsole:translate(at[1], at[2], 0.09)
		midsole:emit(mesh)
	end
end, 50, RUBBER)
part("Outsoles", nil, { 0.2, 0.2, 0.22 }, function(mesh)
	-- The dark rubber under it, and a toe bumper curling up at the front.
	for _, f in SHOD do
		local at = shoeAt(f)
		local outsole = Kit.block(SHOE.long + 0.04, SHOE.wide + 0.04, 0.05, 0.02)
		outsole:translate(at[1], at[2], 0.025)
		outsole:emit(mesh)
		local bumper = Kit.block(0.1, SHOE.wide * 0.6, 0.08, 0.02)
		bumper:translate(at[1] + SHOE.long / 2 - 0.03, at[2], 0.14)
		bumper:emit(mesh)
	end
end, 50, RUBBER)
part("ShoeTrim", nil, { 0.96, 0.96, 0.94 }, function(mesh)
	for _, f in SHOD do
		local at = shoeAt(f)
		-- Crossed laces between the eyelet rows down the instep.
		local rows = { -0.14, -0.02, 0.1, 0.22 }
		for k = 1, #rows - 1 do
			for _, side in { -1, 1 } do
				Kit.tube({ { at[1] + rows[k], at[2] + side * 0.1, instep(rows[k]) + 0.01 }, { at[1] + rows[k + 1], at[2] - side * 0.1, instep(rows[k + 1]) + 0.01 } }, 0.016, 6):emit(mesh)
			end
		end
		-- A stripe along each side, dipping under the laces.
		for _, side in { -1, 1 } do
			Kit.tube(Kit.curve({ { at[1] - 0.42, at[2] + side * 0.25, 0.28 }, { at[1] - 0.1, at[2] + side * 0.29, 0.19 }, { at[1] + 0.22, at[2] + side * 0.27, 0.16 }, { at[1] + 0.4, at[2] + side * 0.18, 0.2 } }, 4), 0.02, 6):emit(mesh)
		end
		-- The padded collar rim and a heel tab.
		local rim = EditMesh.torus(0.12, 0.03, 16, 6)
		Kit.size(rim, { 1.5, 1, 1 })
		rim:translate(at[1] - SHOE.long * 0.32, at[2], SOLE - 0.04 + SHOE.high)
		rim:emit(mesh)
		Kit.tube(Kit.curve({ { at[1] - 0.5, at[2], SOLE + 0.2 }, { at[1] - 0.55, at[2], SOLE + 0.3 }, { at[1] - 0.5, at[2], SOLE + 0.38 } }, 3), 0.02, 6):emit(mesh)
	end
end, 50, 0)
part("Eyelets", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	for _, f in SHOD do
		local at = shoeAt(f)
		for _, x in { -0.14, -0.02, 0.1, 0.22 } do
			for _, side in { -1, 1 } do
				local eye = EditMesh.cylinder(0.024, 0.012, 8, 1)
				eye:translate(at[1] + x, at[2] + side * 0.1, instep(x) + 0.005)
				eye:emit(mesh)
			end
		end
	end
end, 50, 0)
-- The mouth's rim, walked from one corner (t = -1) round the front (0) to
-- the other (1), on the skin; out lifts it off.
local function rimPoint(t, out)
	local a = math.rad(t * 90)
	local x = CORNER.x + MOUTH_REACH * math.abs(math.cos(a)) ^ 0.8
	local p = skin(x, (if t < 0 then -1 else 1) * 150)
	return { p[1], p[2], p[3] + MIDDLE + (out or 0) }
end
-- Places a piece built round the mouth (from the axis) onto the hanging
-- jaw: turned open about the hinge line through the corners.
local function onJaw(m)
	m:translate(-CORNER.x, 0, -ROOF)
	Kit.turn(m, "y", GAPE)
	return m:translate(CORNER.x, 0, MIDDLE + ROOF)
end
-- The lower jaw: the head's bottom slice under the mouth's rim, rings of
-- the skin between the rim's sides, flat across the top at the roof.
local function jaw()
	local m = EditMesh.new()
	local rings = {}
	for i = 0, 16 do
		local t = 1 - i / 16 -- from the corners forward
		local a = math.rad(t * 90)
		local x = CORNER.x + MOUTH_REACH * math.cos(a) ^ 0.8
		if i == 16 then
			x = CORNER.x + MOUTH_REACH - 0.02
		end
		local ring = {}
		for k = 0, 12 do
			local n = 150 + 60 * k / 12 -- round the bottom from one rim to the other
			local p = skin(x, if n <= 180 then n else n - 360)
			table.insert(ring, m:addVertex(p[1], p[2], math.min(p[3], ROOF - 0.012)))
		end
		for k = 11, 1, -1 do
			local n = 150 + 60 * k / 12
			local p = skin(x, if n <= 180 then n else n - 360)
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
	roof:translate(0, 0, MIDDLE + ROOF - 0.005)
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
part("Eyes", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, side in { -1, 1 } do
		local p = skin(1.77, side * 72)
		local eye = EditMesh.sphere(0.065, 8)
		eye:translate(p[1], p[2] * 0.93, p[3] + MIDDLE)
		eye:emit(mesh)
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
		tip:translate(p[1] - 0.06, p[2] * 0.82, MIDDLE + ROOF - 0.004)
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
-- Scrap panels, as on the Zapper: plates of mismatched metal beaten to the
-- body's curve, each a grid over a patch of the skin between two x's and
-- two nominal angles round the section (minus for the left side, 0 the
-- top, 180 the bottom), lifted a hair off it with its own thickness, and
-- riveted at the corners. They keep clear of the eyes and the mouth.
local PANEL_METALS = {
	GALVANISED = { 0.6, 0.63, 0.62 },
	OLIVE = { 0.42, 0.45, 0.36 },
	BLUE_GREY = { 0.4, 0.47, 0.52 },
	RUST = { 0.55, 0.35, 0.16 },
	BRASS = { 0.7, 0.58, 0.3 },
	TIN = { 0.72, 0.7, 0.66 },
}
local PANELS = {
	{ -0.2, 0.6, 12, 58, "GALVANISED" },
	{ 0.7, 1.3, -12, -56, "OLIVE" },
	{ -1.2, -0.45, 22, 78, "BLUE_GREY" },
	{ 0.05, 0.85, -68, -112, "RUST" },
	{ 1.25, 1.85, 28, 62, "BRASS" },
	{ -0.95, -0.15, -42, -92, "TIN" },
	{ 0.3, 1.05, 98, 142, "GALVANISED" },
	{ -0.55, 0.25, -96, -148, "OLIVE" },
	{ -1.55, -0.95, -8, -52, "RUST" },
	{ 1.4, 2.0, -18, -52, "BLUE_GREY" },
	{ 0.85, 1.35, 62, 98, "OLIVE" },
	{ -0.45, 0.35, -22, 24, "TIN" },
	{ 1.95, 2.25, 10, 48, "RUST" },
	{ -1.3, -0.7, 95, 135, "BRASS" },
}
-- The skin's outward direction at x, a, from neighbouring points.
local function skinNormal(x, a)
	local p = skin(x, a)
	local px, pa = skin(x + 0.01, a), skin(x, a + 0.5)
	local u = { px[1] - p[1], px[2] - p[2], px[3] - p[3] }
	local v = { pa[1] - p[1], pa[2] - p[2], pa[3] - p[3] }
	local n = { u[2] * v[3] - u[3] * v[2], u[3] * v[1] - u[1] * v[3], u[1] * v[2] - u[2] * v[1] }
	local len = math.sqrt(n[1] ^ 2 + n[2] ^ 2 + n[3] ^ 2)
	n = { n[1] / len, n[2] / len, n[3] / len }
	-- Outward: away from the axis.
	local mid = select(1, station(x)) + select(2, station(x))
	local away = { 0, p[2], p[3] - mid / 2 }
	if n[1] * away[1] + n[2] * away[2] + n[3] * away[3] < 0 then
		n = { -n[1], -n[2], -n[3] }
	end
	return p, n
end
local function onSkin(x, a, lift)
	local p, n = skinNormal(x, a)
	return { p[1] + n[1] * lift, p[2] + n[2] * lift, p[3] + n[3] * lift + MIDDLE }
end
local function panel(x0, x1, a0, a1)
	local m = EditMesh.new()
	local ALONG, ROUND = 8, 6
	local top, bottom = {}, {}
	for i = 0, ALONG do
		top[i], bottom[i] = {}, {}
		for j = 0, ROUND do
			local x, a = x0 + (x1 - x0) * i / ALONG, a0 + (a1 - a0) * j / ROUND
			local o, u = onSkin(x, a, 0.035), onSkin(x, a, -0.01)
			top[i][j] = m:addVertex(o[1], o[2], o[3])
			bottom[i][j] = m:addVertex(u[1], u[2], u[3])
		end
	end
	for i = 0, ALONG - 1 do
		for j = 0, ROUND - 1 do
			m:addFace({ top[i][j], top[i + 1][j], top[i + 1][j + 1], top[i][j + 1] })
			m:addFace({ bottom[i][j], bottom[i][j + 1], bottom[i + 1][j + 1], bottom[i + 1][j] })
		end
	end
	for k = 0, ALONG - 1 do
		m:addFace({ top[k][0], bottom[k][0], bottom[k + 1][0], top[k + 1][0] })
		m:addFace({ top[k + 1][ROUND], bottom[k + 1][ROUND], bottom[k][ROUND], top[k][ROUND] })
	end
	for k = 0, ROUND - 1 do
		m:addFace({ top[0][k + 1], bottom[0][k + 1], bottom[0][k], top[0][k] })
		m:addFace({ top[ALONG][k], bottom[ALONG][k], bottom[ALONG][k + 1], top[ALONG][k + 1] })
	end
	-- Consistent winding whichever way round the angles run.
	local o = onSkin((x0 + x1) / 2, (a0 + a1) / 2, 0.1)
	local c = onSkin((x0 + x1) / 2, (a0 + a1) / 2, 0.035)
	local n = m:faceNormal(m:select("face", "all"):list()[1])
	if n[1] * (o[1] - c[1]) + n[2] * (o[2] - c[2]) + n[3] * (o[3] - c[3]) < 0 then
		m:flip()
	end
	return m
end
for metal, colour in PANEL_METALS do
	part("Panels" .. metal, nil, colour, function(mesh)
		for _, q in PANELS do
			if q[5] == metal then
				panel(q[1], q[2], q[3], q[4]):emit(mesh)
			end
		end
	end, 40, if metal == "RUST" then 0.7 elseif metal == "BRASS" then 0.3 else 0.5)
end
part("Rivets", nil, DARK_STEEL, function(mesh)
	-- A dome rivet in each panel's corners, half sunk into it.
	for _, q in PANELS do
		local dx, da = (q[2] - q[1]) * 0.08, (q[4] - q[3]) * 0.1
		for _, x in { q[1] + dx, q[2] - dx } do
			for _, a in { q[3] + da, q[4] - da } do
				local o = onSkin(x, a, 0.035)
				local rivet = EditMesh.sphere(0.03, 6)
				rivet:translate(o[1], o[2], o[3])
				rivet:emit(mesh)
			end
		end
	end
end, true, 0.4)
finishParts()
