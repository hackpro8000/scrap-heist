local CACHE_KEY = "JunkrotRusteliRustela-2072b9e1c278ea4c"
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
-- Rusteli Rustela: Lirili Larila from scrap. A tall green oil barrel
-- ribbed like a cactus and bristling with rebar spines, standing up on
-- just two massive elephant legs in tyre-rubber sandals, toenails and all;
-- on top a grey tin elephant's head with huge sheet-tin ears, a hose trunk
-- hanging down its front and curling up at the end, two tusks and its own
-- small eyes; a cactus flower blooming on its back. No googly face. 4
-- studs tall.
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
local BARREL_GREEN = { 0.3, 0.52, 0.36 }
local ELEPHANT = { 0.6, 0.6, 0.58 }
local HIPS = 1.3 -- where the barrel starts, the legs' tops
local CROWN = 3.0 -- the barrel's top
local HEAD = { 0, -0.42, 3.05 }
local LEGS = { -0.42, 0.42 } -- the two legs' x
part("Barrel", nil, BARREL_GREEN, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.62, 0 }, { 0.74, 0.12 }, { 0.8, 0.6 }, { 0.8, 1.3 }, { 0.72, 1.6 }, { 0.5, 1.72 }, { 0, CROWN - HIPS } }, 24)
	-- Ribbed like a cactus: eight ribs round.
	m:transform(function(p)
		local f = 1 + 0.08 * math.cos(math.atan2(p[2], p[1]) * 8)
		return { p[1] * f, p[2] * f, p[3] }
	end)
	m:translate(0, 0.1, HIPS)
	m:emit(mesh)
end, 40, 0.3)
part("Spikes", nil, DARK_STEEL, function(mesh)
	-- Rebar spines along the rib crests, all round but the front, where the
	-- trunk hangs.
	for rib = 0, 7 do
		local a = rib * 45
		local c, s = math.cos(math.rad(a)), math.sin(math.rad(a))
		if s > -0.8 then
			for _, z in { 0.3, 0.75, 1.2 } do
				local spike = EditMesh.cone(0.04, 0.008, 0.3, 4, 1)
				-- Pointing straight out from the barrel's axis.
				Kit.turn(spike, "y", 90)
				Kit.turn(spike, "z", a)
				spike:translate(c * 0.98, 0.1 + s * 0.98, HIPS + z + (rib % 2) * 0.2)
				spike:emit(mesh)
			end
		end
	end
end, 40, 0.4)
part("Head", nil, ELEPHANT, function(mesh)
	local m = EditMesh.sphere(0.62, 12)
	Kit.size(m, { 1.05, 0.95, 0.95 })
	m:translate(HEAD[1], HEAD[2], HEAD[3])
	m:emit(mesh)
	-- Two massive legs, wider at the foot, and a thin tail behind.
	for _, x in LEGS do
		local leg = Kit.lathe({ { 0, 0 }, { 0.45, 0 }, { 0.44, 0.15 }, { 0.38, 0.6 }, { 0.37, HIPS - 0.05 }, { 0.3, HIPS + 0.25 }, { 0, HIPS + 0.3 } }, 16)
		leg:translate(x, 0.05, 0.1)
		leg:emit(mesh)
	end
	Kit.tube({ { 0, 0.88, HIPS + 0.6 }, { 0, 1.15, HIPS + 0.35 }, { 0.05, 1.22, HIPS }, }, 0.05, 6):emit(mesh)
end, true, 0.3)
part("Ears", nil, { 0.72, 0.7, 0.66 }, function(mesh)
	-- Huge flat tin ears out to the sides, facing forward.
	local outline = { { -0.1, -0.6 }, { 0.35, -0.5 }, { 0.6, -0.1 }, { 0.55, 0.35 }, { 0.2, 0.6 }, { -0.25, 0.4 }, { -0.35, -0.15 } }
	for _, side in { -1, 1 } do
		local ear = Kit.plate(outline, 0.05)
		if side < 0 then
			Kit.turn(ear, "z", 180)
		end
		Kit.turn(ear, "z", side * -15)
		ear:translate(HEAD[1] + side * 0.55, HEAD[2] + 0.1, HEAD[3] + 0.05)
		ear:emit(mesh)
	end
end, 40, 0.3)
part("Trunk", nil, { 0.16, 0.16, 0.17 }, function(mesh)
	local path = Kit.curve({
		{ 0, HEAD[2] - 0.45, HEAD[3] - 0.15 },
		{ 0, HEAD[2] - 0.66, HEAD[3] - 0.55 },
		{ 0, HEAD[2] - 0.7, HEAD[3] - 1.15 },
		{ 0, HEAD[2] - 0.78, HEAD[3] - 1.5 },
		{ 0, HEAD[2] - 1.0, HEAD[3] - 1.45 },
	}, 4)
	Kit.tube(path, function(t)
		return 0.17 - 0.07 * t
	end, 10):emit(mesh)
end, true, RUBBER)
part("Tusks", nil, { 0.92, 0.9, 0.82 }, function(mesh)
	for _, side in { -1, 1 } do
		local path = Kit.curve({ { side * 0.22, HEAD[2] - 0.4, HEAD[3] - 0.3 }, { side * 0.3, HEAD[2] - 0.72, HEAD[3] - 0.5 }, { side * 0.26, HEAD[2] - 0.9, HEAD[3] - 0.3 } }, 3)
		Kit.tube(path, function(t)
			return 0.065 * (1 - 0.75 * t)
		end, 8):emit(mesh)
	end
	-- Toenails, three on the front of each foot.
	for _, x in LEGS do
		for k = -1, 1 do
			local nail = EditMesh.sphere(0.08, 8)
			Kit.size(nail, { 1, 0.6, 0.8 })
			nail:translate(x + k * 0.2, 0.05 - 0.43, 0.24)
			nail:emit(mesh)
		end
	end
end, true, 0.1)
part("Eyes", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, side in { -1, 1 } do
		local eye = EditMesh.sphere(0.075, 8)
		eye:translate(HEAD[1] + side * 0.3, HEAD[2] - 0.5, HEAD[3] + 0.16)
		eye:emit(mesh)
	end
end, true, 0)
part("Sandals", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	for _, x in LEGS do
		local sole = Kit.block(1.0, 1.05, 0.1, 0.05)
		sole:translate(x, -0.05, 0.05)
		sole:emit(mesh)
		Kit.tube({ { x - 0.42, -0.1, 0.1 }, { x, -0.35, 0.35 }, { x + 0.42, -0.1, 0.1 } }, 0.04, 6):emit(mesh)
	end
end, 40, RUBBER)
part("Flower", nil, { 0.95, 0.45, 0.6 }, function(mesh)
	-- A cactus flower blooming on its back: petals round a heart, each
	-- starting a little out from the middle so none share a point.
	for k = 0, 5 do
		local petal = Kit.plate({ { -0.06, 0.04 }, { 0.06, 0.04 }, { 0.08, 0.2 }, { 0, 0.26 }, { -0.08, 0.2 } }, 0.03)
		Kit.turn(petal, "x", 50)
		Kit.turn(petal, "z", k * 60)
		petal:translate(0, 0.45, CROWN - 0.12)
		petal:emit(mesh)
	end
end, 40, 0)
part("FlowerHeart", nil, { 1.0, 0.85, 0.25 }, function(mesh)
	local m = EditMesh.sphere(0.08, 8)
	m:translate(0, 0.45, CROWN - 0.06)
	m:emit(mesh)
end, true, 0)
finishParts()
