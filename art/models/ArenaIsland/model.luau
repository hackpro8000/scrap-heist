local CACHE_KEY = "ArenaIsland-f9e2c7afd164641c"
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
-- thin it would visibly bend them.
local function part(name, bone, color, build, smooth, rust, texture: number?, emissive: number?, flat: boolean?)
	local mesh = Mesh.new()
	build(if rust == 0 or flat then mesh else imperfect(mesh, name))
	mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
	local fit = mesh:unwrap()
	local size = if texture then texture
		elseif texelDensity then math.clamp(math.ceil(texelDensity / fit / 4) * 4, 16, 1024)
		else TEXTURE
	local image = Image.new(size, size, color[1], color[2], color[3])
	local entry = { name = name, bone = bone, mesh = mesh, image = image, emissive = emissive }
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
local function chunkedPart(name, bone, color, build, smooth, rust, flat: boolean?)
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
		end, smooth, 0, texture)
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
			highlight = EDGE_HIGHLIGHT,
			shadow = CONTACT_SHADOW,
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
		})
		model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true })
	end
end
-- Arena Island: the arena's octagonal floating island, from the shared
-- rock generator (shared/RockIsland.luau) with the yard islands' rocks. The
-- top carries the Server Map's ring road and
-- arena: rim at z = 0.7, sinking into the arena bowl inside the road.
-- Sized so the rim stands just outside the ring road, whose outer edge is 58
-- studs out on a flat side.
local RADIUS = 72
-- The yard islands' rock size (4.7 times the base), so the big arena wall
-- shows many rocks rather than a few broad panels.
local ROCK_SCALE = 4.7
-- Four times the base bulge, a little short of the yards' (which scale it
-- with their rocks), so the rocks stand clearly proud of the big body.
local ROCK_BULGE = 4

-- The Server Map's octagon: a flat side facing each spoke (1 there), the
-- corners between them, so the ring road and arena on top share the outline.
local function octagon(angle: number): number
	local sector = ((angle + math.pi / 8) % (math.pi / 4)) - math.pi / 8
	return 1 / math.cos(sector)
end

-- The island's outline, as a radius scale per angle: the octagon with only
-- a slight wobble, so the rim keeps clear of the ring road all the way round.
local function outlineScale(angle: number): number
	return octagon(angle) + 0.012 * math.sin(3 * angle + 0.6) + 0.008 * math.sin(5 * angle + 2.1)
end

-- The top, matching the Server Map's arena (its heightAt and the ring road
-- laid over it), in octagon radii: flat at the rim, sunk a little under the
-- road so the two never z-fight, then a straight bank down to the fight
-- floor. The bowl is the deck height (2) plus the arena's depth (3.5) deep.
local CAP_TOP = 0.7
local ARENA_FLOOR, ROAD_INNER, ROAD_OUTER = 36, 50, 58
local BOWL_DEPTH, ROAD_SINK = 5.5, 0.15
local function bowlAt(radius: number): number
	if radius > ROAD_INNER and radius < ROAD_OUTER then
		return CAP_TOP - ROAD_SINK
	end
	return CAP_TOP - BOWL_DEPTH * (1 - math.clamp((radius - ARENA_FLOOR) / (ROAD_INNER - ARENA_FLOOR), 0, 1))
