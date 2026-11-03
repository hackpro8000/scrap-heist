local CACHE_KEY = "FloatingIsland-bbe5c8a9441cf111"
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
-- and `wide` the width of the highlight brush strokes.
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
-- as for part().
local function chunkedPart(name, bone, color, build, smooth, rust, flat: boolean?, edge: number?, shade: number?, lit: number?)
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
			blend = EDGE_BLEND,
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
		})
		model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true })
	end
end
-- Floating Island: the generator for the game's floating islands.
-- The island is stones, not a body with stones on it. The profile (a wobbly rim
-- with one shallow bay, a cone down to a point) is only a guide for where the
-- stones sit; none of it is drawn. Cells cover the whole surface: rows down the
-- wall from the rim to the point, and a deck of rings over the flat top. Each
-- cell is a displaced blob cut by the bisector planes to its neighbours, so the
-- stones meet exactly, then sliced with a few facet planes so they read as cut
-- stone. Every stone is cut at one height, so the top is flat and walkable.
--
-- Below FLOAT_START the stones pull back from those planes, so the joints open
-- into gaps and the base comes apart into loose rocks instead of tapering to a
-- solid point. The dials, roughly in the order they matter:
--   SEED, RADIUS, DEPTH_SHARE, TAPER_POWER, WALL_REACH   the profile
--   ROCK_WIDTH, ROW_T, ROCK_FACETS, the deck rings       how it is divided
--   FLOAT_START, FLOAT_SHRINK                            how it comes apart
local SEED = 1
local RADIUS = 30
-- How deep the underside hangs, as a share of the radius.
local DEPTH_SHARE = 1.05
-- The top's height, matching the other islands so sea level stays at 0.
local CAP_TOP = 0.7
-- How far the outline moves in and out, as a share of the radius.
local WOBBLE = 0.08
-- The bay: how far it cuts in and how wide (radians) it is.
local BAY_DEPTH, BAY_WIDTH = 0.09, 0.5
-- The wall's reach at the rim, and the share it narrows to at the underside.
-- Nearly zero, so the island closes on a point rather than a flat cap.
local WALL_REACH, UNDERSIDE_SHARE = 0.86, 0.03
-- How sharply the wall draws to that point: 1 is a straight cone, higher
-- numbers keep the top broad and pull the taper into the lower half.
local TAPER_POWER = 1.35
-- The rock cells: rows down the wall, roughly how wide a cell is, and how
-- many facet slices each stone gets.
local ROCK_ROWS = 4
local ROCK_WIDTH = 7
local ROCK_FACETS = 7
-- How many times a cell's blob is split. One is enough: the fitting and the
-- slices do the shaping, and the cells are small on screen.
local ROCK_SUBDIVISIONS = 1
local ANGLES, STEPS = 128, 28
-- Below this share of the profile the stones shrink and pull apart, so the
-- base hangs under the island as loose floating rocks instead of a solid tail.
local FLOAT_START, FLOAT_SHRINK = 0.4, 0.85


local TAU = 2 * math.pi

local function hash(k: number): number
	local s = math.sin(k * 12.9898 + 4.1414) * 43758.5453
	return s - math.floor(s)
end

local function dot(a: { number }, b: { number }): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function cross(a: { number }, b: { number }): { number }
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

local function normalize(p: { number }): { number }
	local length = math.sqrt(dot(p, p))
	return { p[1] / length, p[2] / length, p[3] / length }
end

local phase = {}
for i = 1, 4 do
	phase[i] = hash(SEED * 7 + i) * TAU
end
local bayAngle = hash(SEED * 13) * TAU

