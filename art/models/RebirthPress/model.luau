local CACHE_KEY = "RebirthPress-5637efb951b5cdc8"
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
-- Rebirth Press: the hydraulic press in a yard that flattens its scrap pile
-- into a medal (art/concepts/rebirth-press-sketch.png, RebirthPress.plan.luau).
-- 16 x 8 on the ground and 15.2 tall, the origin at the middle of the
-- footprint at ground level, z up, the front (console, medal tray) on the
-- -y side. Riveted dark steel with bronze caps and plate, crisp hazard tape,
-- the yard's scrap heaped on the anvil under the platen.

-- Baked at the yard kit's density (KIT_DENSITY in the ServerMap layout), as it
-- is in game.
useTexelDensity(40)

local PRESS_DARK = { 0.2, 0.21, 0.24 }
local PRESS_STEEL = { 0.42, 0.45, 0.5 }
local COLUMN_STEEL = { 0.28, 0.3, 0.34 }
local HOSE_GREY = { 0.3, 0.31, 0.34 }
local SILVER = { 0.72, 0.74, 0.77 }
local BARE = { 0.68, 0.7, 0.73 }
local BRONZE = { 0.66, 0.46, 0.26 }
local BRASS = { 0.86, 0.68, 0.32 }
local HAZARD = { 0.86, 0.64, 0.16 }
local TAPE_BLACK = { 0.08, 0.08, 0.09 }
local CONCRETE = { 0.62, 0.6, 0.56 }
local RUST = { 0.46, 0.27, 0.16 }
local BUTTON_RED = { 1.0, 0.2, 0.15 }

-- The anvil, ram and platen share one axis; the console sits at the +x end.
local MID_X, MID_Y = -1.5, 0.4
local PLINTH_TOP = 1.2
-- The game centres a yard thing's bounding box on its cells, so nothing
-- reaches past the concrete pad's 16 x 8. The steel bed stands back from the
-- pad's front edge, leaving room for the medal's ramp.
local PLINTH_HALF_X, PLINTH_FRONT, PLINTH_BACK = 7.8, -2.6, 3.8
local ANVIL_TOP = PLINTH_TOP + 1.3
local PLATEN_BASE, PLATEN_TOP = 5.6, 6.5
local COLUMN_X = { -6.2, 3.2 }
local COLUMN_HALF_X, COLUMN_HALF_Y = 1.2, 1.7
local CROWN_BASE, CROWN_TOP = 10.6, 12.8
local CROWN_X0, CROWN_X1 = -7.6, 4.6
local CYL_R, CYL_TOP = 1.6, 15.2
local CONSOLE_X, CONSOLE_Y = 6.3, -1.2

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

-- -------------------------------------------------------------- the bed
part("Plinth", nil, PRESS_DARK, function(mesh)
	-- A concrete pad the size of the press's cells, the steel bed on it.
	box(mesh, 0, 0, 0, 16, 8, 0.3)
	box(mesh, 0, (PLINTH_FRONT + PLINTH_BACK) / 2, 0.3, 2 * PLINTH_HALF_X, PLINTH_BACK - PLINTH_FRONT, PLINTH_TOP - 0.3)
	-- Rivets along each face, under the hazard band.
	for _, y in { PLINTH_FRONT, PLINTH_BACK } do
		rivets(mesh, -7.4, y, 0.6, 7.4, y, 0.6, 8, "y", 0.09)
	end
	for _, x in { -PLINTH_HALF_X, PLINTH_HALF_X } do
		rivets(mesh, x, PLINTH_FRONT + 0.4, 0.6, x, PLINTH_BACK - 0.4, 0.6, 4, "x", 0.09)
	end
end, nil, function(x, y, z)
	if z < 0.32 then
		local k = 0.92 + 0.08 * math.noise(x * 0.8, y * 0.8, 3.1)
		return CONCRETE[1] * k, CONCRETE[2] * k, CONCRETE[3] * k
	end
	-- The hazard band round the top.
	local onEnd = math.abs(x) > PLINTH_HALF_X - 0.1
	local onLong = y < PLINTH_FRONT + 0.1 or y > PLINTH_BACK - 0.1
	if z > PLINTH_TOP - 0.3 and z < PLINTH_TOP + 0.01 and (onEnd or onLong) then
		if tape(if onLong then x else y, z) then
			return TAPE_BLACK[1], TAPE_BLACK[2], TAPE_BLACK[3]
		end
		return HAZARD[1], HAZARD[2], HAZARD[3]
	end
	local k = 0.94 + 0.1 * math.noise(x * 0.5, y * 0.5, z * 2)
	return PRESS_DARK[1] * k, PRESS_DARK[2] * k, PRESS_DARK[3] * k
end, nil, nil, true, 0.25)
crisp()

