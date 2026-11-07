-- Chimneyzini Spannerini: Chimpanzini Bananini from scrap, a tin chimp in
-- a peeled stove pipe. After the picture: the chimp's head and neck ARE
-- the banana, one tall column leaning gently forward, its upper part the
-- green-furred head (green-painted plates), a bare pink face on its front
-- (heavy brow, sunk eyes, a long flat muzzle with wide nostrils and a
-- downturned mouth, round pink ears out at eye height), under the fur a
-- short ribbed column of pale banana flesh, and at its foot the peel: four
-- yellow sheet-metal strips folded up over the rim and down round it,
-- their pale insides showing, over the unpeeled yellow pipe that stands
-- on the ground. No arms, nothing in its hands: the picture has none.
-- Googly eyes under the brow. 4 studs tall, face toward +x.
-- include: JunkrotScrap

-- The column is a loft along x, head top at x = -4 down to the ground at
-- 0, its "top" the front, then turned up (x -> z, front -> +x).
local function st(x, r, lean)
	return { x, r + lean, -r + lean, r }
end
local L = Scrap.loft({
	stations = {
		st(-4.0, 0.05, 0.3),
		st(-3.96, 0.24, 0.3),
		st(-3.88, 0.37, 0.29),
		st(-3.76, 0.47, 0.27),
		st(-3.58, 0.54, 0.22),
		st(-3.3, 0.57, 0.15),
		st(-3.0, 0.56, 0.09),
		st(-2.72, 0.53, 0.04),
		st(-2.47, 0.52, 0.01),
		st(-2.38, 0.53, 0),
		st(-2.06, 0.55, 0),
		st(-2.0, 0.58, 0),
		st(-1.2, 0.6, 0),
		st(0.0, 0.55, 0),
	},
	sides = 32,
	steps = 120,
})
local function lean(x)
	local top, bottom = L.station(x)
	return (top + bottom) / 2
end
-- Angle round the section from the front, of a loft-frame point.
local function round(p)
	return math.deg(math.atan2(math.abs(p[2]), p[3] - lean(p[1])))
end
local function turnPoint(p)
	return { p[3], p[2], -p[1] }
end
local T = { x0 = L.x0, x1 = L.x1, at = L.at, station = L.station }
function T.skin(x, a)
	return turnPoint(L.skin(x, a))
end
function T.normal(x, a)
	local p, n = L.normal(x, a)
	return turnPoint(p), turnPoint(n)
end
function T.on(x, a, lift)
	return turnPoint(L.on(x, a, lift))
end

-- The face: the bare patch on the front of the head, a tall oval, and the
-- features worked into it.
local FACE_HALF = { { -3.85, 28 }, { -3.65, 44 }, { -3.45, 56 }, { -3.1, 52 }, { -2.8, 34 } }
local M = L.mesh
M:select("face", "where", function(p)
	return p[1] > -3.85 and p[1] < -2.8 and round(p) < Scrap.tableAt(FACE_HALF, p[1])
end):tag("face")
M:tagging("face", function()
	-- The brow: a ridge across the top of the face.
	local brow = M:select("face", "where", function(p)
		return p[1] > -3.66 and p[1] < -3.55 and round(p) < 30
	end)
	M:extrude(brow, 0.07)
	-- The eye sockets under it, sunk.
	for _, side in { -1, 1 } do
		local socket = M:select("face", "where", function(p)
			return p[1] > -3.52 and p[1] < -3.4 and p[2] * side > 0.07 and p[2] * side < 0.26
		end)
		M:extrude(M:inset(socket, 0.01, 0), -0.04)
	end
	-- The muzzle: long and flat, out from the lower face.
	local muzzle = M:select("face", "where", function(p)
		return p[1] > -3.3 and p[1] < -2.92 and round(p) < 32
	end)
	M:extrude(M:inset(muzzle, 0.02, 0), 0.16)
	-- Nostrils on its upper front, and the mouth, a slit across the lower.
	for _, side in { -1, 1 } do
		local nare = M:select("face", "facing", { 0, 0, 1 }, 35):filter(function(p)
			return p[1] > -3.28 and p[1] < -3.19 and p[2] * side > 0.04 and p[2] * side < 0.15 and p[3] > 0.6
		end)
		if nare:count() > 0 then
			Kit.recess(M, nare, 0.01, 0.025)
		end
	end
	local mouth = M:select("face", "facing", { 0, 0, 1 }, 35):filter(function(p)
		return p[1] > -3.06 and p[1] < -2.97 and math.abs(p[2]) < 0.2 and p[3] > 0.6
	end)
	if mouth:count() > 0 then
		Kit.recess(M, mouth, 0.01, 0.03)
	end
end)
T.mesh = Kit.turn(M:copy(), "y", 90)

local PINK = { 0.84, 0.46, 0.42 }
part("Body", nil, { 0.18, 0.19, 0.21 }, function(mesh)
	Scrap.skinPart(T, { drop = { "face" } }):emit(mesh)
end, true, 0.4)
part("Face", nil, PINK, function(mesh)
	Scrap.skinPart(T, { keep = "face" }, 0.03):emit(mesh)
end, true, 0.25)

