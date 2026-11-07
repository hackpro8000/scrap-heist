-- Ballerina Tincuppina: a friendly Ballerina Cappuccina bent from scrap.
-- A cappuccino cup for a head, a little dancer under it; the cup a lofted
-- tin bowl in pale cream plates, its handle out to one side, crema in it
-- with a rosetta drawn in cream wire; on its front big googly eyes under
-- soft arched brows, rosy cheeks and a small closed smile; a pink tin
-- bodice, a tutu of pink sheet-metal petals fanned round her hips, warm
-- copper arms in a port de bras (one raised beside the cup, one held out)
-- and legs crossed on two pink pointe shoes. Face +x. 3.8 studs tall.
-- (The first, scarier take is kept in art/archive/BallerinaCappuccinaScrap.luau.)
-- include: JunkrotScrap
local COPPER = { 0.9, 0.66, 0.52 } -- her limbs, warm like skin
local PINK = { 0.93, 0.6, 0.7 }
local PINKS = { { "ROSE", { 0.93, 0.6, 0.7 } }, { "BLUSH", { 0.97, 0.76, 0.8 } }, { "PEACH", { 0.95, 0.7, 0.62 } } }
local DARK = { 0.18, 0.19, 0.21 }
local CREAM = { 0.9, 0.86, 0.78 } -- under the cup's plates: seams read pale, not dark

local HIP = 1.75 -- the top of her legs
local SHOULDER = 2.42
local CUP0 = 2.62 -- the cup's base
local CUPH = 1.2 -- rim height above the base
local TUTU = 1.86

