-- Rock Boulder Pile: brake drums dumped on a low rusty mound and left where
-- they rolled, heaped like loose boulders. Centered on the origin.
-- include: HandFinish
-- mates: Drums Mound, Discs Mound, Hubs Mound
local MOUND_REACH, MOUND_DEPTH, MOUND_HEIGHT = 3.0, 0.85, 1.3
-- Builds into a mesh whose z axis points along (nx, ny, nz) from (cx, cy, cz),
-- so round pieces made about "z" at the origin face that way. A `crush` under 1
-- flattens it across y, dented in from one side.
-- Every drum and disc set on the mound, { x, y, z, radius }, so each gets its own paint bands.
local PIECES = {}
local function facing(mesh, cx: number, cy: number, cz: number, nx: number, ny: number, nz: number, crush: number?)
	table.insert(PIECES, { cx, cy, cz, 0.55 })
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

-- Each drum: where it sits, its radius and length, the way its axis points and
-- how crushed it is. Most have rolled onto their sides; a few nestle in the mound.
local DRUMS = {
	{ 0.0, 0.05, 1.3, 0.86, 0.95, 0.25, 0.15, 0.95, 1 },
	{ 1.45, 0.4, 0.55, 0.46, 0.85, 0.95, 0.3, 0.15, 0.62 },
	{ -1.35, 0.55, 0.62, 0.66, 0.6, -0.8, 0.4, 0.4, 1 },
	{ 0.25, -1.3, 0.48, 0.38, 0.7, 0.2, -0.95, 0.2, 1 },
	-- Rolled down against the big drum, held by it and the slope.
	{ 1.02, 0.82, 0.95, 0.42, 0.5, 0.45, 0.8, 0.4, 0.7 },
	{ -0.95, -0.72, 0.82, 0.5, 0.82, -0.25, 1, 0.2, 1 },
	{ 1.3, -0.75, 0.42, 0.3, 0.42, 0.3, -0.2, 0.9, 1 },
}

-- The earth and rust-dust the drums lie in.
part("Mound", nil, { 0.42, 0.33, 0.25 }, function(mesh)
	moundSurface(mesh)
end, nil, 0.5)

part("Drums", nil, { 0.34, 0.31, 0.3 }, function(mesh)
	for _, d in DRUMS do
		cylinder(facing(mesh, d[1], d[2], d[3], d[6], d[7], d[8], d[9]), 0, 0, 0, d[4], d[5], "z", 14)
	end
end, nil, 0.85)

part("Discs", nil, RUST_ORANGE, function(mesh)
	-- Leaning on the crushed drum at the pile's east side, its lower rim in the mound.
	ring(facing(mesh, 2.0, 0.05, 0.56, 0.62, 0.05, 0.78), 0, 0, 0, 0.18, 0.58, 0.1, "z", 16)
	-- Snapped across, its broken half lying flat on the west slope.
	local half = {}
	for step = 0, 8 do
		local t = math.rad(180 - step * 22.5)
		table.insert(half, { math.cos(t) * 0.5, math.sin(t) * 0.5 })
	end
	table.insert(half, { 0.32, -0.08 })
	table.insert(half, { 0.16, 0.05 })
	for step = 1, 7 do
		local t = math.rad(step * 22.5)
		table.insert(half, { math.cos(t) * 0.16, math.sin(t) * 0.16 })
	end
	table.insert(half, { -0.24, -0.05 })
	local lying = facing(mesh, -2.05, -0.3, moundTop(-2.05, -0.3) + 0.06, -0.3, -0.1, 0.95)
	plate({
		vertex = function(_self, x: number, y: number, z: number)
			return lying:vertex(x, -z, y)
		end,
		face = function(_self, face)
			return lying:face(face)
		end,
	}, half, 0, 0.1, 0.012)
end, nil, 0.8)

part("Hubs", nil, DARK_STEEL, function(mesh)
	for _, d in DRUMS do
		local cap = facing(mesh, d[1], d[2], d[3], d[6], d[7], d[8], d[9])
		cylinder(cap, 0, 0, d[5] / 2, d[4] * 0.36, 0.1, "z", 10)
		cylinder(cap, 0, 0, d[5] / 2 + 0.05, d[4] * 0.14, 0.08, "z", 8)
	end
end, nil, 0.5)

for _, entry in parts do
	if entry.name ~= "Mound" then
		entry.bandPieces = PIECES
	end
	-- A lumpy mound is all edges to the rust and the highlights, so it takes little of either; cast iron takes its full share.
	entry.rust *= if entry.name == "Drums" then 2 else 0.3
	if entry.name == "Mound" then
		-- Earth has no edge to catch the light and no rust: both fleck the rim.
		entry.lit, entry.rust = 0, 0
	end
end
handFinish({
	Mound = "rock",
	Drums = "metal",
	Discs = "metal",
	Hubs = "metal",
}, {}, { Mound = "heapBody", metal = "heapPiece" })
finishParts()
