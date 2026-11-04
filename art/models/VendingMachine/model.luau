local CACHE_KEY = "VendingMachine-a30b7bd1b18cccda"
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
-- Vending Machine: a gutted drinks and snacks machine, its window smashed
-- out to a fringe of jagged glass, most of its spiral shelves emptied, and
-- cans, coins and glass spilled on the ground in front. A hollow steel
-- cabinet on levelling feet, a framed front door hinged on the left with a
-- lit header sign, and a control column on the right: display, keypad, coin
-- and note slots, coin return and a T-handle lock. The front faces -y.
-- Centered on the origin.
local CASE = { 0.18, 0.3, 0.55 }
local SIGN_RED = { 0.72, 0.12, 0.1 }
local CREAM = { 0.9, 0.87, 0.78 }
local INTERIOR = { 0.1, 0.1, 0.11 }
local GLASS = { 0.55, 0.7, 0.75 }
local CAN_RED = { 0.62, 0.16, 0.12 }
local CAN_GREEN = { 0.2, 0.45, 0.22 }
local BAG_YELLOW = { 0.85, 0.65, 0.15 }
local BAG_PURPLE = { 0.4, 0.2, 0.5 }
local SCREEN = { 0.06, 0.12, 0.08 }
local NOTE_GREEN = { 0.15, 0.5, 0.25 }
local BRASS = { 0.72, 0.58, 0.28 }

-- Cabinet: x -0.7..0.7, y -0.5..0.5, standing on its plinth at z = 0.14
-- and topping out at z = 2.8.
local HX, HY = 0.7, 0.5
local BASE, TOP = 0.14, 2.8
local SKIN = 0.04
-- The front door, its face at y = -0.5, with the window cut out of it and
-- the control column to the window's right.
local DOOR = 0.06
local FRONT = -HY
local WIN_X0, WIN_X1, WIN_Z0, WIN_Z1 = -0.62, 0.26, 0.62, 2.38
local COLUMN_X0 = 0.34
-- The glass sat in the window just behind the door face.
local GLASS_Y = FRONT + 0.03
-- The delivery bin's opening in the door's bottom rail.
local BIN_X0, BIN_X1, BIN_Z0, BIN_Z1 = -0.55, 0.15, 0.25, 0.5