-- The cup: a loft along x (x = height above the base), turned upright so
-- its nominal angle 180 (the loft's underside) faces +x: the face there,
-- the handle at +y (nominal 90). Scrap.panels still runs on it through
-- the wrapper below, which maps the loft's frame into the world.
local L = Scrap.loft({
	stations = { -- height, r, -r, r
		{ 0, 0.32, -0.32, 0.32 },
		{ 0.06, 0.44, -0.44, 0.44 },
		{ 0.22, 0.59, -0.59, 0.59 },
		{ 0.45, 0.71, -0.71, 0.71 },
		{ 0.72, 0.79, -0.79, 0.79 },
		{ 0.98, 0.83, -0.83, 0.83 },
		{ CUPH, 0.85, -0.85, 0.85 },
	},
	sides = 28,
	steps = 30,
})
local function W(p)
	return { -p[3], p[2], p[1] + CUP0 }
end
local Cup = { station = L.station, x0 = L.x0, x1 = L.x1, at = { 0, 0, 0 } }
function Cup.skin(x, a)
	return W(L.skin(x, a))
end
function Cup.normal(x, a)
	local p, n = L.normal(x, a)
	return W(p), { -n[3], n[2], n[1] }
end
function Cup.on(x, a, lift)
	return W(L.on(x, a, lift))
end
-- The rim's cap goes: the cup is open, crema inside it.
for _, id in L.mesh:select("face", "facing", { 1, 0, 0 }, 20):filter(function(p)
	return p[1] > CUPH - 0.02
end):list() do
	L.mesh:removeFace(id)
end
Kit.turn(L.mesh, "y", -90)
L.mesh:translate(0, 0, CUP0)
Cup.mesh = L.mesh

part("Cup", nil, CREAM, function(mesh)
	Scrap.skinPart(Cup, {}, 0.035):emit(mesh)
end, true, 0.4)
part("Rim", nil, { 0.78, 0.8, 0.8 }, function(mesh)
	-- A rolled bead round the rim.
	local ring = {}
	for k = 0, 36 do
		local p = Cup.skin(CUPH - 0.005, 180 - k * 10)
		table.insert(ring, p)
	end
	Kit.tube(ring, 0.04, 8):emit(mesh)
end, true, 0.3)
part("Handle", nil, { 0.72, 0.7, 0.66 }, function(mesh)
	-- A bent wire loop out of the +y side.
	local a = Cup.skin(0.9, 90)
	local b = Cup.skin(0.34, 90)
	local path = Kit.curve({
		{ a[1], a[2] - 0.05, a[3] },
		{ a[1], a[2] + 0.2, a[3] + 0.04 },
		{ b[1], b[2] + 0.42, b[3] + 0.26 },
		{ b[1], b[2] + 0.22, b[3] - 0.08 },
		{ b[1], b[2] - 0.06, b[3] },
	}, 5)
	Kit.tube(path, 0.055, 8):emit(mesh)
end, true, 0.3)

-- Her body: a pink tin bodice from the hips to the bust, the bare chest,
-- shoulders and neck in copper above it.
local BODICE = { { 0, 0 }, { 0.3, 0 }, { 0.31, 0.06 }, { 0.22, 0.24 }, { 0.26, 0.42 }, { 0.31, 0.56 }, { 0, 0.56 } }
local CHEST = { { 0, 0 }, { 0.31, 0 }, { 0.3, 0.06 }, { 0.26, 0.15 }, { 0.13, 0.2 }, { 0.1, 0.3 }, { 0, 0.3 } }
part("Bodice", nil, PINK, function(mesh)
	local m = Kit.lathe(BODICE, 16)
	Kit.size(m, { 0.8, 1, 1 })
	m:translate(0, 0, HIP - 0.02)
	m:emit(mesh)
end, true, 0.15)
part("Chest", nil, COPPER, function(mesh)
	local m = Kit.lathe(CHEST, 16)
	Kit.size(m, { 0.8, 1, 1 })
	m:translate(0, 0, HIP + 0.52)
	m:emit(mesh)
	-- Thin wire straps over the shoulders.
	for _, side in { -1, 1 } do
		Kit.tube(Kit.curve({ { 0.2, side * 0.18, HIP + 0.54 }, { 0, side * 0.2, HIP + 0.69 }, { -0.2, side * 0.18, HIP + 0.54 } }, 4), 0.016, 6):emit(mesh)
	end
	-- The neck, into the cup's base.
	Kit.tube({ { 0, 0, HIP + 0.78 }, { 0, 0, CUP0 + 0.06 } }, 0.09, 10):emit(mesh)
end, true, 0.3)

-- Limbs: copper wire. The +y arm raised beside the cup, its hand bent in
-- over the rim; the -y arm held out level, the hand drooping. The legs
-- cross to two feet on pointe, the +y leg in front.
local function wire(points, r0, r1)
	return Kit.tube(Kit.curve(points, 5), function(t)
		return r0 + (r1 - r0) * t
	end, 8)
end
local HANDS = {}
part("Arms", nil, COPPER, function(mesh)
	wire({ { 0, 0.22, SHOULDER }, { 0.04, 0.62, 2.7 }, { 0.02, 0.98, 3.08 }, { -0.02, 1.02, 3.4 }, { -0.04, 0.9, 3.58 } }, 0.085, 0.065):emit(mesh)
	wire({ { 0, -0.22, SHOULDER }, { 0.14, -0.66, 2.47 }, { 0.3, -1.04, 2.52 }, { 0.36, -1.22, 2.44 } }, 0.085, 0.065):emit(mesh)
end, true, 0.25)
part("Legs", nil, COPPER, function(mesh)
	wire({ { 0, 0.13, HIP }, { 0.1, 0.1, 1.2 }, { 0.2, -0.02, 0.4 } }, 0.1, 0.07):emit(mesh)
	wire({ { 0, -0.13, HIP }, { -0.02, -0.14, 1.2 }, { -0.04, -0.16, 0.4 } }, 0.1, 0.07):emit(mesh)
end, true, 0.25)
part("Hands", nil, COPPER, function(mesh)
	-- Flat little tin hands on the wire ends, along the wire's last run.
	local function hand(at, tilt)
		local m = Kit.plate({ { -0.06, 0 }, { 0.06, 0 }, { 0.085, 0.07 }, { 0.07, 0.15 }, { 0, 0.18 }, { -0.07, 0.15 }, { -0.085, 0.07 } }, 0.05)
		m:translate(0, -0.025, -0.03)
		Kit.turn(m, "x", tilt)
		m:translate(at[1], at[2], at[3])
		return m
	end
	hand({ -0.04, 0.9, 3.58 }, 33):emit(mesh)
	hand({ 0.36, -1.22, 2.44 }, 115):emit(mesh)
end, true, 0.25)
part("Shoes", nil, PINK, function(mesh)
	-- Pointe shoes stood on their toe platforms, the legs' wire into them.
	for _, foot in { { 0.2, -0.02 }, { -0.04, -0.16 } } do
		local m = Kit.lathe({ { 0, 0 }, { 0.075, 0 }, { 0.09, 0.05 }, { 0.105, 0.2 }, { 0.115, 0.36 }, { 0.1, 0.44 }, { 0.06, 0.46 }, { 0, 0.46 } }, 12)
		Kit.size(m, { 1.15, 0.9, 1 })
		m:translate(foot[1], foot[2], 0)
		m:emit(mesh)
		-- Ribbons wound up the ankle.
		local path = {}
		for k = 0, 16 do
			local t = k / 16
			local a = t * math.pi * 2.5
			table.insert(path, { foot[1] + math.cos(a) * (0.09 - 0.03 * t), foot[2] + math.sin(a) * (0.085 - 0.03 * t), 0.4 + 0.3 * t })
		end
		Kit.tube(path, 0.018, 6):emit(mesh)
	end
end, true, 0.15)

-- In the cup: crema a little below the rim, a rosetta drawn on it in
-- cream wire, its leaf tip toward her face.
local CREMA = CUP0 + CUPH - 0.1
part("Crema", nil, { 0.74, 0.52, 0.3 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.84, 0 }, { 0.84, 0.03 }, { 0, 0.03 } }, 28)
	m:translate(0, 0, CREMA - 0.03)
	m:emit(mesh)
