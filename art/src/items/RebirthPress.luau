-- Rebirth Press: the hydraulic press in a yard that flattens its scrap pile
-- into a medal (art/concepts/rebirth-press-sketch.png, RebirthPress.plan.luau).
-- 16 x 8 on the ground and 15.2 tall, the origin at the middle of the
-- footprint at ground level, z up, the front (console, medal tray) on the
-- -y side. Riveted dark steel with bronze caps and plate, crisp hazard tape,
-- the yard's scrap heaped on the anvil under the platen.

-- Baked at the map's density, as it is in game.
useTexelDensity(16)

local PRESS_DARK = { 0.2, 0.21, 0.24 }
local PRESS_STEEL = { 0.42, 0.45, 0.5 }
local COLUMN_STEEL = { 0.28, 0.3, 0.34 }
local HOSE_GREY = { 0.3, 0.31, 0.34 }
local SILVER = { 0.72, 0.74, 0.77 }
local BARE = { 0.68, 0.7, 0.73 }
local BRONZE = { 0.66, 0.46, 0.26 }
local BRASS = { 0.86, 0.68, 0.32 }
local HAZARD = { 0.86, 0.64, 0.16 }
local TAPE_BLACK = { 0.08, 0.08, 0.09 }
local CONCRETE = { 0.62, 0.6, 0.56 }
local RUST = { 0.46, 0.27, 0.16 }
local BUTTON_RED = { 1.0, 0.2, 0.15 }

-- The anvil, ram and platen share one axis; the console sits at the +x end.
local MID_X, MID_Y = -1.5, 0.4
local PLINTH_TOP = 1.2
local ANVIL_TOP = PLINTH_TOP + 1.3
local PLATEN_BASE, PLATEN_TOP = 5.6, 6.5
local COLUMN_X = { -6.2, 3.2 }
local COLUMN_HALF_X, COLUMN_HALF_Y = 1.2, 1.7
local CROWN_BASE, CROWN_TOP = 10.6, 12.8
local CROWN_X0, CROWN_X1 = -7.6, 4.6
local CYL_R, CYL_TOP = 1.6, 15.2
local CONSOLE_X, CONSOLE_Y = 6.3, -1.2

-- A crisp 45-degree hazard tape: black where the stripe falls.
local function tape(along: number, up: number): boolean
	return (along + up) % 1.1 < 0.55
end
-- A line of rivets along a straight run.
local function rivets(mesh, x0, y0, z0, x1, y1, z1, count, axis, size)
	for i = 0, count - 1 do
		local t = (i + 0.5) / count
		bolt(mesh, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z0 + (z1 - z0) * t, axis, size)
	end
