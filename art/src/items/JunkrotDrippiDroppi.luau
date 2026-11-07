-- Drippi Droppi: Trippi Troppi from scrap. A shrimp of copper plate, nose
-- forward (+x), carried level on ten thin wire legs: a fat carapace whose
-- front edge hoods over a tin cat's head, a segmented abdomen curling down
-- behind it to a fanned tail resting on the ground, bead eyes on stalks on
-- top of the shell, long antennae swept back. The cat's head has pointed
-- ears, a muzzle with a pink nose and wire whiskers, and its own yellow
-- cat eyes. About 3.3 studs tall.
-- include: JunkrotScrap
local MIDDLE = 1.85 -- the carapace's axis height
local HEAD = { 1.55, 0, 1.8 } -- the cat head's middle
local HEAD_R = 0.58
local DARK_COPPER = { 0.32, 0.18, 0.1 }
local TIN = { 0.7, 0.72, 0.72 }

-- The carapace's front edge: the hood over the cat's head. From x = 1.05
-- the rim climbs from the bottom of the section to 75 degrees from the top
-- at the shell's front; the skin below it is cut away, the head shows.
local HOOD_FROM, HOOD_TO = 1.05, 1.95
local function hoodAngle(x)
	if x <= HOOD_FROM or x > HOOD_TO + 0.01 then
		return nil
	end
	local t = math.clamp((x - HOOD_FROM) / (HOOD_TO - HOOD_FROM), 0, 1)
	return 180 - 105 * (t * t * (3 - 2 * t)) ^ 0.7
end
-- Segment boundaries along the abdomen, tail to carapace.
local SEGMENTS = { -1.5, -1.2, -0.8, -0.3, 0.2 }

-- The body: carapace fat and level, the abdomen behind it curling down to
-- a slim tail end just off the ground.
local L = Scrap.loft({
	stations = { -- x, top, bottom, half width (from the axis)
		{ -1.8, -1.02, -1.28, 0.12 },
		{ -1.5, -0.72, -1.2, 0.22 },
		{ -1.2, -0.36, -1.0, 0.3 },
		{ -0.8, 0.04, -0.74, 0.38 },
		{ -0.3, 0.38, -0.6, 0.46 },
		{ 0.2, 0.6, -0.58, 0.52 },
		{ 0.7, 0.7, -0.62, 0.58 },
		{ 1.2, 0.72, -0.6, 0.62 },
		{ 1.6, 0.68, -0.52, 0.63 },
		{ 1.95, 0.52, -0.4, 0.5 },
	},
	at = { 0, 0, MIDDLE },
	splits = {
		{ nominal = 120, tag = "hood", angle = hoodAngle },
	},
})
-- The shell's front is open: the head comes out of it.
for _, id in L.mesh:select("face", "where", function(p)
	return p[1] > HOOD_TO - 0.005
end):list() do
	L.mesh:removeFace(id)
end

-- The skin under the plates: dark copper, showing in the seams.
part("Body", nil, DARK_COPPER, function(mesh)
	Scrap.skinPart(L, { drop = { "hood" } }, 0.04):emit(mesh)
end, true, 0.5)

-- Ribs round the section at each segment's edge, proud of the plates: the
-- shell's telescoping joints.
part("Ribs", nil, { 0.42, 0.24, 0.12 }, function(mesh)
	local ring = {}
	for k = 0, 7 do
		local r = math.rad(k * 45)
		table.insert(ring, { math.cos(r) * 0.04, math.sin(r) * 0.03 })
	end
	for _, x in SEGMENTS do
		local path = {}
		for k = 0, 23 do
			local a = -180 + 360 * k / 24
			table.insert(path, L.on(x, a, 0.045))
		end
		EditMesh.sweep(ring, path, { closed = true }):emit(mesh)
	end
end, true, 0.5)

-- The tail fan: five lobes of sheet metal spread from the tail's end,
-- sloping down and back so their tips rest on the ground.
local TAIL = { -1.72, 0, MIDDLE - 1.15 }
part("TailFan", nil, DARK_COPPER, function(mesh)
	for k = -2, 2 do
		local long = if k == 0 then 1.0 else 0.92
		Scrap.metalFin({ { -0.13, 0 }, { 0.13, 0 }, { 0.24, long * 0.5 }, { 0.06, long }, { -0.14, long * 0.92 }, { -0.24, long * 0.5 } }, 0.1, long, { long * 0.45 }, function(m)
			Kit.turn(m, "y", -125)
			Kit.turn(m, "z", k * 26)
			return m:translate(TAIL[1], TAIL[2], TAIL[3])
		end, 2 + k):emit(mesh)
	end
end, 40, 0.4)

