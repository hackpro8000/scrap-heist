-- Bruiser: the slow tank scrap bot, about 5 studs tall. A hulking rusty body
-- plated with dumpster lids (ribbed, hinged, with grab handles), a red visor
-- slit in a steel frame, bolted shoulder plates and two lugged tank treads.
-- Faces -Y; stands with the treads on the origin.
-- Rig: Root > Treads, Body > ShoulderL, ShoulderR, Visor.

-- Mismatched scrap: rusty body steel, green dumpster lids, a galvanised
-- patch, a cream panel off an old fridge, dark steel running gear, in sRGB.
local RUST = { 0.55, 0.35, 0.16 }
local DUMPSTER = { 0.25, 0.4, 0.28 }
local GALVANISED = { 0.6, 0.63, 0.62 }
local FRIDGE = { 0.82, 0.78, 0.66 }
local OLIVE = { 0.42, 0.45, 0.36 }
local BLUE_GREY = { 0.4, 0.47, 0.52 }
local GREY = { 0.55, 0.57, 0.6 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local STEEL = { 0.62, 0.64, 0.66 }
local TREAD = { 0.18, 0.18, 0.2 }
local VISOR = { 0.95, 0.15, 0.1 }

local TREAD_HEIGHT = 0.9
local TREAD_X, TREAD_WIDTH, TREAD_LENGTH = 1.05, 0.7, 2.6
local BODY_TOP = 4.2
local BODY_FRONT = -0.85
local SHOULDER_Z = 3.7
local TAU = 2 * math.pi

-- Edge highlight and feathering, matching the salvage machine.
local EDGE_HIGHLIGHT = 0.45
local EDGE_BLEND = 0.7
local SMOOTH_ANGLE = 30
local TEXTURE = 256

-- Faces are split into a grid about every 0.4 studs so the warp in
-- `part` can bend and dent flat panels.
local GRID = 0.4

local function gridFace(mesh, origin, u, v, nu, nv)
	local rows = {}
	for j = 0, nv do
		rows[j] = {}
		for i = 0, nu do
			local a, b = i / nu, j / nv
			rows[j][i] = mesh:vertex(
				origin[1] + u[1] * a + v[1] * b,
				origin[2] + u[2] * a + v[2] * b,
				origin[3] + u[3] * a + v[3] * b
			)
		end
	end
	for j = 0, nv - 1 do
		for i = 0, nu - 1 do
			mesh:face({ rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i] })
		end
	end
end

local function box(mesh, cx, cy, cz, sx, sy, sz)
	local x0, y0, z0 = cx - sx / 2, cy - sy / 2, cz
	local nx = math.clamp(math.ceil(sx / GRID), 1, 8)
	local ny = math.clamp(math.ceil(sy / GRID), 1, 8)
	local nz = math.clamp(math.ceil(sz / GRID), 1, 8)
	gridFace(mesh, { x0, y0, z0 }, { 0, sy, 0 }, { sx, 0, 0 }, ny, nx)
	gridFace(mesh, { x0, y0, z0 + sz }, { sx, 0, 0 }, { 0, sy, 0 }, nx, ny)
	gridFace(mesh, { x0, y0, z0 }, { sx, 0, 0 }, { 0, 0, sz }, nx, nz)
	gridFace(mesh, { x0, y0 + sy, z0 }, { 0, 0, sz }, { sx, 0, 0 }, nz, nx)
	gridFace(mesh, { x0, y0, z0 }, { 0, 0, sz }, { 0, sy, 0 }, nz, ny)
	gridFace(mesh, { x0 + sx, y0, z0 }, { 0, sy, 0 }, { 0, 0, sz }, ny, nz)
end

