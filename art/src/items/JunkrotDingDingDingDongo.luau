-- Ding Ding Ding Dongo: a garden snail whose shell is a chrome bicycle
-- bell. Built after the pictures: a soft body lying on its flat foot,
-- drawn out to a point behind, rising at the front to a lifted head with
-- two long eye stalks leaning forward, each tipped with an eye; the bell
-- a domed chrome shell perched over the back where a snail's shell sits,
-- on its black clapper housing, its thumb lever out to one side. The body
-- is mismatched scrap plates (JunkrotScrap); no legs, no other limbs: it
-- glides. About 2.9 studs tall to the top of its eyes.
-- include: JunkrotScrap
local DARK = { 0.18, 0.19, 0.21 }

-- The foot's skirt: where the pale foot meets the body, in degrees from
-- the top round the section, along x: high at the tail and the neck,
-- lower under the shell, climbing up the chin at the lifted head.
local FOOT = { { -1.75, 150 }, { -1.2, 136 }, { -0.4, 128 }, { 0.5, 130 }, { 0.95, 142 }, { 1.35, 160 } }
-- The body: a loft along x, the foot flat on the ground from the tail's
-- point to under the neck, the back highest under the shell, the head
-- rising off the ground at the front to a rounded snout.
local L = Scrap.loft({
	stations = { -- x, top, bottom, half width
		{ -1.75, 0.05, 0.0, 0.04 },
		{ -1.45, 0.14, 0.0, 0.13 },
		{ -1.05, 0.34, 0.0, 0.3 },
		{ -0.6, 0.54, 0.0, 0.43 },
		{ -0.15, 0.58, 0.0, 0.44 },
		{ 0.3, 0.52, 0.0, 0.38 },
		{ 0.65, 0.48, 0.0, 0.32 },
		{ 0.95, 0.64, 0.08, 0.3 },
		{ 1.2, 0.9, 0.28, 0.29 },
		{ 1.42, 0.94, 0.5, 0.24 },
		{ 1.62, 0.78, 0.66, 0.07 },
	},
	steps = 84,
	splits = {
		{ nominal = 135, tag = "foot", angle = function(x)
			return Scrap.tableAt(FOOT, x)
		end },
	},
})

-- A sheet over a surface: surface(s, t, lift) gives the point at s, t in
-- 0..1 lifted off it; the sheet's outer face at `lift`, `thick` deep,
-- walled round its edges, wound outward.
local vec = EditMesh.vec
local function sheet(surface, N, M, lift, thick)
	local m = EditMesh.new()
	local top, under = {}, {}
	for i = 0, N do
		top[i], under[i] = {}, {}
		for j = 0, M do
			local o, u = surface(i / N, j / M, lift), surface(i / N, j / M, lift - thick)
			top[i][j] = m:addVertex(o[1], o[2], o[3])
			under[i][j] = m:addVertex(u[1], u[2], u[3])
		end
	end
	for i = 0, N - 1 do
		for j = 0, M - 1 do
			m:addFace({ top[i][j], top[i + 1][j], top[i + 1][j + 1], top[i][j + 1] })
			m:addFace({ under[i][j], under[i][j + 1], under[i + 1][j + 1], under[i + 1][j] })
		end
	end
	for k = 0, N - 1 do
		m:addFace({ top[k][0], under[k][0], under[k + 1][0], top[k + 1][0] })
		m:addFace({ top[k + 1][M], under[k + 1][M], under[k][M], top[k][M] })
	end
	for k = 0, M - 1 do
		m:addFace({ top[0][k + 1], under[0][k + 1], under[0][k], top[0][k] })
		m:addFace({ top[N][k], under[N][k], under[N][k + 1], top[N][k + 1] })
	end
	local c, o = surface(0.5 / N, 0.5 / M, lift), surface(0.5 / N, 0.5 / M, lift + 0.1)
	if vec.dot(m:faceNormal(m:select("face", "all"):list()[1]), vec.sub(o, c)) < 0 then
		m:flip()
	end
	return m
end

