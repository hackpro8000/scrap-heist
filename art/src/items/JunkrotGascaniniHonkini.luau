-- Gascanini Honkini: Bombombini Gusini beaten out of scrap. After the
-- picture: a Canada goose built like a warplane. A long torpedo body,
-- plump in the breast, a neck as long as the body rising in an S to a
-- small head: the head dark with the white cheek patch, the bill black
-- with its yellow ridge, worked into the head mesh; huge swept wings,
-- sheet metal in pieces, with the jet engines slung under them on pylons
-- near the root (here: gas cans with nozzles), a vertical tail fin and a
-- short tail fan, and the bomb under the breast, which it sits on. No
-- legs show in the picture, so none: it rests on its belly and bomb.
-- Googly eyes. 4 studs tall.
-- include: JunkrotScrap
local MID = 0.78 -- the body's axis: it sits low, belly on the bomb
local DARK = { 0.18, 0.19, 0.21 }
local HEAD = { 1.5, 0, 3.5 } -- the head's loft origin
local DIHEDRAL = 38 -- degrees the wings rise
local WING = { x = -0.15, y = 0.4, z = MID + 0.3 } -- the wing roots
local SPAN = 1.45
local ENAMEL = { 0.86, 0.86, 0.82 }
local YELLOW = { 0.95, 0.75, 0.15 }

