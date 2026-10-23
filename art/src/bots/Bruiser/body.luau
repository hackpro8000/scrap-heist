
local root = model.bone("Root", { at = { 0, 0, 0 } })
local treads = model.bone("Treads", { at = { 0, 0, TREAD_HEIGHT / 2 }, parent = root })
local body = model.bone("Body", { at = { 0, 0, TREAD_HEIGHT }, parent = root })
local shoulderL = model.bone("ShoulderL", { at = { -1.3, 0, SHOULDER_Z }, parent = body })
local shoulderR = model.bone("ShoulderR", { at = { 1.3, 0, SHOULDER_Z }, parent = body })
local visor = model.bone("Visor", { at = { 0, -0.9, 3.6 }, parent = body })

-- Each track is a rubber band looped round a recessed frame, so the road
-- wheels sit down inside it between the band's edges.
local BAND = 0.12
local RECESS = 0.1

part("Treads", treads, TREAD, function(mesh)
	local radius = TREAD_HEIGHT / 2
	for _, side in { -1, 1 } do
		local x = side * TREAD_X
		box(mesh, x, 0, 0, TREAD_WIDTH, TREAD_LENGTH, BAND)
		box(mesh, x, 0, TREAD_HEIGHT - BAND, TREAD_WIDTH, TREAD_LENGTH, BAND)
		for _, y in { -TREAD_LENGTH / 2, TREAD_LENGTH / 2 } do
			ring(mesh, x, y, radius, radius - BAND, radius, TREAD_WIDTH, "x")
		end
		-- Grip lugs all the way round the loop.
		for i = 0, 7 do
			local y = -TREAD_LENGTH / 2 + (i + 0.5) * TREAD_LENGTH / 8
			cylinder(mesh, x, y, TREAD_HEIGHT + 0.02, 0.05, TREAD_WIDTH + 0.04, "x", 6)
			cylinder(mesh, x, y, -0.02, 0.05, TREAD_WIDTH + 0.04, "x", 6)
		end
		for _, end_ in { -1, 1 } do
			for k = 1, 3 do
				local t = k / 4 * math.pi
				local y = end_ * (TREAD_LENGTH / 2 + math.sin(t) * (radius + 0.02))
				cylinder(mesh, x, y, radius + math.cos(t) * (radius + 0.02), 0.05, TREAD_WIDTH + 0.04, "x", 6)
			end
		end
	end
	box(mesh, 0, 0, 0.3, 2 * TREAD_X - TREAD_WIDTH, 1.6, 0.5)
end, nil, RUBBER)
part("TrackFrames", treads, DARK_STEEL, function(mesh)
	local radius = TREAD_HEIGHT / 2
	local width = TREAD_WIDTH - 2 * RECESS
	for _, side in { -1, 1 } do
		local x = side * TREAD_X
		box(mesh, x, 0, BAND, width, TREAD_LENGTH, TREAD_HEIGHT - 2 * BAND)
		for _, y in { -TREAD_LENGTH / 2, TREAD_LENGTH / 2 } do
			cylinder(mesh, x, y, radius, radius - BAND, width, "x")
		end
	end
end, nil, 0.5)
part("RoadWheels", treads, DARK_STEEL, function(mesh)
	local radius = TREAD_HEIGHT / 2
	for _, side in { -1, 1 } do
		-- Set into the recess, just inside the band's outer edge.
		local x = side * (TREAD_X + TREAD_WIDTH / 2 - RECESS + 0.03)
		-- Drive sprockets at the ends, road wheels between.
		for _, y in { -TREAD_LENGTH / 2, TREAD_LENGTH / 2 } do
			ring(mesh, x, y, radius, 0.12, radius - BAND - 0.02, 0.06, "x")
			cylinder(mesh, x + side * 0.03, y, radius, 0.1, 0.1, "x", 8)
		end
		for _, y in { -0.65, 0, 0.65 } do
			cylinder(mesh, x, y, radius, 0.26, 0.06, "x")
			bolt(mesh, x + side * 0.04, y, radius, "x", 0.06)
		end
	end
end)
part("Body", body, DARK_STEEL, function(mesh)
	box(mesh, 0, 0, TREAD_HEIGHT - 0.1, 2.2, 1.7, BODY_TOP - TREAD_HEIGHT + 0.1)
	-- Welded seam strips around the waist.
	box(mesh, 0, 0, 2.0, 2.34, 1.84, 0.08)
end, nil, 0.5)
-- Skin panels off different wrecks, each rusted to its own degree.
local function panel(name, color, rust, ...)
	local args = { ... }
	part(name, body, color, function(mesh)
		sheet(mesh, args[1], args[2], args[3], args[4], args[5], args[6], args[7], 0.04, 0.05)
	end, nil, rust)
