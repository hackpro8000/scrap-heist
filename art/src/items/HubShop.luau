-- Hub Shop: the town's shop, salvaged containers stacked behind a long counter
-- (art/concepts/town-pieces-sketch.png, plan in HubShop.plan.luau). Local -y is
-- the front, toward the middle of the town.
-- include: HandFinish
-- include: TownClutter
-- include: WarpedMesh
useTexelDensity(32)

local CONCRETE = { 0.56, 0.54, 0.5 }
local CONTAINER_BLUE = { 0.27, 0.42, 0.52 }
local CONTAINER_RUST = { 0.62, 0.36, 0.19 }
local PLANK = { 0.5, 0.36, 0.22 }
local DRUM = { 0.25, 0.27, 0.3 }
local TIN = { 0.44, 0.5, 0.56 }
local PATCH = { 0.38, 0.42, 0.46 }
local PIPE = { 0.23, 0.24, 0.28 }
local YELLOW = { 0.86, 0.66, 0.18 }
local DARK = { 0.1, 0.1, 0.12 }
local WEIGHT = { 0.3, 0.31, 0.33 }

local FLOOR = 0.8
local LOWER_TOP = 8.8
local UPPER_TOP = 16.8
-- The container's roof sits just below its frame's top rail.
local ROOF_TOP = UPPER_TOP - 0.12
local COUNTER_Y = -3.6
local POST_Y = -9.65
-- The awning falls toward the front from its ledger on the containers.
local AWNING_REAR, AWNING_Z, AWNING_FALL = -1.1, 9.05, 0.05
-- Negative toward the front, so rain runs off away from the containers.
local function awningDrop(y: number): number
	return (y - AWNING_REAR) * AWNING_FALL
end

-- Pressed trapezoid ribs along a wall, stopping short of the corner posts.
local function ribsAlongX(mesh, x0, x1, y, z, height)
	for x = x0, x1, 0.6 do
		box(mesh, x, y, z, 0.3, 0.14, height)
	end
end
local function ribsAlongY(mesh, x, y0, y1, z, height)
	for y = y0, y1, 0.6 do
		box(mesh, x, y, z, 0.14, 0.3, height)
	end
end
-- A container's steel frame: corner posts, and rails round the top and bottom.
local function containerFrame(mesh, x0, x1, y0, y1, z0, z1)
	for _, x in { x0, x1 } do
		for _, y in { y0, y1 } do
			box(mesh, x, y, z0, 0.62, 0.62, z1 - z0)
		end
	end
	for _, z in { z0, z1 - 0.34 } do
		for _, y in { y0, y1 } do
			box(mesh, (x0 + x1) / 2, y, z, x1 - x0 - 0.4, 0.5, 0.34)
		end
		for _, x in { x0, x1 } do
			box(mesh, x, (y0 + y1) / 2, z, 0.5, y1 - y0 - 0.4, 0.34)
		end
	end
end

part("Slab", nil, CONCRETE, function(mesh)
	box(mesh, 0, 0, 0, 34, 20, FLOOR)
end, nil, 0.15)

part("LowerContainers", nil, CONTAINER_BLUE, function(mesh)
	-- Two units welded end to end, open at the front.
	box(mesh, 0, 3.9, FLOOR, 29, 9.7, 0.3)
	box(mesh, 0, 8.8, FLOOR + 0.2, 29.4, 0.3, 7.3)
	box(mesh, 0, 4, LOWER_TOP - 0.4, 29.6, 9.6, 0.3)
	box(mesh, 0, 4, FLOOR + 0.2, 0.3, 9.4, 7.3)
	for _, side in { -1, 1 } do
		box(mesh, side * 14.75, 4, FLOOR + 0.2, 0.3, 9.4, 7.3)
		ribsAlongY(mesh, side * 15.0, -0.2, 8.2, FLOOR + 0.4, 7)
		containerFrame(mesh, math.min(side * 0.42, side * 15), math.max(side * 0.42, side * 15), -0.75, 8.75, FLOOR, LOWER_TOP)
	end
	ribsAlongX(mesh, -14.2, -0.8, 9.0, FLOOR + 0.4, 7)
	ribsAlongX(mesh, 0.8, 14.2, 9.0, FLOOR + 0.4, 7)
end, nil, 0.04)

part("Shelves", nil, PIPE, function(mesh)
	for _, side in { -1, 1 } do
		for z = 2.6, 6.2, 1.8 do
			box(mesh, side * 7.5, 7.9, z, 13, 1.4, 0.15)
		end
		for _, x in { 1.4, 13.6 } do
			box(mesh, side * x, 7.3, FLOOR + 0.3, 0.2, 0.2, 7)
		end
	end
end, nil, 0.1)

