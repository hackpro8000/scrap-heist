-- Junk Mound: a low, slumped heap of mixed scrap players can walk over, with
-- torn sheets and bent bars sticking out of it all round and the odd
-- recognisable bit on top. Centered on the origin.
-- mates: Plates Heap, Bits Heap
-- include: HandFinish
local MOUND_REACH, MOUND_DEPTH, MOUND_HEIGHT = 3.9, 0.76, 2.3
-- Builds into a mesh laid along two directions from a point: local x runs along
-- (ux, uy, uz) and local z along (wx, wy, wz), so a plate's x-z outline lies there.
local function laidOn(mesh, ox: number, oy: number, oz: number, ux: number, uy: number, uz: number, wx: number, wy: number, wz: number)
	local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / ul, uy / ul, uz / ul
	local along = wx * ux + wy * uy + wz * uz
	wx, wy, wz = wx - ux * along, wy - uy * along, wz - uz * along
	local wl = math.sqrt(wx * wx + wy * wy + wz * wz)
	wx, wy, wz = wx / wl, wy / wl, wz / wl
	local vx, vy, vz = wy * uz - wz * uy, wz * ux - wx * uz, wx * uy - wy * ux
	return {
		vertex = function(_self, x: number, y: number, z: number)
			return mesh:vertex(ox + ux * x + vx * y + wx * z, oy + uy * x + vy * y + wy * z, oz + uz * x + vz * y + wz * z)
		end,
		face = function(_self, face)
			return mesh:face(face)
		end,
	}
end
-- Builds into a mesh whose z axis points along (nx, ny, nz) from (cx, cy, cz),
-- so round pieces made about "z" at the origin face that way.
-- Every piece set on the heap, { x, y, z, radius }, so each gets its own paint bands.
local PIECES = {}
local function facing(mesh, cx: number, cy: number, cz: number, nx: number, ny: number, nz: number, crush: number?)
	table.insert(PIECES, { cx, cy, cz, 0.7 })
	local tx, ty, tz, ux, uy, uz, vx, vy, vz = crossFrame(nx, ny, nz)
	local squash = crush or 1
	return {
		vertex = function(_self, x: number, y: number, z: number)
			local across = y * squash
			return mesh:vertex(cx + ux * x + vx * across + tx * z, cy + uy * x + vy * across + ty * z, cz + uz * x + vz * across + tz * z)
		end,
		face = function(_self, face)
			return mesh:face(face)
		end,
	}
end

-- A mound's outline radius on a bearing: a lopsided circle.
local function moundReach(angle: number): number
	return MOUND_REACH * (1 + 0.14 * math.sin(angle * 2 + 0.7) + 0.09 * math.sin(angle * 3 + 2.1) + 0.05 * math.sin(angle * 5))
end

-- How high the mound's top is above a spot: spreading out to nothing at its
-- edge, with slumps across it.
local function moundTop(x: number, y: number): number
	local stretched = y / MOUND_DEPTH
	local reach = moundReach(math.atan2(stretched, x))
	local along = math.sqrt(x * x + stretched * stretched) / reach
	if along >= 1 then
		return 0
	end
	local slump = (0.72 + 0.34 * math.noise(x * 0.75 + 3.1, y * 0.75 - 1.7, 0.4)) * math.min(1, (1 - along) * 5 + 0.5)
	return MOUND_HEIGHT * (1 - along * along) ^ 1.5 * slump
end

local function moundSurface(mesh)
	local rings, sides = 10, 36
	local rows = {}
	for r = 1, rings do
		rows[r] = {}
		for s = 1, sides do
			local a = s / sides * math.pi * 2
			local d = moundReach(a) * r / rings
			local x, y = math.cos(a) * d, math.sin(a) * d * MOUND_DEPTH
			rows[r][s] = mesh:vertex(x, y, if r == rings then -0.05 else moundTop(x, y))
		end
	end
	local peak = mesh:vertex(0, 0, moundTop(0, 0))
	local floor = {}
	for s = 1, sides do
		local n = s % sides + 1
		mesh:face({ peak, rows[1][s], rows[1][n] })
		for r = 1, rings - 1 do
			mesh:face({ rows[r][s], rows[r + 1][s], rows[r + 1][n], rows[r][n] })
		end
		floor[sides - s + 1] = rows[rings][s]
	end
	mesh:face(floor)
end

