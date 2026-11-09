-- Hub Stage: the town's event stage, a plate platform with a scrap lighting rig
-- (art/concepts/town-pieces-sketch.png, plan in HubStage.plan.luau). Local -y is
-- the front, where the steps are.
-- include: HandFinish
-- include: WarpedMesh
-- include: TownClutter
useTexelDensity(24)

local PLATE = { 0.22, 0.24, 0.28 }
local WORN = { 0.31, 0.32, 0.34 }
local DRUM = { 0.27, 0.4, 0.5 }
local CONCRETE = { 0.56, 0.54, 0.5 }
local STEEL = { 0.44, 0.5, 0.56 }
local SPEAKER = { 0.14, 0.15, 0.17 }
local CONE = { 0.44, 0.46, 0.5 }
local LAMP = { 1, 0.82, 0.42 }
local HOUSING = { 0.17, 0.18, 0.2 }
-- Overlapping sheets of the backdrop: centre x, z, width, height, colour.
local SHEETS = {
	{ -7.4, 4.6, 7.4, 5.6, { 0.42, 0.26, 0.54 } },
	{ 0.2, 4.2, 8.2, 4.9, { 0.36, 0.22, 0.48 } },
	{ 7.6, 4.8, 6.8, 6, { 0.47, 0.3, 0.56 } },
	{ -6.3, 9.7, 9.4, 5.4, { 0.33, 0.24, 0.5 } },
	{ 3.1, 9.4, 9.6, 6.2, { 0.45, 0.25, 0.46 } },
	{ 9.2, 10.3, 3.6, 4.2, { 0.5, 0.33, 0.42 } },
}
-- Mismatched stage lamps: x, radius, length, drop below the beam, housing.
local LAMPS = { { -10, 0.55, 0.9, 0, "can" }, { -5.2, 0.4, 1.1, 0.5, "flood" }, { 0.3, 0.6, 0.8, 0.15, "flare" }, { 5, 0.45, 1, 0.7, "can" }, { 10, 0.5, 1.1, 0.05, "flood" } }

local DECK_TOP = 1.8
local TRUSS_Y, TRUSS_X, BEAM_Z = 8, 12, 12.6
local BACK_Y = 9.2

local function latticeColumn(mesh, x, y)
	box(mesh, x, y, DECK_TOP, 2.2, 2.2, 0.12)
	for _, cx in { -0.8, 0.8 } do
		for _, cy in { -0.8, 0.8 } do
			box(mesh, x + cx, y + cy, DECK_TOP, 0.3, 0.3, BEAM_Z - DECK_TOP)
		end
	end
	for z = DECK_TOP, BEAM_Z - 2.7, 2.7 do
		strut(mesh, x - 0.8, y - 0.8, z, x + 0.8, y - 0.8, z + 2.7, 0.15)
		strut(mesh, x + 0.8, y + 0.8, z, x - 0.8, y + 0.8, z + 2.7, 0.15)
		strut(mesh, x - 0.8, y + 0.8, z, x - 0.8, y - 0.8, z + 2.7, 0.15)
		strut(mesh, x + 0.8, y - 0.8, z, x + 0.8, y + 0.8, z + 2.7, 0.15)
	end
end

