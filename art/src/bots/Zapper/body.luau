
local root = model.bone("Root", { at = { 0, 0, 0 } })
local body = model.bone("Body", { at = { 0, 0, HIP_Z }, parent = root })
local eye = model.bone("Eye", { at = { 0, -BODY_RADIUS, BODY_Z }, parent = body })
local coil = model.bone("Coil", { at = { 0, 0, COIL_BOTTOM }, parent = body })
local coilTip = model.bone("CoilTip", { at = { 0, 0, COIL_TOP + 0.2 }, parent = coil })

part("Body", body, DARK_STEEL, function(mesh)
	sphere(mesh, 0, 0, BODY_Z, BODY_RADIUS, BODY_RADIUS, BODY_RADIUS * 0.9, 16, 24)
end, true, 0.5)
part("BodyBand", body, GALVANISED, function(mesh)
	-- Strap round the equator, bolted every eighth of a turn.
	ring(mesh, 0, 0, BODY_Z - 0.15, BODY_RADIUS - 0.08, BODY_RADIUS + 0.03, 0.14, "z", 24)
	for i = 0, 7 do
		local t = (i + 0.5) / 8 * TAU
		local r = BODY_RADIUS + 0.04
		bolt(mesh, math.cos(t) * r, math.sin(t) * r, BODY_Z - 0.15, if math.abs(math.cos(t)) > 0.5 then "x" else "y")
	end
	-- Collar the coil stands on.
	cylinder(mesh, 0, 0, COIL_BOTTOM - 0.1, 0.3, 0.12, "z")
end)
-- Point on the body's surface, pushed `lift` out along it, at azimuth `t` and
-- elevation `e` (radians above the equator).
local function onBody(t, e, lift)
	local r, rz = BODY_RADIUS + lift, BODY_RADIUS * 0.9 + lift
	return math.cos(e) * math.cos(t) * r, math.cos(e) * math.sin(t) * r, BODY_Z + math.sin(e) * rz
end

-- Plate beaten to the body's curve between azimuths t0..t1 and elevations
-- e0..e1, from `inner` to `outer` off the surface, studded at each corner.
local function curvedPlate(mesh, t0, t1, e0, e1, inner, outer, studs)
	local STEPS = 8
	local top, bottom = {}, {}
	for i = 0, STEPS do
		top[i], bottom[i] = {}, {}
		for j = 0, STEPS do
			local t, e = t0 + (t1 - t0) * i / STEPS, e0 + (e1 - e0) * j / STEPS
			top[i][j] = mesh:vertex(onBody(t, e, outer))
			bottom[i][j] = mesh:vertex(onBody(t, e, inner))
		end
	end
	for i = 0, STEPS - 1 do
		for j = 0, STEPS - 1 do
			mesh:face({ top[i][j], top[i + 1][j], top[i + 1][j + 1], top[i][j + 1] })
			mesh:face({ bottom[i][j], bottom[i][j + 1], bottom[i + 1][j + 1], bottom[i + 1][j] })
		end
	end
	for k = 0, STEPS - 1 do
		mesh:face({ top[k][0], bottom[k][0], bottom[k + 1][0], top[k + 1][0] })
		mesh:face({ top[k + 1][STEPS], bottom[k + 1][STEPS], bottom[k][STEPS], top[k][STEPS] })
		mesh:face({ top[0][k + 1], bottom[0][k + 1], bottom[0][k], top[0][k] })
		mesh:face({ top[STEPS][k], bottom[STEPS][k], bottom[STEPS][k + 1], top[STEPS][k + 1] })
	end
	if not studs then
		return
	end
	for _, t in { t0 + 0.08, t1 - 0.08 } do
		for _, e in { e0 + 0.07, e1 - 0.07 } do
			local x, y, z = onBody(t, e, outer)
			local ox, oy, oz = onBody(t, e, outer + 1)
			stud(mesh, x, y, z, ox - x, oy - y, oz - z, 0.04)
		end
	end
end