local TORN_A = {
	{ -0.9, 0.35 }, { -0.45, 0.75 }, { -0.1, 0.5 }, { 0.35, 0.9 }, { 0.85, 0.55 }, { 0.75, 0 },
	{ 1, -0.45 }, { 0.4, -0.8 }, { 0.05, -0.55 }, { -0.5, -0.85 }, { -0.95, -0.3 },
}
local TORN_B = {
	{ -0.7, 0.6 }, { 0.1, 0.85 }, { 0.3, 0.55 }, { 0.8, 0.7 }, { 0.6, 0.1 }, { 0.9, -0.6 },
	{ 0.2, -0.4 }, { -0.3, -0.8 }, { -0.85, -0.35 }, { -0.6, 0 },
}
-- A long strip torn off something, for variety against the wide sheets.
local TORN_STRIP = {
	{ -0.25, 1 }, { 0.2, 1.1 }, { 0.3, 0.3 }, { 0.2, -0.3 }, { 0.32, -1 }, { -0.15, -1.1 }, { -0.3, -0.2 },
}
-- Each sheet: where it comes out, how far its middle stands off the heap, its
-- size and outline, then the two directions it lies along.
local SHEETS = {
	{ 2.7, 0.75, 0.3, 1.1, TORN_A, -0.3, 1, 0.1, 0.75, 0.2, 0.6 },
	{ -2.9, -0.6, 0.42, 0.7, TORN_B, 0.2, 1, -0.1, -0.8, 0.1, 0.55 },
	{ 3.0, -0.75, 0.3, 0.9, TORN_STRIP, 0.3, 1, 0.1, 0.85, -0.25, 0.5 },
	{ 1.5, -1.6, 0.3, 0.8, TORN_B, 1, 0.3, -0.1, 0.2, -0.75, 0.55 },
	{ -1.6, -1.25, 0.34, 0.9, TORN_STRIP, 0.8, -0.5, 0.15, -0.3, -0.5, 0.85 },
	{ 0.2, -2.3, 0.26, 0.85, TORN_A, 1, -0.1, 0.1, 0, -0.6, 0.75 },
	{ 2.05, -0.2, 0.2, 0.6, TORN_STRIP, 0.3, 1, 0.2, 0.9, -0.1, 0.45 },
	{ 2.2, -2.05, 0.2, 0.55, TORN_A, 0.7, 0.6, -0.1, 0.5, -0.7, 0.5 },
	-- One bedded nearly flat on top, half under the big piece.
	{ -1.9, 0.95, 0.14, 0.95, TORN_B, 1, -0.2, 0.2, 0.3, 1, 0.25 },
}
-- Blocks of crushed stuff bedded in the heap, breaking its surface: where, size,
-- then the way each one's top faces.
local CRUSHED = {
	{ -2.2, 0.75, 1.1, 0.8, 0.5, -0.4, 0.3, 0.9 },
	{ 1.0, -1.1, 0.9, 0.7, 0.42, 0.3, -0.5, 0.8 },
	{ 2.6, 0.0, 0.7, 0.9, 0.36, 0.6, 0.1, 0.8 },
	{ -0.3, -1.3, 0.75, 0.55, 0.4, -0.1, -0.55, 0.85 },
	{ 0.4, 1.35, 0.95, 0.6, 0.44, 0.2, 0.6, 0.8 },
	{ -2.9, 0.1, 0.6, 0.7, 0.32, -0.7, 0, 0.7 },
	{ 1.9, 1.3, 0.55, 0.5, 0.3, 0.45, 0.5, 0.75 },
	{ -1.3, -0.5, 0.8, 0.6, 0.4, -0.2, -0.2, 0.95 },
}

part("Heap", nil, { 0.55, 0.4, 0.27 }, function(mesh)
	moundSurface(mesh)
	for _, c in CRUSHED do
		box(facing(mesh, c[1], c[2], moundTop(c[1], c[2]) - 0.2, c[6], c[7], c[8]), 0, 0, 0, c[3], c[4], c[5])
	end
end, nil, 0.9)

part("Plates", nil, { 0.48, 0.28, 0.13 }, function(mesh)
	for _, s in SHEETS do
		local size, outline = s[4], s[5]
		local scaled = {}
		for i, p in outline do
			scaled[i] = { p[1] * size, p[2] * size }
		end
		plate(laidOn(mesh, s[1], s[2], moundTop(s[1], s[2]) + s[3] + 0.16, s[6], s[7], s[8], s[9], s[10], s[11]), scaled, 0, 0.08, 0.01)
	end
end, nil, 0.8)

