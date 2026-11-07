-- La Vacuuma Saturnita: La Vaca Saturno Saturnita from scrap. After the
-- picture: a planet, a round vacuum canister (a loft, axis up) plated in
-- pale mismatched metals with a lid and a base at its poles; a broad flat
-- ring of sheet-metal sectors round it, tipped as Saturn's is; a tin
-- cow's head grown out of the planet's upper front, nose down, with a
-- pink muzzle, ears out to the sides, horns up, googly eyes; under the
-- planet two pipe cuffs, short shins and two huge bare human feet of
-- scrap with five toes each, pointing forward. 4 studs tall.
-- include: JunkrotScrap
local R, RZ = 1.25, 1.15 -- the planet: radius across, and up (oblate)
local ZC = 2.55 -- its centre's height
local TILT = 22 -- degrees the ring tips, front down
local LEG_Y = 0.62 -- the legs' spread from the middle
local DARK = { 0.18, 0.19, 0.21 }
local TIN = { 0.72, 0.7, 0.66 }

-- Point and direction maps for a mesh turned about y, then about x, then
-- moved: the way a loft and all built on it are placed.
local function placement(yDeg, xDeg, move)
	local cy, sy = math.cos(math.rad(yDeg)), math.sin(math.rad(yDeg))
	local cx, sx = math.cos(math.rad(xDeg)), math.sin(math.rad(xDeg))
	local function dir(p)
		local x, y, z = p[1] * cy + p[3] * sy, p[2], -p[1] * sy + p[3] * cy
		return { x, y * cx - z * sx, y * sx + z * cx }
	end
	local function point(p)
		local q = dir(p)
		return { q[1] + move[1], q[2] + move[2], q[3] + move[3] }
	end
	return point, dir
end
local function zPlacement(zDeg, move)
	local c, s = math.cos(math.rad(zDeg)), math.sin(math.rad(zDeg))
	local function dir(p)
		return { p[1] * c - p[2] * s, p[1] * s + p[2] * c, p[3] }
	end
	return function(p)
		local q = dir(p)
		return { q[1] + move[1], q[2] + move[2], q[3] + move[3] }
	end, dir
end
-- Places a loft: its skin, normals and mesh all go through the maps, so
-- plates and rivets built on it afterwards land where it is.
local function placeLoft(loft, point, dir)
	local skin0, normal0 = loft.skin, loft.normal
	function loft.skin(x, a)
		return point(skin0(x, a))
	end
	function loft.normal(x, a)
		local p, n = normal0(x, a)
		return point(p), dir(n)
	end
	function loft.on(x, a, lift)
		local p, n = loft.normal(x, a)
		return { p[1] + n[1] * lift, p[2] + n[2] * lift, p[3] + n[3] * lift }
	end
	loft.mesh:transform(point)
	loft.place = function(m)
		return m:transform(point)
	end
	return loft
end

-- The planet: a near-sphere lofted along x, then stood up (x to z), so
-- its plates run in bands round its waist like a canister's.
local stations = {}
for _, h in { -1.12, -1.02, -0.88, -0.7, -0.5, -0.26, 0, 0.26, 0.5, 0.7, 0.88, 1.02, 1.12 } do
	local w = R * math.sqrt(math.max(0, 1 - (h / RZ) ^ 2))
	table.insert(stations, { h, w, -w, w })
end
local P = Scrap.loft({ stations = stations, sides = 32, steps = 48 })
placeLoft(P, placement(-90, 0, { 0, 0, ZC }))

-- The head: a cow's head lofted nose +x, grown from inside the planet,
-- turned nose down and set high on the planet's front.
local HEAD_DOWN = 28
local H = Scrap.loft({
	stations = { -- x, top, bottom, half width
		{ 0.5, 0.4, -0.38, 0.4 },
		{ 0.85, 0.5, -0.46, 0.5 },
		{ 1.2, 0.5, -0.46, 0.5 },
		{ 1.45, 0.44, -0.43, 0.44 },
		{ 1.65, 0.3, -0.4, 0.36 },
		{ 1.85, 0.16, -0.38, 0.32 },
		{ 2.0, 0.08, -0.34, 0.3 },
		{ 2.08, 0.0, -0.3, 0.26 },
		{ 2.13, -0.1, -0.22, 0.14 },
	},
	straightFrom = 1.65,
	sides = 24,
	steps = 40,
})
-- Horns out of the skull's top corners, three extrusions each, curving
-- up and out; the muzzle tagged for its own pink skin.
for _, s in { -1, 1 } do
	local base = H.mesh:select("face", "facing", { 0, s * 0.7, 1 }, 28):filter(function(p)
		return p[1] > 0.95 and p[1] < 1.3
	end)
	if base:count() > 0 then
		local top = H.mesh:extrude(base, 0.14, { tag = "horn" })
		top:scale(0.7)
		top:move({ 0, s * 0.06, 0.08 })
		top = H.mesh:extrude(top, 0.14, { tag = "horn" })
		top:scale(0.7)
		top:move({ 0.06, s * 0.02, 0.12 })
		top = H.mesh:extrude(top, 0.1, { tag = "horn" })
		top:scale(0.45)
		top:move({ 0.06, -s * 0.02, 0.1 })
	end
