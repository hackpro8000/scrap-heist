-- Zapper: the ranged scrap bot, about 4.5 studs tall. A round rusty body on
-- spindly legs, a blue glowing eye and a tesla coil on top that fires bolts
-- from its tip. Faces -Y; stands with its feet on the origin.
-- Rig: Root > Body > Eye, Coil > CoilTip, LegUpperL/R > LegLowerL/R.
-- Rigged blockout.

local RUST = { 0.55, 0.35, 0.16 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local COPPER = { 0.85, 0.5, 0.25 }
local GLOW = { 0.3, 0.8, 1.0 }

local HIP_Z, KNEE_Z = 2.0, 1.0
local HIP_X, FOOT_X = 0.45, 0.75
local BODY_Z, BODY_RADIUS = 2.55, 0.85
local COIL_BOTTOM, COIL_TOP = 3.3, 4.1
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
local function sphere(mesh, cx, cy, cz, rx, ry, rz)
	local rings, sides = 8, 16
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

-- Flat-coloured blockout part following one bone.
local function part(name, bone, color, build)
	local mesh = Mesh.new()
	build(mesh)
	mesh:setSmooth(SMOOTH_ANGLE)
	mesh:unwrap()
	local image = Image.new(TEXTURE, TEXTURE, color[1], color[2], color[3])
	mesh:paintShading(image, { highlight = EDGE_HIGHLIGHT, blend = EDGE_BLEND })
	model.part(name, mesh, image, { bone = bone, preview = true })
end

local root = model.bone("Root", { at = { 0, 0, 0 } })
local body = model.bone("Body", { at = { 0, 0, HIP_Z }, parent = root })
local eye = model.bone("Eye", { at = { 0, -BODY_RADIUS, BODY_Z }, parent = body })
local coil = model.bone("Coil", { at = { 0, 0, COIL_BOTTOM }, parent = body })
local coilTip = model.bone("CoilTip", { at = { 0, 0, COIL_TOP + 0.2 }, parent = coil })

part("Body", body, RUST, function(mesh)
	sphere(mesh, 0, 0, BODY_Z, BODY_RADIUS, BODY_RADIUS, BODY_RADIUS * 0.9)
end)
part("Eye", eye, GLOW, function(mesh)
	sphere(mesh, 0, -BODY_RADIUS + 0.05, BODY_Z + 0.1, 0.25, 0.12, 0.25)
end)
part("Coil", coil, COPPER, function(mesh)
	cylinder(mesh, 0, 0, (COIL_BOTTOM + COIL_TOP) / 2 - 0.1, 0.12, COIL_TOP - COIL_BOTTOM + 0.2, "z")
	for i = 0, 3 do
		cylinder(mesh, 0, 0, COIL_BOTTOM + 0.1 + i * 0.2, 0.25 - i * 0.03, 0.06, "z")
	end
end)
part("CoilTip", coilTip, DARK_STEEL, function(mesh)
	sphere(mesh, 0, 0, COIL_TOP + 0.2, 0.2, 0.2, 0.2)
end)
for _, side in { { "L", -1 }, { "R", 1 } } do
	local name, s = side[1], side[2]
	local upper = model.bone("LegUpper" .. name, { at = { s * HIP_X, 0, HIP_Z }, parent = body })
	local lower = model.bone("LegLower" .. name, { at = { s * FOOT_X, 0, KNEE_Z }, parent = upper })
	part("LegUpper" .. name, upper, DARK_STEEL, function(mesh)
		strut(mesh, s * HIP_X, 0, HIP_Z, s * FOOT_X, 0, KNEE_Z, 0.12)
	end)
	part("LegLower" .. name, lower, DARK_STEEL, function(mesh)
		strut(mesh, s * FOOT_X, 0, KNEE_Z, s * FOOT_X * 0.9, 0, 0.1, 0.1)
		box(mesh, s * FOOT_X * 0.9, -0.1, 0, 0.3, 0.45, 0.1)
	end)
end