-- Ten wire legs under the carapace, each bent at a knee, standing on the
-- ground; short paddles (swimmerets) under the abdomen.
part("Legs", nil, { 0.5, 0.3, 0.15 }, function(mesh)
	for i = 0, 4 do
		local x = 0.45 + i * 0.28
		for _, side in { -1, 1 } do
			local root = L.skin(x, side * 150)
			local path = Kit.curve({
				{ root[1], root[2] * 0.8, root[3] + 0.12 },
				{ root[1] + 0.05, root[2] + side * 0.28, root[3] - 0.45 },
				{ root[1] + 0.22 + i * 0.03, root[2] + side * 0.18, 0.02 },
			}, 4)
			Kit.tube(path, function(t)
				return 0.048 - 0.02 * t
			end, 6):emit(mesh)
		end
	end
	for i = 1, 4 do
		local x = -0.1 - i * 0.3
		for _, side in { -1, 1 } do
			local root = L.skin(x, side * 160)
			local paddle = Kit.plate({ { -0.07, 0 }, { 0.07, 0 }, { 0.06, -0.26 }, { -0.03, -0.32 }, { -0.1, -0.24 } }, 0.025)
			Kit.turn(paddle, "z", side * -25)
			Kit.turn(paddle, "y", -20)
			paddle:translate(root[1], root[2] * 0.9, root[3] + 0.04)
			paddle:emit(mesh)
		end
	end
end, true, 0.4)
-- The cat's head: a tin ball with the ears pulled up out of it, a muzzle
-- pushed out of its front, the eye sockets sunk in; smoothed once so the
-- pulls round off. It sits in the shell's hood, the shell's front edge
-- over its brow.
local function catHead()
	local m = EditMesh.sphere(HEAD_R, 24)
	for _, side in { -1, 1 } do
		local ear = m:select("face", "facing", { -0.1, side * 0.6, 1 }, 26):filter(function(p)
			return p[2] * side > 0.12 and p[2] * side < 0.46 and p[3] > 0.26 and p[1] > -0.24 and p[1] < 0.2
		end)
		if ear:count() > 0 then
			local tip = m:extrude(ear, 0.42)
			tip:scale(0.12)
			tip:move({ -0.02, side * 0.12, 0.12 })
		end
	end
	local muzzle = m:select("face", "facing", { 1, 0, -0.25 }, 24):filter(function(p)
		return math.abs(p[2]) < 0.3 and p[3] > -0.36 and p[3] < 0.02
	end)
	if muzzle:count() > 0 then
		local front = m:extrude(muzzle, 0.1)
		front:scale({ 1, 0.8, 0.75 })
	end
	for _, side in { -1, 1 } do
		local socket = m:select("face", "facing", { 1, side * 0.5, 0.35 }, 20):filter(function(p)
			return p[2] * side > 0.1 and p[2] * side < 0.38 and p[3] > 0.04 and p[3] < 0.3
		end)
		if socket:count() > 0 then
			m:extrude(m:inset(socket, 0.015, 0), -0.04)
		end
	end
	m:smoothSubdivide(1)
	return m:translate(HEAD[1], HEAD[2], HEAD[3])
end
local HEAD_MESH = catHead()
-- The head's surface point out along d from its middle: the vertex that
-- lies most nearly that way.
local function onHead(d)
	d = EditMesh.vec.unit(d)
	local best, bestDot = nil, -2
	for _, v in HEAD_MESH.verts do
		local q = v.position
		local r = EditMesh.vec.unit({ q[1] - HEAD[1], q[2] - HEAD[2], q[3] - HEAD[3] })
		local dot = EditMesh.vec.dot(r, d)
		if dot > bestDot then
			best, bestDot = q, dot
		end
	end
	return best