-- The outline as a radius scale per angle: a sum of waves, so no two seeds
-- share an island, and one gaussian dip for the bay.
local function outlineScale(angle: number): number
	local wobble = 0.045 * math.sin(2 * angle + phase[1])
		+ 0.025 * math.sin(3 * angle + phase[2])
		+ 0.012 * math.sin(7 * angle + phase[3])
		+ 0.008 * math.sin(11 * angle + phase[4])
	local d = (angle - bayAngle + math.pi) % TAU - math.pi
	local bay = BAY_DEPTH * math.exp(-((d / BAY_WIDTH) ^ 2))
	return 1 + WOBBLE * wobble / 0.09 - bay
end

local DEPTH = RADIUS * DEPTH_SHARE
local RIM_Z = CAP_TOP - DEPTH

-- The wall's reach at `t`, 0 at the rim and 1 at the underside: a power
-- curve, so the island stays broad near the top and draws to a point below.
local function shareAt(t: number): number
	return UNDERSIDE_SHARE + (1 - UNDERSIDE_SHARE) * (1 - t) ^ TAPER_POWER
end

local function wallPoint(angle: number, t: number): { number }
	local r = RADIUS * WALL_REACH * shareAt(t) * outlineScale(angle)
	return { r * math.cos(angle), r * math.sin(angle), CAP_TOP - DEPTH * t }
end

local function wallNormal(angle: number, t: number): { number }
	local e = 1e-3
	local a1, a0 = wallPoint(angle + e, t), wallPoint(angle - e, t)
	local d1, d0 = wallPoint(angle, t + e), wallPoint(angle, t - e)
	local n = normalize(cross(
		{ a1[1] - a0[1], a1[2] - a0[2], a1[3] - a0[3] },
		{ d1[1] - d0[1], d1[2] - d0[2], d1[3] - d0[3] }
	))
	if dot(n, { math.cos(angle), math.sin(angle), 0 }) < 0 then
		n = { -n[1], -n[2], -n[3] }
	end
	return n
end

-- A unit icosphere, split `times`, returned as corners plus triangles.
local function icosphere(times: number)
	local golden = (1 + math.sqrt(5)) / 2
	local vertices = {
		{ -1, golden, 0 }, { 1, golden, 0 }, { -1, -golden, 0 }, { 1, -golden, 0 },
		{ 0, -1, golden }, { 0, 1, golden }, { 0, -1, -golden }, { 0, 1, -golden },
		{ golden, 0, -1 }, { golden, 0, 1 }, { -golden, 0, -1 }, { -golden, 0, 1 },
	}
	for i, p in vertices do
		vertices[i] = normalize(p)
	end
	local faces = {
		{ 1, 12, 6 }, { 1, 6, 2 }, { 1, 2, 8 }, { 1, 8, 11 }, { 1, 11, 12 },
		{ 2, 6, 10 }, { 6, 12, 5 }, { 12, 11, 3 }, { 11, 8, 7 }, { 8, 2, 9 },
		{ 4, 10, 5 }, { 4, 5, 3 }, { 4, 3, 7 }, { 4, 7, 9 }, { 4, 9, 10 },
		{ 5, 10, 6 }, { 3, 5, 12 }, { 7, 3, 11 }, { 9, 7, 8 }, { 10, 9, 2 },
	}
	for _ = 1, times do
		local cache, out = {}, {}
		local function midpoint(a: number, b: number): number
			local key = if a < b then a .. ":" .. b else b .. ":" .. a
			if cache[key] then
				return cache[key]
			end
			local va, vb = vertices[a], vertices[b]
			table.insert(vertices, normalize({ va[1] + vb[1], va[2] + vb[2], va[3] + vb[3] }))
			cache[key] = #vertices
			return #vertices
		end
		for _, f in faces do
			local ab, bc, ca = midpoint(f[1], f[2]), midpoint(f[2], f[3]), midpoint(f[3], f[1])
			table.insert(out, { f[1], ab, ca })
			table.insert(out, { f[2], bc, ab })
			table.insert(out, { f[3], ca, bc })
			table.insert(out, { ab, bc, ca })
		end
		faces = out
	end
	return vertices, faces
end

local unitVertices, unitFaces = icosphere(ROCK_SUBDIVISIONS)