part("Platform", nil, PLATE, function(mesh)
	box(mesh, 0, 2, DECK_TOP - 0.4, 26, 22, 0.4)
	-- A shallow fascia round the plates, leaving the drums showing below it.
	box(mesh, 0, -8.7, 1.15, 25.8, 0.4, 0.3)
	box(mesh, 0, 12.7, 1.15, 25.8, 0.4, 0.3)
	for _, side in { -1, 1 } do
		box(mesh, side * 12.75, 2, 1.15, 0.4, 21, 0.3)
	end
	-- Rows of fixings either side of each plate join.
	for _, x in { -6.5, 0, 6.5 } do
		for y = -8.4, 12.4, 1.6 do
			bolt(mesh, x - 0.32, y, DECK_TOP, "z", 0.1)
			bolt(mesh, x + 0.32, y, DECK_TOP, "z", 0.1)
		end
	end
	for _, y in { -5.5, 0, 5.5, 11 } do
		for x = -12.2, 12.2, 1.6 do
			bolt(mesh, x, y - 0.32, DECK_TOP, "z", 0.1)
			bolt(mesh, x, y + 0.32, DECK_TOP, "z", 0.1)
		end
	end
end, nil, function(x, y, z)
	if y < -8.4 and z < DECK_TOP - 0.35 then
		if (x + z) % 1.1 < 0.55 then
			return 0.08, 0.08, 0.09
		end
		return 0.86, 0.66, 0.18
	end
	local joinX = math.abs(((x + 3.25) % 6.5) - 3.25)
	local joinY = math.abs(((y + 2.75) % 5.5) - 2.75)
	if joinX < 0.06 or joinY < 0.06 then
		return 0.11, 0.12, 0.14
	end
	-- Scuffs from the steps to centre stage, thinning toward their edges.
	local toward = math.clamp((3 - y) / 12, 0, 1)
	local spread = 3.2 + 1.6 * (1 - toward)
	local keep = 1 - math.abs(x) / spread
	local scuff = math.noise(x * 1.4, y * 0.5, 4) + 0.5 * math.noise(x * 4, y * 1.5, 7)
	local wear = math.clamp((keep * toward * 1.5 + scuff - 0.55) / 0.3, 0, 1) * 0.8
	return PLATE[1] + (WORN[1] - PLATE[1]) * wear, PLATE[2] + (WORN[2] - PLATE[2]) * wear, PLATE[3] + (WORN[3] - PLATE[3]) * wear
end)

part("PlatformDrums", nil, DRUM, function(mesh)
	-- Extra drums packed under each tower's foot.
	for _, side in { -1, 1 } do
		for _, spot in { { 11.9, 7.3 }, { 11.9, 8.7 }, { 10.7, 8 } } do
			cylinder(mesh, side * spot[1], spot[2], 0.72, 0.62, 1.44, "z", 14)
			for _, z in { 0.14, 1.28 } do
				cylinder(mesh, side * spot[1], spot[2], z, 0.68, 0.09, "z", 14)
			end
		end
	end
	for x = -11, 11.1, 4.4 do
		for y = -6, 6, 4 do
			cylinder(mesh, x, y, 0.72, 0.62, 1.44, "z", 14)
			for _, z in { 0.14, 0.7, 1.28 } do
				cylinder(mesh, x, y, z, 0.68, 0.09, "z", 14)
			end
		end
	end
end, nil, 0.15)

part("Steps", nil, CONCRETE, function(mesh)
	box(mesh, 0, -10.95, 0, 10, 4.3, 0.6)
	box(mesh, 0, -9.85, 0.55, 9.8, 2.2, 0.65)
end, nil, 0.1)

part("Truss", nil, STEEL, function(mesh)
	latticeColumn(mesh, -TRUSS_X, TRUSS_Y)
	latticeColumn(mesh, TRUSS_X, TRUSS_Y)
	-- Backing rails behind the sheets, on cleats off each tower.
	for _, z in { 4.2, 9.4 } do
		box(mesh, 0, BACK_Y + 0.42, z, 23, 0.26, 0.4)
		for _, side in { -1, 1 } do
			box(mesh, side * 11.3, TRUSS_Y + 1.1, z - 0.05, 0.5, 1.15, 0.5)
		end
	end
end, nil, 0.1)

part("TrussTop", nil, STEEL, function(mesh)
	for _, y in { -0.8, 0.8 } do
		for _, z in { 0.15, 1.65 } do
			box(mesh, 0, TRUSS_Y + y, BEAM_Z + z - 0.15, 26, 0.3, 0.3)
		end
	end
	for x = -13, 11, 2 do
		strut(mesh, x, TRUSS_Y - 0.8, BEAM_Z, x + 2, TRUSS_Y - 0.8, BEAM_Z + 1.65, 0.15)
		strut(mesh, x, TRUSS_Y + 0.8, BEAM_Z + 1.65, x + 2, TRUSS_Y + 0.8, BEAM_Z, 0.15)
	end
	for _, lamp in LAMPS do
		box(mesh, lamp[1], TRUSS_Y, BEAM_Z - 0.05, 0.5, 1.9, 0.2)
	end
end, nil, 0.1)

