local CACHE_KEY = "BeltCrossing-b7c50e18a585e3f4"
-- Rarity accents, in sRGB: grey common, green uncommon, blue rare, gold
-- legendary.
local COMMON = { 0.62, 0.62, 0.6 }
local UNCOMMON = { 0.3, 0.72, 0.3 }
local RARE = { 0.25, 0.5, 0.95 }
local LEGENDARY = { 1.0, 0.72, 0.18 }
local STEEL = { 0.62, 0.64, 0.66 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local COPPER = { 0.85, 0.5, 0.25 }
local TAU = 2 * math.pi

-- Edge highlight and feathering, matching the salvage machine.
local EDGE_HIGHLIGHT = 0.6
local CONTACT_SHADOW = 0.425
-- Scales every part's wear (rust, grime, scratches): 57% of what each part asks for.
local WEAR = 0.57
local GRADIENT = 0.5
local EDGE_BLEND = 0.7
local SMOOTH_ANGLE = 30
local TEXTURE = 256

-- Faces are split into a grid about every 0.4 studs so the warp in
-- `part` can bend and dent flat panels.
local GRID = 0.4

-- When set, every part sizes its texture to this many pixels per stud
-- instead of the fixed TEXTURE, so a layout reads at one texel density.
-- A part's own `texture` size still wins.
local texelDensity: number? = nil
-- The density the layout asked for, before TEXEL_SCALE: chunk sizes follow
-- this one, so a max-detail preview keeps the chunks it would ship with.
local layoutDensity: number? = nil

-- Previews build at a fraction of the density the layout asks for (TEXEL_SCALE).
local function useTexelDensity(pixelsPerStud: number)
	layoutDensity = pixelsPerStud
	texelDensity = pixelsPerStud * (TEXEL_SCALE or 1)
end

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

-- Points along a circular arc in the x-z plane, from angle a0 to a1 in
-- degrees. Feeds plate outlines; run the angles downward for a clockwise path.
local function arc(cx, cz, radius, a0, a1, steps)
	local points = {}
	for i = 0, steps do
		local a = math.rad(a0 + (a1 - a0) * i / steps)
		table.insert(points, { cx + math.cos(a) * radius, cz + math.sin(a) * radius })
	end
	return points
end

-- Splits a clockwise x-z outline into triangles by ear clipping, so concave
-- silhouettes cap cleanly. Returns index triples into the outline.
local function earClip(outline)
	local left, tris = {}, {}
	for i = 1, #outline do
		left[i] = i
	end
	local function cross(a, b, c)
		return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
	end
	local guard = 0
	while #left > 3 and guard < 10000 do
		guard += 1
		local clipped = false
		for k = 1, #left do
			local i0, i1, i2 = left[(k - 2) % #left + 1], left[k], left[k % #left + 1]
			local a, b, c = outline[i0], outline[i1], outline[i2]
			if cross(a, b, c) < 0 then
				local inside = false
				for _, j in left do
					if j ~= i0 and j ~= i1 and j ~= i2 then
						local p = outline[j]
						if cross(a, b, p) <= 0 and cross(b, c, p) <= 0 and cross(c, a, p) <= 0 then
							inside = true
							break
						end
					end
				end
				if not inside then
					table.insert(tris, { i0, i1, i2 })
					table.remove(left, k)
					clipped = true
					break
				end
			end
		end
		if not clipped then
			break
		end
	end
	if #left == 3 then
		table.insert(tris, { left[1], left[2], left[3] })
	end
	return tris
end

-- Flat cut-out plate: a clockwise x-z outline extruded `depth` along y,
-- centred on y, with both faces chamfered inward by `bevel`. Use it for any
-- silhouette (signs, blades, brackets) instead of stacking boxes.
local function plate(mesh, outline, y, depth, bevel)
	local n = #outline
	local inset = {}
	for i = 1, n do
		local p0, p1, p2 = outline[(i - 2) % n + 1], outline[i], outline[i % n + 1]
		local function inward(a, b)
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
			return dz / len, -dx / len
		end
		local n1x, n1z = inward(p0, p1)
		local n2x, n2z = inward(p1, p2)
		local bx, bz = n1x + n2x, n1z + n2z
		local bl = math.max(math.sqrt(bx * bx + bz * bz), 1e-6)
		bx, bz = bx / bl, bz / bl
		local scale = math.min(1 / math.max(bx * n1x + bz * n1z, 0.34), 3) * bevel
		inset[i] = { p1[1] + bx * scale, p1[2] + bz * scale }
	end
	local h = depth / 2
	local layers = {
		{ inset, y - h },
		{ outline, y - h + bevel },
		{ outline, y + h - bevel },
		{ inset, y + h },
	}
	local rows = {}
	for l, layer in layers do
		rows[l] = {}
		for i = 1, n do
			rows[l][i] = mesh:vertex(layer[1][i][1], layer[2], layer[1][i][2])
		end
	end
	for l = 1, 3 do
		for i = 1, n do
			local j = i % n + 1
			mesh:face({ rows[l][i], rows[l][j], rows[l + 1][j], rows[l + 1][i] })
		end
	end
	for _, t in earClip(inset) do
		mesh:face({ rows[1][t[3]], rows[1][t[2]], rows[1][t[1]] })
		mesh:face({ rows[4][t[1]], rows[4][t[2]], rows[4][t[3]] })
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
	local function unit(a, b)
		local x, y, z = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local length = math.sqrt(x * x + y * y + z * z)
		if length < 1e-6 then
			return nil
		end
		return { x / length, y / length, z / length }
	end
	local rings = {}
	local carried
	for i, p in points do
		local before, after = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local into, out = i > 1 and unit(before, p) or nil, i < #points and unit(p, after) or nil
		-- Each ring lies across the bisector of its bend.
		local dx, dy, dz = after[1] - before[1], after[2] - before[2], after[3] - before[3]
		if into and out then
			local x, y, z = into[1] + out[1], into[2] + out[2], into[3] + out[3]
			if x * x + y * y + z * z > 1e-6 then
				dx, dy, dz = x, y, z
			end
		end
		local tx, ty, tz, ux, uy, uz, vx, vy, vz = crossFrame(dx, dy, dz)
		-- Carry the last ring's frame round the bend, so the tube can't twist.
		if carried then
			local along = carried[1] * tx + carried[2] * ty + carried[3] * tz
			local x, y, z = carried[1] - tx * along, carried[2] - ty * along, carried[3] - tz * along
			local length = math.sqrt(x * x + y * y + z * z)
			if length > 1e-6 then
				ux, uy, uz = x / length, y / length, z / length
				vx, vy, vz = ty * uz - tz * uy, tz * ux - tx * uz, tx * uy - ty * ux
			end
		end
		carried = { ux, uy, uz }
		-- A ring across a bend is widened toward the bend's outside, or the tube
		-- would pinch there.
		local stretch, bx, by, bz = 1, 0, 0, 0
		if into and out then
			local x, y, z = out[1] - into[1], out[2] - into[2], out[3] - into[3]
			local length = math.sqrt(x * x + y * y + z * z)
			if length > 1e-6 then
				bx, by, bz = x / length, y / length, z / length
				stretch = 1 / math.max(tx * out[1] + ty * out[2] + tz * out[3], 0.5)
			end
		end
		local ring = {}
		for k = 0, sides - 1 do
			local t = k / sides * TAU
			local c, n = math.cos(t) * radius, math.sin(t) * radius
			local x, y, z = ux * c + vx * n, uy * c + vy * n, uz * c + vz * n
			local extra = (x * bx + y * by + z * bz) * (stretch - 1)
			ring[k + 1] = mesh:vertex(p[1] + x + bx * extra, p[2] + y + by * extra, p[3] + z + bz * extra)
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

-- `points` with each inner corner replaced by a curve starting up to `reach`
-- studs before it, for wires and hoses that shouldn't have sharp elbows.
local function roundedPath(points, reach, steps)
	steps = steps or 4
	local path = { points[1] }
	for i = 2, #points - 1 do
		local a, p, b = points[i - 1], points[i], points[i + 1]
		local function towards(q)
			local x, y, z = q[1] - p[1], q[2] - p[2], q[3] - p[3]
			local length = math.sqrt(x * x + y * y + z * z)
			local r = math.min(reach, length / 2) / length
			return { p[1] + x * r, p[2] + y * r, p[3] + z * r }
		end
		local first, last = towards(a), towards(b)
		for s = 0, steps do
			local t = s / steps
			local m0, m1, m2 = (1 - t) ^ 2, 2 * t * (1 - t), t * t
			table.insert(path, {
				first[1] * m0 + p[1] * m1 + last[1] * m2,
				first[2] * m0 + p[2] * m1 + last[2] * m2,
				first[3] * m0 + p[3] * m1 + last[3] * m2,
			})
		end
	end
	table.insert(path, points[#points])
	return path
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

-- Weathering colors, in sRGB. The bake paints the wear itself, stroke by
-- stroke: rust patches, drips, grime and scratches on metal, dust and scuffs
-- on rubber. These are for parts made of the stuff.
local RUST_DARK = { 0.3, 0.2, 0.12 }
local RUST_ORANGE = { 0.62, 0.36, 0.15 }
local RUST_FLAKE = { 0.78, 0.52, 0.3 }
local BARE_METAL = { 0.74, 0.73, 0.7 }

-- How rusty a part painted by its own paint fn is; `rusting` sets it.
local paintRust = setmetatable({}, { __mode = "k" })

-- Marks a paint fn as `rust` worn (0 clean, 1 eaten through), for parts
-- whose coat has its own look but should still rust.
local function rusting(rust, paint)
	paintRust[paint] = rust
	return paint
end

local RUBBER = -1
local DUST = { 0.55, 0.5, 0.42 }
-- Bindings, painted as RUBBER: duct tape and hemp rope.
local TAPE = { 0.58, 0.58, 0.56 }
local RUBBER_BLACK = { 0.12, 0.12, 0.13 }
local ROPE = { 0.62, 0.5, 0.32 }

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

local parts = {}

-- What the bake paints on a part: `paint` gives its coat colors, `rust` how
-- worn it is, and `rubber` that it gathers dust and scuffs instead.
local function setLook(entry, color, rust)
	rust = rust or 0.4
	if type(rust) == "function" then
		entry.paint, entry.rust, entry.custom = rust, paintRust[rust] or 0, true
		return
	end
	entry.paint = function()
		return color[1], color[2], color[3]
	end
	entry.rust = math.max(rust, 0)
	entry.rubber = rust == RUBBER
end

local HAND_EDGE_MOTION = { rock = "feather", wood = "flick", metal = "worn" }

-- `rust` can also be a paint fn for surfaces with their own look.
-- `texture` overrides the texture size for parts that need more detail.
-- `emissive` is a glow strength (like SurfaceAppearance.EmissiveStrength);
-- glowing parts skip painted shading. `flat` skips the warp, for parts so
-- thin it would visibly bend them. `edge` is how far highlights and contact
-- shadows reach from an edge, in studs: bigger surfaces take a wider band.
-- `shade` multiplies the contact shadow strength, for parts that should sit in
-- heavier shadow than the standard wear. `lit` scales the highlight strength
-- and `wide` the width of the highlight brush strokes. Set `painted` on an entry
-- to paint its highlights as bold, fully loaded strokes instead of dry ones,
-- `blend` (0-1) to tint them from cream toward a lighter part colour, and
-- `taper` (studs) to run them full width at corners, thinning along each edge.
-- `softLit` (0-1) adds a wide, very soft highlight under the strokes, fading
-- out over `softEdge` studs from each edge; `softUneven` (0-1) makes its width
-- wander along the edge and `softTaper` (studs) thins it away from corners.
-- `softToZero` lets that thinning reach nothing, and `softPower` steepens the fade.
-- `strokes` lists brush strokes painted over the coat ({start, along, normal,
-- length, width, tail, color, brush}, color in sRGB), such as cracks or dabs;
-- `brush` is "taper" (crisp lines, the default), "round" or "sponge".
-- `stamps` lays the coat with scanned stroke shapes instead of the flat brush.
-- `hand` ("rock", "wood" or "metal") paints the coat the way a hand would, and
-- `handFocus` ({x, y, z, radius}) is where it gathers its finest strokes.
-- `handTune` sets any of its numbers by name (settings! in tools/modelkit/src/hand.rs).
-- `litMotion` draws the hard edge highlight with a moving hand, `litTune` sets its
-- numbers by name (tools/modelkit/src/marks.rs). A hand-painted part gets its
-- material's motion unless it names another, or `false` for the default strokes.
-- `brushes` draws any layer with a motion: edge, shade, soft, coat, grime, rust,
-- drip or scratch, each {motion = "press", tune = {name = value}}. A `strokes`
-- entry takes `motion` and `tune` the same way.
-- With `hand` as well, `crisp` keeps the shapes exact and takes only the brushwork's tone.
-- `crisp` lays the coat on texel by texel in the paint fn's exact colours
-- instead of brush strokes, for machine finishes (hazard tape, ribbed
-- rubber) that strokes would smear; shading still goes over it.
local function part(name, bone, color, build, smooth, rust, texture: number?, emissive: number?, flat: boolean?, edge: number?, shade: number?, lit: number?, wide: number?)
	local mesh = Mesh.new()
	build(if rust == 0 or flat then mesh else imperfect(mesh, name))
	mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
	local fit = mesh:unwrap()
	local size = if texture then texture
		elseif texelDensity then math.clamp(math.ceil(texelDensity / fit / 4) * 4, 16, 1024)
		else TEXTURE
	local image = Image.new(size, size, color[1], color[2], color[3])
	local entry = { name = name, bone = bone, mesh = mesh, image = image, emissive = emissive, edge = edge, shade = shade, lit = lit, wide = wide }
	setLook(entry, color, rust)
	-- Glowing parts skip the painted bake, so their colors go on as they are.
	if emissive then
		mesh:paint(image, entry.paint)
	end
	table.insert(parts, entry)
end

-- Large surfaces (terrain, roads, floors) are split into cubes 128 studs
-- across, or 1024 texels at the layout's texel density if that is smaller,
-- each its own part with a texture up to 1024, named <name>_<cx>_<cy>_<cz>. The
-- build runs once into a recorder, then each face goes to the chunk holding
-- its centre. Cells sit on the origin across, and centred on z = 0 up and
-- down, so ground near sea level stays in one layer. `flat` skips the warp,
-- as for part(). Every chunk shades against one height range, the whole
-- mesh's z-range or the `heightRange` {bottom, top} given, so the gradient runs
-- on across chunks instead of restarting in each (a flat chunk would go dark).
local function chunkedPart(name, bone, color, build, smooth, rust, flat: boolean?, edge: number?, shade: number?, lit: number?, heightRange: { number }?)
	local CHUNK = if layoutDensity then math.min(128, 1024 / layoutDensity) else 128
	-- Smallest cell a chunk is halved down to while looking for a split.
	local MIN_CELL = 2
	local positions, faces = {}, {}
	local recorder = {
		vertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		-- A vertex the rust wobble leaves alone, for surfaces that must stay flat.
		exactVertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		face = function(_, verts, uvs)
			table.insert(faces, { verts = verts, uvs = uvs })
		end,
	}
	build(if rust == 0 or flat then recorder else imperfect(recorder, name))
	if not heightRange then
		local bottom, top = math.huge, -math.huge
		for _, p in positions do
			bottom, top = math.min(bottom, p[3]), math.max(top, p[3])
		end
		heightRange = { bottom, top }
	end

	local chunks, order = {}, {}
	for _, f in faces do
		local cx, cy, cz = 0, 0, 0
		for _, v in f.verts do
			local p = positions[v]
			cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
		end
		local n = #f.verts
		local key = `{math.floor(cx / n / CHUNK)}_{math.floor(cy / n / CHUNK)}_{math.floor(cz / n / CHUNK + 0.5)}`
		if not chunks[key] then
			chunks[key] = {}
			table.insert(order, key)
		end
		table.insert(chunks[key], f)
	end

	-- Each chunk becomes a part. With a texel density set, a chunk whose
	-- texture would need more than 1024 texels to hold it is split into
	-- octants until every piece fits, so the whole surface reads at one density.
	local function chunkMesh(chunkFaces)
		local mesh, remap = Mesh.new(), {}
		for _, f in chunkFaces do
			local verts = {}
			for i, v in f.verts do
				if not remap[v] then
					local p = positions[v]
					remap[v] = mesh:vertex(p[1], p[2], p[3])
				end
				verts[i] = remap[v]
			end
			mesh:face(verts, f.uvs)
		end
		return mesh
	end
	local function emit(label, chunkFaces, size)
		local texture = 1024
		if texelDensity then
			local mesh = chunkMesh(chunkFaces)
			mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
			-- Split by the layout's density; the scale only sizes the texture.
			local unwrap = mesh:unwrap()
			local needed = math.ceil((layoutDensity or texelDensity) / unwrap / 4) * 4
			if needed > 1024 and #chunkFaces > 1 then
				local half = size / 2
				local octants, octantOrder = {}, {}
				for _, f in chunkFaces do
					local cx, cy, cz = 0, 0, 0
					for _, v in f.verts do
						local p = positions[v]
						cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
					end
					local n = #f.verts
					local sub = `{math.floor(cx / n / half) % 2}{math.floor(cy / n / half) % 2}{math.floor(cz / n / half + 0.5) % 2}`
					if not octants[sub] then
						octants[sub] = {}
						table.insert(octantOrder, sub)
					end
					table.insert(octants[sub], f)
				end
				if #octantOrder > 1 then
					for _, sub in octantOrder do
						emit(`{label}_{sub}`, octants[sub], half)
					end
					return
				end
				-- Everything sits in one octant, such as a curved strip whose
				-- unwrap leaves most of the texture empty: halve the cell again
				-- until the faces part.
				if half >= MIN_CELL then
					emit(label, chunkFaces, half)
					return
				end
			end
			texture = math.clamp(math.ceil(texelDensity / unwrap / 4) * 4, 16, 1024)
		end
		part(label, bone, color, function(mesh)
			local handles = {}
			for _, f in chunkFaces do
				local verts = {}
				for i, v in f.verts do
					if not handles[v] then
						local p = positions[v]
						handles[v] = mesh:vertex(p[1], p[2], p[3])
					end
					verts[i] = handles[v]
				end
				mesh:face(verts, f.uvs)
			end
			-- The recorder hands over a triangle soup; weld so the crease angle
			-- can run smooth over a chunk instead of faceting every triangle.
			mesh:weld(1e-4)
		end, smooth, 0, texture, nil, nil, edge, shade, lit)
		-- The warp was applied while recording; the chunk still wears the look.
		setLook(parts[#parts], color, rust)
		-- Chunks of one part share a group, so their edges count as its own.
		parts[#parts].group = name
		parts[#parts].heightRange = heightRange
	end
	for _, key in order do
		emit(`{name}_{key}`, chunks[key], CHUNK)
	end
end

-- Shades every part with all the others as occluders, so parts darken where
-- they touch or tuck under each other, then adds them to the model.
local function finishParts()
	for _, entry in parts do
		if entry.emissive then
			model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true, emissive = entry.emissive })
			continue
		end
		local occluders, group = {}, {}
		for _, other in parts do
			if other ~= entry and entry.group and other.group == entry.group then
				table.insert(group, other.mesh)
			elseif other ~= entry then
				table.insert(occluders, other.mesh)
			end
		end
		entry.mesh:paintShading(entry.image, {
			highlight = EDGE_HIGHLIGHT * (entry.lit or 1),
			shadow = CONTACT_SHADOW * (entry.shade or 1),
			gradient = GRADIENT,
			blend = entry.blend or EDGE_BLEND,
			occluders = occluders,
			group = group,
			name = entry.name,
			paint = entry.paint,
			-- A custom paint fn is cached under the item's key, since its code is not hashed.
			custom = entry.custom,
			salt = if entry.custom then CACHE_KEY else nil,
			rust = entry.rust * WEAR,
			stamps = entry.stamps,
			hand = entry.hand,
			handFocus = entry.handFocus,
			handTune = entry.handTune,
			rubber = entry.rubber,
			reach = entry.edge,
			highlightWidth = entry.wide,
			highlightUneven = entry.litUneven,
			highlightUnevenStep = entry.litUnevenStep,
			highlightMotion = if entry.litMotion == nil then (entry.hand and HAND_EDGE_MOTION[entry.hand]) else (entry.litMotion or nil),
			highlightMotionTune = entry.litTune,
			highlightToZero = entry.litToZero,
			highlightEnd = entry.litEnd,
			paintedHighlights = entry.painted,
			cornerTaper = entry.taper,
			softHighlight = entry.softLit,
			softReach = entry.softEdge,
			softUneven = entry.softUneven,
			softTaper = entry.softTaper,
			softToZero = entry.softToZero,
			softPower = entry.softPower,
			softEnd = entry.softEnd,
			strokes = entry.strokes,
			brushes = entry.brushes,
			heightRange = entry.heightRange,
			crisp = entry.crisp,
		})
		model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true })
	end
end
-- Belt Crossing: a footbridge over the capsule belt, with stairs both ways
-- (art/concepts/town-pieces-sketch.png, plan in BeltCrossing.plan.luau). Local x
-- runs across the belt, whose middle is at x = 0. A riding capsule reaches 4.0
-- and the deck's underside is at 4.75.
-- The hand-painted finish for a model's parts: `coats` names a part's hand coat
-- ("metal", "wood" or "rock"), `plain` lists parts left alone, such as lamps. A
-- crisp part with a hand coat keeps its exact shapes and takes only the
-- brushwork's tone. Call it just before finishParts().
local SMALL_MARKS = {
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

local function handFinish(coats, plain)
	for _, entry in parts do
		if plain[entry.name] then
			continue
		end
		entry.hand = coats[entry.name]
		if entry.hand == nil then
			entry.litMotion = "worn"
		elseif entry.hand == "metal" then
			entry.handTune = SMALL_MARKS
		end
		entry.softLit, entry.softEdge, entry.softUneven, entry.softTaper = 0.25, 0.22, 0, 0.8
		entry.softToZero, entry.softPower = true, 2
		entry.taper = entry.taper or 0.5
		entry.litToZero, entry.litUneven, entry.litUnevenStep = true, 0.6, 0.5
		entry.brushes = { shade = { motion = "feather", tune = { width = 0.02 } } }
	end
end
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
useTexelDensity(32)

local STEEL = { 0.44, 0.5, 0.56 }
local TREAD = { 0.36, 0.38, 0.41 }
local CHEQUER = { 0.5, 0.53, 0.57 }
local SEAM = { 0.15, 0.16, 0.19 }
local YELLOW = { 0.86, 0.66, 0.18 }
local PIPE = { 0.23, 0.24, 0.28 }

local SPAN_HALF, HALF_WIDE = 3.5, 4
local UNDERSIDE, DECK_TOP = 4.75, 5.25
local FLIGHT, STEPS = 7, 10
local RAIL_Y, DECK_RAIL, STAIR_RAIL = 3.8, 3.2, 2.8
local LEG_X, LEG_Y, BEAM_DEEP = 3.7, 3.5, 0.5
local GOING = FLIGHT / STEPS

-- Raised diamonds on a chequer plate.
local function onChequer(u: number, v: number): boolean
	local size = 0.34
	local fu, fv = (u / size) % 2, (v / size) % 2
	local cellU, cellV = math.floor(fu), math.floor(fv)
	local a, b = math.abs(fu - cellU - 0.5), math.abs(fv - cellV - 0.5)
	if (cellU + cellV) % 2 == 0 then
		return a < 0.4 and b < 0.14
	end
	return a < 0.14 and b < 0.4
end

part("Span", nil, STEEL, function(mesh)
	box(mesh, 0, 0, UNDERSIDE, SPAN_HALF * 2, HALF_WIDE * 2, DECK_TOP - UNDERSIDE)
	-- A splice bearer under the join, clear of riding capsules.
	box(mesh, 0, 0, UNDERSIDE - 0.2, 1, 7.8, 0.22)
	-- Cross stiffeners and edge beams, the lowest at 4.5.
	for _, x in { -1.9, 1.9 } do
		box(mesh, x, 0, UNDERSIDE - 0.24, 0.3, 7.8, 0.26)
	end
	for _, y in { -3.8, 3.8 } do
		box(mesh, 0, y, UNDERSIDE - 0.24, 6.8, 0.3, 0.26)
	end
	-- Shallow ribs across the middle, and the frames of the two deck plates.
	for _, y in { -2.4, -1, 1, 2.4 } do
		box(mesh, 0, y, UNDERSIDE - 0.2, 6.4, 0.2, 0.22)
	end
	box(mesh, -1.8, 1.4, UNDERSIDE - 0.1, 1.7, 1.4, 0.12)
	box(mesh, 1.3, -0.7, UNDERSIDE - 0.1, 2.2, 1.8, 0.12)
	for y = -3.4, 3.4, 1.7 do
		for _, x in { -3.1, 0.22, 3.1 } do
			bolt(mesh, x, y, DECK_TOP, "z", 0.08)
		end
	end
end, nil, function(x, y, z)
	if z < DECK_TOP - 0.1 then
		return STEEL[1], STEEL[2], STEEL[3]
	end
	if math.abs(x) < 0.05 then
		return SEAM[1], SEAM[2], SEAM[3]
	end
	-- Worn bright along the walked line from one stair head to the other.
	local walked = math.abs(y) < 2.1 and math.noise(x * 1.8, y * 2.4, 2) + (2.1 - math.abs(y)) * 0.22 > 0.3
	if onChequer(x, y) then
		if walked then
			return 0.62, 0.64, 0.66
		end
		return CHEQUER[1], CHEQUER[2], CHEQUER[3]
	end
	if walked then
		return 0.46, 0.48, 0.51
	end
	return TREAD[1], TREAD[2], TREAD[3]
end)
parts[#parts].crisp = true

part("Stairs", nil, TREAD, function(mesh)
	local rise = DECK_TOP / STEPS
	for _, side in { -1, 1 } do
		for step = 1, STEPS do
			local x = side * (SPAN_HALF + FLIGHT - (step - 0.5) * GOING)
			box(mesh, x, 0, rise * step - 0.2, GOING, HALF_WIDE * 2 - 0.3, 0.2)
		end
		for _, y in { -3.9, 3.9 } do
			strut(mesh, side * (SPAN_HALF + FLIGHT), y, 0, side * SPAN_HALF, y, DECK_TOP - 0.1, 0.22)
			-- A bolted foot, and a bracket onto the deck edge.
			box(mesh, side * (SPAN_HALF + FLIGHT - 0.15), y, 0, 0.9, 0.5, 0.1)
			box(mesh, side * (SPAN_HALF + 0.05), y, DECK_TOP - 0.75, 0.4, 0.34, 0.6)
		end
	end
end, nil, function(x, y, z)
	if math.abs(y) > 3.72 then
		return TREAD[1], TREAD[2], TREAD[3]
	end
	-- The treads' undersides are bare, darker steel.
	local phase = z % (DECK_TOP / STEPS)
	if phase > 0.14 and phase < 0.42 then
		return 0.24, 0.25, 0.28
	end
	-- Yellow painted nosing along each tread, worn through where feet land.
	local along = (math.abs(x) - SPAN_HALF) % GOING
	if along > GOING - 0.16 or along < 0.02 then
		local worn = math.abs(y) < 2.3 and math.noise(x * 4, y * 2.5, 3) + (2.3 - math.abs(y)) * 0.18 > 0.15
		if worn then
			return 0.58, 0.6, 0.63
		end
		return YELLOW[1], YELLOW[2], YELLOW[3]
	end
	if onChequer(x, y) then
		return CHEQUER[1], CHEQUER[2], CHEQUER[3]
	end
	return TREAD[1], TREAD[2], TREAD[3]
end)
parts[#parts].crisp = true

part("Railings", nil, PIPE, function(mesh)
	local outer = SPAN_HALF + FLIGHT
	-- The rail's height at a point along it, and the floor beneath it.
	local function floorAt(x: number): number
		local out = math.abs(x)
		return if out <= SPAN_HALF then DECK_TOP else DECK_TOP * (1 - (out - SPAN_HALF) / FLIGHT)
	end
	for _, y in { -RAIL_Y, RAIL_Y } do
		for _, share in { 1, 0.52 } do
			local points = {
				{ -outer, y, STAIR_RAIL * share },
				{ -SPAN_HALF, y, DECK_TOP + DECK_RAIL * share },
				{ SPAN_HALF, y, DECK_TOP + DECK_RAIL * share },
				{ outer, y, STAIR_RAIL * share },
			}
			tube(mesh, roundedPath(points, 0.5, 3), if share == 1 then 0.1 else 0.06, 8)
		end
		for _, side in { -1, 1 } do
			for k = 0, 3 do
				local x = side * (SPAN_HALF + FLIGHT * k / 3)
				local floor = floorAt(x)
				local high = STAIR_RAIL + (DECK_RAIL - STAIR_RAIL) * (1 - k / 3)
				local thick = if k == 0 then 0.2 else 0.12
				box(mesh, x, y, floor - 0.02, thick, thick, high)
			end
		end
	end
end, nil, 0.1)

part("Legs", nil, PIPE, function(mesh)
	for _, x in { -LEG_X, LEG_X } do
		for _, y in { -LEG_Y, LEG_Y } do
			box(mesh, x + math.sign(x) * 0.15, y, 0, 1, 1.3, 0.12)
			for _, cx in { -0.3, 0.6 } do
				for _, cy in { -0.48, 0.48 } do
					bolt(mesh, x + math.sign(x) * cx, y + cy, 0.12, "z", 0.08)
				end
			end
			box(mesh, x, y, 0.1, 0.6, 0.6, UNDERSIDE - BEAM_DEEP - 0.08)
			strut(mesh, x, y, UNDERSIDE - BEAM_DEEP - 0.9, x, y - math.sign(y) * 0.9, UNDERSIDE - BEAM_DEEP - 0.02, 0.16)
		end
		-- A beam across each pair of legs carries the deck edge and the stair
		-- head, and a brace between the legs stops them racking.
		box(mesh, x, 0, UNDERSIDE - BEAM_DEEP, 0.72, 7.9, BEAM_DEEP + 0.02)
		strut(mesh, x, -LEG_Y, 0.6, x, LEG_Y, UNDERSIDE - BEAM_DEEP - 0.1, 0.16)
	end
end, nil, function(_x, y, z)
	-- Hazard bands round the feet, where a capsule might clip them.
	if z < 1.4 and z > 0.13 and math.abs(y) > 2.9 then
		if (z + y) % 0.7 < 0.35 then
			return 0.08, 0.08, 0.09
		end
		return 0.86, 0.66, 0.18
	end
	return PIPE[1], PIPE[2], PIPE[3]
end)
parts[#parts].crisp = true

-- The lived-in layer: kick plates, a cable tray under the deck, a warning sign
-- and lamps at the deck corners.
part("Fittings", nil, { 0.3, 0.32, 0.36 }, function(mesh)
	for _, y in { -3.68, 3.68 } do
		box(mesh, 0, y, DECK_TOP, SPAN_HALF * 2, 0.1, 0.32)
	end
	-- A cable tray along the deck's underside, clear of riding capsules.
	box(mesh, 2.6, 0, UNDERSIDE - 0.22, 0.6, 7.6, 0.24)
	cylinder(mesh, 2.6, 0, UNDERSIDE - 0.12, 0.09, 7.6, "y", 6)
	-- A junction box on one leg, with conduit up to the deck and out to both
	-- lamp posts, and one patched tread plate.
	box(mesh, LEG_X, -LEG_Y + 0.56, 2.1, 0.5, 0.5, 0.8)
	cylinder(mesh, LEG_X, -LEG_Y + 0.56, 3.6, 0.07, 2.2, "z", 6)
	cylinder(mesh, 0, 3.66, DECK_TOP + 0.5, 0.06, 7, "x", 6)
	cylinder(mesh, 0, -3.66, DECK_TOP + 0.5, 0.06, 7, "x", 6)
	box(mesh, -1.8, 1.4, DECK_TOP, 1.5, 1.2, 0.05)
	for _, cx in { -0.6, 0.6 } do
		for _, cy in { -0.45, 0.45 } do
			bolt(mesh, -1.8 + cx, 1.4 + cy, DECK_TOP + 0.05, "z", 0.08)
		end
	end
	-- A welded repair in the walked lane, and stiffeners along each fascia.
	box(mesh, 1.3, -0.7, DECK_TOP, 2, 1.6, 0.04)
	for _, y in { -4.05, 4.05 } do
		for x = -3, 3, 1.5 do
			box(mesh, x, y, UNDERSIDE - 0.02, 0.18, 0.14, 0.54)
		end
		box(mesh, 0, y, UNDERSIDE + 0.2, 6.8, 0.14, 0.14)
	end
	cylinder(mesh, -2.6, 0, UNDERSIDE - 0.16, 0.08, 7.6, "y", 6)
	-- Clamps holding the warning sign to the mid rail.
	for _, x in { -1.2, 1.2 } do
		box(mesh, x, -RAIL_Y - 0.1, DECK_TOP + 1.55, 0.3, 0.3, 0.4)
	end
	-- Lamp posts on two deck corners.
	for _, x in { -SPAN_HALF, SPAN_HALF } do
		cylinder(mesh, x, x * 1.086, DECK_TOP + 2.3, 0.1, 4.6, "z", 6)
		cylinder(mesh, x, x * 1.086, DECK_TOP + 0.12, 0.2, 0.24, "z", 8)
		box(mesh, x, x * 1.086, DECK_TOP + 4.6, 0.7, 0.7, 0.14)
		box(mesh, x, x * 1.086, DECK_TOP + 5.36, 0.7, 0.7, 0.14)
		for _, cx in { -0.3, 0.3 } do
			box(mesh, x + cx, x * 1.086 + cx, DECK_TOP + 4.7, 0.06, 0.06, 0.7)
		end
	end
end, nil, 0.1)

part("WarningSign", nil, YELLOW, function(mesh)
	box(mesh, 0, -RAIL_Y - 0.12, DECK_TOP + 1.3, 3, 0.1, 1.1)
end, nil, function(x, y, z)
	-- A printed warning triangle with its bar and dot, on the front only.
	if y > -RAIL_Y - 0.1 then
		return 0.44, 0.46, 0.5
	end
	local v = z - (DECK_TOP + 1.42)
	local inside = v > 0 and v < 0.86 and math.abs(x) < 0.5 * (1 - v / 0.86)
	local outer = v > -0.06 and v < 0.96 and math.abs(x) < 0.62 * (1 - (v + 0.06) / 1.02)
	if outer and not inside then
		return 0.08, 0.08, 0.09
	end
	if inside and math.abs(x) < 0.06 and ((v > 0.28 and v < 0.62) or (v > 0.12 and v < 0.22)) then
		return 0.08, 0.08, 0.09
	end
	return YELLOW[1], YELLOW[2], YELLOW[3]
end)
parts[#parts].crisp = true


part("Bulbs", nil, { 1, 0.84, 0.48 }, function(mesh)
	for _, x in { -SPAN_HALF, SPAN_HALF } do
		cylinder(mesh, x, x * 1.086, DECK_TOP + 5.05, 0.26, 0.62, "z", 10)
	end
end, true, 0, nil, 0.9)

handFinish({ Fittings = "metal", Span = "metal", Railings = "metal", Legs = "metal", Stairs = "metal" }, { WarningSign = true, Bulbs = true })

finishParts()