-- Builds into a mesh whose z axis points along (nx, ny, nz) from (cx, cy, cz),
-- so round and boxed pieces made about "z" at the origin face that way.
local function facing(mesh, cx: number, cy: number, cz: number, nx: number, ny: number, nz: number)
	local tx, ty, tz, ux, uy, uz, vx, vy, vz = crossFrame(nx, ny, nz)
	return setmetatable({
		vertex = function(_, x, y, z)
			return mesh:vertex(cx + ux * x + vx * y + tx * z, cy + uy * x + vy * y + ty * z, cz + uz * x + vz * y + tz * z)
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

-- A flat shard of glass lying on the ground: an outline anticlockwise seen
-- from above, `thick` tall.
local function lyingShard(mesh, outline, thick: number)
	local low, high = {}, {}
	for i, p in outline do
		low[i] = mesh:vertex(p[1], p[2], 0.002)
		high[i] = mesh:vertex(p[1], p[2], 0.002 + thick)
	end
	local n = #outline
	for i = 1, n do
		local j = i % n + 1
		mesh:face({ low[i], low[j], high[j], high[i] })
	end
	local under = {}
	for i = n, 1, -1 do
		table.insert(under, low[i])
	end
	mesh:face(under)
	mesh:face(high)
end

-- A drinks can standing at (x, y, z): its body, a tapered shoulder, and the
-- rolled rims top and bottom, with the ring pull on top.
local function standingCan(mesh, x: number, y: number, z: number)
	cylinder(mesh, x, y, z + 0.1, 0.055, 0.17, "z", 16)
	cylinder(mesh, x, y, z + 0.19, 0.048, 0.02, "z", 16)
	ring(mesh, x, y, z + 0.2, 0.038, 0.046, 0.008, "z", 16)
	cylinder(mesh, x, y, z + 0.01, 0.048, 0.02, "z", 16)
	box(mesh, x + 0.012, y, z + 0.2, 0.03, 0.016, 0.004)
end

part("Cabinet", nil, CASE, function(mesh)
	-- Sides, back, top and bottom: sheet steel round a hollow box.
	for _, side in { -1, 1 } do
		box(mesh, side * (HX - SKIN / 2), 0, BASE, SKIN, 2 * HY - DOOR, TOP - BASE)
		-- A rolled lip down the front edge of each side, where the door shuts.
		box(mesh, side * (HX - 0.015), FRONT + DOOR + 0.01, BASE, 0.05, 0.02, TOP - BASE)
	end
	box(mesh, 0, HY - SKIN / 2, BASE, 2 * HX - 2 * SKIN, SKIN, TOP - BASE)
	box(mesh, 0, DOOR / 2, TOP - SKIN, 2 * HX, 2 * HY - DOOR, SKIN)
	box(mesh, 0, DOOR / 2, BASE, 2 * HX - 2 * SKIN, 2 * HY - DOOR, SKIN)
	-- A raised drip edge round the top.
	for _, side in { -1, 1 } do
		box(mesh, side * (HX - 0.01), DOOR / 2, TOP, 0.02, 2 * HY - DOOR, 0.025)
	end
	box(mesh, 0, HY - 0.01, TOP, 2 * HX, 0.02, 0.025)
	-- Pressed stiffening ribs up each side and across the back.
	for _, side in { -1, 1 } do
		for _, y in { -0.15, 0.15 } do
			box(mesh, side * (HX + 0.006), y, BASE + 0.15, 0.012, 0.05, TOP - BASE - 0.3)
		end
	end
	for _, x in { -0.35, 0, 0.35 } do
		box(mesh, x, HY + 0.006, BASE + 0.15, 0.05, 0.012, TOP - BASE - 0.3)
	end
end, nil, 0.6, nil, nil, true)

part("Plinth", nil, DARK_STEEL, function(mesh)
	-- A kick plinth set back under the cabinet, and four levelling feet: a
	-- round pad, a threaded stem and a hex nut each.
	box(mesh, 0, 0.03, 0.05, 2 * HX - 0.12, 2 * HY - 0.14, BASE - 0.05)
	for _, x in { -0.6, 0.6 } do
		for _, y in { -0.38, 0.4 } do
			cylinder(mesh, x, y, 0.012, 0.06, 0.024, "z", 16)
			cylinder(mesh, x, y, 0.06, 0.018, 0.08, "z", 10)
			cylinder(mesh, x, y, 0.09, 0.04, 0.03, "z", 6)
		end
	end
	-- Vent louvres low on each side near the back: slats angled down to
	-- shed water, in a pressed frame.
	for _, side in { -1, 1 } do
		local x = side * (HX + 0.012)
		box(mesh, x, 0.22, 0.28, 0.02, 0.4, 0.02)
		box(mesh, x, 0.22, 0.7, 0.02, 0.4, 0.02)
		box(mesh, x, 0.03, 0.28, 0.02, 0.02, 0.44)
		box(mesh, x, 0.41, 0.28, 0.02, 0.02, 0.44)
		for k = 0, 7 do
			local z = 0.33 + k * 0.048
			strut(mesh, x + side * 0.01, 0.05, z + 0.02, x + side * 0.01, 0.39, z + 0.02, 0.012)
			strut(mesh, x + side * 0.02, 0.05, z, x + side * 0.02, 0.39, z, 0.01)
		end
	end
	-- Door hinges down the left edge: knuckles round a pin.
	for _, z in { 0.45, 1.45, 2.45 } do
		cylinder(mesh, -HX - 0.015, FRONT + 0.02, z, 0.025, 0.2, "z", 12)
		cylinder(mesh, -HX - 0.015, FRONT + 0.02, z + 0.11, 0.012, 0.02, "z", 8)
		box(mesh, -HX + 0.01, FRONT + 0.02, z - 0.08, 0.04, 0.012, 0.16)
	end
end, nil, 0.5, nil, nil, true)

part("Door", nil, CASE, function(mesh)
	local y = FRONT + DOOR / 2
	local function slab(x0: number, x1: number, z0: number, z1: number)
		box(mesh, (x0 + x1) / 2, y, z0, x1 - x0, DOOR, z1 - z0)
	end
	-- The frame round the window, the stile between window and column, the
	-- control column, the bottom rail round the bin opening and the header.
	slab(-HX, WIN_X0, BASE, TOP)
	slab(WIN_X1, HX, BASE, BIN_Z0)
	slab(WIN_X1, COLUMN_X0, BIN_Z0, TOP)
	slab(COLUMN_X0, HX, BIN_Z0, TOP)
	slab(WIN_X0, WIN_X1, BASE, BIN_Z0)
	slab(WIN_X0, BIN_X0, BIN_Z0, WIN_Z0)
	slab(BIN_X1, WIN_X1, BIN_Z0, WIN_Z0)
	slab(BIN_X0, BIN_X1, BIN_Z1, WIN_Z0)
	slab(WIN_X0, WIN_X1, WIN_Z1, TOP)
	-- A raised moulding round the window, mitred at the corners.
	local m, d = 0.035, 0.02
	box(mesh, (WIN_X0 + WIN_X1) / 2, FRONT - d / 2, WIN_Z0 - m, WIN_X1 - WIN_X0 + 2 * m, d, m)
	box(mesh, (WIN_X0 + WIN_X1) / 2, FRONT - d / 2, WIN_Z1, WIN_X1 - WIN_X0 + 2 * m, d, m)
	box(mesh, WIN_X0 - m / 2, FRONT - d / 2, WIN_Z0, m, d, WIN_Z1 - WIN_Z0)
	box(mesh, WIN_X1 + m / 2, FRONT - d / 2, WIN_Z0, m, d, WIN_Z1 - WIN_Z0)
	-- A raised panel on the control column, and a kick panel on the rail.
	box(mesh, (COLUMN_X0 + HX) / 2 + 0.005, FRONT - 0.008, 0.6, HX - COLUMN_X0 - 0.07, 0.016, 1.74)
	box(mesh, (WIN_X0 + WIN_X1) / 2, FRONT - 0.008, BASE + 0.02, WIN_X1 - WIN_X0 - 0.04, 0.016, BIN_Z0 - BASE - 0.05)
	-- The header sign's frame.
	box(mesh, 0, FRONT - 0.015, 2.42, 1.3, 0.03, 0.03)
	box(mesh, 0, FRONT - 0.015, 2.74, 1.3, 0.03, 0.03)
	box(mesh, -0.635, FRONT - 0.015, 2.42, 0.03, 0.03, 0.35)
	box(mesh, 0.635, FRONT - 0.015, 2.42, 0.03, 0.03, 0.35)
	-- A dent in the door's bottom rail, kicked in: a pressed hollow ringed
	-- by a raised crease.
	ring(mesh, -0.3, FRONT - 0.004, 0.19, 0.035, 0.05, 0.008, "y", 16)
end, nil, 0.6, nil, nil, true)

part("Gasket", nil, RUBBER_BLACK, function(mesh)
	-- Rubber seal round the inside of the window, where the glass sat.
	local g = 0.015
	box(mesh, (WIN_X0 + WIN_X1) / 2, GLASS_Y, WIN_Z0, WIN_X1 - WIN_X0, 0.03, g)
	box(mesh, (WIN_X0 + WIN_X1) / 2, GLASS_Y, WIN_Z1 - g, WIN_X1 - WIN_X0, 0.03, g)
	box(mesh, WIN_X0 + g / 2, GLASS_Y, WIN_Z0, g, 0.03, WIN_Z1 - WIN_Z0)
	box(mesh, WIN_X1 - g / 2, GLASS_Y, WIN_Z0, g, 0.03, WIN_Z1 - WIN_Z0)
	-- Rubber flap edge on the delivery bin opening.
	box(mesh, (BIN_X0 + BIN_X1) / 2, FRONT + 0.005, BIN_Z0 - 0.01, BIN_X1 - BIN_X0, 0.012, 0.012)
end, nil, 0.2, nil, nil, true)

part("SignPanel", nil, SIGN_RED, function(mesh)
	-- The header sign's backing, set into its frame.
	box(mesh, 0, FRONT - 0.006, 2.45, 1.24, 0.008, 0.29)
end, nil, 0.4, nil, nil, true)

-- "SODA" in raised block letters across the header, from a 5 by 7 grid.
local LETTERS = {
	{ ".###.", "#...#", "#....", ".###.", "....#", "#...#", ".###." },
	{ ".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###." },
	{ "####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####." },
	{ ".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#" },
}
local PIXEL = 0.028
local LETTER_GAP = 0.05
part("Lettering", nil, CREAM, function(mesh)
	local width = #LETTERS * 5 * PIXEL + (#LETTERS - 1) * LETTER_GAP
	local left = -width / 2
	local top = 2.595 + 3.5 * PIXEL
	for l, rows in LETTERS do
		local x0 = left + (l - 1) * (5 * PIXEL + LETTER_GAP)
		for r, row in rows do
			for c = 1, 5 do
				if row:sub(c, c) == "#" then
					box(mesh, x0 + (c - 0.5) * PIXEL, FRONT - 0.016, top - r * PIXEL, PIXEL * 0.92, 0.014, PIXEL * 0.92)
				end
			end
		end
	end
end, nil, 0.3, nil, nil, true)

part("Interior", nil, INTERIOR, function(mesh)
	-- The dark inside: a back wall and side liners behind the window.
	box(mesh, (WIN_X0 + COLUMN_X0) / 2, 0.42, BASE + SKIN, COLUMN_X0 - WIN_X0 + 0.1, 0.02, TOP - BASE - 2 * SKIN)
	box(mesh, WIN_X0 - 0.02, 0, BASE + SKIN, 0.02, 0.84, TOP - BASE - 2 * SKIN)
	box(mesh, COLUMN_X0 + 0.02, 0, BASE + SKIN, 0.02, 0.84, TOP - BASE - 2 * SKIN)
	-- The delivery bin: a sloped chute down to a tray behind the opening.
	box(mesh, (BIN_X0 + BIN_X1) / 2, -0.25, BIN_Z0 - 0.04, BIN_X1 - BIN_X0, 0.42, 0.02)
	local chute = facing(mesh, (BIN_X0 + BIN_X1) / 2, -0.05, 0.55, 0, 0.6, 0.8)
	box(chute, 0, 0, -0.01, BIN_X1 - BIN_X0, 0.45, 0.02)
end, nil, 0.3, nil, nil, true)

-- Shelves: five trays behind the window, each with a price strip along its
-- front edge, four wire spirals that push the stock forward, and the
-- motors that turn them at the back.
local SHELF_ZS = { 0.72, 1.05, 1.38, 1.71, 2.04 }
local SPIRAL_XS = { -0.5, -0.29, -0.08, 0.13 }
local SPIRAL_RADIUS = 0.07
local SPIRAL_TURNS = 7
part("Shelves", nil, STEEL, function(mesh)
	for _, z in SHELF_ZS do
		box(mesh, (WIN_X0 + WIN_X1) / 2, 0, z, WIN_X1 - WIN_X0, 0.8, 0.012)
		-- Dividers between the spiral lanes.
		for k = 1, #SPIRAL_XS - 1 do
			local x = (SPIRAL_XS[k] + SPIRAL_XS[k + 1]) / 2
			box(mesh, x, 0, z + 0.012, 0.008, 0.76, 0.15)
		end
	end
end, nil, 0.3, nil, nil, true)

part("Spirals", nil, BARE_METAL, function(mesh)
	for _, z in SHELF_ZS do
		for _, x in SPIRAL_XS do
			local points = {}
			local steps = SPIRAL_TURNS * 12
			for i = 0, steps do
				local a = i / 12 * TAU
				table.insert(points, { x + math.cos(a) * SPIRAL_RADIUS, -0.38 + 0.74 * i / steps, z + 0.085 + math.sin(a) * SPIRAL_RADIUS })
			end
			tube(mesh, points, 0.008, 5)
		end
	end
end, nil, 0.25, nil, nil, true)

part("Motors", nil, DARK_STEEL, function(mesh)
	for _, z in SHELF_ZS do
		for _, x in SPIRAL_XS do
			box(mesh, x, 0.37, z + 0.03, 0.09, 0.05, 0.11)
			cylinder(mesh, x, 0.34, z + 0.085, 0.02, 0.02, "y", 10)
		end
	end
end, nil, 0.4, nil, nil, true)

part("PriceStrips", nil, CREAM, function(mesh)
	for _, z in SHELF_ZS do
		box(mesh, (WIN_X0 + WIN_X1) / 2, -0.405, z - 0.035, WIN_X1 - WIN_X0, 0.01, 0.045)
		-- A raised label tab under each lane.
		for _, x in SPIRAL_XS do
			box(mesh, x, -0.412, z - 0.028, 0.08, 0.006, 0.03)
		end
	end
end, nil, 0.2, nil, nil, true)

-- What's left of the stock: a few cans standing in the spirals and a few
-- snack bags hanging in them, one knocked crooked.
part("Cans", nil, CAN_RED, function(mesh)
	standingCan(mesh, SPIRAL_XS[1], -0.25, SHELF_ZS[1] + 0.012)
	standingCan(mesh, SPIRAL_XS[1], -0.11, SHELF_ZS[1] + 0.012)
	standingCan(mesh, SPIRAL_XS[3], -0.32, SHELF_ZS[2] + 0.012)
	standingCan(mesh, SPIRAL_XS[4], 0.1, SHELF_ZS[5] + 0.012)
end, nil, 0.4)

part("CansGreen", nil, CAN_GREEN, function(mesh)
	standingCan(mesh, SPIRAL_XS[2], -0.18, SHELF_ZS[1] + 0.012)
	standingCan(mesh, SPIRAL_XS[2], 0.2, SHELF_ZS[4] + 0.012)
end, nil, 0.4)

-- A snack bag: a pillow of foil with crimped seals top and bottom, standing
-- in a spiral, leaning `lean` sideways.
local function snackBag(mesh, x: number, y: number, z: number, lean: number)
	local bag = facing(mesh, x, y, z, math.sin(lean), 0, math.cos(lean))
	box(bag, 0, 0, 0.02, 0.15, 0.035, 0.2)
	box(bag, 0, 0, 0.005, 0.15, 0.014, 0.018)
	box(bag, 0, 0, 0.217, 0.15, 0.014, 0.018)
	box(bag, 0, 0, 0.06, 0.13, 0.045, 0.12)
end
part("Snacks", nil, BAG_YELLOW, function(mesh)
	snackBag(mesh, SPIRAL_XS[4], -0.3, SHELF_ZS[2] + 0.015, 0)
	snackBag(mesh, SPIRAL_XS[1], -0.28, SHELF_ZS[4] + 0.015, 0)
	snackBag(mesh, SPIRAL_XS[3], -0.2, SHELF_ZS[4] + 0.015, math.rad(18))
end, nil, 0.3)

part("SnacksPurple", nil, BAG_PURPLE, function(mesh)
	snackBag(mesh, SPIRAL_XS[2], -0.31, SHELF_ZS[3] + 0.015, 0)
	snackBag(mesh, SPIRAL_XS[2], -0.1, SHELF_ZS[3] + 0.015, 0)
end, nil, 0.3)

-- The control column: a display, a keypad, a coin slot with its reject
-- button, a note acceptor, the coin return cup and the door lock. Each
-- fitting is a plate on the column's raised panel; everything on a plate is
-- placed from the plate's own middle and face, and its screws sit in its
-- corners, so it all lines up.
local COLUMN_X = (COLUMN_X0 + HX) / 2
local PANEL_FACE = FRONT - 0.016
local PLATES = {
	display = { z0 = 2.08, z1 = 2.28, half = 0.13, thick = 0.024 },
	keypad = { z0 = 1.6, z1 = 2.0, half = 0.13, thick = 0.016 },
	coin = { z0 = 1.42, z1 = 1.56, half = 0.13, thick = 0.02 },
	note = { z0 = 1.13, z1 = 1.33, half = 0.13, thick = 0.04 },
	change = { z0 = 0.72, z1 = 0.92, half = 0.11, thick = 0.02 },
}
-- A plate's middle height and the y of its face.
local function plateAt(name: string): (number, number)
	local plate = PLATES[name]
	return (plate.z0 + plate.z1) / 2, PANEL_FACE - plate.thick
end
-- The keypad: three columns by four rows, centred on its plate.
local KEY_PITCH_X, KEY_PITCH_Z = 0.075, 0.085
local function keyAt(row: number, col: number): (number, number)
	local middle = plateAt("keypad")
	return COLUMN_X + col * KEY_PITCH_X, middle + (1.5 - row) * KEY_PITCH_Z
end
local COIN_SLOT_X, REJECT_X = COLUMN_X - 0.03, COLUMN_X + 0.07
-- The lock sits centred on the column between the note acceptor and the
-- coin return.
local LOCK_Z = (PLATES.change.z1 + PLATES.note.z0) / 2

part("Controls", nil, DARK_STEEL, function(mesh)
	for _, plate in PLATES do
		box(mesh, COLUMN_X, PANEL_FACE - plate.thick / 2, plate.z0, 2 * plate.half, plate.thick, plate.z1 - plate.z0)
		-- A security screw in each corner.
		for _, z in { plate.z0 + 0.02, plate.z1 - 0.02 } do
			for _, side in { -1, 1 } do
				cylinder(mesh, COLUMN_X + side * (plate.half - 0.02), PANEL_FACE - plate.thick - 0.004, z, 0.009, 0.008, "y", 8)
			end
		end
	end
	-- Each key's skirt.
	local _, keyFace = plateAt("keypad")
	for row = 0, 3 do
		for col = -1, 1 do
			local x, z = keyAt(row, col)
			box(mesh, x, keyFace - 0.008, z - 0.03, 0.06, 0.016, 0.06)
		end
	end
	-- The coin slot's raised lips either side of it, and the reject
	-- button's collar.
	local coinZ, coinFace = plateAt("coin")
	for _, side in { -1, 1 } do
		box(mesh, COIN_SLOT_X + side * 0.018, coinFace - 0.006, coinZ - 0.04, 0.012, 0.012, 0.08)
	end
	ring(mesh, REJECT_X, coinFace - 0.006, coinZ, 0.022, 0.032, 0.012, "y", 16)
	-- The note acceptor's mouth: a lip sloping out over the slot.
	local noteZ, noteFace = plateAt("note")
	local mouth = facing(mesh, COLUMN_X, noteFace - 0.02, noteZ + 0.035, 0, -0.5, 0.87)
	box(mouth, 0, 0, -0.008, 0.2, 0.05, 0.016)
	-- The coin return's flap, hinged at the top of its cup and swung out.
	local changeZ, changeFace = plateAt("change")
	local flap = facing(mesh, COLUMN_X, changeFace - 0.03, changeZ + 0.005, 0, -0.5, -0.87)
	box(flap, 0, 0, -0.006, 0.13, 0.07, 0.012)
	-- The T-handle lock: its escutcheon, barrel and handle.
	cylinder(mesh, COLUMN_X, PANEL_FACE - 0.008, LOCK_Z, 0.04, 0.016, "y", 16)
	cylinder(mesh, COLUMN_X, PANEL_FACE - 0.041, LOCK_Z, 0.022, 0.05, "y", 16)
	box(mesh, COLUMN_X, PANEL_FACE - 0.07, LOCK_Z - 0.045, 0.03, 0.02, 0.09)
end, nil, 0.45, nil, nil, true)

part("Keys", nil, CREAM, function(mesh)
	local _, keyFace = plateAt("keypad")
	for row = 0, 3 do
		for col = -1, 1 do
			local x, z = keyAt(row, col)
			box(mesh, x, keyFace - 0.022, z - 0.024, 0.048, 0.012, 0.048)
		end
	end
	local coinZ, coinFace = plateAt("coin")
	cylinder(mesh, REJECT_X, coinFace - 0.01, coinZ, 0.02, 0.02, "y", 16)
end, nil, 0.2, nil, nil, true)

part("Screen", nil, SCREEN, function(mesh)
	local z, face = plateAt("display")
	box(mesh, COLUMN_X, face - 0.002, z - 0.07, 0.22, 0.004, 0.14)
end, nil, 0.1, nil, nil, true)

part("Slots", nil, INTERIOR, function(mesh)
	-- The coin slot between its lips, the note slot under its mouth, and the
	-- coin return cup's hollow.
	local coinZ, coinFace = plateAt("coin")
	box(mesh, COIN_SLOT_X, coinFace - 0.002, coinZ - 0.035, 0.016, 0.004, 0.07)
	local noteZ, noteFace = plateAt("note")
	box(mesh, COLUMN_X, noteFace - 0.002, noteZ - 0.007, 0.16, 0.004, 0.014)
	local changeZ, changeFace = plateAt("change")
	box(mesh, COLUMN_X, changeFace - 0.002, changeZ - 0.07, 0.14, 0.004, 0.08)
end, nil, 0.1, nil, nil, true)

part("NoteBezel", nil, NOTE_GREEN, function(mesh)
	-- A green guide strip under the note slot.
	local noteZ, noteFace = plateAt("note")
	box(mesh, COLUMN_X, noteFace - 0.002, noteZ - 0.045, 0.2, 0.004, 0.02)
end, nil, 0.3, nil, nil, true)

part("Lock", nil, BRASS, function(mesh)
	-- The key face on the barrel's end, with its keyway.
	cylinder(mesh, COLUMN_X, PANEL_FACE - 0.07, LOCK_Z, 0.014, 0.008, "y", 12)
	box(mesh, COLUMN_X, PANEL_FACE - 0.075, LOCK_Z - 0.006, 0.004, 0.004, 0.012)
end, nil, 0.4, nil, nil, true)

-- The delivery bin's push flap, hinged along its top edge and swung in.
part("BinFlap", nil, DARK_STEEL, function(mesh)
	local height = BIN_Z1 - BIN_Z0
	local swing = math.rad(30)
	local flap = facing(mesh, (BIN_X0 + BIN_X1) / 2, FRONT + 0.02 + math.sin(swing) * height / 2, BIN_Z1 - math.cos(swing) * height / 2, 0, -math.cos(swing), math.sin(swing))
	box(flap, 0, 0, -0.006, BIN_X1 - BIN_X0 - 0.02, height - 0.01, 0.012)
	-- The hinge rod across the top of the opening.
	cylinder(mesh, (BIN_X0 + BIN_X1) / 2, FRONT + 0.02, BIN_Z1 - 0.005, 0.01, BIN_X1 - BIN_X0, "x", 8)
	-- A pressed "PUSH" bar on the door rail above it.
	box(mesh, (BIN_X0 + BIN_X1) / 2, FRONT - 0.01, BIN_Z1 + 0.03, 0.3, 0.012, 0.03)
end, nil, 0.4, nil, nil, true)

-- What's left of the window glass: jagged shards still held in the gasket
-- round the edges, each outline clockwise seen from the front.
local STUCK_SHARDS = {
	{ { -0.6, 0.63 }, { -0.6, 1.05 }, { -0.52, 0.88 }, { -0.45, 0.95 }, { -0.38, 0.7 }, { -0.2, 0.78 }, { -0.1, 0.63 } },
	{ { 0.25, 2.37 }, { 0.25, 1.9 }, { 0.18, 2.05 }, { 0.1, 1.98 }, { 0.02, 2.2 }, { -0.15, 2.15 }, { -0.25, 2.37 } },
	{ { -0.6, 1.4 }, { -0.6, 1.95 }, { -0.56, 1.7 }, { -0.575, 1.5 } },
	{ { 0, 0.63 }, { 0.05, 0.75 }, { 0.12, 0.68 }, { 0.2, 0.8 }, { 0.25, 0.74 }, { 0.25, 0.63 } },
	{ { -0.6, 2.37 }, { -0.4, 2.37 }, { -0.47, 2.27 }, { -0.55, 2.3 }, { -0.6, 2.15 } },
}
-- Shards fallen in front, each outline anticlockwise seen from above.
local FALLEN_SHARDS = {
	{ { -0.3, -0.75 }, { -0.18, -0.72 }, { -0.24, -0.62 } },
	{ { 0.05, -0.85 }, { 0.2, -0.8 }, { 0.12, -0.7 }, { 0.02, -0.74 } },
	{ { -0.5, -0.65 }, { -0.42, -0.7 }, { -0.4, -0.58 } },
	{ { 0.3, -1.0 }, { 0.38, -0.95 }, { 0.3, -0.9 } },
	{ { -0.1, -1.05 }, { 0.02, -1.02 }, { -0.05, -0.95 } },
	{ { -0.62, -0.9 }, { -0.5, -0.88 }, { -0.56, -0.8 } },
	{ { 0.1, -0.6 }, { 0.2, -0.62 }, { 0.16, -0.54 } },
}
part("Glass", nil, GLASS, function(mesh)
	for _, outline in STUCK_SHARDS do
		plate(mesh, outline, GLASS_Y, 0.012, 0.002)
	end
	for _, outline in FALLEN_SHARDS do
		lyingShard(mesh, outline, 0.01)
	end
end, true, 0)

-- Cans and coins spilled on the ground: two cans on their sides, one
-- stamped flat, and a scatter of coins.
part("Spilled", nil, CAN_RED, function(mesh)
	for _, can in { { 0.2, -0.9, 0.4 }, { -0.4, -1.1, 1.9 } } do
		local dx, dy = math.cos(can[3]), math.sin(can[3])
		local lying = facing(mesh, can[1], can[2], 0.055, dx, dy, 0)
		cylinder(lying, 0, 0, 0, 0.055, 0.17, "z", 16)
		cylinder(lying, 0, 0, 0.095, 0.048, 0.02, "z", 16)
		cylinder(lying, 0, 0, -0.095, 0.048, 0.02, "z", 16)
		ring(lying, 0, 0, 0.105, 0.038, 0.046, 0.008, "z", 16)
	end
	-- Stamped flat: a crumpled disc with its rims splayed.
	cylinder(mesh, -0.05, -0.62, 0.02, 0.075, 0.04, "z", 12)
	ring(mesh, -0.05, -0.62, 0.04, 0.05, 0.068, 0.012, "z", 12)
end, nil, 0.5)

part("Coins", nil, BRASS, function(mesh)
	for _, coin in { { 0.35, -0.7 }, { 0.42, -0.78 }, { 0.3, -0.85 }, { 0.5, -0.66 }, { 0.55, -0.9 }, { 0.46, -0.6 } } do
		cylinder(mesh, coin[1], coin[2], 0.004, 0.025, 0.006, "z", 12)
	end
end, nil, 0.3)

-- The power cable from the back down to a plug on the ground.
part("PowerCable", nil, RUBBER_BLACK, function(mesh)
	tube(mesh, { { 0.5, HY, 0.4 }, { 0.5, HY + 0.08, 0.3 }, { 0.55, HY + 0.15, 0.03 }, { 0.75, HY + 0.3, 0.03 }, { 0.85, HY + 0.32, 0.03 } }, 0.02, 8)
	box(mesh, 0.9, HY + 0.32, 0.005, 0.1, 0.06, 0.05)
	box(mesh, 0.5, HY + 0.012, 0.36, 0.08, 0.024, 0.08)
end, nil, 0.3, nil, nil, true)

finishParts()