part("Backdrop", nil, SHEETS[1][5], function(mesh)
	for index, sheet in SHEETS do
		local y = BACK_Y - 0.03 * index
		box(mesh, sheet[1], y, sheet[2] - sheet[4] / 2, sheet[3], 0.3, sheet[4])
	end
end, nil, rusting(0.03, function(x, y, z)
	-- The bare back of the wall is raw sheet.
	if y > BACK_Y + 0.05 then
		return 0.42, 0.43, 0.45
	end
	-- The last sheet laid over a point shows its colour.
	for index = #SHEETS, 1, -1 do
		local sheet = SHEETS[index]
		if math.abs(x - sheet[1]) <= sheet[3] / 2 + 0.05 and math.abs(z - sheet[2]) <= sheet[4] / 2 + 0.05 then
			return sheet[5][1], sheet[5][2], sheet[5][3]
		end
	end
	return SHEETS[1][5][1], SHEETS[1][5][2], SHEETS[1][5][3]
end))

part("BackdropRivets", nil, HOUSING, function(mesh)
	for index, sheet in SHEETS do
		local y = BACK_Y - 0.03 * index - 0.15
		local x0, x1 = sheet[1] - sheet[3] / 2 + 0.25, sheet[1] + sheet[3] / 2 - 0.25
		local count = math.floor(sheet[3] / 1.3)
		for k = 0, count do
			local x = x0 + (x1 - x0) * k / count
			bolt(mesh, x, y, sheet[2] + sheet[4] / 2 - 0.25, "y", 0.09)
			bolt(mesh, x, y, sheet[2] - sheet[4] / 2 + 0.25, "y", 0.09)
		end
	end
end, nil, 0)

part("Speakers", nil, SPEAKER, function(mesh)
	-- Left: a wide twin-driver cabinet under a horn. Right: a tall single
	-- cabinet beside a small one, stacked out of line.
	box(mesh, -10.8, 1.5, DECK_TOP, 4, 2, 2.6)
	box(mesh, -10.5, 1.9, DECK_TOP + 2.6, 2.8, 1.8, 2.8)
	box(mesh, 11.1, 1.6, DECK_TOP, 2.8, 2, 4)
	box(mesh, 10.7, 1.6, DECK_TOP + 4, 2.2, 1.8, 1.4)
end, nil, 0.15)

-- Each driver sits in the baffle inside a dark surround: x, y of the baffle, z, radius.
local DRIVERS = { { -11.8, 0.5, 1.3, 0.85 }, { -9.8, 0.5, 1.3, 0.85 }, { -10.5, 1, 4, 0.95 }, { 11.1, 0.6, 2.8, 1 }, { 11.1, 0.6, 1, 0.55 }, { 10.7, 0.7, 4.7, 0.5 } }

part("SpeakerSurrounds", nil, HOUSING, function(mesh)
	for _, driver in DRIVERS do
		ring(mesh, driver[1], driver[2] - 0.03, DECK_TOP + driver[3], driver[4] * 0.8, driver[4], 0.08, "y", 20)
	end
end, nil, 0)

part("SpeakerCones", nil, CONE, function(mesh)
	for _, driver in DRIVERS do
		-- A shallow dish down to a raised dust cap.
		ring(mesh, driver[1], driver[2] - 0.01, DECK_TOP + driver[3], driver[4] * 0.3, driver[4] * 0.8, 0.03, "y", 20)
		cylinder(mesh, driver[1], driver[2] - 0.05, DECK_TOP + driver[3], driver[4] * 0.3, 0.1, "y", 14)
	end
end, nil, 0)

-- Builds a lamp in its own space, hung from a pivot and tipped toward the stage.
local function tippedAt(built, lamp)
	local x, pivotZ = lamp[1], BEAM_Z - 0.3
	local c, s = math.cos(0.5), math.sin(0.5)
	return warped(built, function(px, py, pz)
		local dy, dz = py - TRUSS_Y, pz - pivotZ
		return px, TRUSS_Y + dy * c + dz * s, pivotZ - dy * s + dz * c
	end), pivotZ - lamp[3] - lamp[4] * 0.5
