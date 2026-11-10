local CACHE_KEY = "HubShop-d28bf4508d6bb561"
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
			gradient = entry.gradient or GRADIENT,
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
			rustEdges = entry.rustEdges,
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
-- Hub Shop: the town's shop, salvaged containers stacked behind a long counter
-- (art/concepts/town-pieces-sketch.png, plan in HubShop.plan.luau). Local -y is
-- the front, toward the middle of the town.
-- The hand-painted finish for a model's parts: `coats` names a part's hand coat
-- ("metal", "wood" or "rock"), `plain` lists parts left alone, such as lamps. A
-- crisp part with a hand coat keeps its exact shapes and takes only the
-- brushwork's tone. `finish` maps coat names and part names to a preset below,
-- for props standing alone on open ground; the town models leave it nil.
-- Call it just before finishParts().
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

-- One preset per material, so tuning concrete never moves steel. A number a
-- model set on the part before handFinish wins over the preset's. `bands`
-- paints the stepped gradient: `steps` (default by height), `drop` (how dark
-- the lowest step goes), `top` (the top step's brightness), `facing` (loose
-- pieces each lit from above) and `stain` (how far a short part's steps wander
-- as blotches instead of bands; high values fleck a dark surface).
local PRESETS = {
	-- Steel standing alone on open ground.
	propMetal = { gradient = 0.2, shade = 2, rustEdges = true, edge = 0.3, lit = 1.6, litUneven = 0.85, bands = { drop = 0.48, top = 1 } },
	-- Concrete footings and plinths.
	propConcrete = { gradient = 0.4, shade = 2, rustEdges = true, edge = 0.3, lit = 1.28, litUneven = 0.85, bands = { drop = 0.48, top = 1 } },
	-- Stones on the map, banded from the turf up by the bandDepth the layout gives them.
	rock = { gradient = 0.4, shade = 1, rustEdges = true, edge = 0.3, lit = 1.28, litUneven = 0.85, bands = { steps = 4, drop = 0.32, top = 1 } },
	-- Loose pieces lying on a heap, each banded on its own from the model's bandPieces.
	heapPiece = { gradient = 0.2, shade = 1.4, rustEdges = true, edge = 0.3, lit = 1.8, litUneven = 0.85, bands = { steps = 4, drop = 0.58, top = 1, facing = true } },
	-- The earth body of a heap: it darkens well under everything resting on it.
	heapBody = { gradient = 0.4, shade = 1.8, rustEdges = true, edge = 0.45, lit = 1.0, litUneven = 0.85, softLit = 0, bands = { drop = 0.48, top = 1, stain = 0.08 } },
}
-- The finish most props take.
local PROP_FINISH = { metal = "propMetal", rock = "propConcrete" }

-- Light at the top, stepping down to dark and cool at the base. The hand coat
-- samples this per stroke, so each step's edge comes out brushed, not ruled.
local function paintStepBands(entry, bands)
	if entry.crisp and not entry.bandCrisp then
		return
	end
	-- The part's height range, read off a scratch paint of its surface.
	local low, high = math.huge, -math.huge
	entry.mesh:paint(Image.new(32, 32), function(_x, _y, z)
		low, high = math.min(low, z), math.max(high, z)
		return 0, 0, 0
	end)
	if high - low < 0.25 then
		return
	end
	-- Loose pieces listed as { x, y, z, radius } each band from their own top to
	-- their own foot, instead of all sharing the part's height.
	if entry.bandPieces then
		local pieces = entry.bandPieces
		entry.bandDepth = function(x: number, y: number, z: number): number
			local nearest, best = pieces[1], math.huge
			for _, piece in pieces do
				local d = (x - piece[1]) ^ 2 + (y - piece[2]) ^ 2 + (z - piece[3]) ^ 2
				if d < best then
					nearest, best = piece, d
				end
			end
			return 1 - math.clamp((z - nearest[3] + nearest[4]) / (2 * nearest[4]), 0, 1)
		end
	end
	-- Tall parts get more steps, so any stretch of them shows some.
	local steps = bands.steps or math.clamp(math.round((high - low) / 1.5), 4, 8)
	local drop, top = bands.drop, bands.top
	local paint = entry.paint
	entry.custom = true
	entry.paint = function(x: number, y: number, z: number, nx: number, ny: number, nz: number)
		local r, g, b = paint(x, y, z, nx, ny, nz)
		local depth = if entry.bandDepth then entry.bandDepth(x, y, z) else 1 - (z - low) / (high - low)
		if bands.facing then
			depth = depth * 0.3 + (1 - nz) * 0.35
		end
		depth += 0.07 * math.noise(x * 0.7, y * 0.7, z * 0.35)
		-- A short part has no height to band, so it stains in steps instead.
		if high - low < 1.5 then
			depth += (bands.stain or 0.4) * math.noise(x * 0.5, y * 0.5, z * 0.3)
		end
		local step = math.clamp(math.floor(depth * steps), 0, steps - 1) / (steps - 1)
		-- A small lift at the top, so near-black paint still shows its steps.
		local lift = (1 - step) * 0.22 * (1 - math.max(r, g, b)) ^ 2
		return r * (top - drop * step) + lift, g * (top - (drop + 0.02) * step) + lift, b * (top - (drop - 0.08) * step) + lift
	end
end