part("Anvil", nil, BARE, function(mesh)
	box(mesh, MID_X, MID_Y, PLINTH_TOP, 7, 5, ANVIL_TOP - PLINTH_TOP)
	box(mesh, MID_X, MID_Y, PLINTH_TOP, 7.4, 5.4, 0.25)
end, nil, function(x, y, z)
	-- Scarred bare steel, darker in dents on the top, its sides darker so
	-- it reads as a bed block between the plinth and the pile.
	local k = 0.9 + 0.12 * math.noise(x * 1.1, y * 1.1, 4.2)
	if z > ANVIL_TOP - 0.02 and math.noise(x * 2.2, y * 2.2, 1.7) > 0.35 then
		k -= 0.25
	elseif z < ANVIL_TOP - 0.05 then
		k *= 0.72
	end
	return BARE[1] * k, BARE[2] * k, BARE[3] * k
end, nil, nil, nil, 0.2)

-- ------------------------------------------------------------ the frame
part("Columns", nil, COLUMN_STEEL, function(mesh)
	for _, x in COLUMN_X do
		box(mesh, x, MID_Y, PLINTH_TOP, 2 * COLUMN_HALF_X, 2 * COLUMN_HALF_Y, CROWN_BASE - PLINTH_TOP)
		-- Bronze foot plate and cap band.
		box(mesh, x, MID_Y, PLINTH_TOP, 2 * COLUMN_HALF_X + 0.5, 2 * COLUMN_HALF_Y + 0.5, 0.7)
		box(mesh, x, MID_Y, CROWN_BASE - 0.9, 2 * COLUMN_HALF_X + 0.3, 2 * COLUMN_HALF_Y + 0.3, 0.9)
		-- Rivets down each front and back edge, and the side edges.
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				rivets(mesh, x + sx * (COLUMN_HALF_X - 0.3), MID_Y + sy * COLUMN_HALF_Y, 2.4, x + sx * (COLUMN_HALF_X - 0.3), MID_Y + sy * COLUMN_HALF_Y, 9.4, 6, "y", 0.09)
				rivets(mesh, x + sx * COLUMN_HALF_X, MID_Y + sy * (COLUMN_HALF_Y - 0.3), 2.4, x + sx * COLUMN_HALF_X, MID_Y + sy * (COLUMN_HALF_Y - 0.3), 9.4, 6, "x", 0.09)
			end
		end
		-- Foot plate bolts.
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				bolt(mesh, x + sx * (COLUMN_HALF_X + 0.15), MID_Y + sy * (COLUMN_HALF_Y + 0.15), PLINTH_TOP + 0.7, "z", 0.11)
			end
		end
	end
end, nil, function(x, y, z)
	local x0 = if x < -1.5 then COLUMN_X[1] else COLUMN_X[2]
	if z < PLINTH_TOP + 0.72 or (z > CROWN_BASE - 0.92 and (math.abs(x - x0) > COLUMN_HALF_X + 0.05 or math.abs(y - MID_Y) > COLUMN_HALF_Y + 0.05)) then
		local k = 0.9 + 0.12 * math.noise(x * 1.3, y * 1.3, z * 1.3)
		return BRONZE[1] * k, BRONZE[2] * k, BRONZE[3] * k
	end
	-- A step lighter than the plinth and crown, so the frame reads apart.
	local k = 0.94 + 0.1 * math.noise(x * 0.6, z * 0.6, 6.4)
	return COLUMN_STEEL[1] * k, COLUMN_STEEL[2] * k, COLUMN_STEEL[3] * k
end, nil, nil, nil, 0.25)

