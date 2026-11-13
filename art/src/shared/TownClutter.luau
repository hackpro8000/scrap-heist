-- Small props and fittings shared by the town pieces. Each takes the mesh,
-- stands at its base height `z` and returns its bounds, { x0, y0, z0, x1, y1, z1 }.
local SUPPLY_TONES = { { 0.64, 0.36, 0.2 }, { 0.3, 0.44, 0.52 }, { 0.72, 0.56, 0.2 }, { 0.5, 0.5, 0.48 }, { 0.32, 0.42, 0.3 }, { 0.58, 0.24, 0.2 } }

type Bounds = { number }

-- Colour by object, never by region of space: each prop in a clutter part is
-- registered with `prop(bounds, tone?)` as it is built, and `paint` gives a
-- point the tone of the smallest prop holding it (the nearest, for a point
-- just outside every one). A prop without its own tone takes the next in
-- SUPPLY_TONES, so neighbours built one after another differ. Make one pair
-- per part, before the part, and pass `paint` as its paint.
local function supplyTones(): ((Bounds, { number }?) -> (), (number, number, number) -> (number, number, number))
	local props: { { bounds: Bounds, tone: { number } } } = {}
	local function prop(bounds: Bounds, tone: { number }?)
		table.insert(props, { bounds = bounds, tone = tone or SUPPLY_TONES[#props % #SUPPLY_TONES + 1] })
	end
	local function paint(x: number, y: number, z: number): (number, number, number)
		local best, bestScore = props[1], math.huge
		for _, entry in props do
			local b = entry.bounds
			-- Distance outside the box (0 inside), then size, so the smallest
			-- holder wins over a larger one it rests against.
			local dx = math.max(b[1] - x, 0, x - b[4])
			local dy = math.max(b[2] - y, 0, y - b[5])
			local dz = math.max(b[3] - z, 0, z - b[6])
			local score = math.sqrt(dx * dx + dy * dy + dz * dz) * 1000 + (b[4] - b[1]) * (b[5] - b[2]) * (b[6] - b[3])
			if score < bestScore then
				best, bestScore = entry, score
			end
		end
		return best.tone[1], best.tone[2], best.tone[3]
	end
	return prop, paint
end

-- A box() as a prop, returning its bounds.
local function boxProp(mesh, x: number, y: number, z: number, wide: number, deep: number, high: number): Bounds
	box(mesh, x, y, z, wide, deep, high)
	return { x - wide / 2, y - deep / 2, z, x + wide / 2, y + deep / 2, z + high }
end

-- A strut() as a prop, returning its bounds.
local function strutProp(mesh, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, thick: number): Bounds
	strut(mesh, x0, y0, z0, x1, y1, z1, thick)
	local half = thick / 2
	return { math.min(x0, x1) - half, math.min(y0, y1) - half, math.min(z0, z1) - half, math.max(x0, x1) + half, math.max(y0, y1) + half, math.max(z0, z1) + half }
end

-- An upright barrel; its bung sits `bungTurn` radians round from +x, so a
-- stack can keep bungs clear of the barrel above. A barrel stacked on others
-- stands at their z + BARREL_HIGH.
local BARREL_HIGH = 1.8
local function barrel(mesh, x: number, y: number, z: number, bungTurn: number?): Bounds
	cylinder(mesh, x, y, z + BARREL_HIGH / 2, 0.6, BARREL_HIGH, "z", 14)
	for _, h in { 0.08, 0.62, 1.2, 1.74 } do
		cylinder(mesh, x, y, z + h, 0.66, 0.1, "z", 14)
	end
	local turn = bungTurn or 0
	cylinder(mesh, x + math.cos(turn) * 0.25, y + math.sin(turn) * 0.25, z + 1.86, 0.1, 0.12, "z", 8)
	return { x - 0.66, y - 0.66, z, x + 0.66, y + 0.66, z + 1.92 }
end

local function gasBottle(mesh, x: number, y: number, z: number): Bounds
	cylinder(mesh, x, y, z + 1.3, 0.29, 2.6, "z", 12)
	sphere(mesh, x, y, z + 2.6, 0.27, 0.27, 0.2, 4, 12)
	cylinder(mesh, x, y, z + 2.88, 0.08, 0.3, "z", 8)
	cylinder(mesh, x, y, z + 3.05, 0.17, 0.08, "z", 8)
	return { x - 0.29, y - 0.29, z, x + 0.29, y + 0.29, z + 3.09 }
end

local function tyres(mesh, x: number, y: number, z: number, count: number): Bounds
	for n = 0, count - 1 do
		ring(mesh, x + (n * 7 % 3 - 1) * 0.1, y + (n * 5 % 3 - 1) * 0.1, z + 0.22 + n * 0.44, 0.42, 0.95, 0.44, "z", 16)
	end
	return { x - 1.05, y - 1.05, z, x + 1.05, y + 1.05, z + count * 0.44 }
end

local function toolChest(mesh, x: number, y: number, z: number): Bounds
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
	return { x - 1.15, y - 0.91, z, x + 1.15, y + 0.75, z + 2.58 }
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
