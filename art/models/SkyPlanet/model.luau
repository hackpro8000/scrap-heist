local CACHE_KEY = "SkyPlanet-57086543dc75872e"
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
-- Sky Planet: the pastel banded giant that fills a corner of the sky, with
-- its ring system. The sphere is two hemispheres so each gets a full
-- texture; the ring is six flat bands with gaps between them. 10 studs in
-- radius, spinning about z; the game scales it up a few hundred times.
-- Sky bodies: shared builders and painters for the planet and the moons.
-- A body is a smooth sphere, 10 studs in radius, spinning about z, painted
-- flat (the game's sun shades it). Two genotypes: banded gas giants and
-- cratered moons, each drawn from a palette and a seed. Rings are flat
-- bands of real geometry with gaps between them, so they need no alpha.

local BODY_RADIUS = 10

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
		unit = function()
			local z = nextUnit() * 2 - 1
			local t, r = nextUnit() * TAU, math.sqrt(1 - z * z)
			return r * math.cos(t), r * math.sin(t), z
		end,
	}
end

local function fbm(x, y, z)
	return math.noise(x, y, z) + 0.5 * math.noise(x * 2.03, y * 2.03, z * 2.03) + 0.25 * math.noise(x * 4.1, y * 4.1, z * 4.1)
end

local function blend(a, b, f)
	return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

-- Part of a sphere at (cx, cy, cz): rows `from` to `to` of `rings`, top first.
local function sphereRows(mesh, cx, cy, cz, radius, rings, sides, from, to)
	local grid = {}
	for r = from, to do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local theta = s / sides * TAU
			grid[r][s] = mesh:vertex(
				cx + math.sin(phi) * math.cos(theta) * radius,
				cy + math.sin(phi) * math.sin(theta) * radius,
				cz + math.cos(phi) * radius
			)
		end
	end
	for r = from, to - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			mesh:face({ grid[r][s], grid[r + 1][s], grid[r + 1][n], grid[r][n] })
		end
	end
end

-- A flat ring band round z at (cx, cy, cz), `thick` deep.
local function ringBand(mesh, cx, cy, cz, inner, outer, thick, steps)
	local rows = {}
	for i = 0, steps - 1 do
		local t = i / steps * TAU
		local c, s = math.cos(t), math.sin(t)
		rows[i + 1] = {
			mesh:vertex(cx + c * outer, cy + s * outer, cz - thick / 2),
			mesh:vertex(cx + c * outer, cy + s * outer, cz + thick / 2),
			mesh:vertex(cx + c * inner, cy + s * inner, cz + thick / 2),
			mesh:vertex(cx + c * inner, cy + s * inner, cz - thick / 2),
		}
	end
	for i = 1, steps do
		local a, b = rows[i], rows[i % steps + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], a[l], b[l], b[k] })
		end
	end
end