end
panel("LeftLowerPanel", RUST, 0.85, "x", -1.1, -1, -0.8, 0.8, 0.85, 1.96)
panel("LeftUpperFrontPanel", BLUE_GREY, 0.35, "x", -1.1, -1, -0.8, -0.02, 2.06, 3.35)
panel("LeftUpperBackPanel", RUST, 0.6, "x", -1.1, -1, 0.02, 0.8, 2.06, 3.35)
panel("RightLowerPanel", OLIVE, 0.55, "x", 1.1, 1, -0.8, 0.8, 0.85, 1.96)
panel("RightUpperPanel", RUST, 0.4, "x", 1.1, 1, -0.8, 0.8, 2.06, 3.35)
panel("BackLowerPanel", RUST, 0.7, "y", 0.85, 1, -1.05, 1.05, 0.85, 1.96)
panel("BackUpperPanel", OLIVE, 0.25, "y", 0.85, 1, -1.05, 1.05, 2.06, 4.12)
panel("FrontUpperPanel", RUST, 0.55, "y", BODY_FRONT, -1, -1.05, 1.05, 3.15, 4.12)
part("Lashing", body, ROPE, function(mesh)
	-- Rope cinched round the waist, knotted at the front corner.
	lashing(mesh, 1.25, -1.05, 1.0, 2.55, 0.045)
	sphere(mesh, 1.1, -1.08, 2.55, 0.1, 0.08, 0.1)
end, nil, RUBBER)
part("SeamTape", body, TAPE, function(mesh)
	-- Tape across the seam between the two upper left panels.
	for _, z in { 2.98, 3.22 } do
		box(mesh, -1.1 - 0.045, 0, z, 0.01, 0.3, 0.09)
	end
end, nil, RUBBER)
part("Brackets", body, DARK_STEEL, function(mesh)
	for _, sx in { -1, 1 } do
		for _, z in { 1.0, 3.0 } do
			cornerBracket(mesh, sx * 1.14, 0.89, sx, 1, z, 0.5, 0.25)
		end
	end
end, nil, 0.6)
part("ScrapPatches", body, GALVANISED, function(mesh)
	-- Galvanised sheet riveted over the left side, and a back plate.
	box(mesh, -1.17, 0.1, 1.6, 0.05, 1.1, 1.3)
	for _, y in { -0.38, 0.58 } do
		for _, z in { 1.7, 2.8 } do
			bolt(mesh, -1.2, y, z, "x")
		end
	end
	box(mesh, 0.3, 0.915, 2.3, 1.2, 0.05, 1.0)
	for _, x in { -0.22, 0.82 } do
		for _, z in { 2.4, 3.2 } do
			bolt(mesh, x, 0.945, z, "y")
		end
	end
end)
part("FridgePanel", body, FRIDGE, function(mesh)
	-- A dented fridge door bolted on the right side, handle and all.
	box(mesh, 1.17, -0.05, 1.3, 0.05, 1.2, 1.5)
	box(mesh, 1.21, -0.55, 1.9, 0.04, 0.08, 0.5)
	for _, y in { -0.55, 0.45 } do
		for _, z in { 1.4, 2.7 } do
			bolt(mesh, 1.2, y, z, "x")
		end
	end
end)
part("LidPlates", body, DUMPSTER, function(mesh)
	-- Front lid bolted over the chest, ribbed like the real thing.
	box(mesh, 0, BODY_FRONT - 0.05, 1.4, 1.9, 0.1, 1.7)
	for i = 0, 3 do
		box(mesh, 0, BODY_FRONT - 0.13, 1.6 + i * 0.4, 1.8, 0.06, 0.08)
	end
	-- Top lid slung over like a cap, with a raised hump and ribs.
	box(mesh, 0, -0.1, BODY_TOP, 2.4, 2.0, 0.15)
	box(mesh, 0, 0.3, BODY_TOP + 0.15, 2.3, 1.2, 0.5)
	for _, x in { -0.7, 0, 0.7 } do
		box(mesh, x, 0.3, BODY_TOP + 0.65, 0.1, 1.1, 0.05)
	end
end)
part("LidHardware", body, DARK_STEEL, function(mesh)
	-- Hinges along the top lid's back edge and the front lid's top edge.
	for _, x in { -0.8, 0.8 } do
		cylinder(mesh, x, 0.9, BODY_TOP + 0.1, 0.07, 0.4, "x", 8)
		box(mesh, x, 0.75, BODY_TOP + 0.15, 0.36, 0.3, 0.04)
		box(mesh, x, 0.94, BODY_TOP - 0.35, 0.36, 0.04, 0.4)
		cylinder(mesh, x, BODY_FRONT - 0.12, 3.12, 0.06, 0.35, "x", 8)
	end
	-- Grab handles: on the front lid, and along the top lid's front lip.
	strut(mesh, -0.4, BODY_FRONT - 0.12, 1.75, -0.4, BODY_FRONT - 0.3, 1.75, 0.06)
	strut(mesh, 0.4, BODY_FRONT - 0.12, 1.75, 0.4, BODY_FRONT - 0.3, 1.75, 0.06)
	strut(mesh, -0.43, BODY_FRONT - 0.3, 1.75, 0.43, BODY_FRONT - 0.3, 1.75, 0.06)
	strut(mesh, -0.5, -1.1, BODY_TOP + 0.07, -0.5, -1.25, BODY_TOP - 0.05, 0.05)
	strut(mesh, 0.5, -1.1, BODY_TOP + 0.07, 0.5, -1.25, BODY_TOP - 0.05, 0.05)
	strut(mesh, -0.53, -1.25, BODY_TOP - 0.05, 0.53, -1.25, BODY_TOP - 0.05, 0.05)
	-- Corner bolts holding the front lid on.
	for _, x in { -0.85, 0.85 } do
		for _, z in { 1.5, 3.0 } do
			bolt(mesh, x, BODY_FRONT - 0.12, z, "y", 0.06)
		end
	end
end)
part("VisorFrame", body, GREY, function(mesh)
	local y = BODY_FRONT - 0.12
	box(mesh, 0, y, 3.4, 1.7, 0.14, 0.08)
	box(mesh, 0, y, 3.72, 1.7, 0.14, 0.08)
	box(mesh, -0.81, y, 3.4, 0.08, 0.14, 0.4)
	box(mesh, 0.81, y, 3.4, 0.08, 0.14, 0.4)
	for _, x in { -0.75, 0.75 } do
		bolt(mesh, x, y - 0.08, 3.44, "y", 0.035)
		bolt(mesh, x, y - 0.08, 3.76, "y", 0.035)
	end
end)
part("Visor", visor, VISOR, function(mesh)
	box(mesh, 0, BODY_FRONT - 0.09, 3.48, 1.54, 0.1, 0.24)
end, true, 0)
for _, side in { { "L", shoulderL, -1 }, { "R", shoulderR, 1 } } do
	local name, bone, s = side[1], side[2], side[3]
	part("Shoulder" .. name, bone, GREY, function(mesh)
		-- Pivot hub along X at the bone, with a gap so the arm turns clear of the body.
		cylinder(mesh, s * 1.14, 0, SHOULDER_Z, 0.28, 0.1, "x", 14)
		cylinder(mesh, s * 1.14, 0, SHOULDER_Z, 0.08, 0.16, "x", 6)
		local x = s * 1.53
		box(mesh, x, 0, SHOULDER_Z - 0.4, 0.7, 1.4, 0.9)
		-- A thinner armour plate overlapping the top, bolted down.
		box(mesh, x + s * 0.05, 0, SHOULDER_Z + 0.5, 0.75, 1.45, 0.08)
		for _, y in { -0.55, 0, 0.55 } do
			bolt(mesh, x + s * 0.25, y, SHOULDER_Z + 0.6, "z")
			bolt(mesh, x + s * 0.36, y, SHOULDER_Z, "x")
		end
	end)