-- Ears: round tin dishes out from the sides of the head at eye height,
-- cupped a little forward.
part("Ears", nil, PINK, function(mesh)
	for _, side in { -1, 1 } do
		local outline = {}
		for k = 0, 15 do
			local a = math.rad(k * 360 / 16)
			table.insert(outline, { 0.14 + math.cos(a) * 0.17, math.sin(a) * 0.17 })
		end
		local ear = Kit.plate(outline, 0.03)
		ear:transform(function(p)
			local d = math.sqrt((p[1] - 0.14) ^ 2 + p[3] ^ 2) / 0.17
			return { p[1], p[2] - side * 0.07 * d * d, p[3] }
		end)
		Kit.turn(ear, "z", side * 90)
		Kit.turn(ear, "z", -side * 20)
		local p = T.skin(-3.45, side * 88)
		ear:translate(p[1], p[2] - side * 0.08, p[3])
		ear:emit(mesh)
	end
end, true, 0.25)

-- Googly eyes in the sockets.
local eyes = {}
for _, side in { -1, 1 } do
	local p, n = T.normal(-3.46, side * 19)
	table.insert(eyes, { p, n })
end
Scrap.googlyEyes(eyes, 0.11)

-- The lips: a dark bead along the mouth, turned down at the corners.
part("Lips", nil, { 0.5, 0.2, 0.2 }, function(mesh)
	local front = T.skin(-3.0, 0)[1] + 0.16
	local path = {}
	for k = 0, 8 do
		local y = -0.18 + 0.36 * k / 8
		local u = y / 0.18
		table.insert(path, { front + 0.01 - 0.035 * u * u, y, 3.0 - 0.07 * u * u })
	end
	Kit.tube(path, 0.024, 6):emit(mesh)
end, true, 0.1)

-- The peel: four strips of yellow sheet metal in pieces, each rising from
-- inside the rim, folding over and hanging down round the pipe, tapering
-- to a tip, a pale lining on the inside that shows below the fold.
local PEEL = {
	{ "PeelYellow", { 0.97, 0.8, 0.14 } },
	{ "PeelFaded", { 0.93, 0.84, 0.4 } },
	{ "PeelOchre", { 0.88, 0.68, 0.12 } },
}
local CURVE = Kit.curve({ { 0.44, 0, 1.96 }, { 0.6, 0, 2.16 }, { 0.8, 0, 2.3 }, { 1.04, 0, 2.26 }, { 1.24, 0, 2.02 }, { 1.33, 0, 1.66 }, { 1.28, 0, 1.28 }, { 1.1, 0, 0.96 } }, 6)
local LENGTHS = { 0 }
for i = 2, #CURVE do
	LENGTHS[i] = LENGTHS[i - 1] + math.sqrt((CURVE[i][1] - CURVE[i - 1][1]) ^ 2 + (CURVE[i][3] - CURVE[i - 1][3]) ^ 2)
