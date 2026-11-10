-- Scrap Tree (Exhaust): a trunk of exhaust pipes bundled with wire, set in a
-- concrete footing and splaying at the top into branches, each ending in a
-- muffler can for leaves. One can has rusted off and lies at the foot.
-- include: HandFinish
local CONCRETE = { 0.5, 0.48, 0.44 }
-- Builds into a mesh whose z axis points along (nx, ny, nz) from (cx, cy, cz),
-- so round pieces made about "z" at the origin face that way. A `crush` under 1
-- flattens it across y, dented in from one side.
local function facing(mesh, cx: number, cy: number, cz: number, nx: number, ny: number, nz: number, crush: number?)
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

-- Each branch: where its pipe ends and the can it carries, then the side can on
-- a stub halfway along, if it still has one.
local BRANCHES = {
	{ tip = { 2.3, 0.3, 7.2 }, radius = 0.6, long = 1.7, side = { radius = 0.4, long = 1.1 } },
	{ tip = { -0.2, 2.05, 7.8 }, radius = 0.5, long = 1.2, crush = 0.42, side = { radius = 0.3, long = 0.8 } },
	{ tip = { -2.45, -0.15, 6.95 }, radius = 0.72, long = 1.7, side = { radius = 0.44, long = 1.3, crush = 0.48 } },
	{ tip = { 0.3, -2.15, 7.55 } },
}
local CENTRE_TIP = { 0.1, 0.05, 8.3 }
local COLLAR_LONG = 0.24

local function pipePoints(i: number)
	local a = i * math.pi / 2
	local ox, oy = math.cos(a) * 0.25, math.sin(a) * 0.25
	local branch = BRANCHES[i + 1]
	local t = branch.tip
	return { { ox * 2, oy * 2, 0.42 }, { ox, oy, 2 }, { ox, oy, 5 }, { t[1] * 0.85, t[2] * 0.85, t[3] - 0.9 }, t }
end

-- Where a side stub leaves its branch, and where it ends.
local function stubOf(i: number)
	local points = pipePoints(i)
	local a, b = points[3], points[4]
	local at = { a[1] + (b[1] - a[1]) * 0.55, a[2] + (b[2] - a[2]) * 0.55, a[3] + (b[3] - a[3]) * 0.55 }
	local t = BRANCHES[i + 1].tip
	local length = math.sqrt(t[1] * t[1] + t[2] * t[2])
	local sideX, sideY = -t[2] / length * 0.6, t[1] / length * 0.6
	return at, { at[1] + sideX, at[2] + sideY, at[3] + 0.8 }
end

-- A can seated on the end of a pipe running from `from` to `to`; the pipe's
-- collar meets its base and a short outlet tops it.
local function can(mesh, from, to, radius: number, long: number, crush: number?)
	local onPipe = facing(mesh, to[1], to[2], to[3], to[1] - from[1], to[2] - from[2], to[3] - from[3], crush)
	cylinder(onPipe, 0, 0, COLLAR_LONG / 2 - 0.02 + long / 2, radius, long, "z", 10)
	cylinder(onPipe, 0, 0, COLLAR_LONG / 2 - 0.02 + long + 0.06, 0.2, 0.16, "z", 8)
end

local function collar(mesh, from, to)
	local onPipe = facing(mesh, to[1], to[2], to[3], to[1] - from[1], to[2] - from[2], to[3] - from[3])
	cylinder(onPipe, 0, 0, 0, 0.3, COLLAR_LONG, "z", 10)
end

part("Footing", nil, CONCRETE, function(mesh)
	box(mesh, 0, 0, 0, 2.5, 2.3, 0.48)
	box(mesh, 1.5, 0.5, 0, 0.7, 0.8, 0.3)
	box(mesh, -1.45, -0.6, 0, 0.6, 0.7, 0.24)
end, nil, 0.25)

part("Pipes", nil, { 0.52, 0.52, 0.55 }, function(mesh)
	for i = 0, 3 do
		local points = pipePoints(i)
		exhaust(mesh, points, 0.16)
		if BRANCHES[i + 1].radius then
			collar(mesh, points[4], points[5])
		end
		-- A bolted flange on the footing round each pipe's foot.
		cylinder(mesh, points[1][1], points[1][2], 0.58, 0.3, 0.2, "z", 10)
		local at, tip = stubOf(i)
		tube(mesh, { at, tip }, 0.11, 8)
		if BRANCHES[i + 1].side then
			collar(mesh, at, tip)
		else
			-- Its can rusted off, leaving the stub capped with a torn flange.
			cylinder(facing(mesh, tip[1], tip[2], tip[3], tip[1] - at[1], tip[2] - at[2], tip[3] - at[3]), 0, 0, 0, 0.2, 0.08, "z", 8)
		end
	end
	local base, bend = { 0, 0, 0.42 }, { 0, 0, 7.6 }
	tube(mesh, { base, bend, CENTRE_TIP }, 0.16, 10)
	collar(mesh, bend, CENTRE_TIP)
end, true, 0.85)

part("Mufflers", nil, { 0.56, 0.55, 0.54 }, function(mesh)
	for i = 0, 3 do
		local branch = BRANCHES[i + 1]
		local points = pipePoints(i)
		-- One branch has lost its can and just ends in open pipe.
		if branch.radius then
			can(mesh, points[4], points[5], branch.radius, branch.long, branch.crush)
		end
		if branch.side then
			local at, tip = stubOf(i)
			can(mesh, at, tip, branch.side.radius, branch.side.long, branch.side.crush)
		end
	end
	can(mesh, { 0, 0, 7.6 }, CENTRE_TIP, 0.62, 1.4)
	-- The one that fell, lying against the footing.
	cylinder(facing(mesh, 1.75, -1.0, 0.42, 1, 0.35, 0.1), 0, 0, 0, 0.42, 1.3, "z", 10)
end, nil, 0.6)

part("Lashing", nil, COPPER, function(mesh)
	for _, z in { 1.5, 3, 4.5 } do
		ring(mesh, 0, 0, z, 0.38, 0.48, 0.12, "z", 10)
	end
end, nil, 0.3)

-- Pipes are dark, so their edges catch more light to show their steps.
for _, entry in parts do
	if entry.name == "Pipes" then
		-- Dark pipes: a light base gradient, bright edges and heavy rust do the darkening.
		entry.lit, entry.gradient, entry.rust = 2.2, 0.1, 0.7
	elseif entry.name == "Mufflers" then
		-- Pale steel goes violet under the cool base tint; it rusts instead.
		entry.gradient, entry.rust = 0.1, 0.75
	end
end
handFinish({
	Footing = "rock",
	Pipes = "metal",
	Mufflers = "metal",
	Lashing = "metal",
}, {}, PROP_FINISH)
finishParts()