end, true, 0.2)
part("Rosetta", nil, { 0.95, 0.9, 0.8 }, function(mesh)
	local z = CREMA + 0.012
	Kit.tube({ { -0.48, 0, z }, { 0.5, 0, z } }, 0.028, 6):emit(mesh)
	for k = 1, 5 do
		local x = 0.44 - 0.16 * k
		local w = 0.4 - 0.045 * k
		for _, side in { -1, 1 } do
			Kit.tube(Kit.curve({ { x + 0.06, 0, z }, { x - 0.1, side * w * 0.6, z }, { x - 0.3, side * w, z } }, 4), 0.026, 6):emit(mesh)
		end
	end
end, true, 0)

-- The face on the cup's front: big googly eyes, soft brows arched high
-- over them, rosy cheeks and a small closed smile.
local eyes = {}
for _, side in { -1, 1 } do
	local p, n = Cup.normal(0.56, side * 164)
	table.insert(eyes, { p, n })
end
Scrap.googlyEyes(eyes, 0.18)
part("FaceWire", nil, { 0.36, 0.22, 0.16 }, function(mesh)
	for _, side in { -1, 1 } do
		local brow = {}
		for k = 0, 8 do
			local t = k / 8
			table.insert(brow, Cup.on(0.84 + 0.05 * math.sin(math.pi * t), side * (175 - 20 * t), 0.05))
		end
		Kit.tube(brow, 0.02, 6):emit(mesh)
	end
	local smile = {}
	for k = 0, 12 do
		local t = -1 + k / 6
		local side = if t < 0 then -1 else 1
		table.insert(smile, Cup.on(0.3 + 0.06 * t * t, side * (180 - 13 * math.abs(t)), 0.05))
	end
	Kit.tube(smile, 0.024, 6):emit(mesh)
end, true, 0.1)
part("Cheeks", nil, { 0.97, 0.62, 0.66 }, function(mesh)
	for _, side in { -1, 1 } do
		local p, n = Cup.normal(0.36, side * 150)
		local cheek = EditMesh.sphere(0.075, 8)
		cheek:transform(function(q)
			local d = q[1] * n[1] + q[2] * n[2] + q[3] * n[3]
			return { q[1] - n[1] * d * 0.65 + p[1] + n[1] * 0.04, q[2] - n[2] * d * 0.65 + p[2] + n[2] * 0.04, q[3] - n[3] * d * 0.65 + p[3] + n[3] * 0.04 }
		end)
		cheek:emit(mesh)
	end
end, true, 0)