end
-- Machine finishes go on crisp, texel by texel (see common.luau).
local function crisp()
	parts[#parts].crisp = true
end

-- -------------------------------------------------------------- the bed
part("Plinth", nil, PRESS_DARK, function(mesh)
	box(mesh, 0, 0, 0, 16.4, 8.4, 0.3)
	box(mesh, 0, 0, 0.3, 16, 8, PLINTH_TOP - 0.3)
	-- The medal slot's lip, standing a little proud of the front face.
	box(mesh, MID_X, -4.1, 0.5, 3.4, 0.2, 0.5)
	-- Rivets round the top edge.
	rivets(mesh, -7.4, -3.75, 0.75, 7.4, -3.75, 0.75, 8, "y", 0.09)
	rivets(mesh, -7.4, 3.75, 0.75, 7.4, 3.75, 0.75, 8, "y", 0.09)
	rivets(mesh, -7.75, -3.2, 0.75, -7.75, 3.2, 0.75, 4, "x", 0.09)
	rivets(mesh, 7.75, -3.2, 0.75, 7.75, 3.2, 0.75, 4, "x", 0.09)
end, nil, function(x, y, z)
	if z < 0.3 then
		local k = 0.92 + 0.08 * math.noise(x * 0.8, y * 0.8, 3.1)
		return CONCRETE[1] * k, CONCRETE[2] * k, CONCRETE[3] * k
	end
	-- The slot, black inside its lip.
	if math.abs(x - MID_X) < 1.5 and y < -3.9 and z > 0.6 and z < 0.9 then
		return 0.02, 0.02, 0.02
	end
	-- The hazard band round the top.
	if z > PLINTH_TOP - 0.3 and z < PLINTH_TOP + 0.01 and (math.abs(x) > 7.9 or math.abs(y) > 3.9) then
		local along = if math.abs(y) > 3.9 then x else y
		if tape(along, z) then
			return TAPE_BLACK[1], TAPE_BLACK[2], TAPE_BLACK[3]
		end
		return HAZARD[1], HAZARD[2], HAZARD[3]
	end
	local k = 0.94 + 0.1 * math.noise(x * 0.5, y * 0.5, z * 2)
	return PRESS_DARK[1] * k, PRESS_DARK[2] * k, PRESS_DARK[3] * k
end, nil, nil, true, 0.25)
crisp()

part("Anvil", nil, BARE, function(mesh)
	box(mesh, MID_X, MID_Y, PLINTH_TOP, 7, 5, ANVIL_TOP - PLINTH_TOP)
	box(mesh, MID_X, MID_Y, PLINTH_TOP, 7.4, 5.4, 0.25)
end, nil, function(x, y, z)
	-- Scarred bare steel, darker in dents on the top, its sides darker so
	-- it reads as a bed block between the plinth and the pile.
	local k = 0.9 + 0.12 * math.noise(x * 1.1, y * 1.1, 4.2)
	if z > ANVIL_TOP - 0.02 and math.noise(x * 2.2, y * 2.2, 1.7) > 0.35 then
		k -= 0.25
	elseif z < ANVIL_TOP - 0.05 then
		k *= 0.72
	end
	return BARE[1] * k, BARE[2] * k, BARE[3] * k
end, nil, nil, nil, 0.2)

-- ------------------------------------------------------------ the frame
part("Columns", nil, COLUMN_STEEL, function(mesh)
	for _, x in COLUMN_X do
		box(mesh, x, MID_Y, PLINTH_TOP, 2 * COLUMN_HALF_X, 2 * COLUMN_HALF_Y, CROWN_BASE - PLINTH_TOP)
		-- Bronze foot plate and cap band.
		box(mesh, x, MID_Y, PLINTH_TOP, 2 * COLUMN_HALF_X + 0.5, 2 * COLUMN_HALF_Y + 0.5, 0.7)
		box(mesh, x, MID_Y, CROWN_BASE - 0.9, 2 * COLUMN_HALF_X + 0.3, 2 * COLUMN_HALF_Y + 0.3, 0.9)
		-- Rivets down each front and back edge, and the side edges.
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				rivets(mesh, x + sx * (COLUMN_HALF_X - 0.3), MID_Y + sy * COLUMN_HALF_Y, 2.4, x + sx * (COLUMN_HALF_X - 0.3), MID_Y + sy * COLUMN_HALF_Y, 9.4, 6, "y", 0.09)
				rivets(mesh, x + sx * COLUMN_HALF_X, MID_Y + sy * (COLUMN_HALF_Y - 0.3), 2.4, x + sx * COLUMN_HALF_X, MID_Y + sy * (COLUMN_HALF_Y - 0.3), 9.4, 6, "x", 0.09)
			end
		end
		-- Foot plate bolts.
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				bolt(mesh, x + sx * (COLUMN_HALF_X + 0.15), MID_Y + sy * (COLUMN_HALF_Y + 0.15), PLINTH_TOP + 0.7, "z", 0.11)
			end
		end
	end
end, nil, function(x, y, z)
	local x0 = if x < -1.5 then COLUMN_X[1] else COLUMN_X[2]
	if z < PLINTH_TOP + 0.72 or (z > CROWN_BASE - 0.92 and (math.abs(x - x0) > COLUMN_HALF_X + 0.05 or math.abs(y - MID_Y) > COLUMN_HALF_Y + 0.05)) then
		local k = 0.9 + 0.12 * math.noise(x * 1.3, y * 1.3, z * 1.3)
		return BRONZE[1] * k, BRONZE[2] * k, BRONZE[3] * k
	end
	-- A step lighter than the plinth and crown, so the frame reads apart.
	local k = 0.94 + 0.1 * math.noise(x * 0.6, z * 0.6, 6.4)
	return COLUMN_STEEL[1] * k, COLUMN_STEEL[2] * k, COLUMN_STEEL[3] * k
end, nil, nil, nil, 0.25)

-- Block letters for the name plate, five wide and seven tall.
local GLYPHS = {
	R = { "1111.", "1...1", "1...1", "1111.", "1.1..", "1..1.", "1...1" },
	E = { "11111", "1....", "1....", "1111.", "1....", "1....", "11111" },
	B = { "1111.", "1...1", "1...1", "1111.", "1...1", "1...1", "1111." },
	I = { "11111", "..1..", "..1..", "..1..", "..1..", "..1..", "11111" },
	T = { "11111", "..1..", "..1..", "..1..", "..1..", "..1..", "..1.." },
	H = { "1...1", "1...1", "1...1", "11111", "1...1", "1...1", "1...1" },
}
local NAME = "REBIRTH"
local PLATE_X0, PLATE_X1, PLATE_Z0, PLATE_Z1 = -4.6, 1.6, 11.1, 12.3
local function nameAt(x: number, z: number): boolean
	local cell = (PLATE_X1 - PLATE_X0 - 0.5) / (#NAME * 6 - 1)
	local u = (x - PLATE_X0 - 0.25) / cell
	local v = (PLATE_Z1 - 0.2 - z) / cell
	local letter = math.floor(u / 6) + 1
	local col, row = math.floor(u % 6) + 1, math.floor(v) + 1
	if letter < 1 or letter > #NAME or col > 5 or row < 1 or row > 7 then
		return false
	end
	local glyph = GLYPHS[NAME:sub(letter, letter)]
	return glyph ~= nil and glyph[row]:sub(col, col) == "1"
end

part("Crown", nil, PRESS_DARK, function(mesh)
	box(mesh, (CROWN_X0 + CROWN_X1) / 2, MID_Y, CROWN_BASE, CROWN_X1 - CROWN_X0, 4, CROWN_TOP - CROWN_BASE)
	-- The bronze name plate on the front, the gauge beside it.
	box(mesh, (PLATE_X0 + PLATE_X1) / 2, MID_Y - 2.05, PLATE_Z0, PLATE_X1 - PLATE_X0, 0.14, PLATE_Z1 - PLATE_Z0)
	for _, x in { PLATE_X0 + 0.2, PLATE_X1 - 0.2 } do
		for _, z in { PLATE_Z0 + 0.2, PLATE_Z1 - 0.2 } do
			bolt(mesh, x, MID_Y - 2.12, z, "y", 0.08)
		end
	end
	cylinder(mesh, 2.9, MID_Y - 2.1, 11.7, 0.7, 0.2, "y", 16)
	ring(mesh, 2.9, MID_Y - 2.18, 11.7, 0.6, 0.78, 0.12, "y", 16)
	-- Rivets along the top and bottom edges, front and back.
	for _, sy in { -1, 1 } do
		rivets(mesh, CROWN_X0 + 0.3, MID_Y + sy * 2, CROWN_BASE + 0.35, CROWN_X1 - 0.3, MID_Y + sy * 2, CROWN_BASE + 0.35, 9, "y", 0.09)
		rivets(mesh, CROWN_X0 + 0.3, MID_Y + sy * 2, CROWN_TOP - 0.35, CROWN_X1 - 0.3, MID_Y + sy * 2, CROWN_TOP - 0.35, 9, "y", 0.09)
	end
end, nil, function(x, y, z)
	if y < MID_Y - 2.02 and x > PLATE_X0 and x < PLATE_X1 and z > PLATE_Z0 and z < PLATE_Z1 then
		if nameAt(x, z) then
			return 0.22, 0.14, 0.07
		end
		local k = 0.95 + 0.1 * math.noise(x * 1.5, z * 1.5, 2.9)
		return BRONZE[1] * k, BRONZE[2] * k, BRONZE[3] * k
	end
	-- The gauge: cream face, a dark needle.
	local gx, gz = x - 2.9, z - 11.7
	local gr = math.sqrt(gx * gx + gz * gz)
	if y < MID_Y - 2.15 and gr < 0.62 then
		local needle = math.abs(gx * 0.8 - gz * 0.6) < 0.05 and gx * 0.6 + gz * 0.8 > -0.1
		if needle or gr > 0.52 then
			return 0.12, 0.1, 0.1
		end
		return 0.92, 0.9, 0.82
	end
	local k = 0.94 + 0.1 * math.noise(x * 0.6, z * 0.6, 7.7)
	return PRESS_DARK[1] * k, PRESS_DARK[2] * k, PRESS_DARK[3] * k
end, nil, nil, true, 0.25)
crisp()

-- ------------------------------------------------------- the hydraulics
part("Cylinder", nil, PRESS_STEEL, function(mesh)
	cylinder(mesh, MID_X, MID_Y, (CROWN_TOP + CYL_TOP - 0.6) / 2, CYL_R, CYL_TOP - 0.6 - CROWN_TOP, "z", 20)
	sphere(mesh, MID_X, MID_Y, CYL_TOP - 0.64, CYL_R, CYL_R, 0.64, 5, 20)
	ring(mesh, MID_X, MID_Y, CROWN_TOP + 0.3, CYL_R + 0.02, CYL_R + 0.3, 0.6, "z", 20)
	ring(mesh, MID_X, MID_Y, CYL_TOP - 0.7, CYL_R - 0.1, CYL_R + 0.25, 0.3, "z", 20)
	for i = 0, 9 do
		local t = i / 10 * TAU
		bolt(mesh, MID_X + math.cos(t) * (CYL_R + 0.08), MID_Y + math.sin(t) * (CYL_R + 0.08), CYL_TOP - 0.55, "z", 0.1)
	end
	-- Hose fittings on the -x side.
	for _, dy in { -0.5, 0.5 } do
		cylinder(mesh, MID_X - CYL_R - 0.2, MID_Y + dy, CYL_TOP - 1.3, 0.22, 0.5, "x", 8)
	end
end, nil, 0.25, nil, nil, nil, 0.2)

part("Ram", nil, BARE, function(mesh)
	cylinder(mesh, MID_X, MID_Y, (PLATEN_TOP + CROWN_BASE) / 2, 0.8, CROWN_BASE - PLATEN_TOP, "z", 16)
	cylinder(mesh, MID_X, MID_Y, CROWN_BASE - 0.35, 1.3, 0.7, "z", 16)
	cylinder(mesh, MID_X, MID_Y, PLATEN_TOP + 0.3, 1.3, 0.6, "z", 16)
end, nil, 0.1, nil, nil, nil, 0.15)

part("Platen", nil, PRESS_DARK, function(mesh)
	box(mesh, MID_X, MID_Y, PLATEN_BASE, 7, 5, PLATEN_TOP - PLATEN_BASE)
	for _, sy in { -1, 1 } do
		rivets(mesh, MID_X - 3, MID_Y + sy * 2.5, PLATEN_TOP - 0.2, MID_X + 3, MID_Y + sy * 2.5, PLATEN_TOP - 0.2, 7, "y", 0.09)
	end
end, nil, function(x, y, z)
	-- The hazard rim round the lower half of the sides.
	if z < PLATEN_BASE + 0.45 and (math.abs(x - MID_X) > 3.45 or math.abs(y - MID_Y) > 2.45) then
		local along = if math.abs(y - MID_Y) > 2.45 then x else y
		if tape(along, z) then
			return TAPE_BLACK[1], TAPE_BLACK[2], TAPE_BLACK[3]
		end
		return HAZARD[1], HAZARD[2], HAZARD[3]
	end
	local k = 0.94 + 0.1 * math.noise(x * 0.7, y * 0.7, 5.5)
	return PRESS_DARK[1] * k, PRESS_DARK[2] * k, PRESS_DARK[3] * k
end, nil, nil, true, 0.2)
crisp()

-- --------------------------------------------------------- the scrap pile
-- Steady pseudo-random number in -1..1 for whole numbers a, b.
local function jitter(a: number, b: number): number
	local s = math.sin(a * 127.1 + b * 311.7) * 43758.5453
	return 2 * (s - math.floor(s)) - 1
end
part("Pile", nil, RUST, function(mesh)
	-- A heap of mounds to a low peak, then junk pressed into its surface.
	local heap = {
		{ 0, 0, 2.4, 1.7, 2.9 },
		{ -1.8, -0.6, 1.8, 1.3, 1.9 },
		{ 1.6, 0.5, 1.7, 1.2, 1.7 },
		{ -0.4, 1.2, 1.6, 1.0, 1.4 },
		{ 0.8, -1.3, 1.5, 1.0, 1.3 },
		{ -2.4, 0.9, 1.2, 0.8, 0.9 },
		{ 2.3, -0.9, 1.2, 0.8, 0.9 },
	}
	-- Each mound's centre sits a little above the anvil, so less of it is
	-- buried; what is buried is hidden in the anvil.
	for _, h in heap do
		sphere(mesh, MID_X + h[1], MID_Y + h[2], ANVIL_TOP + 0.5, h[3], h[4], h[5] - 0.5, 6, 12)
	end
	-- Small pipe ends and crushed cans pressed into the surface; the big
	-- pieces are PileJunk.
	for i = 1, 6 do
		local a = i / 6 * TAU + 0.4
		local r = 1.6 + 0.6 * jitter(i, 1)
		local x, y = MID_X + math.cos(a) * r, MID_Y + math.sin(a) * r * 0.7
		local z = ANVIL_TOP + 0.5 + 0.6 * (1 - r / 2.6) * 2
		cylinder(mesh, x, y, z, 0.26, 0.8, if i % 3 == 0 then "z" elseif i % 3 == 1 then "x" else "y", 10)
	end
end, nil, function(x, y, z)
	-- Rusty steel, bare where the junk sticks out, paint flecks here and there.
	local n = math.noise(x * 1.6, y * 1.6, z * 1.6)
	local k = 0.85 + 0.3 * n
	if n > 0.42 then
		return BARE[1] * 0.8, BARE[2] * 0.8, BARE[3] * 0.8
	end
	local fleck = math.noise(x * 3.1, y * 3.1, z * 3.1 + 9)
	if fleck > 0.52 then
		return 0.2, 0.42, 0.68
	elseif fleck < -0.55 then
		return 0.84, 0.3, 0.2
	end
	return RUST[1] * k, RUST[2] * k, RUST[3] * k
end, nil, nil, nil, 0.2)

-- The big pieces in the heap, each in its own finish: a gear standing in
-- it, a hubcap leaning on the side, a stack of painted cans, a spring.
local GEAR_AT = { MID_X - 1.3, MID_Y - 0.5, ANVIL_TOP + 2.3 }
local HUBCAP_AT = { MID_X + 1.6, MID_Y - 1.7, ANVIL_TOP + 1.5 }
local CANS_AT = { MID_X + 1.1, MID_Y + 1.1 }
local SPRING_AT = { MID_X - 0.6, MID_Y + 1.6 }
part("PileJunk", nil, BRASS, function(mesh)
	gear(mesh, GEAR_AT[1], GEAR_AT[2], GEAR_AT[3], 1.05, 0.26, 12, "x")
	ring(mesh, GEAR_AT[1], GEAR_AT[2], GEAR_AT[3], 0.55, 0.72, 0.3, "x", 16)
	cylinder(mesh, HUBCAP_AT[1], HUBCAP_AT[2], HUBCAP_AT[3], 1.0, 0.18, "y", 16)
	sphere(mesh, HUBCAP_AT[1], HUBCAP_AT[2] - 0.12, HUBCAP_AT[3], 0.4, 0.22, 0.4, 4, 12)
	for _, c in { { -0.45, 0, 0.5 }, { 0.45, 0, 0.5 }, { 0, 0.05, 1.45 } } do
		cylinder(mesh, CANS_AT[1] + c[1], CANS_AT[2] + c[2], ANVIL_TOP + 0.9 + c[3], 0.42, 0.95, "z", 12)
	end
	for i = 0, 4 do
		ring(mesh, SPRING_AT[1], SPRING_AT[2], ANVIL_TOP + 1.3 + i * 0.22, 0.26, 0.4, 0.12, "z", 12)
	end
end, nil, function(x, y, z)
	local function near(ax, ay, az, r)
		return (x - ax) ^ 2 + (y - ay) ^ 2 + (z - az) ^ 2 < r * r
	end
	if near(GEAR_AT[1], GEAR_AT[2], GEAR_AT[3], 1.4) then
		local k = 0.9 + 0.12 * math.noise(y * 2, z * 2, 1.2)
		return BRASS[1] * k, BRASS[2] * k, BRASS[3] * k
	elseif near(HUBCAP_AT[1], HUBCAP_AT[2], HUBCAP_AT[3], 1.3) then
		local k = 0.9 + 0.1 * math.noise(x * 2, z * 2, 2.2)
		return SILVER[1] * k, SILVER[2] * k, SILVER[3] * k
	elseif near(SPRING_AT[1], SPRING_AT[2], ANVIL_TOP + 1.8, 1.0) then
		return PRESS_STEEL[1], PRESS_STEEL[2], PRESS_STEEL[3]
	end
	-- Cans: red, blue and cream, a white label band round the middle.
	local can = if x < CANS_AT[1] - 0.1 and z < ANVIL_TOP + 1.9 then 1 elseif z < ANVIL_TOP + 1.9 then 2 else 3
	local mid = (z - ANVIL_TOP - 0.9) % 0.95
	if mid > 0.3 and mid < 0.62 then
		return 0.92, 0.9, 0.84
	end
	if can == 1 then
		return 0.8, 0.22, 0.16
	elseif can == 2 then
		return 0.2, 0.42, 0.72
	end
	return 0.88, 0.76, 0.4
end, nil, nil, nil, 0.1)

-- ------------------------------------------------------- front and side
part("Tray", nil, PRESS_STEEL, function(mesh)
	box(mesh, MID_X, -4.7, 0.75, 3.2, 1.6, 0.12)
	box(mesh, MID_X - 1.5, -4.7, 0.87, 0.1, 1.6, 0.38)
	box(mesh, MID_X + 1.5, -4.7, 0.87, 0.1, 1.6, 0.38)
	box(mesh, MID_X, -5.4, 0.87, 3.0, 0.1, 0.38)
	-- Two legs down to the ground.
	for _, dx in { -1.3, 1.3 } do
		box(mesh, MID_X + dx, -5.3, 0, 0.2, 0.2, 0.75)
	end
	-- The medal lying in the tray, a raised rim and a boss.
	cylinder(mesh, MID_X + 0.1, -4.6, 1.0, 1.1, 0.26, "z", 20)
	ring(mesh, MID_X + 0.1, -4.6, 1.16, 0.86, 1.04, 0.1, "z", 20)
	cylinder(mesh, MID_X + 0.1, -4.6, 1.18, 0.36, 0.16, "z", 10)
end, nil, function(x, y, z)
	if z > 0.85 and math.sqrt((x - MID_X - 0.1) ^ 2 + (y + 4.6) ^ 2) < 1.15 then
		local k = 1.08 + 0.1 * math.noise(x * 3, y * 3, 1.1)
		return BRASS[1] * k, BRASS[2] * k, BRASS[3] * k
	end
	local k = 0.9 + 0.1 * math.noise(x * 1.2, y * 1.2, z * 1.2)
	return PRESS_STEEL[1] * k, PRESS_STEEL[2] * k, PRESS_STEEL[3] * k
end, nil, nil, nil, 0.15)

part("Console", nil, PRESS_DARK, function(mesh)
	box(mesh, CONSOLE_X, CONSOLE_Y, PLINTH_TOP, 2.4, 2.4, 2.8)
	-- The sloped top panel, higher at the back.
	local x0, x1, y0, y1 = CONSOLE_X - 1.25, CONSOLE_X + 1.25, CONSOLE_Y - 1.25, CONSOLE_Y + 1.25
	local z0, z1 = PLINTH_TOP + 2.8, PLINTH_TOP + 3.4
	local a1, a2, a3, a4 = mesh:vertex(x0, y0, z0), mesh:vertex(x1, y0, z0), mesh:vertex(x1, y1, z0), mesh:vertex(x0, y1, z0)
	local b1, b2, b3, b4 = mesh:vertex(x0, y0, z0 + 0.2), mesh:vertex(x1, y0, z0 + 0.2), mesh:vertex(x1, y1, z1), mesh:vertex(x0, y1, z1)
	mesh:face({ a1, a2, b2, b1 })
	mesh:face({ a2, a3, b3, b2 })
	mesh:face({ a3, a4, b4, b3 })
	mesh:face({ a4, a1, b1, b4 })
	mesh:face({ b1, b2, b3, b4 })
	mesh:face({ a4, a3, a2, a1 })
	-- The button's bezel, the cage's hinge posts, a lever, the lamp's stalk.
	cylinder(mesh, CONSOLE_X - 0.3, CONSOLE_Y - 0.2, z0 + 0.45, 0.62, 0.2, "z", 16)
	for _, dx in { -0.95, 0.35 } do
		for _, dy in { -0.9, 0.5 } do
			box(mesh, CONSOLE_X + dx, CONSOLE_Y + dy, z0 + 0.35, 0.14, 0.14, 1.1)
		end
	end
	cylinder(mesh, CONSOLE_X + 0.85, CONSOLE_Y - 0.6, z0 + 0.35, 0.08, 1.2, "z", 6)
	sphere(mesh, CONSOLE_X + 0.85, CONSOLE_Y - 0.6, z0 + 0.95, 0.18, 0.18, 0.18, 4, 8)
	cylinder(mesh, CONSOLE_X + 0.85, CONSOLE_Y + 0.7, z0 + 0.9, 0.06, 1.6, "z", 6)
	-- A small gauge on the front face.
	cylinder(mesh, CONSOLE_X, CONSOLE_Y - 1.26, PLINTH_TOP + 2.1, 0.4, 0.12, "y", 14)
end, nil, function(x, y, z)
	if y < CONSOLE_Y - 1.28 and math.sqrt((x - CONSOLE_X) ^ 2 + (z - PLINTH_TOP - 2.1) ^ 2) < 0.34 then
		return 0.92, 0.9, 0.82
	end
	-- The top panel lighter steel.
	if z > PLINTH_TOP + 2.78 then
		local k = 0.95 + 0.08 * math.noise(x * 2, y * 2, 3.3)
		return PRESS_STEEL[1] * k, PRESS_STEEL[2] * k, PRESS_STEEL[3] * k
	end
	local k = 0.94 + 0.1 * math.noise(x * 0.8, y * 0.8, z * 0.8)
	return PRESS_DARK[1] * k, PRESS_DARK[2] * k, PRESS_DARK[3] * k
end, nil, nil, nil, 0.2)

part("Cage", nil, HAZARD, function(mesh)
	-- A hinged yellow cage over the button: a frame of thin bars.
	local z = PLINTH_TOP + 2.8 + 1.45
	local x0, x1, y0, y1 = CONSOLE_X - 0.95, CONSOLE_X + 0.35, CONSOLE_Y - 0.9, CONSOLE_Y + 0.5
	strut(mesh, x0, y0, z, x1, y0, z, 0.1)
	strut(mesh, x1, y0, z, x1, y1, z, 0.1)
	strut(mesh, x1, y1, z, x0, y1, z, 0.1)
	strut(mesh, x0, y1, z, x0, y0, z, 0.1)
	strut(mesh, x0, (y0 + y1) / 2, z, x1, (y0 + y1) / 2, z, 0.07)
	strut(mesh, (x0 + x1) / 2, y0, z, (x0 + x1) / 2, y1, z, 0.07)
end, nil, 0.1, nil, nil, true, 0.1)

part("Button", nil, BUTTON_RED, function(mesh)
	cylinder(mesh, CONSOLE_X - 0.3, CONSOLE_Y - 0.2, PLINTH_TOP + 2.8 + 0.75, 0.5, 0.4, "z", 16)
	sphere(mesh, CONSOLE_X - 0.3, CONSOLE_Y - 0.2, PLINTH_TOP + 2.8 + 0.92, 0.5, 0.5, 0.21, 4, 16)
	-- The lamp on its stalk.
	sphere(mesh, CONSOLE_X + 0.85, CONSOLE_Y + 0.7, PLINTH_TOP + 2.8 + 1.85, 0.22, 0.22, 0.26, 6, 10)
end, true, 0, nil, 1.2)

-- The hoses run from the cylinder over the crown's back edge and down the
-- back of the -x column to the pump behind it.
local PUMP_X, PUMP_Y = COLUMN_X[1] - 0.9, MID_Y + 2.6
part("Hoses", nil, HOSE_GREY, function(mesh)
	for i, dy in { -0.5, 0.5 } do
		local x = PUMP_X - 0.35 + (i - 1) * 0.7
		tube(mesh, {
			{ MID_X - CYL_R - 0.4, MID_Y + dy, CYL_TOP - 1.3 },
			{ MID_X - CYL_R - 1.0, MID_Y + dy, CYL_TOP - 1.5 },
			{ x, MID_Y + dy, CROWN_TOP + 0.5 },
			{ x, PUMP_Y + 0.3, CROWN_TOP + 0.3 },
			{ x, PUMP_Y + 0.3, PLINTH_TOP + 1.5 },
		}, 0.14, 8)
	end
end, nil, 0.1, nil, nil, nil, 0.1)

part("Pump", nil, PRESS_STEEL, function(mesh)
	box(mesh, PUMP_X, PUMP_Y, PLINTH_TOP, 1.8, 1.6, 1.5)
	sphere(mesh, PUMP_X - 0.35, PUMP_Y - 0.2, PLINTH_TOP + 1.48, 0.55, 0.55, 0.5, 4, 12)
	cylinder(mesh, PUMP_X + 0.5, PUMP_Y - 0.4, PLINTH_TOP + 1.6, 0.16, 0.34, "z", 8)
	-- Collars where the hoses enter the top.
	for _, dx in { -0.35, 0.35 } do
		ring(mesh, PUMP_X + dx, PUMP_Y + 0.3, PLINTH_TOP + 1.5, 0.14, 0.26, 0.3, "z", 10)
	end
end, nil, 0.3, nil, nil, nil, 0.15)

part("Collars", nil, BRASS, function(mesh)
	-- Brass bands on the hoses where they bend, so their route reads.
	for i = 1, 2 do
		local x = PUMP_X - 0.35 + (i - 1) * 0.7
		ring(mesh, x, PUMP_Y + 0.3, CROWN_TOP - 0.2, 0.15, 0.26, 0.4, "z", 10)
		ring(mesh, x, PUMP_Y + 0.3, PLINTH_TOP + 3.5, 0.15, 0.26, 0.4, "z", 10)
		ring(mesh, MID_X - CYL_R - 0.7, MID_Y + (i - 1.5), CYL_TOP - 1.4, 0.15, 0.26, 0.4, "x", 10)
	end
end, nil, 0.1, nil, nil, nil, 0.1)

part("Beacons", nil, { 1, 0.6, 0.15 }, function(mesh)
	for _, x in { CROWN_X0 + 0.5, CROWN_X1 - 0.5 } do
		for _, sy in { -1, 1 } do
			sphere(mesh, x, MID_Y + sy * 1.5, CROWN_TOP + 0.3, 0.3, 0.3, 0.3, 6, 10)
		end
	end
end, true, 0, nil, 1.5)

finishParts()