end

part("LampHousings", nil, HOUSING, function(built)
	for _, lamp in LAMPS do
		local mesh, bottom = tippedAt(built, lamp)
		local x, radius = lamp[1], lamp[2]
		local top = BEAM_Z - 0.3
		box(built, x, TRUSS_Y, top, 0.5, 0.22, 0.3)
		box(mesh, x, TRUSS_Y, bottom + (top - bottom) * 0.55, 0.14, 0.14, (top - bottom) * 0.5)
		if lamp[5] == "flood" then
			-- A square flood with its cooling fins.
			box(mesh, x, TRUSS_Y, bottom, radius * 2.8, radius * 2, (top - bottom) * 0.5)
			for k = -1, 1 do
				box(mesh, x + k * radius * 0.8, TRUSS_Y, bottom + (top - bottom) * 0.5, 0.08, radius * 1.8, 0.2)
			end
		elseif lamp[5] == "flare" then
			-- A car headlight: a shallow bowl behind a wide rim.
			sphere(mesh, x, TRUSS_Y, bottom + 0.25, radius + 0.1, radius + 0.1, 0.42, 5, 14)
			ring(mesh, x, TRUSS_Y, bottom + 0.05, radius * 0.86, radius + 0.26, 0.12, "z", 18)
		else
			-- A round can with its top vent.
			cylinder(mesh, x, TRUSS_Y, bottom + (top - bottom) * 0.3, radius + 0.14, (top - bottom) * 0.6, "z", 14)
			cylinder(mesh, x, TRUSS_Y, bottom + (top - bottom) * 0.66, radius * 0.6, 0.16, "z", 12)
		end
	end
end, nil, 0)

part("Lamps", nil, LAMP, function(mesh)
	for _, lamp in LAMPS do
		local tipped, bottom = tippedAt(mesh, lamp)
		if lamp[5] == "flood" then
			box(tipped, lamp[1], TRUSS_Y, bottom - 0.04, lamp[2] * 2.4, lamp[2] * 1.6, 0.08)
		else
			cylinder(tipped, lamp[1], TRUSS_Y, bottom + 0.0, lamp[2] * 0.92, 0.1, "z", 14)
		end
	end
end, true, 0, nil, 0.8)