end
part("Head", nil, TIN, function(mesh)
	HEAD_MESH:copy():emit(mesh)
end, true, 0.4)
-- Where an eye sits: on the head's surface, looking out along d.
local function eyeAt(side)
	local d = EditMesh.vec.unit({ 1, side * 0.5, 0.35 })
	local p = { HEAD[1] + d[1] * (HEAD_R - 0.06), HEAD[2] + d[2] * (HEAD_R - 0.06), HEAD[3] + d[3] * (HEAD_R - 0.06) }
	return p, d
end
-- A ball flattened along n (keeping `keep` of its depth), set at c.
local function lens(radius, c, n, keep, squeeze)
	local ball = EditMesh.sphere(radius, 12)
	return ball:transform(function(q)
		local s = { q[1], q[2] * (squeeze or 1), q[3] }
		local d = s[1] * n[1] + s[2] * n[2] + s[3] * n[3]
		return { s[1] - n[1] * d * (1 - keep) + c[1], s[2] - n[2] * d * (1 - keep) + c[2], s[3] - n[3] * d * (1 - keep) + c[3] }
	end)
end
-- The cat's own eyes: yellow lenses in the sockets, black slit pupils.
part("Eyes", nil, { 0.85, 0.75, 0.2 }, function(mesh)
	for _, side in { -1, 1 } do
		local p, n = eyeAt(side)
		lens(0.125, { p[1] + n[1] * 0.02, p[2] + n[2] * 0.02, p[3] + n[3] * 0.02 }, n, 0.5):emit(mesh)
	end
end, true, 0)
part("Pupils", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, side in { -1, 1 } do
		local p, n = eyeAt(side)
		local out = 0.125 * 0.5 + 0.03
		lens(0.085, { p[1] + n[1] * out, p[2] + n[2] * out, p[3] + n[3] * out }, n, 0.3, 0.35):emit(mesh)
	end
end, true, 0)
part("Nose", nil, { 0.85, 0.45, 0.5 }, function(mesh)
	local nose = Kit.plate({ { -0.07, 0.05 }, { 0.07, 0.05 }, { 0.0, -0.06 } }, 0.03)
	Kit.turn(nose, "z", 90)
	Kit.turn(nose, "y", 20)
	nose:translate(HEAD[1] + HEAD_R + 0.07, 0, HEAD[3] - 0.08)
	nose:emit(mesh)
end, true, 0)
part("Whiskers", nil, DARK_STEEL, function(mesh)
	for _, side in { -1, 1 } do
		for k = -1, 1 do
			local a = onHead({ 1, side * 0.45, -0.3 + k * 0.08 })
			local b = { HEAD[1] + HEAD_R + 0.3, side * 0.72, HEAD[3] - 0.14 + k * 0.12 }
			Kit.tube({ { a[1] - 0.03, a[2], a[3] }, a, b }, 0.012, 4):emit(mesh)
		end
	end
	-- A mouth line under the nose: a thin dark seam.
	for _, side in { -1, 1 } do
		Kit.tube(Kit.curve({ { HEAD[1] + HEAD_R + 0.09, 0, HEAD[3] - 0.15 }, { HEAD[1] + HEAD_R + 0.07, side * 0.07, HEAD[3] - 0.21 }, { HEAD[1] + HEAD_R + 0.02, side * 0.14, HEAD[3] - 0.19 } }, 4), 0.012, 4):emit(mesh)
	end
end, true, 0.2)
-- The shrimp's own eyes: black beads on stalks up out of the shell's top,
-- and its antennae: two long wires swept back over the body, two short
-- ones forward.
part("Stalks", nil, DARK_STEEL, function(mesh)
	for _, side in { -1, 1 } do
		local p = L.on(1.3, side * 28, -0.02)
		Kit.tube({ p, { p[1] + 0.1, p[2] + side * 0.06, p[3] + 0.22 } }, 0.03, 6):emit(mesh)
	end
end, true, 0.3)
part("Beads", nil, { 0.05, 0.05, 0.06 }, function(mesh)
	for _, side in { -1, 1 } do
		local p = L.on(1.3, side * 28, -0.02)
		EditMesh.sphere(0.08, 10):translate(p[1] + 0.11, p[2] + side * 0.065, p[3] + 0.25):emit(mesh)
	end
end, true, 0)
part("Antennae", nil, { 0.6, 0.38, 0.2 }, function(mesh)
	for _, side in { -1, 1 } do
		local root = L.on(1.85, side * 22, -0.02)
		Kit.tube(Kit.curve({ root, { root[1] - 0.15, root[2] + side * 0.1, root[3] + 0.55 }, { root[1] - 1.2, root[2] + side * 0.3, root[3] + 0.75 }, { root[1] - 2.6, root[2] + side * 0.4, root[3] + 0.3 } }, 5), function(t)
			return 0.026 - 0.012 * t
		end, 5):emit(mesh)
		local short = L.on(1.9, side * 40, -0.02)
		Kit.tube(Kit.curve({ short, { short[1] + 0.35, short[2] + side * 0.2, short[3] + 0.12 }, { short[1] + 0.75, short[2] + side * 0.4, short[3] - 0.1 } }, 4), 0.018, 4):emit(mesh)
	end
end, true, 0.4)
-- Tabby stripes: dark strips stuck on the brow between the ears and the
-- eyes, and along each cheek.
local function stuck(plate, d, lift)
	d = EditMesh.vec.unit(d)
	Kit.turn(plate, "z", 90)
	Kit.turn(plate, "y", -math.deg(math.asin(d[3])))
	Kit.turn(plate, "z", math.deg(math.atan2(d[2], d[1])))
	local o = onHead(d)
	return plate:translate(o[1] + d[1] * lift, o[2] + d[2] * lift, o[3] + d[3] * lift)
