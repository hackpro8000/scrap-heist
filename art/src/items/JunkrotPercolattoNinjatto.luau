-- Percolatto Ninjatto: Cappuccino Assassino from scrap. The picture: a
-- tall takeaway coffee cup IS the character, a dark lid on top, a dark
-- sleeve band under the lid wearing a steel forehead plate with a spiral,
-- its tails flying off behind to its left; two big round eyes under
-- angry brows on the pale middle; a second dark sleeve band across the
-- lower half for the mask; thin dark stick arms out of the sides holding
-- a curved katana each, blades up and out; thin legs in split-toe boots.
-- Built upright: the cup a loft turned on end and skinned in pale plates,
-- the two bands rows of dark plate, the eyes enamel discs with dark
-- pupils and rims, the katanas flat bar. 4 studs tall.
-- include: JunkrotScrap
local DARK = { 0.18, 0.19, 0.21 } -- the steel under the plates
local SOOT = { 0.12, 0.11, 0.11 } -- limbs, rims, brows
local CREAM = { 0.86, 0.86, 0.82 }
local BOTTOM, TOP = 0.78, 3.72 -- the cup's base and rim heights
local BANDS = { mask = { 1.55, 2.25 }, head = { 3.1, TOP } } -- the dark rows
local EYE = { z = 2.72, a = 23, r = 0.2 } -- eye height, angle from the front, radius

-- The cup: a loft along x of round stations (x stands in for height), then
-- stood on end so x is up and the loft's top (angle 0) faces the front
-- (-y). Positive angles go round to the character's right (-x).
local function up(p)
	return { -p[2], -p[3], p[1] }
end
local stations = {}
for _, s in { { BOTTOM, 0.08 }, { BOTTOM + 0.05, 0.5 }, { 1.2, 0.54 }, { 2.0, 0.6 }, { 2.9, 0.68 }, { TOP - 0.02, 0.74 }, { TOP, 0.72 } } do
	table.insert(stations, { s[1], s[2], -s[2], s[2] })
end
local L = Scrap.loft({ stations = stations, sides = 28, steps = 84 })
local rawSkin = L.skin
function L.skin(x, a)
	return up(rawSkin(x, a))
end
function L.normal(x, a)
	local p = L.skin(x, a)
	local px, pa = L.skin(x + 0.01, a), L.skin(x, a + 0.5)
	local u = { px[1] - p[1], px[2] - p[2], px[3] - p[3] }
	local v = { pa[1] - p[1], pa[2] - p[2], pa[3] - p[3] }
	local n = EditMesh.vec.unit(EditMesh.vec.cross(u, v))
	if n[1] * p[1] + n[2] * p[2] < 0 then
		n = { -n[1], -n[2], -n[3] }
	end
	return p, n
end
function L.on(x, a, lift)
	local p, n = L.normal(x, a)
	return { p[1] + n[1] * lift, p[2] + n[2] * lift, p[3] + n[3] * lift }
end
Kit.turn(L.mesh, "x", 90)
Kit.turn(L.mesh, "y", -90)
-- The loft caps its ends; off with them, so the skin's thickness closes
-- round rims instead of leaving an inner shell adrift.
for _, id in L.mesh:select("face", "where", function(p)
	return p[3] < BOTTOM + 0.002 or p[3] > TOP - 0.002
end):list() do
	L.mesh:removeFace(id)
end

-- A curved plate lying on the skin over a height and angle range, lifted
-- off it, with its own thickness: the forehead plate, the eye backs.
local function skinPlate(z0, z1, a0, a1, lift, thick)
	local m = EditMesh.new()
	local N, R = 6, 8
	local outer, inner = {}, {}
	for i = 0, N do
		outer[i], inner[i] = {}, {}
		for j = 0, R do
			local z, a = z0 + (z1 - z0) * i / N, a0 + (a1 - a0) * j / R
			local o, u = L.on(z, a, lift + thick), L.on(z, a, lift)
			outer[i][j] = m:addVertex(o[1], o[2], o[3])
			inner[i][j] = m:addVertex(u[1], u[2], u[3])
		end
	end
	for i = 0, N - 1 do
		for j = 0, R - 1 do
			m:addFace({ outer[i][j], outer[i + 1][j], outer[i + 1][j + 1], outer[i][j + 1] })
			m:addFace({ inner[i][j], inner[i][j + 1], inner[i + 1][j + 1], inner[i + 1][j] })
		end
	end
	for k = 0, N - 1 do
		m:addFace({ outer[k][0], inner[k][0], inner[k + 1][0], outer[k + 1][0] })
		m:addFace({ outer[k + 1][R], inner[k + 1][R], inner[k][R], outer[k][R] })
	end
	for k = 0, R - 1 do
		m:addFace({ outer[0][k + 1], inner[0][k + 1], inner[0][k], outer[0][k] })
		m:addFace({ outer[N][k], inner[N][k], inner[N][k + 1], outer[N][k + 1] })
	end
	local n = m:faceNormal(m:select("face", "all"):list()[1])
	local c, o = L.on((z0 + z1) / 2, (a0 + a1) / 2, lift), L.on((z0 + z1) / 2, (a0 + a1) / 2, lift + 0.1)
	if n[1] * (o[1] - c[1]) + n[2] * (o[2] - c[2]) + n[3] * (o[3] - c[3]) < 0 then
		m:flip()
	end
	return m