-- A banded giant's paint. `look` has: bands (colours, pole to pole), seed,
-- storms (how many), shadow (the ring's shadow line, or nil).
local function bandedPainter(look, cx, cy, cz)
	local rng = seeded(look.seed)
	-- Band edges from the north pole (1) to the south (-1), uneven widths.
	local edges, total = { 0 }, 0
	for i = 1, #look.bands do
		total += rng.number(0.6, 1.6)
		edges[i + 1] = total
	end
	for i = 1, #edges do
		edges[i] = 1 - 2 * edges[i] / total
	end
	local storms = {}
	for _ = 1, look.storms or 0 do
		local sx, sy, sz = rng.unit()
		sz *= 0.55
		local l = math.sqrt(sx * sx + sy * sy + sz * sz)
		table.insert(storms, {
			x = sx / l,
			y = sy / l,
			z = sz / l,
			wide = rng.number(0.1, 0.22),
			tall = rng.number(0.045, 0.085),
			color = look.bands[rng.integer(1, #look.bands)],
		})
	end
	local white, deep = { 1, 1, 1 }, look.deep
	return function(x, y, z)
		local px, py, pz = (x - cx) / BODY_RADIUS, (y - cy) / BODY_RADIUS, (z - cz) / BODY_RADIUS
		local s = look.seed * 0.13
		-- Bands wander: a broad wave and a fine ripple, stretched along the spin.
		local v = pz + fbm(px * 1.2 + s, py * 1.2, pz * 3.5) * 0.05 + fbm(px * 4 + s, py * 4, pz * 11) * 0.012
		local index = #look.bands
		for i = 1, #look.bands do
			if v > edges[i + 1] then
				index = i
				break
			end
		end
		local color = look.bands[index]
		local r, g, b = color[1], color[2], color[3]
		local within = (edges[index] - v) / (edges[index] - edges[index + 1])
		-- Brush strokes: long streaks of a lighter and a darker tone.
		local streak = fbm(px * 2.2 + s, py * 2.2 + index * 3.7, pz * 26)
		if streak > 0.22 then
			r, g, b = blend({ r, g, b }, white, 0.3)
		elseif streak < -0.3 then
			r, g, b = blend({ r, g, b }, deep, 0.28)
		end
		-- Hair-thin strokes over those.
		if fbm(px * 5 + s, py * 5, pz * 70 + index) > 0.42 then
			r, g, b = blend({ r, g, b }, white, 0.45)
		end
		-- Each band has a pale upper edge and a darker lower one.
		if within < 0.08 then
			r, g, b = blend({ r, g, b }, white, 0.5)
		elseif within > 0.9 then
			r, g, b = blend({ r, g, b }, deep, 0.3)
		end
		for _, storm in storms do
			if px * storm.x + py * storm.y + pz * storm.z > 0 then
				-- East and north at the storm, on the sphere.
				local el = math.sqrt(storm.x * storm.x + storm.y * storm.y)
				local ex, ey = -storm.y / el, storm.x / el
				local dx, dy, dz = px - storm.x, py - storm.y, pz - storm.z
				local u = (dx * ex + dy * ey) / storm.wide
				local n = (dz * el - (dx * storm.x + dy * storm.y) * storm.z / el) / storm.tall
				local q = math.sqrt(u * u + n * n)
				if q < 1 then
					-- Swirled rings, edged with a dark line.
					local swirl = math.floor(q * 4 + math.atan2(n, u) / TAU) % 2
					if q > 0.88 then
						r, g, b = blend(storm.color, deep, 0.45)
					elseif swirl == 0 then
						r, g, b = blend(storm.color, white, 0.5)
					else
						r, g, b = blend(storm.color, deep, 0.12)
					end
				end
			end
		end
		-- Soft pale caps at the poles.
		local cap = math.clamp((math.abs(pz) - 0.86) / 0.1, 0, 1)
		r, g, b = blend({ r, g, b }, look.pole, cap * 0.7)
		-- The ring's shadow, a line just off the equator.
		if look.shadow and pz < look.shadow and pz > look.shadow - 0.07 then
			r, g, b = blend({ r, g, b }, deep, 0.4)
		end
		return r, g, b
	end
end

-- A cratered moon's paint. `look` has: tones (dark to light), seed, craters.
local function crateredPainter(look, cx, cy, cz)
	local rng = seeded(look.seed)
	local craters = {}
	for _ = 1, look.craters do
		local x, y, z = rng.unit()
		table.insert(craters, { x, y, z, rng.number(0.06, 0.24) })
	end
	local tones = look.tones
	return function(x, y, z)
		local px, py, pz = (x - cx) / BODY_RADIUS, (y - cy) / BODY_RADIUS, (z - cz) / BODY_RADIUS
		local s = look.seed * 0.17
		-- Seas and highlands in flat patches.
		local land = fbm(px * 1.6 + s, py * 1.6, pz * 1.6)
		local level = if land > 0.2 then 3 elseif land > -0.25 then 2 else 1
		for _, crater in craters do
			local dx, dy, dz = px - crater[1], py - crater[2], pz - crater[3]
			local q = math.sqrt(dx * dx + dy * dy + dz * dz) / crater[4]
			if q < 1.12 then
				-- Lit from the upper left: the far wall catches the light.
				local facing = (dx * -0.5 + dy * -0.5 + dz * 0.7) / math.max(q * crater[4], 1e-4)
				if q > 1 then
					level = math.min(level + 1, 4)
				elseif q > 0.72 then
					level = if facing > 0.1 then 4 else 1
				else
					level = math.max(level - 1, 1)
				end
			end
		end
		-- Speckle so the flats aren't empty.
		if math.noise(px * 14 + s, py * 14, pz * 14) > 0.38 then
			level = math.max(level - 1, 1)
		end
		local color = tones[level]
		return color[1], color[2], color[3]
	end
end

-- A ring's paint: fine pastel grooves across it and scattered glints.
local function ringPainter(colors, cx, cy, inner, outer, seed)
	return function(x, y, _z)
		local dx, dy = x - cx, y - cy
		local reach = math.sqrt(dx * dx + dy * dy)
		local t = math.clamp((reach - inner) / (outer - inner), 0, 0.999) * (#colors - 1)
		local i = math.floor(t)
		local r, g, b = blend(colors[i + 1], colors[i + 2], t - i)
		local groove = math.sin(reach * 21 + seed) + math.sin(reach * 53 + seed * 2) * 0.6 + math.noise(reach * 6, seed) * 0.8
		if groove > 0.7 then
			r, g, b = blend({ r, g, b }, { 1, 1, 1 }, 0.55)
		elseif groove < -0.8 then
			r, g, b = blend({ r, g, b }, { 0.62, 0.56, 0.86 }, 0.35)
		end
		if math.noise(x * 7 + seed, y * 7, 0.5) > 0.44 then
			return 1, 1, 0.96
		end
		return r, g, b
	end
end

-- Bakes one flat-painted part.
local function bakeBody(name, size, build, painter)
	local mesh = Mesh.new()
	build(mesh)
	mesh:setSmooth(true)
	mesh:unwrap()
	local image = Image.new(size, size, 1, 1, 1)
	mesh:paint(image, painter)
	model.part(name, mesh, image, { preview = true })
end

local PASTEL = {
	{ 0.8, 0.76, 0.97 },
	{ 1, 0.8, 0.66 },
	{ 1, 0.95, 0.8 },
	{ 0.98, 0.7, 0.78 },
	{ 0.72, 0.84, 1 },
	{ 1, 0.88, 0.62 },
	{ 0.66, 0.9, 0.86 },
	{ 0.93, 0.74, 0.95 },
	{ 1, 0.96, 0.86 },
	{ 1, 0.74, 0.6 },
	{ 0.74, 0.8, 1 },
	{ 0.99, 0.84, 0.88 },
	{ 0.7, 0.9, 0.9 },
	{ 1, 0.9, 0.7 },
	{ 0.84, 0.74, 0.97 },
	{ 0.98, 0.78, 0.72 },
	{ 0.76, 0.86, 1 },
	{ 0.86, 0.8, 0.98 },
}
local look = {
	bands = PASTEL,
	seed = 41,
	storms = 5,
	deep = { 0.5, 0.42, 0.74 },
	pole = { 0.8, 0.8, 0.98 },
	shadow = -0.04,
}
local RINGS, SIDES = 32, 64
local paint = bandedPainter(look, 0, 0, 0)

bakeBody("North", 1024, function(mesh)
	sphereRows(mesh, 0, 0, 0, BODY_RADIUS, RINGS, SIDES, 0, RINGS // 2)
end, paint)
bakeBody("South", 1024, function(mesh)
	sphereRows(mesh, 0, 0, 0, BODY_RADIUS, RINGS, SIDES, RINGS // 2, RINGS)
end, paint)

local RING_COLORS = { { 1, 0.95, 0.82 }, { 0.92, 0.82, 1 }, { 0.78, 0.92, 1 }, { 1, 0.86, 0.92 }, { 0.9, 0.86, 1 } }
local BANDS = { { 13.4, 14.5 }, { 14.8, 17.3 }, { 17.55, 18.05 }, { 18.5, 20.7 }, { 20.95, 21.35 }, { 21.65, 22.2 } }
bakeBody("Ring", 1024, function(mesh)
	for _, band in BANDS do
		ringBand(mesh, 0, 0, 0, band[1], band[2], 0.05, 96)
	end
end, ringPainter(RING_COLORS, 0, 0, 13.4, 22.2, 3))
