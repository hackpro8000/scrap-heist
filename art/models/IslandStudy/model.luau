local CACHE_KEY = "IslandStudy-628586312a0661ed"
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
-- Island Study: steps 1 to 3 of the island generator.
-- The island is a flat top over a wobbly outline with one shallow bay; the
-- body under it (a cosine wall and a small flat underside) is only a guide the
-- stones are fitted round, kept for the bake but not exported. Over the wall sit fitted rock
-- cells: each one a displaced blob cut by the bisector planes to its
-- neighbours, so the stones meet exactly, then sliced with a few facet
-- planes so they read as cut stone rather than balls. A thick layer of soil
-- is spread over the top and the rim stones' tops.
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
-- Breaking up the rows: the wall is split into sectors round the island, and
-- each sector gets ROCK_ROWS plus up to ROW_SPREAD more rows, so the rows
-- don't line up all the way round.
local ROW_SECTORS, ROW_SPREAD = 5, 1
-- How far a seed may wander in its slot, either way, as a share of the
-- row's height and the slot's width. Small, so no slot is left uncovered.
local HEIGHT_JITTER, ANGLE_JITTER = 0.3, 0.25
-- The odd big stone: the share of top-row slots merged with the nearest
-- second-row slot into one stone over both rows, and its power weight in
-- spacing-squared units, so it claims both slots from its neighbours.
local BIG_STONE_SHARE, BIG_STONE_WEIGHT = 1 / 8, 0.5
-- How many times a cell's blob is split. One is enough: the fitting and the
-- slices do the shaping, and the cells are small on screen.
local ROCK_SUBDIVISIONS = 1
-- The chips: an edge counts as sharp when its two facets' normals agree
-- less than this (0 is a right angle), and the edge and corner cuts go
-- this deep, as a share of the stone's radius.
local CHIP_SHARPNESS = 0.3
local CHIP_EDGE, CHIP_CORNER = 0.05, 0.09
-- The overhanging lip: how far (studs) the top row stands out past where it
-- sat, plus up to LIP_SPREAD more per stone, and how far it is raised so its
-- tops reach the flat-top cut just under the cap.
local LIP_OUT, LIP_SPREAD = 1, 1
local LIP_RISE = 1.2
local ANGLES, STEPS = 128, 28
local TAU = 2 * math.pi
-- Texture detail in pixels per stud. The stones are split into parts by angle
-- so no part's texture needs more than ROCK_TEXTURE at this density.
local TEXEL_DENSITY = 20
local ROCK_TEXTURE = 1024
useTexelDensity(TEXEL_DENSITY)

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

-- The cells: seeds round the wall in rows. Every slot keeps a stone; size
-- variety comes from a power weight instead of dropped slots, because a
-- dropped slot leaves a hole its neighbours may not reach across. The rows
-- are broken up: each sector has its own row count, each seed wanders in its
-- slot, and now and then two slots on the upper rows share one big stone.
local function makeSeed(angle: number, t: number, row: number, key: number)
	local p = wallPoint(angle, t)
	local n = wallNormal(angle, t)
	-- Some seeds sit inside the wall, some just outside, so the cells cut
	-- the surface at angles rather than all from one shell.
	local lift = -1.2 + 2.6 * hash(SEED * 71 + key)
	-- The top row's lip: its seeds move out and up before the fit, so the
	-- stones stand past the cap's edge and the seams still come out exact.
	local lip = if row == 0 then LIP_OUT + LIP_SPREAD * hash(SEED * 61 + key) else 0
	local rise = if row == 0 then LIP_RISE else 0
	return {
		p[1] + n[1] * lift + math.cos(angle) * lip,
		p[2] + n[2] * lift + math.sin(angle) * lip,
		p[3] + n[3] * lift + rise,
		size = 0.85 + 0.3 * hash(SEED * 53 + key),
		t = t,
		row = row,
		angle = angle,
		-- A heavy seed claims more of the wall than a light one. The
		-- weight is in squared-distance units, so it scales with spacing.
		weight = (hash(SEED * 57 + key) - 0.5) * spacing * spacing * 0.55,
	}
end

local seeds = {}
local key = 0
for sector = 0, ROW_SECTORS - 1 do
	local from, to = TAU * sector / ROW_SECTORS, TAU * (sector + 1) / ROW_SECTORS
	local rows = ROCK_ROWS + math.floor(hash(SEED * 83 + sector) * (ROW_SPREAD + 1))
	local band = (0.86 - 0.1) / rows
	local sectorSeeds = {}
	for row = 0, rows - 1 do
		local t = 0.1 + band * (row + 0.5)
		local circumference = TAU * RADIUS * WALL_REACH * shareAt(t)
		local count = math.max(6, math.round(circumference / ROCK_WIDTH))
		local offset = (row % 2) * 0.5
		for col = 0, count - 1 do
			-- Slots are spaced over the whole ring, and each sector keeps the
			-- ones that start inside it, so every slot belongs to one sector.
			local slotAngle = (TAU * (col + offset) / count) % TAU
			if slotAngle >= from and slotAngle < to then
				key += 1
				local angle = slotAngle + (2 * hash(SEED * 87 + key) - 1) * ANGLE_JITTER * TAU / count
				-- The top row keeps its height so the rim stays flush with the cap.
				local drift = if row == 0 then 0 else (2 * hash(SEED * 89 + key) - 1) * HEIGHT_JITTER * band
				table.insert(sectorSeeds, makeSeed(angle, t + drift, row, key))
			end
		end
	end
	-- The big stones: a top-row seed and its nearest second-row seed become
	-- one heavy seed between them, so the pair's two slots are one stone.
	local merged = {}
	for a, top in sectorSeeds do
		if top.row == 0 and hash(SEED * 91 + sector * 31 + a) < BIG_STONE_SHARE then
			local nearest, gap = nil, math.huge
			for b, below in sectorSeeds do
				if below.row == 1 and not merged[b] then
					local d = math.abs((below.angle - top.angle + math.pi) % TAU - math.pi)
					if d < gap then
						nearest, gap = b, d
					end
				end
			end
			if nearest then
				local below = sectorSeeds[nearest]
				merged[nearest] = true
				sectorSeeds[a] = {
					(top[1] + below[1]) / 2,
					(top[2] + below[2]) / 2,
					(top[3] + below[3]) / 2,
					size = math.max(top.size, below.size),
					t = (top.t + below.t) / 2,
					row = 0,
					angle = top.angle,
					weight = BIG_STONE_WEIGHT * spacing * spacing,
				}
			end
		end
	end
	for b, seed in sectorSeeds do
		if not merged[b] then
			table.insert(seeds, seed)
		end
	end