-- Salvage on the shelves, in clusters with gaps: x, shelf, kind.
local STOCK = {
	{ -13.2, 1, "drum" }, { -12, 1, "drum" }, { -9.2, 1, "crate" }, { -3.4, 1, "cog" }, { 3, 1, "crate" }, { 4.3, 1, "crate" }, { 10.5, 1, "pipe" }, { 13, 1, "drum" },
	{ -11.8, 2, "cog" }, { -10.4, 2, "cog" }, { -5, 2, "pipe" }, { -2.2, 2, "crate" }, { 7.4, 2, "drum" }, { 8.6, 2, "drum" }, { 9.9, 2, "crate" },
	{ -13, 3, "crate" }, { -7.8, 3, "drum" }, { -2.6, 3, "cog" }, { 2.6, 3, "pipe" }, { 12.2, 3, "cog" },
	{ -7.8, 1, "cog" }, { -5.9, 1, "crate" }, { 6, 1, "drum" }, { 7.2, 1, "drum" }, { 12, 1, "crate" },
	{ -8, 2, "crate" }, { 2.2, 2, "cog" }, { 4, 2, "cog" }, { 11.6, 2, "pipe" },
	{ -11.6, 3, "cog" }, { -6.2, 3, "drum" }, { 5.4, 3, "crate" }, { 7, 3, "crate" }, { 9.6, 3, "drum" },
}
local SHELF_Z = { 2.75, 4.55, 6.35 }
local STOCK_TONES = { { 0.76, 0.58, 0.2 }, { 0.6, 0.34, 0.2 }, { 0.52, 0.56, 0.6 }, { 0.3, 0.46, 0.34 } }

