-- Rusteli Rustela: Lirili Larila from scrap. A tall ribbed green cactus
-- column of mismatched painted plates bristling with rebar spines, nose
-- forward (+x), standing on just two massive grey elephant legs in
-- strap sandals; at its top front a grey tin elephant's head with huge
-- sheet-tin ears, a corrugated hose trunk hanging down its front and
-- curling up at the end, two tusks and googly eyes. 4 studs tall.
-- include: JunkrotScrap
local LEGY = 0.42 -- the legs' centres, either side
local HX, HZ = 0.35, 3.3 -- the head's axis: its x origin and height
local RIBS, RIB = 10, 0.05 -- ribs round the cactus and how deep

-- Lofts are built along x; the cactus and the legs are stood upright
-- (loft x becomes height, loft z becomes -x) and the ribs are pressed
-- into the cactus round its axis. One composite "loft" stands in for all
-- of them where the plating wants one: the cactus at x under 5, the legs
-- at x from 10 and 20, the head at x from 30.
local function upright(p)
	return { -p[3], p[2], p[1] }
end
local function ribbed(p)
	local f = 1 + RIB * math.cos(RIBS * math.atan2(p[2], p[3]))
	return { p[1], p[2] * f, p[3] * f }
end
-- The cactus: a column rounding in to a skirt between the legs below and
-- a dome above, round in section before the ribs.
local CACTUS = Scrap.loft({
	stations = { -- height, back, front, half width
		{ 0.95, 0.3, -0.3, 0.3 },
		{ 1.2, 0.5, -0.5, 0.5 },
		{ 1.7, 0.62, -0.62, 0.62 },
		{ 2.6, 0.66, -0.66, 0.66 },
		{ 3.2, 0.64, -0.64, 0.64 },
		{ 3.6, 0.56, -0.56, 0.56 },
		{ 3.85, 0.38, -0.38, 0.38 },
		{ 3.98, 0.1, -0.1, 0.1 },
	},
	sides = 40,
	steps = 40,
})
-- A leg: a column, the foot spreading forward at the bottom.
local LEG = Scrap.loft({
	stations = {
		{ 0.06, 0.32, -0.44, 0.36 },
		{ 0.3, 0.32, -0.42, 0.36 },
		{ 0.55, 0.31, -0.36, 0.34 },
		{ 1.0, 0.31, -0.31, 0.32 },
		{ 1.5, 0.3, -0.3, 0.3 },
	},
	sides = 24,
	steps = 16,
})
-- The head: a domed skull, its back buried in the cactus, the forehead
-- sloping down to the trunk's root at the front.
local HEADL = Scrap.loft({
	stations = {
		{ -0.55, 0.3, -0.25, 0.3 },
		{ -0.3, 0.52, -0.48, 0.5 },
		{ 0.0, 0.6, -0.52, 0.55 },
		{ 0.35, 0.58, -0.5, 0.52 },
		{ 0.65, 0.45, -0.45, 0.42 },
		{ 0.85, 0.25, -0.38, 0.3 },
		{ 0.95, 0.05, -0.3, 0.2 },
		{ 1.0, -0.1, -0.25, 0.12 },
	},
	at = { HX, 0, HZ },
	sides = 24,
	steps = 30,
})
local W = {}
local function place(x, p)
	if x < 5 then
		return upright(ribbed(p))
	elseif x < 25 then
		local q = upright(p)
		return { q[1], q[2] + (if x < 15 then -LEGY else LEGY), q[3] }
	end
	return p
end
function W.skin(x, a)
	if x < 5 then
		return place(x, CACTUS.skin(x, a))
	elseif x < 25 then
		return place(x, LEG.skin(x - (if x < 15 then 10 else 20), a))
	end
	return HEADL.skin(x - 30, a)
end
function W.normal(x, a)
	local p = W.skin(x, a)
	local px, pa = W.skin(x + 0.01, a), W.skin(x, a + 0.5)
	local n = EditMesh.vec.unit(EditMesh.vec.cross(EditMesh.vec.sub(px, p), EditMesh.vec.sub(pa, p)))
	local axis = if x < 5 then { 0, 0, p[3] } elseif x < 25 then { 0, if x < 15 then -LEGY else LEGY, p[3] } else { p[1], 0, HZ }
	if EditMesh.vec.dot(n, EditMesh.vec.sub(p, axis)) < 0 then
		n = { -n[1], -n[2], -n[3] }
	end
	return p, n
end
function W.on(x, a, lift)
	local p, n = W.normal(x, a)
	return { p[1] + n[1] * lift, p[2] + n[2] * lift, p[3] + n[3] * lift }
end

-- The skins under the plates: dark steel showing in the seams.
local DARK = { 0.18, 0.19, 0.21 }
part("Cactus", nil, DARK, function(mesh)
	CACTUS.mesh:copy():transform(function(p)
		return place(0, p)
	end):emit(mesh)
end, true, 0.4)
part("Legs", nil, DARK, function(mesh)
	for _, x in { 10, 20 } do
		LEG.mesh:copy():transform(function(p)
			return place(x, p)
		end):emit(mesh)
	end
end, true, 0.4)
part("Head", nil, DARK, function(mesh)
	HEADL.mesh:copy():emit(mesh)
end, true, 0.4)