end
H.mesh:select("face", "where", function(p)
	return p[1] > 1.74
end):tag("muzzle")
local headPoint, headDir = placement(HEAD_DOWN, 0, { 0, 0, ZC + 0.5 })
placeLoft(H, headPoint, headDir)

-- The feet: each a loft heel to ball along x, flat-soled, the ankle rising
-- at the back and the shin extruded up out of it into its cuff; the toes
-- five small lofts from the ball. Splayed a little outward.
local FOOT_X = 0.05 -- the ankle's x under the cuff
local feet = {}
for _, s in { -1, 1 } do
	local F = Scrap.loft({
		stations = {
			{ -0.72, 0.05, -0.2, 0.05 },
			{ -0.62, 0.3, -0.28, 0.2 },
			{ -0.45, 0.42, -0.3, 0.3 },
			{ -0.25, 0.42, -0.3, 0.33 },
			{ 0.0, 0.26, -0.3, 0.36 },
			{ 0.3, 0.1, -0.3, 0.4 },
			{ 0.6, 0.0, -0.3, 0.42 },
			{ 0.8, -0.08, -0.3, 0.4 },
			{ 0.9, -0.12, -0.28, 0.3 },
		},
		at = { 0, 0, 0.3 },
		sides = 24,
		steps = 40,
	})
	local ankle = F.mesh:select("face", "facing", { 0, 0, 1 }, 40):filter(function(p)
		return p[1] > -0.56 and p[1] < -0.16 and math.abs(p[2]) < 0.19
	end)
	if ankle:count() > 0 then
		local top = F.mesh:extrude(ankle, 0.36, { tag = "shin" })
		top:scale({ 0.8, 0.8, 1 })
	end
	placeLoft(F, zPlacement(-s * 8, { FOOT_X, s * LEG_Y, 0 }))
	table.insert(feet, { loft = F, side = s })
end

-- Skins: dark steel under the plates.
part("Planet", nil, DARK, function(mesh)
	P.mesh:copy():emit(mesh)
end, true, 0.4)
part("Head", nil, { 0.86, 0.86, 0.82 }, function(mesh)
	Scrap.skinPart(H, { drop = { "muzzle", "horn" } }):emit(mesh)
end, true, 0.3)
part("Muzzle", nil, { 0.9, 0.62, 0.6 }, function(mesh)
	Scrap.skinPart(H, { keep = "muzzle" }):emit(mesh)
end, true, 0.2)
part("Horns", nil, BARE_METAL, function(mesh)
	Scrap.skinPart(H, { keep = "horn" }):emit(mesh)
end, true, 0.3)
part("Feet", nil, DARK, function(mesh)
	for _, f in feet do
		f.loft.mesh:copy():emit(mesh)
	end
end, true, 0.4)
part("Toes", nil, TIN, function(mesh)
	for _, f in feet do
		-- Big toe inward, the rest shorter and thinner outward.
		for k, toe in { { 0.29, 0.1, 0.44 }, { 0.12, 0.085, 0.42 }, { -0.04, 0.078, 0.38 }, { -0.19, 0.07, 0.33 }, { -0.32, 0.065, 0.27 } } do
			local y, r, len = -f.side * toe[1], toe[2], toe[3]
			local T = Scrap.loft({
				stations = {
					{ 0.66, r, -r, r },
					{ 0.66 + len * 0.6, r * 0.95, -r, r },
					{ 0.66 + len * 0.9, r * 0.75, -r * 0.9, r * 0.85 },
					{ 0.66 + len, 0.02, -0.02, 0.02 },
				},
				at = { 0, y, r + 0.01 },
				sides = 12,
				steps = 8,
			})
			f.loft.place(T.mesh):emit(mesh)
		end
	end
end, true, 0.3)