part("ShelfStock", nil, YELLOW, function(mesh)
	for _, item in STOCK do
		local x, z = item[1], SHELF_Z[item[2]]
		if item[3] == "drum" then
			cylinder(mesh, x, 7.8, z + 0.55, 0.42, 1.1, "z", 12)
		elseif item[3] == "cog" then
			gear(mesh, x, 7.8, z + 0.62, 0.62, 0.22, 9, "y")
			box(mesh, x, 7.8, z, 0.8, 0.5, 0.1)
		elseif item[3] == "pipe" then
			for n = 0, 2 do
				cylinder(mesh, x, 7.8 + n * 0.22 - 0.22, z + 0.14, 0.13, 2.2, "x", 8)
			end
		else
			box(mesh, x, 7.8, z, 1.05, 0.95, 0.85)
			box(mesh, x, 7.8, z + 0.85, 1.16, 1.06, 0.1)
			box(mesh, x, 7.3, z + 0.1, 1.08, 0.04, 0.12)
		end
	end
end, nil, function(x, _y, z)
	-- Each item keeps one colour: find the one this point belongs to.
	local nearest, best = 1, math.huge
	for index, item in STOCK do
		local d = math.abs(item[1] - x) + math.abs(SHELF_Z[item[2]] + 0.5 - z) * 3
		if d < best then
			nearest, best = index, d
		end
	end
	local tone = STOCK_TONES[(nearest * 7) % #STOCK_TONES + 1]
	return tone[1], tone[2], tone[3]
end)

part("UpperContainer", nil, CONTAINER_RUST, function(mesh)
	box(mesh, -4, 4, LOWER_TOP + 0.1, 19.4, 9.4, 7.8)
	ribsAlongX(mesh, -13.2, 5.2, -0.8, LOWER_TOP + 0.4, 7)
	ribsAlongX(mesh, -13.2, 5.2, 8.8, LOWER_TOP + 0.4, 7)
	ribsAlongY(mesh, -13.75, -0.2, 8.2, LOWER_TOP + 0.4, 7)
	ribsAlongY(mesh, 5.75, -0.2, 8.2, LOWER_TOP + 0.4, 7)
	containerFrame(mesh, -14, 6, -1, 9, LOWER_TOP, UPPER_TOP)
end, nil, 0.3)

part("Counter", nil, PLANK, function(mesh)
	-- Long planks, jointed over the middle drum.
	for row = 0, 3 do
		local y = COUNTER_Y + (row - 1.5) * 0.6
		local joint = if row % 2 == 0 then -8 else 8
		box(mesh, (-11 + joint) / 2 - 0.03, y, 3, joint + 11 - 0.06, 0.56, 0.4)
		box(mesh, (11 + joint) / 2 + 0.03, y, 3, 11 - joint - 0.06, 0.56, 0.4)
	end
	box(mesh, 0, COUNTER_Y + 0.9, 2.8, 21, 0.3, 0.22)
end, nil, 0)

part("CounterDrums", nil, DRUM, function(mesh)
	for _, x in { -8, 0, 8 } do
		cylinder(mesh, x, COUNTER_Y, FLOOR + 1.1, 0.75, 2.2, "z", 14)
		for _, z in { 0.5, 1.7 } do
			cylinder(mesh, x, COUNTER_Y, FLOOR + z, 0.82, 0.12, "z", 14)
		end
	end
	-- A pair of stacked crates in each long span, so no plank runs far unsupported.
	for _, x in { -4, 4 } do
		box(mesh, x, COUNTER_Y, FLOOR, 1.5, 1.5, 1.08)
		box(mesh, x + 0.1, COUNTER_Y - 0.06, FLOOR + 1.08, 1.34, 1.34, 1.12)
	end
	box(mesh, -2.5, COUNTER_Y, 3.4, 1.6, 1.1, 0.9)
	strut(mesh, -2.5, COUNTER_Y + 0.25, 4.3, -2.5, COUNTER_Y - 0.35, 3.75, 0.26)
end, nil, 0.1)

local function tiltedAwning(mesh)
	return warped(mesh, function(x, y, z)
		return x, y, z + awningDrop(y)
	end)
end

part("Awning", nil, TIN, function(built)
	local mesh = tiltedAwning(built)
	local middle = AWNING_REAR - 4.45
	box(mesh, 0, middle, AWNING_Z, 32, 8.9, 0.1)
	for x = -15.6, 15.6, 0.8 do
		box(mesh, x, middle, AWNING_Z + 0.1, 0.34, 8.9, 0.1)
		box(mesh, x + 0.4, middle, AWNING_Z - 0.1, 0.34, 8.9, 0.1)
	end
end, nil, 0)

-- Lapped patch sheets: centre x, y, width, depth, and a slight skew.
local PATCHES = { { -7.5, -6, 7, 4, 0.05 }, { 6, -3.2, 5, 3, -0.08 }, { 11, -7.6, 4, 3.2, 0.1 } }

part("AwningPatches", nil, PATCH, function(built)
	for _, patch in PATCHES do
		local c, s = math.cos(patch[5]), math.sin(patch[5])
		local mesh = tiltedAwning(warped(built, function(x, y, z)
			local dx, dy = x - patch[1], y - patch[2]
			return patch[1] + dx * c - dy * s, patch[2] + dx * s + dy * c, z
		end))
		box(mesh, patch[1], patch[2], AWNING_Z + 0.22, patch[3], patch[4] + 0.03, 0.05)
		for x = patch[1] - patch[3] / 2 + 0.4, patch[1] + patch[3] / 2 - 0.3, 0.8 do
			box(mesh, x, patch[2], AWNING_Z + 0.24, 0.3, patch[4] - 0.05, 0.09)
		end
		for x = patch[1] - patch[3] / 2 + 0.2, patch[1] + patch[3] / 2, 1 do
			bolt(mesh, x, patch[2] - patch[4] / 2 + 0.15, AWNING_Z + 0.27, "z", 0.07)
			bolt(mesh, x, patch[2] + patch[4] / 2 - 0.15, AWNING_Z + 0.27, "z", 0.07)
		end
	end
end, nil, 0.15)

part("AwningPosts", nil, PIPE, function(mesh)
	local top = AWNING_Z + awningDrop(POST_Y) - 0.12
	for _, x in { -15, -5, 5, 15 } do
		cylinder(mesh, x, POST_Y, (FLOOR + top - 0.16) / 2, 0.3, top - 0.16 - FLOOR, "z", 10)
		box(mesh, x, POST_Y, top - 0.2, 0.9, 0.7, 0.2)
		box(mesh, x, POST_Y + 0.05, FLOOR, 0.86, 0.6, 0.1)
		-- A knee brace from the post back up to the rafters.
		strut(mesh, x, POST_Y + 0.15, top - 1.5, x, POST_Y + 1.35, top - 0.2, 0.14)
	end
	-- The ledger that carries the rear edge, bolted along the containers.
	box(mesh, 0, -1.2, AWNING_Z - 0.32, 31, 0.5, 0.3)
	-- An eave beam along the post heads and rafters back to the ledger.
	box(mesh, 0, POST_Y, top - 0.5, 31, 0.5, 0.42)
	for _, x in { -10, 0, 10 } do
		strut(mesh, x, POST_Y, top - 0.22, x, -1.3, AWNING_Z - 0.2, 0.26)
	end
end, nil, 0.1)

local LETTERS = {
	S = { "01111", "10000", "10000", "01110", "00001", "00001", "11110" },
	C = { "01110", "10001", "10000", "10000", "10000", "10001", "01110" },
	R = { "11110", "10001", "10001", "11110", "10100", "10010", "10001" },
	A = { "01110", "10001", "10001", "11111", "10001", "10001", "10001" },
	P = { "11110", "10001", "10001", "11110", "10000", "10000", "10000" },
}
local WORD = { "S", "C", "R", "A", "P" }
local CELL = 0.46
local SIGN_X, SIGN_Y, SIGN_Z = -4, 0.2, 19

local function onLetters(x: number, z: number): boolean
	local across = (x - SIGN_X) / CELL + 14.5
	local down = 3.5 - (z - SIGN_Z) / CELL
	if down < 0 or down >= 7 or across < 0 or across >= 29 then
		return false
	end
	local slot = math.floor(across / 6)
	local column = math.floor(across - slot * 6)
	if column >= 5 then
		return false
	end
	local rows = LETTERS[WORD[slot + 1]]
	return string.sub(rows[math.floor(down) + 1], column + 1, column + 1) == "1"
end

part("Sign", nil, YELLOW, function(mesh)
	box(mesh, SIGN_X, SIGN_Y, UPPER_TOP + 0.05, 18, 0.5, 4.4)
end, nil, function(x, y, z)
	-- Lettered on the front only; the back is bare board.
	if y < SIGN_Y and onLetters(x, z) then
		return DARK[1], DARK[2], DARK[3]
	end
	return YELLOW[1], YELLOW[2], YELLOW[3]
end)
parts[#parts].crisp = true

part("SignBraces", nil, PIPE, function(mesh)
	for _, x in { -11, -4, 3 } do
		strut(mesh, x, SIGN_Y + 0.3, UPPER_TOP + 3.4, x, SIGN_Y + 3.6, UPPER_TOP + 0.05, 0.28)
		box(mesh, x, SIGN_Y + 3.6, UPPER_TOP, 0.9, 0.9, 0.12)
		box(mesh, x, SIGN_Y + 0.35, UPPER_TOP, 0.9, 0.5, 0.12)
	end
end, nil, 0.1)

local CRANE_X, CRANE_Y, JIB_Z = 12, 4, 20.9
part("Crane", nil, YELLOW, function(mesh)
	for _, cx in { -0.8, 0.8 } do
		for _, cy in { -0.8, 0.8 } do
			box(mesh, CRANE_X + cx, CRANE_Y + cy, LOWER_TOP, 0.3, 0.3, 11.8)
		end
	end
	for z = LOWER_TOP, 19.2, 2.6 do
		strut(mesh, CRANE_X - 0.8, CRANE_Y - 0.8, z, CRANE_X + 0.8, CRANE_Y - 0.8, z + 2.6, 0.16)
		strut(mesh, CRANE_X + 0.8, CRANE_Y + 0.8, z, CRANE_X - 0.8, CRANE_Y + 0.8, z + 2.6, 0.16)
		strut(mesh, CRANE_X - 0.8, CRANE_Y + 0.8, z, CRANE_X - 0.8, CRANE_Y - 0.8, z + 2.6, 0.16)
		strut(mesh, CRANE_X + 0.8, CRANE_Y - 0.8, z, CRANE_X + 0.8, CRANE_Y + 0.8, z + 2.6, 0.16)
	end
	box(mesh, CRANE_X, CRANE_Y, 20.5, 2, 2, 0.5)
	-- The jib, its short counter-jib and the stays over the mast head.
	box(mesh, CRANE_X, 1, JIB_Z, 0.7, 16, 0.6)
	box(mesh, CRANE_X, CRANE_Y, JIB_Z + 0.5, 0.5, 0.5, 2.6)
	strut(mesh, CRANE_X, CRANE_Y, JIB_Z + 3, CRANE_X, -5, JIB_Z + 0.55, 0.13)
	strut(mesh, CRANE_X, CRANE_Y, JIB_Z + 3, CRANE_X, 8.6, JIB_Z + 0.55, 0.13)
end, nil, 0.1)

part("CraneWeight", nil, WEIGHT, function(mesh)
	box(mesh, CRANE_X, 8, JIB_Z - 1.45, 1.7, 1.6, 1.5)
	cylinder(mesh, CRANE_X, 5.9, JIB_Z + 1.05, 0.45, 1.1, "x", 14)
	box(mesh, CRANE_X, 5.9, JIB_Z + 0.55, 1.2, 0.8, 0.2)
end, nil, 0.1)

part("CraneHook", nil, PIPE, function(mesh)
	cylinder(mesh, CRANE_X, -6.5, 17.45, 0.07, 7.1, "z", 6)
	box(mesh, CRANE_X, -6.5, 13.6, 0.7, 0.35, 0.6)
	tube(mesh, roundedPath({ { CRANE_X, -6.5, 13.7 }, { CRANE_X, -6.5, 12.9 }, { CRANE_X, -5.9, 12.9 }, { CRANE_X, -5.9, 13.3 } }, 0.2, 3), 0.11, 8)
	-- The cable runs back along the jib to the winch.
	tube(mesh, { { CRANE_X, -6.5, JIB_Z + 0.62 }, { CRANE_X, 5.9, JIB_Z + 1.3 } }, 0.05, 6)
end, nil, 0.1)

part("StockPiles", nil, CONTAINER_RUST, function(mesh)
	-- Slatted crates on the right; a sagging stack and torn sheet on the left.
	local function crate(x, y, wide, deep, high)
		box(mesh, x, y, FLOOR, wide, deep, high)
		for z = FLOOR + 0.3, FLOOR + high - 0.2, 0.42 do
			box(mesh, x, y, z, wide + 0.08, deep + 0.08, 0.12)
		end
		for _, side in { -1, 1 } do
			box(mesh, x + side * (wide / 2 - 0.1), y - deep / 2 - 0.04, FLOOR, 0.2, 0.1, high)
		end
	end
	crate(13.8, -6.6, 2, 2.1, 2.2)
	crate(11.1, -7.1, 1.5, 1.7, 1.3)
	crate(-13.7, -6.4, 2, 2.2, 1.7)
	box(mesh, -13.8, -6.3, FLOOR + 1.7, 1.2, 1.2, 0.5)
	strut(mesh, -11.9, -7.4, FLOOR, -10.4, -6, FLOOR + 1.3, 0.3)
	strut(mesh, -10.5, -7.8, FLOOR, -9.8, -6.3, FLOOR + 0.7, 0.2)
	-- Torn sheet and bent lengths thrown against the left-hand stack.
	strut(mesh, -12.1, -8, FLOOR, -11.7, -7.7, FLOOR + 1.8, 0.8)
	strut(mesh, -14.8, -7.9, FLOOR, -14.5, -7.65, FLOOR + 1.5, 0.55)
	-- Torn sheet and bent bar leaning on the right-hand crates.
	strut(mesh, 15, -7.9, FLOOR, 14.4, -7.75, FLOOR + 2.1, 0.85)
	strut(mesh, 12.3, -8.3, FLOOR, 12.5, -7.2, FLOOR + 1.5, 0.3)
	strut(mesh, 10.2, -7.7, FLOOR, 10.9, -8.2, FLOOR + 0.8, 0.2)
end, nil, rusting(0.1, function(x, _y, _z)
	-- Each stack its own weathered timber or rusted sheet.
	if x > 13 then
		return 0.62, 0.36, 0.2
	elseif x > 9 then
		return 0.42, 0.34, 0.26
	elseif x < -12.4 then
		return 0.5, 0.3, 0.16
	end
	return 0.46, 0.44, 0.42
end))

-- The lived-in layer: door hardware, roof plant, a ladder, conduit, strings of
-- bulbs, price boards and supplies stacked round the shop.
part("Fittings", nil, { 0.3, 0.32, 0.36 }, function(mesh)
	-- The upper container's door end, with its locking rods and handles.
	box(mesh, 6.22, 4, LOWER_TOP + 0.2, 0.12, 9, 7.6)
	for _, y in { 1.2, 3.1, 4.9, 6.8 } do
		cylinder(mesh, 6.34, y, LOWER_TOP + 4, 0.08, 6.9, "z", 6)
		box(mesh, 6.42, y, LOWER_TOP + 3.1, 0.14, 0.6, 0.14)
		for _, h in { 0.9, 7 } do
			box(mesh, 6.36, y, LOWER_TOP + h, 0.14, 0.34, 0.3)
		end
	end
	-- The upper container's blind end: a bolted hatch and a downpipe on brackets.
	box(mesh, -13.86, 4, LOWER_TOP + 1.9, 0.14, 2.6, 3)
	for _, y in { 2.95, 5.05 } do
		box(mesh, -13.95, y, LOWER_TOP + 3.2, 0.08, 0.3, 0.4)
	end
	cylinder(mesh, -14.08, 6.8, LOWER_TOP + 4, 0.12, 7.2, "z", 8)
	for _, h in { 1, 4, 7 } do
		box(mesh, -13.9, 6.8, LOWER_TOP + h, 0.24, 0.3, 0.15)
	end
	-- Roof plant: an extractor, a fan unit and a hatch.
	cylinder(mesh, -11, 6.5, ROOF_TOP + 0.55, 0.55, 1.1, "z", 12)
	box(mesh, -11, 6.5, ROOF_TOP + 1.04, 1.5, 1.5, 0.14)
	box(mesh, -3.5, 6.6, ROOF_TOP, 3.2, 2.2, 1.3)
	ring(mesh, -3.5, 5.5, ROOF_TOP + 0.65, 0.2, 0.52, 0.2, "y", 14)
	for _, x in { -4.7, -2.3 } do
		box(mesh, x, 6.6, ROOF_TOP + 1.27, 0.12, 2, 0.1)
	end
	box(mesh, 2.8, 6.5, ROOF_TOP, 2, 2, 0.24)
	box(mesh, 2.8, 6.5, ROOF_TOP + 0.22, 1.5, 1.5, 0.12)
	box(mesh, 2.8, 7.1, ROOF_TOP + 0.26, 0.7, 0.12, 0.18)
	-- A ladder up the end of the lower containers.
	ladderOnX(mesh, 15.42, 6.2, FLOOR, LOWER_TOP + 1.1, 0.42)
	-- Conduit along the ledger, into a junction box by the door.
	cylinder(mesh, 0, -1.52, AWNING_Z - 0.4, 0.09, 29, "x", 6)
	box(mesh, -14.3, -1.5, AWNING_Z - 1.4, 1, 0.3, 1.2)
	for x = -12, 12, 4 do
		box(mesh, x, -1.42, AWNING_Z - 0.5, 0.2, 0.26, 0.34)
	end
	-- Back walls: welded patches, a door set, vents, a downpipe and conduit.
	for _, plate in { { -11, 1.6, 2.6, 3.4 }, { 3.5, 3.8, 3.4, 2.6 }, { 10.8, 5.2, 2.2, 2 } } do
		box(mesh, plate[1], 9.1, plate[2], plate[3], 0.24, plate[4])
		for k = 0, 3 do
			bolt(mesh, plate[1] - plate[3] / 2 + 0.15 + k * (plate[3] - 0.3) / 3, 9.23, plate[2] + 0.15, "y", 0.07)
			bolt(mesh, plate[1] - plate[3] / 2 + 0.15 + k * (plate[3] - 0.3) / 3, 9.23, plate[2] + plate[4] - 0.15, "y", 0.07)
		end
	end
	box(mesh, -4.4, 9.1, FLOOR + 0.1, 3.8, 0.3, 6.9)
	box(mesh, -4.4, 9.26, FLOOR + 0.2, 3.2, 0.06, 6.3)
	box(mesh, -3.1, 9.3, FLOOR + 2.9, 0.2, 0.14, 0.7)
	for _, vent in { { -11.6, 12.8 }, { -5.5, 13.6 }, { 1.6, 12.4 } } do
		box(mesh, vent[1], 8.95, vent[2], 1.6, 0.3, 1)
		for k = 0, 3 do
			box(mesh, vent[1], 9.1, vent[2] + 0.1 + k * 0.23, 1.45, 0.08, 0.08)
		end
	end
	cylinder(mesh, 7.5, 9.5, (FLOOR + LOWER_TOP + 0.5) / 2, 0.16, LOWER_TOP + 0.5 - FLOOR, "z", 8)
	box(mesh, 7.5, 9.5, LOWER_TOP + 0.5, 0.6, 0.6, 0.14)
	for _, z in { 2.5, 7 } do
		box(mesh, 7.5, 9.1, z, 0.5, 0.8, 0.16)
	end
	cylinder(mesh, -2, 9.42, 4.8, 0.09, 22, "x", 6)
	for x = -11, 7, 4.5 do
		box(mesh, x, 9.2, 4.68, 0.18, 0.5, 0.24)
	end
	-- A base frame carries the crane to the container's long walls.
	for _, x in { 10.9, 13.1 } do
		box(mesh, x, 4, LOWER_TOP - 0.1, 0.5, 10, 0.5)
	end
	box(mesh, CRANE_X, CRANE_Y, LOWER_TOP + 0.3, 3, 2.6, 0.2)
	-- Hanging stock on the back wall of the shop.
	for k, x in { -12.6, -10.4, -4.2, 3.4, 11, 13 } do
		box(mesh, x, 8.42, 7.2, 0.14, 0.34, 0.14)
		box(mesh, x, 8.32, 5.9 + k % 2 * 0.3, 0.16 + k % 3 * 0.12, 0.14, 1.3)
	end
	-- The upper container's face: a welded patch, a cut hatch, a vent and conduit.
	for _, plate in { { -10.9, 10.2, 3.4, 2.6 }, { 2.6, 12.4, 2.8, 2.4 } } do
		box(mesh, plate[1], -0.94, plate[2], plate[3], 0.26, plate[4])
		for k = 0, 4 do
			bolt(mesh, plate[1] - plate[3] / 2 + 0.2 + k * (plate[3] - 0.4) / 4, -1.08, plate[2] + 0.2, "y", 0.08)
			bolt(mesh, plate[1] - plate[3] / 2 + 0.2 + k * (plate[3] - 0.4) / 4, -1.08, plate[2] + plate[4] - 0.2, "y", 0.08)
		end
	end
	box(mesh, -5.2, -0.94, 10.2, 3, 0.26, 3.2)
	box(mesh, -5.2, -1.08, 10.5, 2.5, 0.08, 2.6)
	ring(mesh, -5.2, -1.14, 11.8, 0.22, 0.48, 0.1, "y", 14)
	box(mesh, 1.6, -0.94, 9.9, 2.2, 0.26, 1.3)
	for k = 0, 3 do
		box(mesh, 1.6, -1.08, 10.05 + k * 0.28, 2, 0.08, 0.1)
	end
	cylinder(mesh, -4.3, -1.14, 15.2, 0.1, 18.6, "x", 8)
	box(mesh, 5.2, -1.14, 14.85, 0.7, 0.3, 0.7)
	for x = -12, 5, 4.2 do
		box(mesh, x, -0.98, 15.05, 0.22, 0.34, 0.3)
	end
	-- The weld between the two lower units, on the back and the roof.
	box(mesh, 0, 9.04, FLOOR, 0.5, 0.34, 8)
	box(mesh, 0, 4, LOWER_TOP - 0.04, 0.5, 10, 0.12)
	for z = 1.4, 8.4, 0.5 do
		box(mesh, 0, 9.24, z, 0.6, 0.08, 0.2)
	end
	-- Inside: brackets, a cable run, hung tools and a noticeboard by the counter.
	for _, side in { -1, 1 } do
		cylinder(mesh, side * 14.5, 2, 6.7, 0.08, 6, "y", 6)
		for _, y in { 0.2, 3.4 } do
			box(mesh, side * 14.48, y, 6.2, 0.2, 0.3, 0.7)
			box(mesh, side * 14.4, y, 5.1 + (y * 2 % 1.3), 0.14, 0.26, 1.1)
		end
		box(mesh, side * 14.5, 6, 3.8, 0.16, 2.6, 1.8)
	end
	box(mesh, -3.5, 8.56, 6.7, 3.2, 0.16, 1.4)
	box(mesh, 3.6, 8.56, 6.8, 2.4, 0.16, 1.2)
	for _, x in { -4.3, -3.25, -2.35, 3, 4.1 } do
		box(mesh, x, 8.44, 7, 0.7, 0.08, 0.8)
	end
	-- Trim round the sign.
	box(mesh, SIGN_X, SIGN_Y - 0.08, UPPER_TOP + 4.32, 18.3, 0.66, 0.2)
	box(mesh, SIGN_X, SIGN_Y - 0.08, UPPER_TOP + 0.02, 18.3, 0.66, 0.2)
	for _, side in { -1, 1 } do
		box(mesh, SIGN_X + side * 9.08, SIGN_Y - 0.08, UPPER_TOP + 0.02, 0.2, 0.66, 4.5)
	end
end, nil, 0.1)

part("Stencil", nil, { 0.85, 0.82, 0.74 }, function(mesh)
	box(mesh, -9.8, -0.94, 13.4, 4.6, 0.26, 1.7)
end, nil, function(x, _y, z)
	-- A stencilled unit mark: bold bars and a hazard corner on an old panel.
	local u, v = x + 12.1, z - 13.4
	if u < 1.2 and (u + v) % 0.5 < 0.25 then
		return 0.08, 0.08, 0.09
	end
	if u > 1.5 and u < 4.3 and v > 0.3 and v < 1.4 and (u * 2) % 1 < 0.6 then
		return 0.08, 0.08, 0.09
	end
	return 0.85, 0.82, 0.74
end)
parts[#parts].crisp = true

part("PriceBoards", nil, { 0.76, 0.72, 0.6 }, function(mesh)
	for _, board in { { -11, 1.9 }, { -7.5, 1.5 }, { 7.2, 1.7 }, { 11, 2 } } do
		box(mesh, board[1], -0.95, LOWER_TOP - 1.1, board[2], 0.3, 0.92)
		for _, side in { -0.45, 0.45 } do
			box(mesh, board[1] + side * board[2], -1.12, LOWER_TOP - 0.5, 0.1, 0.1, 0.2)
		end
	end
end, nil, function(x, _y, z)
	-- Two bold rows of price marks on a pale board.
	local row = z - (LOWER_TOP - 1.1)
	local inRow = (row > 0.2 and row < 0.42) or (row > 0.56 and row < 0.78)
	if inRow and x % 0.46 < 0.3 then
		return 0.14, 0.13, 0.12
	end
	return 0.76, 0.72, 0.6
end)
parts[#parts].crisp = true

part("Supplies", nil, { 0.5, 0.45, 0.3 }, function(mesh)
	barrel(mesh, -16, 2.6, FLOOR)
	barrel(mesh, -16, 4.1, FLOOR)
	barrel(mesh, -15.9, 3.4, FLOOR + 1.86)
	gasBottle(mesh, -16.1, 6.2, FLOOR)
	gasBottle(mesh, -16.1, 7.2, FLOOR)
	tyres(mesh, 16, 1.6, FLOOR, 3)
	-- Goods out on the counter.
	box(mesh, 5.4, COUNTER_Y, 3.4, 1.4, 1, 0.6)
	box(mesh, 7.2, COUNTER_Y + 0.2, 3.4, 0.9, 0.7, 0.4)
	gear(mesh, 2, COUNTER_Y, 3.5, 0.55, 0.2, 9, "z")
	cylinder(mesh, -6, COUNTER_Y, 3.65, 0.3, 0.5, "z", 10)
	-- Stored on the lower roof.
	box(mesh, 9, 7.2, LOWER_TOP - 0.12, 2.2, 1.8, 1)
	for n = 0, 2 do
		cylinder(mesh, 8.8, 1 + n * 0.5, LOWER_TOP - 0.12 + 0.2, 0.22, 4.2, "x", 8)
	end
end, nil, supplyTones)

part("Cables", nil, { 0.08, 0.08, 0.1 }, function(mesh)
	local z = 7.9
	for _, x in { -15, -5, 5 } do
		tube(mesh, sagging(x, POST_Y, z, x + 10, POST_Y, z, 0.45, 8), 0.04, 5)
	end
	tube(mesh, roundedPath({ { -14.3, -1.5, AWNING_Z - 1.4 }, { -14.3, -1.5, FLOOR + 1 }, { -15, -0.6, FLOOR + 0.04 } }, 0.4, 3), 0.06, 6)
end, nil, 0)

part("Bulbs", nil, { 1, 0.84, 0.45 }, function(mesh)
	-- Festoon lamps along the eave, and a row round the sign.
	for _, start in { -15, -5, 5 } do
		for k = 1, 4 do
			local t = k / 5
			sphere(mesh, start + 10 * t, POST_Y, 7.9 - 0.45 * 4 * t * (1 - t) - 0.14, 0.13, 0.13, 0.16, 4, 8)
		end
	end
	for k = 0, 14 do
		local x = SIGN_X - 8.4 + k * 1.2
		sphere(mesh, x, SIGN_Y - 0.42, UPPER_TOP + 4.42, 0.11, 0.11, 0.11, 4, 8)
		sphere(mesh, x, SIGN_Y - 0.42, UPPER_TOP + 0.12, 0.11, 0.11, 0.11, 4, 8)
	end
end, true, 0, nil, 0.9)

handFinish({
	Fittings = "metal",
	Supplies = "metal",
	Slab = "rock",
	UpperContainer = "metal",
	LowerContainers = "metal",
	Shelves = "metal",
	Awning = "metal",
	AwningPatches = "metal",
	AwningPosts = "metal",
	SignBraces = "metal",
	Counter = "wood",
	CounterDrums = "metal",
	Crane = "metal",
	CraneWeight = "metal",
	CraneHook = "metal",
	StockPiles = "metal",
	Sign = "metal",
}, { Cables = true, Bulbs = true, PriceBoards = true, Stencil = true })
-- The ribs read better with broken strokes than a dash on every one.
for _, entry in parts do
	if entry.name == "LowerContainers" or entry.name == "UpperContainer" then
		entry.brushes.edge = { motion = "skip", tune = { skip = 0.65, width = 0.04 } }
	end
end

finishParts()
