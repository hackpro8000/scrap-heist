-- Clank Clank Clank Scrapur: Tung Tung Tung Sahur from scrap. After the
-- picture: a tall plain log, its height three times its width, standing
-- on thin legs two thirds as long as the log, thin arms hanging from its
-- sides two fifths of the way up, one hand holding a bat whose thick end
-- rests on the ground. The face in the log's upper half: two huge round
-- staring eyes near the edges with arched brows over them, a long nose
-- from between the eyes down to a bulb, a wide thin grin under it. Here
-- the log is a length of rusty pipe skinned in mismatched plates, the
-- face worked into the pipe itself (eyes bulging out of sunk sockets,
-- nose and brows raised, the grin a slot), rebar limbs, a rebar bat.
-- 4 studs tall.
-- include: JunkrotScrap
local FOOT = 1.45 -- the log's bottom; it stands on its legs
local TOP = 4.0
local R = 0.42 -- the pipe's radius
local IRON = { 0.2, 0.17, 0.15 }

-- The loft runs along x (bottom to top) with the front at its top (angle
-- 0); it is turned upright afterwards: loft x up, loft top to the front.
local function up(p)
	return { -p[2], -p[3], p[1] }
end

-- The face, as heights along the pipe (loft x) and angles from the front.
local EYE = { x = 3.42, a = 33, r = 0.16 } -- centre height, centre angle, radius
local EYE_SPAN = math.deg(EYE.r / R)
local MOUTH = { corner = 2.82, wide = 50, centre = 2.70, half = 0.03 }
-- The eye's rim: lower and upper edge of a round outline, rounded off
-- short of a point at top and bottom so no ring vertex collapses.
local function eyeHalf(x)
	local t = (x - EYE.x) / EYE.r
	if math.abs(t) >= 1 then
		return nil
	end
	return EYE_SPAN * math.max(0.15, math.sqrt(1 - t * t))
end
local function lipAngle(from, to)
	return function(x)
		if x < from or x > to then
			return nil
		end
		return MOUTH.wide * math.sqrt((x - from) / (to - from))
	end
end
local upperLip = lipAngle(MOUTH.centre + MOUTH.half, MOUTH.corner + 0.012)
local lowerLip = lipAngle(MOUTH.centre - MOUTH.half, MOUTH.corner)

local L = Scrap.loft({
	stations = { -- x, top, bottom, half width: a round pipe, lipped at both ends
		{ FOOT, 0.03, -0.03, 0.03 },
		{ FOOT + 0.03, R - 0.02, -(R - 0.02), R - 0.02 },
		{ FOOT + 0.1, R + 0.02, -(R + 0.02), R + 0.02 },
		{ FOOT + 0.2, R, -R, R },
		{ TOP - 0.16, R, -R, R },
		{ TOP - 0.08, R + 0.025, -(R + 0.025), R + 0.025 },
		{ TOP - 0.02, R, -R, R },
		{ TOP, 0.03, -0.03, 0.03 },
	},
	sides = 72,
	steps = 92,
	splits = {
		{ nominal = 10, tag = "lipUp", angle = upperLip },
		{ nominal = 15, tag = "lipLow", angle = lowerLip },
		{ nominal = 25, tag = "eyeIn", angle = function(x)
			local h = eyeHalf(x)
			return if h then EYE.a - h else nil
		end },
		{ nominal = 55, tag = "eyeOut", angle = function(x)
			local h = eyeHalf(x)
			return if h then EYE.a + h else nil
		end },
	},
})
local M = L.mesh
local function angleOf(p) -- a point's angle from the front, in the loft frame
	return math.deg(math.atan2(math.abs(p[2]), p[3]))
end

-- The eyes: the round region between the rims, a thin rim inset, the
-- socket sunk, then the eyeball domed up out of it, well proud of the
-- pipe: the stare.
local eyeCentres = {}
local PLAIN = false
for _, side in (if PLAIN then {} else { -1, 1 }) do
	local region = M:select("face", "tag", "eyeIn"):minus(M:select("face", "tag", "eyeOut")):filter(function(p)
		return p[2] * side > 0
	end)
	local inner = M:inset(region, 0.02, 0)
	local cap = M:extrude(inner, -0.03)
	local c = L.skin(EYE.x, side * EYE.a)
	M:transform(function(p)
		local d = { p[1] - c[1], p[2] - c[2], p[3] - c[3] }
		local r = math.sqrt(d[1] ^ 2 + d[2] ^ 2 + d[3] ^ 2) / (EYE.r - 0.02)
		local lift = 0.11 * math.sqrt(math.max(0, 1 - r * r))
		local a = math.rad(angleOf(p)) * side
		return { p[1], p[2] + math.sin(a) * lift, p[3] + math.cos(a) * lift }
	end, cap)
	cap:tag("eye")
	eyeCentres[side] = c