end
-- Stands a piece built z-up at the origin on the skin at (z, a), lifted.
local function stood(piece, z, a, lift)
	local p, n = L.normal(z, a)
	Kit.turn(piece, "y", math.deg(math.acos(math.clamp(n[3], -1, 1))))
	Kit.turn(piece, "z", math.deg(math.atan2(n[2], n[1])))
	return piece:translate(p[1] + n[1] * lift, p[2] + n[2] * lift, p[3] + n[3] * lift)
end

-- The skin under the plates: dark steel, showing in the seams.
part("Body", nil, DARK, function(mesh)
	Scrap.skinPart(L, {}, 0.03):emit(mesh)
end, true, 0.4)

-- The lid: a dark steel can lid over the rim, a rolled lip round it, a
-- raised disc in the middle with the sip hole's bump.
part("Lid", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.7, 0 }, { 0.79, 0.04 }, { 0.8, 0.13 }, { 0.76, 0.17 }, { 0.66, 0.14 }, { 0.5, 0.2 }, { 0.46, 0.28 }, { 0.3, 0.3 }, { 0, 0.31 } }, 28)
	m:translate(0, 0, TOP - 0.04)
	m:emit(mesh)
end, true, 0.3)

-- The forehead plate: a steel plate on the upper band, riveted at its
-- corners, the leaf spiral scribed on it as a thin dark coil.
part("Headband", nil, { 0.62, 0.64, 0.64 }, function(mesh)
	skinPlate(3.2, 3.48, -26, 26, 0.07, 0.03):emit(mesh)
end, 40, 0.6)
part("HeadbandRivets", nil, SOOT, function(mesh)
	for _, z in { 3.24, 3.44 } do
		for _, a in { -22, 22 } do
			local r = EditMesh.sphere(0.022, 6)
			local o = L.on(z, a, 0.1)
			r:translate(o[1], o[2], o[3])
			r:emit(mesh)
		end
	end
	local path = {}
	for k = 0, 22 do
		local t = k / 22
		local ang = t * 2.4 * math.pi
		local rad = 0.012 + 0.07 * t
		local z, a = 3.34 + math.cos(ang) * rad, math.sin(ang) * rad / 0.011
		local o = L.on(z, a, 0.1)
		table.insert(path, o)
	end
	table.insert(path, L.on(3.3, 16, 0.1))
	Kit.tube(path, 0.011, 6):emit(mesh)
end, true, 0.2)

-- The plating: rows of pale cup plates, the two sleeve rows in dark
-- plates, the lid's rim row dark too; cuts at the rows' edges on every
-- band so the dark rows have clean edges, other cuts differing by band.
local CUPS = { { "ENAMEL", CREAM }, { "TIN", { 0.74, 0.72, 0.66 } }, { "ENAMEL", CREAM }, { "ALUMINIUM", { 0.8, 0.81, 0.78 } }, { "ENAMEL", CREAM } }
local DARKS = { { "SOOT", { 0.14, 0.12, 0.11 } }, { "TAR", { 0.2, 0.16, 0.13 } }, { "SOOT", { 0.14, 0.12, 0.11 } }, { "BURNT", { 0.17, 0.14, 0.12 } } }
local B = BOTTOM + 0.06
local panels = Scrap.panels(L, {
	bands = {
		{ 0, 36, { B, 1.2, 1.55, 1.9, 2.25, 2.7, 3.1, 3.4, TOP } },
		{ 36, 72, { B, 1.55, 2.25, 3.1, TOP } },
		{ 72, 108, { B, 1.1, 1.55, 2.0, 2.25, 2.65, 3.1, TOP } },
		{ 108, 144, { B, 1.55, 1.85, 2.25, 3.1, 3.45, TOP } },
		{ 144, 180, { B, 1.3, 1.55, 2.25, 2.8, 3.1, TOP } },
	},
	paleFrom = 0,
	splits = { [2] = 0.5, [5] = 0.4, [9] = 0.6, [14] = 0.45, [20] = 0.55, [27] = 0.35, [33] = 0.5, [38] = 0.6 },
	open = function(band, x0, x1)
		-- The face: no plates over the eyes' row on the front band, the
		-- forehead plate's cell neither.
		return (band == 1 and x0 >= 2.25 and x1 <= 3.1) or (band == 1 and x0 >= 3.1 and x1 <= 3.4)
	end,
	metal = function(band, seg, cell, side, x0, x1)
		local n = band * 7 + seg * 3 + cell + (if side < 0 then 1 else 0)
		if (x0 >= BANDS.mask[1] - 0.01 and x1 <= BANDS.mask[2] + 0.01) or x0 >= BANDS.head[1] - 0.01 then
			return DARKS[n % #DARKS + 1]
		end
		return CUPS[n % #CUPS + 1]
	end,
})
Scrap.panelParts(L, panels, { lift = 0.035 })
-- The front of the face under the eyes' opening: a pale plate of its own,
-- wider than the opening, so the eyes sit on enamel, and the forehead
-- plate's dark backing.
part("Face", nil, CREAM, function(mesh)
	skinPlate(2.26, 3.09, -37, 37, 0.03, 0.02):emit(mesh)
end, 40, 0.3)
part("Brow", nil, DARKS[1][2], function(mesh)
	skinPlate(3.11, 3.39, -37, 37, 0.03, 0.02):emit(mesh)
end, 40, 0.5)
finishParts()