end

local REACH = spacing * 3.2

-- Each stone's blob has to reach past the furthest bisector it can be cut
-- by, or the cell never fills its share and a hole appears. So the radius is
-- worked out per cell from its own neighbours, not from one global constant.
local cellRadius = {}
for i, seed in seeds do
	local farthest = spacing
	for j, other in seeds do
		if j ~= i then
			local dx, dy, dz = other[1] - seed[1], other[2] - seed[2], other[3] - seed[3]
			local distance = dx * dx + dy * dy + dz * dz
			if distance < REACH * REACH and distance > farthest * farthest then
				farthest = math.sqrt(distance)
			end
		end
	end
	cellRadius[i] = farthest * 0.62 * (0.75 + 0.25 * shareAt(seed.t))
end

-- A stone beside one that stands further out must still reach their shared
-- plane all the way out to the neighbour's face, or the seam opens into a
-- notch. So each blob also grows to cover, on every plane that cuts it, the
-- point level with the neighbour's outer face. The blob's surface is about
-- radius * size^2, give or take the wave, so the reach is divided by that.
-- A grown stone is capped at the furthest such face (seamLimit), so it rises
-- to meet its neighbour but never past it.
local SEAM_WAVE, SEAM_CORE = 0.9, 0.7
local seamRadius, seamLimit = {}, {}
for i, seed in seeds do
	local blob = cellRadius[i] * seed.size * seed.size
	local own = wallNormal(seed.angle, seed.t)
	local needed = cellRadius[i]
	for j, other in seeds do
		if j ~= i then
			local dx, dy, dz = other[1] - seed[1], other[2] - seed[2], other[3] - seed[3]
			local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
			if distance < REACH and distance > 1e-6 then
				local n = { dx / distance, dy / distance, dz / distance }
				local seedSq = seed[1] ^ 2 + seed[2] ^ 2 + seed[3] ^ 2
				local otherSq = other[1] ^ 2 + other[2] ^ 2 + other[3] ^ 2
				local offset = (otherSq - seedSq + seed.weight - other.weight) / (2 * distance)
				local out = wallNormal(other.angle, other.t)
				local extent = cellRadius[j] * other.size * other.size
				local face = { other[1] + out[1] * extent, other[2] + out[2] * extent, other[3] + out[3] * extent }
				-- Only a plane that cuts this blob's facet core makes a seam
				-- with it, and only a neighbour standing further out leaves one
				-- open.
				local seam = offset - dot(n, seed) < blob * SEAM_CORE
				if seam and dot(own, face) > dot(own, seed) + blob then
					local past = dot(n, face) - offset
					local onPlane = { face[1] - n[1] * past - seed[1], face[2] - n[2] * past - seed[2], face[3] - n[3] * past - seed[3] }
					local reach = math.sqrt(dot(onPlane, onPlane)) / (seed.size * seed.size * SEAM_WAVE)
					needed = math.max(needed, reach)
					seamLimit[i] = math.max(seamLimit[i] or -math.huge, dot(own, face))
				end
			end
		end
	end
	seamRadius[i] = needed
end
cellRadius = seamRadius

-- The body under the top: the wall and underside the stones were fitted
-- round. It is never exported, only shaded against.
local function buildWall(mesh)
	local rings = {}
	for i = 0, STEPS do
		local t = i / STEPS
		local ring = {}
		for j = 0, ANGLES - 1 do
			local angle = TAU * j / ANGLES
			local p = wallPoint(angle, t)
			ring[j] = mesh:vertex(p[1], p[2], p[3])
		end
		rings[i] = ring
	end
	for i = 0, STEPS - 1 do
		for j = 0, ANGLES - 1 do
			local l = (j + 1) % ANGLES
			local upper, lower = rings[i], rings[i + 1]
			mesh:face({ upper[j], lower[j], lower[l] })
			mesh:face({ upper[j], lower[l], upper[l] })
		end
	end
	local bottom = mesh:vertex(0, 0, RIM_Z)
	for j = 0, ANGLES - 1 do
		mesh:face({ bottom, rings[STEPS][(j + 1) % ANGLES], rings[STEPS][j] })
	end
	mesh:weld(1e-4)
end

-- A triangle lies on a seam plane when all its corners do.
local function onPlane(tri, plane): boolean
	for k = 1, 3 do
		if math.abs(planeDistance(plane, tri[k])) > 1e-5 then
			return false
		end
	end
	return true
end

local function polygonArea(polygon): number
	local total = { 0, 0, 0 }
	for k = 2, #polygon - 1 do
		local a, b, c = polygon[1], polygon[k], polygon[k + 1]
		local n = cross({ b[1] - a[1], b[2] - a[2], b[3] - a[3] }, { c[1] - a[1], c[2] - a[2], c[3] - a[3] })
		total = { total[1] + n[1], total[2] + n[2], total[3] + n[3] }
	end
	return math.sqrt(dot(total, total)) / 2