end
part("Stripes", nil, { 0.3, 0.31, 0.33 }, function(mesh)
	for _, d in { { 1, -0.16, 0.5 }, { 1, 0, 0.56 }, { 1, 0.16, 0.5 } } do
		stuck(Kit.plate({ { -0.03, -0.09 }, { 0.03, -0.09 }, { 0.025, 0.09 }, { -0.025, 0.09 } }, 0.06), d, 0.025):emit(mesh)
	end
	for _, side in { -1, 1 } do
		for k = -1, 1 do
			local strip = Kit.plate({ { -0.11, -0.025 }, { 0.11, -0.025 }, { 0.09, 0.025 }, { -0.09, 0.025 } }, 0.06)
			stuck(strip, { 0.45, side, 0.05 + k * 0.22 }, 0.025):emit(mesh)
		end
	end
end, true, 0.2)

-- The plating: the abdomen's plates cut at the segments' edges, one ring
-- of plates to a segment, the carapace in longer mismatched plates; the
-- metals mostly copper, with rust and brass and the odd stray sheet,
-- paler under the belly. The hood's underside is bare: the head is there.
local COPPER = { "COPPER", { 0.72, 0.42, 0.22 } }
local panels = Scrap.panels(L, {
	bands = {
		{ 0, 35, { -1.8, -1.5, -1.2, -0.8, -0.3, 0.2, 0.9, 1.4, 1.95 } },
		{ 35, 80, { -1.8, -1.5, -1.2, -0.8, -0.3, 0.2, 0.55, 1.2, 1.95 } },
		{ 80, 120, { -1.8, -1.5, -1.2, -0.8, -0.3, 0.2, 0.75, 1.1, 1.5, 1.95 } },
		{ 120, 150, { -1.8, -1.5, -1.2, -0.8, -0.3, 0.2, 0.65, 1.05 } },
		{ 150, 180, { -1.8, -1.5, -1.2, -0.8, -0.3, 0.2, 0.8, 1.05 } },
	},
	paleFrom = 150,
	splits = { [4] = 0.5, [9] = 0.4, [15] = 0.6, [22] = 0.45, [30] = 0.55, [37] = 0.35 },
	noSplitFrom = 1.05,
	metal = function(band, seg, cell, side, x0, _, pale)
		if pale then
			return nil
		end
		local n = (band * 7 + seg * 3 + cell * 5 + (if side < 0 then 4 else 0)) % 11
		if n < 5 then
			return COPPER
		elseif n < 8 then
			return Scrap.BACK_METALS[3]
		elseif n < 10 then
			return Scrap.BACK_METALS[6]
		end
		return Scrap.BACK_METALS[1]
	end,
})
Scrap.panelParts(L, panels, { rivetsUpTo = 1.9 })
finishParts()