part("BrassPatch", body, BRASS, function(mesh)
	-- A boiler plate bolted over a hole on the back.
	curvedPlate(mesh, 1.25, 1.9, 0.02, 0.5, -0.01, 0.04, true)
end)
-- Skin panels off different wrecks, each rusted to its own degree.
part("BackPanel", body, GALVANISED, function(mesh)
	curvedPlate(mesh, 1.95, 3.5, 0.02, 1.0, -0.01, 0.03, true)
end, nil, 0.15)
part("SidePanel", body, OLIVE, function(mesh)
	curvedPlate(mesh, 5.3, 7.5, 0.02, 1.0, -0.01, 0.03, true)
end, nil, 0.65)
part("BellyPanelRight", body, BLUE_GREY, function(mesh)
	curvedPlate(mesh, 0.35, 2.8, -1.2, -0.32, -0.01, 0.03, true)
end, nil, 0.5)
part("BellyPanelLeft", body, RUST, function(mesh)
	curvedPlate(mesh, 3.5, 5.95, -1.2, -0.32, -0.01, 0.03, true)
end, nil, 0.9)
part("SeamTape", body, TAPE, function(mesh)
	-- Tape bridging the gap between the side panel and the brass patch.
	for _, e in { 0.12, 0.3, 0.42 } do
		curvedPlate(mesh, 1.12, 1.35, e - 0.04, e + 0.04, 0.04, 0.05)
	end
end, nil, RUBBER)
part("Lashing", body, ROPE, function(mesh)
	-- Rope lashed round the belly to hold the lower panels on, knotted at the front.
	local points = {}
	for i = 0, 32 do
		local x, y, z = onBody(i / 32 * TAU, -0.6, 0.08)
		table.insert(points, { x, y, z })
	end
	rope(mesh, points, 0.04)
	local x, y, z = onBody(-math.pi / 2 + 0.6, -0.6, 0.11)
	sphere(mesh, x, y, z, 0.08, 0.08, 0.08)
end, nil, RUBBER)

part("EyeRim", body, STEEL, function(mesh)
	ring(mesh, 0, -BODY_RADIUS + 0.04, EYE_Z, 0.24, 0.34, 0.1, "y", 20)
	for i = 0, 5 do
		local t = i / 6 * TAU
		bolt(mesh, math.cos(t) * 0.29, -BODY_RADIUS - 0.02, EYE_Z + math.sin(t) * 0.29, "y", 0.035)
	end
end)
part("Eye", eye, GLOW, function(mesh)
	sphere(mesh, 0, -BODY_RADIUS + 0.05, EYE_Z, 0.25, 0.12, 0.25)
end, true, 0)
part("Coil", coil, COPPER, function(mesh)
	cylinder(mesh, 0, 0, (COIL_BOTTOM + COIL_TOP) / 2 - 0.1, 0.12, COIL_TOP - COIL_BOTTOM + 0.2, "z")
	for i = 0, 3 do
		cylinder(mesh, 0, 0, COIL_BOTTOM + 0.1 + i * 0.2, 0.25 - i * 0.03, 0.06, "z")
	end
end)
part("CoilTip", coilTip, DARK_STEEL, function(mesh)
	sphere(mesh, 0, 0, COIL_TOP + 0.2, 0.2, 0.2, 0.2)
end, true)
local ANKLE_Z = 0.18
for _, side in { { "L", -1 }, { "R", 1 } } do
	local name, s = side[1], side[2]
	local upper = model.bone("LegUpper" .. name, { at = { s * HIP_X, 0, HIP_Z }, parent = body })
	local lower = model.bone("LegLower" .. name, { at = { s * FOOT_X, 0, KNEE_Z }, parent = upper })
	local ankleX = s * FOOT_X * 0.9
	local foot = model.bone("Foot" .. name, { at = { ankleX, 0, ANKLE_Z }, parent = lower })
	part("LegUpper" .. name, upper, DARK_STEEL, function(mesh)
		strut(mesh, s * HIP_X, 0, HIP_Z, s * FOOT_X, 0, KNEE_Z, 0.12)
		-- Hip: a ball joint in a bracket.
		sphere(mesh, s * HIP_X, 0, HIP_Z, 0.13, 0.13, 0.13)
		box(mesh, s * HIP_X, 0, HIP_Z + 0.05, 0.3, 0.1, 0.12)
	end)
	-- Knee clevis: cheek plates on the upper leg either side of the lower leg's hub,
	-- pinned along X so the shin swings fore and aft without fouling the cheeks.
	part("KneeClevis" .. name, upper, STEEL, function(mesh)
		for _, dx in { -0.11, 0.11 } do
			box(mesh, s * FOOT_X + dx, 0, KNEE_Z - 0.14, 0.04, 0.24, 0.32)
		end
		cylinder(mesh, s * FOOT_X, 0, KNEE_Z, 0.035, 0.32, "x", 6)
	end)
	part("LegJoints" .. name, lower, STEEL, function(mesh)
		cylinder(mesh, s * FOOT_X, 0, KNEE_Z, 0.1, 0.16, "x", 12)
		-- Ankle: hub and pin along X, the same swing as the knee.
		cylinder(mesh, ankleX, 0, 0.18, 0.08, 0.2, "x", 12)
		cylinder(mesh, ankleX, 0, 0.18, 0.03, 0.28, "x", 6)
	end)
	part("LegLower" .. name, lower, DARK_STEEL, function(mesh)
		strut(mesh, s * FOOT_X, 0, KNEE_Z, ankleX, 0, ANKLE_Z, 0.1)
	end)
	part("Foot" .. name, foot, DARK_STEEL, function(mesh)
		box(mesh, ankleX, -0.1, 0, 0.3, 0.45, 0.1)
		bolt(mesh, ankleX, -0.25, 0.1, "z", 0.04)
	end)
