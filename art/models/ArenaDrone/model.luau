local CACHE_KEY = "ArenaDrone-f9581083b0e3d10e"
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
-- Arena Drone: the storm arena, carried over the map by a scrap-built
-- quadcopter instead of standing on a floating island. An open octagonal
-- ring girder holds the deck: steel grating over the ring, so it can be
-- walked on and still seen through, and solid plating inside it banking
-- down to the fight floor. Four truss arms will carry the motors and
-- propellers, with a battery pack slung under the middle.
-- Built 1.5 times the old arena island's size, as the yards are: the fight
-- floor is 108 studs across and the plating's rim 150. The deck's top
-- stands at z = 0; the ring's outer edge is 90 studs out on a flat side.
useTexelDensity(16)

local GIRDER = { 0.5, 0.24, 0.15 }
local HAZARD_YELLOW = { 0.9, 0.72, 0.15 }
local HAZARD_BLACK = { 0.11, 0.11, 0.12 }

-- The truss (ring girder and arms) is painted in yellow and black hazard
-- bands. The bands are planes across the model, tilted so no strut runs
-- along them: every member, whichever way it runs, shows stripes.
local HAZARD_BAND = 4
local HAZARD_AXIS = { 1, 0.41, 0.57 }
local paintHazard = rusting(0.6, function(x, y, z)
	local along = x * HAZARD_AXIS[1] + y * HAZARD_AXIS[2] + z * HAZARD_AXIS[3]
	local colour = if math.floor(along / HAZARD_BAND) % 2 == 0 then HAZARD_YELLOW else HAZARD_BLACK
	return colour[1], colour[2], colour[3]
end)
local PLATING = { 0.47, 0.47, 0.46 }

-- Octagon sizes, as the distance to the middle of a flat side. A flat side
-- faces each axis, as on the Server Map.
local RING_OUTER, RING_INNER = 90, 75
local FLOOR = 54
-- The floor plating is laid in rings round a small octagon in the middle.
local FLOOR_HUB = 6
-- The bank keeps the old arena's slope: its depth grew with its width.
local BOWL_DEPTH = 8.25
local PLATE_THICK = 0.5
-- The ring girder hangs under the grating.
local GIRDER_TOP, GIRDER_BOTTOM = -0.5, -9
local CHORD = 1.3
local WEB = 0.8
-- Truss panels along each side of the ring.
local PANELS = 8

-- Corner k (0-7) of an octagon, corners sitting between the axes.
local CORNER_SCALE = 1 / math.cos(math.pi / 8)
local function corner(apothem: number, k: number): (number, number)
	local angle = math.pi / 8 + k * math.pi / 4
	return math.cos(angle) * apothem * CORNER_SCALE, math.sin(angle) * apothem * CORNER_SCALE
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- A four-sided patch split into a grid, so the warp can dent it and its
-- texture keeps an even density. Corners run anticlockwise seen from the
-- side the face looks out of.
local function patch(mesh, p00, p10, p11, p01, nu: number, nv: number)
	local rows = {}
	for j = 0, nv do
		rows[j] = {}
		local v = j / nv
		for i = 0, nu do
			local u = i / nu
			local x = lerp(lerp(p00[1], p10[1], u), lerp(p01[1], p11[1], u), v)
			local y = lerp(lerp(p00[2], p10[2], u), lerp(p01[2], p11[2], u), v)
			local z = lerp(lerp(p00[3], p10[3], u), lerp(p01[3], p11[3], u), v)
			rows[j][i] = mesh:vertex(x, y, z)
		end
	end
	for j = 0, nv - 1 do
		for i = 0, nu - 1 do
			mesh:face({ rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i] })
		end
	end
end

local function cells(length: number): number
	return math.clamp(math.ceil(length / 6), 1, 32)
end

