
local root = model.bone("Root", { at = { 0, 0, 0 } })
local treads = model.bone("Treads", { at = { 0, 0, TREAD_HEIGHT / 2 }, parent = root })
local body = model.bone("Body", { at = { 0, 0, TREAD_HEIGHT }, parent = root })
local shoulderL = model.bone("ShoulderL", { at = { -1.3, 0, SHOULDER_Z }, parent = body })
local shoulderR = model.bone("ShoulderR", { at = { 1.3, 0, SHOULDER_Z }, parent = body })
local visor = model.bone("Visor", { at = { 0, -0.9, 3.6 }, parent = body })
-- Each track is a loop of rigid links running round the wheels: straight
-- along the ground and the top, bending round a half circle at each end. A
-- link is a bone, shared by both tracks since their loops match.
local TRACK_RADIUS = TREAD_HEIGHT / 2
local TRACK_LOOP = 2 * TREAD_LENGTH + 2 * math.pi * TRACK_RADIUS
local LINKS = 24
local LINK_SPACING = TRACK_LOOP / LINKS

-- Point (y, z) along the loop and the angle its outward face points at, in
-- degrees from +Y toward +Z. Starts at the front of the ground run and heads
-- back, the way the track runs past the body as the bot drives forward. The
-- angle keeps climbing past a lap, so turning between two points is a plain
-- difference.
local function trackPoint(distance)
	local laps = math.floor(distance / TRACK_LOOP)
	local s = distance - laps * TRACK_LOOP
	local half, r, arc = TREAD_LENGTH / 2, TRACK_RADIUS, math.pi * TRACK_RADIUS
	local y, z, angle
	if s < TREAD_LENGTH then
		y, z, angle = -half + s, 0, -90
	elseif s < TREAD_LENGTH + arc then
		local a = (s - TREAD_LENGTH) / r
		y, z, angle = half + r * math.sin(a), r - r * math.cos(a), -90 + math.deg(a)
	elseif s < 2 * TREAD_LENGTH + arc then
		y, z, angle = half - (s - TREAD_LENGTH - arc), 2 * r, 90
	else
		local a = (s - 2 * TREAD_LENGTH - arc) / r
		y, z, angle = -half - r * math.sin(a), r + r * math.cos(a), 90 + math.deg(a)
	end
	return y, z, angle + laps * 360
end

local links = {}
for i = 1, LINKS do
	local y, z = trackPoint((i - 1) * LINK_SPACING)
	links[i] = model.bone("Link" .. i, { at = { 0, y, z }, parent = treads })
end
local SPROCKET_Y = { -TREAD_LENGTH / 2, TREAD_LENGTH / 2 }
local ROAD_WHEEL_Y = { -0.65, 0, 0.65 }
local wheelBones = {}
for i, y in { SPROCKET_Y[1], ROAD_WHEEL_Y[1], ROAD_WHEEL_Y[2], ROAD_WHEEL_Y[3], SPROCKET_Y[2] } do
	wheelBones[y] = model.bone("Wheel" .. i, { at = { 0, y, TREAD_HEIGHT / 2 }, parent = treads })
end

-- Each track is a rubber band looped round a recessed frame, so the road
-- wheels sit down inside it between the band's edges.
local BAND = 0.12
local RECESS = 0.1

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
-- A box turned to sit on the loop: `along` runs with the track, `out` points
-- away from the wheels, and it spans the track's width.
local function linkBox(mesh, x, y, z, angle, length, from, to)
	local a = math.rad(angle)
	local out = { 0, math.cos(a), math.sin(a) }
	local along = { 0, -math.sin(a), math.cos(a) }
	local corners = {}
	for i, dx in { -TREAD_WIDTH / 2, TREAD_WIDTH / 2 } do
		for j, du in { -length / 2, length / 2 } do
			for k, dn in { to, from } do
				corners[(i - 1) * 4 + (j - 1) * 2 + k] = mesh:vertex(x + dx, y + along[2] * du + out[2] * dn, z + along[3] * du + out[3] * dn)
			end
		end
	end
	local function quad(p, q, r, t)
		mesh:face({ corners[p], corners[q], corners[r], corners[t] })
	end
	quad(1, 2, 4, 3)
	quad(5, 7, 8, 6)
	quad(1, 5, 6, 2)
	quad(3, 4, 8, 7)
	quad(1, 3, 7, 5)
	quad(2, 6, 8, 4)
end

-- Each link: a rubber plate with a grip lug across its outer face.
for i, bone in links do
	local y, z, angle = trackPoint((i - 1) * LINK_SPACING)
	part("Link" .. i, bone, TREAD, function(mesh)
		for _, side in { -1, 1 } do
			local x = side * TREAD_X
			linkBox(mesh, x, y, z, angle, LINK_SPACING * 0.9, -BAND, 0)
			linkBox(mesh, x, y, z, angle, 0.09, 0, 0.06)
		end
	end, nil, RUBBER)
