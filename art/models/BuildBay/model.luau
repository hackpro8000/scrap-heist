local CACHE_KEY = "BuildBay-d74007e67b0bb91d"
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
-- `blend` (0-1) to tint them from cream toward a lighter part colour, and
-- `taper` (studs) to run them full width at corners, thinning along each edge.
-- `softLit` (0-1) adds a wide, very soft highlight under the strokes, fading
-- out over `softEdge` studs from each edge; `softUneven` (0-1) makes its width
-- wander along the edge and `softTaper` (studs) thins it away from corners.
-- `strokes` lists brush strokes painted over the coat ({start, along, normal,
-- length, width, tail, color, brush}, color in sRGB), such as cracks or dabs;
-- `brush` is "taper" (crisp lines, the default), "round" or "sponge".
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
			rubber = entry.rubber,
			reach = entry.edge,
			highlightWidth = entry.wide,
			paintedHighlights = entry.painted,
			cornerTaper = entry.taper,
			softHighlight = entry.softLit,
			softReach = entry.softEdge,
			softUneven = entry.softUneven,
			softTaper = entry.softTaper,
			strokes = entry.strokes,
			heightRange = entry.heightRange,
			crisp = entry.crisp,
		})
		model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true })
	end
end
-- Build Bay: where a capsule sits to be whacked open with the Big Spanner, and
-- where raiders steal it from (art/concepts/build-bay-sketch.png,
-- BuildBay.plan.luau). Exactly 10 x 10 on the ground and 8.1 tall, the origin
-- at the middle of the footprint at ground level, z up, the front (toward the
-- gate) on the -y side.
-- The game seats the capsule by dropping a ray from above the bay's middle
-- (PlotService.seatOf), so nothing stands over x = 0, y = 0: the frame is on
-- the back edge and the work lamp's arm stops short of the middle. It also
-- centres the art's bounding box on the bay's cells, so nothing reaches past
-- the deck.

-- Baked at the yard kit's density (KIT_DENSITY in the ServerMap layout), as it
-- is in game.
useTexelDensity(40)

local DECK_STEEL = { 0.2, 0.21, 0.24 }
local FRAME_STEEL = { 0.28, 0.3, 0.34 }
local BOARD_GREY = { 0.46, 0.52, 0.58 }
local SEAT_STEEL = { 0.46, 0.48, 0.52 }
local PANEL_STEEL = { 0.42, 0.45, 0.5 }
local BARE = { 0.68, 0.7, 0.73 }
local TOOL_STEEL = { 0.62, 0.64, 0.68 }
-- Yellower than the crate's wood, so the cast parts can't be taken for timber.
local BRONZE = { 0.66, 0.5, 0.2 }
local BRASS = { 0.86, 0.68, 0.32 }
local HAZARD = { 0.86, 0.64, 0.16 }
local TAPE_BLACK = { 0.08, 0.08, 0.09 }
local CONCRETE = { 0.62, 0.6, 0.56 }
local RUBBER_BLACK = { 0.1, 0.1, 0.11 }
local WOOD = { 0.46, 0.33, 0.2 }
local OIL_BLUE = { 0.22, 0.36, 0.52 }
local AMBER = { 1.0, 0.72, 0.25 }
local CREAM = { 0.92, 0.9, 0.82 }

local DECK_TOP = 0.5
-- The capsule's seat: the drum's flat top.
local SEAT_Z, CRADLE_R = 1.7, 2.6
-- The frame on the back edge: two posts and a beam, the pegboard between.
local FRAME_Y, POST_X, POST_HALF = 3.9, 3.7, 0.45
local BEAM_HALF, BEAM_Z0, BEAM_Z1 = 4.4, 6.6, 7.5
local BOARD_Y, TOOL_Y = 3.95, 3.75
local PANEL_X, DIAL_Z = 2.25, 4.25
local LAMP_POST, LAMP_TOP = 4.55, 4.5
local CRATE_X, CRATE_Y = -3.6, 2.5
local OIL_X, OIL_Y = 3.6, 2.6
-- The work lamp's shade: the top of its axis, tipped toward the gate.
local SHADE_Y, SHADE_Z, SHADE_TILT = 1.5, 6.35, math.rad(15)
local SHADE_COS, SHADE_SIN = math.cos(SHADE_TILT), math.sin(SHADE_TILT)

-- A crisp 45-degree hazard tape: black where the stripe falls.
local function tape(along: number, up: number): boolean
	return (along + up) % 1.1 < 0.55
end
-- A line of rivets along a straight run.
local function rivets(mesh, x0, y0, z0, x1, y1, z1, count, axis, size)
	for i = 0, count - 1 do
		local t = (i + 0.5) / count
		bolt(mesh, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z0 + (z1 - z0) * t, axis, size)
	end