-- The deck plating: the bank from the rim down to the floor and the floor
-- itself, each side's panel a plate with a top, an underside and a lip at
-- the rim.
chunkedPart("Plating", nil, PLATING, function(mesh)
	for k = 0, 7 do
		local rx0, ry0 = corner(RING_INNER, k)
		local rx1, ry1 = corner(RING_INNER, k + 1)
		local fx0, fy0 = corner(FLOOR, k)
		local fx1, fy1 = corner(FLOOR, k + 1)
		local side = 2 * RING_INNER * math.tan(math.pi / 8)
		local mx0, my0 = corner(FLOOR_HUB, k)
		local mx1, my1 = corner(FLOOR_HUB, k + 1)
		for _, layer in { { 0, 1 }, { -PLATE_THICK, -1 } } do
			local dz, facing = layer[1], layer[2]
			local floorZ = dz - BOWL_DEPTH
			local rim0, rim1 = { rx0, ry0, dz }, { rx1, ry1, dz }
			local low0, low1 = { fx0, fy0, floorZ }, { fx1, fy1, floorZ }
			local hub0, hub1 = { mx0, my0, floorZ }, { mx1, my1, floorZ }
			-- Faces wind anticlockwise seen from outside, as box() does.
			if facing > 0 then
				patch(mesh, low1, low0, rim0, rim1, cells(side), cells(RING_INNER - FLOOR))
				patch(mesh, hub1, hub0, low0, low1, cells(side), cells(FLOOR - FLOOR_HUB))
			else
				patch(mesh, low0, low1, rim1, rim0, cells(side), cells(RING_INNER - FLOOR))
				patch(mesh, hub0, hub1, low1, low0, cells(side), cells(FLOOR - FLOOR_HUB))
			end
		end
		-- The lip where the plating meets the grating.
		patch(mesh, { rx0, ry0, -PLATE_THICK }, { rx1, ry1, -PLATE_THICK }, { rx1, ry1, 0 }, { rx0, ry0, 0 }, cells(side), 1)
	end
	-- The small octagon in the middle of the floor, top and underside.
	for _, z in { -BOWL_DEPTH, -BOWL_DEPTH - PLATE_THICK } do
		local ring = {}
		for k = 0, 7 do
			local x, y = corner(FLOOR_HUB, k)
			ring[k + 1] = mesh:vertex(x, y, z)
		end
		if z < -BOWL_DEPTH then
			ring = { ring[8], ring[7], ring[6], ring[5], ring[4], ring[3], ring[2], ring[1] }
		end
		mesh:face(ring)
	end
end, nil, 0.3, nil, 1.5)

-- Steel grating over the ring girder: flat bars running round the ring,
-- crossed by thin bars every stud, open between them so the girders and
-- the sky show through.
local GRATE_BAR, GRATE_HEIGHT = 0.25, 0.3
local GRATE_ROWS = 6
local GRATE_PITCH = 1
-- Thin bars unwrap into many small islands, so at the deck's texel density
-- they would need hundreds of textures; each side's bars and girders are
-- one part with a fixed texture instead.
local GRATE_TEXTURE, GIRDER_TEXTURE = 256, 512
for k = 0, 7 do
	part(`Grating{k + 1}`, nil, DARK_STEEL, function(mesh)
		local z = -GRATE_HEIGHT / 2
		local ix0, iy0 = corner(RING_INNER, k)
		local ix1, iy1 = corner(RING_INNER, k + 1)
		local ox0, oy0 = corner(RING_OUTER, k)
		local ox1, oy1 = corner(RING_OUTER, k + 1)
		-- Bearing bars round the ring, inner edge to outer edge.
		for r = 0, GRATE_ROWS do
			local t = r / GRATE_ROWS
			strut(mesh, lerp(ix0, ox0, t), lerp(iy0, oy0, t), z, lerp(ix1, ox1, t), lerp(iy1, oy1, t), z, GRATE_BAR)
		end
		-- Cross bars, across the ring at a stud's spacing.
		local length = 2 * RING_OUTER * math.tan(math.pi / 8)
		local count = math.floor(length / GRATE_PITCH)
		for c = 1, count - 1 do
			local t = c / count
			local ax, ay = lerp(ix0, ix1, t), lerp(iy0, iy1, t)
			local bx, by = lerp(ox0, ox1, t), lerp(oy0, oy1, t)
			strut(mesh, ax, ay, z + GRATE_HEIGHT * 0.15, bx, by, z + GRATE_HEIGHT * 0.15, GRATE_BAR * 0.6)
		end
	end, nil, 0.5, GRATE_TEXTURE, nil, true)
end