end
-- Rings of the top, from just inside the rim to the centre: either side of
-- each road edge, every 2 studs down the bank, then wider across the floor.
local islandTop = {
	radii = { ROAD_OUTER + 0.4, ROAD_OUTER - 0.1, ROAD_INNER + 0.2, ROAD_INNER - 0.2, 48, 46, 44, 42, 40, 38, ARENA_FLOOR, 30, 24, 18, 12, 6 },
	height = bowlAt,
	octagon = octagon,
}

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
-- Rock Island: the shared generator behind Arena, Yard, Pad and Market Island,
-- the Island Rocks algorithm (items/IslandRocks.luau) sized per island. One
-- set of rocks covers the whole island, from the top rim down the wall, round
-- the bottom rim and in across the underside. The seeds are scattered in 3D on
-- the surface and each rock is the set of points nearer its seed than any
-- other (a power diagram, so bigger rocks claim more), so a rock carries round
-- the rim instead of the pattern restarting there. The surface is meshed as a
-- grid and every triangle is cut by the bisector planes between the seeds its
-- corners belong to, so the seams are exact and both rocks on a seam share it.
--
-- The item sets, before including this:
--   RADIUS        the island's radius;
--   ROCK_SCALE    how many times the base rock size its rocks are;
--   outlineScale  the outline as a radius scale per angle;
--   ROCK_BULGE    optionally, how many times the base bulge its rocks stand
--                 out (ROCK_SCALE if not set; 0 for a smooth body);
--   islandTop     optionally, a shaped top instead of a flat one:
--                 { radii, height, octagon }, rings at octagon radii `radii`
--                 (outermost first), each at height(radius), measured with
--                 octagon(angle) as the radius scale.
useTexelDensity(16)
local CAP_TOP = 0.7
local WALL_REACH = 0.86
-- The body keeps the Island Rocks test island's proportions (16 deep at
-- radius 14), so a big island is as deep for its size as a small one.
local PROPORTION = RADIUS / 14
local PROFILE_DEPTH, HALF_DEPTH = 16 * PROPORTION, 4 * PROPORTION
local UNDERSIDE_SHARE = 0.18
-- Rock spacing, scaled by the item's ROCK_SCALE, and how far a rock of base
-- size bulges out, scaled by its ROCK_BULGE. Rock sizes spread by
-- e^(SIZE_SPREAD * r) for r from -1 to 1, and are bigger near the top:
-- TOP_SIZE times the base size at the rim, easing to BOTTOM_SIZE.
local RELIEF = if ROCK_BULGE ~= nil then ROCK_BULGE else ROCK_SCALE
local ROCK, BULGE = 4.6 * ROCK_SCALE, 1.5 * RELIEF
local SIZE_SPREAD = 0.8
-- A rock's size runs from MIN_SHARE of the largest rock its zone allows up to
-- that largest size, so the smallest rock is always 80% of the biggest.
local MIN_SHARE = 0.8
local TOP_SIZE, BOTTOM_SIZE = 1.3, 0.8
-- How sharply the size falls off going down: the size eases from TOP_SIZE to
-- BOTTOM_SIZE along (1 - depth)^SIZE_CURVE, so the top stays near its maximum
-- and the drop comes lower down.
local SIZE_CURVE = 3
-- How deep each joint sits (scaling with the bulge, but never under the
-- base joint, so even a smooth body shows its seams), and how far from the
-- top rim the joint takes to reach that depth. The rim itself stays on the
-- profile. The joint's width is set below, from the grid.
local SEAM_DEPTH, SEAM_FADE = 0.2 * math.max(RELIEF, 1), 2.5
-- Below DOWN_FROM of the way down the wall, a rock pushes straight down rather
-- than out along the wall, so the rocks near the bottom stand off the underside
-- instead of flaring the island's silhouette.
local DOWN_FROM = 0.55
-- The tip is one rock covering the bottom out to TIP_SHARE of the underside's rim.
local TIP_SHARE = 0.5
-- How much of its crest a rock still stands off at its seams.
local REST = 0.45
-- How far the seams near the top merge: their dip is cut by MERGE_TOP at the
-- rim, easing back to full depth by the middle of the wall.
local MERGE_TOP = 1.0
-- How much of its bulge a rock keeps at the bottom: BOTTOM_BULGE of it, easing
-- in from the middle of the wall.
local BOTTOM_BULGE = 0.3
-- How much each rock's texture varies from its neighbours': TOP_SPREAD at the
-- rim, easing to BOTTOM_SPREAD at the bottom.
local TOP_SPREAD, BOTTOM_SPREAD = 2.0, 0.5
-- The surface grid: samples round the island, rows down the wall and rings in
-- across the underside, finer on bigger islands up to a limit.
local ANGLES = math.clamp(math.round(96 * PROPORTION), 96, 384)
local WALL_ROWS = math.clamp(math.round(36 * PROPORTION), 36, 120)
local UNDER_ROWS = math.clamp(math.round(30 * PROPORTION), 30, 90)
local ROCK_COLOUR = { 0.36, 0.33, 0.28 }

