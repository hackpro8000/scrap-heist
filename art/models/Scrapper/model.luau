-- Scrapper: the fast, weak scrap bot, about 2.5 studs tall. A rusty box body
-- patched with odd plates, carried on a swing arm over one wobbly wheel. A
-- red eye in a steel rim, a buzzsaw on a side arm and a bent antenna
-- topped with a little radar dish. Faces -Y; stands with the wheel on the
-- origin.
-- Rig: Root > Body > Suspension > Wheel (spins), SawArm > Saw (spins),
-- Antenna (wobbles).

-- Mismatched scrap: rusty box steel, a galvanised panel, a sky-blue panel
-- off an old appliance, dark steel running gear, a bright saw, in sRGB.
local RUST = { 0.55, 0.35, 0.16 }
local GALVANISED = { 0.6, 0.63, 0.62 }
local APPLIANCE = { 0.36, 0.55, 0.66 }
local OLIVE = { 0.42, 0.45, 0.36 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local STEEL = { 0.62, 0.64, 0.66 }
local TYRE = { 0.16, 0.16, 0.17 }
local EYE = { 0.95, 0.15, 0.1 }

local WHEEL_RADIUS = 0.42
-- The wheel trails behind the body, held on the swing arm's axle.
local AXLE_Y = 0.3
local AXLE_LENGTH = 0.8
local BODY_BOTTOM, BODY_HEIGHT = 0.95, 0.9
local BODY_WIDTH, BODY_DEPTH = 1.05, 0.9
-- Swing arm pivot, under the body on the +X side.
local PIVOT = { 0.36, -0.15, BODY_BOTTOM - 0.08 }
local SAW_X, SAW_Z = 1.05, 1.35
local SAW_RADIUS = 0.42
local SAW_TEETH = 14
local EYE_Z = 1.5
local TAU = 2 * math.pi

-- Edge highlight and feathering, matching the salvage machine.
local EDGE_HIGHLIGHT = 0.45
local EDGE_BLEND = 0.7
local SMOOTH_ANGLE = 30
local TEXTURE = 256

local function box(mesh, cx, cy, cz, sx, sy, sz)
	local v = {}
	for i = 0, 7 do
		local x = cx + (if i % 2 == 0 then -sx else sx) / 2
		local y = cy + (if i // 2 % 2 == 0 then -sy else sy) / 2
		local z = cz + (if i // 4 == 0 then 0 else sz)
		v[i + 1] = mesh:vertex(x, y, z)
	end
	mesh:face({ v[1], v[3], v[4], v[2] })
	mesh:face({ v[5], v[6], v[8], v[7] })
	mesh:face({ v[1], v[2], v[6], v[5] })
	mesh:face({ v[3], v[7], v[8], v[4] })
	mesh:face({ v[1], v[5], v[7], v[3] })
	mesh:face({ v[2], v[4], v[8], v[6] })
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
local function part(name, bone, color, build, smooth, rust)
	local mesh = Mesh.new()
	build(mesh)
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

-- Disc in the YZ plane with sawtooth edge, centred at (cx, cy, cz).
local function sawBlade(mesh, cx, cy, cz, radius, thick, teeth)
	local front, back = {}, {}
	for i = 0, teeth * 2 - 1 do
		local t = i / (teeth * 2) * TAU
		-- Hooked teeth: tips lean round the spin direction.
		local r = if i % 2 == 0 then radius else radius * 0.82
		local lean = if i % 2 == 0 then 0.12 else 0
		front[i + 1] = mesh:vertex(cx + thick / 2, cy + math.cos(t + lean) * r, cz + math.sin(t + lean) * r)
		back[i + 1] = mesh:vertex(cx - thick / 2, cy + math.cos(t + lean) * r, cz + math.sin(t + lean) * r)
	end
	local n = #front
	for i = 1, n do
		local j = i % n + 1
		mesh:face({ back[i], back[j], front[j], front[i] })
	end
	mesh:face(front)
	local capBack = {}
	for i = n, 1, -1 do
		table.insert(capBack, back[i])
	end
	mesh:face(capBack)
end

-- Shallow dish opening along +Z then tilted toward -Y, apex at (cx, cy, cz).
local function radarDish(mesh, cx, cy, cz, radius, depth)
	local sides = 12
	local tilt = 0.6
	local function at(x, y, z)
		-- Tilt about X so the dish faces up and forward.
		local c, s = math.cos(tilt), math.sin(tilt)
		return mesh:vertex(cx + x, cy + y * c + z * s, cz - y * s + z * c)
	end
	local apex = at(0, 0, 0)
	local rim, lip = {}, {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		rim[i + 1] = at(math.cos(t) * radius, math.sin(t) * radius, depth)
		lip[i + 1] = at(math.cos(t) * radius * 0.9, math.sin(t) * radius * 0.9, depth * 0.75)
	end
	for i = 1, sides do
		local j = i % sides + 1
		mesh:face({ apex, rim[j], rim[i] })
		mesh:face({ rim[i], rim[j], lip[j], lip[i] })
	end
	local inner = {}
	for i = sides, 1, -1 do
		table.insert(inner, lip[i])
	end
	mesh:face(inner)
end

local root = model.bone("Root", { at = { 0, 0, 0 } })
local body = model.bone("Body", { at = { 0, 0, BODY_BOTTOM }, parent = root })
local suspension = model.bone("Suspension", { at = PIVOT, parent = body })
local wheel = model.bone("Wheel", { at = { 0, AXLE_Y, WHEEL_RADIUS }, parent = suspension })
local sawArm = model.bone("SawArm", { at = { BODY_WIDTH / 2, 0, SAW_Z }, parent = body })
local saw = model.bone("Saw", { at = { SAW_X, -0.15, SAW_Z }, parent = sawArm })
local antenna = model.bone("Antenna", { at = { -0.3, 0.2, BODY_BOTTOM + BODY_HEIGHT }, parent = body })

local top = BODY_BOTTOM + BODY_HEIGHT
local front = -BODY_DEPTH / 2

part("Wheel", wheel, TYRE, function(mesh)
	cylinder(mesh, 0, AXLE_Y, WHEEL_RADIUS, WHEEL_RADIUS, 0.3, "x", 20)
end, nil, RUBBER)
part("WheelHub", wheel, STEEL, function(mesh)
	-- Hub rims on both faces, with lug bolts round each.
	for _, side in { -1, 1 } do
		ring(mesh, side * 0.16, AXLE_Y, WHEEL_RADIUS, 0.1, 0.24, 0.04, "x")
		for i = 0, 4 do
			local t = i / 5 * TAU
			bolt(mesh, side * 0.18, AXLE_Y + math.cos(t) * 0.17, WHEEL_RADIUS + math.sin(t) * 0.17, "x", 0.03)
		end
	end
end)
part("SwingArm", suspension, DARK_STEEL, function(mesh)
	-- Axle right through the wheel, capped with nuts.
	cylinder(mesh, 0.08, AXLE_Y, WHEEL_RADIUS, 0.06, AXLE_LENGTH, "x", 10)
	bolt(mesh, -AXLE_LENGTH / 2 + 0.08, AXLE_Y, WHEEL_RADIUS, "x", 0.09)
	-- Arm from the pivot bracket back and down to the axle end.
	local ax = AXLE_LENGTH / 2 + 0.02
	strut(mesh, PIVOT[1], PIVOT[2], PIVOT[3], ax, AXLE_Y, WHEEL_RADIUS, 0.13)
	cylinder(mesh, ax, AXLE_Y, WHEEL_RADIUS, 0.1, 0.12, "x", 10)
	cylinder(mesh, PIVOT[1], PIVOT[2], PIVOT[3], 0.09, 0.2, "x", 10)
end)
-- Coil-over shock: the cylinder hangs from the body, the rod rides on the arm and
-- slides inside it, so the arm can swing without the shock bending.
local SHOCK_TOP = { 0.3, 0.35, BODY_BOTTOM + 0.05 }
local SHOCK_FOOT = { AXLE_LENGTH / 2 - 0.01, AXLE_Y - 0.12, WHEEL_RADIUS + 0.25 }
local function alongShock(k)
	return SHOCK_FOOT[1] + (SHOCK_TOP[1] - SHOCK_FOOT[1]) * k,
		SHOCK_FOOT[2] + (SHOCK_TOP[2] - SHOCK_FOOT[2]) * k,
		SHOCK_FOOT[3] + (SHOCK_TOP[3] - SHOCK_FOOT[3]) * k
end
part("ShockCylinder", body, DARK_STEEL, function(mesh)
	local x, y, z = alongShock(0.45)
	strut(mesh, x, y, z, SHOCK_TOP[1], SHOCK_TOP[2], SHOCK_TOP[3], 0.08)
	for i = 0, 3 do
		local rx, ry, rz = alongShock(0.5 + i * 0.13)
		ring(mesh, rx, ry, rz, 0.04, 0.085, 0.03, "z", 8)
	end
end)
part("ShockRod", suspension, GALVANISED, function(mesh)
	local x, y, z = alongShock(0.8)
	strut(mesh, SHOCK_FOOT[1], SHOCK_FOOT[2], SHOCK_FOOT[3], x, y, z, 0.035)
	cylinder(mesh, SHOCK_FOOT[1], SHOCK_FOOT[2], SHOCK_FOOT[3], 0.05, 0.12, "x", 8)
end)
local halfW, halfD = BODY_WIDTH / 2, BODY_DEPTH / 2
part("Body", body, DARK_STEEL, function(mesh)
	box(mesh, 0, 0, BODY_BOTTOM, BODY_WIDTH, BODY_DEPTH, BODY_HEIGHT)
end, nil, 0.5)
part("Lid", body, RUST, function(mesh)
	-- Lid lip round the top, like the box it was cut from.
	box(mesh, 0, 0, top - 0.08, BODY_WIDTH + 0.06, BODY_DEPTH + 0.06, 0.08)
end, nil, 0.5)
-- Skin panels, each off a different scrap pile and rusted to its own degree.
part("FrontPanel", body, RUST, function(mesh)
	sheet(mesh, "y", front, -1, -0.5, 0.5, BODY_BOTTOM + 0.44, top - 0.1)
end, nil, 0.75)
part("FrontCornerPanel", body, RUST, function(mesh)
	sheet(mesh, "y", front, -1, 0.25, 0.5, BODY_BOTTOM + 0.03, BODY_BOTTOM + 0.4)
end, nil, 0.95)
part("RightPanel", body, RUST, function(mesh)
	sheet(mesh, "x", halfW, 1, -0.42, 0.42, BODY_BOTTOM + 0.03, top - 0.1)
end, nil, 0.85)
part("LeftPanel", body, OLIVE, function(mesh)
	sheet(mesh, "x", -halfW, -1, -0.42, 0.42, BODY_BOTTOM + 0.03, top - 0.1)
end, nil, 0.45)
part("BackPanelLeft", body, GALVANISED, function(mesh)
	sheet(mesh, "y", halfD, 1, -0.5, -0.02, BODY_BOTTOM + 0.03, top - 0.1)
end, nil, 0.2)
part("BackPanelRight", body, RUST, function(mesh)
	sheet(mesh, "y", halfD, 1, 0.02, 0.5, BODY_BOTTOM + 0.03, top - 0.1)
end, nil, 0.55)
part("SeamTape", body, TAPE, function(mesh)
	-- Strips of tape holding the back seam shut.
	for _, z in { BODY_BOTTOM + 0.2, BODY_BOTTOM + 0.45, BODY_BOTTOM + 0.65 } do
		box(mesh, 0, halfD + 0.035, z, 0.24, 0.01, 0.07)
	end
end, nil, RUBBER)
part("Brackets", body, DARK_STEEL, function(mesh)
	for _, sx in { -1, 1 } do
		cornerBracket(mesh, sx * (halfW + 0.03), front - 0.03, sx, -1, BODY_BOTTOM + 0.3, 0.3, 0.2)
	end
end, nil, 0.6)
part("Plates", body, GALVANISED, function(mesh)
	-- Strap riveted over the top.
	box(mesh, 0.25, 0, top, 0.16, BODY_DEPTH + 0.1, 0.03)
end)
part("Motor", body, DARK_STEEL, function(mesh)
	-- Lawnmower engine bolted on the lid, its exhaust bent up off the back.
	engine(mesh, 0.05, -0.12, top, 0.24)
	exhaust(mesh, { { 0.2, -0.05, top + 0.12 }, { 0.32, 0.1, top + 0.14 }, { 0.36, 0.3, top + 0.35 }, { 0.36, 0.32, top + 0.6 } }, 0.04)
end, nil, 0.7)
part("Gears", body, STEEL, function(mesh)
	-- Exposed gear train on the back, meshing as the wheel turns.
	gear(mesh, -0.22, halfD + 0.06, BODY_BOTTOM + 0.38, 0.16, 0.04, 10, "y")
	gear(mesh, 0.06, halfD + 0.06, BODY_BOTTOM + 0.56, 0.12, 0.04, 8, "y")
	gear(mesh, 0.25, halfD + 0.06, BODY_BOTTOM + 0.38, 0.09, 0.04, 6, "y")
end, nil, 0.55)
part("Pipes", body, GALVANISED, function(mesh)
	-- Fuel line from the motor down the left side, flanged at the joints.
	local points = { { -0.1, -0.12, top + 0.05 }, { -0.4, -0.12, top + 0.05 }, { -halfW - 0.08, -0.12, top - 0.1 }, { -halfW - 0.08, -0.3, BODY_BOTTOM + 0.15 } }
	tube(mesh, points, 0.025, 8)
	ring(mesh, -halfW - 0.08, -0.15, top - 0.18, 0.02, 0.045, 0.04, "z", 8)
end, nil, 0.45)
part("AppliancePanel", body, APPLIANCE, function(mesh)
	-- Off-square panel on the -X side, from an old washing machine.
	box(mesh, -BODY_WIDTH / 2 - 0.05, 0.05, BODY_BOTTOM + 0.3, 0.04, 0.62, 0.48)
	for _, y in { -0.21, 0.31 } do
		for _, z in { BODY_BOTTOM + 0.36, BODY_BOTTOM + 0.72 } do
			bolt(mesh, -BODY_WIDTH / 2 - 0.08, y, z, "x", 0.035)
		end
	end
end)
part("EyeRim", body, STEEL, function(mesh)
	ring(mesh, 0.12, front - 0.06, EYE_Z, 0.17, 0.27, 0.08, "y", 20)
	for i = 0, 5 do
		local t = i / 6 * TAU
		bolt(mesh, 0.12 + math.cos(t) * 0.22, front - 0.11, EYE_Z + math.sin(t) * 0.22, "y", 0.025)
	end
end)
part("Eye", body, EYE, function(mesh)
	sphere(mesh, 0.12, front - 0.04, EYE_Z, 0.18, 0.08, 0.18)
end, true, 0)
part("SawArm", sawArm, DARK_STEEL, function(mesh)
	box(mesh, BODY_WIDTH / 2 + 0.06, 0, SAW_Z - 0.18, 0.06, 0.3, 0.36)
	strut(mesh, BODY_WIDTH / 2, 0, SAW_Z, SAW_X - 0.05, -0.15, SAW_Z, 0.14)
	cylinder(mesh, SAW_X - 0.08, -0.15, SAW_Z, 0.09, 0.12, "x", 10)
end)
part("SawBelt", sawArm, RUBBER_BLACK, function(mesh)
	-- Belt from a pulley on the body out to the saw's hub.
	cylinder(mesh, BODY_WIDTH / 2 + 0.17, 0.2, SAW_Z, 0.09, 0.05, "x", 12)
	belt(mesh, "x", BODY_WIDTH / 2 + 0.17, 0.2, SAW_Z, 0.09, BODY_WIDTH / 2 + 0.17, -0.15, SAW_Z, 0.11, 0.022)
end, nil, RUBBER)
part("Saw", saw, STEEL, function(mesh)
	sawBlade(mesh, SAW_X, -0.15, SAW_Z, SAW_RADIUS, 0.04, SAW_TEETH)
	bolt(mesh, SAW_X + 0.04, -0.15, SAW_Z, "x", 0.08)
end)
part("Antenna", antenna, DARK_STEEL, function(mesh)
	cylinder(mesh, -0.3, 0.2, top + 0.04, 0.07, 0.08, "z", 8)
	strut(mesh, -0.3, 0.2, top, -0.35, 0.25, top + 0.4, 0.05)
	strut(mesh, -0.35, 0.25, top + 0.4, -0.12, 0.3, top + 0.62, 0.05)
end)
part("RadarDish", antenna, GALVANISED, function(mesh)
	radarDish(mesh, -0.12, 0.3, top + 0.6, 0.3, 0.14)
end)