-- The pipe cuffs the legs hang from, lipped at the bottom.
part("Cuffs", nil, { 0.3, 0.33, 0.37 }, function(mesh)
	for _, s in { -1, 1 } do
		local cuff = Kit.lathe({ { 0, 0 }, { 0.25, 0 }, { 0.25, 0.05 }, { 0.29, 0.05 }, { 0.29, 0.12 }, { 0.26, 0.12 }, { 0.26, 0.6 }, { 0, 0.6 } }, 16)
		cuff:translate(FOOT_X, s * LEG_Y, 1.0)
		cuff:emit(mesh)
	end
end, true, 0.5)

-- The poles: a lid and a base closing the canister where the plates stop.
part("Caps", nil, { 0.6, 0.63, 0.62 }, function(mesh)
	local lid = Kit.lathe({ { 0, -0.06 }, { 0.5, -0.06 }, { 0.56, 0 }, { 0.56, 0.06 }, { 0.46, 0.1 }, { 0, 0.1 } }, 24)
	lid:translate(0, 0, ZC + 1.04)
	lid:emit(mesh)
	local base = Kit.lathe({ { 0, -0.1 }, { 0.46, -0.1 }, { 0.56, -0.06 }, { 0.56, 0 }, { 0.5, 0.06 }, { 0, 0.06 } }, 24)
	base:translate(0, 0, ZC - 1.04)
	base:emit(mesh)
end, true, 0.4)

-- The ring: two bands of flat sheet sectors, pale inside and darker out,
-- the outer band's seams half a sector round from the inner's; the whole
-- tipped front down and a little to one side.
local function sector(radii, a0, a1, thick)
	local m = EditMesh.new()
	local ids = {}
	local nr, na = #radii - 1, 5
	for i = 0, nr do
		ids[i] = {}
		for j = 0, na do
			local r, a = radii[i + 1], math.rad(a0 + (a1 - a0) * j / na)
			ids[i][j] = m:addVertex(r * math.cos(a), r * math.sin(a), 0)
		end
	end
	for i = 0, nr - 1 do
		for j = 0, na - 1 do
			m:addFace({ ids[i][j], ids[i + 1][j], ids[i + 1][j + 1], ids[i][j + 1] })
		end
	end
	return m:solidify(thick)
end
local ringPoint = placement(TILT, 7, { 0, 0, ZC })
local function onRing(m)
	return m:transform(ringPoint)
end
-- Each band: its radii (a row of vertices near the planet's skin, so the
-- inner band is seen to meet it), its first seam's angle, its metals.
local RING = { { { 1.17, 1.25, 1.48, 1.72 }, 0, Scrap.BELLY_METALS }, { { 1.78, 2.06, 2.35 }, 15, Scrap.BACK_METALS } }
local ringSectors = {}
for b, band in RING do
	for k = 0, 11 do
		local metal = band[3][(k * 5 + b) % #band[3] + 1]
		ringSectors[(b - 1) * 12 + k + 1] = { radii = band[1], a0 = band[2] + k * 30 + 1.2, a1 = band[2] + (k + 1) * 30 - 1.2, metal = metal }
	end
end
do
	local metals = {}
	for _, q in ringSectors do
		metals[q.metal[1]] = q.metal[2]
	end
	local names = {}
	for name in metals do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		part("Ring" .. name, nil, metals[name], function(mesh)
			for _, q in ringSectors do
				if q.metal[1] == name then
					onRing(sector(q.radii, q.a0, q.a1, 0.05)):emit(mesh)
				end
			end
		end, 40, if name == "RUST" then 0.7 else 0.45)
	end
end
part("RingRivets", nil, DARK_STEEL, function(mesh)
	for _, q in ringSectors do
		for _, a in { q.a0, q.a1 } do
			for _, t in { 0.25, 0.75 } do
				local r = q.radii[1] + (q.radii[#q.radii] - q.radii[1]) * t
				local rad = math.rad(a)
				local rivet = EditMesh.sphere(0.028, 6)
				rivet:translate(r * math.cos(rad), r * math.sin(rad), 0.005)
				onRing(rivet):emit(mesh)
			end
		end
	end
end, true, 0.4)
finishParts()
