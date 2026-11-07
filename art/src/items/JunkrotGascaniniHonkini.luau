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
local HEAD = { 1.4, 0, 3.5 } -- the head's loft origin
local DIHEDRAL = 24 -- degrees the wings rise
local WING = { x = -0.15, y = 0.4, z = MID + 0.22 } -- the wing roots

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

-- The neck: lofted straight along x, then bent along its curve, up from
-- inside the breast in an S to the back of the head.
local NECK_PATH = Kit.curve({ { 0.45, 0, MID - 0.05 }, { 0.6, 0, MID + 0.1 }, { 0.92, 0, MID + 0.62 }, { 1.0, 0, 1.95 }, { 0.9, 0, 2.6 }, { 1.0, 0, 3.1 }, { 1.26, 0, 3.4 } }, 8)
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
	steps = 40,
})

-- The body: a torpedo along x, deepest and widest a little ahead of the
-- middle, the breast plump and rounded off ahead, the tail end drawn up
-- to a point behind.
local L = Scrap.loft({
	stations = { -- x, top, bottom, half width
		{ -1.45, 0.14, 0.0, 0.05 },
		{ -1.2, 0.22, -0.1, 0.16 },
		{ -0.8, 0.36, -0.26, 0.3 },
		{ -0.3, 0.46, -0.4, 0.43 },
		{ 0.2, 0.5, -0.45, 0.48 },
		{ 0.6, 0.47, -0.43, 0.45 },
		{ 0.9, 0.36, -0.32, 0.34 },
		{ 1.05, 0.2, -0.14, 0.17 },
		{ 1.1, 0.08, -0.04, 0.05 },
	},
	at = { 0, 0, MID },
})

-- The head: a small loft, the bill a straight taper from its front,
-- flattened, tagged so it takes its own metal.
local H = Scrap.loft({
	stations = {
		{ -0.32, 0.06, -0.04, 0.05 },
		{ -0.22, 0.17, -0.16, 0.16 },
		{ -0.02, 0.24, -0.22, 0.21 },
		{ 0.14, 0.22, -0.2, 0.19 },
		{ 0.26, 0.13, -0.12, 0.12 },
		{ 0.62, 0.0, -0.05, 0.06 },
		{ 0.66, -0.02, -0.04, 0.03 },
	},
	straightFrom = 0.26,
	at = HEAD,
	sides = 20,
	steps = 50,
})
H.mesh:select("face", "where", function(p)
	return p[1] > HEAD[1] + 0.265
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

-- Wings: huge, swept back, spread and raised; sheet metal in three
-- pieces out from the root, the trailing edge scalloped into feathers.
local WING_OUTLINE = { { 0.6, 0 }, { 0.5, 0.5 }, { 0.3, 1.1 }, { 0.0, 1.7 }, { -0.35, 1.78 }, { -0.5, 1.55 }, { -0.68, 1.62 }, { -0.8, 1.3 }, { -0.98, 1.36 }, { -1.02, 1.0 }, { -0.9, 0.55 }, { -0.7, 0.1 }, { -0.6, 0 } }
local function placeWing(side)
	return function(m)
		Kit.turn(m, "x", -90 * side)
		Kit.turn(m, "x", -DIHEDRAL * side)
		return m:translate(WING.x, WING.y * side, WING.z)
	end
end
-- Where a wing's mid-chord line is at span s: for the pylons.
local function wingAt(side, s, chord)
	local p = { chord or -0.2, 0, s }
	local a = math.rad(-90 * side)
	p = { p[1], p[2] * math.cos(a) - p[3] * math.sin(a), p[2] * math.sin(a) + p[3] * math.cos(a) }
	a = math.rad(-DIHEDRAL * side)
	p = { p[1], p[2] * math.cos(a) - p[3] * math.sin(a), p[2] * math.sin(a) + p[3] * math.cos(a) }
	return { p[1] + WING.x, p[2] + WING.y * side, p[3] + WING.z }
end
part("Wings", nil, DARK, function(mesh)
	for n, side in { -1, 1 } do
		Scrap.metalFin(WING_OUTLINE, 0.13, 1.78, { 0.55, 1.2 }, placeWing(side), n * 2):emit(mesh)
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

-- Googly eyes, in the dark of the head above the cheek patch.
local eyes = {}
for _, side in { -1, 1 } do
	local p, n = H.normal(0.06, side * 62)
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