-- The ring girder: an inner and an outer truss wall round the octagon,
-- top and bottom chords with a zigzag web between, tied across the ring
-- at every panel point.
local inner, outer = RING_INNER + 1, RING_OUTER - 1
local top, bottom = GIRDER_TOP - CHORD / 2, GIRDER_BOTTOM + CHORD / 2
for k = 0, 7 do
	part(`Girder{k + 1}`, nil, GIRDER, function(mesh)
		local ix0, iy0 = corner(inner, k)
		local ix1, iy1 = corner(inner, k + 1)
		local ox0, oy0 = corner(outer, k)
		local ox1, oy1 = corner(outer, k + 1)
		for _, wall in { { ix0, iy0, ix1, iy1 }, { ox0, oy0, ox1, oy1 } } do
			local x0, y0, x1, y1 = wall[1], wall[2], wall[3], wall[4]
			strut(mesh, x0, y0, top, x1, y1, top, CHORD)
			strut(mesh, x0, y0, bottom, x1, y1, bottom, CHORD)
			for p = 0, PANELS - 1 do
				local a, b = p / PANELS, (p + 1) / PANELS
				local ax, ay, bx, by = lerp(x0, x1, a), lerp(y0, y1, a), lerp(x0, x1, b), lerp(y0, y1, b)
				strut(mesh, ax, ay, top, ax, ay, bottom, WEB)
				if p % 2 == 0 then
					strut(mesh, ax, ay, top, bx, by, bottom, WEB)
				else
					strut(mesh, ax, ay, bottom, bx, by, top, WEB)
				end
			end
		end
		-- Ties across the ring at each panel point, top and bottom, with a
		-- diagonal brace in every other bay.
		for p = 0, PANELS - 1 do
			local t = p / PANELS
			local ax, ay = lerp(ix0, ix1, t), lerp(iy0, iy1, t)
			local bx, by = lerp(ox0, ox1, t), lerp(oy0, oy1, t)
			strut(mesh, ax, ay, top, bx, by, top, WEB)
			strut(mesh, ax, ay, bottom, bx, by, bottom, WEB)
			if p % 2 == 0 then
				strut(mesh, ax, ay, top, bx, by, bottom, WEB)
			end
		end
	end, nil, paintHazard, GIRDER_TEXTURE, nil, nil, 1)
end

-- Radial beams from the ring's inner wall to the middle, holding the
-- plating up from underneath.
part("Joists", nil, GIRDER, function(mesh)
	local depth = 1.6
	for k = 0, 7 do
		local x, y = corner(RING_INNER + 1, k)
		local fx, fy = corner(FLOOR, k)
		local under = -PLATE_THICK - depth / 2
		-- Along the bank, then flat under the floor.
		strut(mesh, x, y, GIRDER_TOP - CHORD, fx, fy, under - BOWL_DEPTH, depth)
		strut(mesh, fx, fy, under - BOWL_DEPTH, 0, 0, under - BOWL_DEPTH, depth)
	end
end, nil, 0.6, GIRDER_TEXTURE)

-- Four truss arms in an X, each a box truss of four chords tapering out
-- from the ring to a motor 175 studs from the middle. Inside the ring the
-- arm runs level under the grating, tied into the girder; past the ring
-- it climbs to the collar clamped round the motor.
local ARM_DIRECTIONS = { 45, 135, 225, 315 }
local MOTOR_OUT = 175
local ARM_ROOT = RING_INNER + 1
local ARM_PANEL = 8
local ARM_TEXTURE, MOTOR_TEXTURE = 512, 256
-- Each motor is gripped round its lower body by a steel collar, and the
-- arm's tip is welded to the collar's inner side. The collar's height
-- covers the arm's tip, which ends where its chords meet the collar.
local COLLAR_INNER, COLLAR_OUTER, COLLAR_HEIGHT = 5.3, 6.8, 3.6
local ARM_TIP_TOP, ARM_TIP_BOTTOM, ARM_TIP_HALF = 8, 5, 3
local ARM_END = MOTOR_OUT - math.sqrt(COLLAR_OUTER ^ 2 - ARM_TIP_HALF ^ 2) + 0.3
-- Half width across the arm, and its top and bottom chords' heights, at a
-- distance out from the middle.
local function armShape(r: number): (number, number, number)
	local t = math.clamp((r - ARM_ROOT) / (ARM_END - ARM_ROOT), 0, 1)
	local climb = math.clamp((r - RING_OUTER) / (ARM_END - RING_OUTER), 0, 1)
	return lerp(7, ARM_TIP_HALF, t), lerp(top, ARM_TIP_TOP, climb), lerp(bottom, ARM_TIP_BOTTOM, climb)
end
-- The motors lean in towards the middle, so the propellers on them tilt
-- that way too. Each motor and its collar lean about the point where the
-- collar meets the arm's tip, so the weld stays put.
local MOTOR_TILT = math.rad(8)
local MOTOR_PIVOT = COLLAR_OUTER
local MOTOR_PIVOT_Z = (ARM_TIP_TOP + ARM_TIP_BOTTOM) / 2
-- The motor's bottom hangs a stud below the collar.
local MOTOR_BASE = MOTOR_PIVOT_Z - COLLAR_HEIGHT / 2 - 1