-- A polyline measured along: at(s) -> point and unit tangent s studs in.
local function along(points)
	local len = { 0 }
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		len[i] = len[i - 1] + math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
	end
	local total = len[#len]
	local function point(s)
		s = math.clamp(s, 0, total)
		for i = 2, #points do
			if s <= len[i] then
				local a, b = points[i - 1], points[i]
				local t = (s - len[i - 1]) / (len[i] - len[i - 1])
				return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
			end
		end
		return points[#points]
	end
	local function at(s)
		local p, q = point(s - 0.03), point(s + 0.03)
		local d = { q[1] - p[1], q[2] - p[2], q[3] - p[3] }
		local l = math.sqrt(d[1] ^ 2 + d[2] ^ 2 + d[3] ^ 2)
		return point(s), { d[1] / l, d[2] / l, d[3] / l }
	end
	return at, total
end

-- A small piece stood along a normal: turned from z up to n and set at p.
local function stood(piece, p, n)
	Kit.turn(piece, "y", math.deg(math.acos(math.clamp(n[3], -1, 1))))
	Kit.turn(piece, "z", math.deg(math.atan2(n[2], n[1])))
	return piece:translate(p[1], p[2], p[3])
end

-- A plate following a loft's skin: its faces between x0 and x1 along and
-- a0 to a1 round (degrees from the top; side -1, 1 or nil for both),
-- lifted off and given thickness.
local function skinCell(loft, x0, x1, a0, a1, lift, thick, side)
	local m = loft.mesh:copy()
	local drop = m:select("face", "where", function(p)
		local x = p[1] - loft.at[1]
		local top, bottom = loft.station(x)
		local y, z = p[2] - loft.at[2], p[3] - loft.at[3] - (top + bottom) / 2
		local a = math.deg(math.atan2(math.abs(y), z))
		local ok = x >= x0 and x <= x1 and a >= a0 and a <= a1 and (side == nil or y * side > 0)
		return not ok
	end)
	for _, id in drop:list() do
		m:removeFace(id)
	end
	m:push(m:select("vertex", "all"), lift)
	m:solidify(thick or 0.03)
	return m
end

-- The neck: lofted straight along x, then bent along its curve, up from
-- inside the breast, leaning forward, in an S to the back of the head.
local NECK_PATH = Kit.curve({ { 0.4, 0, MID - 0.1 }, { 0.7, 0, MID + 0.2 }, { 1.05, 0, 1.75 }, { 1.1, 0, 2.35 }, { 1.0, 0, 2.9 }, { 1.1, 0, 3.25 }, { 1.36, 0, 3.42 } }, 8)
local neckAt, NECK_LEN = along(NECK_PATH)
-- Straight-frame point (x along, y to the side, z toward the front) to
-- the model: z goes to the curve's forward normal, y to its side.
local function bend(p)
	local c, t = neckAt(p[1])
	local f = { 1, 0, 0 }
	local d = f[1] * t[1] + f[2] * t[2] + f[3] * t[3]
	local n = { f[1] - t[1] * d, f[2] - t[2] * d, f[3] - t[3] * d }
	local l = math.sqrt(n[1] ^ 2 + n[2] ^ 2 + n[3] ^ 2)
	n = { n[1] / l, n[2] / l, n[3] / l }
	local b = { n[2] * t[3] - n[3] * t[2], n[3] * t[1] - n[1] * t[3], n[1] * t[2] - n[2] * t[1] }
	return { c[1] + n[1] * p[3] + b[1] * p[2], c[2] + n[2] * p[3] + b[2] * p[2], c[3] + n[3] * p[3] + b[3] * p[2] }
end
local NECK = Scrap.loft({
	stations = {
		{ 0, 0.36, -0.36, 0.36 },
		{ 0.35, 0.3, -0.3, 0.3 },
		{ 0.8, 0.22, -0.22, 0.22 },
		{ 1.6, 0.18, -0.18, 0.18 },
		{ NECK_LEN, 0.17, -0.17, 0.17 },
	},
	sides = 20,
	steps = 48,
})

-- The body: a torpedo along x, deepest and widest a little ahead of the
-- middle, the breast plump and rounded off ahead, the tail end drawn up
-- to a point behind.
local L = Scrap.loft({
	stations = { -- x, top, bottom, half width
		{ -1.45, 0.14, 0.0, 0.05 },
		{ -1.2, 0.24, -0.1, 0.17 },
		{ -0.8, 0.4, -0.28, 0.33 },
		{ -0.3, 0.52, -0.44, 0.47 },
		{ 0.2, 0.55, -0.5, 0.52 },
		{ 0.6, 0.5, -0.46, 0.48 },
		{ 0.9, 0.38, -0.34, 0.36 },
		{ 1.05, 0.22, -0.16, 0.18 },
		{ 1.1, 0.08, -0.04, 0.05 },
	},
	at = { 0, 0, MID },
})

-- The head: a small loft, the bill a straight taper from its front, deep
-- at the base, flattened toward a rounded tip; tagged for its own metal.
local H = Scrap.loft({
	stations = {
		{ -0.34, 0.08, -0.05, 0.06 },
		{ -0.24, 0.2, -0.18, 0.18 },
		{ -0.02, 0.27, -0.25, 0.23 },
		{ 0.14, 0.25, -0.23, 0.21 },
		{ 0.28, 0.15, -0.14, 0.14 },
		{ 0.66, 0.02, -0.05, 0.07 },
		{ 0.7, -0.01, -0.04, 0.03 },
	},
	straightFrom = 0.28,
	at = HEAD,
	sides = 20,
	steps = 50,
})
local BILL = 0.285
H.mesh:select("face", "where", function(p)
	return p[1] > HEAD[1] + BILL
end):tag("beak")

-- The skin under the plates: dark steel, showing in the seams.
part("Body", nil, DARK, function(mesh)
	L.mesh:copy():emit(mesh)
	local neck = NECK.mesh:copy()
	neck:transform(bend)
	neck:emit(mesh)
	Scrap.skinPart(H, { drop = { "beak" } }):emit(mesh)
end, true, 0.4)
part("Bill", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	Scrap.skinPart(H, { keep = "beak" }, 0.04):emit(mesh)
end, true, 0.2)
part("BillRidge", nil, YELLOW, function(mesh)
	skinCell(H, BILL + 0.02, 0.62, 0, 20, 0.035, 0.02):emit(mesh)
end, true, 0.2)

-- The neck's plates: rings of mismatched dark metal along it, a gap of
-- dark core between, some rings split down the sides; the head's plates
-- in the same metals, dark over the crown and down the back, enamel for
-- the white cheek patch that runs under the chin.
local NECK_METALS = {
	{ "Gunmetal", { 0.3, 0.33, 0.37 } },
	{ "Bluegrey", { 0.4, 0.47, 0.52 } },
	{ "Slate", { 0.26, 0.28, 0.3 } },
	{ "Painted", { 0.36, 0.5, 0.62 } },
}
local rings = {}
do
	local x, k = 0.2, 0
	while x < NECK_LEN - 0.08 do
		local len = if k % 3 == 1 then 0.22 else 0.32
		local x1 = math.min(x + len, NECK_LEN - 0.02)
		if k % 4 == 2 then
			table.insert(rings, { x, x1, -1, k })
			table.insert(rings, { x, x1, 1, k + 1 })
		else
			table.insert(rings, { x, x1, nil, k })
		end
		x, k = x1 + 0.03, k + 1
	end
end
for n, metal in NECK_METALS do
	part("Neck" .. metal[1], nil, metal[2], function(mesh)
		for _, r in rings do
			if r[4] % #NECK_METALS + 1 == n then
				local piece = skinCell(NECK, r[1], r[2], 0, 180, 0.035, 0.03, r[3])
				piece:transform(bend)
				piece:emit(mesh)
			end
		end
		if n == 1 then
			skinCell(H, -0.34, -0.1, 0, 180, 0.035, 0.03):emit(mesh)
			skinCell(H, -0.08, BILL - 0.01, 0, 60, 0.035, 0.03, 1):emit(mesh)
		elseif n == 3 then
			skinCell(H, -0.08, BILL - 0.01, 0, 60, 0.035, 0.03, -1):emit(mesh)
		end
	end, true, 0.45)
end
part("HeadEnamel", nil, ENAMEL, function(mesh)
	skinCell(H, -0.08, BILL - 0.01, 62, 180, 0.035, 0.03):emit(mesh)
end, true, 0.3)

-- Wings: huge, swept back, spread and raised; sheet metal in three
-- pieces out from the root, the trailing edge scalloped into feathers.
local WING_OUTLINE = { { 0.5, 0 }, { 0.42, 0.4 }, { 0.26, 0.9 }, { 0.0, 1.38 }, { -0.3, 1.45 }, { -0.42, 1.26 }, { -0.58, 1.32 }, { -0.68, 1.06 }, { -0.83, 1.1 }, { -0.87, 0.82 }, { -0.77, 0.45 }, { -0.6, 0.08 }, { -0.5, 0 } }
local function placeWing(side)
	return function(m)
		Kit.turn(m, "x", -90 * side)
		Kit.turn(m, "x", DIHEDRAL * side)
		return m:translate(WING.x, WING.y * side, WING.z)
	end
end
-- Where a wing's mid plane is at span s and chord x: for the pylons.
local function wingAt(side, s, chord)
	local p = { chord, 0, s }
	for _, deg in { -90 * side, DIHEDRAL * side } do
		local a = math.rad(deg)
		p = { p[1], p[2] * math.cos(a) - p[3] * math.sin(a), p[2] * math.sin(a) + p[3] * math.cos(a) }
	end
	return { p[1] + WING.x, p[2] + WING.y * side, p[3] + WING.z }
end
part("Wings", nil, DARK, function(mesh)
	for n, side in { -1, 1 } do
		Scrap.metalFin(WING_OUTLINE, 0.13, SPAN, { 0.45, 0.98 }, placeWing(side), n * 2):emit(mesh)
	end
	-- The vertical tail fin, swept back over the tail.
	Scrap.metalFin({ { -0.55, -0.1 }, { -0.95, 0.7 }, { -1.3, 0.76 }, { -1.36, 0.5 }, { -1.3, -0.1 } }, 0.09, 0.76, { 0.35 }, function(m)
		return m:translate(0, 0, MID + 0.2)
	end, 3):emit(mesh)
	-- The tail fan: short feathers straight back, level.
	Scrap.metalFin({ { 0.3, 0 }, { 0.2, 0.55 }, { 0.08, 0.5 }, { 0, 0.58 }, { -0.08, 0.5 }, { -0.2, 0.55 }, { -0.3, 0 } }, 0.07, 0.58, { 0.22 }, function(m)
		Kit.turn(m, "y", -90)
		Kit.turn(m, "x", 90)
		return m:translate(-1.15, 0, MID + 0.08)
	end, 5):emit(mesh)
end, 40, 0.35)

-- The engines: gas cans slung under each wing on pylons, one near the
-- root and one further out, lying along x: the can's handles forward as
-- the intake grille, its spout behind as the nozzle, glowing blue.
local CANS = { { s = 0.42, colour = { 0.38, 0.42, 0.3 }, name = "Olive" }, { s = 1.0, colour = { 0.72, 0.14, 0.1 }, name = "Red" } }
local CAN = { long = 0.5, wide = 0.2, high = 0.34, x = -0.2, drop = 0.33 }
local function canCentre(side, c)
	local w = wingAt(side, c.s, CAN.x)
	return { w[1], w[2], w[3] - CAN.drop }
end
for _, c in CANS do
	part("GasCans" .. c.name, nil, c.colour, function(mesh)
		for _, side in { -1, 1 } do
			local o = canCentre(side, c)
			local can = Kit.block(CAN.long, CAN.wide, CAN.high, 0.03, { 1, 7, 1 })
			-- The X stamped into each side.
			for _, face in { -1, 1 } do
				local sel = can:select("face", "facing", { 0, face, 0 }, 10)
				if sel:count() > 0 then
					Kit.recess(can, sel, 0.04, 0.012)
				end
			end
			-- The handles: three bars out of the forward end, the grille.
			local grille = can:select("face", "facing", { 1, 0, 0 }, 5):filter(function(p)
				return math.abs(math.abs(p[2]) - 0.04) < 0.006 or math.abs(p[2]) < 0.006
			end)
			if grille:count() > 0 then
				can:extrude(grille, 0.05)
			end
			can:translate(o[1], o[2], o[3])
			can:emit(mesh)
			-- The spout: a short cone back out of the can, the nozzle.
			local spout = EditMesh.cone(0.1, 0.075, 0.12, 12, 1)
			Kit.turn(spout, "y", -90)
			spout:translate(o[1] - CAN.long / 2 - 0.05, o[2], o[3] + 0.04)
			spout:emit(mesh)
		end
	end, 40, 0.35)
end
part("Pylons", nil, { 0.32, 0.34, 0.36 }, function(mesh)
	for _, c in CANS do
		for _, side in { -1, 1 } do
			local o = canCentre(side, c)
			local tall = CAN.drop - CAN.high / 2 + 0.01
			local pylon = Kit.block(0.47, 0.08, tall, 0.015)
			pylon:translate(o[1], o[2], o[3] + CAN.drop - tall / 2)
			pylon:emit(mesh)
		end
	end
	-- And the bomb's two shackles under the belly.
	for _, x in { 0.25, 0.8 } do
		local shackle = Kit.block(0.12, 0.1, 0.22, 0.015)
		shackle:translate(x, 0, 0.36)
		shackle:emit(mesh)
	end
end, 40, 0.4)
part("Jets", nil, { 0.5, 0.8, 1.0 }, function(mesh)
	for _, c in CANS do
		for _, side in { -1, 1 } do
			local o = canCentre(side, c)
			local glow = EditMesh.cylinder(0.065, 0.03, 12, 1)
			Kit.turn(glow, "y", 90)
			glow:translate(o[1] - CAN.long / 2 - 0.1, o[2], o[3] + 0.04)
			glow:emit(mesh)
		end
	end
end, true, 0, nil, 1.8)

-- The bomb under the breast, nose forward past it, four small fins at
-- the tail; the goose sits on it.
part("Bomb", nil, { 0.33, 0.36, 0.3 }, function(mesh)
	local bomb = Kit.lathe({ { 0, 0 }, { 0.05, 0.03 }, { 0.12, 0.18 }, { 0.165, 0.42 }, { 0.17, 1.0 }, { 0.14, 1.2 }, { 0.09, 1.34 }, { 0.06, 1.42 }, { 0, 1.44 } }, 16)
	Kit.turn(bomb, "y", -90)
	bomb:translate(1.15, 0, 0.17)
	bomb:emit(mesh)
	for k = 0, 3 do
		local fin = Kit.plate({ { -1.4, 0.04 }, { -1.08, 0.1 }, { -1.1, 0.22 }, { -1.36, 0.24 } }, 0.02)
		fin:translate(0, -0.01, 0)
		Kit.turn(fin, "x", 45 + 90 * k)
		fin:translate(1.15, 0, 0.17)
		fin:emit(mesh)
	end
end, true, 0.3)
part("BombNose", nil, YELLOW, function(mesh)
	local band = EditMesh.cylinder(0.14, 0.08, 16, 1)
	Kit.turn(band, "y", 90)
	band:translate(1.15 - 0.3, 0, 0.17)
	band:emit(mesh)
end, true, 0.2)

-- The roundels on the flanks: a dark disc with a white star.
local ROUNDEL = { x = -0.25, a = 72 }
part("Roundels", nil, { 0.1, 0.15, 0.35 }, function(mesh)
	for _, side in { -1, 1 } do
		local p, n = L.normal(ROUNDEL.x, side * ROUNDEL.a)
		stood(EditMesh.cylinder(0.2, 0.016, 20, 1), { p[1] + n[1] * 0.075, p[2] + n[2] * 0.075, p[3] + n[3] * 0.075 }, n):emit(mesh)
	end
end, true, 0.2)
part("Stars", nil, ENAMEL, function(mesh)
	for _, side in { -1, 1 } do
		local p, n = L.normal(ROUNDEL.x, side * ROUNDEL.a)
		for k = 0, 4 do
			local th = math.rad(90 + 72 * k + (if side < 0 then 180 else 0))
			local a, b = th - math.rad(33), th + math.rad(33)
			local kite = Kit.plate({ { math.cos(th) * 0.015, math.sin(th) * 0.015 }, { math.cos(a) * 0.065, math.sin(a) * 0.065 }, { math.cos(th) * 0.165, math.sin(th) * 0.165 }, { math.cos(b) * 0.065, math.sin(b) * 0.065 } }, 0.014)
			Kit.turn(kite, "x", 90)
			stood(kite, { p[1] + n[1] * 0.085, p[2] + n[2] * 0.085, p[3] + n[3] * 0.085 }, n):emit(mesh)
		end
	end
end, true, 0.1)

-- Googly eyes, in the dark of the head just above the cheek patch.
local eyes = {}
for _, side in { -1, 1 } do
	local p, n = H.normal(0.08, side * 58)
	table.insert(eyes, { p, n })
end
Scrap.googlyEyes(eyes, 0.085)

-- The plating over the body: dark metals over the back, pale under.
local panels = Scrap.panels(L, {
	bands = {
		{ 0, 35, { -1.45, -1.1, -0.2, 0.1, 0.8, 1.1 } },
		{ 35, 70, { -1.45, -0.7, -0.45, 0.5, 1.1 } },
		{ 70, 95, { -1.45, -1.2, -0.15, 0.7, 0.95, 1.1 } },
		{ 95, 125, { -1.45, -0.9, 0.15, 0.4, 1.1 } },
		{ 125, 155, { -1.45, -1.3, -0.5, 0.0, 0.9, 1.1 } },
		{ 155, 180, { -1.45, -0.6, 0.6, 1.1 } },
	},
	paleFrom = 95,
	splits = { [3] = 0.45, [7] = 0.6, [12] = 0.35, [18] = 0.55, [23] = 0.4, [29] = 0.65 },
})
Scrap.panelParts(L, panels, {})
finishParts()
