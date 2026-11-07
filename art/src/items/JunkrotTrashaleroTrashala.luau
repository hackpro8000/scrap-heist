-- Trashalero Trashala: Tralalero Tralala riveted from tin sheet. A blue
-- shark with a white belly, nose forward (+x), its two pectoral fins and
-- its pelvic fin hanging down as legs into blue sneakers with white soles.
-- One lofted body shaped like a shark: a conical snout over a crescent
-- mouth on the underside, its corners back behind the eyes near the gills;
-- the lower jaw is the head's own bottom slice hinged there, hanging open
-- on two rows of triangular teeth; the dorsal, tail and pelvic fins are pulled out
-- of the body and the pectorals shaped from their outline,
-- the eyes sit in sockets sunk into it, the gill slits and nostrils are
-- recessed into it. No googly face. 3 studs tall, 4.5 long.
-- include: JunkrotKit
local TIN_BLUE = { 0.4, 0.5, 0.6 } -- grey-blue, as the shark is
local BELLY = { 0.88, 0.89, 0.86 }
local GULLET = { 0.3, 0.07, 0.09 }
local SNEAKER_BLUE = { 0.14, 0.46, 0.92 }
local MIDDLE = 1.75 -- the body's middle line: it stands about a body's depth off the ground
-- The sneakers stand here, on the pectoral fins' tips and the pelvic fin's.
local STANDS = { { 0.6, -0.5 }, { 0.6, 0.5 }, { -1.0, 0 } }