local function wave(p: { number }, frequency: number, salt: number): number
	return math.sin(frequency * p[1] + salt)
		* math.sin(frequency * p[2] + salt * 1.7)
		* math.sin(frequency * p[3] + salt * 2.3)
end

local function planeDistance(plane: { number }, p: { number }): number
	return plane[1] * p[1] + plane[2] * p[2] + plane[3] * p[3] - plane[4]
end

-- Cuts triangles exactly at the plane and caps the opening on the plane. The
-- cap is what makes each cut a solid face rather than a hole.
local function clip(tris, plane)
	local out, cut = {}, {}
	for _, tri in tris do
		local distance = {
			planeDistance(plane, tri[1]),
			planeDistance(plane, tri[2]),
			planeDistance(plane, tri[3]),
		}
		local inside = { distance[1] <= 0, distance[2] <= 0, distance[3] <= 0 }
		if inside[1] and inside[2] and inside[3] then
			table.insert(out, tri)
		elseif not (inside[1] or inside[2] or inside[3]) then
			-- Fully outside: dropped.
		else
			local polygon = {}
			for i = 1, 3 do
				local j = i % 3 + 1
				if inside[i] then
					table.insert(polygon, tri[i])
				end
				if inside[i] ~= inside[j] and math.abs(distance[i]) > 1e-6 then
					local t = distance[i] / (distance[i] - distance[j])
					local p, q = tri[i], tri[j]
					local point = {
						p[1] + (q[1] - p[1]) * t,
						p[2] + (q[2] - p[2]) * t,
						p[3] + (q[3] - p[3]) * t,
					}
					table.insert(polygon, point)
					table.insert(cut, point)
				end
			end
			for k = 2, #polygon - 1 do
				table.insert(out, { polygon[1], polygon[k], polygon[k + 1] })
			end
		end
	end
	if #cut >= 3 then
		local unique, seen = {}, {}
		for _, p in cut do
			local key = string.format("%.4f:%.4f:%.4f", p[1], p[2], p[3])
			if not seen[key] then
				seen[key] = true
				table.insert(unique, p)
			end
		end
		if #unique >= 3 then
			local centre = { 0, 0, 0 }
			for _, p in unique do
				centre = { centre[1] + p[1], centre[2] + p[2], centre[3] + p[3] }
			end
			centre = { centre[1] / #unique, centre[2] / #unique, centre[3] / #unique }
			local normal = { plane[1], plane[2], plane[3] }
			local u = cross(normal, { 0, 0, 1 })
			if dot(u, u) < 1e-8 then
				u = cross(normal, { 1, 0, 0 })
			end
			u = normalize(u)
			local v = cross(normal, u)
			table.sort(unique, function(a, b)
				local da = { a[1] - centre[1], a[2] - centre[2], a[3] - centre[3] }
				local db = { b[1] - centre[1], b[2] - centre[2], b[3] - centre[3] }
				return math.atan2(dot(da, v), dot(da, u)) < math.atan2(dot(db, v), dot(db, u))
			end)
			for i = 1, #unique do
				local j = i % #unique + 1
				table.insert(out, { centre, unique[i], unique[j] })
			end
		end
	end
	return out
end

-- How far apart stones sit round the wall, from the widest row.
local spacing = TAU * RADIUS * WALL_REACH * shareAt(0.5) / math.max(6, math.round(TAU * RADIUS * WALL_REACH * shareAt(0.5) / ROCK_WIDTH))

-- The stones are the surface now, so their seeds cover the whole island: rows
-- down the wall from the rim to the tip, then a deck over the flat top. The
-- profile only decides where the seeds sit; none of it is drawn.
-- Every slot keeps a stone; size variety comes from a power weight instead of
-- dropped slots, because a dropped slot leaves a hole its neighbours may not
-- reach across.
local seeds = {}
local function addSeed(x, y, z, t, size, out, floating)
	local i = #seeds + 1
	-- A heavy seed claims more of the surface than a light one. The weight is
	-- in squared-distance units, so it scales with spacing.
	seeds[i] = {
		x, y, z,
		size = size,
		t = t,
		out = out,
		-- Every stone is cut at one height: the top of the island is a flat,
		-- walkable surface, with no stone standing above its neighbours.
		capZ = CAP_TOP,
		floating = floating,
		weight = (hash(SEED * 57 + i) - 0.5) * spacing * spacing * 0.3,
	}
end

-- Rows down the wall from the rim to the point, bunched where the cone turns
-- quickly so the point closes on stone.
local ROW_T = { 0.09, 0.28, 0.47, 0.64, 0.78, 0.89, 0.96 }
for row = 1, #ROW_T do
	local t = ROW_T[row]
	local circumference = TAU * RADIUS * WALL_REACH * shareAt(t)
	local count = math.max(3, math.round(circumference / ROCK_WIDTH))
	local offset = (row % 2) * 0.5
	-- A size gradient down the wall: each row is smaller than the one above it,
	-- so the stones shrink toward the tip instead of jumping around. The jitter
	-- stays under half a row's step, which keeps the order intact.
	local rowSize = 1.15 - 0.5 * row / #ROW_T
	for col = 0, count - 1 do
		local i = #seeds + 1
		local angle = TAU * (col + offset) / count
		local p = wallPoint(angle, t)
		local n = wallNormal(angle, t)
		-- Some seeds sit inside the wall, some just outside, so the cells cut
		-- the surface at angles rather than all from one shell.
		local lift = -1.2 + 2.6 * hash(SEED * 71 + i)
		addSeed(
			p[1] + n[1] * lift,
			p[2] + n[2] * lift,
			p[3] + n[3] * lift,
			t,
			rowSize + (hash(SEED * 53 + i) - 0.5) * 0.07,
			n
		)
	end
end

-- The deck: seeds on concentric rings over the flat top, trimmed to the
-- outline. Rings keep the spacing even all the way in, so no band of the
-- plateau is left without a stone to cover it. The blobs are cut flat at the
-- cap, so the plateau comes out as a mosaic of stone tops that meet on the
-- same planes the wall stones meet on.
local deckStep = ROCK_WIDTH
local deckSize = 1.15 - 0.5 * 0.5 / #ROW_T
local deckRim = RADIUS * WALL_REACH * (1 + WOBBLE)
for ring = 0, math.floor(deckRim / deckStep) do
	local r = ring * deckStep
	local count = if ring == 0 then 1 else math.max(5, math.round(TAU * r / deckStep))
	local offset = (ring % 2) * 0.5
	for col = 0, count - 1 do
		local angle = TAU * (col + offset) / count
		local x, y = r * math.cos(angle), r * math.sin(angle)
		local rim = RADIUS * WALL_REACH * outlineScale(math.atan2(y, x))
		if math.sqrt(x * x + y * y) < rim - 0.4 then
			local i = #seeds + 1
			addSeed(x, y, CAP_TOP, 0, deckSize + (hash(SEED * 61 + i) - 0.5) * 0.07, { 0, 0, 1 })
		end
	end
end

local REACH = spacing * 3.2

-- Each stone's blob has to reach past the furthest bisector it can be cut
-- by, or the cell never fills its share and a hole appears. So the radius is
-- worked out per cell from its own neighbours, not from one global constant.
local cellRadius = {}
for i, seed in seeds do
	if seed.radius then
		cellRadius[i] = seed.radius
		continue
	end
	-- No floor at the wall spacing: the rows near the tip are only a couple of
	-- studs across, and a floor there grows the chips into a bulb.
	local farthest = 0
	for j, other in seeds do
		if j ~= i then
			local dx, dy, dz = other[1] - seed[1], other[2] - seed[2], other[3] - seed[3]
			local distance = dx * dx + dy * dy + dz * dz
			if distance < REACH * REACH and distance > farthest * farthest then
				farthest = math.sqrt(distance)
			end
		end
	end
	-- A blob far bigger than its own cell clips away to nothing, so the reach
	-- stays close to the cell it has to fill.
	-- Capped at 1.3 spacings: a blob far bigger than its own cell clips away
	-- to nothing. The small floor keeps the chips at the tip from vanishing.
	local radius = math.clamp(farthest, 0.5, spacing * 1.3) * 0.9 * (0.75 + 0.25 * shareAt(seed.t))
	-- Below the float start the stones pull back from their neighbours, so the
	-- joints open into gaps and the base comes apart. The jitter keeps it from
	-- reading as a ring: every stone lets go at its own rate.
	local float = math.clamp((seed.t - FLOAT_START) / (1 - FLOAT_START), 0, 1)
	local jitter = 0.72 + 0.56 * hash(SEED * 107 + i)
	cellRadius[i] = radius * (1 - FLOAT_SHRINK * float ^ 0.5 * jitter)
end

-- Smooth value noise on a lattice, for the grain inside one material.
local function noise(p, scale, salt)
	local x, y, z = p[1] * scale, p[2] * scale, p[3] * scale
	local i, j, k = math.floor(x), math.floor(y), math.floor(z)
	local fx, fy, fz = x - i, y - j, z - k
	local ux, uy, uz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
	local function at(a, b, c)
		return hash(a * 157.0 + b * 311.0 + c * 613.0 + salt)
	end
	local function mix(a, b, t)
		return a + (b - a) * t
	end
	local x00 = mix(at(i, j, k), at(i + 1, j, k), ux)
	local x10 = mix(at(i, j + 1, k), at(i + 1, j + 1, k), ux)
	local x01 = mix(at(i, j, k + 1), at(i + 1, j, k + 1), ux)
	local x11 = mix(at(i, j + 1, k + 1), at(i + 1, j + 1, k + 1), ux)
	return mix(mix(x00, x10, uy), mix(x01, x11, uy), uz)
end

-- Each stone takes one material and keeps it: no blending inside a rock, no
-- gradient across one. A texel finds its stone through a lookup grid, built
-- once from the seeds, so the paint stays a table read per texel.
local MATERIALS = {
	-- grey rock, warm rock, pale rock, dark rock, topsoil, grass, moss
	{ 0.36, 0.34, 0.31 },
	{ 0.37, 0.33, 0.28 },
	{ 0.40, 0.39, 0.36 },
	{ 0.30, 0.29, 0.27 },
	{ 0.30, 0.26, 0.20 },
	{ 0.33, 0.29, 0.23 },
	{ 0.26, 0.29, 0.21 },
}

-- Below the deck, stones mostly stay rock; the top course gets soil and grass.
local DECK_MATERIALS = { 5, 5, 5, 6, 6, 7, 7, 1 }
local WALL_MATERIALS = { 1, 1, 2, 2, 4, 3, 7 }

for i, seed in seeds do
	local pick = if seed.t == 0 then DECK_MATERIALS else WALL_MATERIALS
	seed.material = pick[1 + math.floor(hash(SEED * 163 + i) * #pick)]
	-- A small tone shift per stone, so two stones of one material differ.
	seed.tone = 0.95 + 0.1 * hash(SEED * 167 + i)
end

-- The lookup grid: 1-stud cells holding the nearest stone. It is filled by
-- walking each stone's own box, so the build stays linear in stones rather
-- than in stones times cells.
local GRID = 1.0
local lows, highs = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
for _, seed in seeds do
	for k = 1, 3 do
		lows[k] = math.min(lows[k], seed[k] - 1)
		highs[k] = math.max(highs[k], seed[k] + 1)
	end
end
local counts = {}
for k = 1, 3 do
	counts[k] = math.ceil((highs[k] - lows[k]) / GRID) + 1
end
local index, closest = {}, {}
for i, seed in seeds do
	local reach = 5
	for ix = math.floor((seed[1] - reach - lows[1]) / GRID), math.ceil((seed[1] + reach - lows[1]) / GRID) do
		for iy = math.floor((seed[2] - reach - lows[2]) / GRID), math.ceil((seed[2] + reach - lows[2]) / GRID) do
			for iz = math.floor((seed[3] - reach - lows[3]) / GRID), math.ceil((seed[3] + reach - lows[3]) / GRID) do
				if ix < 0 or iy < 0 or iz < 0 or ix >= counts[1] or iy >= counts[2] or iz >= counts[3] then
					continue
				end
				local x, y, z = lows[1] + (ix + 0.5) * GRID, lows[2] + (iy + 0.5) * GRID, lows[3] + (iz + 0.5) * GRID
				local dx, dy, dz = seed[1] - x, seed[2] - y, seed[3] - z
				local d = dx * dx + dy * dy + dz * dz
				local at = ix + counts[1] * (iy + counts[2] * iz)
				if not closest[at] or d < closest[at] then
					closest[at], index[at] = d, i
				end
			end
		end
	end
end

local function stoneAt(x, y, z): number
	local ix = math.floor((x - lows[1]) / GRID)
	local iy = math.floor((y - lows[2]) / GRID)
	local iz = math.floor((z - lows[3]) / GRID)
	if ix < 0 or iy < 0 or iz < 0 or ix >= counts[1] or iy >= counts[2] or iz >= counts[3] then
		return 1
	end
	return index[ix + counts[1] * (iy + counts[2] * iz)] or 1
end

local function material(px, py, pz, _nx, _ny, _nz)
	local seed = seeds[stoneAt(px, py, pz)]
	local colour = MATERIALS[seed.material]
	-- Grain is the stone's own material, not a second one: a small tonal shift
	-- inside the colour it already has.
	local grain = 0.9 + 0.2 * noise({ px, py, pz }, 0.8, 5.1)
	local tone = seed.tone * grain
	return colour[1] * tone, colour[2] * tone, colour[3] * tone
end

-- Chunks: the surface is cut into sectors and height bands, each its own part
-- with a 1024 texture. Cutting by stone rather than by face keeps every cell's
-- seam inside one part, so the fitting survives the split, and the islands of
-- the unwrap stay whole.
local SECTORS = 6

local function chunkOf(seed): number
	if seed.t == 0 then
		return 0
	end
	local angle = math.atan2(seed[2], seed[1]) + math.pi
	local sector = math.floor(angle / TAU * SECTORS) % SECTORS
	local band = if seed.t < 0.45 then 1 else 2
	return 1 + sector + SECTORS * (band - 1)
end

local function buildRocks(mesh, chunk)
	for i, seed in seeds do
		if chunkOf(seed) ~= chunk then
			continue
		end
		-- Stones shrink with the wall, so the bottom rows are chips rather
		-- than full-size boulders crowded round a point.
		local radius = cellRadius[i] * seed.size
		local points = {}
		for v, p in unitVertices do
			local r = (1 + 0.16 * wave(p, 2.3, SEED + i) + 0.05 * wave(p, 4.9, SEED + i + 3.1)) * seed.size
			local z = p[3] * r * radius
			-- A hanging stone grows downward from its seed, not both ways.
			if z < 0 then
				z = z * (seed.stretch or 1)
			end
			points[v] = {
				seed[1] + p[1] * r * radius,
				seed[2] + p[2] * r * radius,
				seed[3] + z,
			}
		end
		local tris = {}
		for _, f in unitFaces do
			table.insert(tris, { points[f[1]], points[f[2]], points[f[3]] })
		end
		-- The flat spots, cut while the stone is still free-standing. They are
		-- biased to the exposed side of the stone: a facet that cuts across the
		-- cell's own bisectors would leave a gap the core shows through.
		local out = seed.out
		-- Deck stones get no facet cuts: their top is the flat cap, and facets
		-- would break it into a fan of small faces.
		for k = 1, (if seed.t == 0 then 0 else ROCK_FACETS) do
			local n = normalize({
				out[1] + 1.2 * (hash(SEED * 31 + i * 13 + k * 7.1) - 0.5),
				out[2] + 1.2 * (hash(SEED * 17 + i * 13 + k * 3.3) - 0.5),
				out[3] + 1.2 * (hash(SEED * 5 + i * 13 + k * 11.7) - 0.5),
			})
			local reach = 0.86 + 0.11 * hash(SEED * 41 + i * 13 + k * 5.9)
			tris = clip(tris, { n[1], n[2], n[3], dot(n, seed) + reach * radius })
		end
		-- Cut every stone flat at its cap height: the deck and the top wall row
		-- share the plane, so the top of the island is a mosaic of flat tops.
		tris = clip(tris, { 0, 0, 1, seed.capZ })
		-- The fit: cut against every nearby seed, so neighbours share planes.
		for j, other in seeds do
			-- A falling rock is not fitted to anything: it is a free boulder.
			if j ~= i and not seed.floating then
				local dx, dy, dz = other[1] - seed[1], other[2] - seed[2], other[3] - seed[3]
				local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
				if distance < REACH and distance > 1e-6 then
					local n = { dx / distance, dy / distance, dz / distance }
					-- The power plane: the midpoint shifts by the weight
					-- difference, so a heavy seed pushes it away from itself.
					local seedSq = seed[1] ^ 2 + seed[2] ^ 2 + seed[3] ^ 2
					local otherSq = other[1] ^ 2 + other[2] ^ 2 + other[3] ^ 2
					-- The midpoint plane sits (otherSq - seedSq) / 2d from the
					-- origin; the weight only shifts it along n. Clamping the
					-- whole constant instead would drag rim cells' planes back
					-- to the origin and cut the cell away entirely.
					local midpoint = (otherSq - seedSq) / (2 * distance)
					local shift = (seed.weight - other.weight) / (2 * distance)
					shift = math.clamp(shift, -0.32 * distance, 0.32 * distance)
					tris = clip(tris, { n[1], n[2], n[3], midpoint + shift })
				end
			end
		end
		for _, tri in tris do
			local a, b, c = tri[1], tri[2], tri[3]
			local n = cross({ b[1] - a[1], b[2] - a[2], b[3] - a[3] }, { c[1] - a[1], c[2] - a[2], c[3] - a[3] })
			local mid = { (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3, (a[3] + b[3] + c[3]) / 3 }
			local facing = n[1] * (mid[1] - seed[1]) + n[2] * (mid[2] - seed[2]) + n[3] * (mid[3] - seed[3])
			if facing < 0 then
				a, b, c = a, c, b
			end
			mesh:face({
				mesh:vertex(a[1], a[2], a[3]),
				mesh:vertex(b[1], b[2], b[3]),
				mesh:vertex(c[1], c[2], c[3]),
			})
		end
	end
	-- Weld so the shading can run smooth over each stone; the crease angle in
	-- part() keeps the cut faces and the seams sharp. A chunked build gets its
	-- own weld per chunk instead, so the recorder is skipped.
	if mesh.weld then
		mesh:weld(1e-4)
	end
end

-- The upper half of the wall and the deck take the wide wear band; the stones
-- that fall away underneath take a narrow one, because they are smaller.
for chunk = 0, SECTORS * 2 do
	local edge = if chunk <= SECTORS then 0.55 else 0.3
	part("Island_" .. chunk, nil, MATERIALS[1], function(mesh)
		buildRocks(mesh, chunk)
	end, nil, material, 1024, nil, true, edge, 2.0, 1.4, 2.4)
	-- Chunks of one island share a group, so a seam between two of them is a
	-- crease the bake knows belongs to the island, not a dark edge.
	parts[#parts].group = "Island"
end

finishParts()
