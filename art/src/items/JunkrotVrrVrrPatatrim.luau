-- Vrr Vrr Patatrim: Brr Brr Patapim from scrap. A monkey's head, far too
-- big for its body, with a big round cartoon nose between the eyes, short
-- and broad, wider than it is tall, a friendly smile under it, small
-- close-set googly eyes under a heavy brow, an orange copper face in a pale tin mane; a mop of green
-- sheet-metal leaves for hair, spreading down a hunched mossy back; two
-- thick moss-and-bark trunk legs; thin knobbly root pipes for arms hanging
-- to the ground; and two enormous bare feet of pale tin, five toes each
-- with nail plates. Every surface is mismatched scrap plates. About 4 studs
-- tall, nose +x.
-- include: JunkrotScrap

-- A rigid frame: turns (as Kit.turn, in order) then a move; place() for
-- points, rot() for directions.
local function frame(turns, move)
	local function rot(p)
		local q = { p[1], p[2], p[3] }
		for _, t in turns do
			local a = math.rad(t[2])
			local c, s = math.cos(a), math.sin(a)
			local x, y, z = q[1], q[2], q[3]
			if t[1] == "x" then
				q = { x, y * c - z * s, y * s + z * c }
			elseif t[1] == "y" then
				q = { x * c + z * s, y, -x * s + z * c }
			else
				q = { x * c - y * s, x * s + y * c, z }
			end
		end
		return q
	end
	local function place(p)
		local q = rot(p)
		return { q[1] + move[1], q[2] + move[2], q[3] + move[3] }
	end
	return { rot = rot, place = place }
end
-- Stands a piece built up +z along n at p.
local function stand(m, p, n)
	Kit.turn(m, "y", math.deg(math.acos(math.clamp(n[3], -1, 1))))
	Kit.turn(m, "z", math.deg(math.atan2(n[2], n[1])))
	return m:translate(p[1], p[2], p[3])
end
-- A fixed scatter in [-1, 1).
local function jitter(i, j)
	return math.fmod(math.sin(i * 12.9898 + j * 78.233) * 43758.5453, 1)
end

-- Several lofts, each in its own frame, plated by one Scrap.panelParts
-- call: a sub-loft's x is offset by its base (multiples of 10), and the
-- composite dispatches on it.
local SUBS = {}
local function sub(base, loft, f)
	SUBS[base] = { loft = loft, f = f }
	return base
end
local function pick(x)
	local base = math.floor(x / 10 + 0.5) * 10
	return SUBS[base], x - base
end
local BODY = {}
function BODY.on(x, a, lift)
	local s, lx = pick(x)
	return s.f.place(s.loft.on(lx, a, lift))
end
function BODY.skin(x, a)
	local s, lx = pick(x)
	return s.f.place(s.loft.skin(lx, a))
end
function BODY.normal(x, a)
	local s, lx = pick(x)
	local p, n = s.loft.normal(lx, a)
	return s.f.place(p), s.f.rot(n)
end
function BODY.station(x)
	local s, lx = pick(x)
	return s.loft.station(lx)
end
-- A sub-loft's skin, closed already, in the model's frame.
local function skinOf(base)
	local s = SUBS[base]
	return s.loft.mesh:copy():transform(s.f.place)
end
-- Plates for one sub-loft, its band cuts in its own x; the callbacks get
-- its own x too.
local PANELS = {}
local function plating(base, bands, spec)
	local shifted = {}
	for _, b in bands do
		local cuts = {}
		for _, x in b[3] do
			table.insert(cuts, base + x)
		end
		table.insert(shifted, { b[1], b[2], cuts })
	end
	local metal, open = spec.metal, spec.open
	spec.bands = shifted
	spec.metal = metal and function(b, seg, c, side, x0, x1, pale)
		return metal(b, seg, c, side, x0 - base, x1 - base, pale)
	end
	spec.open = open and function(b, x0, x1, side)
		return open(b, x0 - base, x1 - base, side)
	end
	for _, q in Scrap.panels(nil, spec) do
		table.insert(PANELS, q)
	end
end

