local CACHE_KEY = "SkyIslands-a140b14b6cfdcbc8"
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

-- Previews build at a fraction of the density the layout asks for (TEXEL_SCALE).
local function useTexelDensity(pixelsPerStud: number)
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
-- and `blend` (0-1) to tint them from cream toward a lighter part colour.
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
	local CHUNK = if texelDensity then math.min(128, 1024 / texelDensity) else 128
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
			local needed = math.ceil(texelDensity / mesh:unwrap() / 4) * 4
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
			texture = math.clamp(needed, 16, 1024)
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
			rubber = entry.rubber,
			reach = entry.edge,
			highlightWidth = entry.wide,
			paintedHighlights = entry.painted,
			heightRange = entry.heightRange,
		})
		model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true })
	end
end
-- Sky Islands: the far-off floating islands and loose rocks of the sky, baked
-- here as variants of two genotypes so the game only places them.
--
-- An island is two or three tiers of rock, each a wobbly disc with a domed
-- grass cap that overhangs a little, the lowest hanging down to a lumpy,
-- knobbled point. Trees grow on every tier: a bent, tapering trunk that
-- forks into a few branches, each ending in a cluster of lumpy leaf
-- clumps. A rock is one knobbled boulder with a mossy top.
--
-- Each island is two parts, IslandNN_Ground and IslandNN_Trees, and each
-- rock one, RockNN; the game groups an island's parts by their name. The
-- rock wears the map islands' strata paint (IslandPaint) and every part
-- gets the kit's painted shading. About 44 studs across; the game scales
-- them up. Laid out in rows for the preview: islands at the back, rocks in
-- front.
-- Island paint: the rock islands' texture (strata, pebbles, grit and topsoil),
-- shared by the rock-wall items and the rock-cell items.
local GROUND = { 0.3, 0.27, 0.22 }
local STRATA = { { 0.5, 0.4, 0.27 }, { 0.36, 0.35, 0.34 }, { 0.48, 0.3, 0.22 } }
local TOPSOIL = { 0.24, 0.19, 0.14 }
-- Grit flecks in the ground and topsoil, and the pebbles set in the strata.
local GRIT_LIGHT, GRIT_DARK = { 0.58, 0.54, 0.46 }, { 0.11, 0.09, 0.07 }
local PEBBLES = { { 0.6, 0.57, 0.52 }, { 0.27, 0.26, 0.25 }, { 0.55, 0.38, 0.26 } }
-- How far a bed's colour drifts warmer or cooler.
local HUE_SHIFT = 0.07

local function random(k: number): number
	local s = math.sin(k * 12.9898 + 4.1414) * 43758.5453
	return s - math.floor(s)
end

local function mix(r: number, g: number, b: number, colour, f: number): (number, number, number)
	return r + (colour[1] - r) * f, g + (colour[2] - g) * f, b + (colour[3] - b) * f
end

-- Grit: sparse light and dark flecks a texel or two across, blended in.
local function grit(r: number, g: number, b: number, x: number, y: number, z: number): (number, number, number)
	local n = math.noise(x * 9, y * 9, z * 9 + 61)
	if math.abs(n) < 0.5 then return r, g, b end
	return mix(r, g, b, if n > 0 then GRIT_LIGHT else GRIT_DARK, math.min((math.abs(n) - 0.5) * 6, 0.7))
end