-- The eye stalks, drawn out of the top of the head: a patch of its skin
-- each side extruded along a gentle curve up, forward and outward,
-- narrowing to the tip, where the eye sits looking ahead.
local function aim(region, from, to)
	local axis = vec.cross(from, to)
	local len = vec.length(axis)
	if len > 1e-6 then
		region:rotate(vec.scale(axis, 1 / len), math.deg(math.atan2(len, vec.dot(from, to))), region:middle())
	end
end
local function regionNormal(region)
	local sum = { 0, 0, 0 }
	for _, id in region:list() do
		sum = vec.add(sum, L.mesh:faceNormal(id))
	end
	return vec.unit(sum)
end
local STALK_STEPS = 9
local eyes = {}
local stalkJoints = {} -- { centre, direction, step } at each extrusion, for the clamps
for _, side in { -1, 1 } do
	local base = L.mesh:select("face", "where", function(p)
		return p[1] > 1.11 and p[1] < 1.21 and p[2] * side > 0.09 and p[2] * side < 0.21 and p[3] > 0.8
	end)
	local b = base:middle()
	local path = Kit.curve({
		b,
		{ b[1] + 0.1, b[2] + side * 0.1, b[3] + 0.42 },
		{ b[1] + 0.3, b[2] + side * 0.3, b[3] + 0.85 },
		{ b[1] + 0.55, b[2] + side * 0.52, b[3] + 1.22 },
	}, 3)
	local region, dir = base, nil
	for k = 1, STALK_STEPS do
		local delta = vec.sub(path[k + 1], path[k])
		local d = vec.unit(delta)
		if k == 1 then
			aim(region, regionNormal(region), d)
		end
		region = L.mesh:extrude(region, delta, { tag = "stalk" })
		if k > 1 then
			aim(region, dir, d)
		end
		region:scale(0.9)
		dir = d
		table.insert(stalkJoints, { region:middle(), d, k })
	end
	region:tag("stalk")
	table.insert(eyes, { region:middle(), vec.unit({ 0.75, side * 0.35, 0.55 }) })
end

-- The skin under the plates: dark steel, showing in the seams; the foot
-- its own pale sheet; the stalks galvanised.
part("Body", nil, DARK, function(mesh)
	Scrap.skinPart(L, { drop = { "foot", "stalk" } }):emit(mesh)
end, true, 0.4)
part("Foot", nil, { 0.3, 0.3, 0.3 }, function(mesh)
	Scrap.skinPart(L, { keep = "foot" }):emit(mesh)
end, true, 0.3)
part("Stalks", nil, { 0.6, 0.63, 0.62 }, function(mesh)
	Scrap.skinPart(L, { keep = "stalk" }, 0.02):emit(mesh)
end, true, 0.5)
Scrap.googlyEyes(eyes, 0.15)

-- The bell: built in its own frame, axis z up through the dome's middle,
-- the dome's rim at z = 0, then tipped back a little and set over the
-- back where the shell sits. The dome is a dark pressing under two rings
-- of chrome plates, eight round the skirt and eight more over the crown
-- staggered between them, a rolled lip round the rim and the screw boss
-- on top; under it the black clapper housing on its stem, strapped round
-- the body like a bell clamped to a handlebar; the thumb lever out to the
-- left on its pivot.
local BELL = { x = -0.45, z = 0.74, tilt = -12 }
local DOME = { -- u up the dome, r, z
	{ 0, 0.8, 0.0 }, { 0.15, 0.79, 0.12 }, { 0.3, 0.75, 0.24 }, { 0.45, 0.67, 0.36 }, { 0.6, 0.55, 0.46 }, { 0.75, 0.4, 0.535 }, { 0.9, 0.2, 0.585 }, { 1, 0.0, 0.6 },
}
local function domeAt(u, a, lift)
	local r, z = Scrap.tableAt(DOME, u)
	local u2 = if u < 0.99 then u + 0.01 else u - 0.01
	local r2, z2 = Scrap.tableAt(DOME, u2)
	local dr, dz = (r2 - r) * (if u < 0.99 then 1 else -1), (z2 - z) * (if u < 0.99 then 1 else -1)
	local len = math.sqrt(dr * dr + dz * dz)
	local nr, nz = dz / len, -dr / len
	local c, s = math.cos(math.rad(a)), math.sin(math.rad(a))
	return { (r + nr * lift) * c, (r + nr * lift) * s, z + nz * lift }