-- The metals: moss greens and bark on the trunk and the hump, among the
-- usual scrap; copper tones for the face and nose; the pale metals for the
-- mane and the feet.
local MOSS = { "MOSS", { 0.3, 0.5, 0.2 } }
local LICHEN = { "LICHEN", { 0.46, 0.58, 0.26 } }
local VERDIGRIS = { "VERDIGRIS", { 0.33, 0.52, 0.4 } }
local BARK = { "BARK", { 0.4, 0.28, 0.17 } }
local B = Scrap.BACK_METALS -- BLUEGREY, OLIVE, RUST, GUNMETAL, PAINTED, BRASS
local TRUNK = { MOSS, LICHEN, BARK, MOSS, B[3], VERDIGRIS, B[2], MOSS, BARK, LICHEN, B[6], MOSS, B[4], LICHEN, B[1], MOSS, BARK, B[5], VERDIGRIS, MOSS }
local ORANGES = { { "COPPER", { 0.74, 0.42, 0.2 } }, { "BRONZE", { 0.62, 0.36, 0.17 } }, { "PEACH", { 0.86, 0.56, 0.32 } } }
local LEAF = { 0.32, 0.55, 0.2 }
local LEAF_DARK = { 0.22, 0.42, 0.16 }
local function hashed(list, b, seg, c, side, x0)
	local h = b * 7 + seg * 3 + c * 5 + (if side < 0 then 1 else 0) + math.floor(x0 * 3 + 9)
	return list[h % #list + 1]
end

-- Sizes: the whole is 4 studs tall; the feet take a tenth of the height
-- and are as long as the legs are tall; the head is a third of it.
local FOOT_Y = 0.52 -- each foot's centre line from the middle
local LEG_LEAN = 10 -- degrees the legs lean forward
local HEAD_AT = { 0.3, 0, 3.0 }
local HEAD_PITCH = 8
local FACE_X = 0.66 -- the head's flat front, in its own frame

-- Legs: each a trunk lofted up from inside its foot to the shoulder, where
-- the hump covers it. Up is +x in the loft; angle 0 is the back.
local function legLoft()
	return Scrap.loft({
		stations = {
			{ 0.0, 0.25, -0.25, 0.26 },
			{ 0.5, 0.29, -0.29, 0.3 },
			{ 1.1, 0.33, -0.33, 0.33 },
			{ 1.6, 0.36, -0.35, 0.36 },
			{ 1.9, 0.3, -0.3, 0.3 },
			{ 2.0, 0.1, -0.1, 0.1 },
		},
		sides = 20,
		steps = 30,
	})
end
local LEG_L = sub(0, legLoft(), frame({ { "y", -90 }, { "y", LEG_LEAN } }, { -0.1, -FOOT_Y, 0.2 }))
local LEG_R = sub(10, legLoft(), frame({ { "y", -90 }, { "y", LEG_LEAN } }, { -0.1, FOOT_Y, 0.2 }))

-- The hump: the hunched back over the legs' tops, the head sitting on its
-- front.
local HUMP = sub(20, Scrap.loft({
	stations = {
		{ -1.05, 0.1, -0.1, 0.2 },
		{ -0.8, 0.35, -0.42, 0.6 },
		{ -0.4, 0.48, -0.5, 0.8 },
		{ 0.05, 0.46, -0.5, 0.8 },
		{ 0.35, 0.28, -0.4, 0.6 },
		{ 0.5, 0.05, -0.1, 0.15 },
	},
	sides = 24,
	steps = 36,
}), frame({}, { 0, 0, 2.2 }))

-- The head: a round head lofted back to front, ending in a broad flat cap
-- where the face plate goes; pitched down a touch.
local HEAD = sub(30, Scrap.loft({
	stations = {
		{ -0.9, 0.14, -0.14, 0.17 },
		{ -0.66, 0.5, -0.5, 0.53 },
		{ -0.3, 0.72, -0.67, 0.7 },
		{ 0.18, 0.76, -0.72, 0.68 },
		{ 0.48, 0.7, -0.67, 0.62 },
		{ FACE_X, 0.62, -0.62, 0.56 },
	},
	sides = 24,
	steps = 40,
}), frame({ { "y", HEAD_PITCH } }, HEAD_AT))
local headF = SUBS[HEAD].f

-- The nose: a big round cartoon nose, short and broad, wider than it is
-- tall, out from the face between the eyes and tipped a little down; it
-- ends well above the smile. Angle 0 is its top.
local NOSE_ROOT = headF.place({ FACE_X - 0.04, 0, 0.08 })
local NOSE = sub(40, Scrap.loft({
	stations = {
		{ 0.0, 0.15, -0.13, 0.19 },
		{ 0.14, 0.19, -0.16, 0.25 },
		{ 0.28, 0.2, -0.16, 0.27 },
		{ 0.38, 0.15, -0.12, 0.21 },
		{ 0.44, 0.06, -0.05, 0.09 },
		{ 0.46, 0.01, -0.01, 0.015 },
	},
	sides = 20,
	steps = 16,
}), frame({ { "y", 30 } }, NOSE_ROOT))

-- The feet: each lofted heel to ball along x, flat-soled, high at the
-- ankle; the toes sit on its front.
local function footLoft()
	return Scrap.loft({
		stations = {
			{ -0.6, 0.12, 0.0, 0.2 },
			{ -0.45, 0.38, 0.0, 0.3 },
			{ -0.2, 0.5, 0.0, 0.34 },
			{ 0.2, 0.42, 0.0, 0.38 },
			{ 0.6, 0.3, 0.0, 0.44 },
			{ 0.9, 0.22, 0.0, 0.43 },
			{ 1.0, 0.1, 0.0, 0.38 },
		},
		sides = 24,
		steps = 40,
	})
end
local FOOT_L = sub(50, footLoft(), frame({ { "z", 6 } }, { 0, -FOOT_Y, 0 }))
local FOOT_R = sub(60, footLoft(), frame({ { "z", -6 } }, { 0, FOOT_Y, 0 }))

-- Toes: five to a foot, big toe inside, each a short loft with a nail
-- plate; given in a foot's own frame (inner side toward -y).
local TOES = { -- y across, length, half width, height
	{ -0.28, 0.42, 0.1, 0.2 },
	{ -0.08, 0.38, 0.085, 0.18 },
	{ 0.08, 0.34, 0.075, 0.17 },
	{ 0.23, 0.3, 0.07, 0.16 },
	{ 0.36, 0.25, 0.065, 0.14 },
}
local function toeMesh(t, inner)
	local l, w, h = t[2], t[3], t[4]
	return Scrap.loft({
		stations = {
			{ 0.78, h, 0.0, w * 0.9 },
			{ 0.78 + l * 0.5, h * 0.95, 0.0, w },
			{ 0.78 + l * 0.85, h * 0.8, 0.0, w * 0.95 },
			{ 0.78 + l, h * 0.35, 0.0, w * 0.6 },
		},
		at = { 0, t[1] * inner, 0 },
		sides = 12,
		steps = 8,
	}).mesh
end
local function nailMesh(t, inner)
	local l, w, h = t[2], t[3], t[4]
	local nail = Kit.block(l * 0.3, w * 1.3, 0.02, 0.006)
	return nail:translate(0.78 + l * 0.8, t[1] * inner, h * 0.62)
end

-- The body's skins under the plates: dark steel showing in the seams.
part("Body", nil, { 0.18, 0.19, 0.21 }, function(mesh)
	for _, base in { LEG_L, LEG_R, HUMP, HEAD, NOSE, FOOT_L, FOOT_R } do
		skinOf(base):emit(mesh)
	end
end, true, 0.4)

part("Toes", nil, { 0.78, 0.76, 0.7 }, function(mesh)
	for _, side in { -1, 1 } do
		local f = SUBS[if side < 0 then FOOT_L else FOOT_R].f
		for _, t in TOES do
			toeMesh(t, side):transform(f.place):emit(mesh)
		end
	end
end, true, 0.35)
part("Nails", nil, { 0.9, 0.88, 0.8 }, function(mesh)
	for _, side in { -1, 1 } do
		local f = SUBS[if side < 0 then FOOT_L else FOOT_R].f
		for _, t in TOES do
			nailMesh(t, side):transform(f.place):emit(mesh)
		end
	end
end, 40, 0.2)

-- Arms: knobbly root pipes from the shoulders down the sides to the feet,
-- three root fingers at the end of each resting on the foot.
part("Arms", nil, { 0.4, 0.27, 0.16 }, function(mesh)
	for _, side in { -1, 1 } do
		local path = Kit.curve({
			{ -0.05, side * 0.7, 2.25 },
			{ 0.05, side * 1.0, 1.85 },
			{ 0.0, side * 1.05, 1.3 },
			{ 0.25, side * 0.9, 0.8 },
			{ 0.45, side * 0.74, 0.55 },
		}, 5)
		Kit.tube(path, function(t)
			return (0.11 - 0.05 * t) * (1 + 0.18 * math.sin(t * 29))
		end, 8):emit(mesh)
		local hand = path[#path]
		local wrist = path[#path - 3]
		for k = -1, 1 do
			Kit.tube(Kit.curve({ wrist, hand, { hand[1] + 0.2, hand[2] + side * k * 0.1, 0.4 }, { hand[1] + 0.42 + 0.05 * k, hand[2] + side * k * 0.12, 0.21 } }, 3), function(t)
				return 0.04 - 0.015 * t
			end, 6):emit(mesh)
		end
	end
end, true, 0.6)

-- The face: a sheet over the head's flat front, worked into a monkey's
-- face: a heavy brow ridge across the top, hollows under it for the eyes
-- either side of the nose's root, the muzzle swelling below; copper.
local FACE_W, FACE_H = 0.54, 0.6
local function faceBump(u, v) -- u across (+ to the left), v up, both -1..1
	local brow = math.exp(-((v - 0.62) / 0.16) ^ 2) * (0.09 + 0.03 * (1 - u * u))
	local eye = (math.exp(-((math.abs(u) - 0.48) / 0.22) ^ 2 - ((v - 0.38) / 0.16) ^ 2)) * 0.05
	local muzzle = math.exp(-((v + 0.3) / 0.5) ^ 2 - (u / 0.7) ^ 2) * 0.07
	local cheek = math.exp(-((math.abs(u) - 0.75) / 0.25) ^ 2 - ((v - 0.1) / 0.3) ^ 2) * 0.03
	return brow - eye + muzzle + cheek
end
local function faceSheet()
	local m = EditMesh.new()
	local N = 12
	local ids = {}
	for i = 0, N do
		ids[i] = {}
		for j = 0, N do
			local u, v = -1 + 2 * i / N, -1 + 2 * j / N
			local du, dv = u * math.sqrt(1 - v * v / 2), v * math.sqrt(1 - u * u / 2)
			ids[i][j] = m:addVertex(FACE_X + faceBump(du, dv), du * FACE_W, dv * FACE_H)
		end
	end
	for i = 0, N - 1 do
		for j = 0, N - 1 do
			m:addFace({ ids[i][j], ids[i][j + 1], ids[i + 1][j + 1], ids[i + 1][j] })
		end
	end
	m:solidify(0.07)
	return m
end
local function onFace(u, v, out) -- a point in front of the face sheet
	local du, dv = u * math.sqrt(1 - v * v / 2), v * math.sqrt(1 - u * u / 2)
	return headF.place({ FACE_X + faceBump(du, dv) + (out or 0), du * FACE_W, dv * FACE_H })
end
part("Face", nil, ORANGES[1][2], function(mesh)
	faceSheet():transform(headF.place):emit(mesh)
end, true, 0.35)
-- A friendly smile under the nose: one dark groove curving up at the ends.
part("Mouth", nil, { 0.2, 0.12, 0.08 }, function(mesh)
	local path = {}
	for k = 0, 12 do
		local u = -0.45 + 0.9 * k / 12
		table.insert(path, onFace(u, -0.55 + 0.35 * u * u, 0.004))
	end
	Kit.tube(path, 0.016, 6):emit(mesh)
end, true, 0)
-- Small googly eyes, close set either side of the nose's root, under the
-- brow.
local eyes = {}
for _, side in { -1, 1 } do
	table.insert(eyes, { onFace(side * 0.42, 0.36), headF.rot({ 1, 0, 0.1 }) })
end
Scrap.googlyEyes(eyes, 0.095)

-- The hair: a mop of ragged sheet-metal leaves shingled over the top and
-- back of the head, wider than the head, framing the face down to the
-- cheeks; a few more as moss tufts on the hump.
local function leaf(i, j, size)
	local w, h = size * (0.9 + 0.2 * jitter(i, j)), size * 1.15 * (0.9 + 0.2 * jitter(j, i))
	local m = Kit.plate({ { -w / 2, 0 }, { -w * 0.55, h * 0.45 }, { -w * 0.3, h * 0.85 }, { 0, h }, { w * 0.3, h * 0.88 }, { w * 0.5, h * 0.5 }, { w / 2, 0 } }, 0.02)
	m:translate(0, -0.01, 0)
	-- Leant over like a shingle, turned a little either way.
	Kit.turn(m, "x", 38 + 14 * jitter(i + 3, j))
	Kit.turn(m, "z", 25 * jitter(i, j + 5))
	return m
end
local function leaves(dark, mesh)
	local n = 0
	local function put(base, x, a, size)
		n += 1
		if (n % 2 == 0) ~= dark then
			return
		end
		local p, nrm = BODY.normal(base + x, a)
		local m = leaf(n, math.floor(a), size)
		-- Spun so it leans down and back, away from the face.
		Kit.turn(m, "z", 180 + 0.6 * a)
		stand(m, p, nrm):emit(mesh)
	end
	for _, x in { -0.82, -0.6, -0.38, -0.16, 0.06, 0.28, 0.5 } do
		for _, a in { 0, -24, 24, -48, 48, -72, 72, -96, 96 } do
			local front = x > 0.3
			if (front and math.abs(a) > 50) or (math.abs(a) > 80 and x > 0.1) then
				continue
			end
			put(HEAD, x, a, if front then 0.26 else 0.36)
		end
	end
	for _, x in { -0.95, -0.7, -0.45, -0.2 } do
		for _, a in { 0, -40, 40, -80, 80 } do
			put(HUMP, x, a, 0.3)
		end
	end
end
part("Leaves", nil, LEAF, function(mesh)
	leaves(false, mesh)
end, 40, 0.3)
part("LeavesDark", nil, LEAF_DARK, function(mesh)
	leaves(true, mesh)
end, 40, 0.3)

-- The plating. Legs and hump: moss and bark among the usual scrap. Head:
-- copper over the brow, greens over the top and back under the leaves,
-- pale mane round the face and under the chin. Nose: copper rings. Feet:
-- pale metals, the sole left bare.
for _, leg in { LEG_L, LEG_R } do
	plating(leg, {
		{ 0, 60, { 0, 0.5, 1.2, 1.75, 2.0 } },
		{ 60, 120, { 0, 0.3, 0.9, 1.5, 2.0 } },
		{ 120, 180, { 0, 0.7, 1.1, 1.8, 2.0 } },
	}, {
		splits = { [2] = 0.5, [5] = 0.4, [9] = 0.6, [14] = 0.45 },
		metal = function(b, seg, c, side, x0)
			return hashed(TRUNK, b, seg, c, side, x0 + leg)
		end,
	})
end
plating(HUMP, {
	{ 0, 55, { -1.05, -0.6, -0.1, 0.5 } },
	{ 55, 115, { -1.05, -0.75, -0.3, 0.15, 0.5 } },
	{ 115, 180, { -1.05, -0.5, 0.0, 0.5 } },
}, {
	splits = { [3] = 0.55, [7] = 0.4 },
	metal = function(b, seg, c, side, x0)
		return hashed(TRUNK, b + 2, seg, c, side, x0)
	end,
})
plating(HEAD, {
	{ 0, 45, { -0.9, -0.5, -0.1, 0.3, FACE_X } },
	{ 45, 95, { -0.9, -0.55, -0.15, 0.25, FACE_X } },
	{ 95, 140, { -0.9, -0.45, 0.0, 0.35, FACE_X } },
	{ 140, 180, { -0.9, -0.4, 0.1, FACE_X } },
}, {
	paleFrom = 45,
	splits = { [4] = 0.5, [9] = 0.4 },
	metal = function(b, seg, c, side, x0)
		if b == 1 then
			return if x0 >= 0.3 then ORANGES[(seg + c) % 3 + 1] else hashed({ MOSS, LICHEN, VERDIGRIS, MOSS }, b, seg, c, side, x0)
		end
		if x0 < (if b == 4 then -0.4 else -0.15) then
			return hashed({ MOSS, LICHEN, BARK, VERDIGRIS }, b, seg, c, side, x0)
		end
		return nil
	end,
})
plating(NOSE, {
	{ 0, 90, { 0, 0.2, 0.46 } },
	{ 90, 180, { 0, 0.26, 0.46 } },
}, {
	metal = function(b, seg, c, side, x0)
		return hashed(ORANGES, b, seg, c, side, x0)
	end,
})
for _, foot in { FOOT_L, FOOT_R } do
	plating(foot, {
		{ 0, 50, { -0.6, -0.3, 0.2, 0.65, 1.0 } },
		{ 50, 110, { -0.6, -0.15, 0.4, 1.0 } },
		{ 110, 150, { -0.6, 0.0, 0.5, 1.0 } },
	}, {
		paleFrom = 0,
		splits = { [3] = 0.5, [8] = 0.4 },
	})
end
Scrap.panelParts(BODY, PANELS, {})
finishParts()