-- The island's texture: gritty ground on top, then topsoil fading into wavy
-- rock strata that darken with depth, with pebbles packed into some beds
-- like a conglomerate. A rock's `seed` shifts its strata, grain and hue
-- so neighbours don't match, and each rock has its own `tint`.
-- `spread` scales how far a rock's tint and hue wander from its neighbours' (1
-- by default). `single` holds the whole rock to one stratum and one pebble
-- colour, so a rock reads as cut from a single material.
local function islandPaint(x: number, y: number, z: number, seed: number?, tint: number?, spread: number?, single: boolean?)
	local below = -z
	if below < 0.3 then
		local k = 1 + 0.12 * math.noise(x / 4, y / 4, 31) + 0.05 * math.noise(x * 3, y * 3, 37)
		return grit(GROUND[1] * k, GROUND[2] * k, GROUND[3] * k, x, y, z)
	end
	local s = seed or 0
	local band = math.noise(x / 9 + s, y / 9, z / 2) * 0.6 + z * (0.8 + 0.2 * random(s + 1)) + random(s + 2) * 3
	local wave = math.sin(band * 2.4)
	local layer = STRATA[if single then math.floor(random(s + 4) * 3) + 1 else math.floor(band * 2.4 / (2 * math.pi)) % 3 + 1]
	local k = (1 + ((tint or 1) - 1) * (spread or 1)) * (1 + 0.1 * wave + 0.06 * math.noise(x * 2 + s, y * 2, z * 2))
	if wave > 0.93 then k -= 0.25 end
	k *= 1 - 0.6 * math.clamp((below - 3) / 20, 0, 1)
	local r, g, b = layer[1], layer[2], layer[3]
	-- Pebbles: rounded clasts, packed denser in some beds than others, each
	-- picked from PEBBLES by a slower noise and ringed by a dark seam.
	local threshold = 0.42 - 0.2 * math.noise(x / 6, y / 6, z / 1.5 + 79)
	local p = math.noise(x * 1.7 + s, y * 1.7, z * 1.7 + 71) - threshold
	if p > 0 then
		local c = if single then random(s + 5) * 0.6 - 0.3 else math.noise(x * 0.9, y * 0.9, z * 0.9 + 83)
		local pebble = PEBBLES[if c < -0.12 then 1 elseif c < 0.12 then 2 else 3]
		local seam = 1 - 0.3 * math.max(0, 1 - p / 0.05)
		r, g, b = pebble[1] * seam, pebble[2] * seam, pebble[3] * seam
	end
	-- The rock's hue drifts warmer or cooler, keeping its brightness.
	local hue = HUE_SHIFT * (spread or 1) * (2 * random(s + 3) - 1)
	r, g, b = r * k * (1 + hue), g * k * (1 + 0.2 * hue), b * k * (1 - hue)
	local soil = 1 - math.clamp((below - 0.5) / 4 + 0.3 * math.noise(x / 2, y / 2, 41), 0, 1)
	r, g, b = mix(r, g, b, TOPSOIL, soil)
	if soil <= 0 then return r, g, b end
	-- Grit only shows where the soil does.
	local gr, gg, gb = grit(r, g, b, x, y, z)
	return r + (gr - r) * soil, g + (gg - g) * soil, b + (gb - b) * soil
end

local ISLANDS = 6
local ROCKS = 8
local SIDES = 44
local WALL_RINGS = 14
local CAP_RINGS = 4
local RADIUS = 20

local GRASS = { { 0.25, 0.42, 0.17 }, { 0.36, 0.56, 0.2 }, { 0.5, 0.7, 0.26 } }
local MOSS_DARK = { 0.2, 0.33, 0.15 }
local LEAF = { { 0.16, 0.32, 0.17 }, { 0.26, 0.47, 0.2 }, { 0.42, 0.62, 0.24 }, { 0.6, 0.76, 0.32 } }
local BARK = { 0.36, 0.25, 0.17 }
local BARK_DARK = { 0.24, 0.16, 0.11 }
local HAZE = { 0.62, 0.7, 0.86 }

-- A seeded random source (the engine has no Random).
local function seeded(seed)
	local state = seed % 2147483647
	local function nextUnit()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	return {
		number = function(low, high)
			return low + (high - low) * nextUnit()
		end,
		integer = function(low, high)
			return math.min(high, low + math.floor(nextUnit() * (high - low + 1)))
		end,
	}
end

local function fbm(x, y, z)
	return math.noise(x, y, z) + 0.5 * math.noise(x * 2.1, y * 2.1, z * 2.1) + 0.25 * math.noise(x * 4.3, y * 4.3, z * 4.3)