-- The tutu: pink sheet-metal petals fanned round her hips, each in two
-- pieces riveted at the seam (Scrap.metalFin's way, in pink metals),
-- alternately drooping more and less so they layer.
local tutuPieces, tutuRivets = {}, {}
local function pinkFin(outline, thick, span, cuts, place, first)
	local edges = { -10 }
	for _, c in cuts do
		table.insert(edges, c)
	end
	table.insert(edges, 10)
	for k = 1, #edges - 1 do
		local lo = edges[k] + (if k > 1 then 0.012 else 0)
		local hi = edges[k + 1] - (if k < #edges - 1 then 0.012 else 0)
		local piece = Scrap.clipBand(outline, lo, hi)
		if #piece >= 3 then
			local metal = PINKS[(first + k - 1) % #PINKS + 1]
			table.insert(tutuPieces, { metal = metal[1], mesh = place(Scrap.fin(piece, thick, span)) })
		end
	end
	for _, c in cuts do
		local band = Scrap.clipBand(outline, c - 0.001, c + 0.001)
		local xs = {}
		for _, q in band do
			table.insert(xs, q[1])
		end
		table.sort(xs)
		if #xs >= 2 then
			local xa, xb = xs[1], xs[#xs]
			local half = thick / 2 * math.max(0.12, 1 - 0.85 * math.clamp(c / span, 0, 1))
			for _, t in { 0.25, 0.75 } do
				for _, side in { -1, 1 } do
					for _, dz in { -0.045, 0.045 } do
						local r = EditMesh.sphere(0.02, 6)
						r:translate(xa + (xb - xa) * t, side * (half + 0.004), c + dz)
						table.insert(tutuRivets, place(r))
					end
				end
			end
		end
	end
	return place(Scrap.fin(outline, thick * 0.45, span))
end
local PETAL = { { 0.16, 0 }, { 0.27, 0.45 }, { 0.26, 0.72 }, { 0.1, 0.78 }, { -0.1, 0.78 }, { -0.26, 0.72 }, { -0.27, 0.45 }, { -0.16, 0 } }
part("TutuCore", nil, { 0.78, 0.48, 0.56 }, function(mesh)
	for k = 0, 11 do
		local droop = if k % 2 == 0 then 12 else 26
		local lift = if k % 2 == 0 then 0.05 else 0
		pinkFin(PETAL, 0.07, 0.78, { 0.36 }, function(m)
			m:translate(0, 0, 0.18)
			Kit.turn(m, "z", 90)
			Kit.turn(m, "y", 90 + droop)
			Kit.turn(m, "z", k * 30 + 15)
			return m:translate(0, 0, TUTU + lift)
		end, k):emit(mesh)
	end
end, 40, 0.3)
for _, metal in PINKS do
	part("Tutu" .. metal[1], nil, metal[2], function(mesh)
		for _, piece in tutuPieces do
			if piece.metal == metal[1] then
				piece.mesh:emit(mesh)
			end
		end
	end, 40, 0.05)
end
part("TutuRivets", nil, DARK, function(mesh)
	for _, r in tutuRivets do
		r:emit(mesh)
	end
end, true, 0.4)

-- The cup's plating: pale metals all round, bands of mismatched cuts up
-- the wall, openings where the eyes sit.
local panels = Scrap.panels(Cup, {
	bands = {
		{ 0, 40, { 0, 0.28, 0.66, 0.9, CUPH } },
		{ 40, 75, { 0, 0.45, 0.58, 0.98, CUPH } },
		{ 75, 110, { 0, 0.18, 0.5, 0.86, CUPH } },
		{ 110, 148, { 0, 0.36, 0.76, CUPH } },
		{ 148, 180, { 0, 0.24, CUPH } },
	},
	paleFrom = 0,
	splits = { [2] = 0.5, [6] = 0.4, [11] = 0.6, [15] = 0.35, [20] = 0.55, [26] = 0.45 },
	-- Her face side clean white china, unrusted, so nothing smudges it.
	metal = function(band)
		if band >= 4 then
			return { "CHINA", { 0.95, 0.94, 0.9 } }
		end
		return nil
	end,
})
Scrap.panelParts(Cup, panels, { rust = { CHINA = 0, ENAMEL = 0.1, TIN = 0.15, ALUMINIUM = 0.1, GALVANISED = 0.15 } })
finishParts()