end
-- Set into the recess, just inside the band's outer edge: drive sprockets at
-- the ends, road wheels between.
local radius = TRACK_RADIUS
for _, y in SPROCKET_Y do
	part(if y < 0 then "SprocketFront" else "SprocketBack", wheelBones[y], DARK_STEEL, function(mesh)
		for _, side in { -1, 1 } do
			local x = side * (TREAD_X + TREAD_WIDTH / 2 - RECESS + 0.03)
			ring(mesh, x, y, radius, 0.12, radius - BAND - 0.02, 0.06, "x")
			cylinder(mesh, x + side * 0.03, y, radius, 0.1, 0.1, "x", 8)
		end
	end)
end
for i, y in ROAD_WHEEL_Y do
	part("RoadWheel" .. i, wheelBones[y], DARK_STEEL, function(mesh)
		for _, side in { -1, 1 } do
			local x = side * (TREAD_X + TREAD_WIDTH / 2 - RECESS + 0.03)
			cylinder(mesh, x, y, radius, 0.26, 0.06, "x")
			bolt(mesh, x + side * 0.04, y, radius, "x", 0.06)
		end
	end)
end
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

model.clip("Idle", {
	length = 2,
	keys = {
		Body = { { t = 0, pos = { 0, 0, 0 } }, { t = 1, pos = { 0, 0, -0.06 }, rot = { 2, 0, 0 } }, { t = 2, pos = { 0, 0, 0 } } },
		ShoulderL = { { t = 0 }, { t = 1, rot = { 4, 0, 0 } }, { t = 2 } },
		ShoulderR = { { t = 0 }, { t = 1, rot = { 4, 0, 0 } }, { t = 2 } },
		Visor = { { t = 0 }, { t = 0.5, rot = { 0, 0, 12 } }, { t = 1.3, rot = { 0, 0, -12 } }, { t = 2 } },
	},
})

-- The Bruiser drives at 14 studs/s, so one Move cycle is the time the track
-- takes to run one full lap at that speed; the wheels turn to match.
local DRIVE_SPEED = 14
local MOVE_LENGTH = TRACK_LOOP / DRIVE_SPEED
local TRACK_TRAVEL = TRACK_LOOP
local moveKeys = {
	Treads = { { t = 0, pos = { 0, 0, 0 } }, { t = 0.25 * MOVE_LENGTH, pos = { 0, 0, 0.04 } }, { t = 0.5 * MOVE_LENGTH, pos = { 0, 0, 0 } }, { t = 0.75 * MOVE_LENGTH, pos = { 0, 0, 0.04 } }, { t = MOVE_LENGTH, pos = { 0, 0, 0 } } },
	Body = { { t = 0, rot = { 6, 0, -2 } }, { t = 0.5 * MOVE_LENGTH, rot = { 6, 0, 2 } }, { t = MOVE_LENGTH, rot = { 6, 0, -2 } } },
	ShoulderL = { { t = 0, rot = { 15, 0, 0 } }, { t = 0.5 * MOVE_LENGTH, rot = { -15, 0, 0 } }, { t = MOVE_LENGTH, rot = { 15, 0, 0 } } },
	ShoulderR = { { t = 0, rot = { -15, 0, 0 } }, { t = 0.5 * MOVE_LENGTH, rot = { 15, 0, 0 } }, { t = MOVE_LENGTH, rot = { -15, 0, 0 } } },
}
for i = 1, 5 do
	local wheelRadius = if i == 1 or i == 5 then TRACK_RADIUS else 0.26
	moveKeys["Wheel" .. i] = { { t = 0 }, { t = MOVE_LENGTH, rot = { math.deg(TRACK_TRAVEL / wheelRadius), 0, 0 } } }
end
-- Links follow the loop frame by frame, so they bend round the ends.
for i = 1, LINKS do
	local start = (i - 1) * LINK_SPACING
	local y0, z0, angle0 = trackPoint(start)
	local keys = {}
	local frames = math.ceil(MOVE_LENGTH * 30)
	for frame = 0, frames do
		local t = MOVE_LENGTH * frame / frames
		local y, z, angle = trackPoint(start + TRACK_TRAVEL * frame / frames)
		table.insert(keys, { t = t, pos = { 0, y - y0, z - z0 }, rot = { angle - angle0, 0, 0 } })
	end
	moveKeys["Link" .. i] = keys
end

model.clip("Move", {
	length = MOVE_LENGTH,
	keys = moveKeys,
})
model.clip("Attack", {
	length = 1,
	keys = {
		Body = { { t = 0 }, { t = 0.35, rot = { -12, 0, 0 } }, { t = 0.5, rot = { 18, 0, 0 }, pos = { 0, -0.3, -0.1 } }, { t = 0.75, rot = { 14, 0, 0 }, pos = { 0, -0.25, -0.1 } }, { t = 1 } },
		ShoulderL = { { t = 0 }, { t = 0.35, rot = { -70, 0, 0 } }, { t = 0.5, rot = { 40, 0, 0 } }, { t = 0.75, rot = { 35, 0, 0 } }, { t = 1 } },
		ShoulderR = { { t = 0 }, { t = 0.35, rot = { -70, 0, 0 } }, { t = 0.5, rot = { 40, 0, 0 } }, { t = 0.75, rot = { 35, 0, 0 } }, { t = 1 } },
	},
})
