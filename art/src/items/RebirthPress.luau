-- mates: Plinth Tray, Pile Anvil, Pile PileJunk
-- Rebirth Press: the hydraulic press in a yard that flattens its scrap pile
-- into a medal (art/concepts/rebirth-press-sketch.png, RebirthPress.plan.luau).
-- 16 x 8 on the ground and 15.2 tall, the origin at the middle of the
-- footprint at ground level, z up, the front (console, medal tray) on the
-- -y side. Riveted dark steel with bronze caps and plate, crisp hazard tape,
-- the yard's scrap heaped on the anvil under the platen.
-- include: HandFinish

-- Baked at the yard kit's density (KIT_DENSITY in the ServerMap layout), as it
-- is in game.
useTexelDensity(40)

local PRESS_DARK = { 0.2, 0.21, 0.24 }
local PRESS_STEEL = { 0.42, 0.45, 0.5 }
local COLUMN_STEEL = { 0.28, 0.3, 0.34 }
local HOSE_GREY = { 0.3, 0.31, 0.34 }
local SILVER = { 0.72, 0.74, 0.77 }
local BARE = { 0.68, 0.7, 0.73 }
-- Darker than the brushed bronze of the sky cog: on a crisp coat the lighter
-- tone reads as planed wood.
local BRONZE = { 0.56, 0.38, 0.19 }
local BRASS = { 0.86, 0.68, 0.32 }
local HAZARD = { 0.86, 0.64, 0.16 }
local TAPE_BLACK = { 0.08, 0.08, 0.09 }
local CONCRETE = { 0.62, 0.6, 0.56 }
local RUST = { 0.46, 0.27, 0.16 }
local BUTTON_RED = { 1.0, 0.2, 0.15 }

-- The anvil, ram and platen share one axis; the console sits at the +x end.
local MID_X, MID_Y = -1.5, 0.4
local PLINTH_TOP = 1.2
-- The game centres a yard thing's bounding box on its cells, so nothing
-- reaches past the concrete pad's 16 x 8. The steel bed stands back from the
-- pad's front edge, leaving room for the medal's ramp.
local PLINTH_HALF_X, PLINTH_FRONT, PLINTH_BACK = 7.8, -2.6, 3.8
local ANVIL_TOP = PLINTH_TOP + 1.3
local PLATEN_BASE, PLATEN_TOP = 6.1, 7
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
	-- A concrete pad the size of the press's cells, the steel bed on it.
	box(mesh, 0, 0, 0, 16, 8, 0.3)
	box(mesh, 0, (PLINTH_FRONT + PLINTH_BACK) / 2, 0.3, 2 * PLINTH_HALF_X, PLINTH_BACK - PLINTH_FRONT, PLINTH_TOP - 0.3)
	-- Rivets along each face, under the hazard band.
	for _, y in { PLINTH_FRONT, PLINTH_BACK } do
		rivets(mesh, -7.4, y, 0.6, 7.4, y, 0.6, 8, "y", 0.09)
	end
	for _, x in { -PLINTH_HALF_X, PLINTH_HALF_X } do
		rivets(mesh, x, PLINTH_FRONT + 0.4, 0.6, x, PLINTH_BACK - 0.4, 0.6, 4, "x", 0.09)
	end
end, nil, function(x, y, z)
	if z < 0.32 then
		local k = 0.92 + 0.08 * math.noise(x * 0.8, y * 0.8, 3.1)
		return CONCRETE[1] * k, CONCRETE[2] * k, CONCRETE[3] * k
	end
	-- The hazard band round the top.
	local onEnd = math.abs(x) > PLINTH_HALF_X - 0.1
	local onLong = y < PLINTH_FRONT + 0.1 or y > PLINTH_BACK - 0.1
	if z > PLINTH_TOP - 0.3 and z < PLINTH_TOP + 0.01 and (onEnd or onLong) then
		if tape(if onLong then x else y, z) then
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
		-- Rivets down each front and back edge, and the side edges.
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				rivets(mesh, x + sx * (COLUMN_HALF_X - 0.3), MID_Y + sy * COLUMN_HALF_Y, 2.4, x + sx * (COLUMN_HALF_X - 0.3), MID_Y + sy * COLUMN_HALF_Y, 9.4, 6, "y", 0.09)
				rivets(mesh, x + sx * COLUMN_HALF_X, MID_Y + sy * (COLUMN_HALF_Y - 0.3), 2.4, x + sx * COLUMN_HALF_X, MID_Y + sy * (COLUMN_HALF_Y - 0.3), 9.4, 6, "x", 0.09)
			end
		end
	end