end
part("Engine", body, DARK_STEEL, function(mesh)
	-- Diesel block strapped to the back, twin stacks rising past the lid.
	engine(mesh, 0, 1.15, 2.2, 0.6)
	box(mesh, 0, 0.95, 2.1, 0.9, 0.2, 0.08)
	for _, s in { -1, 1 } do
		exhaust(mesh, { { s * 0.3, 1.2, 2.9 }, { s * 0.45, 1.15, 3.4 }, { s * 0.5, 1.05, 4.0 }, { s * 0.5, 1.05, 4.8 } }, 0.09)
	end
end, nil, 0.75)
part("FanBelt", body, RUBBER_BLACK, function(mesh)
	belt(mesh, "x", 0.62, 1.1, 2.45, 0.14, 0.62, 1.1, 3.05, 0.09, 0.04)
end, true, RUBBER)
part("Gears", body, STEEL, function(mesh)
	-- Exposed final drive on each side above the treads.
	for _, s in { -1, 1 } do
		gear(mesh, s * 1.15, -0.4, 1.35, 0.28, 0.08, 12, "x")
		gear(mesh, s * 1.15, 0.05, 1.6, 0.18, 0.08, 9, "x")
	end
	gear(mesh, 0.62, 1.1, 2.45, 0.14, 0.05, 8, "x")
end, nil, 0.55)
part("Pipes", body, GALVANISED, function(mesh)
	-- Coolant lines from the engine round both flanks, flanged at the joints.
	for _, s in { -1, 1 } do
		tube(mesh, { { s * 0.35, 1.3, 2.5 }, { s * 0.9, 1.0, 2.6 }, { s * 1.15, 0.6, 2.7 }, { s * 1.15, -0.5, 2.7 }, { s * 1.15, -0.7, 3.2 } }, 0.05)
		ring(mesh, s * 1.15, 0.1, 2.7, 0.05, 0.08, 0.05, "y")
	end
end, nil, 0.6)

finishParts()
