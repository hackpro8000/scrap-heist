-- Build Bay: where a capsule sits to be whacked open with the Big Spanner, and
-- where raiders steal it from (art/concepts/build-bay-sketch.png,
-- BuildBay.plan.luau). Exactly 10 x 10 on the ground and 8.1 tall, the origin
-- at the middle of the footprint at ground level, z up, the front (toward the
-- gate) on the -y side.
-- The game seats the capsule by dropping a ray from above the bay's middle
-- (PlotService.seatOf), so nothing stands over x = 0, y = 0: the frame is on
-- the back edge and the work lamp's arm stops short of the middle. It also
-- centres the art's bounding box on the bay's cells, so nothing reaches past
-- the deck.

-- Baked at the yard kit's density (KIT_DENSITY in the ServerMap layout), as it
-- is in game.
useTexelDensity(40)

local DECK_STEEL = { 0.2, 0.21, 0.24 }
local FRAME_STEEL = { 0.28, 0.3, 0.34 }
local BOARD_GREY = { 0.46, 0.52, 0.58 }
local SEAT_STEEL = { 0.46, 0.48, 0.52 }
local PANEL_STEEL = { 0.42, 0.45, 0.5 }
local BARE = { 0.68, 0.7, 0.73 }
local TOOL_STEEL = { 0.62, 0.64, 0.68 }
-- Darker and greener than wood, so the cast parts can't be taken for timber.
local BRONZE = { 0.5, 0.4, 0.17 }
local BRASS = { 0.86, 0.68, 0.32 }
local HAZARD = { 0.86, 0.64, 0.16 }
local TAPE_BLACK = { 0.08, 0.08, 0.09 }
local CONCRETE = { 0.62, 0.6, 0.56 }
local RUBBER_BLACK = { 0.1, 0.1, 0.11 }
local WOOD = { 0.46, 0.33, 0.2 }
local OIL_BLUE = { 0.22, 0.36, 0.52 }
local AMBER = { 1.0, 0.72, 0.25 }
local CREAM = { 0.92, 0.9, 0.82 }

