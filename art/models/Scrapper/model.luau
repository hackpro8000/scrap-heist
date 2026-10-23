-- Scrapper: the fast, weak scrap bot, about 2.5 studs tall. A rusty box body
-- patched with odd plates, carried on a swing arm over one wobbly wheel. A
-- red eye in a steel rim, a buzzsaw on a side arm and a bent antenna
-- topped with a little radar dish. Faces -Y; stands with the wheel on the
-- origin.
-- Rig: Root > Body > Suspension > Wheel (spins), SawArm > Saw (spins),
-- Antenna (wobbles).

-- Mismatched scrap: rusty box steel, a galvanised panel, a sky-blue panel
-- off an old appliance, dark steel running gear, a bright saw, in sRGB.
local RUST = { 0.55, 0.35, 0.16 }
local GALVANISED = { 0.6, 0.63, 0.62 }
local APPLIANCE = { 0.36, 0.55, 0.66 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local STEEL = { 0.62, 0.64, 0.66 }
local TYRE = { 0.16, 0.16, 0.17 }
local EYE = { 0.95, 0.15, 0.1 }

local WHEEL_RADIUS = 0.42
-- The wheel trails behind the body, held on the swing arm's axle.
local AXLE_Y = 0.3
local AXLE_LENGTH = 0.8
local BODY_BOTTOM, BODY_HEIGHT = 0.95, 0.9
local BODY_WIDTH, BODY_DEPTH = 1.05, 0.9
-- Swing arm pivot, under the body on the +X side.
local PIVOT = { 0.36, -0.15, BODY_BOTTOM - 0.08 }
local SAW_X, SAW_Z = 1.05, 1.35
local SAW_RADIUS = 0.42
local SAW_TEETH = 14
local EYE_Z = 1.5
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

local RUBBER = -1
local DUST = { 0.55, 0.5, 0.42 }

-- Paint fn for rubber: dust settled low and in patches, and pale scuffs where
-- it has rubbed. Rubber doesn't rust.
local function scuffed(color)
	return function(x, y, z, nx, ny, nz)
		local dust = math.clamp((0.9 - z) * 0.3, 0, 0.3)
			+ math.clamp(math.noise(x * 3 + 2, y * 3, z * 3) * 0.5, 0, 0.35)
			+ math.clamp(nz, 0, 1) * 0.15
		local c = {
			color[1] + (DUST[1] - color[1]) * dust,
			color[2] + (DUST[2] - color[2]) * dust,
			color[3] + (DUST[3] - color[3]) * dust,
		}
		if scratchAt(x, y, z, nx, ny, nz) > 0 then
			return c[1] * 1.6, c[2] * 1.6, c[3] * 1.6
		end
		return c[1], c[2], c[3]
	end
end

-- Part following one bone. `smooth` overrides the auto-smooth angle (true
-- for fully round parts like the zapper's body). `rust` sets how worn it
-- is, default 0.4; 0 for glowing eyes and visors; RUBBER for tyres and treads.
local function part(name, bone, color, build, smooth, rust)
	local mesh = Mesh.new()
	build(mesh)
	mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
	mesh:unwrap()
	local image = Image.new(TEXTURE, TEXTURE, color[1], color[2], color[3])
	rust = rust or 0.4
	if rust == RUBBER then
		mesh:paint(image, scuffed(color))
	elseif rust > 0 then
		mesh:paint(image, weathered(color, rust))
	end
	mesh:paintShading(image, { highlight = EDGE_HIGHLIGHT, blend = EDGE_BLEND })
	model.part(name, mesh, image, { bone = bone, preview = true })
end

-- Disc in the YZ plane with sawtooth edge, centred at (cx, cy, cz).
local function sawBlade(mesh, cx, cy, cz, radius, thick, teeth)
	local front, back = {}, {}
	for i = 0, teeth * 2 - 1 do
		local t = i / (teeth * 2) * TAU
		-- Hooked teeth: tips lean round the spin direction.
		local r = if i % 2 == 0 then radius else radius * 0.82
		local lean = if i % 2 == 0 then 0.12 else 0
		front[i + 1] = mesh:vertex(cx + thick / 2, cy + math.cos(t + lean) * r, cz + math.sin(t + lean) * r)
		back[i + 1] = mesh:vertex(cx - thick / 2, cy + math.cos(t + lean) * r, cz + math.sin(t + lean) * r)
	end
	local n = #front
	for i = 1, n do
		local j = i % n + 1
		mesh:face({ back[i], back[j], front[j], front[i] })
	end
	mesh:face(front)
	local capBack = {}
	for i = n, 1, -1 do
		table.insert(capBack, back[i])
	end
	mesh:face(capBack)
end

-- Shallow dish opening along +Z then tilted toward -Y, apex at (cx, cy, cz).
local function radarDish(mesh, cx, cy, cz, radius, depth)
	local sides = 12
	local tilt = 0.6
	local function at(x, y, z)
		-- Tilt about X so the dish faces up and forward.
		local c, s = math.cos(tilt), math.sin(tilt)
		return mesh:vertex(cx + x, cy + y * c + z * s, cz - y * s + z * c)
	end
	local apex = at(0, 0, 0)
	local rim, lip = {}, {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		rim[i + 1] = at(math.cos(t) * radius, math.sin(t) * radius, depth)
		lip[i + 1] = at(math.cos(t) * radius * 0.9, math.sin(t) * radius * 0.9, depth * 0.75)
	end
	for i = 1, sides do
		local j = i % sides + 1
		mesh:face({ apex, rim[j], rim[i] })
		mesh:face({ rim[i], rim[j], lip[j], lip[i] })
	end
	local inner = {}
	for i = sides, 1, -1 do
		table.insert(inner, lip[i])
	end
	mesh:face(inner)
end

local root = model.bone("Root", { at = { 0, 0, 0 } })
local body = model.bone("Body", { at = { 0, 0, BODY_BOTTOM }, parent = root })
local suspension = model.bone("Suspension", { at = PIVOT, parent = body })
local wheel = model.bone("Wheel", { at = { 0, AXLE_Y, WHEEL_RADIUS }, parent = suspension })
local sawArm = model.bone("SawArm", { at = { BODY_WIDTH / 2, 0, SAW_Z }, parent = body })
local saw = model.bone("Saw", { at = { SAW_X, -0.15, SAW_Z }, parent = sawArm })
local antenna = model.bone("Antenna", { at = { -0.3, 0.2, BODY_BOTTOM + BODY_HEIGHT }, parent = body })

local top = BODY_BOTTOM + BODY_HEIGHT
local front = -BODY_DEPTH / 2

part("Wheel", wheel, TYRE, function(mesh)
	cylinder(mesh, 0, AXLE_Y, WHEEL_RADIUS, WHEEL_RADIUS, 0.3, "x", 20)
end, nil, RUBBER)
part("WheelHub", wheel, STEEL, function(mesh)
	-- Hub rims on both faces, with lug bolts round each.
	for _, side in { -1, 1 } do
		ring(mesh, side * 0.16, AXLE_Y, WHEEL_RADIUS, 0.1, 0.24, 0.04, "x")
		for i = 0, 4 do
			local t = i / 5 * TAU
			bolt(mesh, side * 0.18, AXLE_Y + math.cos(t) * 0.17, WHEEL_RADIUS + math.sin(t) * 0.17, "x", 0.03)
		end
	end
end)
part("SwingArm", suspension, DARK_STEEL, function(mesh)
	-- Axle right through the wheel, capped with nuts.
	cylinder(mesh, 0.08, AXLE_Y, WHEEL_RADIUS, 0.06, AXLE_LENGTH, "x", 10)
	bolt(mesh, -AXLE_LENGTH / 2 + 0.08, AXLE_Y, WHEEL_RADIUS, "x", 0.09)
	-- Arm from the pivot bracket back and down to the axle end.
	local ax = AXLE_LENGTH / 2 + 0.02
	strut(mesh, PIVOT[1], PIVOT[2], PIVOT[3], ax, AXLE_Y, WHEEL_RADIUS, 0.13)
	cylinder(mesh, ax, AXLE_Y, WHEEL_RADIUS, 0.1, 0.12, "x", 10)
	cylinder(mesh, PIVOT[1], PIVOT[2], PIVOT[3], 0.09, 0.2, "x", 10)
end)
-- Coil-over shock: the cylinder hangs from the body, the rod rides on the arm and
-- slides inside it, so the arm can swing without the shock bending.
local SHOCK_TOP = { 0.3, 0.35, BODY_BOTTOM + 0.05 }
local SHOCK_FOOT = { AXLE_LENGTH / 2 - 0.01, AXLE_Y - 0.12, WHEEL_RADIUS + 0.25 }
local function alongShock(k)
	return SHOCK_FOOT[1] + (SHOCK_TOP[1] - SHOCK_FOOT[1]) * k,
		SHOCK_FOOT[2] + (SHOCK_TOP[2] - SHOCK_FOOT[2]) * k,
		SHOCK_FOOT[3] + (SHOCK_TOP[3] - SHOCK_FOOT[3]) * k
end
part("ShockCylinder", body, DARK_STEEL, function(mesh)
	local x, y, z = alongShock(0.45)
	strut(mesh, x, y, z, SHOCK_TOP[1], SHOCK_TOP[2], SHOCK_TOP[3], 0.08)
	for i = 0, 3 do
		local rx, ry, rz = alongShock(0.5 + i * 0.13)
		ring(mesh, rx, ry, rz, 0.04, 0.085, 0.03, "z", 8)
	end
end)
part("ShockRod", suspension, GALVANISED, function(mesh)
	local x, y, z = alongShock(0.8)
	strut(mesh, SHOCK_FOOT[1], SHOCK_FOOT[2], SHOCK_FOOT[3], x, y, z, 0.035)
	cylinder(mesh, SHOCK_FOOT[1], SHOCK_FOOT[2], SHOCK_FOOT[3], 0.05, 0.12, "x", 8)
end)
part("Body", body, RUST, function(mesh)
	box(mesh, 0, 0, BODY_BOTTOM, BODY_WIDTH, BODY_DEPTH, BODY_HEIGHT)
	-- Lid lip round the top, like the box it was cut from.
	box(mesh, 0, 0, top - 0.08, BODY_WIDTH + 0.06, BODY_DEPTH + 0.06, 0.08)
end)
part("Plates", body, GALVANISED, function(mesh)
	-- Galvanised panel bolted low on the front, a strap riveted over the top.
	box(mesh, -0.12, front - 0.02, BODY_BOTTOM + 0.08, 0.7, 0.04, 0.32)
	box(mesh, 0.25, 0, top, 0.16, BODY_DEPTH + 0.1, 0.03)
	for _, x in { -0.42, 0.18 } do
		for _, z in { BODY_BOTTOM + 0.13, BODY_BOTTOM + 0.35 } do
			bolt(mesh, x, front - 0.05, z, "y", 0.035)
		end
	end
end)
part("AppliancePanel", body, APPLIANCE, function(mesh)
	-- Off-square panel on the -X side, from an old washing machine.
	box(mesh, -BODY_WIDTH / 2 - 0.02, 0.05, BODY_BOTTOM + 0.3, 0.04, 0.62, 0.48)
	for _, y in { -0.21, 0.31 } do
		for _, z in { BODY_BOTTOM + 0.36, BODY_BOTTOM + 0.72 } do
			bolt(mesh, -BODY_WIDTH / 2 - 0.05, y, z, "x", 0.035)
		end
	end
end)
part("EyeRim", body, STEEL, function(mesh)
	ring(mesh, 0.12, front - 0.03, EYE_Z, 0.17, 0.27, 0.08, "y", 20)
	for i = 0, 5 do
		local t = i / 6 * TAU
		bolt(mesh, 0.12 + math.cos(t) * 0.22, front - 0.08, EYE_Z + math.sin(t) * 0.22, "y", 0.025)
	end
end)
part("Eye", body, EYE, function(mesh)
	sphere(mesh, 0.12, front - 0.01, EYE_Z, 0.18, 0.08, 0.18)
end, true, 0)
part("SawArm", sawArm, DARK_STEEL, function(mesh)
	box(mesh, BODY_WIDTH / 2 + 0.03, 0, SAW_Z - 0.18, 0.06, 0.3, 0.36)
	strut(mesh, BODY_WIDTH / 2, 0, SAW_Z, SAW_X - 0.05, -0.15, SAW_Z, 0.14)
	cylinder(mesh, SAW_X - 0.08, -0.15, SAW_Z, 0.09, 0.12, "x", 10)
end)
part("Saw", saw, STEEL, function(mesh)
	sawBlade(mesh, SAW_X, -0.15, SAW_Z, SAW_RADIUS, 0.04, SAW_TEETH)
	bolt(mesh, SAW_X + 0.04, -0.15, SAW_Z, "x", 0.08)
end)
part("Antenna", antenna, DARK_STEEL, function(mesh)
	cylinder(mesh, -0.3, 0.2, top + 0.04, 0.07, 0.08, "z", 8)
	strut(mesh, -0.3, 0.2, top, -0.35, 0.25, top + 0.4, 0.05)
	strut(mesh, -0.35, 0.25, top + 0.4, -0.12, 0.3, top + 0.62, 0.05)
end)
part("RadarDish", antenna, GALVANISED, function(mesh)
	radarDish(mesh, -0.12, 0.3, top + 0.6, 0.3, 0.14)
end)