end

-- Splits a convex polygon by a plane into the part behind it and the part in
-- front, both keeping the polygon's winding.
local function split(polygon, plane)
	local behind, front = {}, {}
	for k, p in polygon do
		local q = polygon[k % #polygon + 1]
		local dp, dq = planeDistance(plane, p), planeDistance(plane, q)
		if dp <= 0 then
			table.insert(behind, p)
		end
		if dp >= 0 then
			table.insert(front, p)
		end
		if (dp < 0 and dq > 0) or (dp > 0 and dq < 0) then
			local t = dp / (dp - dq)
			local point = { p[1] + (q[1] - p[1]) * t, p[2] + (q[2] - p[2]) * t, p[3] + (q[3] - p[3]) * t }
			table.insert(behind, point)
			table.insert(front, point)
		end
	end
	return behind, front
end

-- A neighbour's faces on one seam plane as convex covers: one outline when
-- they make a convex polygon (their hull holds no more than their own area),
-- else the triangles themselves, so a cover never reaches past the face.
local function seamCover(tris, plane)
	if #tris == 0 then
		return {}
	end
	local normal = { plane[1], plane[2], plane[3] }
	local u = cross(normal, { 0, 0, 1 })
	if dot(u, u) < 1e-8 then
		u = cross(normal, { 1, 0, 0 })
	end
	u = normalize(u)
	local v = cross(normal, u)
	local points, area = {}, 0
	for _, tri in tris do
		area += polygonArea(tri)
		for _, p in tri do
			table.insert(points, { p = p, x = dot(p, u), y = dot(p, v) })
		end
	end
	table.sort(points, function(a, b)
		return a.x < b.x or (a.x == b.x and a.y < b.y)
	end)
	local function turn(o, a, b): number
		return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
	end
	-- Andrew's monotone chain: lower then upper hull.
	local hull = {}
	for _, pass in { 1, -1 } do
		local start = #hull
		local from, to = if pass == 1 then 1 else #points, if pass == 1 then #points else 1
		for k = from, to, pass do
			local point = points[k]
			while #hull >= start + 2 and turn(hull[#hull - 1], hull[#hull], point) <= 0 do
				table.remove(hull)
			end
			table.insert(hull, point)
		end
		table.remove(hull)
	end
	local outline = {}
	for _, h in hull do
		table.insert(outline, h.p)
	end
	if #outline >= 3 and polygonArea(outline) <= area + 1e-4 * math.max(area, 1) then
		return { outline }
	end
	return tris
end

-- The parts of a seam triangle its neighbour's covers on the same plane leave
-- uncovered, as convex polygons. Slivers thinner
-- than a hair are dropped as rounding noise.
local SLIVER = 1e-6
local function uncovered(tri, cover, plane)
	local normal = { plane[1], plane[2], plane[3] }
	local pieces = { tri }
	for _, c in cover do
		local remaining = {}
		for _, piece in pieces do
			-- A piece clear of this cover triangle's box keeps whole.
			local clear = false
			for axis = 1, 3 do
				local low, high = math.huge, -math.huge
				for _, p in c do
					low, high = math.min(low, p[axis]), math.max(high, p[axis])
				end
				local pieceLow, pieceHigh = math.huge, -math.huge
				for _, p in piece do
					pieceLow, pieceHigh = math.min(pieceLow, p[axis]), math.max(pieceHigh, p[axis])
				end
				if pieceLow > high or pieceHigh < low then
					clear = true
					break
				end
			end
			if clear then
				table.insert(remaining, piece)
				continue
			end
			local rest = piece
			local centre = { 0, 0, 0 }
			for _, p in c do
				centre = { centre[1] + p[1] / #c, centre[2] + p[2] / #c, centre[3] + p[3] / #c }
			end
			for e = 1, #c do
				local p, q = c[e], c[e % #c + 1]
				local edge = cross({ q[1] - p[1], q[2] - p[2], q[3] - p[3] }, normal)
				local length = math.sqrt(dot(edge, edge))
				if length > 1e-9 then
					edge = { edge[1] / length, edge[2] / length, edge[3] / length }
					if dot(edge, { centre[1] - p[1], centre[2] - p[2], centre[3] - p[3] }) > 0 then
						edge = { -edge[1], -edge[2], -edge[3] }
					end
					local inside, outside = split(rest, { edge[1], edge[2], edge[3], dot(edge, p) })
					if #outside >= 3 and polygonArea(outside) > SLIVER then
						table.insert(remaining, outside)
					end
					rest = inside
					if #rest < 3 then
						break
					end
				end
			end
		end
		pieces = remaining
	end
	return pieces
end

-- Whether a polygon sits wholly inside the body, a hair in from its wall so
-- the body's flat-sided rings still cover it. Corners, edge midpoints and the
-- centre are tested, so a long face can't bow out between them.
local BODY_MARGIN = 0.15
local function insideBody(polygon): boolean
	local function inside(p): boolean
		if p[3] > CAP_TOP - BODY_MARGIN or p[3] < RIM_Z + BODY_MARGIN then
			return false
		end
		local t = (CAP_TOP - p[3]) / DEPTH
		local angle = math.atan2(p[2], p[1])
		local reach = RADIUS * WALL_REACH * shareAt(t) * outlineScale(angle)
		return math.sqrt(p[1] * p[1] + p[2] * p[2]) < reach - BODY_MARGIN
	end
	local centre = { 0, 0, 0 }
	for k, p in polygon do
		local q = polygon[k % #polygon + 1]
		if not inside(p) or not inside({ (p[1] + q[1]) / 2, (p[2] + q[2]) / 2, (p[3] + q[3]) / 2 }) then
			return false
		end
		centre = { centre[1] + p[1], centre[2] + p[2], centre[3] + p[3] }
	end
	return inside({ centre[1] / #polygon, centre[2] / #polygon, centre[3] / #polygon })
end

-- The stones are cut 0.2 under the top, so a thin slit runs round the rim
-- between the top's edge and the stones. Through it, at a grazing angle, the
-- stones' tops under the rim and the far side's inner faces just below them
-- show, so faces reaching this close under the slit stay exported. The
-- stones reach at least 12 studs in under the rim, so a ray through the slit
-- drops under a stud before it crosses the island.
local SLIT_VIEW = 1.5
local function seenThroughRim(polygon): boolean
	for _, p in polygon do
		if p[3] > CAP_TOP - 0.2 - SLIT_VIEW then
			return true
		end
	end
	return false
end

-- The stone faces nobody sees, kept only so the bake still shades with them.
local hiddenRocks = Mesh.new()

local function emitPolygon(target, polygon)
	for k = 2, #polygon - 1 do
		local a, b, c = polygon[1], polygon[k], polygon[k + 1]
		target:face({
			target:vertex(a[1], a[2], a[3]),
			target:vertex(b[1], b[2], b[3]),
			target:vertex(c[1], c[2], c[3]),
		})
	end
end

-- Builds every stone and returns each one's visible faces as polygons, with
-- their area. The faces nobody sees go into hiddenRocks.
local function buildRocks()
	local stones = {}
	for i, seed in seeds do
		-- Stones shrink with the wall, so the bottom rows are chips rather
		-- than full-size boulders crowded round a point.
		local radius = cellRadius[i] * seed.size
		local points = {}
		for v, p in unitVertices do
			local r = (1 + 0.16 * wave(p, 2.3, SEED + i) + 0.05 * wave(p, 4.9, SEED + i + 3.1)) * seed.size
			points[v] = {
				seed[1] + p[1] * r * radius,
				seed[2] + p[2] * r * radius,
				seed[3] + p[3] * r * radius,
			}
		end
		local tris = {}
		for _, f in unitFaces do
			table.insert(tris, { points[f[1]], points[f[2]], points[f[3]] })
		end
		-- The flat spots, cut while the stone is still free-standing.
		local facets = {}
		for k = 1, ROCK_FACETS do
			local angle = hash(SEED * 31 + i * 13 + k * 7.1) * TAU
			local z = 2 * hash(SEED * 17 + i * 13 + k * 3.3) - 1
			local ring = math.sqrt(1 - z * z)
			local n = { ring * math.cos(angle), ring * math.sin(angle), z }
			local reach = 0.68 + 0.27 * hash(SEED * 5 + i * 13 + k * 11.7)
			local facet = { n[1], n[2], n[3], dot(n, seed) + reach * radius }
			table.insert(facets, facet)
			tris = clip(tris, facet)
		end
		-- The chips: a small cut along every sharp edge two facets make, and
		-- on every corner three of them make. Only facet edges are touched, so
		-- the seams cut later stay exact. Each cut is bounded by its facets,
		-- so it can only take a sliver off that edge or corner.
		for a = 1, #facets do
			for b = a + 1, #facets do
				local p, q = facets[a], facets[b]
				if dot(p, q) < CHIP_SHARPNESS then
					local m = { p[1] + q[1], p[2] + q[2], p[3] + q[3] }
					local length = math.sqrt(dot(m, m))
					if length > 0.5 then
						local edge = (p[4] + q[4]) / length
						tris = clip(tris, { m[1] / length, m[2] / length, m[3] / length, edge - CHIP_EDGE * radius })
					end
				end
			end
		end
		for a = 1, #facets do
			for b = a + 1, #facets do
				for c = b + 1, #facets do
					local p, q, r = facets[a], facets[b], facets[c]
					local qr, rp, pq = cross(q, r), cross(r, p), cross(p, q)
					local determinant = dot(p, qr)
					if
						dot(p, q) < CHIP_SHARPNESS
						and dot(q, r) < CHIP_SHARPNESS
						and dot(r, p) < CHIP_SHARPNESS
						and math.abs(determinant) > 1e-3
					then
						local corner = {
							(p[4] * qr[1] + q[4] * rp[1] + r[4] * pq[1]) / determinant,
							(p[4] * qr[2] + q[4] * rp[2] + r[4] * pq[2]) / determinant,
							(p[4] * qr[3] + q[4] * rp[3] + r[4] * pq[3]) / determinant,
						}
						local m = { p[1] + q[1] + r[1], p[2] + q[2] + r[2], p[3] + q[3] + r[3] }
						local length = math.sqrt(dot(m, m))
						if length > 0.5 then
							m = { m[1] / length, m[2] / length, m[3] / length }
							tris = clip(tris, { m[1], m[2], m[3], dot(m, corner) - CHIP_CORNER * radius })
						end
					end
				end
			end
		end
		-- A stone grown to seal a seam stops level with the neighbour it meets.
		if seamLimit[i] then
			local own = wallNormal(seed.angle, seed.t)
			tris = clip(tris, { own[1], own[2], own[3], seamLimit[i] })
		end
		-- Keep the flat top clear.
		tris = clip(tris, { 0, 0, 1, CAP_TOP - 0.2 })
		-- The fit: cut against every nearby seed, so neighbours share planes.
		local seams = {}
		for j, other in seeds do
			if j ~= i then
				local dx, dy, dz = other[1] - seed[1], other[2] - seed[2], other[3] - seed[3]
				local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
				if distance < REACH and distance > 1e-6 then
					local n = { dx / distance, dy / distance, dz / distance }
					-- The power plane: the midpoint shifts by the weight
					-- difference, so a heavy seed pushes it away from itself.
					local seedSq = seed[1] ^ 2 + seed[2] ^ 2 + seed[3] ^ 2
					local otherSq = other[1] ^ 2 + other[2] ^ 2 + other[3] ^ 2
					local offset = (otherSq - seedSq + seed.weight - other.weight) / (2 * distance)
					local plane = { n[1], n[2], n[3], offset }
					tris = clip(tris, plane)
					table.insert(seams, { other = j, plane = plane })
				end
			end
		end
		-- Wind every triangle outward from the seed.
		for k, tri in tris do
			local a, b, c = tri[1], tri[2], tri[3]
			local n = cross({ b[1] - a[1], b[2] - a[2], b[3] - a[3] }, { c[1] - a[1], c[2] - a[2], c[3] - a[3] })
			local mid = { (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3, (a[3] + b[3] + c[3]) / 3 }
			local facing = n[1] * (mid[1] - seed[1]) + n[2] * (mid[2] - seed[2]) + n[3] * (mid[3] - seed[3])
			if facing < 0 then
				tris[k] = { a, c, b }
			end
		end
		stones[i] = { tris = tris, seams = seams }
	end
	-- Only the faces anyone can see are kept. A seam face loses the part its
	-- neighbour's matching face covers, and anything left wholly inside the
	-- body goes too: the stones cover the whole wall, so only the slit under
	-- the rim looks inside. The dropped faces still shade the stones and the
	-- top, through the hidden part.
	-- Each stone's faces sorted by the seam they lie on, keyed by neighbour.
	for _, stone in stones do
		stone.onSeam, stone.seamOf = {}, {}
		for k, tri in stone.tris do
			for _, seam in stone.seams do
				if onPlane(tri, seam.plane) then
					stone.onSeam[seam.other] = stone.onSeam[seam.other] or {}
					table.insert(stone.onSeam[seam.other], tri)
					stone.seamOf[k] = seam
					break
				end
			end
		end
	end
	local visible = {}
	for i, stone in stones do
		visible[i] = { polygons = {}, area = 0 }
		for k, tri in stone.tris do
			local pieces = { tri }
			local seam = stone.seamOf[k]
			if seam then
				local other = stones[seam.other]
				other.covers = other.covers or {}
				other.covers[i] = other.covers[i] or seamCover(other.onSeam[i] or {}, seam.plane)
				pieces = uncovered(tri, other.covers[i], seam.plane)
			end
			-- A face that loses any part keeps its whole self in the hidden
			-- part, so the bake still sees every stone as it was.
			local whole = #pieces == 1 and pieces[1] == tri
			for _, polygon in pieces do
				if insideBody(polygon) and not seenThroughRim(polygon) then
					whole = false
				else
					table.insert(visible[i].polygons, polygon)
					visible[i].area += polygonArea(polygon)
				end
			end
			if not whole then
				emitPolygon(hiddenRocks, tri)
			end
		end
	end
	hiddenRocks:weld(1e-4)
	return visible
end

-- One mesh of the given stones' visible faces, welded so the shading can run
-- smooth over each stone; the crease angle keeps the cuts and seams sharp.
local function stonesMesh(mesh, visible, members)
	for _, i in members do
		for _, polygon in visible[i].polygons do
			emitPolygon(mesh, polygon)
		end
	end
	mesh:weld(1e-4)
end

-- The stones in runs of neighbours round the island, as few runs as fit: runs
-- of about equal area, one more each try, until every run's texture holds it
-- at TEXEL_DENSITY within ROCK_TEXTURE.
local function rockGroups(visible)
	local order, total = {}, 0
	for i in visible do
		table.insert(order, i)
		total += visible[i].area
	end
	table.sort(order, function(a, b)
		return seeds[a].angle % TAU < seeds[b].angle % TAU
	end)
	local function fits(members): boolean
		local mesh = Mesh.new()
		stonesMesh(mesh, visible, members)
		mesh:setSmooth(SMOOTH_ANGLE)
		return math.ceil(TEXEL_DENSITY / mesh:unwrap() / 4) * 4 <= ROCK_TEXTURE
	end
	local count = math.max(1, math.ceil(total * TEXEL_DENSITY ^ 2 / ROCK_TEXTURE ^ 2))
	while true do
		local groups, sum = {}, 0
		for _, i in order do
			local g = math.min(count, math.floor(sum / total * count) + 1)
			groups[g] = groups[g] or {}
			table.insert(groups[g], i)
			sum += visible[i].area
		end
		local ok = true
		for g = 1, count do
			if groups[g] and not fits(groups[g]) then
				ok = false
				break
			end
		end
		if ok then
			return groups
		end
		count += 1
	end
end

-- Each stone's own coat: the rock colour shifted a little per stone, some
-- warmer and browner, some cooler and greyer, up to 8% lighter or darker, flat
-- across the stone so neighbours read apart without any noise.
local STONE_BRIGHTNESS, STONE_WARMTH = 0.08, 1
-- How far the light's colour shifts each channel: warm on tops, cool below.
local SKY_TINT = 0.1
-- Rock patches over the stone faces: faceted cells about SPLOTCH_SIZE studs
-- across (jittered Voronoi), each one a stepped shade up to SPLOTCH_STRENGTH
-- lighter or darker, quantized to SPLOTCH_STEPS levels, so patches meet on
-- straight edges like broken facets. SPLOTCH_GREY pulls a patch's colour
-- toward grey by that share at full strength, so the shift is mostly value.
local SPLOTCH_SIZE = 4.5
local SPLOTCH_STRENGTH = 0.07
local SPLOTCH_STEPS = 5
local SPLOTCH_GREY = 0.35
-- Fine grain: small light and dark flecks GRAIN_SIZE studs across, the ones
-- past GRAIN_FLECK in a fast noise, up to GRAIN_STRENGTH lighter or darker.
local GRAIN_SIZE = 0.22
local GRAIN_FLECK = 0.28
local GRAIN_STRENGTH = 0.05
-- Mineral veins: on VEIN_SHARE of the stones, faint thin light streaks
-- VEIN_WIDTH studs wide, VEIN_SPACING apart, slanted across the stone and
-- broken up along their length, VEIN_STRENGTH lighter at most.
local VEIN_SHARE = 0.35
local VEIN_WIDTH = 0.12
local VEIN_SPACING = 3.5
local VEIN_STRENGTH = 0.08
local stoneNeighbours, stoneColour = {}, {}
for i, seed in seeds do
	stoneNeighbours[i] = {}
	for j, other in seeds do
		local dx, dy, dz = other[1] - seed[1], other[2] - seed[2], other[3] - seed[3]
		if j ~= i and dx * dx + dy * dy + dz * dz < REACH * REACH then
			table.insert(stoneNeighbours[i], j)
		end
	end
end

-- Paints stones in their own colours. A point belongs to the stone whose
-- power cell holds it, since the stones were cut on those planes; the walk
-- starts from the last stone found, so it rarely takes more than one step.
local function stonePaint(base, members)
	for _, i in members do
		local light = 1 + (2 * hash(SEED * 211 + i * 7.3) - 1) * STONE_BRIGHTNESS
		local warmth = (2 * hash(SEED * 223 + i * 5.9) - 1) * STONE_WARMTH
		local r, g, b = base[1], base[2], base[3]
		if warmth > 0 then
			r, g, b = r * (1 + 0.07 * warmth), g * (1 + 0.015 * warmth), b * (1 - 0.1 * warmth)
		else
			local grey = (r + g + b) / 3
			local mix = -warmth * 0.55
			r, g, b = r + (grey - r) * mix, g + (grey - g) * mix, b + (grey * 1.04 - b) * mix
		end
		stoneColour[i] = { r * light, g * light, b * light }
	end
	local last = members[1]
	local function power(i, x, y, z): number
		local s = seeds[i]
		return (x - s[1]) ^ 2 + (y - s[2]) ^ 2 + (z - s[3]) ^ 2 - s.weight
	end
	return rusting(0, function(x, y, z, _nx, _ny, nz)
		local best = power(last, x, y, z)
		while true do
			local step = nil
			for _, j in stoneNeighbours[last] do
				local p = power(j, x, y, z)
				if p < best then
					best, step = p, j
				end
			end
			if not step then
				break
			end
			last = step
		end
		local colour = stoneColour[last] or base
		-- Rock patches: the nearest jittered cell point picks the patch, and its
		-- hash a stepped shade, lighter or darker and greyer the further it goes.
		local cx, cy, cz = math.floor(x / SPLOTCH_SIZE), math.floor(y / SPLOTCH_SIZE), math.floor(z / SPLOTCH_SIZE)
		local nearest, cell = math.huge, 0
		for ix = cx - 1, cx + 1 do
			for iy = cy - 1, cy + 1 do
				for iz = cz - 1, cz + 1 do
					local key = ix * 157.1 + iy * 311.7 + iz * 74.3
					local px = (ix + hash(key + 1.7)) * SPLOTCH_SIZE - x
					local py = (iy + hash(key + 5.3)) * SPLOTCH_SIZE - y
					local pz = (iz + hash(key + 9.1)) * SPLOTCH_SIZE - z
					local d = px * px + py * py + pz * pz
					if d < nearest then
						nearest, cell = d, key
					end
				end
			end
		end
		local step = math.floor(hash(cell + SEED * 13.7) * SPLOTCH_STEPS)
		local shade = (2 * step / (SPLOTCH_STEPS - 1) - 1) * SPLOTCH_STRENGTH
		-- Grain: flecks where a fast noise passes GRAIN_FLECK either way.
		local grain = math.noise(x / GRAIN_SIZE, y / GRAIN_SIZE, z / GRAIN_SIZE + 211)
		local fleck = math.clamp((math.abs(grain) - GRAIN_FLECK) / 0.12, 0, 1)
		shade += (if grain > 0 then fleck else -fleck) * GRAIN_STRENGTH
		-- Veins: bands across a slanted direction per stone, thin and broken up
		-- by a slow noise so only stretches of them show.
		if hash(SEED * 241 + last * 3.1) < VEIN_SHARE then
			local turn = hash(SEED * 251 + last * 4.7) * TAU
			local tilt = 0.5 + 0.4 * hash(SEED * 263 + last * 6.1)
			local along = x * math.cos(turn) * tilt + y * math.sin(turn) * tilt + z * (1 - tilt)
				+ 0.3 * math.noise(x / 1.3, y / 1.3, z / 1.3 + 271)
			local band = math.abs(along / VEIN_SPACING - math.floor(along / VEIN_SPACING + 0.5)) * VEIN_SPACING
			local line = math.clamp(1 - band / VEIN_WIDTH, 0, 1)
			local show = math.clamp(math.noise(x / 2, y / 2, z / 2 + 281) * 3 + 0.3, 0, 1)
			shade += line * show * VEIN_STRENGTH
		end
		local grey = (colour[1] + colour[2] + colour[3]) / 3
		local mix = math.min(math.abs(shade) / SPLOTCH_STRENGTH, 1) * SPLOTCH_GREY
		local light = 1 + shade
		colour = {
			(colour[1] + (grey - colour[1]) * mix) * light,
			(colour[2] + (grey - colour[2]) * mix) * light,
			(colour[3] + (grey - colour[3]) * mix) * light,
		}
		-- Sunlit tops warm toward yellow-orange, undersides cool toward a
		-- blue-purple bounce, the sides blending between.
		local up = math.clamp(nz, -1, 1)
		local warm, cool = math.max(up, 0), math.max(-up, 0)
		local tint = SKY_TINT
		return colour[1] * (1 + tint * (warm - 0.6 * cool)),
			colour[2] * (1 + tint * (0.5 * warm - 0.3 * cool)),
			colour[3] * (1 + tint * (-warm + cool))
	end)
end

-- The soil: a thick layer spread like peanut butter over the flat top and on
-- over the rim stones' tops, ending in a rounded bead that overhangs the
-- stones unevenly with a few drips. It hides the old flat top completely, so
-- it replaces it. Built as one sheet over a polar grid: the top surface out
-- to the bead, round the bead, then a short way back in underneath (the rest
-- of the underside sits inside the stones, so it is left open).
local SOIL_ANGLES, SOIL_RINGS = 192, 24
-- Where the soil rests: just under the stones' cut tops, so no face is shared.
local SOIL_BASE = CAP_TOP - 0.25
-- Thickness above the old flat top's height, and the knife-stroke ridges and lumps.
local SOIL_THICKNESS = 1.15
local SOIL_RIDGE, SOIL_RIDGE_SPACING = 0.17, 5.5
local SOIL_LUMP = 0.14
-- How far the bead's outer edge sits past the stones' top edge, on average,
-- and how far either way it wanders; then the drips.
local SOIL_OVERHANG, SOIL_OVERHANG_SPREAD = 0.9, 2
local SOIL_DRIPS, SOIL_DRIP_WIDTH = 10, 0.09
local SOIL_COLOUR = { 0.34, 0.235, 0.15 }
local BEAD_STEPS = 8
local UNDER_RINGS = { 0.5, 1.2, 2.2, 3.5 }

local soilPhase = {}
for i = 1, 4 do
	soilPhase[i] = hash(SEED * 301 + i) * TAU
end
local drips = {}
for d = 1, SOIL_DRIPS do
	drips[d] = { angle = hash(SEED * 311 + d) * TAU, size = 0.6 + 0.4 * hash(SEED * 313 + d) }
end

-- Thickness at a point: wide gentle strokes whose direction turns slowly over
-- the island, plus soft lumps, kept to 0.8-1.5 studs.
local function soilThickness(x: number, y: number): number
	local turn = 1.4 * math.noise(x / 22, y / 22, 7.3) + soilPhase[1]
	local along = x * math.cos(turn) + y * math.sin(turn) + 1.8 * math.noise(x / 9, y / 9, 3.1)
	local ridge = math.sin(along / SOIL_RIDGE_SPACING * TAU)
	local lump = math.noise(x / 4.5, y / 4.5, 11.7)
	return math.clamp(SOIL_THICKNESS + SOIL_RIDGE * ridge + SOIL_LUMP * lump, 0.8, 1.5)
end

-- The stones' top edge per angle: the furthest point of their cut tops, with
-- the gaps between stones bridged and smoothed so the soil follows them loosely.
local function stoneTopEdge(visible)
	local edge = {}
	for _, stone in visible do
		for _, polygon in stone.polygons do
			for _, p in polygon do
				if p[3] > CAP_TOP - 0.25 then
					local j = math.floor((math.atan2(p[2], p[1]) % TAU) / TAU * SOIL_ANGLES + 0.5) % SOIL_ANGLES
					local r = math.sqrt(p[1] * p[1] + p[2] * p[2])
					edge[j] = math.max(edge[j] or 0, r)
				end
			end
		end
	end
	local widened = {}
	for j = 0, SOIL_ANGLES - 1 do
		local best = 0
		for k = -3, 3 do
			best = math.max(best, edge[(j + k) % SOIL_ANGLES] or 0)
		end
		if best == 0 then
			local p = wallPoint(TAU * j / SOIL_ANGLES, 0)
			best = math.sqrt(p[1] * p[1] + p[2] * p[2]) + 1
		end
		widened[j] = best
	end
	local smooth = {}
	for j = 0, SOIL_ANGLES - 1 do
		local sum = 0
		for k = -4, 4 do
			sum += widened[(j + k) % SOIL_ANGLES]
		end
		smooth[j] = sum / 9
	end
	return smooth
end

local function buildSoil(mesh, visible)
	local stoneEdge = stoneTopEdge(visible)
	local columns = {}
	for j = 0, SOIL_ANGLES - 1 do
		local angle = TAU * j / SOIL_ANGLES
		local c, s = math.cos(angle), math.sin(angle)
		local wander = 0.5 * math.sin(3 * angle + soilPhase[2]) + 0.3 * math.sin(7 * angle + soilPhase[3])
			+ 0.2 * math.sin(13 * angle + soilPhase[4])
		local over = SOIL_OVERHANG + SOIL_OVERHANG_SPREAD * wander
		local drip = 0
		for _, d in drips do
			local gap = (angle - d.angle + math.pi) % TAU - math.pi
			drip = math.max(drip, d.size * math.exp(-((gap / SOIL_DRIP_WIDTH) ^ 2)))
		end
		over += 0.8 * drip
		local outer = stoneEdge[j] + over
		-- The bead hangs lower where it is past the stones, and lowest at a drip.
		local droop = 1 * math.clamp(over / 2.5, 0, 1) + 1.6 * drip
		local bottom = SOIL_BASE - droop
		-- The bead: its top meets the surface level, its round runs out to `outer`.
		local probe = outer - 1
		local top = SOIL_BASE + 0.25 + soilThickness(probe * c, probe * s)
		local half = (top - bottom) / 2
		local width = half * (0.85 + 0.25 * hash(SEED * 331 + j))
		local centre = outer - width
		local column = {}
		for k = 1, SOIL_RINGS do
			local r = centre * k / SOIL_RINGS
			local x, y = r * c, r * s
			local z = SOIL_BASE + 0.25 + soilThickness(x, y)
			-- Ease the last stretch onto the bead's top so the surface runs on smooth.
			local blend = math.clamp((k / SOIL_RINGS - 0.85) / 0.15, 0, 1)
			z += (top - z) * blend * blend
			table.insert(column, mesh:vertex(x, y, z))
		end
		local middle = (top + bottom) / 2
		for step = 1, BEAD_STEPS do
			local phi = math.pi * step / BEAD_STEPS
			local r = centre + width * math.sin(phi)
			table.insert(column, mesh:vertex(r * c, r * s, middle + half * math.cos(phi)))
		end
		for _, inward in UNDER_RINGS do
			local r = centre - inward
			local z = SOIL_BASE - droop * math.exp(-((inward / 1.2) ^ 2))
			table.insert(column, mesh:vertex(r * c, r * s, z))
		end
		columns[j] = column
	end
	local middle = mesh:vertex(0, 0, SOIL_BASE + 0.25 + soilThickness(0, 0))
	for j = 0, SOIL_ANGLES - 1 do
		local a, b = columns[j], columns[(j + 1) % SOIL_ANGLES]
		mesh:face({ middle, a[1], b[1] })
		for k = 1, #a - 1 do
			mesh:face({ a[k], a[k + 1], b[k + 1] })
			mesh:face({ a[k], b[k + 1], b[k] })
		end
	end
end

-- The soil's coat: the brown shifted in soft wide patches and fine grain,
-- warmed on top and cooled below like the stones.
local soilPaint = rusting(0, function(x, y, z, _nx, _ny, nz)
	local patch = math.noise(x / 6, y / 6, z / 6 + 401)
	local grain = math.noise(x / 0.3, y / 0.3, z / 0.3 + 409)
	local light = 1 + 0.06 * patch + 0.035 * grain
	local up = math.clamp(nz, -1, 1)
	local warm, cool = math.max(up, 0), math.max(-up, 0)
	return SOIL_COLOUR[1] * light * (1 + SKY_TINT * (warm - 0.6 * cool)),
		SOIL_COLOUR[2] * light * (1 + SKY_TINT * (0.5 * warm - 0.3 * cool)),
		SOIL_COLOUR[3] * light * (1 + SKY_TINT * (-warm + cool))
end)

-- The parts and their shading are cached under a key hashing every line above
-- "-- cached above", so an unchanged rebuild loads them instead of baking.
-- finishParts() adds parts straight to the model, so model.part is swapped
-- for a collector while it runs and the collected list is what gets cached.
local baked = model.cached(CACHE_KEY, function()
	-- The top and the stones shade against the body's island-wide height
	-- range, so the gradient runs on across every part instead of restarting
	-- in each.
	local islandRange = { RIM_Z, CAP_TOP }
	-- The stones go in a few parts of neighbouring stones, all in one group, so
	-- they shade each other as one surface.
	local visible = buildRocks()
	-- The soil replaces the flat top, which it hides completely. Fully smooth,
	-- with the stones' bold painted highlights.
	chunkedPart("Soil", nil, SOIL_COLOUR, function(mesh)
		buildSoil(mesh, visible)
	end, true, soilPaint, true, 1, nil, nil, islandRange)
	for _, entry in parts do
		if entry.group == "Soil" then
			entry.wide = 4
			entry.painted = true
			entry.blend = 1
		end
	end
	for g, members in rockGroups(visible) do
		-- Flat, since a paint fn would otherwise bring back the warp rust 0 skips.
		local rock = { 0.37, 0.34, 0.29 }
		part(`Rocks_{g}`, nil, rock, function(mesh)
			stonesMesh(mesh, visible, members)
		end, nil, stonePaint(rock, members), nil, nil, true)
		parts[#parts].group = "Rocks"
		parts[#parts].heightRange = islandRange
		parts[#parts].wide = 4
		parts[#parts].edge = 1
		parts[#parts].painted = true
		parts[#parts].blend = 1
	end
	-- The hidden faces join the rocks' group, so the stones still shade with
	-- them as their own surfaces and the body still takes their shadows. Marked
	-- emissive, finishParts skips baking them, and they are left out below.
	table.insert(parts, { name = "HiddenRocks", mesh = hiddenRocks, emissive = 1, group = "Rocks" })
	-- The body's wall stays for the bake the same way, in the top's group as
	-- it was when they were one part, so the stones still take its shadows.
	local wall = Mesh.new()
	buildWall(wall)
	table.insert(parts, { name = "BodyWall", mesh = wall, emissive = 1, group = "Top" })
	local addPart, collected = model.part, {}
	model.part = function(name, mesh, image, options)
		if name == "HiddenRocks" or name == "BodyWall" then
			return
		end
		table.insert(collected, { name = name, mesh = mesh, image = image, preview = options.preview, emissive = options.emissive })
	end
	finishParts()
	model.part = addPart
	table.clear(parts)
	return collected
end)
-- cached above

for _, entry in baked do
	model.part(entry.name, entry.mesh, entry.image, { preview = entry.preview, emissive = entry.emissive })
end
