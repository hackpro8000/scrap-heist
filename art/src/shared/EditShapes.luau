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
--   EditMesh.roundedBox({sx, sy, sz}, radius, segments)
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
-- quads round each edge.
function EditMesh.roundedBox(size, radius, segments)
	segments = segments or 3
	local function axis(length)
		local h = length / 2
		local r = math.min(radius, h)
		local list = {}
		for k = 0, segments do
			table.insert(list, -h + r * k / segments)
		end
		if h - r > -h + r + 1e-9 then
			table.insert(list, h - r)
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