end
-- Machine finishes go on crisp, texel by texel (see common.luau).
local function crisp()
	parts[#parts].crisp = true
end
-- Crisp, with clean bold edge highlights in a lighter shade of the part's own
-- colour instead of dry-brushed ones.
local function machined()
	local entry = parts[#parts]
	entry.crisp, entry.painted, entry.blend = true, true, 0.8
end
-- A shape turned round an axis through `origin`: `profile` lists { radius,
-- distance along the axis }. `u` and `v` are unit vectors across the axis,
-- with u x v along it.
local function lathe(mesh, origin, u, v, axis, profile, sides)
	local rows = {}
	for k, step in profile do
		local row = {}
		for i = 1, sides do
			local t = (i - 1) / sides * TAU
			local across, up = math.cos(t) * step[1], math.sin(t) * step[1]
			row[i] = mesh:vertex(
				origin[1] + u[1] * across + v[1] * up + axis[1] * step[2],
				origin[2] + u[2] * across + v[2] * up + axis[2] * step[2],
				origin[3] + u[3] * across + v[3] * up + axis[3] * step[2]
			)
		end
		rows[k] = row
	end
	for k = 1, #rows - 1 do
		for i = 1, sides do
			local j = i % sides + 1
			mesh:face({ rows[k][i], rows[k][j], rows[k + 1][j], rows[k + 1][i] })
		end
	end
	local first = {}
	for i = sides, 1, -1 do
		table.insert(first, rows[1][i])
	end
	mesh:face(first)
	mesh:face(rows[#rows])
end

-- ------------------------------------------------------------- the deck
part("Deck", nil, DECK_STEEL, function(mesh)
	box(mesh, 0, 0, 0, 10, 10, 0.15)
	box(mesh, 0, 0, 0.15, 9.7, 9.7, DECK_TOP - 0.15)
	for _, side in { -1, 1 } do
		rivets(mesh, -4.4, side * 4.85, 0.32, 4.4, side * 4.85, 0.32, 8, "y", 0.07)
		rivets(mesh, side * 4.85, -4.4, 0.32, side * 4.85, 4.4, 0.32, 8, "x", 0.07)
	end
end, nil, function(x, y, z)
	if z < 0.17 then
		local k = 0.92 + 0.08 * math.noise(x * 0.8, y * 0.8, 3.1)
		return CONCRETE[1] * k, CONCRETE[2] * k, CONCRETE[3] * k
	end
	local k = 0.94 + 0.1 * math.noise(x * 0.5, y * 0.5, z * 2)
	if z > DECK_TOP - 0.01 then
		-- The hazard border, and a painted ring showing where capsules go.
		if math.max(math.abs(x), math.abs(y)) > 4.25 then
			if tape(x, y) then
				return TAPE_BLACK[1], TAPE_BLACK[2], TAPE_BLACK[3]
			end
			return HAZARD[1], HAZARD[2], HAZARD[3]
		end
		local r = math.sqrt(x * x + y * y)
		if r > 3.32 and r < 3.48 then
			return HAZARD[1], HAZARD[2], HAZARD[3]
		end
		-- Chequer plate: little raised bars, turned each way in turn.
		local cellX, cellY = math.floor(x / 0.6), math.floor(y / 0.6)
		local u, v = x / 0.6 - cellX - 0.5, y / 0.6 - cellY - 0.5
		local along, across = if (cellX + cellY) % 2 == 0 then u + v else u - v, if (cellX + cellY) % 2 == 0 then u - v else u + v
		if math.abs(along) < 0.5 and math.abs(across) < 0.13 then
			k += 0.42
		end
	end
	return DECK_STEEL[1] * k, DECK_STEEL[2] * k, DECK_STEEL[3] * k
end, nil, nil, true, 0.06, 0.3, 0.35)
machined()

-- ----------------------------------------------------------- the cradle
part("Cradle", nil, PANEL_STEEL, function(mesh)
	cylinder(mesh, 0, 0, (DECK_TOP + SEAT_Z) / 2, CRADLE_R, SEAT_Z - DECK_TOP, "z", 32)
	cylinder(mesh, 0, 0, DECK_TOP + 0.13, CRADLE_R + 0.25, 0.26, "z", 32)
	ring(mesh, 0, 0, SEAT_Z + 0.04, 2.2, CRADLE_R - 0.05, 0.08, "z", 32)
	for i = 0, 11 do
		local t = (i + 0.5) / 12 * TAU
		bolt(mesh, math.cos(t) * (CRADLE_R + 0.13), math.sin(t) * (CRADLE_R + 0.13), DECK_TOP + 0.26, "z", 0.09)
	end
end, nil, function(x, y, z)
	local r = math.sqrt(x * x + y * y)
	if z > SEAT_Z + 0.01 and r > 2.15 then
		return RUBBER_BLACK[1], RUBBER_BLACK[2], RUBBER_BLACK[3]
	end
	if z > SEAT_Z - 0.01 and r < CRADLE_R - 0.02 then
		-- Worn steel with a target painted on it, showing where capsules go.
		local acrossX, acrossY = math.abs(x), math.abs(y)
		local tick = (acrossX < 0.07 and acrossY > 1.5 and acrossY < 1.92) or (acrossY < 0.07 and acrossX > 1.5 and acrossX < 1.92)
		if (r > 1.92 and r < 2.04) or tick then
			return HAZARD[1], HAZARD[2], HAZARD[3]
		end
		-- Fine lathe rings, worn bright in the middle where capsules sit.
		local k = 0.93 + 0.05 * math.sin(r * 44) + 0.12 * math.clamp((1.1 - r) / 0.5, 0, 1)
		return SEAT_STEEL[1] * k, SEAT_STEEL[2] * k, SEAT_STEEL[3] * k
	end
	if z < DECK_TOP + 0.28 then
		local k = 0.94 + 0.1 * math.noise(x * 1.5, y * 1.5, 2.2)
		return DECK_STEEL[1] * k, DECK_STEEL[2] * k, DECK_STEEL[3] * k
	end
	-- The tape round the drum, a whole number of stripes so it joins up.
	if z > 0.98 and z < 1.3 then
		if (math.atan2(y, x) / TAU * 15 + z / 1.09) % 1 < 0.5 then
			return TAPE_BLACK[1], TAPE_BLACK[2], TAPE_BLACK[3]
		end
		return HAZARD[1], HAZARD[2], HAZARD[3]
	end
	return PANEL_STEEL[1], PANEL_STEEL[2], PANEL_STEEL[3]
end, nil, nil, true, 0.07)
machined()

-- A cast arm swept along `spine` in the upright plane through the bay's middle
-- at direction (c, s), or `offset` to one side of it. Each spine entry is
-- { radius, height, half thickness, half width }.
local function castArm(mesh, c: number, s: number, spine, offset: number?)
	local rows = {}
	for k, at in spine do
		local before, after = spine[math.max(k - 1, 1)], spine[math.min(k + 1, #spine)]
		local dr, dz = after[1] - before[1], after[2] - before[2]
		local length = math.sqrt(dr * dr + dz * dz)
		dr, dz = dr / length, dz / length
		local row = {}
		for i, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			local r = at[1] + corner[1] * at[3] * dz
			local z = at[2] - corner[1] * at[3] * dr
			local across = (offset or 0) + corner[2] * at[4]
			row[i] = mesh:vertex(c * r - s * across, s * r + c * across, z)
		end
		rows[k] = row
	end
	for k = 1, #rows - 1 do
		for i = 1, 4 do
			local j = i % 4 + 1
			mesh:face({ rows[k][i], rows[k][j], rows[k + 1][j], rows[k + 1][i] })
		end
	end
	mesh:face({ rows[1][4], rows[1][3], rows[1][2], rows[1][1] })
	mesh:face(rows[#rows])
end

-- One part each, so no single part reaches across the seat. Each claw's pad
-- stops at radius 2.33, clear of the widest capsule's corners.
for i, degrees in { 90, 210, 330 } do
	local c, s = math.cos(math.rad(degrees)), math.sin(math.rad(degrees))
	local function at(r: number, z: number): (number, number, number)
		return c * r, s * r, z
	end
	part(`Clamp{i}`, nil, BRONZE, function(mesh)
		local hingeX, hingeY, hingeZ = at(3.02, 1.02)
		-- The claw: heavy at the hinge, tapering, curling in to its rubber pad.
		castArm(mesh, c, s, {
			{ 3.02, 0.9, 0.3, 0.3 },
			{ 3.16, 1.6, 0.26, 0.27 },
			{ 3.12, 2.3, 0.21, 0.23 },
			{ 2.92, 2.92, 0.17, 0.2 },
			{ 2.62, 3.2, 0.15, 0.19 },
			{ 2.5, 3.18, 0.2, 0.27 },
			{ 2.33, 3.18, 0.2, 0.27 },
		})
		-- A lug either side of the claw's heel, standing on the deck, and the
		-- hinge pin through them, so the claw hangs clear and can swing.
		for _, side in { -1, 1 } do
			castArm(mesh, c, s, { { 3.02, 0.48, 0.34, 0.06 }, { 3.02, 1.02, 0.3, 0.06 }, { 3.02, 1.3, 0.16, 0.06 } }, side * 0.37)
		end
		local acrossX, acrossY = -s * 0.5, c * 0.5
		tube(mesh, { { hingeX - acrossX, hingeY - acrossY, hingeZ }, { hingeX + acrossX, hingeY + acrossY, hingeZ } }, 0.2, 10)
	end, nil, function(px, py, pz)
		local r = math.sqrt(px * px + py * py)
		if pz > 2.7 and r < 2.52 then
			return RUBBER_BLACK[1], RUBBER_BLACK[2], RUBBER_BLACK[3]
		end
		local k = 0.96 + 0.06 * math.noise(px * 0.9, py * 0.9, pz * 0.9)
		if math.abs(-s * px + c * py) > 0.31 and pz < 1.4 then
			return PANEL_STEEL[1] * k, PANEL_STEEL[2] * k, PANEL_STEEL[3] * k
		end
		return BRONZE[1] * k, BRONZE[2] * k, BRONZE[3] * k
	end, nil, nil, true, 0.06)
	machined()
end

-- ------------------------------------------------------------ the frame
part("Frame", nil, FRAME_STEEL, function(mesh)
	for _, side in { -1, 1 } do
		local x = side * POST_X
		box(mesh, x, FRAME_Y, DECK_TOP - 0.02, 2 * POST_HALF, 2 * POST_HALF, BEAM_Z0 + 0.1 - DECK_TOP)
		for _, across in { -0.28, 0.28 } do
			rivets(mesh, x + across, FRAME_Y - POST_HALF, 1.1, x + across, FRAME_Y - POST_HALF, 5.8, 5, "y", 0.09)
			rivets(mesh, x + across, FRAME_Y + POST_HALF, 1.1, x + across, FRAME_Y + POST_HALF, 5.8, 5, "y", 0.09)
			rivets(mesh, x + side * POST_HALF, FRAME_Y + across, 1.1, x + side * POST_HALF, FRAME_Y + across, 5.8, 5, "x", 0.09)
		end
		-- The socket of the lamp on the beam's end.
		cylinder(mesh, side * 4.1, FRAME_Y, BEAM_Z1 + 0.06, 0.2, 0.14, "z", 10)
	end
	box(mesh, 0, FRAME_Y, BEAM_Z0, 2 * BEAM_HALF, 0.9, BEAM_Z1 - BEAM_Z0)
	for _, z in { BEAM_Z0 + 0.15, BEAM_Z1 - 0.15 } do
		rivets(mesh, -4.1, FRAME_Y - 0.45, z, 4.1, FRAME_Y - 0.45, z, 9, "y", 0.09)
		rivets(mesh, -4.1, FRAME_Y + 0.45, z, 4.1, FRAME_Y + 0.45, z, 9, "y", 0.09)
	end
	-- Two braces crossing behind the board.
	for _, side in { -1, 1 } do
		strut(mesh, side * 3.25, BOARD_Y + 0.2, 0.85, -side * 3.25, BOARD_Y + 0.2, 6.35, 0.22)
		for _, z0 in { 0.55, 5.95 } do
			box(mesh, side * 2.95, BOARD_Y + 0.34, z0, 0.72, 0.06, 0.62)
			bolt(mesh, side * 2.8, BOARD_Y + 0.38, z0 + 0.31, "y", 0.08)
		end
	end
	bolt(mesh, 0, BOARD_Y + 0.33, 3.6, "y", 0.1)
end, nil, function(x, y, z)
	if z >= BEAM_Z0 then
		local k = 0.94 + 0.1 * math.noise(x * 0.6, z * 0.6, 7.7)
		return DECK_STEEL[1] * k, DECK_STEEL[2] * k, DECK_STEEL[3] * k
	end
	local k = 0.94 + 0.1 * math.noise(x * 0.6, z * 0.6, 6.4)
	return FRAME_STEEL[1] * k, FRAME_STEEL[2] * k, FRAME_STEEL[3] * k
end, nil, nil, true, 0.06, 0.3, 0.35)
machined()

-- The bronze bands at each post's foot and cap, a part of their own so they go
-- on crisp while the posts stay brushed.
part("Bands", nil, BRONZE, function(mesh)
	for _, side in { -1, 1 } do
		local x = side * POST_X
		box(mesh, x, FRAME_Y, DECK_TOP - 0.02, 2 * POST_HALF + 0.22, 2 * POST_HALF + 0.22, 0.38)
		box(mesh, x, FRAME_Y, BEAM_Z0 - 0.6, 2 * POST_HALF + 0.16, 2 * POST_HALF + 0.16, 0.62)
	end
end, nil, function(x, y, z)
	local k = 0.9 + 0.12 * math.noise(x * 1.3, y * 1.3, z * 1.3)
	return BRONZE[1] * k, BRONZE[2] * k, BRONZE[3] * k
end, nil, nil, true, 0.06)
machined()

-- Block letters for the stencil on the board, five wide and seven tall. It
-- sits low, so a seated capsule mostly hides it: it speaks for an empty bay.
local STENCIL = "HATCH"
local STENCIL_CELL, STENCIL_TOP = 0.1, 4.15
local GLYPHS = {
	H = { "1...1", "1...1", "1...1", "11111", "1...1", "1...1", "1...1" },
	A = { ".111.", "1...1", "1...1", "11111", "1...1", "1...1", "1...1" },
	T = { "11111", "..1..", "..1..", "..1..", "..1..", "..1..", "..1.." },
	C = { ".1111", "1....", "1....", "1....", "1....", "1....", ".1111" },
}
local function stencilAt(x: number, z: number): boolean
	local u = x / STENCIL_CELL + (#STENCIL * 6 - 1) / 2
	local v = (STENCIL_TOP - z) / STENCIL_CELL
	if u < 0 or v < 0 then
		return false
	end
	local letter, column, row = math.floor(u / 6) + 1, math.floor(u % 6) + 1, math.floor(v) + 1
	if letter > #STENCIL or column > 5 or row > 7 then
		return false
	end
	return GLYPHS[STENCIL:sub(letter, letter)][row]:sub(column, column) == "1"
end

-- The pegboard's holes, numbered from the board's middle. The paint and the
-- tools' pegs both come from this, so a peg always lands on a hole.
local HOLE_PITCH = 0.5
local function hole(number: number): number
	return (number + 0.5) * HOLE_PITCH
end

part("Board", nil, BOARD_GREY, function(mesh)
	box(mesh, 0, BOARD_Y, DECK_TOP - 0.02, 6.6, 0.2, BEAM_Z0 - DECK_TOP + 0.04)
	for _, x in { hole(-6), hole(5) } do
		for _, z in { hole(1), hole(12) } do
			bolt(mesh, x, BOARD_Y - 0.1, z, "y", 0.11)
		end
	end
end, nil, function(x, y, z)
	-- The stencil across the front, the pegboard's holes right through.
	if math.abs(y - BOARD_Y) > 0.09 then
		if y < BOARD_Y and stencilAt(x, z) then
			return HAZARD[1], HAZARD[2], HAZARD[3]
		end
		local u, v = x % HOLE_PITCH - HOLE_PITCH / 2, z % HOLE_PITCH - HOLE_PITCH / 2
		if u * u + v * v < 0.0036 then
			return 0.09, 0.1, 0.11
		end
	end
	return BOARD_GREY[1], BOARD_GREY[2], BOARD_GREY[3]
end, nil, nil, true, 0.15)
crisp()

-- A double open-ended spanner, traced from a photo of a real one. { across,
-- along } as fractions of its length, the middle at the origin, clockwise as
-- x-z outlines must be.
local SPANNER_OUTLINE = {
	{ 0.0465, 0.4882 },
	{ 0.0728, 0.4575 },
	{ 0.0871, 0.4309 },
	{ 0.0934, 0.4037 },
	{ 0.0900, 0.3752 },
	{ 0.0541, 0.3243 },
	{ 0.0443, 0.3023 },
	{ 0.0395, 0.2768 },
	{ 0.0425, -0.2710 },
	{ 0.0597, -0.2921 },
	{ 0.0842, -0.3176 },
	{ 0.0931, -0.3319 },
	{ 0.1024, -0.3599 },
	{ 0.1045, -0.3930 },
	{ 0.0954, -0.4448 },
	{ 0.0884, -0.4596 },
	{ 0.0812, -0.4649 },
	{ 0.0731, -0.4545 },
	{ 0.0565, -0.3961 },
	{ 0.0478, -0.3846 },
	{ 0.0315, -0.3783 },
	{ 0.0112, -0.3780 },
	{ -0.0087, -0.3830 },
	{ -0.0227, -0.3915 },
	{ -0.0344, -0.4028 },
	{ -0.0389, -0.4155 },
	{ -0.0249, -0.4797 },
	{ -0.0262, -0.4926 },
	{ -0.0323, -0.4972 },
	{ -0.0607, -0.4743 },
	{ -0.0743, -0.4579 },
	{ -0.0915, -0.4278 },
	{ -0.0989, -0.3955 },
	{ -0.0955, -0.3679 },
	{ -0.0507, -0.3034 },
	{ -0.0422, -0.2720 },
	{ -0.0431, 0.2744 },
	{ -0.0540, 0.2982 },
	{ -0.0926, 0.3437 },
	{ -0.0998, 0.3703 },
	{ -0.1010, 0.3938 },
	{ -0.0914, 0.4405 },
	{ -0.0855, 0.4535 },
	{ -0.0786, 0.4583 },
	{ -0.0708, 0.4516 },
	{ -0.0560, 0.3987 },
	{ -0.0478, 0.3872 },
	{ -0.0334, 0.3829 },
	{ -0.0143, 0.3837 },
	{ 0.0167, 0.3982 },
	{ 0.0298, 0.4109 },
	{ 0.0338, 0.4207 },
	{ 0.0197, 0.4852 },
	{ 0.0217, 0.4949 },
	{ 0.0286, 0.4978 },
}
-- Where the underside of the top head meets a pair of pegs half a hole apart
-- on the Big Spanner, and how far the head's flare sits off the shank's middle.
local SPANNER_REST_ALONG, SPANNER_REST_ACROSS = 0.3299, -0.0114

-- A peg out of the board with a small head, so what hangs on it stays on.
local function peg(mesh, x: number, z: number, radius: number)
	cylinder(mesh, x, TOOL_Y - 0.06, z, radius, 0.4, "y", 8)
	cylinder(mesh, x, TOOL_Y - 0.25, z, radius * 1.5, 0.05, "y", 8)
end

-- The Big Spanner hangs with its head resting on two pegs, the shank between
-- them. The small one lies across two pegs, its heads stopping it sliding off.
local BIG_LENGTH, BIG_PEG_Z, BIG_PEG_RADIUS = 3.6, hole(11), 0.07
local BIG_X = (hole(-6) + hole(-5)) / 2 - SPANNER_REST_ACROSS * BIG_LENGTH
local BIG_Z = BIG_PEG_Z + BIG_PEG_RADIUS + 0.03 - SPANNER_REST_ALONG * BIG_LENGTH
local SMALL_LENGTH, SMALL_PEG_Z, SMALL_PEG_RADIUS = 1.2, hole(11), 0.05
local SMALL_X = (hole(4) + hole(5)) / 2
local SMALL_Z = SMALL_PEG_Z + SMALL_PEG_RADIUS + 0.05
local function onBigSpanner(across: number, along: number): (number, number)
	return BIG_X + across * BIG_LENGTH, BIG_Z + along * BIG_LENGTH
end
-- Turned a quarter round, which keeps the outline clockwise.
local function onSmallSpanner(across: number, along: number): (number, number)
	return SMALL_X + along * SMALL_LENGTH, SMALL_Z - across * SMALL_LENGTH
end
local function spanner(mesh, place, depth: number, bevel: number)
	local outline = {}
	for i, point in SPANNER_OUTLINE do
		local x, z = place(point[1], point[2])
		outline[i] = { x, z }
	end
	plate(mesh, outline, TOOL_Y, depth, bevel)
end
-- The shank's recessed middle, narrowing out at each end as on the real thing.
local function inShankRecess(across: number, along: number): boolean
	return math.abs(across) < 0.024 * math.clamp((0.29 - math.abs(along)) / 0.03, 0, 1)
end

local HAMMER_LEFT_PEG, HAMMER_RIGHT_PEG, HAMMER_PEG_Z = hole(1), hole(2), hole(11)
local HAMMER_X, HEAD_BASE = (HAMMER_LEFT_PEG + HAMMER_RIGHT_PEG) / 2, HAMMER_PEG_Z + 0.07
part("Tools", nil, TOOL_STEEL, function(mesh)
	-- The Big Spanner left of the capsule, a small one above the panel.
	spanner(mesh, onBigSpanner, 0.1, 0.012)
	peg(mesh, hole(-6), BIG_PEG_Z, BIG_PEG_RADIUS)
	peg(mesh, hole(-5), BIG_PEG_Z, BIG_PEG_RADIUS)
	spanner(mesh, onSmallSpanner, 0.06, 0.004)
	peg(mesh, hole(4), SMALL_PEG_Z, SMALL_PEG_RADIUS)
	peg(mesh, hole(5), SMALL_PEG_Z, SMALL_PEG_RADIUS)
	-- A hammer hanging head up: its head rests on two pegs, the handle between.
	box(mesh, HAMMER_X, TOOL_Y, HEAD_BASE - 1.38, 0.16, 0.1, 1.42)
	box(mesh, HAMMER_X, TOOL_Y, HEAD_BASE, 0.76, 0.16, 0.34)
	peg(mesh, HAMMER_LEFT_PEG, HAMMER_PEG_Z, 0.07)
	peg(mesh, HAMMER_RIGHT_PEG, HAMMER_PEG_Z, 0.07)
end, nil, function(x, y, z)
	if math.abs(x - HAMMER_X) < 0.1 and z < HEAD_BASE then
		return WOOD[1], WOOD[2], WOOD[3]
	elseif math.abs(x - HAMMER_X) < 0.4 and z >= HEAD_BASE then
		return DECK_STEEL[1], DECK_STEEL[2], DECK_STEEL[3]
	end
	-- Forged steel, darker in the shank's recess on the front face.
	local across, along = (x - BIG_X) / BIG_LENGTH, (z - BIG_Z) / BIG_LENGTH
	if x > 0 then
		across, along = (SMALL_Z - z) / SMALL_LENGTH, (x - SMALL_X) / SMALL_LENGTH
	end
	local k = if y < TOOL_Y - 0.025 and inShankRecess(across, along) then 0.74 else 1
	return TOOL_STEEL[1] * k, TOOL_STEEL[2] * k, TOOL_STEEL[3] * k
end, nil, nil, true, 0.06, nil, 0.5)
machined()

part("Panel", nil, PANEL_STEEL, function(mesh)
	box(mesh, PANEL_X, TOOL_Y, 2.5, 1.3, 0.26, 2.4)
	for _, x in { hole(3), hole(5) } do
		for _, z in { hole(5), hole(9) } do
			bolt(mesh, x, TOOL_Y - 0.13, z, "y", 0.07)
		end
	end
	-- The dial, its bezel, and a lever in a slotted plate.
	cylinder(mesh, PANEL_X, 3.6, DIAL_Z, 0.46, 0.06, "y", 24)
	ring(mesh, PANEL_X, 3.58, DIAL_Z, 0.44, 0.54, 0.12, "y", 24)
	box(mesh, PANEL_X + 0.32, 3.58, 2.72, 0.24, 0.1, 0.56)
	strut(mesh, PANEL_X + 0.32, 3.6, 2.9, PANEL_X + 0.32, 3.3, 3.42, 0.08)
	sphere(mesh, PANEL_X + 0.32, 3.3, 3.42, 0.18, 0.18, 0.18, 5, 10)
	-- The cable down the board and across the deck to the drum.
	tube(mesh, { { PANEL_X - 0.3, 3.7, 2.55 }, { PANEL_X - 0.3, 3.62, 0.62 }, { 2.55, 2.6, 0.6 }, { 2.35, 1.75, 0.62 }, { 1.95, 1.6, 0.95 } }, 0.1, 8)
end, nil, function(x, y, z)
	if z < 2.45 then
		return RUBBER_BLACK[1], RUBBER_BLACK[2], RUBBER_BLACK[3]
	end
	-- The lever: a red knob on a dark stem, so it doesn't read as a button.
	if (x - PANEL_X - 0.32) ^ 2 + (y - 3.3) ^ 2 + (z - 3.42) ^ 2 < 0.05 then
		return 0.72, 0.14, 0.1
	end
	if y < 3.52 and math.abs(x - PANEL_X - 0.32) < 0.1 and z > 2.8 and z < 3.42 then
		return RUBBER_BLACK[1], RUBBER_BLACK[2], RUBBER_BLACK[3]
	end
	local dx, dz = x - PANEL_X, z - DIAL_Z
	if y < 3.6 and dx * dx + dz * dz < 0.19 then
		local along, across = dx * 0.6 + dz * 0.8, math.abs(dx * 0.8 - dz * 0.6)
		if across < 0.03 and along > -0.05 and along < 0.36 then
			return 0.7, 0.14, 0.1
		end
		return CREAM[1], CREAM[2], CREAM[3]
	end
	return PANEL_STEEL[1], PANEL_STEEL[2], PANEL_STEEL[3]
end, nil, nil, true, 0.06)
machined()

-- ---------------------------------------------------------- the lighting
part("Arm", nil, FRAME_STEEL, function(mesh)
	local ELBOW_Y, ELBOW_Z = 2.35, 7.2
	box(mesh, 0, FRAME_Y - 0.55, BEAM_Z0 + 0.15, 0.6, 0.24, 0.6)
	strut(mesh, 0, FRAME_Y - 0.6, BEAM_Z0 + 0.45, 0, ELBOW_Y, ELBOW_Z, 0.2)
	strut(mesh, 0, ELBOW_Y, ELBOW_Z, 0, SHADE_Y, SHADE_Z + 0.1, 0.16)
	cylinder(mesh, 0, ELBOW_Y, ELBOW_Z, 0.2, 0.34, "x", 12)
	-- The shade, open underneath: outside, rim, then inside.
	lathe(mesh, { 0, SHADE_Y, SHADE_Z }, { 1, 0, 0 }, { 0, -SHADE_COS, SHADE_SIN }, { 0, -SHADE_SIN, -SHADE_COS }, { { 0.28, 0 }, { 0.55, 0.7 }, { 0.5, 0.7 }, { 0.24, 0.1 } }, 20)
end, nil, function(x, y, z)
	-- How far along the shade's axis this is, and how far from it.
	local dy, dz = y - SHADE_Y, z - SHADE_Z
	local along = -dy * SHADE_SIN - dz * SHADE_COS
	if along > -0.02 and along < 0.72 then
		local across = dy * -SHADE_COS + dz * SHADE_SIN
		local r = math.sqrt(x * x + across * across)
		if r < 0.28 + 0.27 * along / 0.7 - 0.03 then
			return CREAM[1], CREAM[2], CREAM[3]
		end
		return HAZARD[1], HAZARD[2], HAZARD[3]
	end
	local k = 0.94 + 0.1 * math.noise(y * 1.5, z * 1.5, 3.3)
	return FRAME_STEEL[1] * k, FRAME_STEEL[2] * k, FRAME_STEEL[3] * k
end, nil, nil, true, 0.1)
crisp()

part("Posts", nil, PANEL_STEEL, function(mesh)
	for _, side in { -1, 1 } do
		local x, y = side * LAMP_POST, -LAMP_POST
		box(mesh, x, y, DECK_TOP - 0.02, 0.5, 0.5, 0.14)
		cylinder(mesh, x, y, (DECK_TOP + LAMP_TOP) / 2, 0.14, LAMP_TOP - DECK_TOP, "z", 10)
		-- The bracket arm reaching in over the deck.
		tube(mesh, { { x, y, LAMP_TOP - 0.2 }, { x - side * 0.42, y + 0.42, LAMP_TOP + 0.02 } }, 0.07, 6)
	end
end, nil, function(_x, _y, _z)
	return PANEL_STEEL[1], PANEL_STEEL[2], PANEL_STEEL[3]
end, nil, nil, true, 0.06)
machined()

-- The glowing lamps, as two parts so that neither reaches across the seat:
-- the pair at the front, and the rest, all behind the middle.
part("PostLamps", nil, AMBER, function(mesh)
	for _, side in { -1, 1 } do
		sphere(mesh, side * (LAMP_POST - 0.45), -LAMP_POST + 0.45, LAMP_TOP + 0.05, 0.26, 0.26, 0.26, 6, 10)
	end
end, true, 0, nil, 1.4)

part("BackLamps", nil, AMBER, function(mesh)
	for _, side in { -1, 1 } do
		sphere(mesh, side * 4.1, FRAME_Y, BEAM_Z1 + 0.3, 0.3, 0.3, 0.3, 6, 10)
	end
	-- The work lamp's bulb, inside its shade.
	sphere(mesh, 0, SHADE_Y - 0.42 * SHADE_SIN, SHADE_Z - 0.42 * SHADE_COS, 0.2, 0.2, 0.2, 6, 10)
	-- The green indicators along the beam, and the red ARMED lamp.
	for i = -5, 5 do
		sphere(mesh, i * 0.45, FRAME_Y - 0.46, (BEAM_Z0 + BEAM_Z1) / 2, 0.14, 0.07, 0.14, 4, 8)
	end
	sphere(mesh, PANEL_X - 0.2, 3.6, 3.3, 0.2, 0.12, 0.2, 5, 10)
end, true, function(x, y, z)
	if z > BEAM_Z0 and z < BEAM_Z1 - 0.1 and y < FRAME_Y - 0.3 then
		return 0.35, 1, 0.4
	elseif x > 1.8 and z < 4 and y > 3 then
		return 1, 0.2, 0.15
	end
	return AMBER[1], AMBER[2], AMBER[3]
end, nil, 1.4)

-- ------------------------------------------------------------- the clutter
part("Crate", nil, WOOD, function(mesh)
	box(mesh, CRATE_X, CRATE_Y, DECK_TOP - 0.02, 1.5, 1.2, 1.02)
	for _, side in { -1, 1 } do
		box(mesh, CRATE_X, CRATE_Y + side * 0.62, DECK_TOP - 0.02, 1.7, 0.16, 1.22)
		box(mesh, CRATE_X + side * 0.77, CRATE_Y, DECK_TOP - 0.02, 0.16, 1.1, 1.2)
	end
	-- What's in it: a gear standing up, a pipe end, a washer.
	gear(mesh, CRATE_X - 0.3, CRATE_Y + 0.1, 1.72, 0.42, 0.14, 9, "y")
	tube(mesh, { { CRATE_X + 0.1, CRATE_Y - 0.2, 1.42 }, { CRATE_X + 0.52, CRATE_Y - 0.1, 1.95 } }, 0.1, 8)
	ring(mesh, CRATE_X + 0.25, CRATE_Y + 0.3, 1.53, 0.12, 0.24, 0.1, "z", 10)
end, nil, function(x, y, z)
	local k = 0.9 + 0.14 * math.noise(x * 1.5, y * 1.5, z * 3)
	if z > 1.5 and math.abs(x - CRATE_X) < 0.69 and math.abs(y - CRATE_Y) < 0.54 then
		if x < CRATE_X then
			return BRASS[1] * k, BRASS[2] * k, BRASS[3] * k
		end
		return BARE[1] * k, BARE[2] * k, BARE[3] * k
	end
	-- Planks, with dark gaps between them.
	if (z - DECK_TOP) % 0.4 < 0.03 then
		k *= 0.45
	end
	return WOOD[1] * k, WOOD[2] * k, WOOD[3] * k
end, nil, nil, true, 0.12)

part("Drum", nil, OIL_BLUE, function(mesh)
	cylinder(mesh, OIL_X, OIL_Y, DECK_TOP + 0.8, 0.62, 1.6, "z", 20)
	for _, z in { DECK_TOP + 0.5, DECK_TOP + 1.1, DECK_TOP + 1.58 } do
		ring(mesh, OIL_X, OIL_Y, z, 0.6, 0.67, 0.08, "z", 20)
	end
	-- The funnel in its filler hole.
	lathe(mesh, { OIL_X + 0.2, OIL_Y, 2.06 }, { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 }, { { 0.07, 0 }, { 0.07, 0.2 }, { 0.26, 0.42 }, { 0.22, 0.42 }, { 0.05, 0.22 } }, 12)
end, nil, function(_x, _y, _z)
	return OIL_BLUE[1], OIL_BLUE[2], OIL_BLUE[3]
end, nil, nil, nil, 0.08)
machined()

finishParts()
