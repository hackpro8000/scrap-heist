
-- Disc in the YZ plane with sawtooth edge, centred at (cx, cy, cz).
local function sawBlade(mesh, cx, cy, cz, radius, thick, teeth)
	local front, back = {}, {}
	for i = 0, teeth * 2 - 1 do
		local t = i / (teeth * 2) * TAU
		-- Hooked teeth: tips lean round the spin direction.
		local r = if i % 2 == 0 then radius else radius * 0.82
		local lean = if i % 2 == 0 then 0.12 else 0
		front[i + 1] = mesh:vertex(cx + thick / 2, cy + math.cos(t + lean) * r, cz + math.sin(t + lean) * r)
		back[i + 1] = mesh:vertex(cx - thick / 2, cy + math.cos(t + lean) * r, cz + math.sin(t + lean) * r)
	end
	local n = #front
	for i = 1, n do
		local j = i % n + 1
		mesh:face({ back[i], back[j], front[j], front[i] })
	end
	mesh:face(front)
	local capBack = {}
	for i = n, 1, -1 do
		table.insert(capBack, back[i])
	end
	mesh:face(capBack)
end

-- Shallow dish opening along +Z then tilted toward -Y, apex at (cx, cy, cz).
local function radarDish(mesh, cx, cy, cz, radius, depth)
	local sides = 12
	local tilt = 0.6
	local function at(x, y, z)
		-- Tilt about X so the dish faces up and forward.
		local c, s = math.cos(tilt), math.sin(tilt)
		return mesh:vertex(cx + x, cy + y * c + z * s, cz - y * s + z * c)
	end
	local apex = at(0, 0, 0)
	local rim, lip = {}, {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		rim[i + 1] = at(math.cos(t) * radius, math.sin(t) * radius, depth)
		lip[i + 1] = at(math.cos(t) * radius * 0.9, math.sin(t) * radius * 0.9, depth * 0.75)
	end
	for i = 1, sides do
		local j = i % sides + 1
		mesh:face({ apex, rim[j], rim[i] })
		mesh:face({ rim[i], rim[j], lip[j], lip[i] })
	end
	local inner = {}
	for i = sides, 1, -1 do
		table.insert(inner, lip[i])
	end
	mesh:face(inner)
end

local root = model.bone("Root", { at = { 0, 0, 0 } })
local body = model.bone("Body", { at = { 0, 0, BODY_BOTTOM }, parent = root })
local suspension = model.bone("Suspension", { at = PIVOT, parent = body })
local wheel = model.bone("Wheel", { at = { 0, AXLE_Y, WHEEL_RADIUS }, parent = suspension })
local sawArm = model.bone("SawArm", { at = { BODY_WIDTH / 2, 0, SAW_Z }, parent = body })
local saw = model.bone("Saw", { at = { SAW_X, -0.15, SAW_Z }, parent = sawArm })
local antenna = model.bone("Antenna", { at = { -0.3, 0.2, BODY_BOTTOM + BODY_HEIGHT }, parent = body })

local top = BODY_BOTTOM + BODY_HEIGHT
local front = -BODY_DEPTH / 2

part("Wheel", wheel, TYRE, function(mesh)
	cylinder(mesh, 0, AXLE_Y, WHEEL_RADIUS, WHEEL_RADIUS, 0.3, "x", 20)
end, nil, RUBBER)
part("WheelHub", wheel, STEEL, function(mesh)
	-- Hub rims on both faces, with lug bolts round each.
	for _, side in { -1, 1 } do
		ring(mesh, side * 0.16, AXLE_Y, WHEEL_RADIUS, 0.1, 0.24, 0.04, "x")
		for i = 0, 4 do
			local t = i / 5 * TAU
			bolt(mesh, side * 0.18, AXLE_Y + math.cos(t) * 0.17, WHEEL_RADIUS + math.sin(t) * 0.17, "x", 0.03)
		end
	end
end)
part("SwingArm", suspension, DARK_STEEL, function(mesh)
	-- Axle right through the wheel, capped with nuts.
	cylinder(mesh, 0.08, AXLE_Y, WHEEL_RADIUS, 0.06, AXLE_LENGTH, "x", 10)
	bolt(mesh, -AXLE_LENGTH / 2 + 0.08, AXLE_Y, WHEEL_RADIUS, "x", 0.09)
	-- Arm from the pivot bracket back and down to the axle end.
	local ax = AXLE_LENGTH / 2 + 0.02
	strut(mesh, PIVOT[1], PIVOT[2], PIVOT[3], ax, AXLE_Y, WHEEL_RADIUS, 0.13)
	cylinder(mesh, ax, AXLE_Y, WHEEL_RADIUS, 0.1, 0.12, "x", 10)
	cylinder(mesh, PIVOT[1], PIVOT[2], PIVOT[3], 0.09, 0.2, "x", 10)
end)
-- Coil-over shock: the cylinder hangs from the body, the rod rides on the arm and
-- slides inside it, so the arm can swing without the shock bending.
local SHOCK_TOP = { 0.3, 0.35, BODY_BOTTOM + 0.05 }
local SHOCK_FOOT = { AXLE_LENGTH / 2 - 0.01, AXLE_Y - 0.12, WHEEL_RADIUS + 0.25 }
local function alongShock(k)
	return SHOCK_FOOT[1] + (SHOCK_TOP[1] - SHOCK_FOOT[1]) * k,
		SHOCK_FOOT[2] + (SHOCK_TOP[2] - SHOCK_FOOT[2]) * k,
		SHOCK_FOOT[3] + (SHOCK_TOP[3] - SHOCK_FOOT[3]) * k
end
part("ShockCylinder", body, DARK_STEEL, function(mesh)
	local x, y, z = alongShock(0.45)
	strut(mesh, x, y, z, SHOCK_TOP[1], SHOCK_TOP[2], SHOCK_TOP[3], 0.08)
	for i = 0, 3 do
		local rx, ry, rz = alongShock(0.5 + i * 0.13)
		ring(mesh, rx, ry, rz, 0.04, 0.085, 0.03, "z", 8)
	end
end)
part("ShockRod", suspension, GALVANISED, function(mesh)
	local x, y, z = alongShock(0.8)
	strut(mesh, SHOCK_FOOT[1], SHOCK_FOOT[2], SHOCK_FOOT[3], x, y, z, 0.035)
	cylinder(mesh, SHOCK_FOOT[1], SHOCK_FOOT[2], SHOCK_FOOT[3], 0.05, 0.12, "x", 8)
end)
local halfW, halfD = BODY_WIDTH / 2, BODY_DEPTH / 2
part("Body", body, DARK_STEEL, function(mesh)
	box(mesh, 0, 0, BODY_BOTTOM, BODY_WIDTH, BODY_DEPTH, BODY_HEIGHT)
end, nil, 0.5)
part("Lid", body, RUST, function(mesh)
	-- Lid lip round the top, like the box it was cut from.
	box(mesh, 0, 0, top - 0.08, BODY_WIDTH + 0.06, BODY_DEPTH + 0.06, 0.08)
end, nil, 0.5)
-- Skin panels, each off a different scrap pile and rusted to its own degree.
part("FrontPanel", body, RUST, function(mesh)
	sheet(mesh, "y", front, -1, -0.5, 0.5, BODY_BOTTOM + 0.44, top - 0.1)
end, nil, 0.75)
part("FrontCornerPanel", body, RUST, function(mesh)
	sheet(mesh, "y", front, -1, 0.25, 0.5, BODY_BOTTOM + 0.03, BODY_BOTTOM + 0.4)
end, nil, 0.95)
part("RightPanel", body, RUST, function(mesh)
	sheet(mesh, "x", halfW, 1, -0.42, 0.42, BODY_BOTTOM + 0.03, top - 0.1)
end, nil, 0.85)
part("LeftPanel", body, OLIVE, function(mesh)
	sheet(mesh, "x", -halfW, -1, -0.42, 0.42, BODY_BOTTOM + 0.03, top - 0.1)
end, nil, 0.45)
part("BackPanelLeft", body, GALVANISED, function(mesh)
	sheet(mesh, "y", halfD, 1, -0.5, -0.02, BODY_BOTTOM + 0.03, top - 0.1)
end, nil, 0.2)
part("BackPanelRight", body, RUST, function(mesh)
	sheet(mesh, "y", halfD, 1, 0.02, 0.5, BODY_BOTTOM + 0.03, top - 0.1)
end, nil, 0.55)
part("SeamTape", body, TAPE, function(mesh)
	-- Strips of tape holding the back seam shut.
	for _, z in { BODY_BOTTOM + 0.2, BODY_BOTTOM + 0.45, BODY_BOTTOM + 0.65 } do
		box(mesh, 0, halfD + 0.035, z, 0.24, 0.01, 0.07)
	end
end, nil, RUBBER)
part("Brackets", body, DARK_STEEL, function(mesh)
	for _, sx in { -1, 1 } do
		cornerBracket(mesh, sx * (halfW + 0.03), front - 0.03, sx, -1, BODY_BOTTOM + 0.3, 0.3, 0.2)
	end
end, nil, 0.6)
part("Plates", body, GALVANISED, function(mesh)
	-- Strap riveted over the top.
	box(mesh, 0.25, 0, top, 0.16, BODY_DEPTH + 0.1, 0.03)
end)
part("Motor", body, DARK_STEEL, function(mesh)
	-- Lawnmower engine bolted on the lid, its exhaust bent up off the back.
	engine(mesh, 0.05, -0.12, top, 0.24)
	exhaust(mesh, { { 0.2, -0.05, top + 0.12 }, { 0.32, 0.1, top + 0.14 }, { 0.36, 0.3, top + 0.35 }, { 0.36, 0.32, top + 0.6 } }, 0.04)
end, nil, 0.7)
part("Gears", body, STEEL, function(mesh)
	-- Exposed gear train on the back, meshing as the wheel turns.
	gear(mesh, -0.22, halfD + 0.06, BODY_BOTTOM + 0.38, 0.16, 0.04, 10, "y")
	gear(mesh, 0.06, halfD + 0.06, BODY_BOTTOM + 0.56, 0.12, 0.04, 8, "y")
	gear(mesh, 0.25, halfD + 0.06, BODY_BOTTOM + 0.38, 0.09, 0.04, 6, "y")
end, nil, 0.55)
part("Pipes", body, GALVANISED, function(mesh)
	-- Fuel line from the motor down the left side, flanged at the joints.
	local points = { { -0.1, -0.12, top + 0.05 }, { -0.4, -0.12, top + 0.05 }, { -halfW - 0.08, -0.12, top - 0.1 }, { -halfW - 0.08, -0.3, BODY_BOTTOM + 0.15 } }
	tube(mesh, points, 0.025, 8)
	ring(mesh, -halfW - 0.08, -0.15, top - 0.18, 0.02, 0.045, 0.04, "z", 8)
end, nil, 0.45)
part("AppliancePanel", body, APPLIANCE, function(mesh)
	-- Off-square panel on the -X side, from an old washing machine.
	box(mesh, -BODY_WIDTH / 2 - 0.05, 0.05, BODY_BOTTOM + 0.3, 0.04, 0.62, 0.48)
	for _, y in { -0.21, 0.31 } do
		for _, z in { BODY_BOTTOM + 0.36, BODY_BOTTOM + 0.72 } do
			bolt(mesh, -BODY_WIDTH / 2 - 0.08, y, z, "x", 0.035)
		end
	end
end)
part("EyeRim", body, STEEL, function(mesh)
	ring(mesh, 0.12, front - 0.06, EYE_Z, 0.17, 0.27, 0.08, "y", 20)
	for i = 0, 5 do
		local t = i / 6 * TAU
		bolt(mesh, 0.12 + math.cos(t) * 0.22, front - 0.11, EYE_Z + math.sin(t) * 0.22, "y", 0.025)
	end
end)
part("Eye", body, EYE, function(mesh)
	sphere(mesh, 0.12, front - 0.04, EYE_Z, 0.18, 0.08, 0.18)
end, true, 0)
part("SawArm", sawArm, DARK_STEEL, function(mesh)
	box(mesh, BODY_WIDTH / 2 + 0.06, 0, SAW_Z - 0.18, 0.06, 0.3, 0.36)
	strut(mesh, BODY_WIDTH / 2, 0, SAW_Z, SAW_X - 0.05, -0.15, SAW_Z, 0.14)
	cylinder(mesh, SAW_X - 0.08, -0.15, SAW_Z, 0.09, 0.12, "x", 10)
end)
part("SawBelt", sawArm, RUBBER_BLACK, function(mesh)
	-- Belt from a pulley on the body out to the saw's hub.
	cylinder(mesh, BODY_WIDTH / 2 + 0.17, 0.2, SAW_Z, 0.09, 0.05, "x", 12)
	belt(mesh, "x", BODY_WIDTH / 2 + 0.17, 0.2, SAW_Z, 0.09, BODY_WIDTH / 2 + 0.17, -0.15, SAW_Z, 0.11, 0.022)
end, nil, RUBBER)
part("Saw", saw, STEEL, function(mesh)
	sawBlade(mesh, SAW_X, -0.15, SAW_Z, SAW_RADIUS, 0.04, SAW_TEETH)
	bolt(mesh, SAW_X + 0.04, -0.15, SAW_Z, "x", 0.08)
end)
part("Antenna", antenna, DARK_STEEL, function(mesh)
	cylinder(mesh, -0.3, 0.2, top + 0.04, 0.07, 0.08, "z", 8)
	strut(mesh, -0.3, 0.2, top, -0.35, 0.25, top + 0.4, 0.05)
	strut(mesh, -0.35, 0.25, top + 0.4, -0.12, 0.3, top + 0.62, 0.05)
end)
part("RadarDish", antenna, GALVANISED, function(mesh)
	radarDish(mesh, -0.12, 0.3, top + 0.6, 0.3, 0.14)
end)

finishParts()
