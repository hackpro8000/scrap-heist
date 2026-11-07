local CACHE_KEY = "JunkrotTrashaleroTrashala-656a018d9ecb7e52"
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
-- Trashalero Trashala: Tralalero Tralala riveted from tin sheet. A
-- grey-blue shark with a white belly, nose forward (+x), in blue sneakers
-- on its three bottom fins, the two pectorals and the fin under its tail,
-- so it sits low on them. Built after the picture: a slim torpedo body, a smooth conical
-- snout, the back sloping down to it over a flat belly line. No googly
-- face.
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
-- Edit Mesh: a mesh that can be edited after it's made, down to every
-- vertex, edge and face, then handed to the engine as one part
-- (`m:emit(mesh)` inside a part's build function). Include it with
-- `-- include: EditMesh`.
--
-- Every vertex, edge and face has an id that never changes and is never
-- reused, so a step can name what an earlier step made. Faces list their
-- vertices counter-clockwise seen from outside (the engine's winding), and
-- the mesh knows which faces share each edge and meet at each vertex, so
-- edge loops and rings can be followed and edits keep the surface closed.
--
-- What to edit is chosen by rule (m:select), not by clicking: faces facing
-- a direction, everything inside a box, an edge loop, a tag a step left.
-- A selection can be moved, turned and scaled, with soft falloff.
-- Operations (extrude, inset, bevel, loop cut, subdivide...) live in
-- shared/EditOps.luau on top of this.
--
-- Positions are z-up studs, as everywhere in the art.

local EditMesh = {}
EditMesh.__index = EditMesh

EditMesh.Selection = {}
EditMesh.Selection.__index = EditMesh.Selection

-- Vectors are plain {x, y, z} tables.
EditMesh.vec = {
	add = function(a, b)
		return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
	end,
	sub = function(a, b)
		return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
	end,
	scale = function(a, k)
		return { a[1] * k, a[2] * k, a[3] * k }
	end,
	dot = function(a, b)
		return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
	end,
	cross = function(a, b)
		return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
	end,
	length = function(a)
		return math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
	end,
	unit = function(a)
		local length = math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
		if length < 1e-12 then
			return { 0, 0, 0 }
		end
		return { a[1] / length, a[2] / length, a[3] / length }
	end,
	lerp = function(a, b, t)
		return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
	end,
}

local function edgeKey(a, b)
	if a < b then
		return a .. ":" .. b
	end
	return b .. ":" .. a
end

function EditMesh.new()
	return setmetatable({
		verts = {}, -- id -> { position = {x, y, z}, tags = {} }
		edges = {}, -- id -> { a, b, crease, tags }
		faces = {}, -- id -> { verts = {ids, counter-clockwise}, tags = {} }
		edgeByKey = {}, -- "a:b" -> edge id
		vertFaces = {}, -- vertex id -> { [face id] = true }
		vertEdges = {}, -- vertex id -> { [edge id] = true }
		edgeFaces = {}, -- edge id -> { [face id] = true }
		nextVert = 1,
		nextEdge = 1,
		nextFace = 1,
		-- Tags put on whatever the next steps make (EditMesh:tagging).
		stamp = nil,
	}, EditMesh)
end

-- ---------------------------------------------------------------- building

function EditMesh:addVertex(x, y, z)
	local id = self.nextVert
	self.nextVert += 1
	self.verts[id] = { position = { x, y, z }, tags = {} }
	self.vertFaces[id] = {}
	self.vertEdges[id] = {}
	if self.stamp then
		self.verts[id].tags[self.stamp] = true
	end
	return id
end

local function addEdge(self, a, b)
	local key = edgeKey(a, b)
	local id = self.edgeByKey[key]
	if id then
		return id
	end
	id = self.nextEdge
	self.nextEdge += 1
	self.edges[id] = { a = math.min(a, b), b = math.max(a, b), crease = 0, tags = {} }
	if self.stamp then
		self.edges[id].tags[self.stamp] = true
	end
	self.edgeByKey[key] = id
	self.edgeFaces[id] = {}
	self.vertEdges[a][id] = true
	self.vertEdges[b][id] = true
	return id
end

-- Adds a face over existing vertices, listed counter-clockwise seen from
-- outside. Returns its id.
function EditMesh:addFace(verts, tags)
	assert(#verts >= 3, "EditMesh: a face needs at least three vertices")
	local id = self.nextFace
	self.nextFace += 1
	local face = { verts = table.clone(verts), tags = {} }
	for name in tags or {} do
		face.tags[name] = true
	end
	if self.stamp then
		face.tags[self.stamp] = true
	end
	self.faces[id] = face
	-- Inside m:rebuilding, vertices a removeFace dropped come back first.
	for _, vert in verts do
		if not self.verts[vert] and self.ghosts and self.ghosts[vert] then
			self.verts[vert] = self.ghosts[vert]
			self.vertFaces[vert] = {}
			self.vertEdges[vert] = {}
		end
		assert(self.verts[vert], `EditMesh: face uses missing vertex {vert}`)
	end
	for index, vert in verts do
		self.vertFaces[vert][id] = true
		local nextVert = verts[index % #verts + 1]
		self.edgeFaces[addEdge(self, vert, nextVert)][id] = true
	end
	return id
end

-- Removes a face, and any edge or vertex left belonging to no face.
function EditMesh:removeFace(id)
	local face = self.faces[id]
	if not face then
		return
	end
	self.faces[id] = nil
	for index, vert in face.verts do
		self.vertFaces[vert][id] = nil
		local edge = self.edgeByKey[edgeKey(vert, face.verts[index % #face.verts + 1])]
		if edge then
			self.edgeFaces[edge][id] = nil
			if next(self.edgeFaces[edge]) == nil then
				local e = self.edges[edge]
				self.edges[edge] = nil
				self.edgeFaces[edge] = nil
				self.edgeByKey[edgeKey(e.a, e.b)] = nil
				self.vertEdges[e.a][edge] = nil
				self.vertEdges[e.b][edge] = nil
			end
		end
	end
	for _, vert in face.verts do
		if self.verts[vert] and next(self.vertFaces[vert]) == nil then
			self.verts[vert] = nil
			self.vertFaces[vert] = nil
			self.vertEdges[vert] = nil
		end
	end
end

-- Runs `body` with every vertex position remembered, so faces can be
-- rebuilt over vertices a removeFace would otherwise forget.
function EditMesh:rebuilding(body)
	self.ghosts = {}
	for id, vert in self.verts do
		self.ghosts[id] = vert
	end
	local results = table.pack(body())
	self.ghosts = nil
	return table.unpack(results, 1, results.n)
end

-- Removes a vertex and every face using it.
function EditMesh:removeVertex(id)
	for face in table.clone(self.vertFaces[id] or {}) do
		self:removeFace(face)
	end
end

-- Removes an edge and every face using it.
function EditMesh:removeEdge(id)
	for face in table.clone(self.edgeFaces[id] or {}) do
		self:removeFace(face)
	end
end

-- Puts `tag` on every vertex, edge and face made while `body` runs.
function EditMesh:tagging(tag, body)
	local outer = self.stamp
	self.stamp = tag
	local results = table.pack(body())
	self.stamp = outer
	return table.unpack(results, 1, results.n)
end

-- ---------------------------------------------------------------- reading

function EditMesh:position(id)
	return self.verts[id].position
end

function EditMesh:setPosition(id, x, y, z)
	self.verts[id].position = { x, y, z }
end

function EditMesh:edge(a, b)
	return self.edgeByKey[edgeKey(a, b)]
end

function EditMesh:edgeVerts(id)
	local edge = self.edges[id]
	return edge.a, edge.b
end

local function keys(set)
	local list = {}
	for key in set do
		table.insert(list, key)
	end
	table.sort(list)
	return list
end

function EditMesh:facesOfVertex(id)
	return keys(self.vertFaces[id])
end

function EditMesh:facesOfEdge(id)
	return keys(self.edgeFaces[id])
end

function EditMesh:edgesOfVertex(id)
	return keys(self.vertEdges[id])
end

function EditMesh:neighbours(id)
	local list = {}
	for edge in self.vertEdges[id] do
		local e = self.edges[edge]
		table.insert(list, if e.a == id then e.b else e.a)
	end
	table.sort(list)
	return list
end

function EditMesh:faceNormal(id)
	-- Newell's method, as the engine works it out.
	local verts = self.faces[id].verts
	local n = { 0, 0, 0 }
	for index, vert in verts do
		local p = self.verts[vert].position
		local q = self.verts[verts[index % #verts + 1]].position
		n[1] += (p[2] - q[2]) * (p[3] + q[3])
		n[2] += (p[3] - q[3]) * (p[1] + q[1])
		n[3] += (p[1] - q[1]) * (p[2] + q[2])
	end
	return EditMesh.vec.unit(n)
end

function EditMesh:faceCentre(id)
	local verts = self.faces[id].verts
	local sum = { 0, 0, 0 }
	for _, vert in verts do
		sum = EditMesh.vec.add(sum, self.verts[vert].position)
	end
	return EditMesh.vec.scale(sum, 1 / #verts)
end

function EditMesh:faceArea(id)
	local verts = self.faces[id].verts
	local n = { 0, 0, 0 }
	local first = self.verts[verts[1]].position
	for index = 2, #verts - 1 do
		local a = EditMesh.vec.sub(self.verts[verts[index]].position, first)
		local b = EditMesh.vec.sub(self.verts[verts[index + 1]].position, first)
		n = EditMesh.vec.add(n, EditMesh.vec.cross(a, b))
	end
	return EditMesh.vec.length(n) / 2
end

-- Average of the normals of the faces around a vertex, weighted by area.
function EditMesh:vertexNormal(id)
	local n = { 0, 0, 0 }
	for face in self.vertFaces[id] do
		n = EditMesh.vec.add(n, EditMesh.vec.scale(self:faceNormal(face), self:faceArea(face)))
	end
	return EditMesh.vec.unit(n)
end

function EditMesh:counts()
	local v, e, f = 0, 0, 0
	for _ in self.verts do
		v += 1
	end
	for _ in self.edges do
		e += 1
	end
	for _ in self.faces do
		f += 1
	end
	return v, e, f
end

function EditMesh:bounds()
	local low, high = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, vert in self.verts do
		for axis = 1, 3 do
			low[axis] = math.min(low[axis], vert.position[axis])
			high[axis] = math.max(high[axis], vert.position[axis])
		end
	end
	return low, high
end

-- ---------------------------------------------------------------- vertex-level edits

-- Puts a new vertex on an edge, `t` of the way from its lower id to its
-- higher, into every face that uses the edge. Returns the new vertex.
function EditMesh:splitEdge(id, t)
	local edge = self.edges[id]
	local a, b = edge.a, edge.b
	local p = EditMesh.vec.lerp(self.verts[a].position, self.verts[b].position, t or 0.5)
	local crease, edgeTags = edge.crease, table.clone(edge.tags)
	local middle = self:addVertex(p[1], p[2], p[3])
	return self:rebuilding(function()
		for _, face in keys(self.edgeFaces[id]) do
			local verts = table.clone(self.faces[face].verts)
			for index, vert in verts do
				local nextVert = verts[index % #verts + 1]
				if (vert == a and nextVert == b) or (vert == b and nextVert == a) then
					table.insert(verts, index + 1, middle)
					break
				end
			end
			self:replaceFace(face, verts)
		end
		for _, half in { self:edge(a, middle), self:edge(middle, b) } do
			if half then
				self.edges[half].crease = crease
				for name in edgeTags do
					self.edges[half].tags[name] = true
				end
			end
		end
		return middle
	end)
end

-- Swaps a face's vertices for `verts`, keeping its id and tags. For edits
-- that change a face in place (splitting an edge, merging vertices).
function EditMesh:replaceFace(id, verts)
	local tags = self.faces[id].tags
	local ghosts = self.ghosts
	if not ghosts then
		return self:rebuilding(function()
			return self:replaceFace(id, verts)
		end)
	end
	self:removeFace(id)
	for _, vert in verts do
		if not self.verts[vert] then
			self.verts[vert] = ghosts[vert]
			self.vertFaces[vert] = {}
			self.vertEdges[vert] = {}
		end
	end
	-- Same id: put the face back where it was.
	local face = { verts = table.clone(verts), tags = tags }
	self.faces[id] = face
	for index, vert in verts do
		self.vertFaces[vert][id] = true
		self.edgeFaces[addEdge(self, vert, verts[index % #verts + 1])][id] = true
	end
	return id
end

-- Merges vertex `b` into `a` (`a` stays, at `position` if given). Faces
-- that collapse below three corners go.
function EditMesh:mergeVertices(a, b, position)
	if position then
		self.verts[a].position = { position[1], position[2], position[3] }
	end
	self:rebuilding(function()
		for _, face in keys(self.vertFaces[b]) do
			local merged = {}
			for _, vert in self.faces[face].verts do
				local use = if vert == b then a else vert
				if merged[#merged] ~= use then
					table.insert(merged, use)
				end
			end
			if #merged > 1 and merged[1] == merged[#merged] then
				table.remove(merged)
			end
			if #merged < 3 then
				self:removeFace(face)
			else
				self:replaceFace(face, merged)
			end
		end
	end)
	if self.verts[b] and next(self.vertFaces[b]) == nil then
		self.verts[b] = nil
		self.vertFaces[b] = nil
		self.vertEdges[b] = nil
	end
	return a
end

-- Collapses an edge to its middle (or `t` along it). Returns the vertex kept.
function EditMesh:collapseEdge(id, t)
	local edge = self.edges[id]
	local p = EditMesh.vec.lerp(self.verts[edge.a].position, self.verts[edge.b].position, t or 0.5)
	return self:mergeVertices(edge.a, edge.b, p)
end

-- Splits a face in two with a new edge between two of its vertices that
-- aren't neighbours. Returns the two faces (the first keeps the old id).
function EditMesh:connect(face, a, b)
	local verts = self.faces[face].verts
	local ia, ib = table.find(verts, a), table.find(verts, b)
	assert(ia and ib, "EditMesh: connect needs two vertices of the face")
	local count = #verts
	assert((ia % count) + 1 ~= ib and (ib % count) + 1 ~= ia, "EditMesh: those vertices already share an edge")
	local first, second = {}, {}
	local index = ia
	while true do
		table.insert(first, verts[index])
		if index == ib then
			break
		end
		index = index % count + 1
	end
	index = ib
	while true do
		table.insert(second, verts[index])
		if index == ia then
			break
		end
		index = index % count + 1
	end
	local tags = table.clone(self.faces[face].tags)
	return self:rebuilding(function()
		self:replaceFace(face, first)
		return face, self:addFace(second, tags)
	end)
end

-- Slides a vertex along one of its edges, `t` of the way to the far end.
function EditMesh:slide(vert, edge, t)
	local e = self.edges[edge]
	local far = if e.a == vert then e.b else e.a
	local p = EditMesh.vec.lerp(self.verts[vert].position, self.verts[far].position, t)
	self.verts[vert].position = p
end

function EditMesh:setCrease(edge, weight)
	self.edges[edge].crease = math.clamp(weight, 0, 1)
end

-- Turns every face over (for a shape built inside out).
function EditMesh:flip(faces)
	self:rebuilding(function()
		for _, face in faces or keys(self.faces) do
			local verts = self.faces[face].verts
			local flipped = {}
			for index = #verts, 1, -1 do
				table.insert(flipped, verts[index])
			end
			self:replaceFace(face, flipped)
		end
	end)
end

-- ---------------------------------------------------------------- selection

-- A set of vertex, edge or face ids from one mesh. Made by m:select; most
-- methods return a selection, so steps chain.
local function selection(mesh, kind, ids)
	return setmetatable({ mesh = mesh, kind = kind, ids = ids }, EditMesh.Selection)
end

local function elements(self, kind)
	if kind == "vertex" then
		return self.verts
	elseif kind == "edge" then
		return self.edges
	end
	return self.faces
end

local function centreOf(self, kind, id)
	if kind == "vertex" then
		return self.verts[id].position
	elseif kind == "edge" then
		local e = self.edges[id]
		return EditMesh.vec.lerp(self.verts[e.a].position, self.verts[e.b].position, 0.5)
	end
	return self:faceCentre(id)
end

-- m:select(kind, rule, ...) with kind "vertex", "edge" or "face", and rule:
--   "all"
--   "ids", { ids }
--   "tag", name                     made inside m:tagging(name, ...)
--   "facing", {x, y, z}, [degrees]  faces whose normal is within degrees
--                                   (default 30) of the direction
--   "inside", {lo}, {hi}            centres inside the box
--   "where", function(position, id) centres the function accepts
function EditMesh:select(kind, rule, a, b)
	kind = kind or "face"
	local ids = {}
	for id, element in elements(self, kind) do
		local keep
		if rule == nil or rule == "all" then
			keep = true
		elseif rule == "ids" then
			keep = table.find(a, id) ~= nil
		elseif rule == "tag" then
			keep = element.tags[a] == true
		elseif rule == "facing" then
			assert(kind == "face", "EditMesh: facing selects faces")
			local limit = math.cos(math.rad(b or 30))
			keep = EditMesh.vec.dot(self:faceNormal(id), EditMesh.vec.unit(a)) >= limit
		elseif rule == "inside" then
			local p = centreOf(self, kind, id)
			keep = p[1] >= a[1] and p[1] <= b[1] and p[2] >= a[2] and p[2] <= b[2] and p[3] >= a[3] and p[3] <= b[3]
		elseif rule == "where" then
			keep = a(centreOf(self, kind, id), id) == true
		else
			error(`EditMesh: no selection rule {rule}`)
		end
		if keep then
			ids[id] = true
		end
	end
	return selection(self, kind, ids)
end

local Selection = EditMesh.Selection

function Selection:list()
	return keys(self.ids)
end

function Selection:count()
	local count = 0
	for _ in self.ids do
		count += 1
	end
	return count
end

function Selection:first()
	return self:list()[1]
end

function Selection:union(other)
	assert(other.kind == self.kind, "EditMesh: union of different kinds")
	local ids = table.clone(self.ids)
	for id in other.ids do
		ids[id] = true
	end
	return selection(self.mesh, self.kind, ids)
end

function Selection:minus(other)
	local ids = table.clone(self.ids)
	for id in other.ids do
		ids[id] = nil
	end
	return selection(self.mesh, self.kind, ids)
end

-- Keeps only the members `keep(position, id)` accepts.
function Selection:filter(keep)
	local ids = {}
	for id in self.ids do
		if keep(centreOf(self.mesh, self.kind, id), id) then
			ids[id] = true
		end
	end
	return selection(self.mesh, self.kind, ids)
end

-- The vertices the selection touches.
function Selection:verts()
	local mesh, ids = self.mesh, {}
	for id in self.ids do
		if self.kind == "vertex" then
			ids[id] = true
		elseif self.kind == "edge" then
			ids[mesh.edges[id].a] = true
			ids[mesh.edges[id].b] = true
		else
			for _, vert in mesh.faces[id].verts do
				ids[vert] = true
			end
		end
	end
	return selection(mesh, "vertex", ids)
end

-- The edges the selection touches (for faces: their outlines and insides).
function Selection:edges()
	local mesh, ids = self.mesh, {}
	if self.kind == "edge" then
		return self
	end
	if self.kind == "vertex" then
		for id in self.ids do
			for edge in mesh.vertEdges[id] do
				local e = mesh.edges[edge]
				if self.ids[e.a] and self.ids[e.b] then
					ids[edge] = true
				end
			end
		end
	else
		for id in self.ids do
			local verts = mesh.faces[id].verts
			for index, vert in verts do
				ids[mesh:edge(vert, verts[index % #verts + 1])] = true
			end
		end
	end
	return selection(mesh, "edge", ids)
end

-- The faces whose every vertex is in the selection.
function Selection:faces()
	local mesh, verts, ids = self.mesh, self:verts().ids, {}
	if self.kind == "face" then
		return self
	end
	for id, face in mesh.faces do
		local all = true
		for _, vert in face.verts do
			if not verts[vert] then
				all = false
				break
			end
		end
		if all then
			ids[id] = true
		end
	end
	return selection(mesh, "face", ids)
end

-- The edges round the outside of a face selection.
function Selection:boundary()
	assert(self.kind == "face", "EditMesh: boundary of faces")
	local mesh, ids = self.mesh, {}
	for edge in self:edges().ids do
		local inside = 0
		for face in mesh.edgeFaces[edge] do
			if self.ids[face] then
				inside += 1
			end
		end
		if inside == 1 then
			ids[edge] = true
		end
	end
	return selection(mesh, "edge", ids)
end

-- One step out: every element sharing a vertex with the selection.
function Selection:grow()
	local mesh, ids, verts = self.mesh, table.clone(self.ids), self:verts().ids
	for vert in verts do
		if self.kind == "vertex" then
			for _, other in mesh:neighbours(vert) do
				ids[other] = true
			end
		elseif self.kind == "edge" then
			for edge in mesh.vertEdges[vert] do
				ids[edge] = true
			end
		else
			for face in mesh.vertFaces[vert] do
				ids[face] = true
			end
		end
	end
	return selection(mesh, self.kind, ids)
end

-- One step in: drops members that touch anything outside the selection.
function Selection:shrink()
	local mesh, outside, ids = self.mesh, {}, {}
	local inVerts = self:verts().ids
	for vert in inVerts do
		if self.kind == "face" then
			for face in mesh.vertFaces[vert] do
				if not self.ids[face] then
					outside[vert] = true
				end
			end
		else
			for _, other in mesh:neighbours(vert) do
				if not inVerts[other] then
					outside[vert] = true
				end
			end
		end
	end
	for id in self.ids do
		local touches = false
		for vert in selection(mesh, self.kind, { [id] = true }):verts().ids do
			if outside[vert] then
				touches = true
			end
		end
		if not touches then
			ids[id] = true
		end
	end
	return selection(mesh, self.kind, ids)
end

-- ---------------------------------------------------------------- loops and rings

-- In a quad, the edge across from `edge`.
local function opposite(mesh, face, edge)
	local verts = mesh.faces[face].verts
	if #verts ~= 4 then
		return nil
	end
	local e = mesh.edges[edge]
	for index, vert in verts do
		local nextVert = verts[index % 4 + 1]
		if (vert == e.a and nextVert == e.b) or (vert == e.b and nextVert == e.a) then
			return mesh:edge(verts[(index + 1) % 4 + 1], verts[(index + 2) % 4 + 1])
		end
	end
	return nil
end

-- The ring of edges across quads from `edge`: each the one opposite the
-- last in the next quad, until it comes round or meets a non-quad.
function EditMesh:ring(edge)
	local ids = { [edge] = true }
	for face in self.edgeFaces[edge] do
		local current, from = edge, face
		while from do
			local across = opposite(self, from, current)
			if not across or ids[across] then
				break
			end
			ids[across] = true
			local nextFace = nil
			for other in self.edgeFaces[across] do
				if other ~= from then
					nextFace = other
				end
			end
			current, from = across, nextFace
		end
	end
	return selection(self, "edge", ids)
end

-- The loop of edges through `edge`: from each end, on through the vertex to
-- the edge that shares no face with the last, while the vertex has four
-- edges (a regular quad grid point).
function EditMesh:loop(edge)
	local ids = { [edge] = true }
	local e = self.edges[edge]
	for _, start in { e.a, e.b } do
		local current, vert = edge, start
		while true do
			if self:count(self.vertEdges[vert]) ~= 4 then
				break
			end
			local sharing = {}
			for face in self.edgeFaces[current] do
				sharing[face] = true
			end
			local nextEdge = nil
			for candidate in self.vertEdges[vert] do
				if candidate ~= current then
					local shares = false
					for face in self.edgeFaces[candidate] do
						if sharing[face] then
							shares = true
						end
					end
					if not shares then
						nextEdge = candidate
					end
				end
			end
			if not nextEdge or ids[nextEdge] then
				break
			end
			ids[nextEdge] = true
			local n = self.edges[nextEdge]
			current, vert = nextEdge, if n.a == vert then n.b else n.a
		end
	end
	return selection(self, "edge", ids)
end

function EditMesh:count(set)
	local count = 0
	for _ in set do
		count += 1
	end
	return count
end

-- ---------------------------------------------------------------- moving selections

-- Moves each selected vertex by `change(position, id) -> new position`.
-- With `radius`, vertices outside the selection within that distance of it
-- follow too, eased from full at the edge to none at `radius` (soft
-- selection): position + (new - position) * falloff.
function Selection:reshape(change, radius)
	local mesh, chosen = self.mesh, self:verts().ids
	local moves = {}
	for vert in chosen do
		moves[vert] = { weight = 1, from = mesh.verts[vert].position }
	end
	if radius and radius > 0 then
		for id, vert in mesh.verts do
			if not chosen[id] then
				local nearest = math.huge
				for other in chosen do
					nearest = math.min(nearest, EditMesh.vec.length(EditMesh.vec.sub(vert.position, mesh.verts[other].position)))
				end
				if nearest < radius then
					local t = 1 - nearest / radius
					moves[id] = { weight = t * t * (3 - 2 * t), from = vert.position }
				end
			end
		end
	end
	for id, move in moves do
		local target = change(move.from, id)
		mesh.verts[id].position = EditMesh.vec.lerp(move.from, target, move.weight)
	end
	return self
end

function Selection:move(offset, radius)
	return self:reshape(function(p)
		return EditMesh.vec.add(p, offset)
	end, radius)
end

-- Scales about `pivot` (default: the selection's middle) by {sx, sy, sz}.
function Selection:scale(factors, pivot, radius)
	pivot = pivot or self:middle()
	if type(factors) == "number" then
		factors = { factors, factors, factors }
	end
	return self:reshape(function(p)
		return {
			pivot[1] + (p[1] - pivot[1]) * factors[1],
			pivot[2] + (p[2] - pivot[2]) * factors[2],
			pivot[3] + (p[3] - pivot[3]) * factors[3],
		}
	end, radius)
end

-- Turns about `axis` ({x, y, z}, through `pivot`) by `degrees`.
function Selection:rotate(axis, degrees, pivot, radius)
	pivot = pivot or self:middle()
	local k = EditMesh.vec.unit(axis)
	local angle = math.rad(degrees)
	local c, s = math.cos(angle), math.sin(angle)
	return self:reshape(function(p)
		-- Rodrigues' rotation.
		local v = EditMesh.vec.sub(p, pivot)
		local cross = EditMesh.vec.cross(k, v)
		local along = EditMesh.vec.scale(k, EditMesh.vec.dot(k, v) * (1 - c))
		local turned = EditMesh.vec.add(EditMesh.vec.add(EditMesh.vec.scale(v, c), EditMesh.vec.scale(cross, s)), along)
		return EditMesh.vec.add(pivot, turned)
	end, radius)
end

-- The middle of the selection's vertices.
function Selection:middle()
	local sum, count = { 0, 0, 0 }, 0
	for vert in self:verts().ids do
		sum = EditMesh.vec.add(sum, self.mesh.verts[vert].position)
		count += 1
	end
	return EditMesh.vec.scale(sum, 1 / math.max(1, count))
end

function Selection:tag(name)
	local all = elements(self.mesh, self.kind)
	for id in self.ids do
		all[id].tags[name] = true
	end
	return self
end

function Selection:crease(weight)
	for edge in self:edges().ids do
		self.mesh:setCrease(edge, weight)
	end
	return self
end

-- ---------------------------------------------------------------- checks

-- What's wrong with the mesh, as a list of short descriptions: edges with
-- one face (holes), edges with more than two (fins), faces turned against
-- their neighbours, faces with more than four corners (unless allowed),
-- sliver faces, and loose vertices.
function EditMesh:problems(options)
	options = options or {}
	local found = {}
	local function note(text)
		if #found < 20 then
			table.insert(found, text)
		end
	end
	for edge, e in self.edges do
		local faces = self:count(self.edgeFaces[edge])
		if faces == 1 and not options.open then
			note(`hole at edge {edge} ({e.a}-{e.b})`)
		elseif faces > 2 then
			note(`edge {edge} is shared by {faces} faces`)
		elseif faces == 2 then
			-- Neighbours must run the shared edge in opposite directions.
			local runs = {}
			for face in self.edgeFaces[edge] do
				local verts = self.faces[face].verts
				for index, vert in verts do
					if vert == e.a and verts[index % #verts + 1] == e.b then
						table.insert(runs, 1)
					elseif vert == e.b and verts[index % #verts + 1] == e.a then
						table.insert(runs, -1)
					end
				end
			end
			if runs[1] == runs[2] then
				note(`faces at edge {edge} are turned against each other`)
			end
		end
	end
	for face, f in self.faces do
		if #f.verts > 4 and not options.ngons then
			note(`face {face} has {#f.verts} corners`)
		end
		if self:faceArea(face) < (options.sliver or 1e-6) then
			note(`face {face} has almost no area`)
		end
	end
	for vert in self.verts do
		if next(self.vertFaces[vert]) == nil then
			note(`vertex {vert} belongs to no face`)
		end
	end
	return found
end

-- The share of faces with four corners, 0-1.
function EditMesh:quadShare()
	local quads, all = 0, 0
	for _, face in self.faces do
		all += 1
		if #face.verts == 4 then
			quads += 1
		end
	end
	return if all == 0 then 1 else quads / all
end

-- ---------------------------------------------------------------- to the engine

-- Writes the mesh into an engine Mesh (the `mesh` a part's build function
-- gets), optionally moved by `offset`. Returns how many faces it wrote.
function EditMesh:emit(mesh, offset)
	local engineIds = {}
	local dx, dy, dz = 0, 0, 0
	if offset then
		dx, dy, dz = offset[1], offset[2], offset[3]
	end
	for _, id in keys(self.verts) do
		local p = self.verts[id].position
		engineIds[id] = mesh:vertex(p[1] + dx, p[2] + dy, p[3] + dz)
	end
	local written = 0
	for _, id in keys(self.faces) do
		local verts = {}
		for index, vert in self.faces[id].verts do
			verts[index] = engineIds[vert]
		end
		mesh:face(verts)
		written += 1
	end
	return written
end

-- A copy with fresh ids, for making variants of a shape.
function EditMesh:copy()
	local other = EditMesh.new()
	local map = {}
	for _, id in keys(self.verts) do
		local p = self.verts[id].position
		map[id] = other:addVertex(p[1], p[2], p[3])
		for name in self.verts[id].tags do
			other.verts[map[id]].tags[name] = true
		end
	end
	for _, id in keys(self.faces) do
		local verts = {}
		for index, vert in self.faces[id].verts do
			verts[index] = map[vert]
		end
		other:addFace(verts, self.faces[id].tags)
	end
	for _, id in keys(self.edges) do
		local e = self.edges[id]
		local mine = other:edge(map[e.a], map[e.b])
		other.edges[mine].crease = e.crease
		for name in e.tags do
			other.edges[mine].tags[name] = true
		end
	end
	return other
end
-- Edit Ops: the operations that reshape an Edit Mesh (shared/EditMesh.luau,
-- included first). Include with `-- include: EditOps` after EditMesh.
--
-- Each works on a selection (m:select(...)) or the whole mesh, keeps faces
-- four-sided wherever the input was, keeps a closed surface closed, and
-- returns what it made as a selection so the next step can use it. What
-- it makes is also tagged with the name passed as `tag`, when given.
--
--   extrude(faces, distance | {x, y, z}, options)  faces out, sides between
--   inset(faces, width, depth, options)            a smaller face inside
--   loopCut(edge, cuts, at)                        cuts across a quad ring
--   subdivide(levels)                              each face into quads
--   smoothSubdivide(levels)                        Catmull-Clark, with creases
--   bridge(edgesA, edgesB)                         quads joining two holes
--   bridgeFaces(a, b)                              a tunnel or handle between
--                                                  two faces or regions
--   bevel(edges, width, segments)                  chamfered or rounded edges
--   poke(faces)                                    a point in each face
--   spin / sweep (shared/EditShapes.luau)          lathe and profile sweeps
--   bend, taper, twist(axis...)                    reshape whole or selection
--   smooth(selection, amount, rounds)              relax towards neighbours
--   push(selection, distance)                      along vertex normals
--   toCircle(vertex loop)                          round a loop out
--   toSphere(selection, amount)                    pull towards a sphere
--   dissolve(edges)                                two faces into one
--   weld(distance)                                 merge vertices that touch
--   fill(edges)                                    close a hole with one face
--   mirror(axis, at)                               build one side, get both
--   solidify(thickness)                            give a sheet thickness
--   array(count, offset)                           copies in a row
--   transform(function)                            any reshaping by position

local vec = EditMesh.vec

local function sortedKeys(set)
	local list = {}
	for key in set do
		table.insert(list, key)
	end
	table.sort(list)
	return list
end

local function asFaces(m, faces)
	if faces == nil then
		return m:select("face", "all")
	end
	if faces.kind then
		return faces:faces()
	end
	return m:select("face", "ids", faces)
end

local function asVerts(m, selection)
	if selection == nil then
		return m:select("vertex", "all")
	end
	return selection:verts()
end

-- The region's edges that have one side in the region and one out (or no
-- other side), each as {a, b} running the way the region's face runs it.
local function boundaryRuns(m, faces)
	local runs = {}
	for face in faces.ids do
		local verts = m.faces[face].verts
		for index, a in verts do
			local b = verts[index % #verts + 1]
			local edge = m:edge(a, b)
			local inside = 0
			for other in m.edgeFaces[edge] do
				if faces.ids[other] then
					inside += 1
				end
			end
			if inside == 1 then
				table.insert(runs, { a, b, face })
			end
		end
	end
	return runs
end

-- ---------------------------------------------------------------- extrude and inset

-- Copies the region's vertices, moves the region onto the copies, and joins
-- old to new with a side quad on every boundary edge. `place(vert, copy)`
-- positions each copy. Returns the region (same faces) and the side faces.
local function lift(m, faces, place, tag)
	local runs = boundaryRuns(m, faces)
	local copies = {}
	local sides = {}
	-- Inner vertices of the region go when it moves; remember where they were.
	local before = {}
	for vert in faces:verts().ids do
		before[vert] = m.verts[vert].position
	end
	m:rebuilding(function()
		for vert in faces:verts().ids do
			local p = m.verts[vert].position
			copies[vert] = m:addVertex(p[1], p[2], p[3])
		end
		for face in faces.ids do
			local moved = {}
			for index, vert in m.faces[face].verts do
				moved[index] = copies[vert]
			end
			m:replaceFace(face, moved)
		end
		for _, run in runs do
			local a, b = run[1], run[2]
			local side = m:addFace({ a, b, copies[b], copies[a] }, tag and { [tag] = true } or nil)
			sides[side] = true
		end
	end)
	for vert, copy in copies do
		place(before[vert], copy, vert)
	end
	return faces, setmetatable({ mesh = m, kind = "face", ids = sides }, EditMesh.Selection)
end

-- The average normal of a region's faces at each of its vertices, and of
-- the whole region.
local function regionNormals(m, faces)
	local perVert, whole = {}, { 0, 0, 0 }
	for face in faces.ids do
		local n = vec.scale(m:faceNormal(face), m:faceArea(face))
		whole = vec.add(whole, n)
		for _, vert in m.faces[face].verts do
			perVert[vert] = vec.add(perVert[vert] or { 0, 0, 0 }, n)
		end
	end
	for vert, n in perVert do
		perVert[vert] = vec.unit(n)
	end
	return perVert, vec.unit(whole)
end

-- Extrudes faces. `amount` is a distance along the region's normal, or a
-- vector. options.each: every face on its own (default: the region as
-- one). options.along = "vertex": each vertex along its own normal (an
-- inflate). Returns the moved faces and the new side faces.
function EditMesh:extrude(faces, amount, options)
	options = options or {}
	faces = asFaces(self, faces)
	if options.each then
		local tops, sides = {}, {}
		for _, face in sortedKeys(faces.ids) do
			local top, side = self:extrude({ face }, amount, { along = options.along, tag = options.tag })
			for id in top.ids do
				tops[id] = true
			end
			for id in side.ids do
				sides[id] = true
			end
		end
		local Selection = EditMesh.Selection
		return setmetatable({ mesh = self, kind = "face", ids = tops }, Selection),
			setmetatable({ mesh = self, kind = "face", ids = sides }, Selection)
	end
	local perVert, whole = regionNormals(self, faces)
	return lift(self, faces, function(p, copy, vert)
		local offset
		if type(amount) == "table" then
			offset = amount
		elseif options.along == "vertex" then
			offset = vec.scale(perVert[vert], amount)
		else
			offset = vec.scale(whole, amount)
		end
		self.verts[copy].position = vec.add(p, offset)
	end, options.tag)
end

-- For each boundary vertex, the direction into the region along its
-- surface, scaled so an inset of 1 keeps edges 1 apart (mitred corners).
local function insetDirections(m, faces)
	local runs = boundaryRuns(m, faces)
	local into, outOf = {}, {}
	for _, run in runs do
		local a, b, face = run[1], run[2], run[3]
		local d = vec.unit(vec.sub(m.verts[b].position, m.verts[a].position))
		local inward = vec.unit(vec.cross(m:faceNormal(face), d))
		outOf[a] = inward
		into[b] = inward
	end
	local directions = {}
	for vert, before in into do
		local after = outOf[vert] or before
		local sum = vec.add(before, after)
		local denominator = 1 + vec.dot(before, after)
		directions[vert] = if denominator > 1e-6 then vec.scale(sum, 1 / denominator) else before
	end
	return directions
end

-- Insets faces: a smaller copy of the region inside it, `width` in from
-- its edges, raised by `depth` (negative to sink it). options.each: every
-- face on its own. Returns the inner faces and the ring of faces round them.
function EditMesh:inset(faces, width, depth, options)
	options = options or {}
	faces = asFaces(self, faces)
	if options.each then
		local inner, rings = {}, {}
		for _, face in sortedKeys(faces.ids) do
			local a, b = self:inset({ face }, width, depth, { tag = options.tag })
			for id in a.ids do
				inner[id] = true
			end
			for id in b.ids do
				rings[id] = true
			end
		end
		local Selection = EditMesh.Selection
		return setmetatable({ mesh = self, kind = "face", ids = inner }, Selection),
			setmetatable({ mesh = self, kind = "face", ids = rings }, Selection)
	end
	local directions = insetDirections(self, faces)
	local perVert = regionNormals(self, faces)
	return lift(self, faces, function(p, copy, vert)
		local offset = vec.scale(directions[vert] or { 0, 0, 0 }, width)
		offset = vec.add(offset, vec.scale(perVert[vert], depth or 0))
		self.verts[copy].position = vec.add(p, offset)
	end, options.tag)
end

-- ---------------------------------------------------------------- loop cut

-- The quad ring from `edge` in order, each step as {edge, face to the next,
-- sideA}: sideA is the end of the edge on the same side as the first edge's
-- lower end, so cuts line up all the way round.
local function orderedRing(m, edge)
	local function across(face, current, sideA)
		local verts = m.faces[face].verts
		if #verts ~= 4 then
			return nil
		end
		local e = m.edges[current]
		for index, vert in verts do
			local nextVert = verts[index % 4 + 1]
			if (vert == e.a and nextVert == e.b) or (vert == e.b and nextVert == e.a) then
				local c, d = verts[(index + 1) % 4 + 1], verts[(index + 2) % 4 + 1]
				-- d is joined to vert, c to nextVert.
				local nextA = if vert == sideA then d else c
				return m:edge(c, d), nextA
			end
		end
		return nil
	end
	local steps = { { edge = edge, a = m.edges[edge].a } }
	local seen = { [edge] = true }
	local closed = false
	local faces = sortedKeys(m.edgeFaces[edge])
	-- Forward through the first face, then backward through the second.
	for direction, startFace in faces do
		local current, sideA, face = edge, m.edges[edge].a, startFace
		while face do
			local nextEdge, nextA = across(face, current, sideA)
			if not nextEdge then
				break
			end
			if seen[nextEdge] then
				closed = nextEdge == edge
				if closed then
					-- The face that comes back round to the first edge.
					steps[1].via = face
				end
				break
			end
			seen[nextEdge] = true
			-- `via` is always the face between a step and the one before it.
			if direction == 1 then
				table.insert(steps, { edge = nextEdge, a = nextA, via = face })
			else
				steps[1].via = face
				table.insert(steps, 1, { edge = nextEdge, a = nextA })
			end
			local following = nil
			for other in m.edgeFaces[nextEdge] do
				if other ~= face then
					following = other
				end
			end
			current, sideA, face = nextEdge, nextA, following
		end
		if closed then
			break
		end
	end
	return steps, closed
end

-- Cuts `cuts` new edge loops across the quad ring through `edge`, evenly
-- spaced or at the fractions in `at` (measured from one side of the ring).
-- Returns the new edges.
function EditMesh:loopCut(edge, cuts, at)
	cuts = cuts or 1
	if not at then
		at = {}
		for k = 1, cuts do
			at[k] = k / (cuts + 1)
		end
	end
	table.sort(at)
	local steps, closed = orderedRing(self, edge)
	-- Split every edge of the ring at the fractions, from its side A.
	local made = {}
	for index, step in steps do
		local e = self.edges[step.edge]
		local other = if e.a == step.a then e.b else e.a
		local points = {}
		local remaining, from = step.edge, step.a
		local done = 0
		for k, t in at do
			-- Each split shortens what's left; rescale the fraction to it.
			local local_t = (t - done) / (1 - done)
			local re = self.edges[remaining]
			local frac = if re.a == from then local_t else 1 - local_t
			local middle = self:splitEdge(remaining, frac)
			points[k] = middle
			remaining = self:edge(middle, other)
			from = middle
			done = t
		end
		made[index] = points
	end
	-- Connect matching points across each quad of the ring: between each
	-- step and the next, and from the last back to the first if it closes.
	local newEdges = {}
	local function join(from, to)
		for k = 1, #at do
			local a, b = made[from][k], made[to][k]
			local shared = nil
			for candidate in self.vertFaces[a] do
				if self.vertFaces[b][candidate] then
					shared = candidate
				end
			end
			if shared and not self:edge(a, b) then
				self:connect(shared, a, b)
				newEdges[self:edge(a, b)] = true
			end
		end
	end
	for index = 1, #steps - 1 do
		join(index, index + 1)
	end
	if closed and #steps > 2 then
		join(#steps, 1)
	end
	return setmetatable({ mesh = self, kind = "edge", ids = newEdges }, EditMesh.Selection)
end

-- ---------------------------------------------------------------- subdivision

-- One level of splitting every face into quads: a point in the middle of
-- each face and each edge. `smooth` positions them by Catmull-Clark,
-- honouring edge creases (1 keeps an edge sharp, between blends).
local function subdivideOnce(m, smooth)
	local facePoint, edgePoint = {}, {}
	local oldFaces = sortedKeys(m.faces)
	local oldEdges = sortedKeys(m.edges)
	local oldVerts = sortedKeys(m.verts)
	local creases, faceTags = {}, {}
	for _, face in oldFaces do
		facePoint[face] = m:faceCentre(face)
		faceTags[face] = table.clone(m.faces[face].tags)
	end
	local edgePosition = {}
	for _, edge in oldEdges do
		local e = m.edges[edge]
		local a, b = m.verts[e.a].position, m.verts[e.b].position
		local middle = vec.lerp(a, b, 0.5)
		local p = middle
		local faces = sortedKeys(m.edgeFaces[edge])
		if smooth and #faces == 2 then
			local soft = vec.scale(vec.add(vec.add(a, b), vec.add(facePoint[faces[1]], facePoint[faces[2]])), 0.25)
			p = vec.lerp(soft, middle, e.crease)
		end
		edgePosition[edge] = p
		creases[edge] = e.crease
	end
	local vertPosition = {}
	for _, vert in oldVerts do
		local p = m.verts[vert].position
		if not smooth then
			vertPosition[vert] = p
			continue
		end
		local edges = sortedKeys(m.vertEdges[vert])
		local faces = sortedKeys(m.vertFaces[vert])
		local sharp, border = {}, {}
		for _, edge in edges do
			if #sortedKeys(m.edgeFaces[edge]) < 2 then
				table.insert(border, edge)
			end
			if m.edges[edge].crease > 0 then
				table.insert(sharp, edge)
			end
		end
		local n = #faces
		local soft
		if #border > 0 or n == 0 then
			-- Open edge: keep to the boundary curve.
			if #border == 2 then
				local function far(edge)
					local e = m.edges[edge]
					return m.verts[if e.a == vert then e.b else e.a].position
				end
				soft = vec.scale(vec.add(vec.scale(p, 6), vec.add(far(border[1]), far(border[2]))), 1 / 8)
			else
				soft = p
			end
			vertPosition[vert] = soft
			continue
		end
		local faceAverage, edgeAverage = { 0, 0, 0 }, { 0, 0, 0 }
		for _, face in faces do
			faceAverage = vec.add(faceAverage, facePoint[face])
		end
		faceAverage = vec.scale(faceAverage, 1 / n)
		for _, edge in edges do
			local e = m.edges[edge]
			edgeAverage = vec.add(edgeAverage, vec.lerp(m.verts[e.a].position, m.verts[e.b].position, 0.5))
		end
		edgeAverage = vec.scale(edgeAverage, 1 / #edges)
		soft = vec.scale(vec.add(vec.add(faceAverage, vec.scale(edgeAverage, 2)), vec.scale(p, n - 3)), 1 / n)
		if #sharp == 2 then
			local function far(edge)
				local e = m.edges[edge]
				return m.verts[if e.a == vert then e.b else e.a].position
			end
			local creased = vec.scale(vec.add(vec.scale(p, 6), vec.add(far(sharp[1]), far(sharp[2]))), 1 / 8)
			local weight = (m.edges[sharp[1]].crease + m.edges[sharp[2]].crease) / 2
			soft = vec.lerp(soft, creased, weight)
		elseif #sharp > 2 then
			local weight = 0
			for _, edge in sharp do
				weight = math.max(weight, m.edges[edge].crease)
			end
			soft = vec.lerp(soft, p, weight)
		end
		vertPosition[vert] = soft
	end

	-- Rebuild: a fresh mesh keeps it simple; ids of the old vertices carry over.
	local rebuilt = EditMesh.new()
	rebuilt.nextVert = m.nextVert
	for _, vert in oldVerts do
		local p = vertPosition[vert]
		rebuilt.verts[vert] = { position = { p[1], p[2], p[3] }, tags = table.clone(m.verts[vert].tags) }
		rebuilt.vertFaces[vert] = {}
		rebuilt.vertEdges[vert] = {}
	end
	local edgeVert, faceVert = {}, {}
	for _, edge in oldEdges do
		local p = edgePosition[edge]
		edgeVert[edge] = rebuilt:addVertex(p[1], p[2], p[3])
	end
	for _, face in oldFaces do
		local p = facePoint[face]
		if smooth then
			-- Catmull-Clark face points are the plain centres.
			p = facePoint[face]
		end
		faceVert[face] = rebuilt:addVertex(p[1], p[2], p[3])
	end
	rebuilt.nextFace = m.nextFace
	local childCreases = {}
	for _, face in oldFaces do
		local verts = m.faces[face].verts
		local count = #verts
		for index, vert in verts do
			local before = verts[(index - 2) % count + 1]
			local after = verts[index % count + 1]
			local e1 = edgeVert[m:edge(before, vert)]
			local e2 = edgeVert[m:edge(vert, after)]
			rebuilt:addFace({ vert, e2, faceVert[face], e1 }, faceTags[face])
		end
	end
	-- Each crease passes to the two halves of its edge.
	for _, edge in oldEdges do
		local e = m.edges[edge]
		for _, half in { rebuilt:edge(e.a, edgeVert[edge]), rebuilt:edge(edgeVert[edge], e.b) } do
			if half then
				rebuilt.edges[half].crease = creases[edge]
				for name in e.tags do
					rebuilt.edges[half].tags[name] = true
				end
			end
		end
	end
	for key, value in rebuilt do
		m[key] = value
	end
	setmetatable(m, EditMesh)
	return childCreases
end

-- Splits every face into quads, `levels` times, without moving anything.
function EditMesh:subdivide(levels)
	for _ = 1, levels or 1 do
		subdivideOnce(self, false)
	end
	return self:select("face", "all")
end

-- Catmull-Clark subdivision, `levels` times: a rough cage becomes a smooth
-- shape. Creased edges (m:setCrease, selection:crease) stay sharp.
function EditMesh:smoothSubdivide(levels)
	for _ = 1, levels or 1 do
		subdivideOnce(self, true)
	end
	return self:select("face", "all")
end

-- ---------------------------------------------------------------- bridging and filling

-- Orders a set of edges forming one closed loop into a vertex cycle, each
-- step running the way the edge's one face runs it (a hole's rim).
local function rimCycle(m, edges)
	local nextOf = {}
	for edge in edges.ids do
		local e = m.edges[edge]
		local face = sortedKeys(m.edgeFaces[edge])[1]
		assert(face, "EditMesh: a rim edge with no face")
		local verts = m.faces[face].verts
		for index, vert in verts do
			local after = verts[index % #verts + 1]
			if (vert == e.a and after == e.b) or (vert == e.b and after == e.a) then
				nextOf[vert] = after
			end
		end
	end
	local start = sortedKeys(nextOf)[1]
	local cycle, vert = {}, start
	repeat
		table.insert(cycle, vert)
		vert = nextOf[vert]
		assert(vert, "EditMesh: those edges aren't one closed loop")
	until vert == start
	assert(#cycle == m:count(edges.ids), `EditMesh: those edges make more than one loop ({#cycle} of {m:count(edges.ids)} in the first)`)
	return cycle
end

-- Joins two holes' rims (edge selections of equal length) with quads.
-- The rims are matched where they line up best. Returns the new faces.
function EditMesh:bridge(edgesA, edgesB, tag)
	local a, b = rimCycle(self, edgesA), rimCycle(self, edgesB)
	assert(#a == #b, `EditMesh: bridge needs rims of one length ({#a} and {#b})`)
	local n = #a
	local best, bestCost = 0, math.huge
	for offset = 0, n - 1 do
		local cost = 0
		for i = 0, n - 1 do
			local j = (offset - i) % n
			cost += vec.length(vec.sub(self.verts[a[i + 1]].position, self.verts[b[j + 1]].position))
		end
		if cost < bestCost then
			best, bestCost = offset, cost
		end
	end
	local made = {}
	for i = 0, n - 1 do
		local j, k = (best - i) % n, (best - i - 1) % n
		local face = self:addFace({ a[(i + 1) % n + 1], a[i + 1], b[j + 1], b[k + 1] }, tag and { [tag] = true } or nil)
		made[face] = true
	end
	return setmetatable({ mesh = self, kind = "face", ids = made }, EditMesh.Selection)
end

-- Removes two faces (or two regions of faces, given as selections) and
-- joins their rims: a tunnel through the mesh, or a handle between two
-- ends turned to face each other.
function EditMesh:bridgeFaces(faceA, faceB, tag)
	local regionA = if type(faceA) == "table" then faceA:faces() else self:select("face", "ids", { faceA })
	local regionB = if type(faceB) == "table" then faceB:faces() else self:select("face", "ids", { faceB })
	local keepA, keepB = regionA:boundary().ids, regionB:boundary().ids
	return self:rebuilding(function()
		for face in regionA.ids do
			self:removeFace(face)
		end
		for face in regionB.ids do
			self:removeFace(face)
		end
		local function restore(ids)
			return setmetatable({ mesh = self, kind = "edge", ids = ids }, EditMesh.Selection)
		end
		return self:bridge(restore(keepA), restore(keepB), tag)
	end)
end

-- Closes a hole with one face over its rim. Returns the face.
function EditMesh:fill(edges, tag)
	local cycle = rimCycle(self, edges)
	local reversed = {}
	for index = #cycle, 1, -1 do
		table.insert(reversed, cycle[index])
	end
	return self:addFace(reversed, tag and { [tag] = true } or nil)
end

-- Removes the edges between pairs of faces, joining each pair into one.
function EditMesh:dissolve(edges)
	self:rebuilding(function()
		for _, edge in sortedKeys(edges:edges().ids) do
			local e = self.edges[edge]
			if not e then
				continue
			end
			local faces = sortedKeys(self.edgeFaces[edge])
			if #faces ~= 2 then
				continue
			end
			local f1, f2 = self.faces[faces[1]].verts, self.faces[faces[2]].verts
			-- Walk f1 from e.b round to e.a, then f2 from e.a round to e.b.
			local function from(verts, start, stop)
				local list, index = {}, table.find(verts, start)
				while verts[index] ~= stop do
					table.insert(list, verts[index])
					index = index % #verts + 1
				end
				return list
			end
			local i1 = table.find(f1, e.a)
			local runsAB = f1[i1 % #f1 + 1] == e.b
			local first = if runsAB then from(f1, e.b, e.a) else from(f1, e.a, e.b)
			local second = if runsAB then from(f2, e.a, e.b) else from(f2, e.b, e.a)
			local joined = table.clone(first)
			for _, vert in second do
				table.insert(joined, vert)
			end
			local tags = self.faces[faces[1]].tags
			self:removeFace(faces[2])
			self:replaceFace(faces[1], joined)
			for name in tags do
				self.faces[faces[1]].tags[name] = true
			end
		end
	end)
end

-- Merges vertices closer than `distance` (default 1e-4) into one.
function EditMesh:weld(distance)
	distance = distance or 1e-4
	local cell = math.max(distance * 4, 1e-6)
	local grid = {}
	local merged = 0
	for _, vert in sortedKeys(self.verts) do
		local v = self.verts[vert]
		if not v then
			continue
		end
		local p = v.position
		local cx, cy, cz = p[1] // cell, p[2] // cell, p[3] // cell
		local target = nil
		for dx = -1, 1 do
			for dy = -1, 1 do
				for dz = -1, 1 do
					for _, other in grid[`{cx + dx},{cy + dy},{cz + dz}`] or {} do
						if self.verts[other] and vec.length(vec.sub(self.verts[other].position, p)) <= distance then
							target = other
						end
					end
				end
			end
		end
		if target then
			self:mergeVertices(target, vert)
			merged += 1
		else
			local key = `{cx},{cy},{cz}`
			grid[key] = grid[key] or {}
			table.insert(grid[key], vert)
		end
	end
	return merged
end

-- A vertex in the middle of each face, joined to its corners (triangles).
function EditMesh:poke(faces)
	faces = asFaces(self, faces)
	local made = {}
	self:rebuilding(function()
		for _, face in sortedKeys(faces.ids) do
			local verts = table.clone(self.faces[face].verts)
			local c = self:faceCentre(face)
			local tags = self.faces[face].tags
			local middle = self:addVertex(c[1], c[2], c[3])
			self:removeFace(face)
			for index, vert in verts do
				local id = self:addFace({ vert, verts[index % #verts + 1], middle }, tags)
				made[id] = true
			end
		end
	end)
	return setmetatable({ mesh = self, kind = "face", ids = made }, EditMesh.Selection)
end

-- ---------------------------------------------------------------- reshaping

-- Moves every vertex (or the selection's) to `change(position) -> new`.
function EditMesh:transform(change, selection)
	for vert in asVerts(self, selection).ids do
		local p = self.verts[vert].position
		local q = change({ p[1], p[2], p[3] })
		self.verts[vert].position = q
	end
	return self
end

local AXES = { x = 1, y = 2, z = 3 }

-- Bends along `along` (the axis the shape runs on) towards `toward`, by
-- `degrees` over the whole length of the mesh (or selection), about its
-- low end. A strip along x bent 180 degrees toward z makes an arch.
function EditMesh:bend(degrees, along, toward, selection)
	local i, j = AXES[along or "x"], AXES[toward or "z"]
	local low, high = self:bounds()
	local length = high[i] - low[i]
	local angle = math.rad(degrees)
	if math.abs(angle) < 1e-9 or length <= 0 then
		return self
	end
	local radius = length / angle
	return self:transform(function(p)
		local theta = (p[i] - low[i]) / length * angle
		local r = radius - (p[j] - low[j])
		local q = table.clone(p)
		q[i] = low[i] + r * math.sin(theta)
		q[j] = low[j] + radius - r * math.cos(theta)
		return q
	end, selection)
end

-- Scales across `axis` from `from` at its low end to `to` at its high end.
function EditMesh:taper(axis, from, to, selection)
	local k = AXES[axis or "z"]
	local low, high = self:bounds()
	local centre = vec.lerp(low, high, 0.5)
	local length = math.max(1e-9, high[k] - low[k])
	return self:transform(function(p)
		local t = (p[k] - low[k]) / length
		local factor = from + (to - from) * t
		local q = table.clone(p)
		for axisIndex = 1, 3 do
			if axisIndex ~= k then
				q[axisIndex] = centre[axisIndex] + (p[axisIndex] - centre[axisIndex]) * factor
			end
		end
		return q
	end, selection)
end

-- Twists about `axis` through the middle, `degrees` from end to end.
function EditMesh:twist(axis, degrees, selection)
	local k = AXES[axis or "z"]
	local u, w = (k % 3) + 1, ((k + 1) % 3) + 1
	local low, high = self:bounds()
	local centre = vec.lerp(low, high, 0.5)
	local length = math.max(1e-9, high[k] - low[k])
	return self:transform(function(p)
		local angle = math.rad(degrees) * (p[k] - low[k]) / length
		local c, s = math.cos(angle), math.sin(angle)
		local du, dw = p[u] - centre[u], p[w] - centre[w]
		local q = table.clone(p)
		q[u] = centre[u] + du * c - dw * s
		q[w] = centre[w] + du * s + dw * c
		return q
	end, selection)
end

-- Relaxes vertices towards the average of their neighbours, `amount`
-- (0-1) each round. options.keepBorder leaves open edges where they are.
function EditMesh:smooth(selection, amount, rounds, options)
	options = options or {}
	local verts = asVerts(self, selection).ids
	for _ = 1, rounds or 1 do
		local moved = {}
		for vert in verts do
			local neighbours = self:neighbours(vert)
			if #neighbours == 0 then
				continue
			end
			if options.keepBorder then
				local border = false
				for edge in self.vertEdges[vert] do
					if self:count(self.edgeFaces[edge]) < 2 then
						border = true
					end
				end
				if border then
					continue
				end
			end
			local sum = { 0, 0, 0 }
			for _, other in neighbours do
				sum = vec.add(sum, self.verts[other].position)
			end
			moved[vert] = vec.lerp(self.verts[vert].position, vec.scale(sum, 1 / #neighbours), amount or 0.5)
		end
		for vert, p in moved do
			self.verts[vert].position = p
		end
	end
	return self
end

-- Moves vertices along their normals (negative to shrink).
function EditMesh:push(selection, distance)
	local moves = {}
	for vert in asVerts(self, selection).ids do
		moves[vert] = vec.add(self.verts[vert].position, vec.scale(self:vertexNormal(vert), distance))
	end
	for vert, p in moves do
		self.verts[vert].position = p
	end
	return self
end

-- Pulls a loop (or any set) of vertices round into a circle in their own
-- plane, about their middle, at their average distance from it.
function EditMesh:toCircle(selection, amount)
	local verts = sortedKeys(selection:verts().ids)
	local centre = { 0, 0, 0 }
	for _, vert in verts do
		centre = vec.add(centre, self.verts[vert].position)
	end
	centre = vec.scale(centre, 1 / #verts)
	-- The plane: the normal from summing cross products round the centre.
	local normal = { 0, 0, 0 }
	for index, vert in verts do
		local p = vec.sub(self.verts[vert].position, centre)
		local q = vec.sub(self.verts[verts[index % #verts + 1]].position, centre)
		local n = vec.cross(p, q)
		if vec.dot(n, normal) < 0 then
			n = vec.scale(n, -1)
		end
		normal = vec.add(normal, n)
	end
	normal = vec.unit(normal)
	local radius = 0
	for _, vert in verts do
		local d = vec.sub(self.verts[vert].position, centre)
		d = vec.sub(d, vec.scale(normal, vec.dot(d, normal)))
		radius += vec.length(d)
	end
	radius /= #verts
	for _, vert in verts do
		local p = self.verts[vert].position
		local d = vec.sub(p, centre)
		local inPlane = vec.sub(d, vec.scale(normal, vec.dot(d, normal)))
		local target = vec.add(centre, vec.scale(vec.unit(inPlane), radius))
		self.verts[vert].position = vec.lerp(p, target, amount or 1)
	end
	return selection
end

-- Pulls vertices towards a sphere about their middle (amount 1: all the
-- way), at their average distance from it, or `radius`.
function EditMesh:toSphere(selection, amount, radius)
	local verts = sortedKeys(asVerts(self, selection).ids)
	local centre = { 0, 0, 0 }
	for _, vert in verts do
		centre = vec.add(centre, self.verts[vert].position)
	end
	centre = vec.scale(centre, 1 / #verts)
	if not radius then
		radius = 0
		for _, vert in verts do
			radius += vec.length(vec.sub(self.verts[vert].position, centre))
		end
		radius /= #verts
	end
	for _, vert in verts do
		local p = self.verts[vert].position
		local target = vec.add(centre, vec.scale(vec.unit(vec.sub(p, centre)), radius))
		self.verts[vert].position = vec.lerp(p, target, amount or 1)
	end
	return self
end

-- ---------------------------------------------------------------- bevel

-- Bevels edges: each selected edge becomes a strip `width` wide on each of
-- its two faces, flat (segments 1) or rounded (more). Edges that meet at a
-- vertex aren't joined there: bevel one edge per corner at a time, or use
-- creases with smoothSubdivide, or a rounded box, to round every edge of a
-- block. Returns the strip faces.
function EditMesh:bevel(edges, width, segments)
	segments = segments or 1
	local made = {}
	for _, edge in sortedKeys(edges:edges().ids) do
		local e = self.edges[edge]
		if not e then
			continue
		end
		local faces = sortedKeys(self.edgeFaces[edge])
		if #faces ~= 2 then
			continue
		end
		local a, b = e.a, e.b
		local pa, pb = self.verts[a].position, self.verts[b].position
		-- In each face, the corner next to a and to b away from the edge.
		local function awayFrom(face, vert, other)
			local verts = self.faces[face].verts
			local index = table.find(verts, vert)
			local before, after = verts[(index - 2) % #verts + 1], verts[index % #verts + 1]
			return if before == other then after else before
		end
		local sides = {}
		for _, face in faces do
			local na, nb = awayFrom(face, a, b), awayFrom(face, b, a)
			local da = vec.unit(vec.sub(self.verts[na].position, pa))
			local db = vec.unit(vec.sub(self.verts[nb].position, pb))
			table.insert(sides, { face = face, da = da, db = db })
		end
		-- New corners: a1/b1 into face 1, a2/b2 into face 2.
		local a1p, b1p = vec.add(pa, vec.scale(sides[1].da, width)), vec.add(pb, vec.scale(sides[1].db, width))
		local a2p, b2p = vec.add(pa, vec.scale(sides[2].da, width)), vec.add(pb, vec.scale(sides[2].db, width))
		-- Rows across the strip from side 1 to side 2: straight for a chamfer,
		-- bowed out towards the old edge for a round.
		local rowsA, rowsB = {}, {}
		for k = 0, segments do
			local t = k / segments
			local qa = vec.lerp(a1p, a2p, t)
			local qb = vec.lerp(b1p, b2p, t)
			if segments > 1 then
				-- Quadratic Bezier with the old corner as the control point.
				local s = 1 - t
				qa = vec.add(vec.add(vec.scale(a1p, s * s), vec.scale(pa, 2 * s * t)), vec.scale(a2p, t * t))
				qb = vec.add(vec.add(vec.scale(b1p, s * s), vec.scale(pb, 2 * s * t)), vec.scale(b2p, t * t))
			end
			rowsA[k] = self:addVertex(qa[1], qa[2], qa[3])
			rowsB[k] = self:addVertex(qb[1], qb[2], qb[3])
		end
		self:rebuilding(function()
			-- Face 1 and 2 lose the old edge's corners for the strip's sides.
			for index, side in sides do
				local verts = table.clone(self.faces[side.face].verts)
				local edgeA = if index == 1 then rowsA[0] else rowsA[segments]
				local edgeB = if index == 1 then rowsB[0] else rowsB[segments]
				for i, vert in verts do
					if vert == a then
						verts[i] = edgeA
					elseif vert == b then
						verts[i] = edgeB
					end
				end
				self:replaceFace(side.face, verts)
			end
			-- Other faces at a and b take the strip's end rows in a's place.
			for _, pair in { { a, rowsA }, { b, rowsB } } do
				local vert, rows = pair[1], pair[2]
				for _, face in sortedKeys(self.vertFaces[vert] or {}) do
					local verts = self.faces[face].verts
					local index = table.find(verts, vert)
					local before, after = verts[(index - 2) % #verts + 1], verts[index % #verts + 1]
					-- The row runs from the end that touches `before`.
					local list = {}
					for k = 0, segments do
						table.insert(list, rows[k])
					end
					if self:edge(before, rows[segments]) or self:edge(rows[0], after) then
						local reversed = {}
						for k = #list, 1, -1 do
							table.insert(reversed, list[k])
						end
						list = reversed
					end
					local replaced = {}
					for i, v in verts do
						if v == vert then
							for _, r in list do
								table.insert(replaced, r)
							end
						else
							table.insert(replaced, v)
						end
					end
					self:replaceFace(face, replaced)
				end
			end
			-- The strip itself, wound to match face 1 (it runs rowsA[k] -> rowsB[k]
			-- the way face 1 ran a -> b).
			local verts1 = self.faces[sides[1].face].verts
			local i1 = table.find(verts1, rowsA[0])
			local forward = verts1[i1 % #verts1 + 1] == rowsB[0]
			for k = 0, segments - 1 do
				local quad = if forward
					then { rowsA[k + 1], rowsB[k + 1], rowsB[k], rowsA[k] }
					else { rowsB[k + 1], rowsA[k + 1], rowsA[k], rowsB[k] }
				local id = self:addFace(quad)
				made[id] = true
			end
		end)
		-- The old edge's corners belong to no face now.
		for _, vert in { a, b } do
			if self.verts[vert] and next(self.vertFaces[vert]) == nil then
				self.verts[vert] = nil
				self.vertFaces[vert] = nil
				self.vertEdges[vert] = nil
			end
		end
	end
	return setmetatable({ mesh = self, kind = "face", ids = made }, EditMesh.Selection)
end

-- ---------------------------------------------------------------- whole-mesh tools

-- Appends a copy of another mesh into this one. Returns the copy's faces.
function EditMesh:append(other)
	local map, made = {}, {}
	for _, vert in sortedKeys(other.verts) do
		local p = other.verts[vert].position
		map[vert] = self:addVertex(p[1], p[2], p[3])
	end
	for _, face in sortedKeys(other.faces) do
		local verts = {}
		for index, vert in other.faces[face].verts do
			verts[index] = map[vert]
		end
		made[self:addFace(verts, other.faces[face].tags)] = true
	end
	for _, edge in sortedKeys(other.edges) do
		local e = other.edges[edge]
		local mine = self:edge(map[e.a], map[e.b])
		if mine then
			self.edges[mine].crease = e.crease
		end
	end
	return setmetatable({ mesh = self, kind = "face", ids = made }, EditMesh.Selection)
end

-- Mirrors across the plane where `axis` (x, y or z) equals `at` (default
-- 0): adds a flipped copy and welds the seam, for shapes built one side at
-- a time. Faces lying on the plane should be removed first (the seam is
-- then an open rim the two halves close up).
function EditMesh:mirror(axis, at, distance)
	local k = AXES[axis or "x"]
	at = at or 0
	local half = self:copy()
	half:transform(function(p)
		p[k] = 2 * at - p[k]
		return p
	end)
	half:flip()
	local made = self:append(half)
	self:weld(distance or 1e-4)
	return made
end

-- Gives an open sheet thickness: an offset copy along the vertex normals
-- (inward for negative), turned over, joined to the sheet round its rims.
function EditMesh:solidify(thickness)
	local inner = self:copy()
	local normals = {}
	for vert in self.verts do
		normals[vert] = self:vertexNormal(vert)
	end
	local ids = sortedKeys(self.verts)
	local innerIds = sortedKeys(inner.verts)
	for index, vert in ids do
		local p = inner.verts[innerIds[index]].position
		inner.verts[innerIds[index]].position = vec.sub(p, vec.scale(normals[vert], thickness))
	end
	local rims = {}
	for edge, _ in self.edges do
		if self:count(self.edgeFaces[edge]) == 1 then
			rims[edge] = true
		end
	end
	inner:flip()
	local before = self.nextVert
	self:append(inner)
	-- Join each rim edge to its copy: vertices map by order of creation.
	local offset = {}
	for index, vert in ids do
		offset[vert] = before + index - 1
	end
	for edge in rims do
		local e = self.edges[edge]
		local face = sortedKeys(self.edgeFaces[edge])[1]
		local verts = self.faces[face].verts
		local i = table.find(verts, e.a)
		local a, b = e.a, e.b
		if verts[i % #verts + 1] ~= e.b then
			a, b = e.b, e.a
		end
		self:addFace({ b, a, offset[a], offset[b] })
	end
	return self
end

-- Adds `count - 1` copies, each `offset` ({x, y, z}) on from the last.
function EditMesh:array(count, offset, weldDistance)
	local base = self:copy()
	for k = 1, count - 1 do
		local piece = base:copy()
		piece:transform(function(p)
			return vec.add(p, vec.scale(offset, k))
		end)
		self:append(piece)
	end
	if weldDistance then
		self:weld(weldDistance)
	end
	return self
end
-- Edit Shapes: starting shapes for an Edit Mesh, each built with
-- four-sided faces (no triangle fans at caps or poles) so every operation
-- works on them. Include after EditMesh and EditOps: `-- include: EditShapes`.
--
-- Every shape is centred on the origin unless it says otherwise; move it
-- with m:translate. Sizes are studs, z up.
--
--   EditMesh.box({sx, sy, sz}, {nx, ny, nz})        cuts per side, default 1
--   EditMesh.lattice(xs, ys, zs)                    a box with cuts at the
--                                                   given coordinates
--   EditMesh.roundedBox({sx, sy, sz}, radius, segments, {nx, ny, nz})
--                                                   cuts across the flat faces
--   EditMesh.grid(sx, sy, nx, ny)                   flat, facing +z, open
--   EditMesh.disk(radius, sides)                    flat, facing +z, open
--   EditMesh.circle(radius, sides)                  one face, facing +z
--   EditMesh.cylinder(radius, height, sides, rings) sides a multiple of 4
--   EditMesh.cone(bottom, top, height, sides, rings)
--   EditMesh.sphere(radius, segments)
--   EditMesh.capsule(radius, length, segments)
--   EditMesh.torus(major, minor, sides, ringSides)
--   EditMesh.tube(outer, inner, height, sides)      a pipe with thickness
--   EditMesh.prism(sides, radius, height)           n-sided caps
--   EditMesh.wedge({sx, sy, sz})                    slopes up toward +y
--   EditMesh.arch(radius, thickness, depth, segments) a half ring over x
--   EditMesh.spin(profile, sides, degrees)          lathe a {r, z} profile
--   EditMesh.sweep(profile, path, options)          a {u, v} outline along
--                                                   a path of {x, y, z}
--   EditMesh.coil(radius, wire, turns, pitch, sides, steps)

local function shapeRange(low, high, cuts)
	local list = {}
	for i = 0, cuts do
		list[i + 1] = low + (high - low) * i / cuts
	end
	return list
end

function EditMesh:translate(x, y, z)
	return self:transform(function(p)
		return { p[1] + x, p[2] + y, p[3] + z }
	end)
end

-- The surface of a box whose cuts fall at the given coordinates along each
-- axis (each list low to high).
function EditMesh.lattice(xs, ys, zs)
	local m = EditMesh.new()
	local nx, ny, nz = #xs - 1, #ys - 1, #zs - 1
	local ids = {}
	local function at(i, j, k)
		local key = i .. "," .. j .. "," .. k
		if not ids[key] then
			ids[key] = m:addVertex(xs[i + 1], ys[j + 1], zs[k + 1])
		end
		return ids[key]
	end
	for i = 0, nx - 1 do
		for j = 0, ny - 1 do
			m:addFace({ at(i, j, 0), at(i, j + 1, 0), at(i + 1, j + 1, 0), at(i + 1, j, 0) })
			m:addFace({ at(i, j, nz), at(i + 1, j, nz), at(i + 1, j + 1, nz), at(i, j + 1, nz) })
		end
	end
	for i = 0, nx - 1 do
		for k = 0, nz - 1 do
			m:addFace({ at(i, 0, k), at(i + 1, 0, k), at(i + 1, 0, k + 1), at(i, 0, k + 1) })
			m:addFace({ at(i, ny, k), at(i, ny, k + 1), at(i + 1, ny, k + 1), at(i + 1, ny, k) })
		end
	end
	for j = 0, ny - 1 do
		for k = 0, nz - 1 do
			m:addFace({ at(0, j, k), at(0, j, k + 1), at(0, j + 1, k + 1), at(0, j + 1, k) })
			m:addFace({ at(nx, j, k), at(nx, j + 1, k), at(nx, j + 1, k + 1), at(nx, j, k + 1) })
		end
	end
	return m
end

function EditMesh.box(size, cuts)
	size = size or { 1, 1, 1 }
	cuts = cuts or { 1, 1, 1 }
	return EditMesh.lattice(
		shapeRange(-size[1] / 2, size[1] / 2, cuts[1]),
		shapeRange(-size[2] / 2, size[2] / 2, cuts[2]),
		shapeRange(-size[3] / 2, size[3] / 2, cuts[3])
	)
end

-- A box with its edges and corners rounded to `radius`, in `segments`
-- quads round each edge, its flat faces cut `cuts` times along each axis.
function EditMesh.roundedBox(size, radius, segments, cuts)
	segments = segments or 3
	cuts = cuts or { 1, 1, 1 }
	local axisIndex = 0
	local function axis(length)
		axisIndex += 1
		local h = length / 2
		local r = math.min(radius, h)
		local list = {}
		for k = 0, segments do
			table.insert(list, -h + r * k / segments)
		end
		if h - r > -h + r + 1e-9 then
			local middle = cuts[axisIndex]
			for k = 1, middle do
				table.insert(list, -h + r + (2 * (h - r)) * k / middle)
			end
		end
		for k = 1, segments do
			table.insert(list, h - r + r * k / segments)
		end
		return list, h - r
	end
	local xs, ix = axis(size[1])
	local ys, iy = axis(size[2])
	local zs, iz = axis(size[3])
	local m = EditMesh.lattice(xs, ys, zs)
	local inner = { ix, iy, iz }
	m:transform(function(p)
		local core = {}
		for a = 1, 3 do
			core[a] = math.clamp(p[a], -inner[a], inner[a])
		end
		local out = EditMesh.vec.sub(p, core)
		if EditMesh.vec.length(out) < 1e-9 then
			return p
		end
		return EditMesh.vec.add(core, EditMesh.vec.scale(EditMesh.vec.unit(out), math.min(radius, size[1] / 2, size[2] / 2, size[3] / 2)))
	end)
	m:weld(1e-7)
	return m
end

-- A flat open sheet sx by sy at z = 0, facing +z.
function EditMesh.grid(sx, sy, nx, ny)
	nx, ny = nx or 1, ny or 1
	local m = EditMesh.new()
	local ids = {}
	for j = 0, ny do
		for i = 0, nx do
			ids[i .. "," .. j] = m:addVertex(-sx / 2 + sx * i / nx, -sy / 2 + sy * j / ny, 0)
		end
	end
	for j = 0, ny - 1 do
		for i = 0, nx - 1 do
			m:addFace({ ids[i .. "," .. j], ids[(i + 1) .. "," .. j], ids[(i + 1) .. "," .. (j + 1)], ids[i .. "," .. (j + 1)] })
		end
	end
	return m
end

-- Maps a point of the square [-1, 1]^2 onto the unit disk, keeping grid
-- lines smooth (so a square grid becomes a round one of quads).
local function squareToDisk(x, y)
	return x * math.sqrt(math.max(0, 1 - y * y / 2)), y * math.sqrt(math.max(0, 1 - x * x / 2))
end

-- A flat open disk of quads at z = 0, facing +z: `sides` round the rim (a
-- multiple of 4).
function EditMesh.disk(radius, sides)
	local n = math.max(1, (sides or 16) // 4)
	local m = EditMesh.grid(2, 2, n, n)
	return m:transform(function(p)
		local x, y = squareToDisk(p[1], p[2])
		return { x * radius, y * radius, 0 }
	end)
end

-- One flat face with `sides` corners at z = 0, facing +z (to extrude from).
function EditMesh.circle(radius, sides)
	local m = EditMesh.new()
	local verts = {}
	for k = 0, sides - 1 do
		local t = k / sides * 2 * math.pi
		verts[k + 1] = m:addVertex(math.cos(t) * radius, math.sin(t) * radius, 0)
	end
	m:addFace(verts)
	return m
end

-- A cylinder along z: caps of quads, `sides` round (a multiple of 4),
-- `rings` cuts along its height.
function EditMesh.cylinder(radius, height, sides, rings)
	local n = math.max(1, (sides or 16) // 4)
	local m = EditMesh.box({ 2, 2, height }, { n, n, rings or 1 })
	return m:transform(function(p)
		local x, y = squareToDisk(math.clamp(p[1], -1, 1), math.clamp(p[2], -1, 1))
		return { x * radius, y * radius, p[3] }
	end)
end

-- A cylinder whose radius runs from `bottom` to `top` (top may be small,
-- never zero: cap it with a point by poking the top face if needed).
function EditMesh.cone(bottom, top, height, sides, rings)
	local m = EditMesh.cylinder(1, height, sides, rings)
	return m:transform(function(p)
		local t = (p[3] + height / 2) / height
		local r = bottom + (top - bottom) * t
		return { p[1] * r, p[2] * r, p[3] }
	end)
end

-- A sphere of quads: a cut box pulled round evenly.
function EditMesh.sphere(radius, segments)
	local n = math.max(1, (segments or 16) // 4)
	local m = EditMesh.box({ 2, 2, 2 }, { n, n, n })
	return m:transform(function(p)
		local x, y, z = p[1], p[2], p[3]
		local x2, y2, z2 = x * x, y * y, z * z
		return {
			radius * x * math.sqrt(math.max(0, 1 - y2 / 2 - z2 / 2 + y2 * z2 / 3)),
			radius * y * math.sqrt(math.max(0, 1 - z2 / 2 - x2 / 2 + z2 * x2 / 3)),
			radius * z * math.sqrt(math.max(0, 1 - x2 / 2 - y2 / 2 + x2 * y2 / 3)),
		}
	end)
end

-- A pill along z: a sphere split at its middle and drawn apart by `length`.
function EditMesh.capsule(radius, length, segments)
	segments = segments or 16
	-- An even number of cuts puts a ring exactly on the equator.
	local n = math.max(2, (segments // 4) // 2 * 2)
	local m = EditMesh.sphere(radius, n * 4)
	m:transform(function(p)
		if p[3] > 1e-9 then
			return { p[1], p[2], p[3] + length / 2 }
		elseif p[3] < -1e-9 then
			return { p[1], p[2], p[3] - length / 2 }
		end
		return p
	end)
	return m
end

-- A ring: `major` from the centre to the middle of the tube, `minor` the
-- tube's radius, in the xy plane.
function EditMesh.torus(major, minor, sides, ringSides)
	sides, ringSides = sides or 24, ringSides or 12
	local m = EditMesh.new()
	local ids = {}
	for i = 0, sides - 1 do
		local u = i / sides * 2 * math.pi
		for j = 0, ringSides - 1 do
			local v = j / ringSides * 2 * math.pi
			local r = major + minor * math.cos(v)
			ids[i * ringSides + j] = m:addVertex(r * math.cos(u), r * math.sin(u), minor * math.sin(v))
		end
	end
	for i = 0, sides - 1 do
		local i2 = (i + 1) % sides
		for j = 0, ringSides - 1 do
			local j2 = (j + 1) % ringSides
			m:addFace({ ids[i * ringSides + j], ids[i2 * ringSides + j], ids[i2 * ringSides + j2], ids[i * ringSides + j2] })
		end
	end
	return m
end

-- A pipe along z with a wall: `outer` and `inner` radii.
function EditMesh.tube(outer, inner, height, sides)
	sides = sides or 16
	local m = EditMesh.new()
	local rings = {}
	-- Four rings round the section: outer bottom, outer top, inner top, inner bottom.
	local section = { { outer, -height / 2 }, { outer, height / 2 }, { inner, height / 2 }, { inner, -height / 2 } }
	for i = 0, sides - 1 do
		local t = i / sides * 2 * math.pi
		rings[i] = {}
		for k, point in section do
			rings[i][k] = m:addVertex(math.cos(t) * point[1], math.sin(t) * point[1], point[2])
		end
	end
	for i = 0, sides - 1 do
		local a, b = rings[i], rings[(i + 1) % sides]
		for k = 1, 4 do
			local k2 = k % 4 + 1
			m:addFace({ a[k], b[k], b[k2], a[k2] })
		end
	end
	return m
end

-- An upright prism with n-sided caps.
function EditMesh.prism(sides, radius, height)
	local m = EditMesh.circle(radius, sides)
	m:translate(0, 0, -height / 2)
	-- Lifting the cap makes the sides; the hole it leaves below is closed.
	m:extrude(m:select("face", "all"), { 0, 0, height })
	m:fill(m:select("edge", "where", function(p)
		return p[3] < 0
	end))
	return m
end

-- A wedge: a box whose top slopes from nothing at -y to full height at +y.
function EditMesh.wedge(size)
	local sx, sy, sz = size[1] / 2, size[2] / 2, size[3]
	local m = EditMesh.new()
	local a = m:addVertex(-sx, -sy, 0)
	local b = m:addVertex(sx, -sy, 0)
	local c = m:addVertex(sx, sy, 0)
	local d = m:addVertex(-sx, sy, 0)
	local e = m:addVertex(-sx, sy, sz)
	local f = m:addVertex(sx, sy, sz)
	m:addFace({ a, d, c, b }) -- bottom
	m:addFace({ d, e, f, c }) -- back (+y)
	m:addFace({ a, b, f, e }) -- slope
	m:addFace({ a, e, d }) -- left
	m:addFace({ b, c, f }) -- right
	return m
end

-- A half ring standing over the x axis, its ends on the ground at
-- x = +-(radius + thickness): inner radius `radius`, `thickness` thick,
-- `depth` deep along y, in `segments` quads round.
function EditMesh.arch(radius, thickness, depth, segments)
	segments = segments or 12
	local m = EditMesh.box({ 1, depth, thickness }, { segments, 1, 1 })
	m:transform(function(p)
		local angle = (p[1] + 0.5) * math.pi
		local r = radius + p[3] + thickness / 2
		return { r * math.cos(angle), p[2], r * math.sin(angle) }
	end)
	-- The map turns the box inside out; turn it back.
	m:flip()
	return m
end

-- Lathe: turns a profile of {r, z} points (bottom to top) about z. A full
-- turn closes up; ends on the axis (r = 0) close with a point.
function EditMesh.spin(profile, sides, degrees)
	sides = sides or 16
	degrees = degrees or 360
	local full = degrees >= 360 - 1e-9
	local steps = if full then sides else sides + 1
	local m = EditMesh.new()
	local columns = {}
	for s = 0, steps - 1 do
		local t = math.rad(degrees) * s / sides
		columns[s] = {}
		for k, point in profile do
			if point[1] < 1e-9 and s > 0 then
				columns[s][k] = columns[0][k]
			else
				columns[s][k] = m:addVertex(point[1] * math.cos(t), point[1] * math.sin(t), point[2])
			end
		end
	end
	local last = if full then steps - 1 else steps - 2
	for s = 0, last do
		local a, b = columns[s], columns[(s + 1) % steps]
		for k = 1, #profile - 1 do
			local quad = { a[k], b[k], b[k + 1], a[k + 1] }
			local unique, seen = {}, {}
			for _, vert in quad do
				if not seen[vert] then
					seen[vert] = true
					table.insert(unique, vert)
				end
			end
			if #unique >= 3 then
				m:addFace(unique)
			end
		end
	end
	return m
end

-- A frame along a path that turns as little as it can (parallel
-- transport), as {tangent, normal, binormal} per point.
local function pathFrames(path, closed)
	local frames = {}
	local count = #path
	local function tangent(i)
		local prev = path[if i > 1 then i - 1 elseif closed then count else i]
		local nxt = path[if i < count then i + 1 elseif closed then 1 else i]
		return EditMesh.vec.unit(EditMesh.vec.sub(nxt, prev))
	end
	local t = tangent(1)
	local helper = if math.abs(t[3]) < 0.9 then { 0, 0, 1 } else { 1, 0, 0 }
	local n = EditMesh.vec.unit(EditMesh.vec.cross(helper, t))
	for i = 1, count do
		local ti = tangent(i)
		-- Remove the part of the last normal along the new tangent.
		n = EditMesh.vec.unit(EditMesh.vec.sub(n, EditMesh.vec.scale(ti, EditMesh.vec.dot(n, ti))))
		frames[i] = { ti, n, EditMesh.vec.cross(ti, n) }
	end
	return frames
end

-- Sweeps an outline of {u, v} points (counter-clockwise looking down the
-- path) along a path of {x, y, z} points. options.closed joins the path
-- into a loop; otherwise each end gets a cap face (options.caps = false
-- leaves them open). options.scale(t) sizes the outline along the path
-- (t from 0 to 1), options.twist degrees over its length.
function EditMesh.sweep(profile, path, options)
	options = options or {}
	local m = EditMesh.new()
	local frames = pathFrames(path, options.closed)
	local rings = {}
	for i, point in path do
		local t = (i - 1) / math.max(1, #path - 1)
		local size = if options.scale then options.scale(t) else 1
		local turn = math.rad((options.twist or 0) * t)
		local c, s = math.cos(turn), math.sin(turn)
		local frame = frames[i]
		rings[i] = {}
		for k, uv in profile do
			local u = (uv[1] * c - uv[2] * s) * size
			local v = (uv[1] * s + uv[2] * c) * size
			local p = EditMesh.vec.add(point, EditMesh.vec.add(EditMesh.vec.scale(frame[2], u), EditMesh.vec.scale(frame[3], v)))
			rings[i][k] = m:addVertex(p[1], p[2], p[3])
		end
	end
	local count = #path
	local segments = if options.closed then count else count - 1
	for i = 1, segments do
		local a, b = rings[i], rings[i % count + 1]
		for k = 1, #profile do
			local k2 = k % #profile + 1
			m:addFace({ a[k], a[k2], b[k2], b[k] })
		end
	end
	if not options.closed and options.caps ~= false then
		local first, lastRing = {}, {}
		for k = #profile, 1, -1 do
			table.insert(first, rings[1][k])
		end
		for k = 1, #profile do
			table.insert(lastRing, rings[count][k])
		end
		m:addFace(first)
		m:addFace(lastRing)
	end
	return m
end

-- A coil spring: `turns` turns of radius `radius` rising `pitch` per turn,
-- wound from wire `wire` thick with `sides` round it.
function EditMesh.coil(radius, wire, turns, pitch, sides, steps)
	sides, steps = sides or 8, steps or 24
	local path = {}
	local total = math.ceil(turns * steps)
	for i = 0, total do
		local t = i / steps * 2 * math.pi
		table.insert(path, { radius * math.cos(t), radius * math.sin(t), pitch * i / steps })
	end
	local outline = {}
	for k = 0, sides - 1 do
		local t = k / sides * 2 * math.pi
		table.insert(outline, { math.cos(t) * wire, math.sin(t) * wire })
	end
	return EditMesh.sweep(outline, path)
end
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
local TIN_BLUE = { 0.4, 0.5, 0.6 }
local BELLY = { 0.88, 0.89, 0.86 }
local MIDDLE = 1.3 -- the body's axis: it sits low, on its fins
local SNEAKER_BLUE = { 0.14, 0.46, 0.92 }
-- The three bottom fins wear the sneakers: the two pectorals and the fin
-- under the tail, ordinary fins angled down so their tips reach the
-- ground. Each: where its root sits on the body, its outline's chord and
-- span, which side it points to (0 for the middle), how far it points
-- down (degrees below level) and how far it sweeps back.
local SHOD = {
	{ root = { 1.0, -0.3, -0.3 }, chord = 0.55, span = 0.95, side = -1, down = 68, back = 15 },
	{ root = { 1.0, 0.3, -0.3 }, chord = 0.55, span = 0.95, side = 1, down = 68, back = 15 },
	{ root = { -0.7, 0, -0.22 }, chord = 0.4, span = 0.62, side = 0, down = 82, back = 12 },
}
-- Turns a point as a shod fin is turned (Kit.turn's rotations): the span
-- runs up +z on the outline; it is tipped over to point down, tilted out
-- to its side and swept back.
local function finTurn(f, p)
	local function turnX(q, deg)
		local c, s = math.cos(math.rad(deg)), math.sin(math.rad(deg))
		return { q[1], q[2] * c - q[3] * s, q[2] * s + q[3] * c }
	end
	local function turnY(q, deg)
		local c, s = math.cos(math.rad(deg)), math.sin(math.rad(deg))
		return { q[1] * c + q[3] * s, q[2], -q[1] * s + q[3] * c }
	end
	local out = (90 - f.down) * (if f.side == 0 then 1 else f.side)
	local q = turnX(p, 180)
	q = turnX(q, out)
	q = turnY(q, f.back)
	return { q[1] + f.root[1], q[2] + f.root[2], q[3] + MIDDLE + f.root[3] }
end
local function shodTip(f)
	return finTurn(f, { 0, 0, f.span })
end
-- The body's lines along x, tail root to nose tip: the back's height, the
-- belly's depth and the half width, read off these stations between;
-- eased, except along the snout, which runs straight to its rounded tip.
-- The back arches over a belly that runs nearly level, and the snout
-- tapers to a point a little below the axis.
local STATIONS = { -- x, top, bottom, half width
	{ -1.7, 0.1, -0.08, 0.07 },
	{ -1.3, 0.2, -0.14, 0.13 },
	{ -0.8, 0.36, -0.24, 0.23 },
	{ -0.3, 0.48, -0.34, 0.33 },
	{ 0.2, 0.56, -0.4, 0.4 },
	{ 0.7, 0.58, -0.42, 0.43 },
	{ 1.1, 0.52, -0.42, 0.42 },
	{ 1.4, 0.47, -0.42, 0.4 },
	{ 1.7, 0.34, -0.37, 0.33 },
	{ 2.0, 0.16, -0.28, 0.22 },
	{ 2.2, -0.02, -0.16, 0.09 },
	{ 2.3, -0.08, -0.12, 0.03 },
}
local SNOUT = 1.4
local function station(x)
	local function mix(a, b, t)
		return { a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t }
	end
	for k = 1, #STATIONS - 1 do
		local a, b = STATIONS[k], STATIONS[k + 1]
		if x <= b[1] then
			local t = math.clamp((x - a[1]) / (b[1] - a[1]), 0, 1)
			if a[1] < SNOUT then
				t = t * t * (3 - 2 * t)
			end
			return table.unpack(mix(a, b, t))
		end
	end
	local last = STATIONS[#STATIONS]
	return last[2], last[3], last[4]
end
-- How far up the section the white belly reaches, in degrees from the
-- bottom, along x: to the mid flank at the chest, lower toward the tail
-- root, and nearly to the eye on the head.
local REACH = { { -1.7, 25 }, { -1.0, 55 }, { -0.3, 85 }, { 0.5, 100 }, { 1.3, 100 }, { 2.0, 102 }, { 2.3, 95 } }
local function reach(x)
	for k = 1, #REACH - 1 do
		local a, b = REACH[k], REACH[k + 1]
		if x <= b[1] then
			local t = math.clamp((x - a[1]) / (b[1] - a[1]), 0, 1)
			return a[2] + (b[2] - a[2]) * (t * t * (3 - 2 * t))
		end
	end
	return REACH[#REACH][2]
end
-- The mouth: a parabola on the underside of the head from its corners,
-- back under the eyes, round the front short of the snout tip. Its rim
-- sits on the skin at mouthAngle(x) round the section; the lower jaw is
-- the head's bottom slice under it, split off along a flat plane at the
-- corners' height and hinged there.
local CORNER = { x = 1.5, spread = 0.85 } -- the corners: x, and y as a share of the width there
local MOUTH_REACH = 0.6 -- how far ahead of the corners the rim goes
local function mouthAngle(x) -- the rim's angle round the section, from the top; nil outside
	local along = (x - CORNER.x) / MOUTH_REACH
	if along <= 0 or along >= 1 then
		return nil
	end
	local a = math.acos(along ^ 1.25)
	return 180 - math.deg(math.asin(CORNER.spread * math.sin(a)))
end
-- A point of the skin: x along, a the ring's nominal angle round the
-- section (0 at the top, 180 at the bottom, either sign for the side),
-- from the body's axis. The ring's spacing is warped so that its vertex at
-- nominal 90 sits exactly on the belly line, whatever the reach there, and
-- the one at nominal 150 on the mouth's rim where there is one: the
-- splits along both then follow true edge loops.
local function skin(x, a)
	local top, bottom, w = station(x)
	local side = if a < 0 then -1 else 1
	local n = math.abs(a)
	local line = 180 - reach(x)
	local rim = mouthAngle(x) or (line + 150 / 180 * (180 - line) - line) -- without a mouth, 150 stays in its natural place
	if not mouthAngle(x) then
		rim = line + (150 - 90) / 90 * (180 - line)
	end
	local actual
	if n <= 90 then
		actual = n / 90 * line
	elseif n <= 150 then
		actual = line + (n - 90) / 60 * (rim - line)
	else
		actual = rim + (n - 150) / 30 * (180 - rim)
	end
	local r = math.rad(actual)
	local c = math.cos(r)
	local mid = (top + bottom) / 2
	return { x, side * math.sin(r) * w, mid + c * (if c > 0 then top - mid else mid - bottom) }
end
local function skinZ(x, a) -- from the axis, in the model's frame
	return skin(x, a)[3]
end
-- The skin's outward direction at x, a, from neighbouring points.
local function skinNormal(x, a)
	local p = skin(x, a)
	local px, pa = skin(x + 0.01, a), skin(x, a + 0.5)
	local u = { px[1] - p[1], px[2] - p[2], px[3] - p[3] }
	local v = { pa[1] - p[1], pa[2] - p[2], pa[3] - p[3] }
	local n = { u[2] * v[3] - u[3] * v[2], u[3] * v[1] - u[1] * v[3], u[1] * v[2] - u[2] * v[1] }
	local len = math.sqrt(n[1] ^ 2 + n[2] ^ 2 + n[3] ^ 2)
	n = { n[1] / len, n[2] / len, n[3] / len }
	-- Outward: away from the axis.
	local mid = select(1, station(x)) + select(2, station(x))
	local away = { 0, p[2], p[3] - mid / 2 }
	if n[1] * away[1] + n[2] * away[2] + n[3] * away[3] < 0 then
		n = { -n[1], -n[2], -n[3] }
	end
	return p, n
end
local function onSkin(x, a, lift)
	local p, n = skinNormal(x, a)
	return { p[1] + n[1] * lift, p[2] + n[2] * lift, p[3] + n[3] * lift + MIDDLE }
end
-- The roof of the mouth, the plane the jaw splits off along: the rim's
-- height at the corners, a touch up.
local ROOF = skinZ(CORNER.x + 0.001, 150) + 0.03
local GAPE = 14 -- degrees the jaw hangs open: a grin, the teeth showing

local function shark()
	local ring, path = {}, {}
	for k = 0, 23 do
		local r = math.rad(k * 15)
		table.insert(ring, { -math.sin(r), math.cos(r) })
	end
	for k = 0, 80 do
		table.insert(path, { -1.7 + 4.0 * k / 80, 0, 0 })
	end
	local m = EditMesh.sweep(ring, path)
	-- The belly's faces: those below the ring's equator, picked on the bare
	-- tube so the split is exactly along its vertex row.
	m:tagging("belly", function()
		m:select("face", "where", function(p)
			return p[3] < 0 and p[1] > -1.69 and p[1] < 2.29
		end):tag("belly")
	end)
	-- The mouth's faces: below the ring's vertex at nominal 150, between the
	-- corners and the front, picked on the bare tube too.
	m:tagging("mouth", function()
		m:select("face", "where", function(p)
			return p[3] < math.cos(math.rad(150)) and mouthAngle(p[1]) ~= nil and mouthAngle(p[1] - 0.025) ~= nil and mouthAngle(p[1] + 0.025) ~= nil
		end):tag("mouth")
	end)
	m:transform(function(p)
		local a = math.deg(math.atan2(p[2], p[3]))
		return skin(p[1], a)
	end)
	-- Eye sockets, sunk into the sides of the head over the mouth's front.
	for _, side in { -1, 1 } do
		local socket = m:select("face", "facing", { 0, side, 0.35 }, 24):filter(function(p)
			return p[1] > 1.66 and p[1] < 1.88 and p[3] > -0.06 and p[3] < 0.22
		end)
		if socket:count() > 0 then
			m:extrude(m:inset(socket, 0.015, 0), -0.05)
		end
	end
	-- The nostrils under the snout, recessed.
	for _, side in { -1, 1 } do
		local nare = m:select("face", "facing", { 0, 0, -1 }, 50):filter(function(p)
			return p[1] > 2.1 and p[1] < 2.17 and p[2] * side > 0.02 and p[2] * side < 0.08
		end)
		if nare:count() > 0 then
			Kit.recess(m, nare, 0.008, 0.02)
		end
	end
	m:translate(0, 0, MIDDLE)
	return m
end
local body = shark()
-- The belly line: the skin is split along it into the white belly and the
-- grey-blue back, each given its own thickness inward.
local function skinPart(m, belly)
	local keep = m:select("face", "tag", "belly")
	if not belly then
		keep = m:select("face", "all"):minus(keep)
	end
	keep = keep:minus(m:select("face", "tag", "mouth"))
	for _, id in m:select("face", "all"):minus(keep):list() do
		m:removeFace(id)
	end
	m:solidify(0.03)
	return m
end

part("Body", nil, { 0.18, 0.19, 0.21 }, function(mesh)
	skinPart(body:copy(), false):emit(mesh)
end, true, 0.4)
part("Belly", nil, { 0.3, 0.3, 0.3 }, function(mesh)
	skinPart(body:copy(), true):emit(mesh)
end, true, 0.3)
-- The scrap the shark is made of: darker metals over the back and on the
-- fins, pale ones under the belly.
local BACK_METALS = {
	{ "BLUEGREY", { 0.4, 0.47, 0.52 } },
	{ "OLIVE", { 0.42, 0.45, 0.36 } },
	{ "RUST", { 0.55, 0.35, 0.16 } },
	{ "GUNMETAL", { 0.3, 0.33, 0.37 } },
	{ "PAINTED", { 0.36, 0.5, 0.62 } },
	{ "BRASS", { 0.7, 0.58, 0.3 } },
}
local BELLY_METALS = {
	{ "TIN", { 0.72, 0.7, 0.66 } },
	{ "GALVANISED", { 0.6, 0.63, 0.62 } },
	{ "ENAMEL", { 0.86, 0.86, 0.82 } },
	{ "ALUMINIUM", { 0.78, 0.8, 0.8 } },
	{ "TIN", { 0.72, 0.7, 0.66 } },
	{ "ENAMEL", { 0.86, 0.86, 0.82 } },
}
-- A fin from its outline in x (along the body) and z (out from the root
-- at 0), thick at the root and thinning toward its edges and tip.
local function fin(outline, thick, span)
	local m = Kit.plate(outline, thick)
	m:translate(0, -thick / 2, 0)
	-- How far from the root, and how near an edge, each point is.
	m:transform(function(p)
		local out = math.clamp(p[3] / span, 0, 1)
		return { p[1], p[2] * math.max(0.12, 1 - 0.85 * out), p[3] }
	end)
	return m
end
-- Clips an x-z outline to lo <= z <= hi (Sutherland-Hodgman).
local function clipBand(outline, lo, hi)
	local function clip(poly, keep, cross)
		local out = {}
		for i, a in poly do
			local b = poly[i % #poly + 1]
			local ka, kb = keep(a), keep(b)
			if ka then
				table.insert(out, a)
			end
			if ka ~= kb then
				table.insert(out, cross(a, b))
			end
		end
		return out
	end
	local function at(a, b, z)
		local t = (z - a[2]) / (b[2] - a[2])
		return { a[1] + (b[1] - a[1]) * t, z }
	end
	local poly = clip(outline, function(q)
		return q[2] >= lo
	end, function(a, b)
		return at(a, b, lo)
	end)
	return clip(poly, function(q)
		return q[2] <= hi
	end, function(a, b)
		return at(a, b, hi)
	end)
end
-- Every fin is sheet metal in pieces: the outline cut into bands along its
-- span at the given heights, each band a plate of its own metal with the
-- fin's thickness rule, a dark steel core showing in the seams. Pieces are
-- made once and placed with the fin's own turns; the metal parts emit
-- them, and Rivets the rivets along the seams.
local FIN_PIECES, FIN_RIVETS = {}, {}
local function metalFin(outline, thick, span, cuts, place, first)
	local edges = { -10 }
	for _, c in cuts do
		table.insert(edges, c)
	end
	table.insert(edges, 10)
	for k = 1, #edges - 1 do
		local lo = edges[k] + (if k > 1 then 0.012 else 0)
		local hi = edges[k + 1] - (if k < #edges - 1 then 0.012 else 0)
		local piece = clipBand(outline, lo, hi)
		if #piece >= 3 then
			local metal = BACK_METALS[(first + k - 1) % #BACK_METALS + 1]
			table.insert(FIN_PIECES, { metal = metal[1], mesh = place(fin(piece, thick, span)) })
		end
	end
	-- Rivets either side of each seam, on both faces.
	for _, c in cuts do
		local band = clipBand(outline, c - 0.001, c + 0.001)
		local xs = {}
		for _, q in band do
			table.insert(xs, q[1])
		end
		table.sort(xs)
		if #xs >= 2 then
			local x0, x1 = xs[1], xs[#xs]
			local out = math.clamp(c / span, 0, 1)
			local half = thick / 2 * math.max(0.12, 1 - 0.85 * out)
			for _, t in { 0.2, 0.5, 0.8 } do
				for _, side in { -1, 1 } do
					for _, dz in { -0.045, 0.045 } do
						local r = EditMesh.sphere(0.02, 6)
						r:translate(x0 + (x1 - x0) * t, side * (half + 0.004) - half + half, c + dz)
						table.insert(FIN_RIVETS, place(r))
					end
				end
			end
		end
	end
	-- The core: the whole outline, a little thinner, in dark steel.
	local core = fin(outline, thick * 0.8, span)
	return place(core)
end
part("Fins", nil, { 0.18, 0.19, 0.21 }, function(mesh)
	-- The first dorsal, over the back's high point: a straight leading edge
	-- raked back to the tip, a concave trailing edge down to a free tip.
	metalFin({ { 0.95, -0.15 }, { 0.6, 0.4 }, { 0.2, 0.9 }, { 0.05, 0.98 }, { 0.12, 0.6 }, { 0.2, 0.25 }, { 0.1, -0.15 } }, 0.14, 0.98, { 0.3, 0.62 }, function(m)
		return m:translate(0, 0, MIDDLE + 0.46)
	end, 1):emit(mesh)
	-- The second dorsal, small, near the tail.
	metalFin({ { 0.25, -0.1 }, { 0.08, 0.16 }, { -0.02, 0.2 }, { 0.0, 0.06 }, { -0.06, -0.1 } }, 0.08, 0.2, {}, function(m)
		return m:translate(-0.95, 0, MIDDLE + 0.22)
	end, 4):emit(mesh)
	-- The tail: a long upper lobe sweeping up and back, a shorter lower
	-- one, both from the tail root.
	metalFin({ { 0.12, 0.12 }, { -0.55, 1.0 }, { -0.75, 1.08 }, { -0.5, 0.4 }, { -0.32, 0.12 }, { -0.5, -0.38 }, { -0.62, -0.55 }, { -0.1, -0.16 }, { 0.12, -0.1 } }, 0.12, 1.08, { -0.2, 0.3, 0.7 }, function(m)
		m:transform(function(p)
			-- Thinning the lower lobe too, which the span rule leaves.
			local down = math.clamp(-p[3] / 0.55, 0, 1)
			return { p[1], p[2] * math.max(0.15, 1 - 0.85 * down), p[3] }
		end)
		return m:translate(-1.62, 0, MIDDLE + 0.01)
	end, 2):emit(mesh)
end, 40, 0.35)
part("ShodFins", nil, { 0.18, 0.19, 0.21 }, function(mesh)
	-- The pectorals and the fin under the tail, from fin outlines like the
	-- rest, turned down to the ground.
	for n, f in SHOD do
		local c = f.chord / 2
		local out = (90 - f.down) * (if f.side == 0 then 1 else f.side)
		-- Narrowing fast in the lower half, so only a slim tip goes into the
		-- sneaker's collar.
		metalFin({ { c, -0.12 }, { c * 0.34, f.span * 0.5 }, { c * 0.15, f.span }, { -c * 0.15, f.span }, { -c * 0.4, f.span * 0.45 }, { -c, -0.12 } }, 0.12, f.span, { f.span * 0.42 }, function(m)
			Kit.turn(m, "x", 180)
			Kit.turn(m, "x", out)
			Kit.turn(m, "y", f.back)
			return m:translate(f.root[1], f.root[2], MIDDLE + f.root[3])
		end, 2 + n):emit(mesh)
	end
end, 40, 0.4)
-- Each sneaker stands on the ground with its collar over its fin's tip.
-- It is lofted along its length from heel to toe: a footprint that is
-- narrow at the heel, widest at the ball and rounded at the toe, an upper
-- that stands tallest at the collar and slopes down the vamp to a low
-- rounded toe box, the whole thing springing up a little at the toe. The
-- collar is a socket sunk into the top over the heel for the fin to go
-- in. The midsole and outsole are the same footprint, thicker and a
-- touch wider.
local SHOE = { long = 1.05, wide = 0.56, high = 0.38 }
local SOLE = 0.14 -- outsole plus midsole
-- The fin leans out and back on its way up, so the shoe is placed by where
-- the fin's axis crosses the collar's height, not by its tip: the hole
-- sits round the fin there, and the tip lies deeper inside the shoe.
local function shoeAt(f)
	local a, b = finTurn(f, { 0, 0, f.span }), finTurn(f, { 0, 0, f.span - 0.5 })
	local collarZ = SOLE - 0.03 + SHOE.high
	local t = (collarZ - a[3]) / (b[3] - a[3])
	local x, y = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
	return { x + SHOE.long * 0.28, y }
end
-- Stations along the shoe, t from the heel (0) to the toe (1): half width
-- and the upper's height, as shares of the shoe's.
local FOOTPRINT = { { 0, 0.1 }, { 0.06, 0.78 }, { 0.3, 0.8 }, { 0.62, 0.95 }, { 0.84, 0.86 }, { 0.96, 0.45 }, { 1, 0.08 } }
local UPPER = { { 0, 0.45 }, { 0.08, 1.0 }, { 0.28, 1.0 }, { 0.45, 0.82 }, { 0.7, 0.6 }, { 0.9, 0.4 }, { 0.97, 0.22 }, { 1, 0.08 } }
local function along(list, t)
	for k = 1, #list - 1 do
		local a, b = list[k], list[k + 1]
		if t <= b[1] then
			local u = math.clamp((t - a[1]) / (b[1] - a[1]), 0, 1)
			u = u * u * (3 - 2 * u)
			return a[2] + (b[2] - a[2]) * u
		end
	end
	return list[#list][2]
end
local function spring(t) -- the toe's lift off the ground
	return 0.05 * math.clamp((t - 0.6) / 0.4, 0, 1) ^ 2
end
-- A loft of the footprint: a rounded-square section, bottom flat at z0,
-- rising to height(t) * scale; w as a share of the shoe's half width.
local function shoeLoft(stations, height, widen, z0, t0, t1)
	t0, t1 = t0 or 0, t1 or 1
	local ring, path = {}, {}
	for k = 0, 19 do
		local r = math.rad(k * 18)
		-- A rounded square: the circle pushed out toward the corners.
		local c, sn = math.cos(r), math.sin(r)
		local push = 1 + 0.18 * (math.abs(c * sn) * 2)
		table.insert(ring, { -sn * push, c * push })
	end
	for k = 0, stations do
		table.insert(path, { -SHOE.long / 2 + SHOE.long * (t0 + (t1 - t0) * k / stations), 0, 0 })
	end
	local m = EditMesh.sweep(ring, path)
	m:transform(function(p)
		local t = (p[1] + SHOE.long / 2) / SHOE.long
		local w = along(FOOTPRINT, t) * SHOE.wide / 2 + widen
		local h = height(t)
		return { p[1], p[2] * w, z0 + spring(t) + (p[3] + 1) / 2 * h }
	end)
	return m
end
part("Sneakers", nil, SNEAKER_BLUE, function(mesh)
	for _, f in SHOD do
		local at = shoeAt(f)
		local upper = shoeLoft(20, function(t)
			return along(UPPER, t) * SHOE.high
		end, 0, SOLE - 0.03)
		-- The collar: a socket sunk into the top over the heel.
		local collar = upper:select("face", "facing", { 0, 0, 1 }, 35):filter(function(p)
			local t = (p[1] + SHOE.long / 2) / SHOE.long
			return t > 0.07 and t < 0.37 and math.abs(p[2]) < SHOE.wide * 0.3
		end)
		if collar:count() > 0 then
			upper:extrude(upper:inset(collar, 0.02, 0), -0.14)
		end
		upper:translate(at[1], at[2], 0)
		upper:emit(mesh)
		-- The tongue, padded, rising out of the collar's front.
		local tongue = Kit.block(0.16, 0.2, 0.22, 0.05)
		Kit.turn(tongue, "y", 30)
		tongue:translate(at[1] - 0.12, at[2], SOLE + SHOE.high * 0.92)
		tongue:emit(mesh)
	end
end, true, RUBBER)
part("HeelCounters", nil, { 0.1, 0.36, 0.78 }, function(mesh)
	-- A stiffer cup of darker blue round the heel, and a mudguard round
	-- the toe, both lofted from the same footprint a hair wider.
	for _, f in SHOD do
		local at = shoeAt(f)
		for _, band in { { 0, 0.24, 0.62 }, { 0.78, 1, 0.9 } } do
			local m = shoeLoft(8, function(t)
				return along(UPPER, t) * SHOE.high * band[3]
			end, 0.012, SOLE - 0.02, band[1], band[2])
			m:translate(at[1], at[2], 0)
			m:emit(mesh)
		end
	end
end, true, RUBBER)
part("Soles", nil, { 0.95, 0.95, 0.93 }, function(mesh)
	-- The midsole, white, the footprint a little wider than the upper.
	for _, f in SHOD do
		local at = shoeAt(f)
		local m = shoeLoft(20, function()
			return 0.1
		end, 0.03, 0.04)
		m:translate(at[1], at[2], 0)
		m:emit(mesh)
	end
end, true, RUBBER)
part("Outsoles", nil, { 0.2, 0.2, 0.22 }, function(mesh)
	-- The dark rubber under it, with the toe spring.
	for _, f in SHOD do
		local at = shoeAt(f)
		local m = shoeLoft(20, function()
			return 0.045
		end, 0.02, 0)
		m:translate(at[1], at[2], 0)
		m:emit(mesh)
	end
end, true, RUBBER)
-- The upper's top at x from the shoe's middle, for the laces and eyelets.
local function instep(x)
	local t = (x + SHOE.long / 2) / SHOE.long
	return SOLE - 0.03 + spring(t) + along(UPPER, t) * SHOE.high
end
part("ShoeTrim", nil, { 0.96, 0.96, 0.94 }, function(mesh)
	for _, f in SHOD do
		local at = shoeAt(f)
		-- Crossed laces between the eyelet rows down the instep.
		local rows = { -0.12, 0.0, 0.12, 0.24 }
		for k = 1, #rows - 1 do
			for _, side in { -1, 1 } do
				Kit.tube({ { at[1] + rows[k], at[2] + side * 0.1, instep(rows[k]) + 0.01 }, { at[1] + rows[k + 1], at[2] - side * 0.1, instep(rows[k + 1]) + 0.01 } }, 0.016, 6):emit(mesh)
			end
		end
		-- A stripe along each side, dipping under the laces.
		for _, side in { -1, 1 } do
			Kit.tube(Kit.curve({ { at[1] - 0.4, at[2] + side * 0.23, 0.3 }, { at[1] - 0.1, at[2] + side * 0.26, 0.2 }, { at[1] + 0.22, at[2] + side * 0.26, 0.17 }, { at[1] + 0.4, at[2] + side * 0.2, 0.22 } }, 4), 0.02, 6):emit(mesh)
		end
		-- The padded collar rim and a heel tab.
		local rim = EditMesh.torus(0.12, 0.03, 16, 6)
		Kit.size(rim, { 1.5, 1, 1 })
		rim:translate(at[1] - SHOE.long * 0.28, at[2], SOLE - 0.03 + SHOE.high)
		rim:emit(mesh)
		Kit.tube(Kit.curve({ { at[1] - 0.49, at[2], SOLE + 0.18 }, { at[1] - 0.55, at[2], SOLE + 0.28 }, { at[1] - 0.47, at[2], SOLE + 0.36 } }, 3), 0.02, 6):emit(mesh)
	end
end, 50, 0)
part("Eyelets", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	for _, f in SHOD do
		local at = shoeAt(f)
		for _, x in { -0.12, 0.0, 0.12, 0.24 } do
			for _, side in { -1, 1 } do
				local eye = EditMesh.cylinder(0.024, 0.012, 8, 1)
				eye:translate(at[1] + x, at[2] + side * 0.1, instep(x) + 0.005)
				eye:emit(mesh)
			end
		end
	end
end, 50, 0)
-- The mouth's rim, walked from one corner (t = -1) round the front (0) to
-- the other (1), on the skin; out lifts it off.
local function rimPoint(t, out)
	local a = math.rad(t * 90)
	local x = CORNER.x + MOUTH_REACH * math.abs(math.cos(a)) ^ 0.8
	local p = skin(x, (if t < 0 then -1 else 1) * 150)
	return { p[1], p[2], p[3] + MIDDLE + (out or 0) }
end
-- Places a piece built round the mouth (from the axis) onto the hanging
-- jaw: turned open about the hinge line through the corners.
local function onJaw(m)
	m:translate(-CORNER.x, 0, -ROOF)
	Kit.turn(m, "y", GAPE)
	return m:translate(CORNER.x, 0, MIDDLE + ROOF)
end
-- The lower jaw: the head's bottom slice under the mouth's rim, rings of
-- the skin between the rim's sides, flat across the top at the roof.
local function jaw()
	local m = EditMesh.new()
	local rings = {}
	for i = 0, 16 do
		local t = 1 - i / 16 -- from the corners forward
		local a = math.rad(t * 90)
		local x = CORNER.x + MOUTH_REACH * math.cos(a) ^ 0.8
		if i == 16 then
			x = CORNER.x + MOUTH_REACH - 0.02
		end
		local ring = {}
		for k = 0, 12 do
			local n = 150 + 60 * k / 12 -- round the bottom from one rim to the other
			local p = skin(x, if n <= 180 then n else n - 360)
			table.insert(ring, m:addVertex(p[1], p[2], math.min(p[3], ROOF - 0.012)))
		end
		for k = 11, 1, -1 do
			local n = 150 + 60 * k / 12
			local p = skin(x, if n <= 180 then n else n - 360)
			table.insert(ring, m:addVertex(p[1], p[2], ROOF - 0.012))
		end
		table.insert(rings, ring)
	end
	for i = 1, #rings - 1 do
		local a, b = rings[i], rings[i + 1]
		for k = 1, #a do
			local k2 = k % #a + 1
			m:addFace({ a[k], b[k], b[k2], a[k2] })
		end
	end
	local front = {}
	for k = #rings[#rings], 1, -1 do
		table.insert(front, rings[#rings][k])
	end
	m:addFace(rings[1])
	m:addFace(front)
	return m
end
part("Jaw", nil, BELLY, function(mesh)
	onJaw(jaw()):emit(mesh)
end, true, 0.25)
part("Mouth", nil, { 0.3, 0.07, 0.09 }, function(mesh)
	-- The roof of the mouth, a plate across the hole in the skin at the
	-- roof plane, and the jaw's top in the same dark red.
	local outline = {}
	for k = 0, 24 do
		local p = rimPoint(-1 + k / 12)
		table.insert(outline, { p[1], p[2] })
	end
	local roof = Kit.plate(outline, 0.02)
	Kit.turn(roof, "x", -90)
	roof:translate(0, 0, MIDDLE + ROOF - 0.005)
	roof:emit(mesh)
	local floor = jaw()
	local keep = floor:select("face", "where", function(p)
		return p[3] > ROOF - 0.03
	end)
	for _, id in floor:select("face", "all"):minus(keep):list() do
		floor:removeFace(id)
	end
	floor:push(floor:select("vertex", "all"), 0.006)
	floor:solidify(0.012)
	onJaw(floor):emit(mesh)
end, true, 0)
local function eyeAt(side)
	local p, n = skinNormal(1.77, side * 72)
	return p, n
end
part("Eyes", nil, { 0.96, 0.96, 0.94 }, function(mesh)
	-- Googly eyes: a white dome on each socket.
	for _, side in { -1, 1 } do
		local p, n = eyeAt(side)
		local eye = EditMesh.sphere(0.13, 12)
		Kit.size(eye, { 1, 0.5, 1 })
		eye:translate(p[1] + n[1] * 0.02, p[2] + n[2] * 0.02, p[3] + n[3] * 0.02 + MIDDLE)
		eye:emit(mesh)
	end
end, true, 0)
part("Pupils", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	-- The loose black pupils, slid down and forward in their domes.
	for _, side in { -1, 1 } do
		local p, n = eyeAt(side)
		local pupil = EditMesh.sphere(0.055, 8)
		Kit.size(pupil, { 1, 0.4, 1 })
		pupil:translate(p[1] + n[1] * 0.075 + 0.025, p[2] + n[2] * 0.075, p[3] + n[3] * 0.075 - 0.035 + MIDDLE)
		pupil:emit(mesh)
	end
end, true, 0)
part("Lips", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	-- Dark rubber beading round the mouth's rim above, and along the jaw's
	-- edge below: the grin stands out dark against the enamel head, the
	-- white teeth between.
	local path = {}
	for k = 0, 24 do
		table.insert(path, rimPoint(-1 + k / 12, 0.02))
	end
	Kit.tube(path, 0.036, 8):emit(mesh)
	local lower = {}
	for k = 0, 24 do
		local q = rimPoint(-1 + k / 12)
		table.insert(lower, { q[1] * 0.985 + CORNER.x * 0.015, q[2] * 0.95, ROOF - 0.03 })
	end
	onJaw(Kit.tube(lower, 0.03, 8)):emit(mesh)
end, true, 0.1)
part("NostrilPits", nil, { 0.05, 0.05, 0.06 }, function(mesh)
	-- Dark pits on the plated snout, under its tip.
	for _, side in { -1, 1 } do
		local o = onSkin(2.1, side * 165, 0.03)
		local pit = EditMesh.sphere(0.03, 6)
		Kit.size(pit, { 1.4, 1, 0.6 })
		pit:translate(o[1], o[2], o[3])
		pit:emit(mesh)
	end
end, true, 0)
-- A tooth: a flat triangle standing up from the origin, facing +-y, its
-- point up; turned to face along its rim.
local function tooth(wide, tall, facing)
	local m = Kit.plate({ { -wide / 2, 0 }, { wide / 2, 0 }, { 0, tall } }, 0.025)
	m:translate(0, -0.0125, 0)
	Kit.turn(m, "z", facing)
	return m
end
local function rimFacing(t)
	local p, q = rimPoint(t - 0.02), rimPoint(t + 0.02)
	return math.deg(math.atan2(q[2] - p[2], q[1] - p[1]))
end
part("Teeth", nil, { 0.97, 0.97, 0.93 }, function(mesh)
	-- Hanging from the upper rim, a second smaller row behind; standing
	-- along the jaw's edge.
	for k = 1, 17 do
		local t = -1 + k / 9
		local p = rimPoint(t)
		local tip = tooth(0.065, 0.13, rimFacing(t))
		Kit.turn(tip, "y", 180)
		tip:translate(p[1] - 0.02, p[2] * 0.92, p[3] + 0.015)
		tip:emit(mesh)
	end
	for k = 1, 16 do
		local t = -1 + (k - 0.5) / 9 + 1 / 18
		local p = rimPoint(t)
		local tip = tooth(0.05, 0.1, rimFacing(t))
		Kit.turn(tip, "y", 180)
		tip:translate(p[1] - 0.06, p[2] * 0.82, MIDDLE + ROOF - 0.004)
		tip:emit(mesh)
	end
	for k = 1, 17 do
		local t = -1 + k / 9
		local p = rimPoint(t)
		local tip = tooth(0.06, 0.12, rimFacing(t))
		tip:translate(p[1] - 0.015, p[2] * 0.9, ROOF - 0.015)
		onJaw(tip):emit(mesh)
	end
end, 40, 0)
-- The whole skin is scrap, as on the Zapper: plates of mismatched metal
-- beaten to the body's curve, in bands round the section with staggered
-- cuts along the length, darker metals over the back and pale ones under
-- the belly, each lifted a hair off the skin with its own thickness and
-- riveted at the corners, a seam of dark steel showing between them. The
-- eyes and the mouth are left open.
-- Bands round the section by nominal angle, and each band's cuts along x.
-- Cuts of very different lengths, so no two plates match; some cells are
-- split round the section as well, and each plate's edges are nudged so
-- the rows don't line up.
local BANDS = {
	{ 0, 32, { -1.7, -1.3, -0.2, 0.1, 1.2, 1.45, 2.05, 2.3 } },
	{ 32, 65, { -1.7, -0.75, -0.5, 0.65, 0.9, 1.75, 2.3 } },
	{ 65, 80, { -1.7, -1.4, -0.3, 0.95, 1.25, 1.6, 1.9, 2.3 } },
	{ 80, 118, { -1.7, -0.95, 0.15, 0.4, 1.3, 1.6, 2.3 } },
	{ 118, 150, { -1.7, -1.45, -0.55, 0.0, 0.25, 1.15, 1.55, 2.3 } },
	{ 150, 180, { -1.7, -0.6, -0.35, 0.85, 1.5, 2.1, 2.3 } },
}
local SPLITS = { [3] = 0.45, [7] = 0.6, [12] = 0.35, [18] = 0.55, [23] = 0.4, [29] = 0.65, [34] = 0.5, [40] = 0.3 }
local PANELS = {}
for b, band in BANDS do
	for seg = 1, #band[3] - 1 do
		local x0, x1 = band[3][seg], band[3][seg + 1]
		for _, side in { -1, 1 } do
			local open = false
			-- The eye's opening, and the mouth's.
			if b == 3 and x0 < 1.9 and x1 > 1.6 then
				open = true
			end
			if b == 6 and x1 > 1.5 and x0 < 2.1 then
				open = true
			end
			if not open then
				local pale = band[1] >= 80
				local palette = if pale then BELLY_METALS else BACK_METALS
				local count = #PANELS
				local nudge = ((count * 7) % 5 - 2) * 1.5 -- degrees, -3..3
				local a0, a1 = band[1] + nudge, band[2] + nudge
				local cells = { { a0, a1 } }
				local split = SPLITS[count % 41 + 1]
				if split and x0 < 1.45 then
					local at = a0 + (a1 - a0) * split
					cells = { { a0, at }, { at, a1 } }
				end
				for c, cell in cells do
					local pick = palette[(b * 3 + seg * 5 + c * 2 + (if side < 0 then 2 else 0)) % #palette + 1]
					-- The head plainer, so the face reads: gunmetal above,
					-- enamel below.
					if x0 >= 1.45 then
						pick = if pale then BELLY_METALS[3] else BACK_METALS[4]
					end
					table.insert(PANELS, { x0 + 0.012, x1 - 0.012, side * (math.max(cell[1], 0.5) + 1.2), side * (math.min(cell[2], 179.5) - 1.2), pick[1], pick[2] })
				end
			end
		end
	end
end
local PANEL_METALS = {}
for _, q in PANELS do
	PANEL_METALS[q[5]] = q[6]
end
for _, m in BACK_METALS do
	PANEL_METALS[m[1]] = m[2]
end
local function panel(x0, x1, a0, a1)
	local m = EditMesh.new()
	local ALONG, ROUND = 8, 6
	local top, bottom = {}, {}
	for i = 0, ALONG do
		top[i], bottom[i] = {}, {}
		for j = 0, ROUND do
			local x, a = x0 + (x1 - x0) * i / ALONG, a0 + (a1 - a0) * j / ROUND
			local o, u = onSkin(x, a, 0.035), onSkin(x, a, -0.01)
			top[i][j] = m:addVertex(o[1], o[2], o[3])
			bottom[i][j] = m:addVertex(u[1], u[2], u[3])
		end
	end
	for i = 0, ALONG - 1 do
		for j = 0, ROUND - 1 do
			m:addFace({ top[i][j], top[i + 1][j], top[i + 1][j + 1], top[i][j + 1] })
			m:addFace({ bottom[i][j], bottom[i][j + 1], bottom[i + 1][j + 1], bottom[i + 1][j] })
		end
	end
	for k = 0, ALONG - 1 do
		m:addFace({ top[k][0], bottom[k][0], bottom[k + 1][0], top[k + 1][0] })
		m:addFace({ top[k + 1][ROUND], bottom[k + 1][ROUND], bottom[k][ROUND], top[k][ROUND] })
	end
	for k = 0, ROUND - 1 do
		m:addFace({ top[0][k + 1], bottom[0][k + 1], bottom[0][k], top[0][k] })
		m:addFace({ top[ALONG][k], bottom[ALONG][k], bottom[ALONG][k + 1], top[ALONG][k + 1] })
	end
	-- Consistent winding whichever way round the angles run.
	local o = onSkin((x0 + x1) / 2, (a0 + a1) / 2, 0.1)
	local c = onSkin((x0 + x1) / 2, (a0 + a1) / 2, 0.035)
	local n = m:faceNormal(m:select("face", "all"):list()[1])
	if n[1] * (o[1] - c[1]) + n[2] * (o[2] - c[2]) + n[3] * (o[3] - c[3]) < 0 then
		m:flip()
	end
	return m
end
for metal, colour in PANEL_METALS do
	part("Panels" .. metal, nil, colour, function(mesh)
		for _, q in PANELS do
			if q[5] == metal then
				panel(q[1], q[2], q[3], q[4]):emit(mesh)
			end
		end
		for _, piece in FIN_PIECES do
			if piece.metal == metal then
				piece.mesh:emit(mesh)
			end
		end
	end, 40, if metal == "RUST" then 0.7 elseif metal == "BRASS" or metal == "ENAMEL" then 0.3 else 0.5)
end
-- How each plate is held on: by turns rivets, hex bolts with washers, a
-- weld bead run along one edge, a strip of tape across a seam, wire
-- stitches over an edge, or bent tabs clipped over it. A plate's join is
-- picked from its place in the list, so neighbours differ.
local JOINS = { "rivets", "bolts", "weld", "tape", "stitches", "clips", "rivets", "weld", "bolts", "stitches", "tape", "clips" }
local function joinOf(index)
	return JOINS[(index * 5) % #JOINS + 1]
end
-- Points along a plate's edge in skin space: edge "x0"/"x1" runs round the
-- section at that x, "a0"/"a1" along x at that angle; t from 0 to 1.
local function edgePoint(q, edge, t, lift)
	if edge == "x0" or edge == "x1" then
		local x = if edge == "x0" then q[1] else q[2]
		return onSkin(x, q[3] + (q[4] - q[3]) * t, lift)
	end
	local a = if edge == "a0" then q[3] else q[4]
	return onSkin(q[1] + (q[2] - q[1]) * t, a, lift)
end
local function joinNormal(q, edge, t)
	local p, n = skinNormal(if edge == "x0" then q[1] elseif edge == "x1" then q[2] else q[1] + (q[2] - q[1]) * t, if edge == "a0" then q[3] elseif edge == "a1" then q[4] else q[3] + (q[4] - q[3]) * t)
	return n
end
part("Rivets", nil, DARK_STEEL, function(mesh)
	for _, r in FIN_RIVETS do
		r:emit(mesh)
	end
	for index, q in PANELS do
		local join = joinOf(index)
		if join == "rivets" or join == "bolts" then
			-- In the corners, half sunk; bolts are hex heads on washers.
			local dx, da = (q[2] - q[1]) * 0.1, (q[4] - q[3]) * 0.15
			for _, x in { q[1] + dx, q[2] - dx } do
				for _, a in { q[3] + da, q[4] - da } do
					if x <= 1.95 then
						local o = onSkin(x, a, 0.035)
						if join == "rivets" then
							local rivet = EditMesh.sphere(0.026, 6)
							rivet:translate(o[1], o[2], o[3])
							rivet:emit(mesh)
						else
							local _, n = skinNormal(x, a)
							local head = EditMesh.cylinder(0.022, 0.03, 6, 1)
							local washer = EditMesh.cylinder(0.036, 0.01, 10, 1)
							-- Standing along the skin's normal.
							local tilt = math.deg(math.acos(math.clamp(n[3], -1, 1)))
							local spin = math.deg(math.atan2(n[2], n[1]))
							head:translate(0, 0, 0.012)
							for _, piece in { head, washer } do
								Kit.turn(piece, "y", tilt)
								Kit.turn(piece, "z", spin)
								piece:translate(o[1] - n[1] * 0.012, o[2] - n[2] * 0.012, o[3] - n[3] * 0.012)
								piece:emit(mesh)
							end
						end
					end
				end
			end
		end
	end
end, true, 0.4)
part("Welds", nil, { 0.32, 0.3, 0.28 }, function(mesh)
	-- A bead of weld run along the plate's rear edge, lumpy.
	for index, q in PANELS do
		if joinOf(index) == "weld" and q[1] < 1.9 then
			local path = {}
			for k = 0, 10 do
				local t = k / 10
				local o = edgePoint(q, "x0", t, 0.03)
				table.insert(path, o)
			end
			EditMesh.sweep((function()
				local ring = {}
				for k = 0, 7 do
					local r = math.rad(k * 45)
					table.insert(ring, { math.cos(r) * 0.03, math.sin(r) * 0.022 })
				end
				return ring
			end)(), path, { scale = function(t)
				return 0.8 + 0.35 * math.abs(math.sin(t * 31))
			end }):emit(mesh)
		end
	end
end, true, 0.6)
part("Tape", nil, { 0.58, 0.58, 0.56 }, function(mesh)
	-- A strip of tape across the seam at the plate's front edge, mid way.
	for index, q in PANELS do
		if joinOf(index) == "tape" and q[2] < 1.95 then
			local path = {}
			for k = 0, 6 do
				local t = 0.3 + 0.4 * k / 6
				local o = edgePoint(q, "x1", t, 0.038)
				table.insert(path, o)
			end
			-- Flat: wide across the seam, thin off the plate.
			EditMesh.sweep({ { -0.045, -0.006 }, { 0.045, -0.006 }, { 0.045, 0.006 }, { -0.045, 0.006 } }, path):emit(mesh)
		end
	end
end, 40, 0.3)
part("Stitches", nil, { 0.55, 0.55, 0.52 }, function(mesh)
	-- Wire staples over the plate's upper edge, three to a plate.
	for index, q in PANELS do
		if joinOf(index) == "stitches" and q[2] < 1.95 then
			for _, t in { 0.25, 0.5, 0.75 } do
				local o = edgePoint(q, "a0", t, 0.036)
				local n = joinNormal(q, "a0", t)
				-- Across the edge: along the section, roughly the direction
				-- of the next point round.
				local across = edgePoint(q, "x0", 0.02, 0.036)
				local ref = edgePoint(q, "x0", 0.0, 0.036)
				local d = { across[1] - ref[1], across[2] - ref[2], across[3] - ref[3] }
				local len = math.sqrt(d[1] ^ 2 + d[2] ^ 2 + d[3] ^ 2)
				d = { d[1] / len, d[2] / len, d[3] / len }
				Kit.tube(Kit.curve({
					{ o[1] - d[1] * 0.05 - n[1] * 0.02, o[2] - d[2] * 0.05 - n[2] * 0.02, o[3] - d[3] * 0.05 - n[3] * 0.02 },
					{ o[1], o[2] + 0, o[3] },
					{ o[1] + d[1] * 0.05 - n[1] * 0.02, o[2] + d[2] * 0.05 - n[2] * 0.02, o[3] + d[3] * 0.05 - n[3] * 0.02 },
				}, 3), 0.009, 5):emit(mesh)
			end
		end
	end
end, true, 0.3)
part("Clips", nil, { 0.5, 0.52, 0.5 }, function(mesh)
	-- Bent tabs clipped over the plate's lower edge.
	for index, q in PANELS do
		if joinOf(index) == "clips" and q[2] < 1.95 then
			for _, t in { 0.3, 0.7 } do
				local o = edgePoint(q, "a1", t, 0.04)
				local n = joinNormal(q, "a1", t)
				local tab = Kit.block(0.07, 0.09, 0.02, 0.005)
				local tilt = math.deg(math.acos(math.clamp(n[3], -1, 1)))
				local spin = math.deg(math.atan2(n[2], n[1]))
				Kit.turn(tab, "y", tilt)
				Kit.turn(tab, "z", spin)
				tab:translate(o[1], o[2], o[3])
				tab:emit(mesh)
			end
		end
	end
end, 40, 0.4)
finishParts()