end
local function onBell(m)
	Kit.turn(m, "y", BELL.tilt)
	return m:translate(BELL.x, 0, BELL.z)
end
local function domePlate(a0, a1, u0, u1)
	return sheet(function(s, t, lift)
		return domeAt(u0 + (u1 - u0) * s, a0 + (a1 - a0) * t, lift)
	end, 5, 6, 0.0, 0.035)
end
local CHROMES = {
	{ "Chrome", { 0.85, 0.86, 0.88 } },
	{ "Steel", { 0.76, 0.78, 0.8 } },
	{ "Nickel", { 0.8, 0.79, 0.76 } },
}
for c, chrome in CHROMES do
	part("Bell" .. chrome[1], nil, chrome[2], function(mesh)
		for k = 0, 7 do
			if (k % 3) + 1 == c then
				onBell(domePlate(k * 45 + 1.5, (k + 1) * 45 - 1.5, 0.04, 0.5)):emit(mesh)
			end
			if ((k + 1) % 3) + 1 == c then
				onBell(domePlate(k * 45 + 22.5 + 2, (k + 1) * 45 + 22.5 - 2, 0.53, 0.97)):emit(mesh)
			end
		end
	end, true, 0.08)
end
part("BellRim", nil, { 0.82, 0.83, 0.85 }, function(mesh)
	-- The rolled lip round the rim.
	onBell(Kit.lathe({ { 0.76, -0.03 }, { 0.82, -0.03 }, { 0.86, 0.01 }, { 0.86, 0.06 }, { 0.82, 0.1 }, { 0.78, 0.09 }, { 0.76, 0.05 }, { 0.76, -0.03 } }, 32)):emit(mesh)
end, true, 0.1)
part("BellPressing", nil, DARK, function(mesh)
	-- The dark dome under the plates, with the screw boss on its crown.
	local profile = {}
	for _, q in DOME do
		local p = domeAt(q[1], 0, -0.04)
		table.insert(profile, { p[1], p[3] })
	end
	for k = #DOME, 1, -1 do
		local p = domeAt(DOME[k][1], 0, -0.1)
		table.insert(profile, { math.max(p[1], 0), p[3] })
	end
	table.insert(profile, { profile[1][1], profile[1][2] })
	onBell(Kit.lathe(profile, 32)):emit(mesh)
	onBell(Kit.lathe({ { 0, 0.56 }, { 0.17, 0.56 }, { 0.18, 0.63 }, { 0.14, 0.67 }, { 0.06, 0.68 }, { 0, 0.68 } }, 16)):emit(mesh)
end, true, 0.4)
part("BellHousing", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	-- The clapper housing under the dome, its stem into the back.
	onBell(Kit.lathe({ { 0, -0.26 }, { 0.5, -0.26 }, { 0.56, -0.22 }, { 0.58, -0.05 }, { 0.63, 0.0 }, { 0.63, 0.04 }, { 0, 0.04 } }, 32)):emit(mesh)
	onBell(Kit.lathe({ { 0, -0.5 }, { 0.2, -0.5 }, { 0.2, -0.24 }, { 0, -0.24 } }, 16)):emit(mesh)
end, true, RUBBER)
part("BellStrap", nil, { 0.3, 0.33, 0.37 }, function(mesh)
	-- The clamp strap over the back under the housing.
	sheet(function(s, t, lift)
		return L.on(BELL.x - 0.08 + 0.16 * s, -125 + 250 * t, lift)
	end, 1, 24, 0.055, 0.03):emit(mesh)
end, true, 0.5)
part("BellPost", nil, BARE_METAL, function(mesh)
	-- The post the dome screws onto, up the bell's axis from the clapper
	-- housing to the crown.
	local post = EditMesh.cylinder(0.07, 0.64, 10, 1)
	post:translate(0, 0, 0.3)
	onBell(post):emit(mesh)
end, true, 0.3)
part("Lever", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	-- The thumb lever: a flat paddle on its pivot at the housing's left
	-- side, pointing forward and out, ridged for the thumb.
	local function place(m)
		Kit.turn(m, "z", -40)
		m:translate(0.05, -0.62, -0.17)
		return onBell(m)
	end
	local paddle = Kit.plate({ { -0.05, -0.07 }, { 0.4, -0.11 }, { 0.6, -0.07 }, { 0.65, 0 }, { 0.6, 0.07 }, { 0.4, 0.11 }, { -0.05, 0.07 } }, 0.045)
	Kit.turn(paddle, "x", 90)
	place(paddle):emit(mesh)
	for _, along in { 0.42, 0.49, 0.56 } do
		local ridge = Kit.block(0.025, 0.16, 0.024, 0.006)
		ridge:translate(along, 0, 0)
		place(ridge):emit(mesh)
	end
	local pivot = EditMesh.cylinder(0.05, 0.2, 8, 1)
	pivot:translate(0.05, -0.62, -0.12)
	onBell(pivot):emit(mesh)
end, 40, RUBBER)
part("BellRivets", nil, DARK_STEEL, function(mesh)
	-- Rivets at the corners of the dome's plates.
	for k = 0, 7 do
		for _, a in { k * 45 + 6, (k + 1) * 45 - 6 } do
			for _, u in { 0.1, 0.44 } do
				local o = domeAt(u, a, 0.012)
				local rivet = EditMesh.sphere(0.022, 6)
				rivet:translate(o[1], o[2], o[3])
				onBell(rivet):emit(mesh)
			end
		end
		for _, a in { k * 45 + 22.5 + 8, (k + 1) * 45 + 22.5 - 8 } do
			local o = domeAt(0.6, a, 0.012)
			local rivet = EditMesh.sphere(0.022, 6)
			rivet:translate(o[1], o[2], o[3])
			onBell(rivet):emit(mesh)
		end
	end
end, true, 0.4)
part("StalkClamps", nil, DARK_STEEL, function(mesh)
	-- Hose clamps round the stalks where their pipe sections join.
	for _, j in stalkJoints do
		if j[3] == 3 or j[3] == 6 then
			local r = 0.062 * 0.9 ^ j[3]
			local clamp = EditMesh.tube(r + 0.016, r - 0.01, 0.05, 12)
			local n = j[2]
			Kit.turn(clamp, "y", math.deg(math.acos(math.clamp(n[3], -1, 1))))
			Kit.turn(clamp, "z", math.deg(math.atan2(n[2], n[1])))
			clamp:translate(j[1][1], j[1][2], j[1][3])
			clamp:emit(mesh)
		end
	end
end, true, 0.4)

