-- Bruiser: the slow tank scrap bot, about 5 studs tall. A hulking rusty body
-- plated with dumpster lids (ribbed, hinged, with grab handles), a red visor
-- slit in a steel frame, bolted shoulder plates and two lugged tank treads.
-- Faces -Y; stands with the treads on the origin.
-- Rig: Root > Treads, Body > ShoulderL, ShoulderR, Visor.

-- Mismatched scrap: rusty body steel, green dumpster lids, a galvanised
-- patch, a cream panel off an old fridge, dark steel running gear, in sRGB.
local RUST = { 0.55, 0.35, 0.16 }
local DUMPSTER = { 0.25, 0.4, 0.28 }
local GALVANISED = { 0.6, 0.63, 0.62 }
local FRIDGE = { 0.82, 0.78, 0.66 }
local GREY = { 0.55, 0.57, 0.6 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local TREAD = { 0.18, 0.18, 0.2 }
local VISOR = { 0.95, 0.15, 0.1 }

local TREAD_HEIGHT = 0.9
local TREAD_X, TREAD_WIDTH, TREAD_LENGTH = 1.05, 0.7, 2.6
local BODY_TOP = 4.2
local BODY_FRONT = -0.85
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

-- Part following one bone. `smooth` overrides the auto-smooth angle (true
-- for fully round parts like the zapper's body).
local function part(name, bone, color, build, smooth)
	local mesh = Mesh.new()
	build(mesh)
	mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
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
	local radius = TREAD_HEIGHT / 2
	for _, side in { -1, 1 } do
		local x = side * TREAD_X
		box(mesh, x, 0, 0, TREAD_WIDTH, TREAD_LENGTH, TREAD_HEIGHT)
		cylinder(mesh, x, -TREAD_LENGTH / 2, radius, radius, TREAD_WIDTH, "x")
		cylinder(mesh, x, TREAD_LENGTH / 2, radius, radius, TREAD_WIDTH, "x")
		-- Grip lugs across the top and bottom runs.
		for i = 0, 6 do
			local y = -1.2 + i * 0.4
			box(mesh, x, y, TREAD_HEIGHT, TREAD_WIDTH + 0.04, 0.12, 0.06)
			box(mesh, x, y, -0.06, TREAD_WIDTH + 0.04, 0.12, 0.06)
		end
	end
	box(mesh, 0, 0, 0.3, 1.5, 1.6, 0.5)
end)
part("RoadWheels", treads, DARK_STEEL, function(mesh)
	local radius = TREAD_HEIGHT / 2
	for _, side in { -1, 1 } do
		local x = side * (TREAD_X + TREAD_WIDTH / 2 + 0.03)
		-- Drive sprockets at the ends, small road wheels between.
		for _, y in { -TREAD_LENGTH / 2, TREAD_LENGTH / 2 } do
			ring(mesh, x, y, radius, 0.12, radius - 0.06, 0.06, "x")
			cylinder(mesh, x + side * 0.03, y, radius, 0.1, 0.1, "x", 8)
		end
		for _, y in { -0.65, 0, 0.65 } do
			cylinder(mesh, x, y, radius, 0.24, 0.06, "x")
			bolt(mesh, x + side * 0.04, y, radius, "x", 0.06)
		end
	end
end)
part("Body", body, RUST, function(mesh)
	box(mesh, 0, 0, TREAD_HEIGHT - 0.1, 2.2, 1.7, BODY_TOP - TREAD_HEIGHT + 0.1)
	-- Welded seam strips around the waist.
	box(mesh, 0, 0, 2.0, 2.26, 1.76, 0.08)
end)
part("ScrapPatches", body, GALVANISED, function(mesh)
	-- Galvanised sheet riveted over the left side, and a back plate.
	box(mesh, -1.12, 0.1, 1.6, 0.05, 1.1, 1.3)
	for _, y in { -0.38, 0.58 } do
		for _, z in { 1.7, 2.8 } do
			bolt(mesh, -1.15, y, z, "x")
		end
	end
	box(mesh, 0.3, 0.87, 2.3, 1.2, 0.05, 1.0)
	for _, x in { -0.22, 0.82 } do
		for _, z in { 2.4, 3.2 } do
			bolt(mesh, x, 0.9, z, "y")
		end
	end
end)
part("FridgePanel", body, FRIDGE, function(mesh)
	-- A dented fridge door bolted on the right side, handle and all.
	box(mesh, 1.12, -0.05, 1.3, 0.05, 1.2, 1.5)
	box(mesh, 1.16, -0.55, 1.9, 0.04, 0.08, 0.5)
	for _, y in { -0.55, 0.45 } do
		for _, z in { 1.4, 2.7 } do
			bolt(mesh, 1.15, y, z, "x")
		end
	end
end)
part("LidPlates", body, DUMPSTER, function(mesh)
	-- Front lid bolted over the chest, ribbed like the real thing.
	box(mesh, 0, BODY_FRONT - 0.05, 1.4, 1.9, 0.1, 1.7)
	for i = 0, 3 do
		box(mesh, 0, BODY_FRONT - 0.13, 1.6 + i * 0.4, 1.8, 0.06, 0.08)
	end
	-- Top lid slung over like a cap, with a raised hump and ribs.
	box(mesh, 0, -0.1, BODY_TOP, 2.4, 2.0, 0.15)
	box(mesh, 0, 0.3, BODY_TOP + 0.15, 2.3, 1.2, 0.5)
	for _, x in { -0.7, 0, 0.7 } do
		box(mesh, x, 0.3, BODY_TOP + 0.65, 0.1, 1.1, 0.05)
	end
end)
part("LidHardware", body, DARK_STEEL, function(mesh)
	-- Hinges along the top lid's back edge and the front lid's top edge.
	for _, x in { -0.8, 0.8 } do
		cylinder(mesh, x, 0.9, BODY_TOP + 0.1, 0.07, 0.4, "x", 8)
		box(mesh, x, 0.75, BODY_TOP + 0.15, 0.36, 0.3, 0.04)
		box(mesh, x, 0.94, BODY_TOP - 0.35, 0.36, 0.04, 0.4)
		cylinder(mesh, x, BODY_FRONT - 0.12, 3.12, 0.06, 0.35, "x", 8)
	end
	-- Grab handles: on the front lid, and along the top lid's front lip.
	strut(mesh, -0.4, BODY_FRONT - 0.12, 1.75, -0.4, BODY_FRONT - 0.3, 1.75, 0.06)
	strut(mesh, 0.4, BODY_FRONT - 0.12, 1.75, 0.4, BODY_FRONT - 0.3, 1.75, 0.06)
	strut(mesh, -0.43, BODY_FRONT - 0.3, 1.75, 0.43, BODY_FRONT - 0.3, 1.75, 0.06)
	strut(mesh, -0.5, -1.1, BODY_TOP + 0.07, -0.5, -1.25, BODY_TOP - 0.05, 0.05)
	strut(mesh, 0.5, -1.1, BODY_TOP + 0.07, 0.5, -1.25, BODY_TOP - 0.05, 0.05)
	strut(mesh, -0.53, -1.25, BODY_TOP - 0.05, 0.53, -1.25, BODY_TOP - 0.05, 0.05)
	-- Corner bolts holding the front lid on.
	for _, x in { -0.85, 0.85 } do
		for _, z in { 1.5, 3.0 } do
			bolt(mesh, x, BODY_FRONT - 0.12, z, "y", 0.06)
		end
	end
end)
part("VisorFrame", body, GREY, function(mesh)
	local y = BODY_FRONT - 0.08
	box(mesh, 0, y, 3.4, 1.7, 0.14, 0.08)
	box(mesh, 0, y, 3.72, 1.7, 0.14, 0.08)
	box(mesh, -0.81, y, 3.4, 0.08, 0.14, 0.4)
	box(mesh, 0.81, y, 3.4, 0.08, 0.14, 0.4)
	for _, x in { -0.75, 0.75 } do
		bolt(mesh, x, y - 0.08, 3.44, "y", 0.035)
		bolt(mesh, x, y - 0.08, 3.76, "y", 0.035)
	end
end)
part("Visor", visor, VISOR, function(mesh)
	box(mesh, 0, BODY_FRONT - 0.05, 3.48, 1.54, 0.1, 0.24)
end, true)
for _, side in { { "L", shoulderL, -1 }, { "R", shoulderR, 1 } } do
	local name, bone, s = side[1], side[2], side[3]
	part("Shoulder" .. name, bone, GREY, function(mesh)
		local x = s * 1.45
		box(mesh, x, 0, SHOULDER_Z - 0.4, 0.7, 1.4, 0.9)
		-- A thinner armour plate overlapping the top, bolted down.
		box(mesh, x + s * 0.05, 0, SHOULDER_Z + 0.5, 0.75, 1.45, 0.08)
		for _, y in { -0.55, 0, 0.55 } do
			bolt(mesh, x + s * 0.25, y, SHOULDER_Z + 0.6, "z")
			bolt(mesh, x + s * 0.36, y, SHOULDER_Z, "x")
		end
	end)
end