end

local function blend(a, b, f)
	return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

-- A tier's rim radius at an angle: a wobbly outline with a bay or two.
local function rimOf(tier, theta)
	local c, s = math.cos(theta), math.sin(theta)
	return tier.radius * (1 + 0.16 * fbm(c * 0.9 + tier.seed, s * 0.9, tier.seed * 0.37))
end

-- How far the grass reaches down the wall below the rim, at an angle:
-- ragged tongues of moss.
local function dripOf(tier, theta)
	local c, s = math.cos(theta), math.sin(theta)
	return 0.5 + 2.6 * math.max(0, fbm(c * 3 + tier.seed, s * 3, 4.4) + 0.15)
end

-- One tier: a domed grass cap, a lip that overhangs the wall, and the rock
-- wall under it. The lowest tier's wall hangs down to a knobbled point; the
-- others stop out of sight inside the tier below.
local function buildTier(vertex, face, tier)
	local rings = {}
	local function ring(scale, z, jag)
		local row = {}
		for s = 0, SIDES - 1 do
			local theta = s / SIDES * TAU
			local r = rimOf(tier, theta) * scale
			if jag > 0 then
				-- Knobbles: lumps that grow toward the bottom.
				r *= 1 + jag * fbm(math.cos(theta) * 2.2 + tier.seed, math.sin(theta) * 2.2, z * 0.22)
			end
			row[s] = vertex(tier.x + math.cos(theta) * r, tier.y + math.sin(theta) * r, z)
		end
		table.insert(rings, row)
	end
	-- The cap, from near the middle out to the lip, rising toward the middle.
	for k = 1, CAP_RINGS do
		local share = k / CAP_RINGS
		ring(share * 1.02, tier.top + tier.dome * (1 - share * share), 0)
	end
	ring(1.06, tier.top - 0.35, 0)
	ring(1.04, tier.top - tier.lip, 0)
	ring(0.95, tier.top - tier.lip - 0.2, 0)
	for j = 1, WALL_RINGS do
		local t = j / WALL_RINGS
		local scale = if tier.pointed then 0.95 * (1 - t) ^ tier.taper else 0.95 * (1 - 0.15 * t)
		ring(math.max(scale, 0.02), tier.top - tier.lip - 0.2 - tier.depth * t, if tier.pointed then 0.18 + 0.3 * t else 0.12)
	end
	local center = vertex(tier.x, tier.y, tier.top + tier.dome)
	for s = 0, SIDES - 1 do
		local n = (s + 1) % SIDES
		face({ center, rings[1][s], rings[1][n] })
		for r = 1, #rings - 1 do
			face({ rings[r][s], rings[r + 1][s], rings[r + 1][n], rings[r][n] })
		end
	end
	local last = rings[#rings]
	local tip = vertex(tier.x + tier.radius * 0.08, tier.y, tier.top - tier.lip - 0.4 - tier.depth * 1.04)
	for s = 0, SIDES - 1 do
		face({ last[s], tip, last[(s + 1) % SIDES] })
	end
end

-- A tapering limb along `points`, from radius r0 to r1.
local function limb(vertex, face, points, r0, r1, sides)
	local rings = {}
	for i, p in points do
		local a, b = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
		local r = r0 + (r1 - r0) * (i - 1) / (#points - 1)
		local row = {}
		for k = 0, sides - 1 do
			local t = k / sides * TAU
			local c, n = math.cos(t) * r, math.sin(t) * r
			row[k] = vertex(p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n)
		end
		rings[i] = row
	end
	for i = 1, #points - 1 do
		for k = 0, sides - 1 do
			local n = (k + 1) % sides
			face({ rings[i][k], rings[i][n], rings[i + 1][n], rings[i + 1][k] })
		end
	end
end

-- A lumpy leaf clump: a sphere pushed in and out by noise, flatter below.
local function clump(vertex, face, cx, cy, cz, radius, seed)
	local rings, sides = 6, 10
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local theta = s / sides * TAU
			local x, y, z = math.sin(phi) * math.cos(theta), math.sin(phi) * math.sin(theta), math.cos(phi)
			local lump = 1 + 0.28 * math.noise(x * 1.8 + seed, y * 1.8, z * 1.8)
			local squash = if z < 0 then 0.55 else 0.85
			grid[r][s] = vertex(cx + x * radius * lump, cy + y * radius * lump, cz + z * radius * lump * squash)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			face({ grid[r][s], grid[r + 1][s], grid[r + 1][n], grid[r][n] })
		end
	end
end

-- A tree: a bent trunk that forks into branches, each ending in a cluster
-- of clumps, plus one cluster crowning the trunk.
local function growTree(rng, x, y, z, height)
	local tree = { limbs = {}, clumps = {} }
	local lean = rng.number(0, TAU)
	local bend = rng.number(0.05, 0.16) * height
	local trunk = {}
	for i = 0, 4 do
		local t = i / 4
		-- Bowed: leans out, then curls back toward upright near the top.
		local sway = math.sin(t * math.pi * 0.9) * bend
		table.insert(trunk, { x + math.cos(lean) * sway, y + math.sin(lean) * sway, z - 0.4 + t * height })
	end
	local girth = height * rng.number(0.05, 0.07)
	table.insert(tree.limbs, { points = trunk, r0 = girth, r1 = girth * 0.45 })
	local top = trunk[#trunk]
	local crown = height * rng.number(0.26, 0.34)
	local function cluster(cx, cy, cz, size)
		for c = 1, rng.integer(3, 5) do
			local a = rng.number(0, TAU)
			local d = if c == 1 then 0 else size * rng.number(0.45, 0.85)
			table.insert(tree.clumps, {
				cx + math.cos(a) * d,
				cy + math.sin(a) * d,
				cz + rng.number(-0.15, 0.3) * size,
				size * (if c == 1 then 0.95 else rng.number(0.55, 0.8)),
			})
		end
	end
	cluster(top[1], top[2], top[3] + crown * 0.3, crown)
	for b = 1, rng.integer(2, 4) do
		-- Branches leave the upper trunk and reach out and up.
		local from = trunk[rng.integer(3, 4)]
		local a = lean + b / 4 * TAU + rng.number(-0.5, 0.5)
		local reach = height * rng.number(0.25, 0.42)
		local rise = height * rng.number(0.12, 0.28)
		local mid = { from[1] + math.cos(a) * reach * 0.5, from[2] + math.sin(a) * reach * 0.5, from[3] + rise * 0.7 }
		local tip = { from[1] + math.cos(a) * reach, from[2] + math.sin(a) * reach, from[3] + rise }
		table.insert(tree.limbs, { points = { from, mid, tip }, r0 = girth * 0.55, r1 = girth * 0.25 })
		cluster(tip[1], tip[2], tip[3] + crown * 0.15, crown * rng.number(0.6, 0.8))
	end
	return tree
end

local function islandGenotype(seed)
	local rng = seeded(seed)
	local tiers, trees = {}, {}
	local count = rng.integer(2, 3)
	local x, y, top, radius = 0, 0, 0, RADIUS
	for k = 1, count do
		table.insert(tiers, {
			x = x,
			y = y,
			top = top,
			radius = radius,
			seed = seed % 97 + k * 3.1,
			lip = 1.1,
			dome = radius * 0.06,
			pointed = k == 1,
			taper = rng.number(0.55, 0.8),
			depth = if k == 1 then RADIUS * rng.number(1.1, 1.5) else RADIUS * 0.5,
		})
		local shrink = rng.number(0.5, 0.62)
		local angle = rng.number(0, TAU)
		local shift = radius * (1 - shrink) * rng.number(0.3, 0.7)
		x, y = x + math.cos(angle) * shift, y + math.sin(angle) * shift
		top += RADIUS * rng.number(0.26, 0.36)
		radius *= shrink
	end
	for k, tier in tiers do
		local above = tiers[k + 1]
		local wanted = if k == 1 then rng.integer(4, 7) else rng.integer(1, 3)
		local tries = 0
		while wanted > 0 and tries < 80 do
			tries += 1
			local angle, reach = rng.number(0, TAU), math.sqrt(rng.number(0.04, 0.6)) * tier.radius
			local tx, ty = tier.x + math.cos(angle) * reach, tier.y + math.sin(angle) * reach
			if above and math.sqrt((tx - above.x) ^ 2 + (ty - above.y) ^ 2) < above.radius * 1.3 then
				continue
			end
			wanted -= 1
			-- The cap's dome at that point, so the tree stands on it.
			local share = reach / tier.radius
			local ground = tier.top + tier.dome * (1 - share * share)
			local height = RADIUS * rng.number(0.3, 0.5) * (if k == 1 then 1 else 0.8)
			local tree = growTree(rng, tx, ty, ground, height)
			tree.tier = k
			table.insert(trees, tree)
		end
	end
	return { tiers = tiers, trees = trees, seed = seed % 97 }
end

-- Ground paint: grass on each tier's cap and its drips, the map islands'
-- strata below, the rock fading toward the sky's blue at the point. Grass
-- under a tree's crown is darker.
local function groundPainter(island, offsetX, offsetY)
	local bottom = island.tiers[1].top - island.tiers[1].lip - island.tiers[1].depth
	return function(x, y, z)
		x, y = x - offsetX, y - offsetY
		for k = #island.tiers, 1, -1 do
			local tier = island.tiers[k]
			local dx, dy = x - tier.x, y - tier.y
			local reach = math.sqrt(dx * dx + dy * dy)
			if reach < tier.radius * 1.35 and z <= tier.top + tier.dome + 0.1 then
				local theta = math.atan2(dy, dx)
				if z > tier.top - tier.lip - dripOf(tier, theta) then
					local patch = fbm(x * 0.18 + tier.seed, y * 0.18, z * 0.18)
					local color = if patch > 0.2 then GRASS[3] elseif patch > -0.25 then GRASS[2] else GRASS[1]
					local r, g, b = color[1], color[2], color[3]
					for _, tree in island.trees do
						local base = tree.limbs[1].points[1]
						local sx, sy = x - base[1] - 1.2, y - base[2] - 0.9
						if tree.tier == k and sx * sx + sy * sy < 9 then
							r, g, b = blend({ r, g, b }, MOSS_DARK, 0.7)
						end
					end
					-- The drips darken as they run down the rock.
					local below = math.clamp((tier.top - tier.lip - z) / 2.5, 0, 1)
					return blend({ r, g, b }, MOSS_DARK, below * 0.6)
				end
				-- Below this tier's grass: it may still be the grass of a
				-- tier beneath, round the foot of this one's wall.
			end
		end
		-- Strata measured down from the top of the tier this wall belongs to:
		-- the lowest tier whose top is above the point.
		local wallTop = math.huge
		for _, tier in island.tiers do
			if tier.top >= z - 0.05 then
				wallTop = math.min(wallTop, tier.top)
			end
		end
		if wallTop == math.huge then
			wallTop = island.tiers[1].top
		end
		local r, g, b = islandPaint(x, y, z - wallTop + 0.5, island.seed, 1.05)
		local fade = math.clamp(-z / -bottom, 0, 1) * 0.35
		return blend({ r, g, b }, HAZE, fade)
	end
end

local function treePainter(island, offsetX, offsetY)
	return function(x, y, z, _nx, _ny, nz)
		x, y = x - offsetX, y - offsetY
		for _, tree in island.trees do
			for _, c in tree.clumps do
				local dx, dy, dz = x - c[1], y - c[2], z - c[3]
				if dx * dx + dy * dy + dz * dz < (c[4] * 1.4) ^ 2 then
					-- Dappled leaves: a light top, a dark underside.
					local light = nz * 0.5 + fbm(x * 0.9, y * 0.9, z * 0.9) * 0.55 + 0.45
					local level = math.clamp(math.floor(light * 2.2) + 1, 1, #LEAF)
					local leaf = LEAF[level]
					return leaf[1], leaf[2], leaf[3]
				end
			end
		end
		-- Bark: dark grooves running up the limbs.
		local groove = math.noise(x * 3, y * 3, z * 0.4) > 0.25
		local color = if groove then BARK_DARK else BARK
		return color[1], color[2], color[3]
	end
end

local function rockGenotype(seed)
	local rng = seeded(seed)
	return { radius = rng.number(2.5, 5), tall = rng.number(0.9, 1.7), seed = seed % 89 }
end

-- A boulder: a knobbled blob, flat on top, drawn down to a point.
local function buildRock(vertex, face, rock)
	local rings, sides = 9, 16
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local theta = s / sides * TAU
			local bump = 1 + 0.35 * fbm(math.cos(theta) * 1.4 + rock.seed, math.sin(theta) * 1.4, r * 0.45)
			local reach = math.sin(phi) * rock.radius * bump
			local z = if phi < math.pi / 2 then math.cos(phi) * rock.radius * 0.3 else math.cos(phi) * rock.radius * rock.tall
			grid[r][s] = vertex(math.cos(theta) * reach, math.sin(theta) * reach, z)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			face({ grid[r][s], grid[r + 1][s], grid[r + 1][n], grid[r][n] })
		end
	end
end

local function rockPainter(rock, offsetX, offsetY)
	return function(x, y, z, _nx, _ny, nz)
		x, y = x - offsetX, y - offsetY
		if nz > 0.5 and z > rock.radius * 0.05 then
			local color = if fbm(x * 0.5 + rock.seed, y * 0.5, 0.5) > 0 then GRASS[3] else GRASS[2]
			return color[1], color[2], color[3]
		end
		local r, g, b = islandPaint(x, y, z - rock.radius * 0.3, rock.seed, 1.05)
		return blend({ r, g, b }, HAZE, math.clamp(-z / (rock.radius * rock.tall), 0, 1) * 0.3)
	end
end

-- A part built at a preview offset.
local function offsetPart(name, offsetX, offsetY, size, smooth, build, paint)
	part(name, nil, { 1, 1, 1 }, function(mesh)
		local function vertex(x, y, z)
			return mesh:vertex(x + offsetX, y + offsetY, z)
		end
		local function face(verts)
			mesh:face(verts)
		end
		build(vertex, face)
	end, smooth, rusting(0, paint), size, nil, true, 1.2)
end

for index = 1, ISLANDS do
	local island = islandGenotype(index * 6151)
	local offsetX, offsetY = (index - (ISLANDS + 1) / 2) * 60, 30
	local name = string.format("Island%02d", index)
	offsetPart(name .. "_Ground", offsetX, offsetY, 1024, 50, function(vertex, face)
		for _, tier in island.tiers do
			buildTier(vertex, face, tier)
		end
	end, groundPainter(island, offsetX, offsetY))
	offsetPart(name .. "_Trees", offsetX, offsetY, 512, 60, function(vertex, face)
		for _, tree in island.trees do
			for _, l in tree.limbs do
				limb(vertex, face, l.points, l.r0, l.r1, 6)
			end
			for k, c in tree.clumps do
				clump(vertex, face, c[1], c[2], c[3], c[4], k * 1.7 + index)
			end
		end
	end, treePainter(island, offsetX, offsetY))
end

for index = 1, ROCKS do
	local rock = rockGenotype(index * 3571)
	local offsetX, offsetY = (index - (ROCKS + 1) / 2) * 16, -30
	offsetPart(string.format("Rock%02d", index), offsetX, offsetY, 256, 50, function(vertex, face)
		buildRock(vertex, face, rock)
	end, rockPainter(rock, offsetX, offsetY))
end

finishParts()