-- The lived-in layer: a tower ladder, sandbags, monitors, a mic stand, road
-- cases, a banner and cables run across the deck.
part("Fittings", nil, { 0.3, 0.32, 0.36 }, function(mesh)
	ladderOnY(mesh, TRUSS_X, TRUSS_Y - 1.2, DECK_TOP, BEAM_Z, -0.34)
	-- Steel stringers and tread plates over the concrete steps.
	for _, side in { -1, 1 } do
		box(mesh, side * 5.1, -10.95, 0, 0.26, 4.3, 0.75)
		box(mesh, side * 5.1, -10, 0.74, 0.26, 2.2, 0.55)
	end
	box(mesh, 0, -12.1, 0.56, 9.6, 1.5, 0.08)
	box(mesh, 0, -9.9, 1.16, 9.4, 1.5, 0.08)
	-- Corner guards, handles and straps on the speakers.
	for _, cab in { { -10.8, 1.5, 0, 4, 2, 2.6 }, { -10.5, 1.9, 2.6, 2.8, 1.8, 2.8 }, { 11.1, 1.6, 0, 2.8, 2, 4 }, { 10.7, 1.6, 4, 2.2, 1.8, 1.4 } } do
		for _, side in { -1, 1 } do
			local x = cab[1] + side * (cab[4] / 2 - 0.1)
			box(mesh, x, cab[2] - cab[5] / 2 - 0.02, DECK_TOP + cab[3], 0.32, 0.16, cab[6])
			box(mesh, cab[1] + side * (cab[4] / 2 + 0.03), cab[2], DECK_TOP + cab[3] + cab[6] * 0.55, 0.12, 0.8, 0.2)
		end
	end
	for _, x in { -10.6, 10.9 } do
		box(mesh, x, 1.6, DECK_TOP + 0.02, 0.2, 2.3, 5.6)
	end
	-- Sheets of plate over the backdrop, conduit and a strap across it.
	-- Repairs gathered where boots and cases hit the wall, each riveted on.
	for _, plate in { { -8.6, 2.1, 3.6, 2.2, 0.3 }, { -5, 2.4, 2.4, 1.6, 0.2 }, { 8.4, 2.2, 3, 2, 0.26 }, { 3.4, 9.4, 3.6, 2.6, 0.3 } } do
		box(mesh, plate[1], BACK_Y - 0.1 - plate[5] / 2, plate[2], plate[3], plate[5], plate[4])
		local front = BACK_Y - 0.1 - plate[5] - 0.02
		for k = 0, 4 do
			local x = plate[1] - plate[3] / 2 + 0.2 + k * (plate[3] - 0.4) / 4
			bolt(mesh, x, front, plate[2] + 0.2, "y", 0.08)
			bolt(mesh, x, front, plate[2] + plate[4] - 0.2, "y", 0.08)
		end
	end
	-- A scrapped pipe section spliced into one tower, and repair plates.
	strut(mesh, -TRUSS_X - 0.8, TRUSS_Y - 0.8, 4.5, -TRUSS_X + 0.8, TRUSS_Y + 0.8, 7.2, 0.3)
	for _, spot in { { -TRUSS_X - 0.95, 6.2 }, { TRUSS_X + 0.95, 9.4 }, { TRUSS_X + 0.95, 4 } } do
		box(mesh, spot[1], TRUSS_Y, spot[2], 0.14, 1.9, 1.1)
	end
	for _, x in { -6, 5 } do
		box(mesh, x, TRUSS_Y - 0.9, BEAM_Z + 0.1, 1.4, 0.12, 1.6)
	end
	-- Framing behind the sheets, along their joins.
	for _, x in { -3.7, 3.9 } do
		box(mesh, x, BACK_Y + 0.42, DECK_TOP + 0.05, 0.3, 0.26, 10.6)
	end
	-- Behind the wall: braces to the deck.
	for _, x in { -8, 0, 8 } do
		strut(mesh, x, BACK_Y + 0.5, 9.6, x, 12.6, DECK_TOP, 0.2)
		strut(mesh, x, BACK_Y + 0.5, 4.5, x, 11.4, DECK_TOP, 0.16)
	end
	cylinder(mesh, -1.4, BACK_Y - 0.2, 7.2, 0.12, 9, "z", 8)
	box(mesh, -1.4, BACK_Y - 0.28, 2.2, 1.2, 0.3, 1.1)
	-- Rails up the steps.
	for _, side in { -1, 1 } do
		local x = side * 4.7
		tube(mesh, { { x, -12.9, 3 }, { x, -9, 4.4 } }, 0.08, 6)
		for _, y in { -12.7, -9.2 } do
			local base = if y < -11 then 0.6 else 1.2
			cylinder(mesh, x, y, (base + (if y < -11 then 3.05 else 4.33)) / 2, 0.08, (if y < -11 then 3.05 else 4.33) - base, "z", 6)
		end
	end
	-- A mic on its stand at centre stage, and two wedge monitors.
	cylinder(mesh, 0, -3.4, DECK_TOP + 0.04, 0.5, 0.08, "z", 12)
	cylinder(mesh, 0, -3.4, DECK_TOP + 2.2, 0.05, 4.3, "z", 6)
	cylinder(mesh, 0, -3.62, DECK_TOP + 4.42, 0.1, 0.42, "y", 8)
	for _, x in { -4.5, 4.5 } do
		box(mesh, x, -5.4, DECK_TOP, 2, 1.2, 0.4)
		strut(mesh, x, -5.55, DECK_TOP + 0.4, x, -5.1, DECK_TOP + 1, 1.7)
	end
	-- A mixing desk at the side of the stage.
	box(mesh, -11, -4.6, DECK_TOP, 2.6, 1.6, 1.3)
	box(mesh, -11, -4.6, DECK_TOP + 1.3, 2.9, 1.8, 0.1)
	for k = 0, 8 do
		box(mesh, -12.1 + k * 0.28, -4.9, DECK_TOP + 1.4, 0.1, 0.5, 0.08)
	end
end, nil, 0.1)