end
-- The nose: a strip down the front from between the eyes, raised, its
-- lower end swelling into the bulb.
local NOSE = { top = 3.5, tip = 2.98 }
local nose = M:select("face", "where", function(p)
	if p[1] < NOSE.tip or p[1] > NOSE.top then
		return false
	end
	local bulb = math.clamp((NOSE.tip + 0.17 - p[1]) / 0.17, 0, 1)
	return angleOf(p) < 7 + 7 * bulb
end)
local noseCap = if PLAIN then nil else M:extrude(nose, 0.04)
if not PLAIN then M:transform(function(p)
	local down = math.clamp((NOSE.top - p[1]) / (NOSE.top - NOSE.tip), 0, 1)
	local bulb = math.clamp((NOSE.tip + 0.17 - p[1]) / 0.17, 0, 1)
	return { p[1], p[2] * (1 + 0.3 * bulb), p[3] + 0.03 * down + 0.07 * bulb }
end, noseCap) end
-- The brows: an arched band over each eye, raised.
local brows = M:select("face", "where", function(p)
	local a = angleOf(p)
	if a < 10 or a > 58 then
		return false
	end
	local arch = 3.63 + 0.05 * ((a - EYE.a) / EYE_SPAN) ^ 2
	return p[1] > arch and p[1] < arch + 0.09
end)
if not PLAIN then M:extrude(brows, 0.045) end
-- The grin: the faces between the lips, sunk into a slot.
local grin = M:select("face", "where", function(p)
	if p[1] < MOUTH.centre - MOUTH.half or p[1] > MOUTH.corner then
		return false
	end
	local a = angleOf(p)
	local u, l = upperLip(p[1]), lowerLip(p[1])
	return l ~= nil and a < l and (u == nil or a > u)
end)
if not PLAIN then M:extrude(grin, -0.05):tag("mouth") end

-- Upright: loft x up, loft top to the front (-y). W is the loft as the
-- plating and skin see it, in the model's frame.
Kit.turn(M, "y", -90)
Kit.turn(M, "z", 90)
local W = { mesh = M, station = L.station, x0 = L.x0, x1 = L.x1, at = L.at }
function W.skin(x, a)
	return up(L.skin(x, a))
end
function W.normal(x, a)
	local p, n = L.normal(x, a)
	return up(p), up(n)
end
function W.on(x, a, lift)
	return up(L.on(x, a, lift))
end

part("Body", nil, RUST_ORANGE, function(mesh)
	Scrap.skinPart(W, { drop = { "eye", "mouth" } }):emit(mesh)
end, 40, 0.75)
part("Eyes", nil, { 0.93, 0.92, 0.88 }, function(mesh)
	Scrap.skinPart(W, { keep = "eye" }, 0.02):emit(mesh)
end, true, 0.2)
part("Mouth", nil, { 0.08, 0.06, 0.05 }, function(mesh)
	Scrap.skinPart(W, { keep = "mouth" }, 0.02):emit(mesh)
end, 40, 0.3)
part("Pupils", nil, { 0.16, 0.08, 0.04 }, function(mesh)
	-- A big dark iris on each dome, a black pupil in it.
	for _, side in { -1, 1 } do
		local c = eyeCentres[side] or L.skin(EYE.x, side * EYE.a)
		local a = math.rad(EYE.a) * side
		local n = up({ 0, math.sin(a), math.cos(a) })
		local centre = up(c)
		for _, disc in { { 0.085, 0.11 - 0.012 }, { 0.04, 0.11 + 0.004 } } do
			local iris = EditMesh.sphere(disc[1], 10)
			Kit.size(iris, { 1, 1, 0.3 })
			Kit.turn(iris, "x", -side * EYE.a)
			local m = Kit.turn(iris, "y", -90)
			Kit.turn(m, "z", 90)
			m:translate(centre[1] + n[1] * disc[2], centre[2] + n[2] * disc[2], centre[3] + n[3] * disc[2])
			m:emit(mesh)
		end
	end
end, true, 0.2)

-- Limbs: rebar. Arms from the pipe's sides two fifths of the way up,
-- hanging to the pipe's bottom, slightly bent; legs under the pipe down
-- to flat feet turned a little out. The bat hangs from the right hand,
-- its thick end on the ground ahead and out to the side.
local BAT = { { 0.48, -0.22, 1.8 }, { 1.05, -0.95, 0.1 } }
local function alongBat(t)
	return { BAT[1][1] + (BAT[2][1] - BAT[1][1]) * t, BAT[1][2] + (BAT[2][2] - BAT[1][2]) * t, BAT[1][3] + (BAT[2][3] - BAT[1][3]) * t }