-- Cylinder centered at (cx, cy, cz) along axis "x", "y" or "z".
local function cylinder(mesh, cx, cy, cz, radius, length, axis, sides)
	sides = sides or 16
	local a, b = {}, {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		local u, w = math.cos(t) * radius, math.sin(t) * radius
		local h = length / 2
		if axis == "x" then
			a[i + 1] = mesh:vertex(cx - h, cy + u, cz + w)
			b[i + 1] = mesh:vertex(cx + h, cy + u, cz + w)
		elseif axis == "y" then
			a[i + 1] = mesh:vertex(cx + w, cy - h, cz + u)
			b[i + 1] = mesh:vertex(cx + w, cy + h, cz + u)
		else
			a[i + 1] = mesh:vertex(cx + u, cy + w, cz - h)
			b[i + 1] = mesh:vertex(cx + u, cy + w, cz + h)
		end
	end
	for i = 1, sides do
		local j = i % sides + 1
		mesh:face({ a[i], a[j], b[j], b[i] })
	end
	local capA = {}
	for i = sides, 1, -1 do
		table.insert(capA, a[i])
	end
	mesh:face(capA)
	mesh:face(b)
end

-- UV sphere, squashed per axis by (rx, ry, rz).
local function sphere(mesh, cx, cy, cz, rx, ry, rz, rings, sides)
	rings, sides = rings or 8, sides or 16
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local t = s / sides * TAU
			local x = math.sin(phi) * math.cos(t)
			local y = math.sin(phi) * math.sin(t)
			grid[r][s] = mesh:vertex(cx + x * rx, cy + y * ry, cz - math.cos(phi) * rz)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			mesh:face({ grid[r][s], grid[r][n], grid[r + 1][n], grid[r + 1][s] })
		end
	end
end

-- Flat ring (washer) facing along axis "x", "y" or "z": a rim round an eye,
-- a hub, a hose clamp.
local function ring(mesh, cx, cy, cz, inner, outer, depth, axis, sides)
	sides = sides or 16
	local function at(r, t, d)
		local u, w = math.cos(t) * r, math.sin(t) * r
		if axis == "x" then
			return mesh:vertex(cx + d, cy + u, cz + w)
		elseif axis == "y" then
			return mesh:vertex(cx + w, cy + d, cz + u)
		end
		return mesh:vertex(cx + u, cy + w, cz + d)
	end
	local rows = {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		rows[i + 1] = { at(outer, t, -depth / 2), at(outer, t, depth / 2), at(inner, t, depth / 2), at(inner, t, -depth / 2) }
	end
	for i = 1, sides do
		local a, b = rows[i], rows[i % sides + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
end

-- Bolt head: a squat hexagonal stud on a face pointing along axis.
local function bolt(mesh, cx, cy, cz, axis, size)
	size = size or 0.05
	cylinder(mesh, cx, cy, cz, size, size * 0.7, axis, 6)
end

-- Square beam from one point to another, for limbs and antennae.
local function strut(mesh, x0, y0, z0, x1, y1, z1, thick)
	local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / len, dy / len, dz / len
	local ax, ay, az = -dy, dx, 0
	if math.abs(dz) > 0.99 then
		ax, ay, az = 1, 0, 0
	end
	local al = math.sqrt(ax * ax + ay * ay + az * az)
	ax, ay, az = ax / al * thick / 2, ay / al * thick / 2, az / al * thick / 2
	local bx, by, bz = dy * az - dz * ay, dz * ax - dx * az, dx * ay - dy * ax
	local v = {}
	for i = 0, 7 do
		local sa = if i % 2 == 0 then -1 else 1
		local sb = if i // 2 % 2 == 0 then -1 else 1
		local x, y, z = if i // 4 == 0 then x0 else x1, if i // 4 == 0 then y0 else y1, if i // 4 == 0 then z0 else z1
		v[i + 1] = mesh:vertex(x + ax * sa + bx * sb, y + ay * sa + by * sb, z + az * sa + bz * sb)
	end
	for _, f in { { 1, 3, 4, 2 }, { 5, 6, 8, 7 }, { 1, 2, 6, 5 }, { 3, 7, 8, 4 }, { 1, 5, 7, 3 }, { 2, 4, 8, 6 } } do
		mesh:face({ v[f[1]], v[f[2]], v[f[3]], v[f[4]] })
	end
end

-- Unit tangent along (tx, ty, tz) plus two unit axes across it, right-handed,
-- the first level with the ground unless the tangent runs nearly vertical.
local function crossFrame(tx, ty, tz)
	local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
	tx, ty, tz = tx / tl, ty / tl, tz / tl
	local ux, uy, uz = -ty, tx, 0
	if math.abs(tz) > 0.9 then
		ux, uy, uz = 0, tz, -ty
	end
	local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / ul, uy / ul, uz / ul
	return tx, ty, tz, ux, uy, uz, ty * uz - tz * uy, tz * ux - tx * uz, tx * uy - ty * ux
end

-- Round tube through `points` ({x, y, z} each), capped at both ends: rope
-- strands, and bolts on curved faces.
local function tube(mesh, points, radius, sides)
	sides = sides or 8
	local rings = {}
	for i, p in points do
		local a, b = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
		local ring = {}
		for k = 0, sides - 1 do
			local t = k / sides * TAU
			local c, n = math.cos(t) * radius, math.sin(t) * radius
			ring[k + 1] = mesh:vertex(p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n)
		end
		rings[i] = ring
	end
	for i = 1, #rings - 1 do
		local a, b = rings[i], rings[i + 1]
		for k = 1, sides do
			local n = k % sides + 1
			mesh:face({ a[k], a[n], b[n], b[k] })
		end
	end
	local cap = {}
	for k = sides, 1, -1 do
		table.insert(cap, rings[1][k])
	end
	mesh:face(cap)
	mesh:face(rings[#rings])
end

-- Point in the plane across `axis` at centre (cx, cy, cz): radius r, angle t,
-- offset d along the axis.
local function onAxis(cx, cy, cz, axis, r, t, d)
	local u, w = math.cos(t) * r, math.sin(t) * r
	if axis == "x" then
		return cx + d, cy + u, cz + w
	elseif axis == "y" then
		return cx + w, cy + d, cz + u
	end
	return cx + u, cy + w, cz + d
end

-- Spur gear turning about `axis`, with square teeth and a hole for its shaft.
local function gear(mesh, cx, cy, cz, radius, thick, teeth, axis)
	local steps = teeth * 4
	local rows = {}
	for i = 0, steps - 1 do
		local t = i / steps * TAU
		-- Two samples up on the tooth, two down in the gap.
		local r = if i % 4 < 2 then radius else radius * 0.82
		local hole = radius * 0.25
		rows[i + 1] = {
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, -thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, -thick / 2)),
		}
	end
	for i = 1, steps do
		local a, b = rows[i], rows[i % steps + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
	-- Shaft through the middle.
	cylinder(mesh, cx, cy, cz, radius * 0.25, thick * 1.8, axis, 8)
end

-- Drive belt wrapped round two pulleys turning about `axis`, the first at
-- (ax, ay, az) with radius ra, the second at (bx, by, bz) with radius rb.
local function belt(mesh, axis, ax, ay, az, ra, bx, by, bz, rb, thick)
	thick = thick or 0.025
	-- Work in the plane across the axis as (u, w), matching onAxis.
	local function flat(x, y, z)
		if axis == "x" then
			return y, z
		elseif axis == "y" then
			return z, x
		end
		return x, y
	end
	local au, aw = flat(ax, ay, az)
	local bu, bw = flat(bx, by, bz)
	local heading = math.atan2(bw - aw, bu - au)
	local points = {}
	-- Round the far side of b, then back round the far side of a.
	for i = 0, 8 do
		local t = heading - math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(bx, by, bz, axis, rb + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	for i = 0, 8 do
		local t = heading + math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(ax, ay, az, axis, ra + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	table.insert(points, points[1])
	tube(mesh, points, thick, 4)
end

-- Exhaust pipe along `points`, ending in a flared, soot-black lip.
local function exhaust(mesh, points, radius)
	tube(mesh, points, radius, 10)
	local a, b = points[#points - 1], points[#points]
	local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / length, dy / length, dz / length
	tube(mesh, {
		{ b[1] - dx * 0.06, b[2] - dy * 0.06, b[3] - dz * 0.06 },
		{ b[1], b[2], b[3] },
	}, radius * 1.3, 10)
end

-- Little engine block: a box crankcase with a finned cylinder on top.
local function engine(mesh, cx, cy, cz, size)
	box(mesh, cx, cy, cz, size * 1.4, size, size * 0.7)
	local top = cz + size * 0.7
	cylinder(mesh, cx, cy, top + size * 0.35, size * 0.3, size * 0.7, "z", 12)
	for i = 0, 3 do
		ring(mesh, cx, cy, top + size * (0.1 + i * 0.17), size * 0.28, size * 0.45, size * 0.05, "z", 12)
	end
	box(mesh, cx, cy, top + size * 0.7, size * 0.5, size * 0.5, size * 0.1)
end

-- Bolt head on a curved face, standing out along the normal (nx, ny, nz).
local function stud(mesh, x, y, z, nx, ny, nz, size)
	size = size or 0.04
	local a, b = -size * 0.2, size * 0.5
	tube(mesh, { { x + nx * a, y + ny * a, z + nz * a }, { x + nx * b, y + ny * b, z + nz * b } }, size, 6)
end

-- Rope along `points`: two strands twisted round each other.
local function rope(mesh, points, radius)
	-- Resample the path finely enough for the twist to turn smoothly.
	local path = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) / (radius * 0.8)))
		for k = 0, steps - 1 do
			table.insert(path, { a[1] + dx * k / steps, a[2] + dy * k / steps, a[3] + dz * k / steps })
		end
	end
	table.insert(path, points[#points])
	for strand = 0, 1 do
		local twisted = {}
		for i, p in path do
			local a, b = path[math.max(i - 1, 1)], path[math.min(i + 1, #path)]
			local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
			local t = i * 0.7 + strand * math.pi
			local c, n = math.cos(t) * radius * 0.45, math.sin(t) * radius * 0.45
			twisted[i] = { p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n }
		end
		tube(mesh, twisted, radius * 0.6, 6)
	end
end

-- Rope lashed round a box at height z, its corners at x = +-halfX and
-- y from y0 to y1, rounded so it sits snug round each corner.
local function lashing(mesh, halfX, y0, y1, z, radius)
	local bend = radius * 3
	-- Corner centres counter-clockwise from (+X, y0), each with its start angle.
	local corners = {
		{ halfX - bend, y0 + bend, -math.pi / 2 },
		{ halfX - bend, y1 - bend, 0 },
		{ -halfX + bend, y1 - bend, math.pi / 2 },
		{ -halfX + bend, y0 + bend, math.pi },
	}
	local points = {}
	for _, c in corners do
		for k = 0, 3 do
			local t = c[3] + k / 3 * math.pi / 2
			table.insert(points, { c[1] + math.cos(t) * bend, c[2] + math.sin(t) * bend, z })
		end
	end
	table.insert(points, points[1])
	rope(mesh, points, radius)
end

-- Flat sheet lying on the face of a box at `axis` = `at`, its outer side toward
-- `sign`, covering a0..a1 along the other level axis and z0..z1 up, bolted at
-- each corner.
local function sheet(mesh, axis, at, sign, a0, a1, z0, z1, thick, boltSize)
	thick, boltSize = thick or 0.03, boltSize or 0.035
	local c = at + sign * thick / 2
	if axis == "x" then
		box(mesh, c, (a0 + a1) / 2, z0, thick, a1 - a0, z1 - z0)
	else
		box(mesh, (a0 + a1) / 2, c, z0, a1 - a0, thick, z1 - z0)
	end
	local inset = boltSize * 2
	for _, a in { a0 + inset, a1 - inset } do
		for _, z in { z0 + inset, z1 - inset } do
			if axis == "x" then
				bolt(mesh, at + sign * thick, a, z, "x", boltSize)
			else
				bolt(mesh, a, at + sign * thick, z, "y", boltSize)
			end
		end
	end
end

-- Angle bracket bent round the vertical box corner at (x, y), outer faces
-- toward sx and sy, legs `size` long, bolted through each leg.
local function cornerBracket(mesh, x, y, sx, sy, z, height, size)
	local t = 0.025
	box(mesh, x + sx * t / 2, y - sy * (size - t) / 2, z, t, size + t, height)
	box(mesh, x - sx * (size - t) / 2, y + sy * t / 2, z, size + t, t, height)
	for _, dz in { 0.25, 0.75 } do
		bolt(mesh, x + sx * t, y - sy * size * 0.6, z + height * dz, "x", 0.03)
		bolt(mesh, x - sx * size * 0.6, y + sy * t, z + height * dz, "y", 0.03)
	end
end

-- Weathering, in sRGB: rust patches (dark pitted core, orange rust, pale
-- flaky rim) with drips running down out of them, bright scratches, and
-- grime that darkens toward the ground.
local RUST_DARK = { 0.3, 0.2, 0.12 }
local RUST_ORANGE = { 0.62, 0.36, 0.15 }
local RUST_FLAKE = { 0.78, 0.52, 0.3 }
local BARE_METAL = { 0.74, 0.73, 0.7 }

-- Scratch coverage at a point: 1 in a scratch, -1 in its dark burr, 0 clear.
-- Scratches run in clusters, each cluster in its own direction across the
-- surface, and every line starts and stops on its own so the ends taper.
local function scratchAt(x, y, z, nx, ny, nz)
	if math.noise(x * 1.8 + 20, y * 1.8, z * 1.8) < 0.05 then
		return 0
	end
	-- Surface tangents from the normal.
	local tx, ty, tz = 1, 0, 0
	if math.abs(nz) < 0.9 then
		tx, ty, tz = -ny, nx, 0
	end
	local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
	tx, ty, tz = tx / tl, ty / tl, tz / tl
	local bx, by, bz = ny * tz - nz * ty, nz * tx - nx * tz, nx * ty - ny * tx
	local angle = math.noise(x * 0.9 + 4, y * 0.9, z * 0.9) * math.pi
	local c, s = math.cos(angle), math.sin(angle)
	local along = (x * tx + y * ty + z * tz) * c + (x * bx + y * by + z * bz) * s
	local across = (x * bx + y * by + z * bz) * c - (x * tx + y * ty + z * tz) * s
	local u = across * 9 + math.noise(x * 5, y * 5, z * 5) * 0.4
	local line = math.floor(u)
	local reach = math.noise(along * 2.2, line * 1.37, 9)
	if reach < 0.25 then
		return 0
	end
	local width = 0.07 + (reach - 0.25) * 0.12
	local d = math.abs(u - line - 0.5)
	return if d < width then 1 elseif d < width * 2 then -1 else 0
end

-- Paint fn for `color` worn by `rust` (0 clean, 1 eaten through).
local function weathered(color, rust)
	local edge = 0.75 - rust * 0.6
	return function(x, y, z, nx, ny, nz)
		local grime = math.clamp((1.2 - z) * 0.18, 0, 0.25) + math.noise(x * 3, y * 3, z * 3) * 0.08
		local k = 1 - math.clamp(grime, 0, 0.35)
		local patch = math.noise(x * 2.5 + 7, y * 2.5, z * 2.5) * 0.8 + math.noise(x * 8, y * 8, z * 8 + 5) * 0.3
		local c = color
		if patch > edge + 0.18 then
			local pit = if math.noise(x * 25, y * 25, z * 25) > 0.25 then 0.7 else 1
			c = { RUST_DARK[1] * pit, RUST_DARK[2] * pit, RUST_DARK[3] * pit }
		elseif patch > edge + 0.06 then
			c = RUST_ORANGE
		elseif patch > edge then
			c = RUST_FLAKE
		else
			local above = math.noise(x * 2.5 + 7, y * 2.5, (z + 0.2) * 2.5) * 0.8
			local drip = math.noise(x * 16, y * 16, z * 0.8 + 3)
			if above > edge - 0.05 and drip > 0.3 then
				c = RUST_ORANGE
			else
				local scratch = scratchAt(x, y, z, nx, ny, nz)
				if scratch > 0 then
					c = { (color[1] + BARE_METAL[1] * 2) / 3, (color[2] + BARE_METAL[2] * 2) / 3, (color[3] + BARE_METAL[3] * 2) / 3 }
				elseif scratch < 0 then
					c = { color[1] * 0.8, color[2] * 0.8, color[3] * 0.8 }
				end
			end
		end
		return c[1] * k, c[2] * k, c[3] * k
	end
end

local RUBBER = -1
local DUST = { 0.55, 0.5, 0.42 }
-- Bindings, painted as RUBBER: duct tape and hemp rope.
local TAPE = { 0.58, 0.58, 0.56 }
local RUBBER_BLACK = { 0.12, 0.12, 0.13 }
local ROPE = { 0.62, 0.5, 0.32 }

-- Paint fn for rubber: dust settled low and in patches, and pale scuffs where
-- it has rubbed. Rubber doesn't rust.
local function scuffed(color)
	return function(x, y, z, nx, ny, nz)
		local dust = math.clamp((0.9 - z) * 0.3, 0, 0.3)
			+ math.clamp(math.noise(x * 3 + 2, y * 3, z * 3) * 0.5, 0, 0.35)
			+ math.clamp(nz, 0, 1) * 0.15
		local c = {
			color[1] + (DUST[1] - color[1]) * dust,
			color[2] + (DUST[2] - color[2]) * dust,
			color[3] + (DUST[3] - color[3]) * dust,
		}
		if scratchAt(x, y, z, nx, ny, nz) > 0 then
			return c[1] * 1.6, c[2] * 1.6, c[3] * 1.6
		end
		return c[1], c[2], c[3]
	end
end

-- Part following one bone. `smooth` overrides the auto-smooth angle (true
-- for fully round parts like the zapper's body). `rust` sets how worn it
-- is, default 0.4; 0 for glowing eyes and visors; RUBBER for tyres and treads.
local WARP = 0.0385

-- Low-frequency warp so no panel is perfectly flat or square: a smooth sum
-- of sines seeded by the part name, plus a couple of dents.
local function imperfect(mesh, name)
	local seed = 0
	for i = 1, #name do
		seed = (seed * 31 + string.byte(name, i)) % 9973
	end
	local function n(k)
		return math.sin(seed * 12.9898 + k * 78.233) * 0.5 + 0.5
	end
	local function noise(x, y, z, k)
		return math.sin(x * (1.7 + n(k)) + y * 0.9 + n(k + 1) * TAU) * 0.5
			+ math.sin(y * (2.3 + n(k + 2)) - z * 1.3 + n(k + 3) * TAU) * 0.3
			+ math.sin(z * (2.9 + n(k + 4)) + x * 1.1 + n(k + 5) * TAU) * 0.2
	end
	local dents = {}
	for d = 1, 2 do
		local k = d * 10
		dents[d] = { (n(k) - 0.5) * 3, (n(k + 1) - 0.5) * 3, n(k + 2) * 4, 0.3 + n(k + 3) * 0.4 }
	end
	return setmetatable({
		vertex = function(_, x, y, z)
			local dx, dy, dz = noise(x, y, z, 1), noise(y, z, x, 7), noise(z, x, y, 13)
			for _, dent in dents do
				local ox, oy, oz = x - dent[1], y - dent[2], z - dent[3]
				local fall = math.exp(-(ox * ox + oy * oy + oz * oz) / (dent[4] * dent[4]))
				dx -= ox * fall * 0.6
				dy -= oy * fall * 0.6
				dz -= oz * fall * 0.6
			end
			return mesh:vertex(x + dx * WARP, y + dy * WARP, z + dz * WARP)
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

local function part(name, bone, color, build, smooth, rust)
	local mesh = Mesh.new()
	build(if rust == 0 then mesh else imperfect(mesh, name))
	mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
	mesh:unwrap()
	local image = Image.new(TEXTURE, TEXTURE, color[1], color[2], color[3])
	rust = rust or 0.4
	if rust == RUBBER then
		mesh:paint(image, scuffed(color))
	elseif rust > 0 then
		mesh:paint(image, weathered(color, rust))
	end
	mesh:paintShading(image, { highlight = EDGE_HIGHLIGHT, blend = EDGE_BLEND })
	model.part(name, mesh, image, { bone = bone, preview = true })
end

local root = model.bone("Root", { at = { 0, 0, 0 } })
local treads = model.bone("Treads", { at = { 0, 0, TREAD_HEIGHT / 2 }, parent = root })
local body = model.bone("Body", { at = { 0, 0, TREAD_HEIGHT }, parent = root })
local shoulderL = model.bone("ShoulderL", { at = { -1.3, 0, SHOULDER_Z }, parent = body })
local shoulderR = model.bone("ShoulderR", { at = { 1.3, 0, SHOULDER_Z }, parent = body })
local visor = model.bone("Visor", { at = { 0, -0.9, 3.6 }, parent = body })

part("Treads", treads, TREAD, function(mesh)
	local radius = TREAD_HEIGHT / 2
	for _, side in { -1, 1 } do
		local x = side * TREAD_X
		box(mesh, x, 0, 0, TREAD_WIDTH, TREAD_LENGTH, TREAD_HEIGHT)
		cylinder(mesh, x, -TREAD_LENGTH / 2, radius, radius, TREAD_WIDTH, "x")
		cylinder(mesh, x, TREAD_LENGTH / 2, radius, radius, TREAD_WIDTH, "x")
		-- Grip lugs across the top and bottom runs.
		for i = 0, 6 do
			local y = -1.2 + i * 0.4
			box(mesh, x, y, TREAD_HEIGHT, TREAD_WIDTH + 0.04, 0.12, 0.06)
			box(mesh, x, y, -0.06, TREAD_WIDTH + 0.04, 0.12, 0.06)
		end
	end
	box(mesh, 0, 0, 0.3, 1.5, 1.6, 0.5)
end, nil, RUBBER)
part("RoadWheels", treads, DARK_STEEL, function(mesh)
	local radius = TREAD_HEIGHT / 2
	for _, side in { -1, 1 } do
		local x = side * (TREAD_X + TREAD_WIDTH / 2 + 0.03)
		-- Drive sprockets at the ends, small road wheels between.
		for _, y in { -TREAD_LENGTH / 2, TREAD_LENGTH / 2 } do
			ring(mesh, x, y, radius, 0.12, radius - 0.06, 0.06, "x")
			cylinder(mesh, x + side * 0.03, y, radius, 0.1, 0.1, "x", 8)
		end
		for _, y in { -0.65, 0, 0.65 } do
			cylinder(mesh, x, y, radius, 0.24, 0.06, "x")
			bolt(mesh, x + side * 0.04, y, radius, "x", 0.06)
		end
	end
end)
part("Body", body, DARK_STEEL, function(mesh)
	box(mesh, 0, 0, TREAD_HEIGHT - 0.1, 2.2, 1.7, BODY_TOP - TREAD_HEIGHT + 0.1)
	-- Welded seam strips around the waist.
	box(mesh, 0, 0, 2.0, 2.34, 1.84, 0.08)
end, nil, 0.5)
-- Skin panels off different wrecks, each rusted to its own degree.
local function panel(name, color, rust, ...)
	local args = { ... }
	part(name, body, color, function(mesh)
		sheet(mesh, args[1], args[2], args[3], args[4], args[5], args[6], args[7], 0.04, 0.05)
	end, nil, rust)
end
panel("LeftLowerPanel", RUST, 0.85, "x", -1.1, -1, -0.8, 0.8, 0.85, 1.96)
panel("LeftUpperFrontPanel", BLUE_GREY, 0.35, "x", -1.1, -1, -0.8, -0.02, 2.06, 3.35)
panel("LeftUpperBackPanel", RUST, 0.6, "x", -1.1, -1, 0.02, 0.8, 2.06, 3.35)
panel("RightLowerPanel", OLIVE, 0.55, "x", 1.1, 1, -0.8, 0.8, 0.85, 1.96)
panel("RightUpperPanel", RUST, 0.4, "x", 1.1, 1, -0.8, 0.8, 2.06, 3.35)
panel("BackLowerPanel", RUST, 0.7, "y", 0.85, 1, -1.05, 1.05, 0.85, 1.96)
panel("BackUpperPanel", OLIVE, 0.25, "y", 0.85, 1, -1.05, 1.05, 2.06, 4.12)
panel("FrontUpperPanel", RUST, 0.55, "y", BODY_FRONT, -1, -1.05, 1.05, 3.15, 4.12)
part("Lashing", body, ROPE, function(mesh)
	-- Rope cinched round the waist, knotted at the front corner.
	lashing(mesh, 1.25, -1.05, 1.0, 2.55, 0.045)
	sphere(mesh, 1.1, -1.08, 2.55, 0.1, 0.08, 0.1)
end, nil, RUBBER)
part("SeamTape", body, TAPE, function(mesh)
	-- Tape across the seam between the two upper left panels.
	for _, z in { 2.98, 3.22 } do
		box(mesh, -1.1 - 0.045, 0, z, 0.01, 0.3, 0.09)
	end
end, nil, RUBBER)
part("Brackets", body, DARK_STEEL, function(mesh)
	for _, sx in { -1, 1 } do
		for _, z in { 1.0, 3.0 } do
			cornerBracket(mesh, sx * 1.14, 0.89, sx, 1, z, 0.5, 0.25)
		end
	end
end, nil, 0.6)
part("ScrapPatches", body, GALVANISED, function(mesh)
	-- Galvanised sheet riveted over the left side, and a back plate.
	box(mesh, -1.17, 0.1, 1.6, 0.05, 1.1, 1.3)
	for _, y in { -0.38, 0.58 } do
		for _, z in { 1.7, 2.8 } do
			bolt(mesh, -1.2, y, z, "x")
		end
	end
	box(mesh, 0.3, 0.915, 2.3, 1.2, 0.05, 1.0)
	for _, x in { -0.22, 0.82 } do
		for _, z in { 2.4, 3.2 } do
			bolt(mesh, x, 0.945, z, "y")
		end
	end
end)
part("FridgePanel", body, FRIDGE, function(mesh)
	-- A dented fridge door bolted on the right side, handle and all.
	box(mesh, 1.17, -0.05, 1.3, 0.05, 1.2, 1.5)
	box(mesh, 1.21, -0.55, 1.9, 0.04, 0.08, 0.5)
	for _, y in { -0.55, 0.45 } do
		for _, z in { 1.4, 2.7 } do
			bolt(mesh, 1.2, y, z, "x")
		end
	end
end)
part("LidPlates", body, DUMPSTER, function(mesh)
	-- Front lid bolted over the chest, ribbed like the real thing.
	box(mesh, 0, BODY_FRONT - 0.05, 1.4, 1.9, 0.1, 1.7)
	for i = 0, 3 do
		box(mesh, 0, BODY_FRONT - 0.13, 1.6 + i * 0.4, 1.8, 0.06, 0.08)
	end
	-- Top lid slung over like a cap, with a raised hump and ribs.
	box(mesh, 0, -0.1, BODY_TOP, 2.4, 2.0, 0.15)
	box(mesh, 0, 0.3, BODY_TOP + 0.15, 2.3, 1.2, 0.5)
	for _, x in { -0.7, 0, 0.7 } do
		box(mesh, x, 0.3, BODY_TOP + 0.65, 0.1, 1.1, 0.05)
	end
end)
part("LidHardware", body, DARK_STEEL, function(mesh)
	-- Hinges along the top lid's back edge and the front lid's top edge.
	for _, x in { -0.8, 0.8 } do
		cylinder(mesh, x, 0.9, BODY_TOP + 0.1, 0.07, 0.4, "x", 8)
		box(mesh, x, 0.75, BODY_TOP + 0.15, 0.36, 0.3, 0.04)
		box(mesh, x, 0.94, BODY_TOP - 0.35, 0.36, 0.04, 0.4)
		cylinder(mesh, x, BODY_FRONT - 0.12, 3.12, 0.06, 0.35, "x", 8)
	end
	-- Grab handles: on the front lid, and along the top lid's front lip.
	strut(mesh, -0.4, BODY_FRONT - 0.12, 1.75, -0.4, BODY_FRONT - 0.3, 1.75, 0.06)
	strut(mesh, 0.4, BODY_FRONT - 0.12, 1.75, 0.4, BODY_FRONT - 0.3, 1.75, 0.06)
	strut(mesh, -0.43, BODY_FRONT - 0.3, 1.75, 0.43, BODY_FRONT - 0.3, 1.75, 0.06)
	strut(mesh, -0.5, -1.1, BODY_TOP + 0.07, -0.5, -1.25, BODY_TOP - 0.05, 0.05)
	strut(mesh, 0.5, -1.1, BODY_TOP + 0.07, 0.5, -1.25, BODY_TOP - 0.05, 0.05)
	strut(mesh, -0.53, -1.25, BODY_TOP - 0.05, 0.53, -1.25, BODY_TOP - 0.05, 0.05)
	-- Corner bolts holding the front lid on.
	for _, x in { -0.85, 0.85 } do
		for _, z in { 1.5, 3.0 } do
			bolt(mesh, x, BODY_FRONT - 0.12, z, "y", 0.06)
		end
	end
end)
part("VisorFrame", body, GREY, function(mesh)
	local y = BODY_FRONT - 0.12
	box(mesh, 0, y, 3.4, 1.7, 0.14, 0.08)
	box(mesh, 0, y, 3.72, 1.7, 0.14, 0.08)
	box(mesh, -0.81, y, 3.4, 0.08, 0.14, 0.4)
	box(mesh, 0.81, y, 3.4, 0.08, 0.14, 0.4)
	for _, x in { -0.75, 0.75 } do
		bolt(mesh, x, y - 0.08, 3.44, "y", 0.035)
		bolt(mesh, x, y - 0.08, 3.76, "y", 0.035)
	end
end)
part("Visor", visor, VISOR, function(mesh)
	box(mesh, 0, BODY_FRONT - 0.09, 3.48, 1.54, 0.1, 0.24)
end, true, 0)
for _, side in { { "L", shoulderL, -1 }, { "R", shoulderR, 1 } } do
	local name, bone, s = side[1], side[2], side[3]
	part("Shoulder" .. name, bone, GREY, function(mesh)
		-- Pivot hub along X at the bone, with a gap so the arm turns clear of the body.
		cylinder(mesh, s * 1.14, 0, SHOULDER_Z, 0.28, 0.1, "x", 14)
		cylinder(mesh, s * 1.14, 0, SHOULDER_Z, 0.08, 0.16, "x", 6)
		local x = s * 1.53
		box(mesh, x, 0, SHOULDER_Z - 0.4, 0.7, 1.4, 0.9)
		-- A thinner armour plate overlapping the top, bolted down.
		box(mesh, x + s * 0.05, 0, SHOULDER_Z + 0.5, 0.75, 1.45, 0.08)
		for _, y in { -0.55, 0, 0.55 } do
			bolt(mesh, x + s * 0.25, y, SHOULDER_Z + 0.6, "z")
			bolt(mesh, x + s * 0.36, y, SHOULDER_Z, "x")
		end
	end)
end
part("Engine", body, DARK_STEEL, function(mesh)
	-- Diesel block strapped to the back, twin stacks rising past the lid.
	engine(mesh, 0, 1.15, 2.2, 0.6)
	box(mesh, 0, 0.95, 2.1, 0.9, 0.2, 0.08)
	for _, s in { -1, 1 } do
		exhaust(mesh, { { s * 0.3, 1.2, 2.9 }, { s * 0.45, 1.15, 3.4 }, { s * 0.5, 1.05, 4.0 }, { s * 0.5, 1.05, 4.8 } }, 0.09)
	end
end, nil, 0.75)
part("FanBelt", body, RUBBER_BLACK, function(mesh)
	belt(mesh, "x", 0.62, 1.1, 2.45, 0.14, 0.62, 1.1, 3.05, 0.09, 0.04)
end, true, RUBBER)
part("Gears", body, STEEL, function(mesh)
	-- Exposed final drive on each side above the treads.
	for _, s in { -1, 1 } do
		gear(mesh, s * 1.15, -0.4, 1.35, 0.28, 0.08, 12, "x")
		gear(mesh, s * 1.15, 0.05, 1.6, 0.18, 0.08, 9, "x")
	end
	gear(mesh, 0.62, 1.1, 2.45, 0.14, 0.05, 8, "x")
end, nil, 0.55)
part("Pipes", body, GALVANISED, function(mesh)
	-- Coolant lines from the engine round both flanks, flanged at the joints.
	for _, s in { -1, 1 } do
		tube(mesh, { { s * 0.35, 1.3, 2.5 }, { s * 0.9, 1.0, 2.6 }, { s * 1.15, 0.6, 2.7 }, { s * 1.15, -0.5, 2.7 }, { s * 1.15, -0.7, 3.2 } }, 0.05)
		ring(mesh, s * 1.15, 0.1, 2.7, 0.05, 0.08, 0.05, "y")
	end
end, nil, 0.6)