part("Banner", nil, { 0.86, 0.66, 0.18 }, function(mesh)
	box(mesh, 0, TRUSS_Y - 1, BEAM_Z + 0.2, 11, 0.12, 1.3)
end, nil, function(x, y, z)
	-- Bold chevrons pointing at the middle of the stage.
	local away = math.abs(x)
	if y < TRUSS_Y - 1 and (away + math.abs(z - BEAM_Z - 0.85)) % 1.3 < 0.55 then
		return 0.09, 0.09, 0.1
	end
	return 0.86, 0.66, 0.18
end)
parts[#parts].crisp = true

part("Supplies", nil, { 0.5, 0.45, 0.3 }, function(mesh)
	-- Road cases stacked stage right, a crate and sandbags on the tower feet.
	for _, case in { { 8.6, -5, 0, 2.4, 1.6, 1.3 }, { 8.9, -5, 1.3, 1.8, 1.3, 0.9 }, { 5, 11, 0, 2.4, 1.6, 1.5 } } do
		box(mesh, case[1], case[2], DECK_TOP + case[3], case[4], case[5], case[6])
		box(mesh, case[1], case[2] - case[5] / 2 - 0.03, DECK_TOP + case[3] + case[6] * 0.55, case[4] * 0.3, 0.08, 0.14)
	end
	barrel(mesh, 3.1, 11.7, DECK_TOP)
	gasBottle(mesh, 3.5, 10.5, DECK_TOP)
	box(mesh, 6.4, 10.2, DECK_TOP, 1.4, 1.2, 0.9)
	-- Ballast heaped unevenly on the tower feet, inside the deck edge.
	for _, bag in { { -1, -0.5, 7, 0 }, { -1, 0.5, 7.1, 0 }, { -1, 0, 7, 1 }, { 1, -0.7, 6.9, 0 }, { 1, 0.2, 7.2, 0 }, { 1, -0.3, 7.1, 1 }, { 1, 0.3, 6.95, 2 } } do
		sphere(mesh, bag[1] * (TRUSS_X - 0.25) + bag[2], bag[3] - 0.6, DECK_TOP + 0.2 + bag[4] * 0.32, 0.46, 0.3, 0.22, 4, 10)
	end
end, nil, supplyTones)

part("Cables", nil, { 0.08, 0.08, 0.1 }, function(mesh)
	local z = DECK_TOP + 0.05
	tube(mesh, roundedPath({ { -9.5, 0.5, z }, { -6, -1, z }, { -2, -2.2, z }, { 0, -3.3, z } }, 1.2, 4), 0.06, 6)
	tube(mesh, roundedPath({ { 9.5, 0.5, z }, { 6.5, 1.5, z }, { 5, -3, z }, { 4.5, -4.8, z } }, 1.2, 4), 0.06, 6)
	tube(mesh, roundedPath({ { -9.5, -4.6, z }, { -7, -3.5, z }, { -4.5, -4.8, z } }, 1, 4), 0.06, 6)
	tube(mesh, sagging(-12, TRUSS_Y - 0.9, BEAM_Z - 0.06, 12, TRUSS_Y - 0.9, BEAM_Z - 0.06, 0.2, 10), 0.05, 5)
end, nil, 0)

handFinish({
	Fittings = "metal",
	Supplies = "metal",
	Platform = "metal",
	PlatformDrums = "metal",
	Steps = "rock",
	Truss = "metal",
	TrussTop = "metal",
	Speakers = "metal",
	Backdrop = "metal",
}, { Cables = true, Banner = true, Lamps = true, SpeakerCones = true, SpeakerSurrounds = true, LampHousings = true, BackdropRivets = true })

finishParts()