-- The trunk: a corrugated rubber hose from the face, hanging down the
-- front of the cactus close against it and curling up forward at the end.
part("Trunk", nil, { 0.14, 0.14, 0.15 }, function(mesh)
	local path = Kit.curve({
		{ HX + 0.85, 0, HZ - 0.15 },
		{ HX + 0.97, 0, HZ - 0.45 },
		{ HX + 0.8, 0, HZ - 0.95 },
		{ HX + 0.6, 0, HZ - 1.35 },
		{ HX + 0.62, 0, HZ - 1.65 },
		{ HX + 0.85, 0, HZ - 1.78 },
		{ HX + 1.05, 0, HZ - 1.62 },
	}, 8)
	Kit.tube(path, function(t)
		return (0.17 - 0.08 * t) * (1 + 0.07 * math.sin(t * 75))
	end, 12):emit(mesh)
end, true, RUBBER)
part("Tusks", nil, { 0.9, 0.88, 0.8 }, function(mesh)
	for _, side in { -1, 1 } do
		local path = Kit.curve({
			{ HX + 0.7, side * 0.18, HZ - 0.3 },
			{ HX + 1.0, side * 0.25, HZ - 0.42 },
			{ HX + 1.25, side * 0.28, HZ - 0.36 },
			{ HX + 1.42, side * 0.28, HZ - 0.22 },
		}, 4)
		Kit.tube(path, function(t)
			return 0.07 * (1 - 0.8 * t)
		end, 8):emit(mesh)
	end
end, true, 0.1)
-- The ears: huge sheet-tin fans hinged along the top of the head's sides,
-- hanging down and flaring out and forward, in pieces.
local EAR = { { -0.3, 0 }, { 0.4, 0 }, { 0.62, 0.35 }, { 0.52, 0.75 }, { 0.2, 1.0 }, { -0.25, 0.95 }, { -0.52, 0.6 }, { -0.45, 0.2 } }
part("Ears", nil, DARK, function(mesh)
	for n, side in { -1, 1 } do
		Scrap.metalFin(EAR, 0.1, 1.0, { 0.35, 0.7 }, function(m)
			Kit.turn(m, "x", 180)
			Kit.turn(m, "x", side * 28)
			Kit.turn(m, "z", side * 18)
			return m:translate(HX + 0.15, side * 0.42, HZ + 0.42)
		end, n):emit(mesh)
	end
end, 40, 0.35)
local eyes = {}
for _, side in { -1, 1 } do
	local p, n = HEADL.normal(0.55, side * 68)
	table.insert(eyes, { p, n })
end
Scrap.googlyEyes(eyes, 0.11)

-- The sandals: a cork footbed on a rubber outsole, two wide leather
-- straps arched over the foot with a buckle each; the toes' nails show
-- at the front.
local FOOT = {}
for k = 0, 15 do
	local t = k / 16 * 2 * math.pi
	table.insert(FOOT, { 0.52 * math.cos(t) + 0.04, 0.36 * math.sin(t) * (1 + 0.1 * math.cos(t)) })
end
part("Footbeds", nil, { 0.55, 0.42, 0.26 }, function(mesh)
	for _, side in { -1, 1 } do
		local bed = Kit.plate(FOOT, 0.08)
		Kit.turn(bed, "x", -90)
		bed:translate(0, side * LEGY, 0.1)
		bed:emit(mesh)
	end
end, 40, 0.6)
part("Outsoles", nil, { 0.12, 0.12, 0.12 }, function(mesh)
	for _, side in { -1, 1 } do
		local sole = Kit.plate(FOOT, 0.05)
		Kit.turn(sole, "x", -90)
		Kit.size(sole, { 1.03, 1.03, 1 })
		sole:translate(0, side * LEGY, 0.05)
		sole:emit(mesh)
	end
end, 40, RUBBER)
local STRAPS = { -0.12, 0.26 } -- the straps' x on each foot
part("Straps", nil, { 0.42, 0.26, 0.14 }, function(mesh)
	for _, side in { -1, 1 } do
		for _, x in STRAPS do
			local strap = EditMesh.arch(0.37, 0.03, 0.15, 14)
			Kit.turn(strap, "z", 90)
			strap:translate(x, side * LEGY, 0.14)
			strap:emit(mesh)
		end
	end
end, 40, 0.5)
part("Buckles", nil, { 0.75, 0.72, 0.6 }, function(mesh)
	for _, side in { -1, 1 } do
		for _, x in STRAPS do
			local frame = EditMesh.tube(0.075, 0.05, 0.03, 4)
			Kit.turn(frame, "z", 45)
			Kit.turn(frame, "x", side * -55)
			frame:translate(x, side * (LEGY + 0.32), 0.4)
			frame:emit(mesh)
		end
	end
end, true, 0.2)
part("Toenails", nil, { 0.88, 0.86, 0.78 }, function(mesh)
	for _, side in { -1, 1 } do
		for _, a in { 150, 180, -150 } do
			local p, n = W.normal((if side < 0 then 10 else 20) + 0.2, a)
			local nail = EditMesh.sphere(0.075, 8)
			nail:transform(function(q)
				local d = q[1] * n[1] + q[2] * n[2] + q[3] * n[3]
				return { q[1] - n[1] * d * 0.7 + p[1] + n[1] * 0.01, q[2] - n[2] * d * 0.7 + p[2] + n[2] * 0.01, q[3] - n[3] * d * 0.7 + p[3] + n[3] * 0.01 }
			end)
			nail:emit(mesh)
		end
	end
end, true, 0.1)
finishParts()