local R0 = RADIUS * WALL_REACH
local RIM_Z = CAP_TOP - PROFILE_DEPTH
-- The grid's spacing on the wall: the larger of its step round the island
-- and its step down the steep top of the wall. Each joint is at least
-- JOINT_STEPS of these wide, so the dip into a seam spans several vertices
-- either side and doesn't step where the seam crosses the grid at a slant.
local GRID_STEP = math.max(TAU * R0 * 1.1 / ANGLES, 2 * PROFILE_DEPTH / WALL_ROWS)
local JOINT_STEPS = 3
local JOINT_WIDTH = math.max(0.4 * math.max(RELIEF, 1), JOINT_STEPS * GRID_STEP)

local function random(k: number): number
	local s = math.sin(k * 12.9898 + 4.1414) * 43758.5453
	return s - math.floor(s)
end

local function sub(a: { number }, b: { number }): { number }
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function dot(a: { number }, b: { number }): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function cross(a: { number }, b: { number }): { number }
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

-- The profile's share of the reach, `depth` studs below the top rim: it halves
-- every HALF_DEPTH studs and levels out at UNDERSIDE_SHARE.
local function shareAt(depth: number): number
	return UNDERSIDE_SHARE + (1 - UNDERSIDE_SHARE) * 2 ^ (-depth / HALF_DEPTH)
end

-- The profile's point at `angle` and `depth`.
local function wallAt(angle: number, depth: number): { number }
	local r = R0 * outlineScale(angle) * shareAt(depth)
	return { r * math.cos(angle), r * math.sin(angle), CAP_TOP - depth }
end

-- The outward normal of the profile at `angle` and `depth`, from its tangents.
local function wallNormal(angle: number, depth: number): { number }
	local e = 1e-3
	local along = sub(wallAt(angle + e, depth), wallAt(angle - e, depth))
	local down = sub(wallAt(angle, depth + e), wallAt(angle, depth - e))
	local n = cross(along, down)
	local length = math.sqrt(dot(n, n))
	n = { n[1] / length, n[2] / length, n[3] / length }
	if dot(n, { math.cos(angle), math.sin(angle), 0 }) < 0 then
		n = { -n[1], -n[2], -n[3] }
	end
	return n
end

-- Which way a rock at `p` pushes: out along the wall near the top, turning
-- straight down toward the underside, and straight down under the island.
local function pushAt(p: { number }): { number }
	if p[3] <= RIM_Z + 1e-6 then return { 0, 0, -1 } end
	local angle = math.atan2(p[2], p[1])
	local depth = math.clamp(CAP_TOP - p[3], 0, PROFILE_DEPTH)
	local n = wallNormal(angle, depth)
	local t = math.clamp((depth / PROFILE_DEPTH - DOWN_FROM) / (1 - DOWN_FROM), 0, 1)
	local d = { n[1] * (1 - t), n[2] * (1 - t), n[3] * (1 - t) - t }
	local length = math.max(math.sqrt(dot(d, d)), 1e-6)
	return { d[1] / length, d[2] / length, d[3] / length }
end

-- The seeds: one set over the whole surface, each a 3D point with a weight (the
-- square of its size), so the cells are a power diagram and bigger rocks claim
-- more of the surface.
local seeds = {}
local function addSeed(p: { number }, key: number, scale: number)
	local largest = scale * ROCK / 2 * math.exp(SIZE_SPREAD)
	local size = largest * (MIN_SHARE + (1 - MIN_SHARE) * random(key))
	table.insert(seeds, {
		p = p,
		weight = size * size,
		size = size,
		key = key,
		tint = 0.88 + 0.24 * random(key + 9),
	})
