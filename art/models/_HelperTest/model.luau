-- Temporary check that rivets, slats and crank build a sane mesh.
local box = function(mesh, cx, cy, cz, sx, sy, sz)
	local v = {}
	for i = 0, 7 do
		local sa = if i % 2 == 0 then -1 else 1
		local sb = if i // 2 % 2 == 0 then -1 else 1
		local sc = if i // 4 == 0 then -1 else 1
		v[i + 1] = mesh:vertex(cx + sa * sx / 2, cy + sb * sy / 2, cz + sc * sz / 2)
	end
	for _, f in { { 1, 3, 4, 2 }, { 5, 6, 8, 7 }, { 1, 2, 6, 5 }, { 3, 7, 8, 4 }, { 1, 5, 7, 3 }, { 2, 4, 8, 6 } } do
		mesh:face({ v[f[1]], v[f[2]], v[f[3]], v[f[4]] })
	end
end
local cylinder = function(mesh, cx, cy, cz, radius, length, axis, sides)
	local a, b = {}, {}
	for k = 0, sides - 1 do
		local t = k / sides * math.pi * 2
		local u, w = math.cos(t) * radius, math.sin(t) * radius
		local x, y, z = if axis == "x" then 0 else u, if axis == "x" then u else w, if axis == "x" then 0 else 0
		local dx, dy, dz = if axis == "x" then -length / 2 else 0, 0, if axis == "x" then 0 else -length / 2
		a[k + 1] = mesh:vertex(cx + x + dx, cy + y, cz + z + dz)
		b[k + 1] = mesh:vertex(cx + x - dx, cy + y, cz + z - dz)
	end
	for k = 1, sides do
		local n = k % sides + 1
		mesh:face({ a[k], a[n], b[n], b[k] })
	end
	mesh:face(a)
	mesh:face(b)
end
local bolt = function(mesh, cx, cy, cz, axis, size)
	cylinder(mesh, cx, cy, cz, size, size * 0.7, axis, 6)
end
local onAxis = function(cx, cy, cz, axis, r, t, d)
	local u, w = math.cos(t) * r, math.sin(t) * r
	if axis == "x" then
		return cx + d, cy + u, cz + w
	end
	return cx + u, cy + w, cz + d
end

local parts = {}
local function add(name, color, build)
	local mesh = Mesh.new()
	build(mesh)
	mesh:setSmooth(true)
	local image = Image.new(128, 128, color[1], color[2], color[3])
	parts[#parts + 1] = { name = name, mesh = mesh, image = image }
end

add("Rivets", { 0.6, 0.6, 0.6 }, function(mesh)
	box(mesh, 0, 0, 0, 2, 0.2, 1)
	for i = 0, 5 do
		local t = i / 5
		bolt(mesh, -1 + 2 * t, -0.1, 0.5, "y", 0.045)
		bolt(mesh, -1 + 2 * t, -0.1, -0.5, "y", 0.045)
	end
end)
add("Slats", { 0.7, 0.5, 0.3 }, function(mesh)
	for i = 0, 4 do
		box(mesh, 0, 0, -0.4 + i * 0.2, 1, 0.1, 0.16)
	end
end)
add("Crank", { 0.5, 0.5, 0.55 }, function(mesh)
	bolt(mesh, 0, 0, 0, "x", 0.08)
	cylinder(mesh, 0.3, 0, 0, 0.08, 0.06, "x", 8)
	cylinder(mesh, 0.3, 0, 0.06, 0.05, 0.12, "x", 8)
	box(mesh, 0.15, 0, 0, 0.25, 0.06, 0.06)
end)
for _, p in parts do
	model.part(p.name, p.mesh, p.image, { preview = true })
end