end, nil, function(x, y, z)
	-- A step lighter than the plinth and crown, so the frame reads apart.
	local k = 0.94 + 0.1 * math.noise(x * 0.6, z * 0.6, 6.4)
	return COLUMN_STEEL[1] * k, COLUMN_STEEL[2] * k, COLUMN_STEEL[3] * k
end, nil, nil, nil, 0.25)

-- The bronze foot plates and cap bands, a part of their own so they go on
-- crisp while the columns stay brushed.
part("Bands", nil, BRONZE, function(mesh)
	for _, x in COLUMN_X do
		-- Collars round the column, four plates each, not blocks through it.
		local function collar(z: number, tall: number, out: number)
			local wx, wy = COLUMN_HALF_X + out / 2, COLUMN_HALF_Y + out / 2
			for _, s in { -1, 1 } do
				box(mesh, x + s * wx, MID_Y, z, out, 2 * COLUMN_HALF_Y + 2 * out, tall)
				box(mesh, x, MID_Y + s * wy, z, 2 * COLUMN_HALF_X - 0.02, out, tall)
			end
		end
		collar(PLINTH_TOP, 0.7, 0.25)
		collar(CROWN_BASE - 0.9, 0.9, 0.15)
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				bolt(mesh, x + sx * (COLUMN_HALF_X + 0.15), MID_Y + sy * (COLUMN_HALF_Y + 0.15), PLINTH_TOP + 0.7, "z", 0.11)
			end
		end
	end
end, nil, function(x, y, z)
	local k = 0.9 + 0.12 * math.noise(x * 1.3, y * 1.3, z * 1.3)
	return BRONZE[1] * k, BRONZE[2] * k, BRONZE[3] * k
end, nil, nil, true, 0.25)
crisp()

-- Block letters for the name plate, five wide and seven tall.
local GLYPHS = {
	R = { "1111.", "1...1", "1...1", "1111.", "1.1..", "1..1.", "1...1" },
	E = { "11111", "11...", "11...", "1111.", "11...", "11...", "11111" },
	B = { "1111.", "11..1", "11..1", "1111.", "11..1", "11..1", "1111." },
	I = { "11111", "..1..", "..1..", "..1..", "..1..", "..1..", "11111" },
	T = { "11111", "..1..", "..1..", "..1..", "..1..", "..1..", "..1.." },
	H = { "1...1", "1...1", "1...1", "11111", "1...1", "1...1", "1...1" },
}
local NAME = "REBIRTH"
local PLATE_X0, PLATE_X1, PLATE_Z0, PLATE_Z1 = -5.1, 2.1, 10.95, 12.45
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
			return 0.09, 0.06, 0.04
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
-- A spot on the anvil: across and along from its middle, height above its top.
local function onAnvil(across: number, along: number, height: number)
	return { MID_X + across, MID_Y + along, ANVIL_TOP + height }
end
-- The axes of something tipped by `pitch` about its own x and `roll` about its
-- own y, then turned by `yaw` about z (degrees).
local function tiltAxes(yaw: number, pitch: number, roll: number)
	local ca, sa = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
	local cp, sp = math.cos(math.rad(pitch)), math.sin(math.rad(pitch))
	local cr, sr = math.cos(math.rad(roll)), math.sin(math.rad(roll))
	return { ca * cr - sa * sp * sr, sa * cr + ca * sp * sr, -cp * sr },
		{ -sa * cp, ca * cp, sp },
		{ ca * sr + sa * sp * cr, sa * sr - ca * sp * cr, cp * cr }