-- The body's half height and half width along x, tail end to nose tip,
-- read off these stations between; eased, except along the snout, which
-- runs straight to its point.
local STATIONS = {
	{ -1.6, 0.105, 0.078 },
	{ -1.3, 0.195, 0.156 },
	{ -0.8, 0.375, 0.312 },
	{ -0.2, 0.525, 0.437 },
	{ 0.5, 0.585, 0.499 },
	{ 1.0, 0.555, 0.484 },
	{ 1.4, 0.45, 0.437 },
	{ 1.7, 0.33, 0.359 },
	{ 1.95, 0.195, 0.234 },
	{ 2.1, 0.09, 0.125 },
	{ 2.2, 0.038, 0.062 },
	{ 2.24, 0.011, 0.02 },
}
local SNOUT = 1.4
local function station(x)
	for k = 1, #STATIONS - 1 do
		local a, b = STATIONS[k], STATIONS[k + 1]
		if x <= b[1] then
			local t = math.clamp((x - a[1]) / (b[1] - a[1]), 0, 1)
			if a[1] < SNOUT then
				t = t * t * (3 - 2 * t)
			end
			return a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
		end
	end
	local last = STATIONS[#STATIONS]
	return last[2], last[3]
end
-- The snout's underside runs flat and a touch upward to the tip, the top
-- sloping down to meet it: it lifts by this.
local function lift(x)
	return 0.07 * math.clamp((x - 1.5) / 0.72, 0, 1)
end
local UNDER = 0.85 -- the lower half is this much of the upper: a flatter belly
-- The skin's underside at x, y, from the middle line.
local function skinBottom(x, y)
	local h, w = station(x)
	return lift(x) - h * UNDER * math.sqrt(math.max(0, 1 - (y / w) ^ 2))
end

-- The mouth: a crescent on the underside, its corners back behind the eyes
-- near the gills, round the front just ahead of them, short of the snout.
-- mouthPoint(a) walks its rim from one corner (a = -90) round the front
-- (0) to the other (90).
local CORNER = { x = 1.3, spread = 0.85 } -- the corners: x, and y as a share of the width there
local MOUTH_REACH = 0.42 -- how far ahead of the corners the rim goes
local function mouthPoint(a)
	local r = math.rad(a)
	local x = CORNER.x + MOUTH_REACH * math.cos(r) ^ 0.8
	local _, w = station(x)
	local y = w * CORNER.spread * math.sin(r)
	return { x, y, skinBottom(x, y) }
end
-- The jaw is the head's own bottom slice inside that rim, split off along
-- a flat plane at the corners' height and hinged there; the body keeps the
-- roof of the mouth at that plane.
local ROOF = mouthPoint(-90)[3] + 0.03
local HINGE = { CORNER.x, ROOF }
local GAPE = 14 -- degrees the jaw hangs open: a grin, the teeth showing
local function inMouth(x, y)
	local along = (x - CORNER.x) / MOUTH_REACH
	if along <= 0 or along >= 1 then
		return false
	end
	local a = math.acos(along ^ 1.25)
	local _, w = station(x)
	return math.abs(y) < w * CORNER.spread * math.sin(a)
end
local EYE = { 1.62, select(2, station(1.62)) * 0.9, 0.1 } -- from the middle line

-- Pulls a fin out of the faces picked, in steps, each thinning it.
local function pullFin(m, faces, steps, thin)
	local fin = faces
	for _, step in steps do
		fin = m:extrude(fin, step)
		fin:scale(thin)
	end
	return fin
end

local function shark()
	local ring, path = {}, {}
	for k = 0, 15 do
		local r = math.rad(k * 22.5)
		table.insert(ring, { math.cos(r), math.sin(r) })
	end
	for k = 0, 32 do
		table.insert(path, { -1.6 + 3.84 * k / 32, 0, 0 })
	end
	local m = EditMesh.sweep(ring, path)
	-- Each ring sized to its station, the belly flatter than the back.
	m:transform(function(p)
		local h, w = station(p[1])
		local z = p[3]
		return { p[1], p[2] * w, lift(p[1]) + (if z < 0 then z * h * UNDER else z * h) }
	end)
	-- Fins, pulled out of the body: the dorsal raked back, the tail's two
	-- lobes, the pectorals down and out into the sneakers, the pelvic down
	-- under the tail.
	local function patch(dir, deg, test)
		return m:select("face", "facing", dir, deg):filter(test)
	end
	m:tagging("fins", function()
		-- The first dorsal: tall, triangular, raked back to a point.
		pullFin(m, patch({ 0, 0, 1 }, 25, function(p)
			return p[1] > 0.1 and p[1] < 0.85 and math.abs(p[2]) < 0.15
		end), { { -0.12, 0, 0.3 }, { -0.15, 0, 0.3 }, { -0.18, 0, 0.25 }, { -0.15, 0, 0.15 } }, { 0.72, 0.5, 0.8 })
		-- The second dorsal, small, over the tail root.
		pullFin(m, patch({ 0, 0, 1 }, 30, function(p)
			return p[1] > -1.0 and p[1] < -0.7 and math.abs(p[2]) < 0.1
		end), { { -0.08, 0, 0.12 }, { -0.08, 0, 0.08 } }, { 0.6, 0.5, 0.7 })
		-- The tail: a tall upper lobe sweeping up and back, a shorter lower one.
		pullFin(m, patch({ 0, 0, 1 }, 35, function(p)
			return p[1] < -1.25 and math.abs(p[2]) < 0.1
		end), { { -0.22, 0, 0.4 }, { -0.26, 0, 0.4 }, { -0.26, 0, 0.35 }, { -0.22, 0, 0.3 }, { -0.15, 0, 0.2 } }, { 0.84, 0.6, 0.88 })
		pullFin(m, patch({ 0, 0, -1 }, 35, function(p)
			return p[1] < -1.25 and math.abs(p[2]) < 0.1
		end), { { -0.2, 0, -0.32 }, { -0.22, 0, -0.3 }, { -0.2, 0, -0.25 }, { -0.12, 0, -0.15 } }, { 0.82, 0.58, 0.85 })
		-- The legs: each pectoral fin runs on down as a thick limb of shark
		-- skin into its sneaker, the pelvic fin the same under the tail.
		for _, side in { -1, 1 } do
			pullFin(m, patch({ 0, side * 0.6, -0.8 }, 32, function(p)
				return p[1] > 0.3 and p[1] < 0.95
			end), { { 0.02, side * 0.05, -0.3 }, { 0.02, side * 0.03, -0.3 }, { 0, 0, -0.26 }, { 0, 0, -0.12 } }, { 0.9, 0.9, 1 })
		end
		pullFin(m, patch({ 0, 0, -1 }, 30, function(p)
			return p[1] > -1.15 and p[1] < -0.8 and math.abs(p[2]) < 0.15
		end), { { 0, 0, -0.3 }, { 0, 0, -0.3 }, { 0, 0, -0.28 }, { 0, 0, -0.25 }, { 0, 0, -0.12 } }, { 0.9, 0.86, 1 })
	end)
	-- Eye sockets, sunk into the sides of the head above the mouth's front.
	for _, side in { -1, 1 } do
		local socket = patch({ 0, side, 0.3 }, 28, function(p)
			return p[1] > 1.48 and p[1] < 1.78 and p[3] > -0.05 and p[3] < 0.3
		end)
		if socket:count() > 0 then
			m:extrude(m:inset(socket, 0.03, 0), -0.06)
		end
	end
	m:smoothSubdivide(1)
	-- Gill slits, five a side, and the nostrils under the snout: recessed.
	for _, side in { -1, 1 } do
		for k = 0, 4 do
			-- On every other column of faces, so no two slits touch.
			local x = 1.25 - k * 0.12
			local slit = patch({ 0, side, 0 }, 50, function(p)
				return p[1] > x - 0.02 and p[1] < x + 0.02 and p[3] > -0.3 and p[3] < 0.45
			end):minus(m:select("face", "tag", "fins"))
			if slit:count() > 0 then
				Kit.recess(m, slit, 0.02, 0.05)
			end
		end
		local nare = patch({ 0, 0, -1 }, 50, function(p)
			return p[1] > 1.94 and p[1] < 2.06 and p[2] * side > 0.04 and p[2] * side < 0.14
		end)
		if nare:count() > 0 then
			Kit.recess(m, nare, 0.008, 0.025)
		end
	end
	-- The mouth: everything inside its rim below the roof is the jaw's, so
	-- the body's skin there lifts to the roof plane.
	m:transform(function(p)
		if inMouth(p[1], p[2]) and p[3] < ROOF then
			return { p[1], p[2], ROOF }
		end
		return p
	end)
	m:translate(0, 0, MIDDLE)
	return m
end
local body = shark()

-- The head's bottom slice inside the mouth's rim: rings of the skin's
-- underside between the rim's sides, flat across the top at the roof.
local function jaw()
	local m = EditMesh.new()
	local rings = {}
	local across = 12
	for i = 0, 16 do
		local p = mouthPoint(90 - i * 5.3)
		local x, reach = p[1], math.max(p[2], 0.02)
		local ring = {}
		for k = 0, across do
			local y = -reach + 2 * reach * k / across
			table.insert(ring, m:addVertex(x, y, math.min(skinBottom(x, y), ROOF - 0.015)))
		end
		for k = across - 1, 1, -1 do
			local y = -reach + 2 * reach * k / across
			table.insert(ring, m:addVertex(x, y, ROOF - 0.015))
		end
		table.insert(rings, ring)
	end
	for i = 1, #rings - 1 do
		local a, b = rings[i], rings[i + 1]
		for k = 1, #a do
			local k2 = k % #a + 1
			m:addFace({ a[k], b[k], b[k2], a[k2] })
		end
	end
	local front = {}
	for k = #rings[#rings], 1, -1 do
		table.insert(front, rings[#rings][k])
	end
	m:addFace(rings[1])
	m:addFace(front)
	m:flip()
	return m
end
-- Places a piece built round the mouth (from the middle line) onto the
-- hanging jaw: turned open about the hinge line through the corners.
local function onJaw(m)
	m:translate(-HINGE[1], 0, -HINGE[2])
	Kit.turn(m, "y", GAPE)
	return m:translate(HINGE[1], 0, MIDDLE + HINGE[2])
end
-- Keeps only the faces of m that pass the test, as a thin skin.
local function skinOf(m, test, out)
	local keep = m:select("face", "where", test)
	for _, id in m:select("face", "all"):minus(keep):list() do
		m:removeFace(id)
	end
	m:push(m:select("vertex", "all"), out)
	m:solidify(0.012)
	return m
end

part("Body", nil, TIN_BLUE, function(mesh)
	body:emit(mesh)
end, true, 0.35)
part("Belly", nil, BELLY, function(mesh)
	-- The underside, fins and mouth left out, lifted off a hair with its own
	-- thickness.
	local belly = body:copy()
	local fins = belly:select("face", "tag", "fins")
	local down = belly:select("face", "facing", { 0, 0, -1 }, 80):minus(fins)
	skinOf(belly, function(p, id)
		return down:count() > 0 and down.ids[id] ~= nil and p[1] > -1.4 and p[1] < 2.1 and not (inMouth(p[1], p[2]) and p[3] > MIDDLE + ROOF - 0.03)
	end, 0.004):emit(mesh)
end, true, 0.25)
part("Jaw", nil, BELLY, function(mesh)
	onJaw(jaw()):emit(mesh)
end, true, 0.25)
part("Mouth", nil, GULLET, function(mesh)
	-- The inside: the roof, lining the body's mouth plane, and the jaw's
	-- top, in the same dark red.
	local roof = body:copy()
	skinOf(roof, function(p)
		return inMouth(p[1], p[2]) and p[3] > MIDDLE + ROOF - 0.03
	end, 0.006):emit(mesh)
	local floor = jaw()
	skinOf(floor, function(p)
		return p[3] > ROOF - 0.03
	end, 0.006)
	onJaw(floor):emit(mesh)
end, true, 0)
part("Pectorals", nil, TIN_BLUE, function(mesh)
	-- Each pectoral fin shaped from its outline: a straight leading edge
	-- sweeping back from the root to a pointed tip, a concave trailing edge
	-- back to the root's rear; thick at the root, thinning to the edges.
	-- Rooted at the back of the leg's top, in the body's own plane and
	-- tilted out a touch, it sweeps down and back along the leg.
	for _, side in { -1, 1 } do
		local fin = Kit.plate({ { 0.3, -0.1 }, { 0.05, 0.42 }, { -0.25, 0.8 }, { -0.36, 0.8 }, { -0.44, 0.38 }, { -0.32, -0.1 } }, 0.1)
		fin:translate(0, -0.05, 0)
		fin:transform(function(p)
			local out = math.clamp(p[3] / 0.8, 0, 1)
			local thin = (1 - 0.8 * out) * (1 - 0.5 * math.abs(p[1] + 0.05) / 0.35)
			return { p[1], p[2] * math.max(thin, 0.1), p[3] }
		end)
		Kit.turn(fin, "x", 180)
		Kit.turn(fin, "y", 22)
		Kit.turn(fin, "x", -side * 10)
		fin:translate(0.42, side * 0.4, MIDDLE - 0.5)
		fin:emit(mesh)
	end
end, 40, 0.35)
part("Eyes", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, side in { -1, 1 } do
		local eye = EditMesh.sphere(0.1, 8)
		eye:translate(EYE[1], side * EYE[2], MIDDLE + EYE[3])
		eye:emit(mesh)
	end
end, true, 0)
-- A tooth: a flat triangle standing up from the origin, facing +-y, its
-- point up; turned to face along its rim.
local function tooth(wide, tall, facing)
	local m = Kit.plate({ { -wide / 2, 0 }, { wide / 2, 0 }, { 0, tall } }, 0.03)
	m:translate(0, -0.015, 0)
	Kit.turn(m, "z", facing)
	return m
end
local function rimFacing(a)
	local p, q = mouthPoint(a - 1), mouthPoint(a + 1)
	return math.deg(math.atan2(q[2] - p[2], q[1] - p[1]))
end
part("Teeth", nil, { 0.97, 0.97, 0.93 }, function(mesh)
	-- Round the upper rim, hanging from the lip, a second smaller row
	-- behind; round the jaw's edge, standing up.
	for k = 1, 15 do
		local a = -90 + k * 11.25
		local p = mouthPoint(a)
		local t = tooth(0.08, 0.17, rimFacing(a))
		Kit.turn(t, "y", 180)
		t:translate(p[1] * 0.96 + CORNER.x * 0.04, p[2] * 0.93, p[3] + MIDDLE + 0.03)
		t:emit(mesh)
	end
	for k = 1, 14 do
		local a = -84.4 + k * 11.25
		local p = mouthPoint(a)
		local t = tooth(0.065, 0.13, rimFacing(a))
		Kit.turn(t, "y", 180)
		t:translate(p[1] * 0.9 + CORNER.x * 0.1, p[2] * 0.84, MIDDLE + ROOF - 0.005)
		t:emit(mesh)
	end
	for k = 1, 15 do
		local a = -90 + k * 11.25
		local p = mouthPoint(a)
		local t = tooth(0.075, 0.15, rimFacing(a))
		t:translate(p[1] * 0.98 + CORNER.x * 0.02, p[2] * 0.92, ROOF - 0.02)
		onJaw(t):emit(mesh)
	end
end, 40, 0)
part("Sneakers", nil, SNEAKER_BLUE, function(mesh)
	for _, at in STANDS do
		local shoe = Kit.shoe(1.15, 0.6, 0.42)
		shoe:translate(at[1] + 0.15, at[2], 0.06)
		shoe:emit(mesh)
	end
end, true, RUBBER)
part("Soles", nil, { 0.95, 0.95, 0.93 }, function(mesh)
	for _, at in STANDS do
		local sole = Kit.block(1.18, 0.62, 0.1, 0.04)
		sole:translate(at[1] + 0.15, at[2], 0.05)
		sole:emit(mesh)
	end
end, 50, RUBBER)
part("Laces", nil, { 0.97, 0.97, 0.95 }, function(mesh)
	for _, at in STANDS do
		for k = 0, 2 do
			local lace = Kit.block(0.05, 0.34, 0.03, 0.01)
			lace:translate(at[1] + 0.25 + k * 0.12, at[2], 0.42 - k * 0.03)
			lace:emit(mesh)
		end
	end
end, 50, 0)
finishParts()