part("Bits", nil, { 0.44, 0.45, 0.47 }, function(mesh)
	-- Bars bent where they stick out of the heap, all the way round.
	for _, bar in {
		{ { 2.2, -0.9, 0.42 }, { 3.0, -1.35, 0.8 }, { 3.35, -1.2, 1.35 } },
		{ { -1.9, 1.05, 0.95 }, { -2.7, 1.45, 1.05 }, { -2.5, 2.05, 0.85 } },
		{ { 0.9, 1.1, 1.05 }, { 1.2, 1.6, 1.5 }, { 1.8, 1.55, 1.75 } },
		{ { -0.8, -1.55, 0.75 }, { -1.2, -2.5, 0.75 }, { -0.8, -2.85, 1.15 } },
		{ { 0.7, -1.4, 0.8 }, { 1.2, -2.4, 0.5 }, { 2.3, -2.75, 0.85 } },
	} do
		tube(mesh, roundedPath(bar, 0.14), 0.11, 6)
	end
	-- The one big thing on it: a crushed tank lying across the top, with a
	-- crumpled cabinet jammed against its end.
	cylinder(facing(mesh, 0.4, 0.55, moundTop(0.4, 0.55) + 0.55, 0.85, 0.42, 0.28, 0.72), 0, 0, 0, 0.95, 3, "z", 14)
	-- The big pieces band over their own full height.
	PIECES[#PIECES][4] = 1.3
	box(facing(mesh, -2.15, -1.05, moundTop(-2.15, -1.05) + 0.05, -0.35, -0.2, 0.9, 0.8), 0, 0, 0, 1.5, 1.2, 1.5)
	PIECES[#PIECES][4] = 1.0
	-- Beams thrown on at odd angles, resting across the heap and each other.
	strut(mesh, -2.4, 0.5, 0.35, -0.3, 1.25, 1.55, 0.22)
	strut(mesh, -0.9, 1.5, 1.05, 0.9, 0.3, 1.2, 0.2)
	strut(mesh, 2.1, 1.1, 0.85, 3.2, 1.75, 0.15, 0.18)
	-- A beam and a bent bar leaning right out over the heap's edge.
	strut(mesh, -3.2, -1.4, 0.04, -1.1, -0.35, 1.45, 0.26)
	strut(mesh, 2.0, -2.2, 0.75, 3.6, -2.7, 1.35, 0.14)
	-- Big loose pieces lying out on the sand: a plate, a drum on its side.
	cylinder(facing(mesh, -1.0, 2.75, 0.42, 1, -0.35, 0.05), 0, 0, 0, 0.42, 1.4, "z", 12)
	-- Spilled onto the ground all round: a crushed drum, brake discs, a dropped bar.
	cylinder(facing(mesh, -2.9, -1.95, 0.32, 0.8, -0.5, 0.15), 0, 0, 0, 0.34, 1, "z", 10)
	strut(mesh, -1.2, -2.9, 0.04, 0.3, -3.2, 0.03, 0.09)
	-- A drum half sunk at an angle, and a gear thrown on beside the top sheets.
	cylinder(facing(mesh, -1.65, 0.35, moundTop(-1.65, 0.35) + 0.2, 1, 0.3, 0.3), 0, 0, 0, 0.3, 1.25, "z", 10)
	gear(facing(mesh, 0.75, -0.45, moundTop(0.75, -0.45) + 0.22, 0.3, -0.4, 0.85), 0, 0, 0, 0.55, 0.14, 9, "z")
end, nil, 0.6)

-- What spilled past the heap onto the ground: flat, so it banks no bands and
-- goes darker and rustier to read as old steel.
part("Spill", nil, { 0.27, 0.28, 0.3 }, function(mesh)
	plate(laidOn(mesh, 3.7, -1.6, 0.08, 1, 0.3, 0.02, -0.3, 1, 0.04), { { -0.8, 0.5 }, { 0.2, 0.7 }, { 0.9, 0.3 }, { 0.7, -0.4 }, { -0.1, -0.7 }, { -0.9, -0.2 } }, 0, 0.1, 0.012)
	ring(mesh, 3.5, 1.9, 0.06, 0.2, 0.55, 0.1, "z", 14)
	ring(mesh, -3.4, 1.7, 0.05, 0.18, 0.46, 0.1, "z", 14)
	ring(mesh, 2.7, -2.6, 0.05, 0.16, 0.4, 0.1, "z", 14)
end, nil, 0.9)

part("Tyre", nil, RUBBER_BLACK, function(mesh)
	-- Sunk a third of its width into the front slope.
	local x, y = 0.9, -1.75
	ring(facing(mesh, x, y, moundTop(x, y) + 0.2, 0.1, -0.75, 0.65), 0, 0, 0, 0.26, 0.62, 0.26, "z", 14)
	-- One more lying flat on top, and a third thrown clear on the sand.
	ring(mesh, 0.7, 0.7, moundTop(0.7, 0.7) + 0.08, 0.26, 0.56, 0.26, "z", 14)
	ring(mesh, -3.7, -0.9, 0.13, 0.26, 0.56, 0.26, "z", 14)
	-- A big one leaning out over the near edge, its foot on the sand.
	ring(facing(mesh, 3.1, 0.45, 0.72, 0.85, 0.1, 0.5), 0, 0, 0, 0.36, 0.86, 0.32, "z", 16)
end, nil, RUBBER)

for _, entry in parts do
	if entry.name == "Heap" then
		-- Joins with the pieces darken over a wider band.
		entry.rust, entry.edge, entry.lit = 0.15, 0.5, 0
	else
		entry.bandPieces = PIECES
	end
	-- Small loose steel has no seams to speak of, so it rusts in patches all over.
	if entry.name == "Bits" or entry.name == "Spill" then
		entry.rust, entry.rustEdges = 0.45, false
	end
end
handFinish({
	Heap = "rock",
	Plates = "metal",
	Bits = "metal",
	Tyre = "rock",
}, {}, { Heap = "heapBody", metal = "heapPiece", rock = "heapPiece" })
finishParts()