end
-- A tilted block, each corner pushed about by up to `dent`. `turn` is
-- { yaw, pitch, roll }.
local function crushedBlock(mesh, centre, size, turn, dent: number, seed: number)
	local u, v, w = tiltAxes(turn[1], turn[2], turn[3])
	local corners = {}
	for i = 0, 7 do
		local a = (if i % 2 == 0 then -0.5 else 0.5) * size[1] + dent * jitter(seed, i)
		local b = (if i // 2 % 2 == 0 then -0.5 else 0.5) * size[2] + dent * jitter(seed, i + 8)
		local c = (if i // 4 == 0 then -0.5 else 0.5) * size[3] + dent * jitter(seed, i + 16)
		corners[i + 1] = mesh:vertex(centre[1] + u[1] * a + v[1] * b + w[1] * c, centre[2] + u[2] * a + v[2] * b + w[2] * c, centre[3] + u[3] * a + v[3] * b + w[3] * c)
	end
	for _, f in { { 1, 3, 4, 2 }, { 5, 6, 8, 7 }, { 1, 2, 6, 5 }, { 3, 7, 8, 4 }, { 1, 5, 7, 3 }, { 2, 4, 8, 6 } } do
		mesh:face({ corners[f[1]], corners[f[2]], corners[f[3]], corners[f[4]] })
	end
end
-- A bale of crushed sheet: thin layers, each knocked a little out of line.
local function bale(mesh, centre, size, turn, seed: number)
	local u, v, w = tiltAxes(turn[1], turn[2], turn[3])
	local layers = math.max(math.round(size[3] / 0.38), 2)
	local thick = size[3] / layers
	for k = 1, layers do
		local up = (k - (layers + 1) / 2) * thick
		local a, b = 0.1 * jitter(seed, k), 0.1 * jitter(seed, k + 20)
		crushedBlock(mesh, {
			centre[1] + u[1] * a + v[1] * b + w[1] * up,
			centre[2] + u[2] * a + v[2] * b + w[2] * up,
			centre[3] + u[3] * a + v[3] * b + w[3] * up,
		}, { size[1], size[2], thick + 0.04 }, turn, 0.07, seed * 10 + k)
	end
end
-- A plate bent across its width: each leaf carries on from the last one's far
-- edge. `leaves` lists { pitch, length }.
local function bentSheet(mesh, start, width: number, yaw: number, leaves)
	local x, y, z = start[1], start[2], start[3]
	for i, leaf in leaves do
		local _, _, w = tiltAxes(yaw, leaf[1], 0)
		local length = leaf[2]
		crushedBlock(mesh, { x + w[1] * length / 2, y + w[2] * length / 2, z + w[3] * length / 2 }, { width, 0.12, length + 0.06 }, { yaw, leaf[1], 0 }, 0.02, 40 + i)
		x, y, z = x + w[1] * length, y + w[2] * length, z + w[3] * length
	end
end

-- A fat pipe in the heap, its open end toward whoever walks up.
local PIPE_AT = onAnvil(-0.9, -1, 0.55)
local PIPE_BORE, PIPE_LENGTH = 0.3, 1.7

part("Pile", nil, RUST, function(mesh)
	-- Two low mounds at the back give the heap its mass; all the rest has edges.
	for _, h in { { -0.6, 1.2, 2.3, 1.1, 1.5 }, { 1.9, 1.1, 1.3, 1.0, 1.2 } } do
		-- They sit on the anvil, not through it.
		sphere(mesh, MID_X + h[1], MID_Y + h[2], ANVIL_TOP + h[5] - 0.5, h[3], h[4], h[5] - 0.5, 6, 12)
	end
	-- Bales of crushed sheet, the last thrown on top of the others.
	bale(mesh, onAnvil(0.9, 0.1, 0.6), { 3, 2.1, 1.5 }, { 14, 4, -6 }, 1)
	bale(mesh, onAnvil(-1.3, 0.35, 0.55), { 2.4, 1.9, 1.4 }, { -16, -3, 8 }, 2)
	bale(mesh, onAnvil(2.35, -0.2, 0.55), { 1.5, 1.4, 1.3 }, { -22, 5, 9 }, 3)
	bale(mesh, onAnvil(0.05, 0.4, 1.8), { 2.5, 1.7, 0.95 }, { 26, 5, -9 }, 4)
	ring(mesh, PIPE_AT[1], PIPE_AT[2], PIPE_AT[3], PIPE_BORE, 0.5, PIPE_LENGTH, "y", 14)
	-- A plate bent over the heap's left shoulder.
	bentSheet(mesh, onAnvil(-2.6, -1.45, -0.02), 1.5, -12, { { -18, 1.25 }, { -62, 0.8 } })
	-- Bits that fell off, along the anvil's front edge.
	crushedBlock(mesh, onAnvil(-2.95, -2.05, 0.07), { 0.7, 0.45, 0.16 }, { 33, 0, 6 }, 0.05, 21)
	crushedBlock(mesh, onAnvil(1.55, -2.15, 0.07), { 0.6, 0.4, 0.14 }, { -40, 4, 0 }, 0.05, 22)
end, nil, function(x, y, z)
	-- Dark down the pipe's bore.
	if (x - PIPE_AT[1]) ^ 2 + (z - PIPE_AT[3]) ^ 2 < (PIPE_BORE + 0.02) ^ 2 and y > PIPE_AT[2] - PIPE_LENGTH / 2 + 0.02 then
		return 0.05, 0.05, 0.06
	end
	-- Rusty steel, bare in patches, paint flecks here and there.
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

-- The big pieces in the heap, each in its own finish, all on its front where a
-- player can see them: a gear standing in it facing out, a hubcap against the
-- right-hand bale, a stack of painted cans, a spring on the bale behind them.
local GEAR_AT = onAnvil(-1.25, -0.5, 1.2)
local HUBCAP_AT = onAnvil(2.55, -0.85, 0.85)
local CANS_AT = onAnvil(0.55, -1.85, 0.02)
local CAN_TALL = 0.95
-- One standing, one knocked over and lying along the front edge, one crushed flat.
local CAN_RED = { 0.8, 0.22, 0.16 }
local CAN_BLUE = { 0.2, 0.42, 0.72 }
local CAN_CREAM = { 0.88, 0.76, 0.4 }
local CAN_OVER_AT = { CANS_AT[1] - 1.05, CANS_AT[2] - 0.05, CANS_AT[3] + 0.42 }
local CAN_FLAT_AT = { CANS_AT[1] + 1.25, CANS_AT[2] + 0.2, CANS_AT[3] + 0.17 }
local SPRING_AT = onAnvil(1.75, -0.35, 1.42)
local function tippedAbout(mesh, ox: number, oy: number, oz: number, yaw: number, pitch: number, roll: number)
	local ca, sa = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
	local cp, sp = math.cos(math.rad(pitch)), math.sin(math.rad(pitch))
	local cr, sr = math.cos(math.rad(roll)), math.sin(math.rad(roll))
	local ux, uy, uz = ca * cr - sa * sp * sr, sa * cr + ca * sp * sr, -cp * sr
	local vx, vy, vz = -sa * cp, ca * cp, sp
	local wx, wy, wz = ca * sr + sa * sp * cr, sa * sr - ca * sp * cr, cp * cr
	return {
		vertex = function(_self, x: number, y: number, z: number)
			local dx, dy, dz = x - ox, y - oy, z - oz
			return mesh:vertex(ox + ux * dx + vx * dy + wx * dz, oy + uy * dx + vy * dy + wy * dz, oz + uz * dx + vz * dy + wz * dz)
		end,
		face = function(_self, face)
			return mesh:face(face)
		end,
	}
end

part("PileJunk", nil, BRASS, function(mesh)
	-- The gear leans back into the heap, half buried; the hubcap is thrown on at
	-- an angle against the bale.
	local leaning = tippedAbout(mesh, GEAR_AT[1], GEAR_AT[2], GEAR_AT[3], 22, 34, -26)
	gear(leaning, GEAR_AT[1], GEAR_AT[2], GEAR_AT[3], 1.05, 0.26, 12, "y")
	ring(leaning, GEAR_AT[1], GEAR_AT[2], GEAR_AT[3], 0.55, 0.72, 0.3, "y", 16)
	local thrown = tippedAbout(mesh, HUBCAP_AT[1], HUBCAP_AT[2], HUBCAP_AT[3], -30, 40, 18)
	cylinder(thrown, HUBCAP_AT[1], HUBCAP_AT[2], HUBCAP_AT[3], 1.0, 0.18, "y", 16)
	sphere(thrown, HUBCAP_AT[1], HUBCAP_AT[2] - 0.12, HUBCAP_AT[3], 0.4, 0.22, 0.4, 4, 12)
	cylinder(mesh, CANS_AT[1], CANS_AT[2], CANS_AT[3] + 0.5 * CAN_TALL, 0.42, CAN_TALL, "z", 12)
	cylinder(mesh, CAN_OVER_AT[1], CAN_OVER_AT[2], CAN_OVER_AT[3], 0.42, CAN_TALL, "x", 12)
	cylinder(mesh, CAN_FLAT_AT[1], CAN_FLAT_AT[2], CAN_FLAT_AT[3], 0.58, 0.34, "z", 12)
	for i = 0, 4 do
		ring(mesh, SPRING_AT[1], SPRING_AT[2], SPRING_AT[3] + i * 0.22, 0.26, 0.4, 0.12, "z", 12)
	end
end, nil, function(x, y, z)
	-- Cans first, by where each one lies: red standing, blue fallen, cream crushed.
	if (x - CANS_AT[1]) ^ 2 + (y - CANS_AT[2]) ^ 2 < 0.2 and z < CANS_AT[3] + CAN_TALL + 0.02 then
		local mid = z - CANS_AT[3]
		if mid > 0.3 and mid < 0.62 then
			return 0.92, 0.9, 0.84
		end
		return CAN_RED[1], CAN_RED[2], CAN_RED[3]
	end
	if (y - CAN_OVER_AT[2]) ^ 2 + (z - CAN_OVER_AT[3]) ^ 2 < 0.2 and math.abs(x - CAN_OVER_AT[1]) < CAN_TALL / 2 + 0.02 then
		return CAN_BLUE[1], CAN_BLUE[2], CAN_BLUE[3]
	end
	if (x - CAN_FLAT_AT[1]) ^ 2 + (y - CAN_FLAT_AT[2]) ^ 2 < 0.36 and z < CAN_FLAT_AT[3] + 0.2 then
		return CAN_CREAM[1], CAN_CREAM[2], CAN_CREAM[3]
	end
	local function near(at, height: number, r: number): boolean
		return (x - at[1]) ^ 2 + (y - at[2]) ^ 2 + (z - height) ^ 2 < r * r
	end
	if near(GEAR_AT, GEAR_AT[3], 1.2) then
		local k = 0.9 + 0.12 * math.noise(x * 2, z * 2, 1.2)
		return BRASS[1] * k, BRASS[2] * k, BRASS[3] * k
	elseif near(SPRING_AT, SPRING_AT[3] + 0.45, 0.85) then
		return PRESS_STEEL[1], PRESS_STEEL[2], PRESS_STEEL[3]
	end
	local k = 0.9 + 0.1 * math.noise(x * 2, z * 2, 2.2)
	return SILVER[1] * k, SILVER[2] * k, SILVER[3] * k
end, nil, nil, nil, 0.1)
crisp()

-- ------------------------------------------------------- front and side
-- The medal's way out: a ramp from a dark mouth at the anvil's front edge
-- down to a lip at the pad's front, the medal resting at its foot and leaning
-- back, so its face is toward whoever walks up.
local RAMP_ANGLE = math.rad(52)
local RAMP_COS, RAMP_SIN = math.cos(RAMP_ANGLE), math.sin(RAMP_ANGLE)
local RAMP_FOOT_Y, RAMP_FOOT_Z, RAMP_TOP_Y = -3.6, 0.5, MID_Y - 2.5
local RAMP_TOP_Z = RAMP_FOOT_Z + (RAMP_TOP_Y - RAMP_FOOT_Y) * math.tan(RAMP_ANGLE)
local RAMP_LENGTH = (RAMP_TOP_Y - RAMP_FOOT_Y) / RAMP_COS
local MEDAL_R, MEDAL_BACK = 1.1, 0.13
local MEDAL_UP_RAMP = MEDAL_R + 0.06
local MEDAL_Y = RAMP_FOOT_Y + RAMP_COS * MEDAL_UP_RAMP - RAMP_SIN * (MEDAL_BACK - 0.01)
local MEDAL_Z = RAMP_FOOT_Z + RAMP_SIN * MEDAL_UP_RAMP + RAMP_COS * (MEDAL_BACK - 0.01)

part("Tray", nil, PRESS_STEEL, function(mesh)
	-- The ramp, a wedge across x: (y, z) corners anticlockwise from +x.
	local outline = { { RAMP_FOOT_Y, 0.3 }, { RAMP_TOP_Y, 0.3 }, { RAMP_TOP_Y, RAMP_TOP_Z }, { RAMP_FOOT_Y, RAMP_FOOT_Z } }
	local near, far = {}, {}
	for i, corner in outline do
		near[i] = mesh:vertex(MID_X - 1.5, corner[1], corner[2])
		far[i] = mesh:vertex(MID_X + 1.5, corner[1], corner[2])
	end
	for i = 1, #outline do
		local j = i % #outline + 1
		mesh:face({ near[i], near[j], far[j], far[i] })
	end
	mesh:face({ near[4], near[3], near[2], near[1] })
	mesh:face(far)
	-- The floor at its foot and the lip that stops the medal.
	box(mesh, MID_X, -3.78, 0.29, 2.8, 0.44, 0.2)
	box(mesh, MID_X, -3.91, 0.28, 3.2, 0.14, 0.5)
end, nil, function(x, y, z)
	local along = (y - RAMP_FOOT_Y) * RAMP_COS + (z - RAMP_FOOT_Z) * RAMP_SIN
	local off = (z - RAMP_FOOT_Z) * RAMP_COS - (y - RAMP_FOOT_Y) * RAMP_SIN
	local k = 0.9 + 0.1 * math.noise(x * 1.2, y * 1.2, z * 1.2)
	if math.abs(off) < 0.02 then
		-- The mouth at the top, dark, and the middle worn bright by medals.
		if along > RAMP_LENGTH - 0.5 and math.abs(x - MID_X) < 1.25 then
			return 0.02, 0.02, 0.02
		end
		if math.abs(x - MID_X) < 0.95 then
			k += 0.28
		end
	end
	return PRESS_STEEL[1] * k, PRESS_STEEL[2] * k, PRESS_STEEL[3] * k
end, nil, nil, true, 0.12)
crisp()

part("Medal", nil, BRASS, function(mesh)
	-- Back to front: { radius, height off its middle plane }, a raised rim
	-- and a boss.
	local profile = { { MEDAL_R, -MEDAL_BACK }, { MEDAL_R, 0.08 }, { MEDAL_R - 0.07, 0.15 }, { 0.86, 0.15 }, { 0.8, 0.08 }, { 0.4, 0.08 }, { 0.34, 0.2 } }
	local SIDES = 24
	local rows = {}
	for k, step in profile do
		local row = {}
		for i = 1, SIDES do
			local t = (i - 1) / SIDES * TAU
			local v, d = math.sin(t) * step[1], step[2]
			row[i] = mesh:vertex(MID_X + math.cos(t) * step[1], MEDAL_Y + v * RAMP_COS - d * RAMP_SIN, MEDAL_Z + v * RAMP_SIN + d * RAMP_COS)
		end
		rows[k] = row
	end
	for k = 1, #rows - 1 do
		for i = 1, SIDES do
			local j = i % SIDES + 1
			mesh:face({ rows[k][i], rows[k][j], rows[k + 1][j], rows[k + 1][i] })
		end
	end
	local back = {}
	for i = SIDES, 1, -1 do
		table.insert(back, rows[1][i])
	end
	mesh:face(back)
	mesh:face(rows[#rows])
end, nil, function(x, y, z)
	local up = (y - MEDAL_Y) * RAMP_COS + (z - MEDAL_Z) * RAMP_SIN
	local r = math.sqrt((x - MID_X) ^ 2 + up * up)
	local k = (if r > 0.42 and r < 0.82 then 0.86 else 1.1) + 0.06 * math.noise(x * 3, y * 3, z * 3)
	return math.min(BRASS[1] * k, 1), math.min(BRASS[2] * k, 1), math.min(BRASS[3] * k, 1)
end, nil, nil, true, 0.08)

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
local PUMP_X, PUMP_Y = COLUMN_X[1] - 0.65, MID_Y + 2.7
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
	box(mesh, PUMP_X, PUMP_Y, PLINTH_TOP, 1.8, 1.3, 1.5)
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

handFinish({
	Plinth = "metal",
	Anvil = "metal",
	Columns = "metal",
	Bands = "metal",
	Crown = "metal",
	Cylinder = "metal",
	Ram = "metal",
	Platen = "metal",
	Pile = "metal",
	PileJunk = "metal",
	Tray = "metal",
	Medal = "metal",
	Console = "metal",
	Cage = "metal",
	Hoses = "rock",
	Pump = "metal",
	Collars = "metal",
}, {
	Button = true,
	Beacons = true,
}, PROP_FINISH)
finishParts()