end
do
	-- Down the wall: a jittered grid in angle and depth.
	local cols = math.max(3, math.round(TAU * R0 / ROCK))
	local rows = math.max(1, math.round(PROFILE_DEPTH / ROCK))
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local key = (row * cols + col) * 7 + 1
			local angle = (col + 0.5 * (row % 2) + 0.38 * (2 * random(key + 1) - 1)) / cols * TAU
			local depth = (row + 0.5 + 0.3 * (2 * random(key + 2) - 1)) * PROFILE_DEPTH / rows
			depth = math.clamp(depth, 0.2, PROFILE_DEPTH - 0.2)
			addSeed(wallAt(angle, depth), key + 3, BOTTOM_SIZE + (TOP_SIZE - BOTTOM_SIZE) * (1 - depth / PROFILE_DEPTH) ^ SIZE_CURVE)
		end
	end
	-- Across the underside: a jittered grid in its plane, kept inside the rim.
	local reach = R0 * 1.2
	local n = 0
	for gx = -reach, reach, ROCK * 0.8 do
		for gy = -reach, reach, ROCK * 0.8 do
			n += 1
			local x = gx + 0.35 * ROCK * (2 * random(n * 2 + 11) - 1)
			local y = gy + 0.35 * ROCK * (2 * random(n * 2 + 12) - 1)
			local rim = R0 * outlineScale(math.atan2(y, x)) * shareAt(PROFILE_DEPTH)
			if math.sqrt(x * x + y * y) < 0.9 * rim then
				addSeed({ x, y, RIM_Z }, n * 3 + 17, BOTTOM_SIZE)
			end
		end
	end
	-- The tip is one rock: a single seed on the axis that claims the whole
	-- bottom, with the underside's rocks kept only around its edge.
	local tipSize = TIP_SHARE * R0 * shareAt(PROFILE_DEPTH)
	table.insert(seeds, { p = { 0, 0, RIM_Z }, weight = tipSize * tipSize, size = tipSize, key = 999, tint = 1 })
	for i = #seeds, 1, -1 do
		local seed = seeds[i]
		if seed.key ~= 999 and seed.p[3] <= RIM_Z + 1e-6 and math.sqrt(seed.p[1] ^ 2 + seed.p[2] ^ 2) < TIP_SHARE * R0 * shareAt(PROFILE_DEPTH) then
			table.remove(seeds, i)
		end
	end
end

-- Seams wander: rocks claim the surface in a gently warped copy of it, so the
-- seam between two rocks bends and wobbles instead of running straight. Two
-- octaves of noise sized to the rocks, SEAM_WANDER studs at most.
local SEAM_WANDER = 0.09 * ROCK
local function warp(p: { number }): { number }
	local s = 3 / ROCK
	local w = {}
	for k = 1, 3 do
		local o = k * 17.3
		local broad = math.noise(p[1] * s + o, p[2] * s, p[3] * s)
		local fine = math.noise(p[1] * s * 3, p[2] * s * 3 + o, p[3] * s * 3)
		w[k] = p[k] + SEAM_WANDER * (broad + 0.4 * fine)
	end
	return w
end

-- The rock owning `p`, and how far `p` lies from that rock's nearest seam: the
-- distance to the bisector plane with the runner-up, both in the warped space.
local function ownerAt(point: { number })
	local p = warp(point)
	local best, second = seeds[1], seeds[2]
	local bestPower, secondPower = math.huge, math.huge
	for _, seed in seeds do
		local d = sub(p, seed.p)
		local power = dot(d, d) - seed.weight
		if power < bestPower then
			bestPower, secondPower = power, bestPower
			best, second = seed, best
		elseif power < secondPower then
			secondPower, second = power, seed
		end
	end
	local span = math.max(math.sqrt(dot(sub(second.p, best.p), sub(second.p, best.p))), 1e-6)
	return best, (secondPower - bestPower) / (2 * span)
end