end
part("Motor", body, DARK_STEEL, function(mesh)
	-- Generator on the back of the sphere, exhaust bent up toward the coil.
	engine(mesh, 0, BODY_RADIUS + 0.05, BODY_Z - 0.35, 0.35)
	exhaust(mesh, { { 0.15, BODY_RADIUS + 0.15, BODY_Z }, { 0.2, 0.6, BODY_Z + 0.5 }, { 0.2, 0.25, COIL_BOTTOM - 0.05 }, { 0.2, 0.25, COIL_BOTTOM + 0.4 } }, 0.05)
end, nil, 0.7)
part("GenBelt", body, RUBBER_BLACK, function(mesh)
	belt(mesh, "x", -0.25, BODY_RADIUS + 0.1, BODY_Z - 0.3, 0.1, -0.25, BODY_RADIUS - 0.1, BODY_Z + 0.25, 0.07, 0.03)
end, true, RUBBER)
part("Gears", body, STEEL, function(mesh)
	-- Hip drive gears.
	for _, s in { -1, 1 } do
		gear(mesh, s * (HIP_X + 0.12), 0, HIP_Z, 0.2, 0.06, 10, "x")
		gear(mesh, s * (HIP_X + 0.12), 0.25, HIP_Z + 0.2, 0.12, 0.06, 7, "x")
	end
end, nil, 0.55)
part("Pipes", body, GALVANISED, function(mesh)
	-- Feed lines from generator round the sphere to the coil base.
	for _, s in { -1, 1 } do
		tube(mesh, { { s * 0.2, BODY_RADIUS + 0.1, BODY_Z - 0.2 }, { s * 0.7, 0.55, BODY_Z }, { s * 0.75, 0, BODY_Z + 0.35 }, { s * 0.35, 0, COIL_BOTTOM - 0.05 }, { s * 0.15, 0, COIL_BOTTOM + 0.1 } }, 0.04)
		ring(mesh, s * 0.7, 0.55, BODY_Z, 0.04, 0.07, 0.04, "x")
	end
end, nil, 0.6)

finishParts()

-- Legs solved so the feet stay planted wherever the body goes. Body poses are
-- {t, back, down, pitch}; between them the body eases, and each frame the
-- two-bone leg (thigh then shin, knee forward) reaches its ankle on the ground.
local THIGH = HIP_Z - KNEE_Z
local SHIN = KNEE_Z - ANKLE_Z