local function applyPreset(entry, preset)
	entry.gradient = entry.gradient or preset.gradient
	entry.shade = entry.shade or preset.shade
	entry.edge = entry.edge or preset.edge
	entry.lit = entry.lit or preset.lit
	entry.litUneven = preset.litUneven
	if entry.rustEdges == nil then
		entry.rustEdges = preset.rustEdges
	end
	-- Earth has no edge for the soft highlight to glow along; it flecks the rim.
	if preset.softLit then
		entry.softLit = preset.softLit
	end
	entry.handTune = SMALL_MARKS
	paintStepBands(entry, preset.bands)
end

local function handFinish(coats, plain, finish)
	for _, entry in parts do
		-- A chunked part takes the coat of the name it was built under.
		local name = string.match(entry.name, "^(.-)_%-?%d+_%-?%d+_%-?%d+$") or entry.name
		if plain[name] then
			continue
		end
		entry.hand = coats[name]
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
		local presetName = finish and (finish[name] or finish[entry.hand])
		if presetName then
			applyPreset(entry, PRESETS[presetName] or error(`no finish preset {presetName}`))
		end
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
-- A mesh that moves every vertex built into it through `move`, for tilting,
-- turning or crumpling simple shapes.
local function warped(mesh, move)
	return {
		vertex = function(_self, x: number, y: number, z: number)
			local a, b, c = move(x, y, z)
			return mesh:vertex(a, b, c)
		end,
		face = function(_self, face)
			return mesh:face(face)
		end,
	}
end
useTexelDensity(32)

local CONCRETE = { 0.56, 0.54, 0.5 }
local CONTAINER_BLUE = { 0.27, 0.42, 0.52 }
local CONTAINER_RUST = { 0.62, 0.36, 0.19 }
local PLANK = { 0.5, 0.36, 0.22 }
local DRUM = { 0.25, 0.27, 0.3 }
local TIN = { 0.44, 0.5, 0.56 }
local PATCH = { 0.38, 0.42, 0.46 }
local PIPE = { 0.23, 0.24, 0.28 }
local YELLOW = { 0.86, 0.66, 0.18 }
local DARK = { 0.1, 0.1, 0.12 }
local WEIGHT = { 0.3, 0.31, 0.33 }

local FLOOR = 0.8
local LOWER_TOP = 8.8
local UPPER_TOP = 16.8
-- The container's roof sits just below its frame's top rail.
local ROOF_TOP = UPPER_TOP - 0.12
local COUNTER_Y = -3.6
local POST_Y = -9.65
-- The awning falls toward the front from its ledger on the containers.
local AWNING_REAR, AWNING_Z, AWNING_FALL = -1.1, 9.05, 0.05
-- Negative toward the front, so rain runs off away from the containers.
local function awningDrop(y: number): number
	return (y - AWNING_REAR) * AWNING_FALL
end

-- Pressed trapezoid ribs along a wall, stopping short of the corner posts.
local function ribsAlongX(mesh, x0, x1, y, z, height)
	for x = x0, x1, 0.6 do
		box(mesh, x, y, z, 0.3, 0.14, height)
	end
end
local function ribsAlongY(mesh, x, y0, y1, z, height)
	for y = y0, y1, 0.6 do
		box(mesh, x, y, z, 0.14, 0.3, height)
	end
end
-- A container's steel frame: corner posts, and rails round the top and bottom.
local function containerFrame(mesh, x0, x1, y0, y1, z0, z1)
	for _, x in { x0, x1 } do
		for _, y in { y0, y1 } do
			box(mesh, x, y, z0, 0.62, 0.62, z1 - z0)
		end
	end
	for _, z in { z0, z1 - 0.34 } do
		for _, y in { y0, y1 } do
			box(mesh, (x0 + x1) / 2, y, z, x1 - x0 - 0.4, 0.5, 0.34)
		end
		for _, x in { x0, x1 } do
			box(mesh, x, (y0 + y1) / 2, z, 0.5, y1 - y0 - 0.4, 0.34)
		end
	end
end

part("Slab", nil, CONCRETE, function(mesh)
	box(mesh, 0, 0, 0, 34, 20, FLOOR)
end, nil, 0.15)

part("LowerContainers", nil, CONTAINER_BLUE, function(mesh)
	-- Two units welded end to end, open at the front.
	box(mesh, 0, 3.9, FLOOR, 29, 9.7, 0.3)
	box(mesh, 0, 8.8, FLOOR + 0.2, 29.4, 0.3, 7.3)
	box(mesh, 0, 4, LOWER_TOP - 0.4, 29.6, 9.6, 0.3)
	box(mesh, 0, 4, FLOOR + 0.2, 0.3, 9.4, 7.3)
	for _, side in { -1, 1 } do
		box(mesh, side * 14.75, 4, FLOOR + 0.2, 0.3, 9.4, 7.3)
		ribsAlongY(mesh, side * 15.0, -0.2, 8.2, FLOOR + 0.4, 7)
		containerFrame(mesh, math.min(side * 0.42, side * 15), math.max(side * 0.42, side * 15), -0.75, 8.75, FLOOR, LOWER_TOP)
	end
	ribsAlongX(mesh, -14.2, -0.8, 9.0, FLOOR + 0.4, 7)
	ribsAlongX(mesh, 0.8, 14.2, 9.0, FLOOR + 0.4, 7)
end, nil, 0.04)