local DECK_TOP = 0.5
-- The capsule's seat: the drum's flat top.
local SEAT_Z, CRADLE_R = 1.7, 2.6
-- The frame on the back edge: two posts and a beam, the pegboard between.
local FRAME_Y, POST_X, POST_HALF = 3.9, 3.7, 0.45
local BEAM_HALF, BEAM_Z0, BEAM_Z1 = 4.4, 6.6, 7.5
local BOARD_Y, TOOL_Y = 3.95, 3.75
local PANEL_X, DIAL_Z = 2.25, 4.25
local LAMP_POST, LAMP_TOP = 4.55, 4.5
local CRATE_X, CRATE_Y = -3.6, 2.5
local OIL_X, OIL_Y = 3.6, 2.6
-- The work lamp's shade: the top of its axis, tipped toward the gate.
local SHADE_Y, SHADE_Z, SHADE_TILT = 1.5, 6.35, math.rad(15)
local SHADE_COS, SHADE_SIN = math.cos(SHADE_TILT), math.sin(SHADE_TILT)

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
-- Dry-brushed edge highlights, full at the corners and thinning along each edge.
local function tapered()
	parts[#parts].taper = 0.5
end
-- A shape turned round an axis through `origin`: `profile` lists { radius,
-- distance along the axis }. `u` and `v` are unit vectors across the axis,
-- with u x v along it.
local function lathe(mesh, origin, u, v, axis, profile, sides)
	local rows = {}
	for k, step in profile do
		local row = {}
		for i = 1, sides do
			local t = (i - 1) / sides * TAU
			local across, up = math.cos(t) * step[1], math.sin(t) * step[1]
			row[i] = mesh:vertex(
				origin[1] + u[1] * across + v[1] * up + axis[1] * step[2],
				origin[2] + u[2] * across + v[2] * up + axis[2] * step[2],
				origin[3] + u[3] * across + v[3] * up + axis[3] * step[2]
			)
		end
		rows[k] = row
	end
	for k = 1, #rows - 1 do
		for i = 1, sides do
			local j = i % sides + 1
			mesh:face({ rows[k][i], rows[k][j], rows[k + 1][j], rows[k + 1][i] })
		end
	end
	local first = {}
	for i = sides, 1, -1 do
		table.insert(first, rows[1][i])
	end
	mesh:face(first)
	mesh:face(rows[#rows])
end

-- ------------------------------------------------------------- the deck
part("Deck", nil, DECK_STEEL, function(mesh)
	box(mesh, 0, 0, 0, 10, 10, 0.15)
	box(mesh, 0, 0, 0.15, 9.7, 9.7, DECK_TOP - 0.15)
	for _, side in { -1, 1 } do
		rivets(mesh, -4.4, side * 4.85, 0.32, 4.4, side * 4.85, 0.32, 8, "y", 0.07)
		rivets(mesh, side * 4.85, -4.4, 0.32, side * 4.85, 4.4, 0.32, 8, "x", 0.07)
	end
end, nil, function(x, y, z)
	if z < 0.17 then
		local k = 0.92 + 0.08 * math.noise(x * 0.8, y * 0.8, 3.1)
		return CONCRETE[1] * k, CONCRETE[2] * k, CONCRETE[3] * k
	end
	local k = 0.94 + 0.1 * math.noise(x * 0.5, y * 0.5, z * 2)
	if z > DECK_TOP - 0.01 then
		-- The hazard border, and a painted ring showing where capsules go.
		if math.max(math.abs(x), math.abs(y)) > 4.25 then
			if tape(x, y) then
				return TAPE_BLACK[1], TAPE_BLACK[2], TAPE_BLACK[3]
			end
			return HAZARD[1], HAZARD[2], HAZARD[3]
		end
		local r = math.sqrt(x * x + y * y)
		if r > 3.32 and r < 3.48 then
			return HAZARD[1], HAZARD[2], HAZARD[3]
		end
		-- Chequer plate: little raised bars, turned each way in turn.
		local cellX, cellY = math.floor(x / 0.6), math.floor(y / 0.6)
		local u, v = x / 0.6 - cellX - 0.5, y / 0.6 - cellY - 0.5
		local along, across = if (cellX + cellY) % 2 == 0 then u + v else u - v, if (cellX + cellY) % 2 == 0 then u - v else u + v
		if math.abs(along) < 0.5 and math.abs(across) < 0.13 then
			k += 0.42
		end
	end
	return DECK_STEEL[1] * k, DECK_STEEL[2] * k, DECK_STEEL[3] * k
end, nil, nil, true, 0.2)
crisp()
tapered()

-- ----------------------------------------------------------- the cradle
part("Cradle", nil, PANEL_STEEL, function(mesh)
	cylinder(mesh, 0, 0, (DECK_TOP + SEAT_Z) / 2, CRADLE_R, SEAT_Z - DECK_TOP, "z", 32)
	cylinder(mesh, 0, 0, DECK_TOP + 0.13, CRADLE_R + 0.25, 0.26, "z", 32)
	ring(mesh, 0, 0, SEAT_Z + 0.04, 2.2, CRADLE_R - 0.05, 0.08, "z", 32)
	for i = 0, 11 do
		local t = (i + 0.5) / 12 * TAU
		bolt(mesh, math.cos(t) * (CRADLE_R + 0.13), math.sin(t) * (CRADLE_R + 0.13), DECK_TOP + 0.26, "z", 0.09)
	end
end, nil, function(x, y, z)
	local r = math.sqrt(x * x + y * y)
	if z > SEAT_Z + 0.01 and r > 2.15 then
		return RUBBER_BLACK[1], RUBBER_BLACK[2], RUBBER_BLACK[3]
	end
	if z > SEAT_Z - 0.01 and r < CRADLE_R - 0.02 then
		-- Worn steel with a target painted on it, showing where capsules go.
		local acrossX, acrossY = math.abs(x), math.abs(y)
		local tick = (acrossX < 0.07 and acrossY > 1.5 and acrossY < 1.92) or (acrossY < 0.07 and acrossX > 1.5 and acrossX < 1.92)
		if (r > 1.92 and r < 2.04) or tick then
			return HAZARD[1], HAZARD[2], HAZARD[3]
		end
		-- Fine lathe rings, worn bright in the middle where capsules sit.
		local k = 0.93 + 0.05 * math.sin(r * 44) + 0.12 * math.clamp((1.1 - r) / 0.5, 0, 1)
		return SEAT_STEEL[1] * k, SEAT_STEEL[2] * k, SEAT_STEEL[3] * k
	end
	if z < DECK_TOP + 0.28 then
		local k = 0.94 + 0.1 * math.noise(x * 1.5, y * 1.5, 2.2)
		return DECK_STEEL[1] * k, DECK_STEEL[2] * k, DECK_STEEL[3] * k
	end
	-- The tape round the drum, a whole number of stripes so it joins up.
	if z > 0.98 and z < 1.3 then
		if (math.atan2(y, x) / TAU * 15 + z / 1.09) % 1 < 0.5 then
			return TAPE_BLACK[1], TAPE_BLACK[2], TAPE_BLACK[3]
		end
		return HAZARD[1], HAZARD[2], HAZARD[3]
	end
	local k = 0.94 + 0.1 * math.noise(x * 0.9, y * 0.9, z * 2)
	return PANEL_STEEL[1] * k, PANEL_STEEL[2] * k, PANEL_STEEL[3] * k
end, nil, nil, true, 0.15, nil, 0.25)
crisp()
tapered()

-- A cast arm swept along `spine` in the upright plane through the bay's middle
-- at direction (c, s), or `offset` to one side of it. Each spine entry is
-- { radius, height, half thickness, half width }.
local function castArm(mesh, c: number, s: number, spine, offset: number?)
	local rows = {}
	for k, at in spine do
		local before, after = spine[math.max(k - 1, 1)], spine[math.min(k + 1, #spine)]
		local dr, dz = after[1] - before[1], after[2] - before[2]
		local length = math.sqrt(dr * dr + dz * dz)
		dr, dz = dr / length, dz / length
		local row = {}
		for i, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			local r = at[1] + corner[1] * at[3] * dz
			local z = at[2] - corner[1] * at[3] * dr
			local across = (offset or 0) + corner[2] * at[4]
			row[i] = mesh:vertex(c * r - s * across, s * r + c * across, z)
		end
		rows[k] = row
	end
	for k = 1, #rows - 1 do
		for i = 1, 4 do
			local j = i % 4 + 1
			mesh:face({ rows[k][i], rows[k][j], rows[k + 1][j], rows[k + 1][i] })
		end
	end
	mesh:face({ rows[1][4], rows[1][3], rows[1][2], rows[1][1] })
	mesh:face(rows[#rows])
end

-- One part each, so no single part reaches across the seat. Each claw's pad
-- stops at radius 2.33, clear of the widest capsule's corners.
for i, degrees in { 90, 210, 330 } do
	local c, s = math.cos(math.rad(degrees)), math.sin(math.rad(degrees))
	local function at(r: number, z: number): (number, number, number)
		return c * r, s * r, z
	end
	part(`Clamp{i}`, nil, BRONZE, function(mesh)
		local hingeX, hingeY, hingeZ = at(3.02, 1.1)
		-- The claw: heavy at the hinge, tapering, curling in to its rubber pad.
		castArm(mesh, c, s, {
			{ 3.02, 1.05, 0.27, 0.3 },
			{ 3.16, 1.6, 0.26, 0.27 },
			{ 3.12, 2.3, 0.21, 0.23 },
			{ 2.92, 2.92, 0.17, 0.2 },
			{ 2.62, 3.2, 0.15, 0.19 },
			{ 2.5, 3.18, 0.15, 0.19 },
		})
		-- The knuckle round the pin.
		local sideX, sideY = -s * 0.3, c * 0.3
		tube(mesh, { { hingeX - sideX, hingeY - sideY, hingeZ }, { hingeX + sideX, hingeY + sideY, hingeZ } }, 0.3, 16)
		-- A lug either side of the claw's heel, standing on the deck, and the
		-- hinge pin through them, so the claw hangs clear and can swing.
		for _, side in { -1, 1 } do
			castArm(mesh, c, s, { { 3.02, 0.48, 0.34, 0.06 }, { 3.02, 1.1, 0.3, 0.06 }, { 3.02, 1.42, 0.16, 0.06 } }, side * 0.37)
		end
		local acrossX, acrossY = -s * 0.5, c * 0.5
		tube(mesh, { { hingeX - acrossX, hingeY - acrossY, hingeZ }, { hingeX + acrossX, hingeY + acrossY, hingeZ } }, 0.16, 10)
	end, nil, function(px, py, pz)
		local k = 0.96 + 0.06 * math.noise(px * 0.9, py * 0.9, pz * 0.9)
		if math.abs(-s * px + c * py) > 0.31 and pz < 1.5 then
			return PANEL_STEEL[1] * k, PANEL_STEEL[2] * k, PANEL_STEEL[3] * k
		end
		return BRONZE[1] * k, BRONZE[2] * k, BRONZE[3] * k
	end, nil, nil, true, 0.1, nil, 1.5)
	tapered()
	-- The pad, a solid rubber block standing proud of the claw's tip.
	part(`Pad{i}`, nil, RUBBER_BLACK, function(mesh)
		castArm(mesh, c, s, { { 2.56, 3.18, 0.23, 0.31 }, { 2.33, 3.18, 0.23, 0.31 } })
	end, nil, 0, nil, nil, true, 0.05, nil, 0.2)
end

-- ------------------------------------------------------------ the frame
part("Frame", nil, FRAME_STEEL, function(mesh)
	for _, side in { -1, 1 } do
		local x = side * POST_X
		box(mesh, x, FRAME_Y, DECK_TOP - 0.02, 2 * POST_HALF, 2 * POST_HALF, BEAM_Z0 + 0.1 - DECK_TOP)
		for _, across in { -0.28, 0.28 } do
			rivets(mesh, x + across, FRAME_Y - POST_HALF, 1.1, x + across, FRAME_Y - POST_HALF, 5.8, 5, "y", 0.09)
			rivets(mesh, x + across, FRAME_Y + POST_HALF, 1.1, x + across, FRAME_Y + POST_HALF, 5.8, 5, "y", 0.09)
			rivets(mesh, x + side * POST_HALF, FRAME_Y + across, 1.1, x + side * POST_HALF, FRAME_Y + across, 5.8, 5, "x", 0.09)
		end
		-- The socket of the lamp on the beam's end.
		cylinder(mesh, side * 4.1, FRAME_Y, BEAM_Z1 + 0.06, 0.2, 0.14, "z", 10)
	end
	box(mesh, 0, FRAME_Y, BEAM_Z0, 2 * BEAM_HALF, 0.9, BEAM_Z1 - BEAM_Z0)
	for _, z in { BEAM_Z0 + 0.15, BEAM_Z1 - 0.15 } do
		rivets(mesh, -4.1, FRAME_Y - 0.45, z, 4.1, FRAME_Y - 0.45, z, 9, "y", 0.09)
		rivets(mesh, -4.1, FRAME_Y + 0.45, z, 4.1, FRAME_Y + 0.45, z, 9, "y", 0.09)
	end
	-- Riveted ends on the beam.
	for _, side in { -1, 1 } do
		for _, across in { -0.25, 0.25 } do
			for _, z in { BEAM_Z0 + 0.22, BEAM_Z1 - 0.22 } do
				bolt(mesh, side * BEAM_HALF, FRAME_Y + across, z, "x", 0.09)
			end
		end
	end
	-- Two braces crossing behind the board.
	for _, side in { -1, 1 } do
		strut(mesh, side * 3.25, BOARD_Y + 0.2, 0.85, -side * 3.25, BOARD_Y + 0.2, 6.35, 0.22)
		for _, z0 in { 0.55, 5.95 } do
			box(mesh, side * 2.95, BOARD_Y + 0.34, z0, 0.72, 0.06, 0.62)
			bolt(mesh, side * 2.8, BOARD_Y + 0.38, z0 + 0.31, "y", 0.08)
		end
	end
	bolt(mesh, 0, BOARD_Y + 0.33, 3.6, "y", 0.1)
end, nil, function(x, y, z)
	if z >= BEAM_Z0 then
		local k = 0.94 + 0.1 * math.noise(x * 0.6, z * 0.6, 7.7)
		return DECK_STEEL[1] * k, DECK_STEEL[2] * k, DECK_STEEL[3] * k
	end
	local k = 0.94 + 0.1 * math.noise(x * 0.6, z * 0.6, 6.4)
	return FRAME_STEEL[1] * k, FRAME_STEEL[2] * k, FRAME_STEEL[3] * k
end, nil, nil, true, 0.2)
tapered()

-- The bronze bands at each post's foot and cap, a part of their own so they go
-- on crisp while the posts stay brushed.
part("Bands", nil, BRONZE, function(mesh)
	for _, side in { -1, 1 } do
		local x = side * POST_X
		box(mesh, x, FRAME_Y, DECK_TOP - 0.02, 2 * POST_HALF + 0.22, 2 * POST_HALF + 0.22, 0.38)
		box(mesh, x, FRAME_Y, BEAM_Z0 - 0.6, 2 * POST_HALF + 0.16, 2 * POST_HALF + 0.16, 0.62)
	end
end, nil, function(x, y, z)
	local k = 0.9 + 0.12 * math.noise(x * 1.3, y * 1.3, z * 1.3)
	return BRONZE[1] * k, BRONZE[2] * k, BRONZE[3] * k
end, nil, nil, true, 0.2, nil, 1.5)
tapered()

-- Block letters for the stencil on the board, five wide and seven tall. It
-- sits low, so a seated capsule mostly hides it: it speaks for an empty bay.
local STENCIL = "HATCH"
local STENCIL_CELL, STENCIL_TOP = 0.1, 4.15
local GLYPHS = {
	H = { "1...1", "1...1", "1...1", "11111", "1...1", "1...1", "1...1" },
	A = { ".111.", "1...1", "1...1", "11111", "1...1", "1...1", "1...1" },
	T = { "11111", "..1..", "..1..", "..1..", "..1..", "..1..", "..1.." },
	C = { ".1111", "1....", "1....", "1....", "1....", "1....", ".1111" },
}
local function stencilAt(x: number, z: number): boolean
	local u = x / STENCIL_CELL + (#STENCIL * 6 - 1) / 2
	local v = (STENCIL_TOP - z) / STENCIL_CELL
	if u < 0 or v < 0 then
		return false
	end
	local letter, column, row = math.floor(u / 6) + 1, math.floor(u % 6) + 1, math.floor(v) + 1
	if letter > #STENCIL or column > 5 or row > 7 then
		return false
	end
	return GLYPHS[STENCIL:sub(letter, letter)][row]:sub(column, column) == "1"
end

-- The pegboard's holes, numbered from the board's middle. The paint and the
-- tools' pegs both come from this, so a peg always lands on a hole.
local HOLE_PITCH = 0.5
local function hole(number: number): number
	return (number + 0.5) * HOLE_PITCH
end

part("Board", nil, BOARD_GREY, function(mesh)
	box(mesh, 0, BOARD_Y, DECK_TOP - 0.02, 6.6, 0.2, BEAM_Z0 - DECK_TOP + 0.04)
	for _, x in { hole(-6), hole(5) } do
		for _, z in { hole(1), hole(12) } do
			bolt(mesh, x, BOARD_Y - 0.1, z, "y", 0.11)
		end
	end
end, nil, function(x, y, z)
	-- The stencil across the front, the pegboard's holes right through.
	if math.abs(y - BOARD_Y) > 0.09 then
		if y < BOARD_Y and stencilAt(x, z) then
			return HAZARD[1], HAZARD[2], HAZARD[3]
		end
		local u, v = x % HOLE_PITCH - HOLE_PITCH / 2, z % HOLE_PITCH - HOLE_PITCH / 2
		if u * u + v * v < 0.0036 then
			return 0.09, 0.1, 0.11
		end
	end
	local k = 0.94 + 0.1 * math.noise(x * 0.7, z * 0.7, 5.5)
	return BOARD_GREY[1] * k, BOARD_GREY[2] * k, BOARD_GREY[3] * k
end, nil, nil, true, 0.15)
crisp()
tapered()

-- A double open-ended spanner, traced from a photo of a real one. { across,
-- along } as fractions of its length, the middle at the origin, clockwise as
-- x-z outlines must be.
local SPANNER_OUTLINE = {
	{ 0.0465, 0.4882 },
	{ 0.0728, 0.4575 },
	{ 0.0871, 0.4309 },
	{ 0.0934, 0.4037 },
	{ 0.0900, 0.3752 },
	{ 0.0541, 0.3243 },
	{ 0.0443, 0.3023 },
	{ 0.0395, 0.2768 },
	{ 0.0425, -0.2710 },
	{ 0.0597, -0.2921 },
	{ 0.0842, -0.3176 },
	{ 0.0931, -0.3319 },
	{ 0.1024, -0.3599 },
	{ 0.1045, -0.3930 },
	{ 0.0954, -0.4448 },
	{ 0.0884, -0.4596 },
	{ 0.0812, -0.4649 },
	{ 0.0731, -0.4545 },
	{ 0.0565, -0.3961 },
	{ 0.0478, -0.3846 },
	{ 0.0315, -0.3783 },
	{ 0.0112, -0.3780 },
	{ -0.0087, -0.3830 },
	{ -0.0227, -0.3915 },
	{ -0.0344, -0.4028 },
	{ -0.0389, -0.4155 },
	{ -0.0249, -0.4797 },
	{ -0.0262, -0.4926 },
	{ -0.0323, -0.4972 },
	{ -0.0607, -0.4743 },
	{ -0.0743, -0.4579 },
	{ -0.0915, -0.4278 },
	{ -0.0989, -0.3955 },
	{ -0.0955, -0.3679 },
	{ -0.0507, -0.3034 },
	{ -0.0422, -0.2720 },
	{ -0.0431, 0.2744 },
	{ -0.0540, 0.2982 },
	{ -0.0926, 0.3437 },
	{ -0.0998, 0.3703 },
	{ -0.1010, 0.3938 },
	{ -0.0914, 0.4405 },
	{ -0.0855, 0.4535 },
	{ -0.0786, 0.4583 },
	{ -0.0708, 0.4516 },
	{ -0.0560, 0.3987 },
	{ -0.0478, 0.3872 },
	{ -0.0334, 0.3829 },
	{ -0.0143, 0.3837 },
	{ 0.0167, 0.3982 },
	{ 0.0298, 0.4109 },
	{ 0.0338, 0.4207 },
	{ 0.0197, 0.4852 },
	{ 0.0217, 0.4949 },
	{ 0.0286, 0.4978 },
}
-- Where the underside of the top head meets a pair of pegs half a hole apart
-- on the Big Spanner, and how far the head's flare sits off the shank's middle.
local SPANNER_REST_ALONG, SPANNER_REST_ACROSS = 0.3299, -0.0114

-- A peg out of the board with a small head, so what hangs on it stays on.
local function peg(mesh, x: number, z: number, radius: number)
	cylinder(mesh, x, TOOL_Y - 0.06, z, radius, 0.4, "y", 8)
	cylinder(mesh, x, TOOL_Y - 0.25, z, radius * 1.5, 0.05, "y", 8)
end

-- The Big Spanner hangs with its head resting on two pegs, the shank between
-- them. The small one lies across two pegs, its heads stopping it sliding off.
local BIG_LENGTH, BIG_PEG_Z, BIG_PEG_RADIUS = 3.6, hole(11), 0.07
local BIG_X = (hole(-6) + hole(-5)) / 2 - SPANNER_REST_ACROSS * BIG_LENGTH
local BIG_Z = BIG_PEG_Z + BIG_PEG_RADIUS + 0.03 - SPANNER_REST_ALONG * BIG_LENGTH
local SMALL_LENGTH, SMALL_PEG_Z, SMALL_PEG_RADIUS = 1.2, hole(11), 0.05
local SMALL_X = (hole(4) + hole(5)) / 2
local SMALL_Z = SMALL_PEG_Z + SMALL_PEG_RADIUS + 0.05
local function onBigSpanner(across: number, along: number): (number, number)
	return BIG_X + across * BIG_LENGTH, BIG_Z + along * BIG_LENGTH
end
-- Turned a quarter round, which keeps the outline clockwise.
local function onSmallSpanner(across: number, along: number): (number, number)
	return SMALL_X + along * SMALL_LENGTH, SMALL_Z - across * SMALL_LENGTH
end
local function spanner(mesh, place, depth: number, bevel: number)
	local outline = {}
	for i, point in SPANNER_OUTLINE do
		local x, z = place(point[1], point[2])
		outline[i] = { x, z }
	end
	plate(mesh, outline, TOOL_Y, depth, bevel)
end
-- The shank's recessed middle, narrowing out at each end as on the real thing.
local function inShankRecess(across: number, along: number): boolean
	return math.abs(across) < 0.024 * math.clamp((0.29 - math.abs(along)) / 0.03, 0, 1)
end

local HAMMER_LEFT_PEG, HAMMER_RIGHT_PEG, HAMMER_PEG_Z = hole(1), hole(2), hole(11)
local HAMMER_X, HEAD_BASE = (HAMMER_LEFT_PEG + HAMMER_RIGHT_PEG) / 2, HAMMER_PEG_Z + 0.07
part("Tools", nil, TOOL_STEEL, function(mesh)
	-- The Big Spanner left of the capsule, a small one above the panel.
	spanner(mesh, onBigSpanner, 0.1, 0.012)
	peg(mesh, hole(-6), BIG_PEG_Z, BIG_PEG_RADIUS)
	peg(mesh, hole(-5), BIG_PEG_Z, BIG_PEG_RADIUS)
	spanner(mesh, onSmallSpanner, 0.06, 0.004)
	peg(mesh, hole(4), SMALL_PEG_Z, SMALL_PEG_RADIUS)
	peg(mesh, hole(5), SMALL_PEG_Z, SMALL_PEG_RADIUS)
	-- A hammer hanging head up: its head rests on two pegs, the handle between.
	box(mesh, HAMMER_X, TOOL_Y, HEAD_BASE - 1.38, 0.16, 0.1, 1.42)
	box(mesh, HAMMER_X, TOOL_Y, HEAD_BASE, 0.76, 0.16, 0.34)
	peg(mesh, HAMMER_LEFT_PEG, HAMMER_PEG_Z, 0.07)
	peg(mesh, HAMMER_RIGHT_PEG, HAMMER_PEG_Z, 0.07)
end, nil, function(x, y, z)
	if math.abs(x - HAMMER_X) < 0.1 and z < HEAD_BASE then
		return WOOD[1], WOOD[2], WOOD[3]
	elseif math.abs(x - HAMMER_X) < 0.4 and z >= HEAD_BASE then
		return DECK_STEEL[1], DECK_STEEL[2], DECK_STEEL[3]
	end
	-- Forged steel, darker in the shank's recess on the front face.
	local across, along = (x - BIG_X) / BIG_LENGTH, (z - BIG_Z) / BIG_LENGTH
	if x > 0 then
		across, along = (SMALL_Z - z) / SMALL_LENGTH, (x - SMALL_X) / SMALL_LENGTH
	end
	local k = if y < TOOL_Y - 0.025 and inShankRecess(across, along) then 0.74 else 1
	return TOOL_STEEL[1] * k, TOOL_STEEL[2] * k, TOOL_STEEL[3] * k
end, nil, nil, true, 0.06)
tapered()

part("Panel", nil, PANEL_STEEL, function(mesh)
	box(mesh, PANEL_X, TOOL_Y, 2.5, 1.3, 0.26, 2.4)
	for _, x in { hole(3), hole(5) } do
		for _, z in { hole(5), hole(9) } do
			bolt(mesh, x, TOOL_Y - 0.13, z, "y", 0.07)
		end
	end
	-- The dial, its bezel, and a lever in a slotted plate.
	cylinder(mesh, PANEL_X, 3.6, DIAL_Z, 0.46, 0.06, "y", 24)
	ring(mesh, PANEL_X, 3.58, DIAL_Z, 0.44, 0.54, 0.12, "y", 24)
	box(mesh, PANEL_X + 0.32, 3.58, 2.72, 0.24, 0.1, 0.56)
	strut(mesh, PANEL_X + 0.32, 3.6, 2.9, PANEL_X + 0.32, 3.3, 3.42, 0.08)
	sphere(mesh, PANEL_X + 0.32, 3.3, 3.42, 0.18, 0.18, 0.18, 5, 10)
	-- The cable down the board and across the deck to the drum.
	tube(mesh, roundedPath({ { PANEL_X - 0.3, 3.7, 2.55 }, { PANEL_X - 0.3, 3.62, 0.62 }, { 2.6, 2.75, 0.6 }, { 2.75, 2.25, 0.8 }, { 1.98, 1.62, 0.95 } }, 0.3), 0.1, 10)
	-- The gland where it enters the drum.
	tube(mesh, { { 1.98, 1.62, 0.95 }, { 2.25, 1.84, 0.95 } }, 0.16, 12)
end, nil, function(x, y, z)
	if z < 2.45 then
		if (x - 2.11) ^ 2 + (y - 1.73) ^ 2 < 0.05 then
			return PANEL_STEEL[1], PANEL_STEEL[2], PANEL_STEEL[3]
		end
		return RUBBER_BLACK[1], RUBBER_BLACK[2], RUBBER_BLACK[3]
	end
	-- The lever: a red knob on a dark stem, so it doesn't read as a button.
	if (x - PANEL_X - 0.32) ^ 2 + (y - 3.3) ^ 2 + (z - 3.42) ^ 2 < 0.05 then
		return 0.72, 0.14, 0.1
	end
	if y < 3.52 and math.abs(x - PANEL_X - 0.32) < 0.1 and z > 2.8 and z < 3.42 then
		return RUBBER_BLACK[1], RUBBER_BLACK[2], RUBBER_BLACK[3]
	end
	local dx, dz = x - PANEL_X, z - DIAL_Z
	if y < 3.6 and dx * dx + dz * dz < 0.19 then
		local along, across = dx * 0.6 + dz * 0.8, math.abs(dx * 0.8 - dz * 0.6)
		if across < 0.03 and along > -0.05 and along < 0.36 then
			return 0.7, 0.14, 0.1
		end
		return CREAM[1], CREAM[2], CREAM[3]
	end
	local k = 0.94 + 0.1 * math.noise(x * 1.2, z * 1.2, 2.6)
	return PANEL_STEEL[1] * k, PANEL_STEEL[2] * k, PANEL_STEEL[3] * k
end, nil, nil, true, 0.12)
crisp()
tapered()

-- ---------------------------------------------------------- the lighting
part("Arm", nil, FRAME_STEEL, function(mesh)
	local ELBOW_Y, ELBOW_Z = 2.35, 7.2
	box(mesh, 0, FRAME_Y - 0.55, BEAM_Z0 + 0.15, 0.6, 0.24, 0.6)
	strut(mesh, 0, FRAME_Y - 0.6, BEAM_Z0 + 0.45, 0, ELBOW_Y, ELBOW_Z, 0.2)
	strut(mesh, 0, ELBOW_Y, ELBOW_Z, 0, SHADE_Y, SHADE_Z + 0.1, 0.16)
	cylinder(mesh, 0, ELBOW_Y, ELBOW_Z, 0.2, 0.34, "x", 12)
	-- The shade, open underneath: outside, rim, then inside.
	lathe(mesh, { 0, SHADE_Y, SHADE_Z }, { 1, 0, 0 }, { 0, -SHADE_COS, SHADE_SIN }, { 0, -SHADE_SIN, -SHADE_COS }, { { 0.28, 0 }, { 0.55, 0.7 }, { 0.5, 0.7 }, { 0.24, 0.1 } }, 20)
end, nil, function(x, y, z)
	-- How far along the shade's axis this is, and how far from it.
	local dy, dz = y - SHADE_Y, z - SHADE_Z
	local along = -dy * SHADE_SIN - dz * SHADE_COS
	if along > -0.02 and along < 0.72 then
		local across = dy * -SHADE_COS + dz * SHADE_SIN
		local r = math.sqrt(x * x + across * across)
		if r < 0.28 + 0.27 * along / 0.7 - 0.03 then
			return CREAM[1], CREAM[2], CREAM[3]
		end
		return HAZARD[1], HAZARD[2], HAZARD[3]
	end
	local k = 0.94 + 0.1 * math.noise(y * 1.5, z * 1.5, 3.3)
	return FRAME_STEEL[1] * k, FRAME_STEEL[2] * k, FRAME_STEEL[3] * k
end, nil, nil, true, 0.1)
tapered()

part("Posts", nil, PANEL_STEEL, function(mesh)
	for _, side in { -1, 1 } do
		local x, y = side * LAMP_POST, -LAMP_POST
		box(mesh, x, y, DECK_TOP - 0.02, 0.5, 0.5, 0.14)
		cylinder(mesh, x, y, (DECK_TOP + LAMP_TOP) / 2, 0.14, LAMP_TOP - DECK_TOP, "z", 10)
		-- The bracket arm reaching in over the deck.
		tube(mesh, { { x, y, LAMP_TOP - 0.2 }, { x - side * 0.42, y + 0.42, LAMP_TOP + 0.02 } }, 0.07, 6)
	end
end, nil, 0.3, nil, nil, true, 0.1)
tapered()

-- The glowing lamps, as two parts so that neither reaches across the seat:
-- the pair at the front, and the rest, all behind the middle.
part("PostLamps", nil, AMBER, function(mesh)
	for _, side in { -1, 1 } do
		sphere(mesh, side * (LAMP_POST - 0.45), -LAMP_POST + 0.45, LAMP_TOP + 0.05, 0.26, 0.26, 0.26, 6, 10)
	end
end, true, 0, nil, 1.4)

part("BackLamps", nil, AMBER, function(mesh)
	for _, side in { -1, 1 } do
		sphere(mesh, side * 4.1, FRAME_Y, BEAM_Z1 + 0.3, 0.3, 0.3, 0.3, 6, 10)
	end
	-- The work lamp's bulb, inside its shade.
	sphere(mesh, 0, SHADE_Y - 0.42 * SHADE_SIN, SHADE_Z - 0.42 * SHADE_COS, 0.2, 0.2, 0.2, 6, 10)
	-- The green indicators along the beam, and the red ARMED lamp.
	for i = -5, 5 do
		sphere(mesh, i * 0.45, FRAME_Y - 0.46, (BEAM_Z0 + BEAM_Z1) / 2, 0.14, 0.07, 0.14, 4, 8)
	end
	sphere(mesh, PANEL_X - 0.2, 3.6, 3.3, 0.2, 0.12, 0.2, 5, 10)
end, true, function(x, y, z)
	if z > BEAM_Z0 and z < BEAM_Z1 - 0.1 and y < FRAME_Y - 0.3 then
		return 0.35, 1, 0.4
	elseif x > 1.8 and z < 4 and y > 3 then
		return 1, 0.2, 0.15
	end
	return AMBER[1], AMBER[2], AMBER[3]
end, nil, 1.4)

-- ------------------------------------------------------------- the clutter
-- `mesh` turned about a point, so any shape can be drawn tipped: pitch about x
-- and roll about y first, then yaw about z, in degrees.
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

-- The crate's heap: a rusty mound with pieces bedded into it. They may sink into
-- the mound but never into each other. Offsets from the crate's middle, with
-- heights above the ground.
local MOUND_X, MOUND_Y, MOUND_Z = 0.66, 0.5, 0.36
local CRATE_RUST = { 0.42, 0.26, 0.16 }
local CRATE_GEAR = { -0.3, 0.18, 1.913 }
local CRATE_COG = { 0.33, -0.2, 1.817 }
local CRATE_WASHER = { -0.4, -0.3, 1.718 }
-- Each bolt: its offset, then yaw, pitch and roll.
local CRATE_BOLTS = { { -0.04, -0.4, 1.715, 30, 18, -22 }, { 0.15, -0.44, 1.65, 70, -30, 14 } }
-- Bent where it crosses the rim, its upper end kicked up and aside.
local CRATE_PIPE = { { 0.26, 0.26, 1.76 }, { 0.69, 0.3, 1.86 } }
local CRATE_PIPE_END = { { 0.69, 0.3, 1.86 }, { 0.84, 0.22, 2.05 } }
-- A cog with a third of it snapped off, clockwise in { across, up } as x-z
-- outlines must be: teeth from the top round the right, then the broken edge.
local function brokenCogOutline(cx: number, cz: number)
	local outline = {}
	local function add(degrees: number, radius: number)
		local t = math.rad(degrees)
		table.insert(outline, { cx + math.cos(t) * radius, cz + math.sin(t) * radius })
	end
	for tooth = 0, 5 do
		local start = 90 - tooth * 45
		add(start + 10, 0.22)
		add(start - 10, 0.22)
		add(start - 13, 0.18)
		add(start - 32, 0.18)
	end
	add(-205, 0.11)
	add(-228, 0.05)
	add(-250, 0.13)
	return outline
end
local function inCrate(offset)
	return CRATE_X + offset[1], CRATE_Y + offset[2], offset[3]
end
local function pathInCrate(segment)
	local a, b = { inCrate(segment[1]) }, { inCrate(segment[2]) }
	return { a, b }
end

part("Crate", nil, WOOD, function(mesh)
	box(mesh, CRATE_X, CRATE_Y, DECK_TOP - 0.02, 1.5, 1.2, 1.02)
	for _, side in { -1, 1 } do
		box(mesh, CRATE_X, CRATE_Y + side * 0.62, DECK_TOP - 0.02, 1.7, 0.16, 1.22)
		box(mesh, CRATE_X + side * 0.77, CRATE_Y, DECK_TOP - 0.02, 0.16, 1.1, 1.2)
	end
end, nil, function(x, y, z)
	local k = 0.9 + 0.14 * math.noise(x * 1.5, y * 1.5, z * 3)
	-- The floor inside, in shadow.
	if z > 1.46 and math.abs(x - CRATE_X) < 0.69 and math.abs(y - CRATE_Y) < 0.54 then
		return 0.3 * k, 0.2 * k, 0.13 * k
	end
	-- Planks, with dark gaps between them.
	if (z - DECK_TOP) % 0.4 < 0.03 then
		k *= 0.45
	end
	return WOOD[1] * k, WOOD[2] * k, WOOD[3] * k
end, nil, nil, true, 0.12)

-- The heap and its pieces are separate parts so one's brush strokes can't land
-- on another.
part("CrateHeap", nil, CRATE_RUST, function(mesh)
	sphere(mesh, CRATE_X, CRATE_Y, 1.5, MOUND_X, MOUND_Y, MOUND_Z, 6, 14)
end, nil, 0.5, nil, nil, nil, 0.1)

part("CrateGear", nil, BRONZE, function(mesh)
	local x, y, z = inCrate(CRATE_GEAR)
	gear(tippedAbout(mesh, x, y, z, 15, -30, 12), x, y, z, 0.36, 0.14, 9, "y")
end, nil, 0.25, nil, nil, true, 0.06)
tapered()

part("CrateScrap", nil, BARE, function(mesh)
	local x, y, z = inCrate(CRATE_COG)
	plate(tippedAbout(mesh, x, y, z, -50, -60, 20), brokenCogOutline(x, z), y, 0.1, 0.008)
	x, y, z = inCrate(CRATE_WASHER)
	ring(tippedAbout(mesh, x, y, z, 40, 28, -35), x, y, z, 0.1, 0.2, 0.08, "z", 10)
	local bent = pathInCrate(CRATE_PIPE)
	table.insert(bent, { inCrate(CRATE_PIPE_END[2]) })
	tube(mesh, roundedPath(bent, 0.1), 0.1, 8)
	for _, loose in CRATE_BOLTS do
		x, y, z = inCrate(loose)
		bolt(tippedAbout(mesh, x, y, z, loose[4], loose[5], loose[6]), x, y, z, "z", 0.09)
	end
end, nil, 0.25, nil, nil, true, 0.06)
tapered()

part("Drum", nil, OIL_BLUE, function(mesh)
	cylinder(mesh, OIL_X, OIL_Y, DECK_TOP + 0.8, 0.62, 1.6, "z", 20)
	for _, z in { DECK_TOP + 0.5, DECK_TOP + 1.1, DECK_TOP + 1.58 } do
		ring(mesh, OIL_X, OIL_Y, z, 0.6, 0.67, 0.08, "z", 20)
	end
	-- The funnel in its filler hole.
	lathe(mesh, { OIL_X + 0.2, OIL_Y, 2.06 }, { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 }, { { 0.07, 0 }, { 0.07, 0.2 }, { 0.26, 0.42 }, { 0.22, 0.42 }, { 0.05, 0.22 } }, 12)
end, nil, 0.45, nil, nil, nil, 0.12)
tapered()

-- The hand-painted finish. On a crisp part with a hand coat, such as the hazard
-- strips, the shapes stay exact and only the brushwork's tone is laid on top.
local HAND_COAT = {
	Deck = "metal",
	Cradle = "metal",
	Frame = "metal",
	Bands = "metal",
	Tools = "metal",
	Arm = "metal",
	Posts = "metal",
	Crate = "wood",
	CrateHeap = "rock",
	CrateGear = "metal",
	CrateScrap = "metal",
}
-- These parts are small and detailed, so their marks are too.
local SMALL_PART_STROKES = {
	big_length_min = 0.4,
	big_length_max = 0.75,
	big_width_min = 0.14,
	big_width_max = 0.28,
	mid_length_min = 0.2,
	mid_length_max = 0.4,
	mid_width_min = 0.07,
	mid_width_max = 0.13,
	edge_opacity = 0,
}
local NO_EDGE_WORK = { PostLamps = true, BackLamps = true }

for _, entry in parts do
	if NO_EDGE_WORK[entry.name] then
		continue
	end
	entry.hand = HAND_COAT[entry.name]
	if entry.hand == nil then
		entry.litMotion = "worn"
	elseif entry.hand == "metal" then
		entry.handTune = SMALL_PART_STROKES
	end
	entry.softLit, entry.softEdge, entry.softUneven, entry.softTaper = 0.25, 0.22, 0, 0.8
	entry.softToZero, entry.softPower = true, 2
	entry.taper = entry.taper or 0.5
	entry.litToZero, entry.litUneven, entry.litUnevenStep = true, 0.6, 0.5
	entry.brushes = { shade = { motion = "feather", tune = { width = 0.02 } } }
end

finishParts()