end
local GRIP = alongBat(0.1)
local SHOULDER = FOOT + 0.4 * (TOP - FOOT)
local HANDS = { [-1] = { -0.5, -0.2, 1.42 }, [1] = GRIP }
part("Limbs", nil, IRON, function(mesh)
	for _, side in { -1, 1 } do
		local hand = HANDS[side]
		Kit.tube(Kit.curve({ { side * 0.3, 0, SHOULDER }, { side * 0.52, -0.03, SHOULDER - 0.5 }, hand }, 5), 0.06, 8):emit(mesh)
		Kit.tube(Kit.curve({ { side * 0.2, 0.02, FOOT + 0.1 }, { side * 0.25, 0.0, 0.8 }, { side * 0.24, -0.06, 0.12 } }, 5), 0.065, 8):emit(mesh)
		local foot = Kit.block(0.2, 0.52, 0.1, 0.03)
		foot:translate(0, -0.1, 0)
		Kit.turn(foot, "z", -side * 14)
		foot:translate(side * 0.26, -0.02, 0.05)
		foot:emit(mesh)
	end
end, true, 0.8)
part("Hands", nil, { 0.26, 0.23, 0.2 }, function(mesh)
	for _, side in { -1, 1 } do
		local hand = HANDS[side]
		local m = Kit.block(0.15, 0.12, 0.18, 0.04)
		m:translate(hand[1], hand[2], hand[3] - 0.04)
		m:emit(mesh)
	end
end, true, 0.6)
part("Bat", nil, DARK_STEEL, function(mesh)
	local path = {}
	for k = 0, 16 do
		table.insert(path, alongBat(k / 16))
	end
	Kit.tube(path, function(t)
		local knob = if t < 0.03 then 0.02 else 0
		return 0.045 + knob + 0.065 * math.clamp((t - 0.25) / 0.6, 0, 1) ^ 1.2
	end, 10):emit(mesh)
end, true, 0.7)
part("Ribs", nil, DARK_STEEL, function(mesh)
	-- Rebar ribs along the bat.
	for k = 1, 5 do
		local c = alongBat(0.2 + k * 0.1)
		local rib = EditMesh.torus(0.05 + 0.065 * math.clamp((0.2 + k * 0.1 - 0.25) / 0.6, 0, 1) ^ 1.2, 0.012, 10, 6)
		local d = { BAT[2][1] - BAT[1][1], BAT[2][2] - BAT[1][2], BAT[2][3] - BAT[1][3] }
		local len = math.sqrt(d[1] ^ 2 + d[2] ^ 2 + d[3] ^ 2)
		Kit.turn(rib, "y", math.deg(math.acos(d[3] / len)))
		Kit.turn(rib, "z", math.deg(math.atan2(d[2], d[1])))
		rib:translate(c[1], c[2], c[3])
		rib:emit(mesh)
	end
end, true, 0.7)

-- The plating: bands round the pipe with cuts of different heights, the
-- front open where the face is, warm and rusty metals mostly.
local panels = Scrap.panels(W, {
	bands = {
		{ 0, 22, { FOOT + 0.05, 2.0, 2.55, 3.85, TOP - 0.03 } },
		{ 22, 62, { FOOT + 0.05, 1.8, 2.25, 2.55, 3.85, TOP - 0.03 } },
		{ 62, 98, { FOOT + 0.05, 2.1, 2.4, 3.0, 3.3, 3.7, TOP - 0.03 } },
		{ 98, 136, { FOOT + 0.05, 1.75, 2.6, 2.85, 3.5, TOP - 0.03 } },
		{ 136, 180, { FOOT + 0.05, 2.0, 2.3, 3.1, 3.6, TOP - 0.03 } },
	},
	splits = { [2] = 0.4, [5] = 0.55, [9] = 0.35, [14] = 0.6, [19] = 0.5 },
	open = function(band, x0, x1)
		return band <= 2 and x1 > 2.5 and x0 < 3.9
	end,
	metal = function(band, seg, cell, side)
		local n = band * 3 + seg * 2 + cell + (if side < 0 then 1 else 0)
		if n % 3 == 0 then
			return Scrap.BACK_METALS[3]
		elseif n % 5 == 0 then
			return Scrap.BACK_METALS[6]
		end
		return nil
	end,
})
Scrap.panelParts(W, panels, { rivetsUpTo = TOP })
finishParts()