part("Shelves", nil, PIPE, function(mesh)
	for _, side in { -1, 1 } do
		for z = 2.6, 6.2, 1.8 do
			box(mesh, side * 7.5, 7.9, z, 13, 1.4, 0.15)
		end
		for _, x in { 1.4, 13.6 } do
			box(mesh, side * x, 7.3, FLOOR + 0.3, 0.2, 0.2, 7)
		end
	end
end, nil, 0.1)

-- Salvage on the shelves, in clusters with gaps: x, shelf, kind.
local STOCK = {
	{ -13.2, 1, "drum" }, { -12, 1, "drum" }, { -9.2, 1, "crate" }, { -3.4, 1, "cog" }, { 3, 1, "crate" }, { 4.3, 1, "crate" }, { 10.5, 1, "pipe" }, { 13, 1, "drum" },
	{ -11.8, 2, "cog" }, { -10.4, 2, "cog" }, { -5, 2, "pipe" }, { -2.2, 2, "crate" }, { 7.4, 2, "drum" }, { 8.6, 2, "drum" }, { 9.9, 2, "crate" },
	{ -13, 3, "crate" }, { -7.8, 3, "drum" }, { -2.6, 3, "cog" }, { 2.6, 3, "pipe" }, { 12.2, 3, "cog" },
	{ -7.8, 1, "cog" }, { -5.9, 1, "crate" }, { 6, 1, "drum" }, { 7.2, 1, "drum" }, { 12, 1, "crate" },
	{ -8, 2, "crate" }, { 2.2, 2, "cog" }, { 4, 2, "cog" }, { 11.6, 2, "pipe" },
	{ -11.6, 3, "cog" }, { -6.2, 3, "drum" }, { 5.4, 3, "crate" }, { 7, 3, "crate" }, { 9.6, 3, "drum" },
}
local SHELF_Z = { 2.75, 4.55, 6.35 }
local STOCK_TONES = { { 0.76, 0.58, 0.2 }, { 0.6, 0.34, 0.2 }, { 0.52, 0.56, 0.6 }, { 0.3, 0.46, 0.34 } }

