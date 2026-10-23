-- Bruiser: the slow tank scrap bot, about 5 studs tall. A hulking body
-- plated with dumpster lids, a red visor slit, grey shoulder plates and two
-- tank treads. Faces -Y; stands with the treads on the origin.
-- Rig: Root > Treads, Body > ShoulderL, ShoulderR, Visor.
-- Rigged blockout.

local RUST = { 0.55, 0.35, 0.16 }
local DUMPSTER = { 0.25, 0.4, 0.28 }
local GREY = { 0.55, 0.57, 0.6 }
local TREAD = { 0.18, 0.18, 0.2 }
local VISOR = { 0.95, 0.15, 0.1 }

local TREAD_HEIGHT = 0.9
local BODY_TOP = 4.2
local SHOULDER_Z = 3.7
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
local treads = model.bone("Treads", { at = { 0, 0, TREAD_HEIGHT / 2 }, parent = root })
local body = model.bone("Body", { at = { 0, 0, TREAD_HEIGHT }, parent = root })
local shoulderL = model.bone("ShoulderL", { at = { -1.3, 0, SHOULDER_Z }, parent = body })
local shoulderR = model.bone("ShoulderR", { at = { 1.3, 0, SHOULDER_Z }, parent = body })
local visor = model.bone("Visor", { at = { 0, -0.9, 3.6 }, parent = body })

part("Treads", treads, TREAD, function(mesh)
	for _, side in { -1, 1 } do
		box(mesh, side * 1.05, 0, 0, 0.7, 2.6, TREAD_HEIGHT)
		cylinder(mesh, side * 1.05, -1.3, TREAD_HEIGHT / 2, TREAD_HEIGHT / 2, 0.7, "x")
		cylinder(mesh, side * 1.05, 1.3, TREAD_HEIGHT / 2, TREAD_HEIGHT / 2, 0.7, "x")
	end
	box(mesh, 0, 0, 0.3, 1.5, 1.6, 0.5)
end)
part("Body", body, RUST, function(mesh)
	box(mesh, 0, 0, TREAD_HEIGHT - 0.1, 2.2, 1.7, BODY_TOP - TREAD_HEIGHT + 0.1)
end)
part("LidPlates", body, DUMPSTER, function(mesh)
	-- Front lid bolted over the chest, and a lid slung over the top like a cap.
	box(mesh, 0, -0.9, 1.4, 1.9, 0.1, 1.7)
	box(mesh, 0, -0.1, BODY_TOP, 2.4, 2.0, 0.15)
	box(mesh, 0, 0.3, BODY_TOP + 0.15, 2.3, 1.2, 0.5)
end)
part("Visor", visor, VISOR, function(mesh)
	box(mesh, 0, -0.9, 3.55, 1.4, 0.12, 0.18)
end)
part("ShoulderL", shoulderL, GREY, function(mesh)
	box(mesh, -1.45, 0, SHOULDER_Z - 0.4, 0.7, 1.4, 0.9)
end)
part("ShoulderR", shoulderR, GREY, function(mesh)
	box(mesh, 1.45, 0, SHOULDER_Z - 0.4, 0.7, 1.4, 0.9)
end)