-- Where (x, y, z) ends up tipped about a level axis through (px, py, pz),
-- so whatever stands up from the pivot leans `angle` towards (-dx, -dy).
local function tipped(px: number, py: number, pz: number, dx: number, dy: number, angle: number, x: number, y: number, z: number)
	local c, s = math.cos(angle), math.sin(angle)
	local ox, oy, oz = x - px, y - py, z - pz
	local out = ox * dx + oy * dy
	local across = -ox * dy + oy * dx
	out, oz = out * c - oz * s, out * s + oz * c
	return px + out * dx - across * dy, py + out * dy + across * dx, pz + oz
end

-- Builds into a mesh tipped about a level axis through (px, py, pz), so
-- whatever stands up from the pivot leans `angle` towards (-dx, -dy).
local function leaning(mesh, px: number, py: number, pz: number, dx: number, dy: number, angle: number)
	return setmetatable({
		vertex = function(_, x, y, z)
			return mesh:vertex(tipped(px, py, pz, dx, dy, angle, x, y, z))
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

-- Propellers: two twisted blades 100 studs tip to tip on a hub over each
-- motor's shaft, tilted with the motor. Each blade is lofted through
-- sections that narrow and flatten their pitch towards the tip. The last
-- stretch of each blade is painted hazard yellow.
local PROP_RADIUS, PROP_HUB = 50, 3
local PROP_TIP = 6
local PROP_SECTIONS = 16
local PROP_TEXTURE = 512
local function bladeChord(s: number): number
	local t = (s - PROP_HUB) / (PROP_RADIUS - PROP_HUB)
	return if t < 0.3 then lerp(4.5, 7, t / 0.3) else lerp(7, 3, (t - 0.3) / 0.7)
end
local function bladePitch(s: number): number
	return math.rad(lerp(24, 8, (s - PROP_HUB) / (PROP_RADIUS - PROP_HUB)))
end
-- One blade from `from` to `to` studs out, pointing at `heading`, around
-- the hub at (hx, hy, hz).
local function blade(mesh, hx: number, hy: number, hz: number, heading: number, from: number, to: number)
	local sx, sy = math.cos(heading), math.sin(heading)
	local cx, cy = -sy, sx
	local sections = {}
	local count = math.max(2, math.round(PROP_SECTIONS * (to - from) / (PROP_RADIUS - PROP_HUB)))
	for j = 0, count do
		local span = lerp(from, to, j / count)
		local chord, pitch = bladeChord(span), bladePitch(span)
		local thick = lerp(1.1, 0.4, (span - PROP_HUB) / (PROP_RADIUS - PROP_HUB))
		-- A thin wing section, leading edge first, round under then over.
		local profile = {
			{ -chord / 2, 0 },
			{ -chord / 4, -thick * 0.35 },
			{ chord / 4, -thick * 0.25 },
			{ chord / 2, 0 },
			{ chord / 4, thick * 0.35 },
			{ -chord / 4, thick * 0.5 },
		}
		local ring = {}
		for k, point in profile do
			local y = point[1] * math.cos(pitch) - point[2] * math.sin(pitch)
			local z = point[1] * math.sin(pitch) + point[2] * math.cos(pitch)
			ring[k] = mesh:vertex(hx + sx * span + cx * y, hy + sy * span + cy * y, hz + z)
		end
		sections[j] = ring
	end
	for j = 0, count - 1 do
		local a, b = sections[j], sections[j + 1]
		for k = 1, 6 do
			local l = k % 6 + 1
			mesh:face({ a[k], a[l], b[l], b[k] })
		end
	end
	local root = {}
	for k = 6, 1, -1 do
		table.insert(root, sections[0][k])
	end
	mesh:face(root)
	mesh:face(sections[count])
end

-- Blur discs: what a propeller looks like spinning, for the game to show in
-- place of the blades once they're up to speed. A thin see-through disc in
-- the blades' plane, painted with alpha: two faint smears trailing the
-- blades, circular streaks, and a yellow ring where the tips pass. It is
-- painted flat, with no shading or wear.
local DISC_RINGS, DISC_SECTORS = 24, 64
local DISC_TEXTURE = 512
local DISC_SMEAR = 1.1
local DISC_TINT = { 0.2, 0.2, 0.22 }
local function blurDisc(name: string, mx: number, my: number, ux: number, uy: number, hubZ: number, phase: number)
	local mesh = Mesh.new()
	local lean = leaning(mesh, mx - ux * MOTOR_PIVOT, my - uy * MOTOR_PIVOT, MOTOR_PIVOT_Z, ux, uy, MOTOR_TILT)
	local rows = {}
	for j = 0, DISC_RINGS do
		local r = lerp(PROP_HUB, PROP_RADIUS, j / DISC_RINGS)
		rows[j] = {}
		for k = 0, DISC_SECTORS - 1 do
			local a = k / DISC_SECTORS * TAU
			rows[j][k] = lean:vertex(mx + math.cos(a) * r, my + math.sin(a) * r, hubZ)
		end
	end
	for j = 0, DISC_RINGS - 1 do
		for k = 0, DISC_SECTORS - 1 do
			local l = (k + 1) % DISC_SECTORS
			mesh:face({ rows[j][k], rows[j][l], rows[j + 1][l], rows[j + 1][k] })
		end
	end
	mesh:setSmooth(true)
	mesh:unwrap()
	local image = Image.new(DISC_TEXTURE, DISC_TEXTURE, DISC_TINT[1], DISC_TINT[2], DISC_TINT[3])
	-- Back from world space into the disc's own plane (see leaning()).
	local c, s = math.cos(MOTOR_TILT), math.sin(MOTOR_TILT)
	mesh:paint(image, function(x, y, z)
		local wx, wy, wz = x - (mx - ux * MOTOR_PIVOT), y - (my - uy * MOTOR_PIVOT), z - MOTOR_PIVOT_Z
		local out = wx * ux * c + wy * uy * c + wz * s - MOTOR_PIVOT
		local across = -wx * uy + wy * ux
		local r = math.sqrt(out * out + across * across)
		-- Angle measured in the same frame the blades were placed in.
		local angle = math.atan2(ux * across + uy * out, ux * out - uy * across)
		-- Each blade smears back against the spin (anticlockwise from above).
		local smear = 0
		for b = 0, 1 do
			local behind = (phase + b * math.pi - angle) % TAU
			smear = math.max(smear, math.exp(-behind / DISC_SMEAR))
		end
		local span = math.clamp((r - PROP_HUB) / (PROP_RADIUS - PROP_HUB), 0, 1)
		-- Wider blades near the root leave a denser smear there.
		local body = bladeChord(math.clamp(r, PROP_HUB, PROP_RADIUS)) / 7
		local streak = 0.85 + 0.15 * math.sin(r * 2.3) * math.sin(r * 0.37 + 1.1)
		local opacity = (0.08 + 0.32 * smear) * body * streak
		local colour = DISC_TINT
		if r > PROP_RADIUS - PROP_TIP then
			colour = HAZARD_YELLOW
			opacity = 0.3 + 0.35 * smear
		end
		-- Soft at the rim, and clear over the hub.
		opacity *= math.clamp((PROP_RADIUS - r) / 1.2, 0, 1) * math.clamp((r - PROP_HUB) / 1.5, 0, 1)
		local k = streak * (0.9 + 0.2 * span)
		return colour[1] * k, colour[2] * k, colour[3] * k, opacity
	end)
	model.part(name, mesh, image, { preview = true })
end

for i, degrees in ARM_DIRECTIONS do
	local angle = math.rad(degrees)
	local ux, uy = math.cos(angle), math.sin(angle)
	local function at(r: number, side: number, z: number): (number, number, number)
		return ux * r - uy * side, uy * r + ux * side, z
	end
	-- Panel points along the arm, with one at the ring's outer wall where
	-- the arm starts to climb.
	local stations = { ARM_ROOT }
	local r = ARM_ROOT
	while r < ARM_END - 1 do
		local nextR = math.min(r + ARM_PANEL, ARM_END)
		if r < RING_OUTER - 1 and nextR > RING_OUTER - 1 then
			nextR = RING_OUTER - 1
		end
		table.insert(stations, nextR)
		r = nextR
	end
	part(`Arm{i}`, nil, GIRDER, function(mesh)
		local function corners(r: number)
			local w, zt, zb = armShape(r)
			return { { at(r, -w, zt) }, { at(r, w, zt) }, { at(r, w, zb) }, { at(r, -w, zb) } }
		end
		local function beam(p, q, thick)
			strut(mesh, p[1], p[2], p[3], q[1], q[2], q[3], thick)
		end
		for n, station in stations do
			local frame = corners(station)
			-- A square frame at every panel point.
			for k = 1, 4 do
				beam(frame[k], frame[k % 4 + 1], WEB)
			end
			if n < #stations then
				local nextFrame = corners(stations[n + 1])
				for k = 1, 4 do
					beam(frame[k], nextFrame[k], CHORD)
					-- A diagonal on each face, alternating direction.
					local l = k % 4 + 1
					if n % 2 == 0 then
						beam(frame[k], nextFrame[l], WEB)
					else
						beam(frame[l], nextFrame[k], WEB)
					end
				end
			end
		end
	end, nil, paintHazard, ARM_TEXTURE, nil, nil, 1)

	-- The motor: a finned stator in hazard stripes, gripped by its collar,
	-- with a spinning bell on top, leaning in towards the middle.
	local mx, my = ux * MOTOR_OUT, uy * MOTOR_OUT
	local base = MOTOR_BASE
	local px, py, pz = mx - ux * MOTOR_PIVOT, my - uy * MOTOR_PIVOT, MOTOR_PIVOT_Z
	-- The collar: a split steel band round the motor, with a lip at top and
	-- bottom, and two lugs on the outer side drawn together by clamp bolts.
	part(`MotorCollar{i}`, nil, STEEL, function(mesh)
		local lean = leaning(mesh, px, py, pz, ux, uy, MOTOR_TILT)
		ring(lean, mx, my, pz, COLLAR_INNER, COLLAR_OUTER, COLLAR_HEIGHT, "z", 24)
		for _, side in { -1, 1 } do
			ring(lean, mx, my, pz + side * (COLLAR_HEIGHT / 2 - 0.3), COLLAR_OUTER - 0.2, COLLAR_OUTER + 0.35, 0.6, "z", 24)
		end
		local vx, vy = -uy, ux
		for _, side in { -1, 1 } do
			local gap = side * 0.8
			strut(lean, mx + ux * (COLLAR_OUTER - 0.4) + vx * gap, my + uy * (COLLAR_OUTER - 0.4) + vy * gap, pz,
				mx + ux * (COLLAR_OUTER + 3) + vx * gap, my + uy * (COLLAR_OUTER + 3) + vy * gap, pz, 1.2)
		end
		for _, along in { 1.2, 2.4 } do
			local cx, cy = mx + ux * (COLLAR_OUTER + along), my + uy * (COLLAR_OUTER + along)
			for _, height in { -0.9, 0.9 } do
				strut(lean, cx - vx * 1.9, cy - vy * 1.9, pz + height, cx + vx * 1.9, cy + vy * 1.9, pz + height, 0.5)
			end
		end
	end, 30, 0.35, MOTOR_TEXTURE)
	part(`Motor{i}`, nil, DARK_STEEL, function(mesh)
		local lean = leaning(mesh, px, py, pz, ux, uy, MOTOR_TILT)
		cylinder(lean, mx, my, base + 4.75, 5.2, 8.5, "z", 20)
		cylinder(lean, mx, my, base + 0.5, 4.4, 1, "z", 20)
		for f = 0, 2 do
			ring(lean, mx, my, base + 5.6 + f * 1.2, 5.1, 6, 0.45, "z", 20)
		end
	end, 30, paintHazard, MOTOR_TEXTURE)
	part(`MotorTrim{i}`, nil, STEEL, function(mesh)
		local lean = leaning(mesh, px, py, pz, ux, uy, MOTOR_TILT)
		-- The bell, with the shaft the propeller will sit on.
		cylinder(lean, mx, my, base + 9.9, 6, 1.8, "z", 20)
		cylinder(lean, mx, my, base + 11.3, 1.2, 1.4, "z", 12)
	end, 30, 0.3, MOTOR_TEXTURE)

	local hubZ = base + 12.8
	-- Each propeller stopped at its own angle, so the four don't match.
	local phase = math.rad(degrees + 30 * i)
	part(`Prop{i}`, nil, DARK_STEEL, function(mesh)
		local lean = leaning(mesh, px, py, pz, ux, uy, MOTOR_TILT)
		for b = 0, 1 do
			blade(lean, mx, my, hubZ, phase + b * math.pi, PROP_HUB, PROP_RADIUS - PROP_TIP)
		end
	end, 30, 0.35, PROP_TEXTURE)
	part(`PropTips{i}`, nil, HAZARD_YELLOW, function(mesh)
		local lean = leaning(mesh, px, py, pz, ux, uy, MOTOR_TILT)
		for b = 0, 1 do
			blade(lean, mx, my, hubZ, phase + b * math.pi, PROP_RADIUS - PROP_TIP, PROP_RADIUS)
		end
	end, 30, 0.35, 128)
	blurDisc(`PropDisc{i}`, mx, my, ux, uy, hubZ, phase)
	part(`PropHub{i}`, nil, STEEL, function(mesh)
		local lean = leaning(mesh, px, py, pz, ux, uy, MOTOR_TILT)
		cylinder(lean, mx, my, hubZ, PROP_HUB + 0.6, 2.4, "z", 16)
		cylinder(lean, mx, my, hubZ + 1.6, 1.6, 0.8, "z", 12)
		for b = 0, 3 do
			local a = phase + b * TAU / 4 + TAU / 8
			bolt(lean, mx + math.cos(a) * 2.4, my + math.sin(a) * 2.4, hubZ + 1.2, "z", 0.3)
		end
	end, 30, 0.3, 128)

	-- Power cable along the underside of the arm, out to the motor.
	part(`Cable{i}`, nil, RUBBER_BLACK, function(mesh)
		local points = {}
		for _, station in stations do
			local _, _, zb = armShape(station)
			table.insert(points, { at(station, 0, zb - 0.9) })
		end
		local last = points[#points]
		-- Up into the middle of the motor's underside.
		table.insert(points, { tipped(px, py, pz, ux, uy, MOTOR_TILT, mx - ux * 1.5, my - uy * 1.5, base + 0.2) })
		tube(mesh, points, 0.45, 8)
	end, true, RUBBER, 256)
end

-- The battery pack, slung under the middle of the deck: a row of cell
-- modules in an olive casing, held in a girder cradle that hangs from the
-- joists, with copper terminals on top feeding a heavy cable out to each
-- arm.
local BATTERY_OLIVE = { 0.33, 0.36, 0.25 }
local BATTERY_TOP, BATTERY_BOTTOM = -14.5, -28
local BATTERY_HALF_X, BATTERY_HALF_Y = 28, 20
local BATTERY_CELLS = 6
local CELL_GAP = 0.5
local CRADLE_GAP = 1.2
local JOIST_BOTTOM = -PLATE_THICK - 1.6 - BOWL_DEPTH
part("Battery", nil, BATTERY_OLIVE, function(mesh)
	local cell = (2 * BATTERY_HALF_X - (BATTERY_CELLS - 1) * CELL_GAP) / BATTERY_CELLS
	for c = 0, BATTERY_CELLS - 1 do
		local x = -BATTERY_HALF_X + cell / 2 + c * (cell + CELL_GAP)
		box(mesh, x, 0, BATTERY_BOTTOM, cell, 2 * BATTERY_HALF_Y, BATTERY_TOP - BATTERY_BOTTOM)
		-- A raised lid on each module.
		box(mesh, x, 0, BATTERY_TOP, cell - 1, 2 * BATTERY_HALF_Y - 2, 0.6)
	end
	-- The spine the modules are bolted to, running underneath.
	box(mesh, 0, 0, BATTERY_BOTTOM - 0.8, 2 * BATTERY_HALF_X + 1, 6, 0.8)
end, nil, 0.45, 512, nil, nil, 1.2)
part("BatteryWarning", nil, HAZARD_YELLOW, function(mesh)
	-- A warning plate on each long side.
	for _, side in { -1, 1 } do
		box(mesh, 0, side * (BATTERY_HALF_Y + 0.1), BATTERY_BOTTOM + 4, 20, 0.3, 5.5)
	end
end, nil, 0.35, 128)
part("BatteryStraps", nil, RUBBER_BLACK, function(mesh)
	for _, x in { -18, 0, 18 } do
		local h = BATTERY_HALF_Y + CRADLE_GAP * 0.5
		box(mesh, x, 0, BATTERY_TOP + 0.6, 2, 2 * h, 0.3)
		box(mesh, x, 0, BATTERY_BOTTOM - 1.1, 2, 2 * h, 0.3)
		for _, side in { -1, 1 } do
			box(mesh, x, side * h, BATTERY_BOTTOM - 1.1, 2, 0.3, BATTERY_TOP - BATTERY_BOTTOM + 2)
		end
	end
end, nil, RUBBER, 256)
part("Terminals", nil, COPPER, function(mesh)
	for i, degrees in ARM_DIRECTIONS do
		local angle = math.rad(degrees)
		local tx, ty = math.cos(angle) * 13 * math.sqrt(2), math.sin(angle) * 10 * math.sqrt(2)
		cylinder(mesh, tx, ty, BATTERY_TOP + 1.4, 1.4, 1.6, "z", 10)
		cylinder(mesh, tx, ty, BATTERY_TOP + 2.4, 0.9, 0.8, "z", 8)
	end
end, nil, 0.5, 128)
part("Cradle", nil, GIRDER, function(mesh)
	local hx, hy = BATTERY_HALF_X + CRADLE_GAP, BATTERY_HALF_Y + CRADLE_GAP
	local low, high = BATTERY_BOTTOM - 1.6, BATTERY_TOP - 1
	local corners = { { -hx, -hy }, { hx, -hy }, { hx, hy }, { -hx, hy } }
	for k, c in corners do
		local n = corners[k % 4 + 1]
		-- A frame round the bottom and one round the top, joined at the corners.
		strut(mesh, c[1], c[2], low, n[1], n[2], low, CHORD)
		strut(mesh, c[1], c[2], high, n[1], n[2], high, WEB)
		strut(mesh, c[1], c[2], low, c[1], c[2], high, CHORD)
	end
	-- Cross members under the pack.
	for _, x in { -18, 0, 18 } do
		strut(mesh, x, -hy, low, x, hy, low, WEB)
	end
	-- Hangers from the top corners up to the joists, splayed so they meet
	-- the joists running out to the octagon's corners.
	for k, c in corners do
		local jx, jy = corner(40, ({ 4, 7, 0, 3 })[k])
		strut(mesh, c[1], c[2], high, jx, jy, JOIST_BOTTOM, CHORD)
	end
end, nil, paintHazard, GIRDER_TEXTURE, nil, nil, 1)
part("MainCables", nil, RUBBER_BLACK, function(mesh)
	for _, degrees in ARM_DIRECTIONS do
		local angle = math.rad(degrees)
		local ux, uy = math.cos(angle), math.sin(angle)
		local tx, ty = ux * 13 * math.sqrt(2), uy * 10 * math.sqrt(2)
		local _, _, zb = armShape(ARM_ROOT)
		tube(mesh, {
			{ tx, ty, BATTERY_TOP + 2.8 },
			{ tx * 1.3, ty * 1.3, BATTERY_TOP + 4.5 },
			{ ux * 40, uy * 40, JOIST_BOTTOM - 1.5 },
			{ ux * (ARM_ROOT - 2), uy * (ARM_ROOT - 2), zb - 0.9 },
		}, 0.7, 8)
	end
end, true, RUBBER, 256)

-- Landing skids: a steel rail under the north and south sides of the ring,
-- each on two legs that splay out from the ring girder's bottom chord,
-- low enough to clear the battery cradle. The rails turn up at both ends.
local SKID_Z = BATTERY_BOTTOM - 6
local SKID_Y = RING_INNER + 9
local SKID_HALF = 72
local SKID_LEGS = { -42, 42 }
local LEG_THICK = 1.8
local CHORD_BOTTOM = GIRDER_BOTTOM + CHORD / 2
part("SkidLegs", nil, GIRDER, function(mesh)
	for _, side in { -1, 1 } do
		for _, x in SKID_LEGS do
			strut(mesh, x, side * (RING_INNER + 1), CHORD_BOTTOM, x, side * SKID_Y, SKID_Z + 1, LEG_THICK)
			-- A brace from the outer wall down to the leg's middle.
			local midY, midZ = lerp(RING_INNER + 1, SKID_Y, 0.5), lerp(CHORD_BOTTOM, SKID_Z + 1, 0.5)
			strut(mesh, x - math.sign(x) * 10, side * (RING_OUTER - 1), CHORD_BOTTOM, x, side * midY, midZ, WEB)
		end
		-- A tie between the two legs, so each skid stands as one frame.
		local tieY, tieZ = lerp(RING_INNER + 1, SKID_Y, 0.7), lerp(CHORD_BOTTOM, SKID_Z + 1, 0.7)
		strut(mesh, SKID_LEGS[1], side * tieY, tieZ, SKID_LEGS[2], side * tieY, tieZ, WEB)
	end
end, nil, paintHazard, GIRDER_TEXTURE, nil, nil, 1)
part("Skids", nil, DARK_STEEL, function(mesh)
	for _, side in { -1, 1 } do
		local points = {}
		for j = 0, 4 do
			local a = j / 4 * math.pi / 2
			table.insert(points, 1, { -SKID_HALF - math.sin(a) * 6, side * SKID_Y, SKID_Z + (1 - math.cos(a)) * 6 })
		end
		for j = 1, 4 do
			local a = j / 4 * math.pi / 2
			table.insert(points, { SKID_HALF + math.sin(a) * 6, side * SKID_Y, SKID_Z + (1 - math.cos(a)) * 6 })
		end
		tube(mesh, points, 1.3, 12)
		-- Clamps where the legs meet the rail.
		for _, x in SKID_LEGS do
			cylinder(mesh, x, side * SKID_Y, SKID_Z, 1.7, 3, "x", 12)
		end
	end
end, 40, 0.5, 256)

finishParts()