-- Block letters for the name plate, five wide and seven tall.
local GLYPHS = {
	R = { "1111.", "1...1", "1...1", "1111.", "1.1..", "1..1.", "1...1" },
	E = { "11111", "1....", "1....", "1111.", "1....", "1....", "11111" },
	B = { "1111.", "1...1", "1...1", "1111.", "1...1", "1...1", "1111." },
	I = { "11111", "..1..", "..1..", "..1..", "..1..", "..1..", "11111" },
	T = { "11111", "..1..", "..1..", "..1..", "..1..", "..1..", "..1.." },
	H = { "1...1", "1...1", "1...1", "11111", "1...1", "1...1", "1...1" },
}
local NAME = "REBIRTH"
local PLATE_X0, PLATE_X1, PLATE_Z0, PLATE_Z1 = -4.6, 1.6, 11.1, 12.3
local function nameAt(x: number, z: number): boolean
	local cell = (PLATE_X1 - PLATE_X0 - 0.5) / (#NAME * 6 - 1)
	local u = (x - PLATE_X0 - 0.25) / cell
	local v = (PLATE_Z1 - 0.2 - z) / cell
	local letter = math.floor(u / 6) + 1
	local col, row = math.floor(u % 6) + 1, math.floor(v) + 1
	if letter < 1 or letter > #NAME or col > 5 or row < 1 or row > 7 then
		return false
	end
	local glyph = GLYPHS[NAME:sub(letter, letter)]
	return glyph ~= nil and glyph[row]:sub(col, col) == "1"
end

part("Crown", nil, PRESS_DARK, function(mesh)
	box(mesh, (CROWN_X0 + CROWN_X1) / 2, MID_Y, CROWN_BASE, CROWN_X1 - CROWN_X0, 4, CROWN_TOP - CROWN_BASE)
	-- The bronze name plate on the front, the gauge beside it.
	box(mesh, (PLATE_X0 + PLATE_X1) / 2, MID_Y - 2.05, PLATE_Z0, PLATE_X1 - PLATE_X0, 0.14, PLATE_Z1 - PLATE_Z0)
	for _, x in { PLATE_X0 + 0.2, PLATE_X1 - 0.2 } do
		for _, z in { PLATE_Z0 + 0.2, PLATE_Z1 - 0.2 } do
			bolt(mesh, x, MID_Y - 2.12, z, "y", 0.08)
		end
	end
	cylinder(mesh, 2.9, MID_Y - 2.1, 11.7, 0.7, 0.2, "y", 16)
	ring(mesh, 2.9, MID_Y - 2.18, 11.7, 0.6, 0.78, 0.12, "y", 16)
	-- Rivets along the top and bottom edges, front and back.
	for _, sy in { -1, 1 } do
		rivets(mesh, CROWN_X0 + 0.3, MID_Y + sy * 2, CROWN_BASE + 0.35, CROWN_X1 - 0.3, MID_Y + sy * 2, CROWN_BASE + 0.35, 9, "y", 0.09)
		rivets(mesh, CROWN_X0 + 0.3, MID_Y + sy * 2, CROWN_TOP - 0.35, CROWN_X1 - 0.3, MID_Y + sy * 2, CROWN_TOP - 0.35, 9, "y", 0.09)
	end
end, nil, function(x, y, z)
	if y < MID_Y - 2.02 and x > PLATE_X0 and x < PLATE_X1 and z > PLATE_Z0 and z < PLATE_Z1 then
		if nameAt(x, z) then
			return 0.22, 0.14, 0.07
		end
		local k = 0.95 + 0.1 * math.noise(x * 1.5, z * 1.5, 2.9)
		return BRONZE[1] * k, BRONZE[2] * k, BRONZE[3] * k
	end
	-- The gauge: cream face, a dark needle.
	local gx, gz = x - 2.9, z - 11.7
	local gr = math.sqrt(gx * gx + gz * gz)
	if y < MID_Y - 2.15 and gr < 0.62 then
		local needle = math.abs(gx * 0.8 - gz * 0.6) < 0.05 and gx * 0.6 + gz * 0.8 > -0.1
		if needle or gr > 0.52 then
			return 0.12, 0.1, 0.1
		end
		return 0.92, 0.9, 0.82
	end
	local k = 0.94 + 0.1 * math.noise(x * 0.6, z * 0.6, 7.7)
	return PRESS_DARK[1] * k, PRESS_DARK[2] * k, PRESS_DARK[3] * k
end, nil, nil, true, 0.25)
crisp()

-- ------------------------------------------------------- the hydraulics
part("Cylinder", nil, PRESS_STEEL, function(mesh)
	cylinder(mesh, MID_X, MID_Y, (CROWN_TOP + CYL_TOP - 0.6) / 2, CYL_R, CYL_TOP - 0.6 - CROWN_TOP, "z", 20)
	sphere(mesh, MID_X, MID_Y, CYL_TOP - 0.64, CYL_R, CYL_R, 0.64, 5, 20)
	ring(mesh, MID_X, MID_Y, CROWN_TOP + 0.3, CYL_R + 0.02, CYL_R + 0.3, 0.6, "z", 20)
	ring(mesh, MID_X, MID_Y, CYL_TOP - 0.7, CYL_R - 0.1, CYL_R + 0.25, 0.3, "z", 20)
	for i = 0, 9 do
		local t = i / 10 * TAU
		bolt(mesh, MID_X + math.cos(t) * (CYL_R + 0.08), MID_Y + math.sin(t) * (CYL_R + 0.08), CYL_TOP - 0.55, "z", 0.1)
	end
	-- Hose fittings on the -x side.
	for _, dy in { -0.5, 0.5 } do
		cylinder(mesh, MID_X - CYL_R - 0.2, MID_Y + dy, CYL_TOP - 1.3, 0.22, 0.5, "x", 8)
	end
end, nil, 0.25, nil, nil, nil, 0.2)

part("Ram", nil, BARE, function(mesh)
	cylinder(mesh, MID_X, MID_Y, (PLATEN_TOP + CROWN_BASE) / 2, 0.8, CROWN_BASE - PLATEN_TOP, "z", 16)
	cylinder(mesh, MID_X, MID_Y, CROWN_BASE - 0.35, 1.3, 0.7, "z", 16)
	cylinder(mesh, MID_X, MID_Y, PLATEN_TOP + 0.3, 1.3, 0.6, "z", 16)
end, nil, 0.1, nil, nil, nil, 0.15)

part("Platen", nil, PRESS_DARK, function(mesh)
	box(mesh, MID_X, MID_Y, PLATEN_BASE, 7, 5, PLATEN_TOP - PLATEN_BASE)
	for _, sy in { -1, 1 } do
		rivets(mesh, MID_X - 3, MID_Y + sy * 2.5, PLATEN_TOP - 0.2, MID_X + 3, MID_Y + sy * 2.5, PLATEN_TOP - 0.2, 7, "y", 0.09)
	end
end, nil, function(x, y, z)
	-- The hazard rim round the lower half of the sides.
	if z < PLATEN_BASE + 0.45 and (math.abs(x - MID_X) > 3.45 or math.abs(y - MID_Y) > 2.45) then
		local along = if math.abs(y - MID_Y) > 2.45 then x else y
		if tape(along, z) then
			return TAPE_BLACK[1], TAPE_BLACK[2], TAPE_BLACK[3]
		end
		return HAZARD[1], HAZARD[2], HAZARD[3]
	end
	local k = 0.94 + 0.1 * math.noise(x * 0.7, y * 0.7, 5.5)
	return PRESS_DARK[1] * k, PRESS_DARK[2] * k, PRESS_DARK[3] * k
end, nil, nil, true, 0.2)
crisp()

-- --------------------------------------------------------- the scrap pile
-- Steady pseudo-random number in -1..1 for whole numbers a, b.
local function jitter(a: number, b: number): number
	local s = math.sin(a * 127.1 + b * 311.7) * 43758.5453
	return 2 * (s - math.floor(s)) - 1
end
part("Pile", nil, RUST, function(mesh)
	-- A heap of mounds to a low peak, then junk pressed into its surface.
	local heap = {
		{ 0, 0, 2.4, 1.7, 2.9 },
		{ -1.8, -0.6, 1.8, 1.3, 1.9 },
		{ 1.6, 0.5, 1.7, 1.2, 1.7 },
		{ -0.4, 1.2, 1.6, 1.0, 1.4 },
		{ 0.8, -1.3, 1.5, 1.0, 1.3 },
		{ -2.4, 0.9, 1.2, 0.8, 0.9 },
		{ 2.3, -0.9, 1.2, 0.8, 0.9 },
	}
	-- Each mound's centre sits a little above the anvil, so less of it is
	-- buried; what is buried is hidden in the anvil.
	for _, h in heap do
		sphere(mesh, MID_X + h[1], MID_Y + h[2], ANVIL_TOP + 0.5, h[3], h[4], h[5] - 0.5, 6, 12)
	end
	-- Small pipe ends and crushed cans pressed into the surface; the big
	-- pieces are PileJunk.
	for i = 1, 6 do
		local a = i / 6 * TAU + 0.4
		local r = 1.6 + 0.6 * jitter(i, 1)
		local x, y = MID_X + math.cos(a) * r, MID_Y + math.sin(a) * r * 0.7
		local z = ANVIL_TOP + 0.5 + 0.6 * (1 - r / 2.6) * 2
		cylinder(mesh, x, y, z, 0.26, 0.8, if i % 3 == 0 then "z" elseif i % 3 == 1 then "x" else "y", 10)
	end
end, nil, function(x, y, z)
	-- Rusty steel, bare where the junk sticks out, paint flecks here and there.
	local n = math.noise(x * 1.6, y * 1.6, z * 1.6)
	local k = 0.85 + 0.3 * n
	if n > 0.42 then
		return BARE[1] * 0.8, BARE[2] * 0.8, BARE[3] * 0.8
	end
	local fleck = math.noise(x * 3.1, y * 3.1, z * 3.1 + 9)
	if fleck > 0.52 then
		return 0.2, 0.42, 0.68
	elseif fleck < -0.55 then
		return 0.84, 0.3, 0.2
	end
	return RUST[1] * k, RUST[2] * k, RUST[3] * k
end, nil, nil, nil, 0.2)

-- The big pieces in the heap, each in its own finish: a gear standing in
-- it, a hubcap leaning on the side, a stack of painted cans, a spring.
local GEAR_AT = { MID_X - 1.3, MID_Y - 0.5, ANVIL_TOP + 2.3 }
local HUBCAP_AT = { MID_X + 1.6, MID_Y - 1.7, ANVIL_TOP + 1.5 }
local CANS_AT = { MID_X + 1.1, MID_Y + 1.1 }
local SPRING_AT = { MID_X - 0.6, MID_Y + 1.6 }
part("PileJunk", nil, BRASS, function(mesh)
	gear(mesh, GEAR_AT[1], GEAR_AT[2], GEAR_AT[3], 1.05, 0.26, 12, "x")
	ring(mesh, GEAR_AT[1], GEAR_AT[2], GEAR_AT[3], 0.55, 0.72, 0.3, "x", 16)
	cylinder(mesh, HUBCAP_AT[1], HUBCAP_AT[2], HUBCAP_AT[3], 1.0, 0.18, "y", 16)
	sphere(mesh, HUBCAP_AT[1], HUBCAP_AT[2] - 0.12, HUBCAP_AT[3], 0.4, 0.22, 0.4, 4, 12)
	for _, c in { { -0.45, 0, 0.5 }, { 0.45, 0, 0.5 }, { 0, 0.05, 1.45 } } do
		cylinder(mesh, CANS_AT[1] + c[1], CANS_AT[2] + c[2], ANVIL_TOP + 0.9 + c[3], 0.42, 0.95, "z", 12)
	end
	for i = 0, 4 do
		ring(mesh, SPRING_AT[1], SPRING_AT[2], ANVIL_TOP + 1.3 + i * 0.22, 0.26, 0.4, 0.12, "z", 12)
	end
end, nil, function(x, y, z)
	local function near(ax, ay, az, r)
		return (x - ax) ^ 2 + (y - ay) ^ 2 + (z - az) ^ 2 < r * r
	end
	if near(GEAR_AT[1], GEAR_AT[2], GEAR_AT[3], 1.4) then
		local k = 0.9 + 0.12 * math.noise(y * 2, z * 2, 1.2)
		return BRASS[1] * k, BRASS[2] * k, BRASS[3] * k
	elseif near(HUBCAP_AT[1], HUBCAP_AT[2], HUBCAP_AT[3], 1.3) then
		local k = 0.9 + 0.1 * math.noise(x * 2, z * 2, 2.2)
		return SILVER[1] * k, SILVER[2] * k, SILVER[3] * k
	elseif near(SPRING_AT[1], SPRING_AT[2], ANVIL_TOP + 1.8, 1.0) then
		return PRESS_STEEL[1], PRESS_STEEL[2], PRESS_STEEL[3]
	end
	-- Cans: red, blue and cream, a white label band round the middle.
	local can = if x < CANS_AT[1] - 0.1 and z < ANVIL_TOP + 1.9 then 1 elseif z < ANVIL_TOP + 1.9 then 2 else 3
	local mid = (z - ANVIL_TOP - 0.9) % 0.95
	if mid > 0.3 and mid < 0.62 then
		return 0.92, 0.9, 0.84
	end
	if can == 1 then
		return 0.8, 0.22, 0.16
	elseif can == 2 then
		return 0.2, 0.42, 0.72
	end
	return 0.88, 0.76, 0.4
end, nil, nil, nil, 0.1)

-- ------------------------------------------------------- front and side
-- The medal's way out: a ramp from a dark mouth at the anvil's front edge
-- down to a lip at the pad's front, the medal resting at its foot and leaning
-- back, so its face is toward whoever walks up.
local RAMP_ANGLE = math.rad(52)
local RAMP_COS, RAMP_SIN = math.cos(RAMP_ANGLE), math.sin(RAMP_ANGLE)
local RAMP_FOOT_Y, RAMP_FOOT_Z, RAMP_TOP_Y = -3.6, 0.5, MID_Y - 2.5
local RAMP_TOP_Z = RAMP_FOOT_Z + (RAMP_TOP_Y - RAMP_FOOT_Y) * math.tan(RAMP_ANGLE)
local RAMP_LENGTH = (RAMP_TOP_Y - RAMP_FOOT_Y) / RAMP_COS
local MEDAL_R, MEDAL_BACK = 1.1, 0.13
local MEDAL_UP_RAMP = MEDAL_R + 0.06
local MEDAL_Y = RAMP_FOOT_Y + RAMP_COS * MEDAL_UP_RAMP - RAMP_SIN * (MEDAL_BACK - 0.01)
local MEDAL_Z = RAMP_FOOT_Z + RAMP_SIN * MEDAL_UP_RAMP + RAMP_COS * (MEDAL_BACK - 0.01)

part("Tray", nil, PRESS_STEEL, function(mesh)
	-- The ramp, a wedge across x: (y, z) corners anticlockwise from +x.
	local outline = { { RAMP_FOOT_Y, 0.3 }, { RAMP_TOP_Y, 0.3 }, { RAMP_TOP_Y, RAMP_TOP_Z }, { RAMP_FOOT_Y, RAMP_FOOT_Z } }
	local near, far = {}, {}
	for i, corner in outline do
		near[i] = mesh:vertex(MID_X - 1.5, corner[1], corner[2])
		far[i] = mesh:vertex(MID_X + 1.5, corner[1], corner[2])
	end
	for i = 1, #outline do
		local j = i % #outline + 1
		mesh:face({ near[i], near[j], far[j], far[i] })
	end
	mesh:face({ near[4], near[3], near[2], near[1] })
	mesh:face(far)
	-- The floor at its foot and the lip that stops the medal.
	box(mesh, MID_X, -3.78, 0.29, 2.8, 0.44, 0.2)
	box(mesh, MID_X, -3.91, 0.28, 3.2, 0.14, 0.5)
end, nil, function(x, y, z)
	local along = (y - RAMP_FOOT_Y) * RAMP_COS + (z - RAMP_FOOT_Z) * RAMP_SIN
	local off = (z - RAMP_FOOT_Z) * RAMP_COS - (y - RAMP_FOOT_Y) * RAMP_SIN
	local k = 0.9 + 0.1 * math.noise(x * 1.2, y * 1.2, z * 1.2)
	if math.abs(off) < 0.02 then
		-- The mouth at the top, dark, and the middle worn bright by medals.
		if along > RAMP_LENGTH - 0.5 and math.abs(x - MID_X) < 1.25 then
			return 0.02, 0.02, 0.02
		end
		if math.abs(x - MID_X) < 0.95 then
			k += 0.28
		end
	end
	return PRESS_STEEL[1] * k, PRESS_STEEL[2] * k, PRESS_STEEL[3] * k
end, nil, nil, true, 0.12)
crisp()

part("Medal", nil, BRASS, function(mesh)
	-- Back to front: { radius, height off its middle plane }, a raised rim
	-- and a boss.
	local profile = { { MEDAL_R, -MEDAL_BACK }, { MEDAL_R, 0.08 }, { MEDAL_R - 0.07, 0.15 }, { 0.86, 0.15 }, { 0.8, 0.08 }, { 0.4, 0.08 }, { 0.34, 0.2 } }
	local SIDES = 24
	local rows = {}
	for k, step in profile do
		local row = {}
		for i = 1, SIDES do
			local t = (i - 1) / SIDES * TAU
			local v, d = math.sin(t) * step[1], step[2]
			row[i] = mesh:vertex(MID_X + math.cos(t) * step[1], MEDAL_Y + v * RAMP_COS - d * RAMP_SIN, MEDAL_Z + v * RAMP_SIN + d * RAMP_COS)
		end
		rows[k] = row
	end
	for k = 1, #rows - 1 do
		for i = 1, SIDES do
			local j = i % SIDES + 1
			mesh:face({ rows[k][i], rows[k][j], rows[k + 1][j], rows[k + 1][i] })
		end
	end
	local back = {}
	for i = SIDES, 1, -1 do
		table.insert(back, rows[1][i])
	end
	mesh:face(back)
	mesh:face(rows[#rows])
end, nil, function(x, y, z)
	local up = (y - MEDAL_Y) * RAMP_COS + (z - MEDAL_Z) * RAMP_SIN
	local r = math.sqrt((x - MID_X) ^ 2 + up * up)
	local k = (if r > 0.42 and r < 0.82 then 0.86 else 1.1) + 0.06 * math.noise(x * 3, y * 3, z * 3)
	return math.min(BRASS[1] * k, 1), math.min(BRASS[2] * k, 1), math.min(BRASS[3] * k, 1)
end, nil, nil, true, 0.08)

part("Console", nil, PRESS_DARK, function(mesh)
	box(mesh, CONSOLE_X, CONSOLE_Y, PLINTH_TOP, 2.4, 2.4, 2.8)
	-- The sloped top panel, higher at the back.
	local x0, x1, y0, y1 = CONSOLE_X - 1.25, CONSOLE_X + 1.25, CONSOLE_Y - 1.25, CONSOLE_Y + 1.25
	local z0, z1 = PLINTH_TOP + 2.8, PLINTH_TOP + 3.4
	local a1, a2, a3, a4 = mesh:vertex(x0, y0, z0), mesh:vertex(x1, y0, z0), mesh:vertex(x1, y1, z0), mesh:vertex(x0, y1, z0)
	local b1, b2, b3, b4 = mesh:vertex(x0, y0, z0 + 0.2), mesh:vertex(x1, y0, z0 + 0.2), mesh:vertex(x1, y1, z1), mesh:vertex(x0, y1, z1)
	mesh:face({ a1, a2, b2, b1 })
	mesh:face({ a2, a3, b3, b2 })
	mesh:face({ a3, a4, b4, b3 })
	mesh:face({ a4, a1, b1, b4 })
	mesh:face({ b1, b2, b3, b4 })
	mesh:face({ a4, a3, a2, a1 })
	-- The button's bezel, the cage's hinge posts, a lever, the lamp's stalk.
	cylinder(mesh, CONSOLE_X - 0.3, CONSOLE_Y - 0.2, z0 + 0.45, 0.62, 0.2, "z", 16)
	for _, dx in { -0.95, 0.35 } do
		for _, dy in { -0.9, 0.5 } do
			box(mesh, CONSOLE_X + dx, CONSOLE_Y + dy, z0 + 0.35, 0.14, 0.14, 1.1)
		end
	end
	cylinder(mesh, CONSOLE_X + 0.85, CONSOLE_Y - 0.6, z0 + 0.35, 0.08, 1.2, "z", 6)
	sphere(mesh, CONSOLE_X + 0.85, CONSOLE_Y - 0.6, z0 + 0.95, 0.18, 0.18, 0.18, 4, 8)
	cylinder(mesh, CONSOLE_X + 0.85, CONSOLE_Y + 0.7, z0 + 0.9, 0.06, 1.6, "z", 6)
	-- A small gauge on the front face.
	cylinder(mesh, CONSOLE_X, CONSOLE_Y - 1.26, PLINTH_TOP + 2.1, 0.4, 0.12, "y", 14)
end, nil, function(x, y, z)
	if y < CONSOLE_Y - 1.28 and math.sqrt((x - CONSOLE_X) ^ 2 + (z - PLINTH_TOP - 2.1) ^ 2) < 0.34 then
		return 0.92, 0.9, 0.82
	end
	-- The top panel lighter steel.
	if z > PLINTH_TOP + 2.78 then
		local k = 0.95 + 0.08 * math.noise(x * 2, y * 2, 3.3)
		return PRESS_STEEL[1] * k, PRESS_STEEL[2] * k, PRESS_STEEL[3] * k
	end
	local k = 0.94 + 0.1 * math.noise(x * 0.8, y * 0.8, z * 0.8)
	return PRESS_DARK[1] * k, PRESS_DARK[2] * k, PRESS_DARK[3] * k
end, nil, nil, nil, 0.2)

part("Cage", nil, HAZARD, function(mesh)
	-- A hinged yellow cage over the button: a frame of thin bars.
	local z = PLINTH_TOP + 2.8 + 1.45
	local x0, x1, y0, y1 = CONSOLE_X - 0.95, CONSOLE_X + 0.35, CONSOLE_Y - 0.9, CONSOLE_Y + 0.5
	strut(mesh, x0, y0, z, x1, y0, z, 0.1)
	strut(mesh, x1, y0, z, x1, y1, z, 0.1)
	strut(mesh, x1, y1, z, x0, y1, z, 0.1)
	strut(mesh, x0, y1, z, x0, y0, z, 0.1)
	strut(mesh, x0, (y0 + y1) / 2, z, x1, (y0 + y1) / 2, z, 0.07)
	strut(mesh, (x0 + x1) / 2, y0, z, (x0 + x1) / 2, y1, z, 0.07)
end, nil, 0.1, nil, nil, true, 0.1)

part("Button", nil, BUTTON_RED, function(mesh)
	cylinder(mesh, CONSOLE_X - 0.3, CONSOLE_Y - 0.2, PLINTH_TOP + 2.8 + 0.75, 0.5, 0.4, "z", 16)
	sphere(mesh, CONSOLE_X - 0.3, CONSOLE_Y - 0.2, PLINTH_TOP + 2.8 + 0.92, 0.5, 0.5, 0.21, 4, 16)
	-- The lamp on its stalk.
	sphere(mesh, CONSOLE_X + 0.85, CONSOLE_Y + 0.7, PLINTH_TOP + 2.8 + 1.85, 0.22, 0.22, 0.26, 6, 10)
end, true, 0, nil, 1.2)

-- The hoses run from the cylinder over the crown's back edge and down the
-- back of the -x column to the pump behind it.
local PUMP_X, PUMP_Y = COLUMN_X[1] - 0.65, MID_Y + 2.7
part("Hoses", nil, HOSE_GREY, function(mesh)
	for i, dy in { -0.5, 0.5 } do
		local x = PUMP_X - 0.35 + (i - 1) * 0.7
		tube(mesh, {
			{ MID_X - CYL_R - 0.4, MID_Y + dy, CYL_TOP - 1.3 },
			{ MID_X - CYL_R - 1.0, MID_Y + dy, CYL_TOP - 1.5 },
			{ x, MID_Y + dy, CROWN_TOP + 0.5 },
			{ x, PUMP_Y + 0.3, CROWN_TOP + 0.3 },
			{ x, PUMP_Y + 0.3, PLINTH_TOP + 1.5 },
		}, 0.14, 8)
	end
end, nil, 0.1, nil, nil, nil, 0.1)

part("Pump", nil, PRESS_STEEL, function(mesh)
	box(mesh, PUMP_X, PUMP_Y, PLINTH_TOP, 1.8, 1.3, 1.5)
	sphere(mesh, PUMP_X - 0.35, PUMP_Y - 0.2, PLINTH_TOP + 1.48, 0.55, 0.55, 0.5, 4, 12)
	cylinder(mesh, PUMP_X + 0.5, PUMP_Y - 0.4, PLINTH_TOP + 1.6, 0.16, 0.34, "z", 8)
	-- Collars where the hoses enter the top.
	for _, dx in { -0.35, 0.35 } do
		ring(mesh, PUMP_X + dx, PUMP_Y + 0.3, PLINTH_TOP + 1.5, 0.14, 0.26, 0.3, "z", 10)
	end
end, nil, 0.3, nil, nil, nil, 0.15)

part("Collars", nil, BRASS, function(mesh)
	-- Brass bands on the hoses where they bend, so their route reads.
	for i = 1, 2 do
		local x = PUMP_X - 0.35 + (i - 1) * 0.7
		ring(mesh, x, PUMP_Y + 0.3, CROWN_TOP - 0.2, 0.15, 0.26, 0.4, "z", 10)
		ring(mesh, x, PUMP_Y + 0.3, PLINTH_TOP + 3.5, 0.15, 0.26, 0.4, "z", 10)
		ring(mesh, MID_X - CYL_R - 0.7, MID_Y + (i - 1.5), CYL_TOP - 1.4, 0.15, 0.26, 0.4, "x", 10)
	end
end, nil, 0.1, nil, nil, nil, 0.1)

part("Beacons", nil, { 1, 0.6, 0.15 }, function(mesh)
	for _, x in { CROWN_X0 + 0.5, CROWN_X1 - 0.5 } do
		for _, sy in { -1, 1 } do
			sphere(mesh, x, MID_Y + sy * 1.5, CROWN_TOP + 0.3, 0.3, 0.3, 0.3, 6, 10)
		end
	end
end, true, 0, nil, 1.5)

finishParts()