part("ShelfStock", nil, YELLOW, function(mesh)
	for _, item in STOCK do
		local x, z = item[1], SHELF_Z[item[2]]
		if item[3] == "drum" then
			cylinder(mesh, x, 7.8, z + 0.55, 0.42, 1.1, "z", 12)
		elseif item[3] == "cog" then
			gear(mesh, x, 7.8, z + 0.62, 0.62, 0.22, 9, "y")
			box(mesh, x, 7.8, z, 0.8, 0.5, 0.1)
		elseif item[3] == "pipe" then
			for n = 0, 2 do
				cylinder(mesh, x, 7.8 + n * 0.22 - 0.22, z + 0.14, 0.13, 2.2, "x", 8)
			end
		else
			box(mesh, x, 7.8, z, 1.05, 0.95, 0.85)
			box(mesh, x, 7.8, z + 0.85, 1.16, 1.06, 0.1)
			box(mesh, x, 7.3, z + 0.1, 1.08, 0.04, 0.12)
		end
	end
end, nil, function(x, _y, z)
	-- Each item keeps one colour: find the one this point belongs to.
	local nearest, best = 1, math.huge
	for index, item in STOCK do
		local d = math.abs(item[1] - x) + math.abs(SHELF_Z[item[2]] + 0.5 - z) * 3
		if d < best then
			nearest, best = index, d
		end
	end
	local tone = STOCK_TONES[(nearest * 7) % #STOCK_TONES + 1]
	return tone[1], tone[2], tone[3]
end)

part("UpperContainer", nil, CONTAINER_RUST, function(mesh)
	box(mesh, -4, 4, LOWER_TOP + 0.1, 19.4, 9.4, 7.8)
	ribsAlongX(mesh, -13.2, 5.2, -0.8, LOWER_TOP + 0.4, 7)
	ribsAlongX(mesh, -13.2, 5.2, 8.8, LOWER_TOP + 0.4, 7)
	ribsAlongY(mesh, -13.75, -0.2, 8.2, LOWER_TOP + 0.4, 7)
	ribsAlongY(mesh, 5.75, -0.2, 8.2, LOWER_TOP + 0.4, 7)
	containerFrame(mesh, -14, 6, -1, 9, LOWER_TOP, UPPER_TOP)
end, nil, 0.3)

part("Counter", nil, PLANK, function(mesh)
	-- Long planks, jointed over the middle drum.
	for row = 0, 3 do
		local y = COUNTER_Y + (row - 1.5) * 0.6
		local joint = if row % 2 == 0 then -8 else 8
		box(mesh, (-11 + joint) / 2 - 0.03, y, 3, joint + 11 - 0.06, 0.56, 0.4)
		box(mesh, (11 + joint) / 2 + 0.03, y, 3, 11 - joint - 0.06, 0.56, 0.4)
	end
	box(mesh, 0, COUNTER_Y + 0.9, 2.8, 21, 0.3, 0.22)
end, nil, 0)

part("CounterDrums", nil, DRUM, function(mesh)
	for _, x in { -8, 0, 8 } do
		cylinder(mesh, x, COUNTER_Y, FLOOR + 1.1, 0.75, 2.2, "z", 14)
		for _, z in { 0.5, 1.7 } do
			cylinder(mesh, x, COUNTER_Y, FLOOR + z, 0.82, 0.12, "z", 14)
		end
	end
	-- A pair of stacked crates in each long span, so no plank runs far unsupported.
	for _, x in { -4, 4 } do
		box(mesh, x, COUNTER_Y, FLOOR, 1.5, 1.5, 1.08)
		box(mesh, x + 0.1, COUNTER_Y - 0.06, FLOOR + 1.08, 1.34, 1.34, 1.12)
	end
	box(mesh, -2.5, COUNTER_Y, 3.4, 1.6, 1.1, 0.9)
	strut(mesh, -2.5, COUNTER_Y + 0.25, 4.3, -2.5, COUNTER_Y - 0.35, 3.75, 0.26)
end, nil, 0.1)

local function tiltedAwning(mesh)
	return warped(mesh, function(x, y, z)
		return x, y, z + awningDrop(y)
	end)
end

part("Awning", nil, TIN, function(built)
	local mesh = tiltedAwning(built)
	local middle = AWNING_REAR - 4.45
	box(mesh, 0, middle, AWNING_Z, 32, 8.9, 0.1)
	for x = -15.6, 15.6, 0.8 do
		box(mesh, x, middle, AWNING_Z + 0.1, 0.34, 8.9, 0.1)
		box(mesh, x + 0.4, middle, AWNING_Z - 0.1, 0.34, 8.9, 0.1)
	end
end, nil, 0)

-- Lapped patch sheets: centre x, y, width, depth, and a slight skew.
local PATCHES = { { -7.5, -6, 7, 4, 0.05 }, { 6, -3.2, 5, 3, -0.08 }, { 11, -7.6, 4, 3.2, 0.1 } }

part("AwningPatches", nil, PATCH, function(built)
	for _, patch in PATCHES do
		local c, s = math.cos(patch[5]), math.sin(patch[5])
		local mesh = tiltedAwning(warped(built, function(x, y, z)
			local dx, dy = x - patch[1], y - patch[2]
			return patch[1] + dx * c - dy * s, patch[2] + dx * s + dy * c, z
		end))
		box(mesh, patch[1], patch[2], AWNING_Z + 0.22, patch[3], patch[4] + 0.03, 0.05)
		for x = patch[1] - patch[3] / 2 + 0.4, patch[1] + patch[3] / 2 - 0.3, 0.8 do
			box(mesh, x, patch[2], AWNING_Z + 0.24, 0.3, patch[4] - 0.05, 0.09)
		end
		for x = patch[1] - patch[3] / 2 + 0.2, patch[1] + patch[3] / 2, 1 do
			bolt(mesh, x, patch[2] - patch[4] / 2 + 0.15, AWNING_Z + 0.27, "z", 0.07)
			bolt(mesh, x, patch[2] + patch[4] / 2 - 0.15, AWNING_Z + 0.27, "z", 0.07)
		end
	end
end, nil, 0.15)

part("AwningPosts", nil, PIPE, function(mesh)
	local top = AWNING_Z + awningDrop(POST_Y) - 0.12
	for _, x in { -15, -5, 5, 15 } do
		cylinder(mesh, x, POST_Y, (FLOOR + top - 0.16) / 2, 0.3, top - 0.16 - FLOOR, "z", 10)
		box(mesh, x, POST_Y, top - 0.2, 0.9, 0.7, 0.2)
		box(mesh, x, POST_Y + 0.05, FLOOR, 0.86, 0.6, 0.1)
		-- A knee brace from the post back up to the rafters.
		strut(mesh, x, POST_Y + 0.15, top - 1.5, x, POST_Y + 1.35, top - 0.2, 0.14)
	end
	-- The ledger that carries the rear edge, bolted along the containers.
	box(mesh, 0, -1.2, AWNING_Z - 0.32, 31, 0.5, 0.3)
	-- An eave beam along the post heads and rafters back to the ledger.
	box(mesh, 0, POST_Y, top - 0.5, 31, 0.5, 0.42)
	for _, x in { -10, 0, 10 } do
		strut(mesh, x, POST_Y, top - 0.22, x, -1.3, AWNING_Z - 0.2, 0.26)
	end
end, nil, 0.1)

local LETTERS = {
	S = { "01111", "10000", "10000", "01110", "00001", "00001", "11110" },
	C = { "01110", "10001", "10000", "10000", "10000", "10001", "01110" },
	R = { "11110", "10001", "10001", "11110", "10100", "10010", "10001" },
	A = { "01110", "10001", "10001", "11111", "10001", "10001", "10001" },
	P = { "11110", "10001", "10001", "11110", "10000", "10000", "10000" },
}
local WORD = { "S", "C", "R", "A", "P" }
local CELL = 0.46
local SIGN_X, SIGN_Y, SIGN_Z = -4, 0.2, 19

local function onLetters(x: number, z: number): boolean
	local across = (x - SIGN_X) / CELL + 14.5
	local down = 3.5 - (z - SIGN_Z) / CELL
	if down < 0 or down >= 7 or across < 0 or across >= 29 then
		return false
	end
	local slot = math.floor(across / 6)
	local column = math.floor(across - slot * 6)
	if column >= 5 then
		return false
	end
	local rows = LETTERS[WORD[slot + 1]]
	return string.sub(rows[math.floor(down) + 1], column + 1, column + 1) == "1"
end

part("Sign", nil, YELLOW, function(mesh)
	box(mesh, SIGN_X, SIGN_Y, UPPER_TOP + 0.05, 18, 0.5, 4.4)
end, nil, function(x, y, z)
	-- Lettered on the front only; the back is bare board.
	if y < SIGN_Y and onLetters(x, z) then
		return DARK[1], DARK[2], DARK[3]
	end
	return YELLOW[1], YELLOW[2], YELLOW[3]
end)
parts[#parts].crisp = true

part("SignBraces", nil, PIPE, function(mesh)
	for _, x in { -11, -4, 3 } do
		strut(mesh, x, SIGN_Y + 0.3, UPPER_TOP + 3.4, x, SIGN_Y + 3.6, UPPER_TOP + 0.05, 0.28)
		box(mesh, x, SIGN_Y + 3.6, UPPER_TOP, 0.9, 0.9, 0.12)
		box(mesh, x, SIGN_Y + 0.35, UPPER_TOP, 0.9, 0.5, 0.12)
	end
end, nil, 0.1)

local CRANE_X, CRANE_Y, JIB_Z = 12, 4, 20.9
part("Crane", nil, YELLOW, function(mesh)
	for _, cx in { -0.8, 0.8 } do
		for _, cy in { -0.8, 0.8 } do
			box(mesh, CRANE_X + cx, CRANE_Y + cy, LOWER_TOP, 0.3, 0.3, 11.8)
		end
	end
	for z = LOWER_TOP, 19.2, 2.6 do
		strut(mesh, CRANE_X - 0.8, CRANE_Y - 0.8, z, CRANE_X + 0.8, CRANE_Y - 0.8, z + 2.6, 0.16)
		strut(mesh, CRANE_X + 0.8, CRANE_Y + 0.8, z, CRANE_X - 0.8, CRANE_Y + 0.8, z + 2.6, 0.16)
		strut(mesh, CRANE_X - 0.8, CRANE_Y + 0.8, z, CRANE_X - 0.8, CRANE_Y - 0.8, z + 2.6, 0.16)
		strut(mesh, CRANE_X + 0.8, CRANE_Y - 0.8, z, CRANE_X + 0.8, CRANE_Y + 0.8, z + 2.6, 0.16)
	end
	box(mesh, CRANE_X, CRANE_Y, 20.5, 2, 2, 0.5)
	-- The jib, its short counter-jib and the stays over the mast head.
	box(mesh, CRANE_X, 1, JIB_Z, 0.7, 16, 0.6)
	box(mesh, CRANE_X, CRANE_Y, JIB_Z + 0.5, 0.5, 0.5, 2.6)
	strut(mesh, CRANE_X, CRANE_Y, JIB_Z + 3, CRANE_X, -5, JIB_Z + 0.55, 0.13)
	strut(mesh, CRANE_X, CRANE_Y, JIB_Z + 3, CRANE_X, 8.6, JIB_Z + 0.55, 0.13)
end, nil, 0.1)

part("CraneWeight", nil, WEIGHT, function(mesh)
	box(mesh, CRANE_X, 8, JIB_Z - 1.45, 1.7, 1.6, 1.5)
	cylinder(mesh, CRANE_X, 5.9, JIB_Z + 1.05, 0.45, 1.1, "x", 14)
	box(mesh, CRANE_X, 5.9, JIB_Z + 0.55, 1.2, 0.8, 0.2)
end, nil, 0.1)

part("CraneHook", nil, PIPE, function(mesh)
	cylinder(mesh, CRANE_X, -6.5, 17.45, 0.07, 7.1, "z", 6)
	box(mesh, CRANE_X, -6.5, 13.6, 0.7, 0.35, 0.6)
	tube(mesh, roundedPath({ { CRANE_X, -6.5, 13.7 }, { CRANE_X, -6.5, 12.9 }, { CRANE_X, -5.9, 12.9 }, { CRANE_X, -5.9, 13.3 } }, 0.2, 3), 0.11, 8)
	-- The cable runs back along the jib to the winch.
	tube(mesh, { { CRANE_X, -6.5, JIB_Z + 0.62 }, { CRANE_X, 5.9, JIB_Z + 1.3 } }, 0.05, 6)
end, nil, 0.1)

part("StockPiles", nil, CONTAINER_RUST, function(mesh)
	-- Slatted crates on the right; a sagging stack and torn sheet on the left.
	local function crate(x, y, wide, deep, high)
		box(mesh, x, y, FLOOR, wide, deep, high)
		for z = FLOOR + 0.3, FLOOR + high - 0.2, 0.42 do
			box(mesh, x, y, z, wide + 0.08, deep + 0.08, 0.12)
		end
		for _, side in { -1, 1 } do
			box(mesh, x + side * (wide / 2 - 0.1), y - deep / 2 - 0.04, FLOOR, 0.2, 0.1, high)
		end
	end
	crate(13.8, -6.6, 2, 2.1, 2.2)
	crate(11.1, -7.1, 1.5, 1.7, 1.3)
	crate(-13.7, -6.4, 2, 2.2, 1.7)
	box(mesh, -13.8, -6.3, FLOOR + 1.7, 1.2, 1.2, 0.5)
	strut(mesh, -11.9, -7.4, FLOOR, -10.4, -6, FLOOR + 1.3, 0.3)
	strut(mesh, -10.5, -7.8, FLOOR, -9.8, -6.3, FLOOR + 0.7, 0.2)
	-- Torn sheet and bent lengths thrown against the left-hand stack.
	strut(mesh, -12.1, -8, FLOOR, -11.7, -7.7, FLOOR + 1.8, 0.8)
	strut(mesh, -14.8, -7.9, FLOOR, -14.5, -7.65, FLOOR + 1.5, 0.55)
	-- Torn sheet and bent bar leaning on the right-hand crates.
	strut(mesh, 15, -7.9, FLOOR, 14.4, -7.75, FLOOR + 2.1, 0.85)
	strut(mesh, 12.3, -8.3, FLOOR, 12.5, -7.2, FLOOR + 1.5, 0.3)
	strut(mesh, 10.2, -7.7, FLOOR, 10.9, -8.2, FLOOR + 0.8, 0.2)
end, nil, rusting(0.1, function(x, _y, _z)
	-- Each stack its own weathered timber or rusted sheet.
	if x > 13 then
		return 0.62, 0.36, 0.2
	elseif x > 9 then
		return 0.42, 0.34, 0.26
	elseif x < -12.4 then
		return 0.5, 0.3, 0.16
	end
	return 0.46, 0.44, 0.42
end))

-- The lived-in layer: door hardware, roof plant, a ladder, conduit, strings of
-- bulbs, price boards and supplies stacked round the shop.
part("Fittings", nil, { 0.3, 0.32, 0.36 }, function(mesh)
	-- The upper container's door end, with its locking rods and handles.
	box(mesh, 6.22, 4, LOWER_TOP + 0.2, 0.12, 9, 7.6)
	for _, y in { 1.2, 3.1, 4.9, 6.8 } do
		cylinder(mesh, 6.34, y, LOWER_TOP + 4, 0.08, 6.9, "z", 6)
		box(mesh, 6.42, y, LOWER_TOP + 3.1, 0.14, 0.6, 0.14)
		for _, h in { 0.9, 7 } do
			box(mesh, 6.36, y, LOWER_TOP + h, 0.14, 0.34, 0.3)
		end
	end
	-- The upper container's blind end: a bolted hatch and a downpipe on brackets.
	box(mesh, -13.86, 4, LOWER_TOP + 1.9, 0.14, 2.6, 3)
	for _, y in { 2.95, 5.05 } do
		box(mesh, -13.95, y, LOWER_TOP + 3.2, 0.08, 0.3, 0.4)
	end
	cylinder(mesh, -14.08, 6.8, LOWER_TOP + 4, 0.12, 7.2, "z", 8)
	for _, h in { 1, 4, 7 } do
		box(mesh, -13.9, 6.8, LOWER_TOP + h, 0.24, 0.3, 0.15)
	end
	-- Roof plant: an extractor, a fan unit and a hatch.
	cylinder(mesh, -11, 6.5, ROOF_TOP + 0.55, 0.55, 1.1, "z", 12)
	box(mesh, -11, 6.5, ROOF_TOP + 1.04, 1.5, 1.5, 0.14)
	box(mesh, -3.5, 6.6, ROOF_TOP, 3.2, 2.2, 1.3)
	ring(mesh, -3.5, 5.5, ROOF_TOP + 0.65, 0.2, 0.52, 0.2, "y", 14)
	for _, x in { -4.7, -2.3 } do
		box(mesh, x, 6.6, ROOF_TOP + 1.27, 0.12, 2, 0.1)
	end
	box(mesh, 2.8, 6.5, ROOF_TOP, 2, 2, 0.24)
	box(mesh, 2.8, 6.5, ROOF_TOP + 0.22, 1.5, 1.5, 0.12)
	box(mesh, 2.8, 7.1, ROOF_TOP + 0.26, 0.7, 0.12, 0.18)
	-- A ladder up the end of the lower containers.
	ladderOnX(mesh, 15.42, 6.2, FLOOR, LOWER_TOP + 1.1, 0.42)
	-- Conduit along the ledger, into a junction box by the door.
	cylinder(mesh, 0, -1.52, AWNING_Z - 0.4, 0.09, 29, "x", 6)
	box(mesh, -14.3, -1.5, AWNING_Z - 1.4, 1, 0.3, 1.2)
	for x = -12, 12, 4 do
		box(mesh, x, -1.42, AWNING_Z - 0.5, 0.2, 0.26, 0.34)
	end
	-- Back walls: welded patches, a door set, vents, a downpipe and conduit.
	for _, plate in { { -11, 1.6, 2.6, 3.4 }, { 3.5, 3.8, 3.4, 2.6 }, { 10.8, 5.2, 2.2, 2 } } do
		box(mesh, plate[1], 9.1, plate[2], plate[3], 0.24, plate[4])
		for k = 0, 3 do
			bolt(mesh, plate[1] - plate[3] / 2 + 0.15 + k * (plate[3] - 0.3) / 3, 9.23, plate[2] + 0.15, "y", 0.07)
			bolt(mesh, plate[1] - plate[3] / 2 + 0.15 + k * (plate[3] - 0.3) / 3, 9.23, plate[2] + plate[4] - 0.15, "y", 0.07)
		end
	end
	box(mesh, -4.4, 9.1, FLOOR + 0.1, 3.8, 0.3, 6.9)
	box(mesh, -4.4, 9.26, FLOOR + 0.2, 3.2, 0.06, 6.3)
	box(mesh, -3.1, 9.3, FLOOR + 2.9, 0.2, 0.14, 0.7)
	for _, vent in { { -11.6, 12.8 }, { -5.5, 13.6 }, { 1.6, 12.4 } } do
		box(mesh, vent[1], 8.95, vent[2], 1.6, 0.3, 1)
		for k = 0, 3 do
			box(mesh, vent[1], 9.1, vent[2] + 0.1 + k * 0.23, 1.45, 0.08, 0.08)
		end
	end
	cylinder(mesh, 7.5, 9.5, (FLOOR + LOWER_TOP + 0.5) / 2, 0.16, LOWER_TOP + 0.5 - FLOOR, "z", 8)
	box(mesh, 7.5, 9.5, LOWER_TOP + 0.5, 0.6, 0.6, 0.14)
	for _, z in { 2.5, 7 } do
		box(mesh, 7.5, 9.1, z, 0.5, 0.8, 0.16)
	end
	cylinder(mesh, -2, 9.42, 4.8, 0.09, 22, "x", 6)
	for x = -11, 7, 4.5 do
		box(mesh, x, 9.2, 4.68, 0.18, 0.5, 0.24)
	end
	-- A base frame carries the crane to the container's long walls.
	for _, x in { 10.9, 13.1 } do
		box(mesh, x, 4, LOWER_TOP - 0.1, 0.5, 10, 0.5)
	end
	box(mesh, CRANE_X, CRANE_Y, LOWER_TOP + 0.3, 3, 2.6, 0.2)
	-- Hanging stock on the back wall of the shop.
	for k, x in { -12.6, -10.4, -4.2, 3.4, 11, 13 } do
		box(mesh, x, 8.42, 7.2, 0.14, 0.34, 0.14)
		box(mesh, x, 8.32, 5.9 + k % 2 * 0.3, 0.16 + k % 3 * 0.12, 0.14, 1.3)
	end
	-- The upper container's face: a welded patch, a cut hatch, a vent and conduit.
	for _, plate in { { -10.9, 10.2, 3.4, 2.6 }, { 2.6, 12.4, 2.8, 2.4 } } do
		box(mesh, plate[1], -0.94, plate[2], plate[3], 0.26, plate[4])
		for k = 0, 4 do
			bolt(mesh, plate[1] - plate[3] / 2 + 0.2 + k * (plate[3] - 0.4) / 4, -1.08, plate[2] + 0.2, "y", 0.08)
			bolt(mesh, plate[1] - plate[3] / 2 + 0.2 + k * (plate[3] - 0.4) / 4, -1.08, plate[2] + plate[4] - 0.2, "y", 0.08)
		end
	end
	box(mesh, -5.2, -0.94, 10.2, 3, 0.26, 3.2)
	box(mesh, -5.2, -1.08, 10.5, 2.5, 0.08, 2.6)
	ring(mesh, -5.2, -1.14, 11.8, 0.22, 0.48, 0.1, "y", 14)
	box(mesh, 1.6, -0.94, 9.9, 2.2, 0.26, 1.3)
	for k = 0, 3 do
		box(mesh, 1.6, -1.08, 10.05 + k * 0.28, 2, 0.08, 0.1)
	end
	cylinder(mesh, -4.3, -1.14, 15.2, 0.1, 18.6, "x", 8)
	box(mesh, 5.2, -1.14, 14.85, 0.7, 0.3, 0.7)
	for x = -12, 5, 4.2 do
		box(mesh, x, -0.98, 15.05, 0.22, 0.34, 0.3)
	end
	-- The weld between the two lower units, on the back and the roof.
	box(mesh, 0, 9.04, FLOOR, 0.5, 0.34, 8)
	box(mesh, 0, 4, LOWER_TOP - 0.04, 0.5, 10, 0.12)
	for z = 1.4, 8.4, 0.5 do
		box(mesh, 0, 9.24, z, 0.6, 0.08, 0.2)
	end
	-- Inside: brackets, a cable run, hung tools and a noticeboard by the counter.
	for _, side in { -1, 1 } do
		cylinder(mesh, side * 14.5, 2, 6.7, 0.08, 6, "y", 6)
		for _, y in { 0.2, 3.4 } do
			box(mesh, side * 14.48, y, 6.2, 0.2, 0.3, 0.7)
			box(mesh, side * 14.4, y, 5.1 + (y * 2 % 1.3), 0.14, 0.26, 1.1)
		end
		box(mesh, side * 14.5, 6, 3.8, 0.16, 2.6, 1.8)
	end
	box(mesh, -3.5, 8.56, 6.7, 3.2, 0.16, 1.4)
	box(mesh, 3.6, 8.56, 6.8, 2.4, 0.16, 1.2)
	for _, x in { -4.3, -3.25, -2.35, 3, 4.1 } do
		box(mesh, x, 8.44, 7, 0.7, 0.08, 0.8)
	end
	-- Trim round the sign.
	box(mesh, SIGN_X, SIGN_Y - 0.08, UPPER_TOP + 4.32, 18.3, 0.66, 0.2)
	box(mesh, SIGN_X, SIGN_Y - 0.08, UPPER_TOP + 0.02, 18.3, 0.66, 0.2)
	for _, side in { -1, 1 } do
		box(mesh, SIGN_X + side * 9.08, SIGN_Y - 0.08, UPPER_TOP + 0.02, 0.2, 0.66, 4.5)
	end
end, nil, 0.1)

part("Stencil", nil, { 0.85, 0.82, 0.74 }, function(mesh)
	box(mesh, -9.8, -0.94, 13.4, 4.6, 0.26, 1.7)
end, nil, function(x, _y, z)
	-- A stencilled unit mark: bold bars and a hazard corner on an old panel.
	local u, v = x + 12.1, z - 13.4
	if u < 1.2 and (u + v) % 0.5 < 0.25 then
		return 0.08, 0.08, 0.09
	end
	if u > 1.5 and u < 4.3 and v > 0.3 and v < 1.4 and (u * 2) % 1 < 0.6 then
		return 0.08, 0.08, 0.09
	end
	return 0.85, 0.82, 0.74
end)
parts[#parts].crisp = true

part("PriceBoards", nil, { 0.76, 0.72, 0.6 }, function(mesh)
	for _, board in { { -11, 1.9 }, { -7.5, 1.5 }, { 7.2, 1.7 }, { 11, 2 } } do
		box(mesh, board[1], -0.95, LOWER_TOP - 1.1, board[2], 0.3, 0.92)
		for _, side in { -0.45, 0.45 } do
			box(mesh, board[1] + side * board[2], -1.12, LOWER_TOP - 0.5, 0.1, 0.1, 0.2)
		end
	end
end, nil, function(x, _y, z)
	-- Two bold rows of price marks on a pale board.
	local row = z - (LOWER_TOP - 1.1)
	local inRow = (row > 0.2 and row < 0.42) or (row > 0.56 and row < 0.78)
	if inRow and x % 0.46 < 0.3 then
		return 0.14, 0.13, 0.12
	end
	return 0.76, 0.72, 0.6
end)
parts[#parts].crisp = true

part("Supplies", nil, { 0.5, 0.45, 0.3 }, function(mesh)
	barrel(mesh, -16, 2.6, FLOOR)
	barrel(mesh, -16, 4.1, FLOOR)
	barrel(mesh, -15.9, 3.4, FLOOR + 1.86)
	gasBottle(mesh, -16.1, 6.2, FLOOR)
	gasBottle(mesh, -16.1, 7.2, FLOOR)
	tyres(mesh, 16, 1.6, FLOOR, 3)
	-- Goods out on the counter.
	box(mesh, 5.4, COUNTER_Y, 3.4, 1.4, 1, 0.6)
	box(mesh, 7.2, COUNTER_Y + 0.2, 3.4, 0.9, 0.7, 0.4)
	gear(mesh, 2, COUNTER_Y, 3.5, 0.55, 0.2, 9, "z")
	cylinder(mesh, -6, COUNTER_Y, 3.65, 0.3, 0.5, "z", 10)
	-- Stored on the lower roof.
	box(mesh, 9, 7.2, LOWER_TOP - 0.12, 2.2, 1.8, 1)
	for n = 0, 2 do
		cylinder(mesh, 8.8, 1 + n * 0.5, LOWER_TOP - 0.12 + 0.2, 0.22, 4.2, "x", 8)
	end
end, nil, supplyTones)

part("Cables", nil, { 0.08, 0.08, 0.1 }, function(mesh)
	local z = 7.9
	for _, x in { -15, -5, 5 } do
		tube(mesh, sagging(x, POST_Y, z, x + 10, POST_Y, z, 0.45, 8), 0.04, 5)
	end
	tube(mesh, roundedPath({ { -14.3, -1.5, AWNING_Z - 1.4 }, { -14.3, -1.5, FLOOR + 1 }, { -15, -0.6, FLOOR + 0.04 } }, 0.4, 3), 0.06, 6)
end, nil, 0)

part("Bulbs", nil, { 1, 0.84, 0.45 }, function(mesh)
	-- Festoon lamps along the eave, and a row round the sign.
	for _, start in { -15, -5, 5 } do
		for k = 1, 4 do
			local t = k / 5
			sphere(mesh, start + 10 * t, POST_Y, 7.9 - 0.45 * 4 * t * (1 - t) - 0.14, 0.13, 0.13, 0.16, 4, 8)
		end
	end
	for k = 0, 14 do
		local x = SIGN_X - 8.4 + k * 1.2
		sphere(mesh, x, SIGN_Y - 0.42, UPPER_TOP + 4.42, 0.11, 0.11, 0.11, 4, 8)
		sphere(mesh, x, SIGN_Y - 0.42, UPPER_TOP + 0.12, 0.11, 0.11, 0.11, 4, 8)
	end
end, true, 0, nil, 0.9)

handFinish({
	Fittings = "metal",
	Supplies = "metal",
	Slab = "rock",
	UpperContainer = "metal",
	LowerContainers = "metal",
	Shelves = "metal",
	Awning = "metal",
	AwningPatches = "metal",
	AwningPosts = "metal",
	SignBraces = "metal",
	Counter = "wood",
	CounterDrums = "metal",
	Crane = "metal",
	CraneWeight = "metal",
	CraneHook = "metal",
	StockPiles = "metal",
	Sign = "metal",
}, { Cables = true, Bulbs = true, PriceBoards = true, Stencil = true })
-- The ribs read better with broken strokes than a dash on every one.
for _, entry in parts do
	if entry.name == "LowerContainers" or entry.name == "UpperContainer" then
		entry.brushes.edge = { motion = "skip", tune = { skip = 0.65, width = 0.04 } }
	end
end

finishParts()