local function plantedKeys(length, poses, extra)
	local keys = extra
	for _, name in { "Body", "LegUpperL", "LegUpperR", "LegLowerL", "LegLowerR", "FootL", "FootR" } do
		keys[name] = {}
	end
	local frames = math.round(length * 30)
	for frame = 0, frames do
		local t = frame / 30
		local k = 1
		while poses[k + 1] and poses[k + 1][1] < t do
			k += 1
		end
		local a, b = poses[k], poses[math.min(k + 1, #poses)]
		local u = if b[1] > a[1] then (t - a[1]) / (b[1] - a[1]) else 0
		u = (1 - math.cos(u * math.pi)) / 2
		local oy = a[2] + (b[2] - a[2]) * u
		local oz = a[3] + (b[3] - a[3]) * u
		local pitch = a[4] + (b[4] - a[4]) * u
		local vy, vz = -oy, ANKLE_Z - (HIP_Z + oz)
		local d = math.min(math.sqrt(vy * vy + vz * vz), THIGH + SHIN - 1e-4)
		local aim = math.atan2(vy, -vz)
		local thigh = aim - math.acos((THIGH ^ 2 + d ^ 2 - SHIN ^ 2) / (2 * THIGH * d))
		local shin = aim + math.acos((SHIN ^ 2 + d ^ 2 - THIGH ^ 2) / (2 * SHIN * d))
		thigh, shin = math.deg(thigh), math.deg(shin)
		table.insert(keys.Body, { t = t, pos = { 0, oy, oz }, rot = { pitch, 0, 0 } })
		for _, side in { "L", "R" } do
			table.insert(keys["LegUpper" .. side], { t = t, rot = { thigh - pitch, 0, 0 } })
			table.insert(keys["LegLower" .. side], { t = t, rot = { shin - thigh, 0, 0 } })
			table.insert(keys["Foot" .. side], { t = t, rot = { -shin, 0, 0 } })
		end
	end
	return keys
end

model.clip("Idle", {
	length = 2,
	keys = plantedKeys(2, { { 0, 0, 0, 0 }, { 1, 0, -0.08, 0 }, { 2, 0, 0, 0 } }, {
		Eye = { { t = 0 }, { t = 0.6, rot = { 0, 0, 20 } }, { t = 1.4, rot = { 0, 0, -20 } }, { t = 2 } },
		Coil = { { t = 0 }, { t = 2, rot = { 0, 0, 360 } } },
		CoilTip = { { t = 0 }, { t = 1, pos = { 0, 0, 0.1 } }, { t = 2 } },
	}),
})

model.clip("Move", {
	length = 0.8,
	keys = {
		Body = { { t = 0, pos = { 0, 0, 0 }, rot = { 6, 0, 0 } }, { t = 0.2, pos = { 0, 0, 0.12 }, rot = { 6, 0, 0 } }, { t = 0.4, pos = { 0, 0, 0 }, rot = { 6, 0, 0 } }, { t = 0.6, pos = { 0, 0, 0.12 }, rot = { 6, 0, 0 } }, { t = 0.8, pos = { 0, 0, 0 }, rot = { 6, 0, 0 } } },
		LegUpperL = { { t = 0, rot = { 25, 0, 0 } }, { t = 0.4, rot = { -25, 0, 0 } }, { t = 0.8, rot = { 25, 0, 0 } } },
		LegUpperR = { { t = 0, rot = { -25, 0, 0 } }, { t = 0.4, rot = { 25, 0, 0 } }, { t = 0.8, rot = { -25, 0, 0 } } },
		LegLowerL = { { t = 0 }, { t = 0.2, rot = { -20, 0, 0 } }, { t = 0.4 }, { t = 0.8 } },
		LegLowerR = { { t = 0 }, { t = 0.4 }, { t = 0.6, rot = { -20, 0, 0 } }, { t = 0.8 } },
		Coil = { { t = 0 }, { t = 0.8, rot = { 0, 0, 360 } } },
	},
})

model.clip("Attack", {
	length = 1.2,
	keys = plantedKeys(1.2, { { 0, 0, 0, 0 }, { 0.4, 0.12, -0.35, -10 }, { 0.6, -0.15, -0.08, 10 }, { 0.8, -0.1, -0.12, 6 }, { 1.2, 0, 0, 0 } }, {
		Coil = { { t = 0 }, { t = 0.6, rot = { 0, 0, 1080 } }, { t = 1.2, rot = { 0, 0, 1440 } } },
		CoilTip = { { t = 0 }, { t = 0.4, pos = { 0, 0, 0.35 } }, { t = 0.6, pos = { 0, 0, -0.05 } }, { t = 1.2 } },
		Eye = { { t = 0 }, { t = 0.4, pos = { 0, -0.1, 0 } }, { t = 1.2 } },
	}),
})