-- The plating: bands round the section with cuts of very different
-- lengths, some cells split; darker metals over the back, pale ones on
-- the foot below its skirt; the head plainer so the face reads; open
-- where the eye stalks grow out of the head.
local panels = Scrap.panels(L, {
	bands = {
		{ 0, 30, { -1.75, -1.35, -0.3, 0.05, 0.75, 1.05, 1.3, 1.62 } },
		{ 30, 62, { -1.75, -0.95, -0.6, 0.4, 0.7, 1.05, 1.3, 1.62 } },
		{ 62, 98, { -1.75, -1.5, -0.45, 0.55, 0.9, 1.25, 1.62 } },
		{ 98, 135, { -1.75, -1.1, 0.1, 0.35, 1.1, 1.4, 1.62 } },
		{ 135, 180, { -1.75, -1.3, -0.5, 0.25, 0.65, 1.2, 1.62 } },
	},
	paleFrom = 135,
	splits = { [3] = 0.45, [7] = 0.6, [12] = 0.35, [18] = 0.55, [23] = 0.4, [29] = 0.65, [34] = 0.5, [40] = 0.3 },
	noSplitFrom = 1.05,
	open = function(band, x0, x1)
		return (band == 1 or band == 2) and x0 < 1.3 and x1 > 1.0
	end,
	metal = function(_, _, _, _, x0, _, pale)
		if x0 >= 1.25 then
			return if pale then Scrap.BELLY_METALS[3] else Scrap.BACK_METALS[4]
		end
		return nil
	end,
})
Scrap.panelParts(L, panels, { rivetsUpTo = 1.3 })
finishParts()
