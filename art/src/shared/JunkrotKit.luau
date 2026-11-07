-- Junkrot Kit: shaping helpers the junkrots share, on top of the edit-mesh
-- tools (which it brings in). Each helper makes a fresh edit mesh, z up,
-- front toward -y, centred on the origin unless it says otherwise; every
-- vertex stays editable afterwards. Include it first: `-- include:
-- JunkrotKit`.
--
--   Kit.turn(m, axis, degrees)     turn a whole mesh about x, y or z
--   Kit.size(m, f | {fx, fy, fz})  scale a whole mesh about the origin
--   Kit.block(sx, sy, sz, round, cuts)  a block with rounded edges
--   Kit.lathe(profile, sides)      a lathe of {r, z} points, bottom to top
--   Kit.curve(points, steps)       a smooth path through control points
--   Kit.tube(path, radius, sides)  a capped round tube along a path;
--                                  radius may be a function of t (0 to 1)
--   Kit.plate(outline, thickness)  a slab cut to a convex {x, z} outline,
--                                  front at y = 0, `thickness` deep in +y
--   Kit.shoe(long, wide, high)     a shoe, toe toward +x, sole at z = 0
--   Kit.recess(m, faces, rim, depth)  a panel sunk into faces (or raised,
--                                  with a negative depth)
-- include: EditMesh
-- include: EditOps
-- include: EditShapes
local Kit = {}

function Kit.turn(m, axis, degrees)
	local a = math.rad(degrees)
	local c, s = math.cos(a), math.sin(a)
	return m:transform(function(p)
		local x, y, z = p[1], p[2], p[3]
		if axis == "x" then
			return { x, y * c - z * s, y * s + z * c }
		elseif axis == "y" then
			return { x * c + z * s, y, -x * s + z * c }
		end
		return { x * c - y * s, x * s + y * c, z }
	end)
end

-- Factors must be positive: a mirror would turn the faces inside out.
function Kit.size(m, f)
	local fx, fy, fz = f, f, f
	if type(f) == "table" then
		fx, fy, fz = f[1], f[2], f[3]
	end
	return m:transform(function(p)
		return { p[1] * fx, p[2] * fy, p[3] * fz }
	end)
end

-- The rounding never reaches half the block's thinnest side: past that the
-- rounded edges would cross each other.
function Kit.block(sx, sy, sz, round, cuts)
	round = math.min(round or 0.08, math.min(sx, sy, sz) / 2 * 0.98)
	return EditMesh.roundedBox({ sx, sy, sz }, round, 2, cuts)
end

function Kit.lathe(profile, sides)
	return EditMesh.spin(profile, sides or 16)
end

-- Catmull-Rom through the points, `steps` points to each span.
function Kit.curve(points, steps)
	steps = steps or 4
	local out = {}
	local n = #points
	for i = 1, n - 1 do
		local p0, p1, p2, p3 = points[math.max(1, i - 1)], points[i], points[i + 1], points[math.min(n, i + 2)]
		for s = 0, steps - 1 do
			local t = s / steps
			local t2, t3 = t * t, t * t * t
			local q = {}
			for a = 1, 3 do
				q[a] = 0.5
					* (2 * p1[a] + (p2[a] - p0[a]) * t + (2 * p0[a] - 5 * p1[a] + 4 * p2[a] - p3[a]) * t2 + (3 * p1[a] - p0[a] - 3 * p2[a] + p3[a]) * t3)
			end
			table.insert(out, q)
		end
	end
	table.insert(out, { points[n][1], points[n][2], points[n][3] })
	return out
end

function Kit.tube(path, radius, sides)
	sides = sides or 8
	local outline = {}
	for k = 0, sides - 1 do
		local t = k / sides * 2 * math.pi
		table.insert(outline, { math.cos(t), math.sin(t) })
	end
	local scale = radius
	if type(radius) ~= "function" then
		scale = function()
			return radius
		end
	end
	return EditMesh.sweep(outline, path, { scale = scale })
end

function Kit.plate(outline, thickness)
	local m = EditMesh.new()
	local verts = {}
	for _, p in outline do
		table.insert(verts, m:addVertex(p[1], 0, p[2]))
	end
	m:addFace(verts)
	return m:solidify(thickness)
end

function Kit.shoe(long, wide, high)
	local hx, hy = long / 2, wide / 2
	local m = EditMesh.lattice({ -hx, -hx * 0.3, hx * 0.25, hx * 0.7, hx }, { -hy, -hy * 0.4, hy * 0.4, hy }, { 0, high * 0.55, high })
	-- The toe slopes down toward its tip.
	m:transform(function(p)
		local toe = math.clamp((p[1] - hx * 0.25) / (hx * 0.75), 0, 1)
		return { p[1], p[2], p[3] * (1 - 0.45 * toe) }
	end)
	-- A collar up from the heel, for a leg to go into.
	local heel = m:select("face", "facing", { 0, 0, 1 }, 20):filter(function(p)
		return p[1] < -hx * 0.3 and math.abs(p[2]) < hy * 0.4
	end)
	local collar = m:extrude(heel, high * 0.45)
	collar:scale(0.85)
	m:select("edge", "where", function(p)
		return p[3] < 0.001
	end):crease(1)
	m:smoothSubdivide(1)
	return m
end

function Kit.recess(m, faces, rim, depth)
	return m:inset(faces, rim, -depth)
end