-- How far a rock's surface stands off the island at `p`: a crest over the
-- rock's middle falling to a narrow joint at the seam. The top rim keeps its
-- profile, so the top meets the rocks without a lip.
local function standoff(p: { number }, seed, edge: number): number
	local depth = CAP_TOP - p[3]
	local lower = 1 - (1 - BOTTOM_BULGE) * math.clamp((depth / PROFILE_DEPTH - DOWN_FROM) / (1 - DOWN_FROM), 0, 1)
	local crest = BULGE * math.sqrt(seed.size / (ROCK / 2)) * lower
	local t = math.clamp(edge / (0.5 * seed.size), 0, 1)
	-- Eased in, so the joint's sides curve into the rock instead of kinking.
	local joint = math.clamp(edge / JOINT_WIDTH, 0, 1)
	joint = joint * joint * (3 - 2 * joint)
	local fade = math.clamp(depth / SEAM_FADE, 0, 1)
	-- Every rock stands off by at least REST of its crest, so the seams sit on
	-- the island's body rather than cutting into it.
	local merge = 1 - MERGE_TOP * math.clamp(1 - depth / (PROFILE_DEPTH / 2), 0, 1)
	-- The joint runs deeper and shallower along the seam, 40% to 160% of SEAM_DEPTH.
	local s = 5 / ROCK
	local uneven = 1 + 0.6 * math.noise(p[1] * s + 41, p[2] * s, p[3] * s)
	local h = crest * (REST + (1 - REST) * math.sin(math.pi / 2 * t)) - SEAM_DEPTH * uneven * fade * merge * (1 - joint)
	return h * math.clamp(depth / 1.5, 0, 1)
end

-- Keeps the part of a polygon on the `keep` side of the bisector between two
-- seeds, tested in the warped space. Both rocks on a seam clip the same edges
-- at the same points, so the seam is shared.
local function clipTo(poly: { { number } }, keep, other): { { number } }
	local n = sub(other.p, keep.p)
	local c = (dot(other.p, other.p) - other.weight - dot(keep.p, keep.p) + keep.weight) / 2
	local out = {}
	local count = #poly
	for i = 1, count do
		local a, b = poly[i], poly[i % count + 1]
		local da, db = dot(n, warp(a)) - c, dot(n, warp(b)) - c
		if da <= 0 then table.insert(out, a) end
		if (da < 0 and db > 0) or (da > 0 and db < 0) then
			local t = da / (da - db)
			table.insert(out, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t })
		end
	end
	return out
end