end
local SPAN = LENGTHS[#LENGTHS]
local function along(s) -- point (r, z) and tangent on the curve at arc length s
	s = math.clamp(s, 0, SPAN - 0.001)
	for i = 2, #CURVE do
		if s <= LENGTHS[i] then
			local a, b = CURVE[i - 1], CURVE[i]
			local len = LENGTHS[i] - LENGTHS[i - 1]
			local t = (s - LENGTHS[i - 1]) / len
			return a[1] + (b[1] - a[1]) * t, a[3] + (b[3] - a[3]) * t, (b[1] - a[1]) / len, (b[3] - a[3]) / len
		end
	end
	return CURVE[#CURVE][1], CURVE[#CURVE][3], 0, -1
end
-- Each strip: its angle round the pipe, how far along the curve it reaches.
local STRIPS = { { 0, 1.0 }, { 90, 0.86 }, { 180, 0.8 }, { -90, 0.92 } }
local THICK = 0.05
local function width(s, reach)
	local out = math.clamp((s - 0.45) / (reach - 0.45), 0, 1)
	return 0.84 * (1 - 0.88 * out ^ 1.3)
end
local function taper(s, reach)
	return 1 - 0.55 * s / reach
end
-- Maps strip coordinates {u across (-0.5..0.5), s along, d off the sheet}
-- onto the strip at angle theta.
local function onStrip(theta, reach)
	return function(p)
		local u, s, d = p[1], p[2], p[3] * taper(p[2], reach)
		local r, z, tr, tz = along(s)
		local nr, nz = tz, -tr
		local radial, height = r + d * nr, z + d * nz
		local a = math.rad(theta) + u * width(s, reach) / math.max(r, 0.5)
		return { radial * math.cos(a), radial * math.sin(a), height }
	end
end
local pieces, linings, peelRivets = {}, {}, {}
for n, strip in STRIPS do
	local theta, reach = strip[1], SPAN * strip[2]
	local cuts = { 0.3 * reach, 0.62 * reach }
	local edges = { 0, cuts[1], cuts[2], reach }
	for k = 1, 3 do
		local lo = edges[k] + (if k > 1 then 0.012 else 0)
		local hi = edges[k + 1] - (if k < 3 then 0.012 else 0)
		local nv = math.max(3, math.ceil((hi - lo) / 0.06))
		local sheet = EditMesh.grid(1, hi - lo, 6, nv)
		sheet:translate(0, (lo + hi) / 2, 0)
		sheet:solidify(THICK)
		sheet:translate(0, 0, THICK / 2)
		sheet:transform(onStrip(theta, reach))
		table.insert(pieces, { (n + k) % 3 + 1, sheet })
	end
	-- The lining, below the fold, on the side that faces out there.
	local lo, hi = 0.4 * reach, reach - 0.01
	local lining = EditMesh.grid(0.9, hi - lo, 4, math.ceil((hi - lo) / 0.08))
	lining:translate(0, (lo + hi) / 2, -THICK / 2 + 0.006)
	lining:solidify(0.02)
	lining:transform(onStrip(theta, reach))
	table.insert(linings, lining)
	for _, c in cuts do
		for _, u in { -0.3, 0, 0.3 } do
			for _, ds in { -0.04, 0.04 } do
				-- Through the sheet, a head showing on both sides.
				local r = EditMesh.sphere(THICK / 2 + 0.012, 6)
				Kit.size(r, { 1 / width(c, reach), 1, 1 })
				r:translate(u, c + ds, 0)
				r:transform(onStrip(theta, reach))
				table.insert(peelRivets, r)
			end
		end
	end
end
for shade, metal in PEEL do
	part(metal[1], nil, metal[2], function(mesh)
		for _, piece in pieces do
			if piece[1] == shade then
				piece[2]:emit(mesh)
			end
		end
	end, 40, 0.45)
end
part("PeelLining", nil, { 0.95, 0.9, 0.74 }, function(mesh)
	for _, lining in linings do
		lining:emit(mesh)
	end
end, 40, 0.2)
part("PeelRivets", nil, DARK_STEEL, function(mesh)
	for _, r in peelRivets do
		r:emit(mesh)
	end
end, true, 0.4)

-- The plating: green-painted plates over the head, yellow over the pipe,
-- the face left open; the flesh between in narrow pale plates, ribbed.
local GREENS = { { "LIME", { 0.56, 0.66, 0.2 } }, { "MOSS", { 0.44, 0.56, 0.18 } }, { "OLIVEPAINT", { 0.52, 0.58, 0.3 } } }
local YELLOWS = { { "YELLOW", { 0.97, 0.8, 0.14 } }, { "FADED", { 0.93, 0.84, 0.4 } }, { "OCHRE", { 0.88, 0.68, 0.12 } } }
local CREAMS = { { "CREAM", { 0.93, 0.88, 0.72 } }, { "IVORY", { 0.88, 0.84, 0.66 } } }
local panels = Scrap.panels(T, {
	bands = {
		{ 0, 30, { -3.95, -3.7, -3.45, -3.2, -2.9, -2.65, -2.42, -2.05, -1.5, -1.0, -0.55, 0 } },
		{ 30, 55, { -3.95, -3.78, -3.5, -3.25, -2.95, -2.75, -2.42, -2.05, -1.65, -1.2, -0.7, 0 } },
		{ 55, 90, { -3.95, -3.68, -3.4, -3.1, -2.85, -2.6, -2.42, -2.05, -1.8, -1.35, -0.9, -0.35, 0 } },
		{ 90, 125, { -3.95, -3.75, -3.55, -3.2, -3.0, -2.7, -2.42, -2.05, -1.55, -1.1, -0.5, 0 } },
		{ 125, 155, { -3.95, -3.65, -3.35, -3.05, -2.8, -2.55, -2.42, -2.05, -1.7, -1.25, -0.8, -0.3, 0 } },
		{ 155, 180, { -3.95, -3.72, -3.42, -3.15, -2.88, -2.62, -2.42, -2.05, -1.45, -1.05, -0.6, 0 } },
	},
	splits = { [4] = 0.5, [9] = 0.4, [15] = 0.6, [22] = 0.45, [30] = 0.55, [37] = 0.35 },
	open = function(band, x0, x1)
		if x0 == -2.42 then
			return true
		end
		return (band == 1 and x0 >= -3.71 and x1 <= -2.64) or (band == 2 and x0 >= -3.51 and x1 <= -2.94)
	end,
	metal = function(band, seg, cell, side, x0)
		local pick = (band * 2 + seg * 3 + cell + (if side < 0 then 1 else 0)) % 3 + 1
		if x0 < -2.42 then
			return GREENS[pick]
		end
		return YELLOWS[pick]
	end,
})
local ribs = {}
for k = 0, 7 do
	table.insert(ribs, { k * 22.5, (k + 1) * 22.5, { -2.38, -2.07 } })
end
for _, q in Scrap.panels(T, {
	bands = ribs,
	metal = function(band, _, _, side)
		return CREAMS[(band + (if side < 0 then 1 else 0)) % 2 + 1]
	end,
}) do
	table.insert(panels, q)
end
Scrap.panelParts(T, panels)
finishParts()
