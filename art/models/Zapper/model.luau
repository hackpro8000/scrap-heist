-- Zapper: the ranged scrap bot, about 4.5 studs tall. A smooth round rusty
-- body banded and patched with bolted plates, a blue glowing eye in a
-- bolted steel rim, spindly legs with visible hip, knee and ankle joints,
-- and a tesla coil on top that fires bolts from its tip. Faces -Y; stands
-- with its feet on the origin.
-- Rig: Root > Body > Eye, Coil > CoilTip, LegUpperL/R > LegLowerL/R.

-- Mismatched scrap: rusty tank steel, a galvanised band, a brass patch off
-- an old boiler, dark steel legs, copper windings, in sRGB.
local RUST = { 0.55, 0.35, 0.16 }
local GALVANISED = { 0.6, 0.63, 0.62 }
local BRASS = { 0.7, 0.58, 0.3 }
local STEEL = { 0.62, 0.64, 0.66 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local COPPER = { 0.85, 0.5, 0.25 }
local GLOW = { 0.3, 0.8, 1.0 }

local HIP_Z, KNEE_Z = 2.0, 1.0
local HIP_X, FOOT_X = 0.45, 0.75
local BODY_Z, BODY_RADIUS = 2.55, 0.85
local COIL_BOTTOM, COIL_TOP = 3.3, 4.1
local EYE_Z = BODY_Z + 0.1
local TAU = 2 * math.pi

-- Edge highlight and feathering, matching the salvage machine.
local EDGE_HIGHLIGHT = 0.45
local EDGE_BLEND = 0.7
local SMOOTH_ANGLE = 30
local TEXTURE = 256

local function box(mesh, cx, cy, cz, sx, sy, sz)
	local v = {}
	for i = 0, 7 do
		local x = cx + (if i % 2 == 0 then -sx else sx) / 2
		local y = cy + (if i // 2 % 2 == 0 then -sy else sy) / 2
		local z = cz + (if i // 4 == 0 then 0 else sz)
		v[i + 1] = mesh:vertex(x, y, z)
	end
	mesh:face({ v[1], v[3], v[4], v[2] })
	mesh:face({ v[5], v[6], v[8], v[7] })
	mesh:face({ v[1], v[2], v[6], v[5] })
	mesh:face({ v[3], v[7], v[8], v[4] })
	mesh:face({ v[1], v[5], v[7], v[3] })
	mesh:face({ v[2], v[4], v[8], v[6] })
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

-- Weathering, in sRGB: rust patches (dark pitted core, orange rust, pale
-- flaky rim) with drips running down out of them, bright scratches, and
-- grime that darkens toward the ground.
local RUST_DARK = { 0.3, 0.2, 0.12 }
local RUST_ORANGE = { 0.62, 0.36, 0.15 }
local RUST_FLAKE = { 0.78, 0.52, 0.3 }
local BARE_METAL = { 0.74, 0.73, 0.7 }

-- Scratch coverage at a point: 1 in a scratch, -1 in its dark burr, 0 clear.
-- Scratches run in clusters, each cluster in its own direction across the
-- surface, and every line starts and stops on its own so the ends taper.
local function scratchAt(x, y, z, nx, ny, nz)
	if math.noise(x * 1.8 + 20, y * 1.8, z * 1.8) < 0.05 then
		return 0
	end
	-- Surface tangents from the normal.
	local tx, ty, tz = 1, 0, 0
	if math.abs(nz) < 0.9 then
		tx, ty, tz = -ny, nx, 0
	end
	local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
	tx, ty, tz = tx / tl, ty / tl, tz / tl
	local bx, by, bz = ny * tz - nz * ty, nz * tx - nx * tz, nx * ty - ny * tx
	local angle = math.noise(x * 0.9 + 4, y * 0.9, z * 0.9) * math.pi
	local c, s = math.cos(angle), math.sin(angle)
	local along = (x * tx + y * ty + z * tz) * c + (x * bx + y * by + z * bz) * s
	local across = (x * bx + y * by + z * bz) * c - (x * tx + y * ty + z * tz) * s
	local u = across * 9 + math.noise(x * 5, y * 5, z * 5) * 0.4
	local line = math.floor(u)
	local reach = math.noise(along * 2.2, line * 1.37, 9)
	if reach < 0.25 then
		return 0
	end
	local width = 0.07 + (reach - 0.25) * 0.12
	local d = math.abs(u - line - 0.5)
	return if d < width then 1 elseif d < width * 2 then -1 else 0
end

-- Paint fn for `color` worn by `rust` (0 clean, 1 eaten through).
local function weathered(color, rust)
	local edge = 0.75 - rust * 0.6
	return function(x, y, z, nx, ny, nz)
		local grime = math.clamp((1.2 - z) * 0.18, 0, 0.25) + math.noise(x * 3, y * 3, z * 3) * 0.08
		local k = 1 - math.clamp(grime, 0, 0.35)
		local patch = math.noise(x * 2.5 + 7, y * 2.5, z * 2.5) * 0.8 + math.noise(x * 8, y * 8, z * 8 + 5) * 0.3
		local c = color
		if patch > edge + 0.18 then
			local pit = if math.noise(x * 25, y * 25, z * 25) > 0.25 then 0.7 else 1
			c = { RUST_DARK[1] * pit, RUST_DARK[2] * pit, RUST_DARK[3] * pit }
		elseif patch > edge + 0.06 then
			c = RUST_ORANGE
		elseif patch > edge then
			c = RUST_FLAKE
		else
			local above = math.noise(x * 2.5 + 7, y * 2.5, (z + 0.2) * 2.5) * 0.8
			local drip = math.noise(x * 16, y * 16, z * 0.8 + 3)
			if above > edge - 0.05 and drip > 0.3 then
				c = RUST_ORANGE
			else
				local scratch = scratchAt(x, y, z, nx, ny, nz)
				if scratch > 0 then
					c = { (color[1] + BARE_METAL[1] * 2) / 3, (color[2] + BARE_METAL[2] * 2) / 3, (color[3] + BARE_METAL[3] * 2) / 3 }
				elseif scratch < 0 then
					c = { color[1] * 0.8, color[2] * 0.8, color[3] * 0.8 }
				end
			end
		end
		return c[1] * k, c[2] * k, c[3] * k
	end
end

-- Part following one bone. `smooth` overrides the auto-smooth angle (true
-- for fully round parts like the zapper's body). `rust` sets how worn it
-- is, default 0.4; 0 for glowing eyes and visors.
local function part(name, bone, color, build, smooth, rust)
	local mesh = Mesh.new()
	build(mesh)
	mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
	mesh:unwrap()
	local image = Image.new(TEXTURE, TEXTURE, color[1], color[2], color[3])
	rust = rust or 0.4
	if rust > 0 then
		mesh:paint(image, weathered(color, rust))
	end
	mesh:paintShading(image, { highlight = EDGE_HIGHLIGHT, blend = EDGE_BLEND })
	model.part(name, mesh, image, { bone = bone, preview = true })
end

local root = model.bone("Root", { at = { 0, 0, 0 } })
local body = model.bone("Body", { at = { 0, 0, HIP_Z }, parent = root })
local eye = model.bone("Eye", { at = { 0, -BODY_RADIUS, BODY_Z }, parent = body })
local coil = model.bone("Coil", { at = { 0, 0, COIL_BOTTOM }, parent = body })
local coilTip = model.bone("CoilTip", { at = { 0, 0, COIL_TOP + 0.2 }, parent = coil })

part("Body", body, RUST, function(mesh)
	sphere(mesh, 0, 0, BODY_Z, BODY_RADIUS, BODY_RADIUS, BODY_RADIUS * 0.9, 16, 24)
end, true)
part("BodyBand", body, GALVANISED, function(mesh)
	-- Strap round the equator, bolted every eighth of a turn.
	ring(mesh, 0, 0, BODY_Z - 0.15, BODY_RADIUS - 0.08, BODY_RADIUS + 0.03, 0.14, "z", 24)
	for i = 0, 7 do
		local t = (i + 0.5) / 8 * TAU
		local r = BODY_RADIUS + 0.04
		bolt(mesh, math.cos(t) * r, math.sin(t) * r, BODY_Z - 0.15, if math.abs(math.cos(t)) > 0.5 then "x" else "y")
	end
	-- Collar the coil stands on.
	cylinder(mesh, 0, 0, COIL_BOTTOM - 0.1, 0.3, 0.12, "z")
end)
part("BrassPatch", body, BRASS, function(mesh)
	-- A boiler plate bolted over a hole on the back.
	box(mesh, 0.25, BODY_RADIUS - 0.1, BODY_Z - 0.4, 0.5, 0.08, 0.4)
	for _, x in { 0.05, 0.45 } do
		for _, z in { -0.33, -0.07 } do
			bolt(mesh, x, BODY_RADIUS - 0.06, BODY_Z + z, "y", 0.04)
		end
	end
end)
part("EyeRim", body, STEEL, function(mesh)
	ring(mesh, 0, -BODY_RADIUS + 0.04, EYE_Z, 0.24, 0.34, 0.1, "y", 20)
	for i = 0, 5 do
		local t = i / 6 * TAU
		bolt(mesh, math.cos(t) * 0.29, -BODY_RADIUS - 0.02, EYE_Z + math.sin(t) * 0.29, "y", 0.035)
	end
end)
part("Eye", eye, GLOW, function(mesh)
	sphere(mesh, 0, -BODY_RADIUS + 0.05, EYE_Z, 0.25, 0.12, 0.25)
end, true, 0)
part("Coil", coil, COPPER, function(mesh)
	cylinder(mesh, 0, 0, (COIL_BOTTOM + COIL_TOP) / 2 - 0.1, 0.12, COIL_TOP - COIL_BOTTOM + 0.2, "z")
	for i = 0, 3 do
		cylinder(mesh, 0, 0, COIL_BOTTOM + 0.1 + i * 0.2, 0.25 - i * 0.03, 0.06, "z")
	end
end)
part("CoilTip", coilTip, DARK_STEEL, function(mesh)
	sphere(mesh, 0, 0, COIL_TOP + 0.2, 0.2, 0.2, 0.2)
end, true)
for _, side in { { "L", -1 }, { "R", 1 } } do
	local name, s = side[1], side[2]
	local upper = model.bone("LegUpper" .. name, { at = { s * HIP_X, 0, HIP_Z }, parent = body })
	local lower = model.bone("LegLower" .. name, { at = { s * FOOT_X, 0, KNEE_Z }, parent = upper })
	local ankleX = s * FOOT_X * 0.9
	part("LegUpper" .. name, upper, DARK_STEEL, function(mesh)
		strut(mesh, s * HIP_X, 0, HIP_Z, s * FOOT_X, 0, KNEE_Z, 0.12)
		-- Hip: a ball joint in a bracket.
		sphere(mesh, s * HIP_X, 0, HIP_Z, 0.13, 0.13, 0.13)
		box(mesh, s * HIP_X, 0, HIP_Z + 0.05, 0.3, 0.1, 0.12)
	end)
	-- Knee clevis: cheek plates on the upper leg either side of the lower leg's hub,
	-- pinned along X so the shin swings fore and aft without fouling the cheeks.
	part("KneeClevis" .. name, upper, STEEL, function(mesh)
		for _, dx in { -0.11, 0.11 } do
			box(mesh, s * FOOT_X + dx, 0, KNEE_Z - 0.14, 0.04, 0.24, 0.32)
		end
		cylinder(mesh, s * FOOT_X, 0, KNEE_Z, 0.035, 0.32, "x", 6)
	end)
	part("LegJoints" .. name, lower, STEEL, function(mesh)
		cylinder(mesh, s * FOOT_X, 0, KNEE_Z, 0.1, 0.16, "x", 12)
		-- Ankle: hub and pin along X, the same swing as the knee.
		cylinder(mesh, ankleX, 0, 0.18, 0.08, 0.2, "x", 12)
		cylinder(mesh, ankleX, 0, 0.18, 0.03, 0.28, "x", 6)
	end)
	part("LegLower" .. name, lower, DARK_STEEL, function(mesh)
		strut(mesh, s * FOOT_X, 0, KNEE_Z, ankleX, 0, 0.18, 0.1)
		box(mesh, ankleX, -0.1, 0, 0.3, 0.45, 0.1)
		bolt(mesh, ankleX, -0.25, 0.1, "z", 0.04)
	end)
end
