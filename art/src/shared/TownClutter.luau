-- Small props and fittings shared by the town pieces. Each takes the mesh and
-- stands at its base height `z`.
local SUPPLY_TONES = { { 0.64, 0.36, 0.2 }, { 0.3, 0.44, 0.52 }, { 0.72, 0.56, 0.2 }, { 0.5, 0.5, 0.48 }, { 0.32, 0.42, 0.3 }, { 0.58, 0.24, 0.2 } }

-- A paint that gives each prop its own colour, so a clutter part isn't one tone.
local function supplyTones(x: number, y: number, z: number): (number, number, number)
	local tone = SUPPLY_TONES[(math.floor(x * 0.32) * 3 + math.floor(y * 0.32) * 5 + math.floor(z * 0.22)) % #SUPPLY_TONES + 1]
	return tone[1], tone[2], tone[3]
end

local function barrel(mesh, x: number, y: number, z: number)
	cylinder(mesh, x, y, z + 0.9, 0.6, 1.8, "z", 14)
	for _, h in { 0.08, 0.62, 1.2, 1.74 } do
		cylinder(mesh, x, y, z + h, 0.66, 0.1, "z", 14)
	end
	cylinder(mesh, x + 0.25, y, z + 1.86, 0.1, 0.12, "z", 8)
end

local function gasBottle(mesh, x: number, y: number, z: number)
	cylinder(mesh, x, y, z + 1.3, 0.29, 2.6, "z", 12)
	sphere(mesh, x, y, z + 2.6, 0.27, 0.27, 0.2, 4, 12)
	cylinder(mesh, x, y, z + 2.88, 0.08, 0.3, "z", 8)
	cylinder(mesh, x, y, z + 3.05, 0.17, 0.08, "z", 8)
end

local function tyres(mesh, x: number, y: number, z: number, count: number)
	for n = 0, count - 1 do
		ring(mesh, x + (n * 7 % 3 - 1) * 0.1, y + (n * 5 % 3 - 1) * 0.1, z + 0.22 + n * 0.44, 0.42, 0.95, 0.44, "z", 16)
	end
end

local function toolChest(mesh, x: number, y: number, z: number)
	box(mesh, x, y, z + 0.28, 2.3, 1.5, 2.3)
	for row = 0, 4 do
		box(mesh, x, y - 0.78, z + 0.42 + row * 0.42, 2.06, 0.08, 0.36)
		box(mesh, x, y - 0.86, z + 0.56 + row * 0.42, 0.8, 0.1, 0.08)
	end
	for _, cx in { -0.9, 0.9 } do
		for _, cy in { -0.55, 0.55 } do
			cylinder(mesh, x + cx, y + cy, z + 0.16, 0.16, 0.34, "z", 8)
		end
	end
end

-- A ladder along z, standing off a wall by `off` (negative for a wall on the
-- other side). Rungs are wide enough to read at a player's size.
local LADDER_HALF = 0.72
local function ladderOnX(mesh, x: number, y: number, z0: number, z1: number, off: number)
	for _, side in { -LADDER_HALF, LADDER_HALF } do
		box(mesh, x, y + side, z0, 0.14, 0.14, z1 - z0)
	end
	for z = z0 + 0.5, z1 - 0.2, 0.9 do
		box(mesh, x, y, z, 0.1, LADDER_HALF * 2 + 0.06, 0.1)
	end
	for z = z0 + 0.8, z1 - 0.4, 3 do
		box(mesh, x - off / 2, y, z, math.abs(off) + 0.1, LADDER_HALF * 2 - 0.1, 0.12)
	end
end

local function ladderOnY(mesh, x: number, y: number, z0: number, z1: number, off: number)
	for _, side in { -LADDER_HALF, LADDER_HALF } do
		box(mesh, x + side, y, z0, 0.14, 0.14, z1 - z0)
	end
	for z = z0 + 0.5, z1 - 0.2, 0.9 do
		box(mesh, x, y, z, LADDER_HALF * 2 + 0.06, 0.1, 0.1)
	end
	for z = z0 + 0.8, z1 - 0.4, 3 do
		box(mesh, x, y - off / 2, z, LADDER_HALF * 2 - 0.1, math.abs(off) + 0.1, 0.12)
	end
end

-- A wire sagging between two points, as a list of points.
local function sagging(ax, ay, az, bx, by, bz, drop: number, steps: number)
	local points = {}
	for n = 0, steps do
		local t = n / steps
		table.insert(points, { ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t - drop * 4 * t * (1 - t) })
	end
	return points
end