-- Whether the point lies on the top (flat, or the item's shaped top), which
-- paints as even ground with no rock under it.
local function onTop(x: number, y: number, z: number): boolean
	if z > CAP_TOP - 0.01 then return true end
	if not islandTop then return false end
	local radius = math.sqrt(x * x + y * y) / islandTop.octagon(math.atan2(y, x))
	-- Between two rings the top runs straight, so allow for the bend at each.
	return radius < islandTop.radii[1] - 0.1 and math.abs(z - islandTop.height(radius)) < 0.2
end

-- The shell and its shading are cached under a key hashing every line above
-- "-- cached above", so changes below it skip the rebuild.
local shell = model.cached(CACHE_KEY, function()
-- The surface is built once into plain lists: every vertex where it ends up,
-- and the triangles of each rock and of the top. Each rock then becomes a part
-- of its own, so every part's edge is a seam, where the surface folds anyway.
-- Cutting a smooth rock face into chunks would split its smoothing there and
-- show as a sawtooth of light and dark along the cut.
local positions, rockFaces, topFaces = {}, {}, {}
local function newVertex(q: { number }): number
	table.insert(positions, q)
	return #positions
end
do
	-- The surface grid: rows down the wall, then rings in across the underside.
	local ROWS = WALL_ROWS + UNDER_ROWS
	local grid, owners = {}, {}
	for k = 0, ROWS do
		grid[k], owners[k] = {}, {}
		for j = 0, ANGLES - 1 do
			local angle = TAU * j / ANGLES
			local p
			if k <= WALL_ROWS then
				p = wallAt(angle, PROFILE_DEPTH * k / WALL_ROWS)
			else
				local rim = R0 * outlineScale(angle) * shareAt(PROFILE_DEPTH)
				local r = rim * (1 - (k - WALL_ROWS) / UNDER_ROWS)
				p = { r * math.cos(angle), r * math.sin(angle), RIM_Z }
			end
			grid[k][j] = p
			owners[k][j] = (ownerAt(p))
		end
	end

	-- Points are shared by position, so a seam is one set of vertices.
	local indexOf = {}
	local function vertexAt(p: { number }): number
		local key = `{math.round(p[1] * 1e4)}_{math.round(p[2] * 1e4)}_{math.round(p[3] * 1e4)}`
		if not indexOf[key] then
			local seed, edge = ownerAt(p)
			local n = pushAt(p)
			local h = standoff(p, seed, edge)
			indexOf[key] = newVertex({ p[1] + n[1] * h, p[2] + n[2] * h, p[3] + n[3] * h })
		end
		return indexOf[key]
	end

	-- Every vertex sitting on the top rim, for the top.
	local rimVertices = {}

	-- One triangle of the grid: cut into a piece per rock its corners belong to.
	local function emit(a: { number }, b: { number }, c: { number }, oa, ob, oc)
		local u, v = sub(b, a), sub(c, a)
		local face = cross(u, v)
		if dot(face, face) < 1e-12 then return end
		local outward = pushAt({ (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3, (a[3] + b[3] + c[3]) / 3 })
		local present = { oa }
		if ob ~= oa then table.insert(present, ob) end
		if oc ~= oa and oc ~= ob then table.insert(present, oc) end
		for _, owner in present do
			local poly = { a, b, c }
			for _, other in present do
				if other ~= owner then poly = clipTo(poly, owner, other) end
			end
			if #poly < 3 then continue end
			rockFaces[owner] = rockFaces[owner] or {}
			local faces = rockFaces[owner]
			local ids = {}
			for i, p in poly do
				ids[i] = vertexAt(p)
				if math.abs(p[3] - CAP_TOP) < 1e-6 then
					rimVertices[ids[i]] = math.atan2(p[2], p[1]) % TAU
				end
			end
			for i = 2, #poly - 1 do
				local p, q, r = positions[ids[1]], positions[ids[i]], positions[ids[i + 1]]
				local normal = cross(sub(q, p), sub(r, p))
				if dot(normal, outward) >= 0 then
					table.insert(faces, { ids[1], ids[i], ids[i + 1] })
				else
					table.insert(faces, { ids[1], ids[i + 1], ids[i] })
				end
			end
		end
	end

	for k = 0, ROWS - 1 do
		for j = 0, ANGLES - 1 do
			local l = (j + 1) % ANGLES
			emit(grid[k][j], grid[k + 1][j], grid[k + 1][l], owners[k][j], owners[k + 1][j], owners[k + 1][l])
			emit(grid[k][j], grid[k + 1][l], grid[k][l], owners[k][j], owners[k + 1][l], owners[k][l])
		end
	end

	-- The top, wound to face up: every top vertex in order round the rim.
	local function upFace(a: number, b: number, c: number)
		local normal = cross(sub(positions[b], positions[a]), sub(positions[c], positions[a]))
		table.insert(topFaces, if normal[3] >= 0 then { a, b, c } else { a, c, b })
	end
	local outer = {}
	for index, angle in rimVertices do
		table.insert(outer, { index = index, angle = angle })
	end
	table.sort(outer, function(p, q) return p.angle < q.angle end)

	if islandTop then
		-- A shaped top: octagonal rings in from the rim, each at its own
		-- height. The rim's vertices fall wherever the seams cut it, so it is
		-- zipped to the first ring by angle; the rings after share their
		-- angles. A ring never reaches past the rim, so the two can't cross.
		local function ring(radius: number)
			local points = {}
			for j = 0, ANGLES - 1 do
				local angle = TAU * j / ANGLES
				local r = math.min(radius * islandTop.octagon(angle), R0 * outlineScale(angle) - 0.3)
				local index = newVertex({ r * math.cos(angle), r * math.sin(angle), islandTop.height(radius) })
				points[j + 1] = { index = index, angle = angle }
			end
			return points
		end
		local inner = ring(islandTop.radii[1])
		local i, j = 1, 1
		while i <= #outer or j <= #inner do
			local a, b = outer[(i - 1) % #outer + 1], inner[(j - 1) % #inner + 1]
			local nextOuter, nextInner = outer[i % #outer + 1], inner[j % #inner + 1]
			-- Angles past the last vertex wrap round to the first plus a turn.
			local outerAngle = if i < #outer then nextOuter.angle else nextOuter.angle + TAU
			local innerAngle = if j < #inner then nextInner.angle else nextInner.angle + TAU
			if j > #inner or (i <= #outer and outerAngle <= innerAngle) then
				upFace(a.index, nextOuter.index, b.index)
				i += 1
			else
				upFace(a.index, nextInner.index, b.index)
				j += 1
			end
		end
		for n = 2, #islandTop.radii do
			local next = ring(islandTop.radii[n])
			for k = 1, ANGLES do
				local l = k % ANGLES + 1
				upFace(inner[k].index, inner[l].index, next[l].index)
				upFace(inner[k].index, next[l].index, next[k].index)
			end
			inner = next
		end
		outer = inner
	end
	-- The middle: a fan from the axis out to the innermost ring, or to the
	-- rim itself on a flat top.
	local centre = newVertex({ 0, 0, if islandTop then islandTop.height(0) else CAP_TOP })
	for i, p in outer do
		upFace(centre, p.index, outer[i % #outer + 1].index)
	end
end

local function paint(x: number, y: number, z: number)
	if onTop(x, y, z) then return islandPaint(x, y, 0) end
	-- Every other texel takes its rock's seed and tint, and paints as one
	-- material: a single stratum and pebble colour for the whole rock.
	local seed = (ownerAt({ x, y, z }))
	local depth = math.clamp(CAP_TOP - z, 0, PROFILE_DEPTH)
	local spread = TOP_SPREAD + (BOTTOM_SPREAD - TOP_SPREAD) * depth / PROFILE_DEPTH
	return islandPaint(x, y, -depth, seed.key, seed.tint, spread, true)
end

-- Builds a list of faces into a part's mesh, unwarped.
local function facesInto(faces)
	return function(mesh)
		local handles = {}
		for _, face in faces do
			local verts = {}
			for i, v in face do
				if not handles[v] then
					local q = positions[v]
					handles[v] = mesh:vertex(q[1], q[2], q[3])
				end
				verts[i] = handles[v]
			end
			mesh:face(verts)
		end
	end
end
-- A part per rock, sized to it at the layout's texel density. The top is flat
-- or gently curved, so it can be chunked without its cuts showing.
for n, seed in seeds do
	if rockFaces[seed] then
		part(`Rock{n}`, nil, ROCK_COLOUR, facesInto(rockFaces[seed]), 30, paint, nil, nil, true)
	end
end
chunkedPart("Top", nil, ROCK_COLOUR, facesInto(topFaces), 30, paint, true)

-- Stronger highlights along the rock edges, and deeper contact shadows in the
-- seams, than the default: each rock shades against every other rock.
local entries = table.clone(parts)
local meshes = {}
for _, entry in entries do
	table.insert(meshes, entry.mesh)
end
for _, entry in entries do
	entry.mesh:paintShading(entry.image, {
		highlight = 1.2,
		highlightRamp = 0.3,
		shadow = 0.9,
		gradient = GRADIENT,
		blend = 1,
		brushed = true,
		occluders = meshes,
		-- The island paint, cached under the item's key since its code is not hashed.
		paint = entry.paint,
		custom = entry.custom,
		salt = CACHE_KEY,
	})
end
table.clear(parts)
return entries
end)
-- cached above

for _, entry in shell do
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
