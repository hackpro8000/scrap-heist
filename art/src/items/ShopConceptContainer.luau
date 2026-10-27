-- Shop concept: the shipping container with a pipe wrench sign on its roof frame,
-- scrap stock piled round the doors and a drum by the steps. The shell is shared
-- with the other shops; this file sets its colours and adds the signage. Local -y
-- is the front.
local PAINT = { 0.7, 0.18, 0.12 }
local PLANK = { 0.5, 0.36, 0.22 }
local CRATE = { 0.55, 0.42, 0.28 }
local CONCRETE = { 0.55, 0.54, 0.5 }
local GLOW = { 1, 0.85, 0.5 }

-- include: ShippingContainer

part("Blades", nil, BARE_METAL, function(mesh)
	-- Saw blades strung up as ornaments beside the opening, each on a wire
	-- dropped from the top rail and hooked through a tooth gap.
	local HANG_Y = -HY - 0.14
	local RAIL = TOP - 0.23
	local function hung(x, z, radius, teeth)
		gear(mesh, x, HANG_Y, z, radius, 0.03, teeth, "y")
		-- Eye round the blade's top edge, and the wire up to the rail.
		ring(mesh, x, HANG_Y, z + radius, 0.03, 0.06, 0.03, "y", 8)
		cylinder(mesh, x, HANG_Y, (z + radius + 0.06 + RAIL) / 2, 0.015, RAIL - z - radius - 0.06, "z", 6)
	end
	hung(-3.4, 2.1, 0.32, 16)
	hung(3.4, 2.2, 0.38, 18)
	hung(3.35, 1.4, 0.25, 14)
end, nil, 0.3)

-- The sign is laid out at half size with its bottom edge at SIGN_BOTTOM, then
-- doubled about that edge, set down to SIGN_BASE and tilted up towards the
-- jaws, pivoting on the handle end.
local SIGN_BOTTOM = TOP + 0.81
local SIGN_SCALE, SIGN_BASE, SIGN_PIVOT = 2, TOP + 0.3, -4.8
local SIGN_TILT = math.rad(22)
-- Slides the tilted sign right so it sits centred over the container.
local SIGN_SHIFT = 0.5
local function enlarged(mesh)
	return {
		vertex = function(_, x, y, z)
			local dx, dz = x * SIGN_SCALE - SIGN_PIVOT, (z - SIGN_BOTTOM) * SIGN_SCALE
			local c, s = math.cos(SIGN_TILT), math.sin(SIGN_TILT)
			return mesh:vertex(SIGN_SHIFT + SIGN_PIVOT + dx * c - dz * s, -0.35 + (y + 0.35) * SIGN_SCALE, SIGN_BASE + dx * s + dz * c)
		end,
		face = function(_, face)
			return mesh:face(face)
		end,
	}
end

local function rect(x0, z0, x1, z1)
	return { { x0, z0 }, { x0, z1 }, { x1, z1 }, { x1, z0 } }
end

part("SignFrame", nil, DARK_STEEL, function(mesh)
	-- Lattice frame on the roof holding the sign up; posts reach the tilted handle.
	for _, x in { -1.7, 1.7 } do
		local top = SIGN_BASE + (x - SIGN_SHIFT - SIGN_PIVOT) * math.tan(SIGN_TILT) + 0.3
		strut(mesh, x, -0.3, TOP, x, -0.3, top, 0.1)
		strut(mesh, x, 0.5, TOP, x, -0.3, top - 0.3, 0.07)
		box(mesh, x, 0.1, TOP, 0.3, 1.0, 0.05)
	end
	strut(mesh, -1.7, -0.3, TOP + 0.1, 1.7, -0.3, TOP + 0.6, 0.05)
	strut(mesh, 1.7, -0.3, TOP + 0.1, -1.7, -0.3, TOP + 0.6, 0.05)
end, nil, 0.6)

part("Sign", nil, { 0.62, 0.3, 0.18 }, function(mesh)
	mesh = enlarged(mesh)
	-- A giant pipe wrench: notched handle with a hex hole, and the heel jaw.
	local z = TOP + 1.25
	local handle = { { -2.4, -0.28 }, { -2.4, -0.12 }, { -2.36, -0.08 } }
	for k = 0, 5 do
		local x = -0.45 + k * 0.2
		for _, p in { { x, -0.05 }, { x + 0.02, -0.085 }, { x + 0.08, -0.085 }, { x + 0.1, -0.05 } } do
			table.insert(handle, p)
		end
	end
	for _, p in { { 0.78, -0.05 }, { 0.78, -0.35 }, { -2.36, -0.32 } } do
		table.insert(handle, p)
	end
	local heel = { { 1.3, -0.12 }, { 1.3, 0.28 }, { 1.36, 0.34 }, { 1.68, 0.34 } }
	for k = 0, 5 do
		local dz = 0.3 - k * 0.07
		table.insert(heel, { 1.72, dz })
		table.insert(heel, { 1.755, dz - 0.035 })
	end
	table.insert(heel, { 1.72, -0.12 })
	for _, outline in { handle, heel } do
		for _, p in outline do
			p[2] += z
		end
		plate(mesh, outline, -0.35, 0.18, 0.04)
	end
end, nil, 0.7)

part("SignJaw", nil, { 0.56, 0.27, 0.20 }, function(mesh)
	mesh = enlarged(mesh)
	-- The hooked top jaw, toothed on its inner face.
	local z = TOP + 1.25
	local outline = {}
	for k = 0, 5 do
		local dz = -0.14 + k * 0.08
		table.insert(outline, { 1.95, dz })
		table.insert(outline, { 1.915, dz + 0.04 })
	end
	for _, p in {
		{ 1.95, 0.4 }, { 1.88, 0.48 }, { 1.93, 0.56 }, { 2.26, 0.56 }, { 2.34, 0.48 },
		{ 2.34, -0.26 }, { 2.28, -0.32 }, { 0.72, -0.32 }, { 0.72, -0.14 },
	} do
		table.insert(outline, p)
	end
	for _, p in outline do
		p[2] += z
	end
	plate(mesh, outline, -0.35, 0.18, 0.04)
end, nil, 0.7)

part("SignHousing", nil, PAINT, function(mesh)
	mesh = enlarged(mesh)
	-- Red spring housing framing a window onto the coil.
	local z = TOP + 1.25
	for _, r in { { 0.68, -0.44, 0.78, 0.06 }, { 1.26, -0.44, 1.36, 0.06 }, { 0.78, -0.44, 1.26, -0.38 }, { 0.78, -0.04, 1.26, 0.06 } } do
		plate(mesh, rect(r[1], z + r[2], r[3], z + r[4]), -0.35, 0.32, 0.03)
	end
end, nil, 0.6)

part("SignSpring", nil, BARE_METAL, function(mesh)
	mesh = enlarged(mesh)
	-- Coil spring seen through the housing window.
	local z = TOP + 1.25
	local points = {}
	for i = 0, 84 do
		local t = i / 12 * 2 * math.pi
		table.insert(points, { 0.8 + i / 84 * 0.46, -0.35 + math.sin(t) * 0.13, z - 0.23 + math.cos(t) * 0.13 })
	end
	tube(mesh, points, 0.022, 6)
end, nil, 0.3)

chunkedPart("SignBolts", nil, DARK_STEEL, function(mesh)
	mesh = enlarged(mesh)
	-- Housing corner bolts and the edge rails along the handle.
	local z = TOP + 1.25
	for _, x in { 0.73, 1.31 } do
		for _, dz in { -0.41, 0.01 } do
			cylinder(mesh, x, -0.52, z + dz, 0.035, 0.05, "y", 6)
		end
	end
	for _, dz in { -0.1, -0.3 } do
		plate(mesh, rect(-2.0, z + dz - 0.012, 0.62, z + dz + 0.012), -0.455, 0.03, 0.006)
	end
end, nil, 0.8)

part("SignRecesses", nil, DIM, function(mesh)
	mesh = enlarged(mesh)
	-- Hex hole through the handle end, and the dark back of the housing window.
	local z = TOP + 1.25
	cylinder(mesh, -2.2, -0.35, z - 0.2, 0.075, 0.2, "y", 6)
	plate(mesh, rect(0.78, z - 0.38, 1.26, z - 0.04), -0.23, 0.04, 0.01)
end, nil, 0.1)
-- LED sockets on the sign's front face: a row down the handle, and the two jaws.
-- Each socket is a cylinder whose front face is inset and pushed back into a cup.
local SOCKET_FRONT, SOCKET_BACK, SOCKET_FLOOR = -0.5, -0.43, -0.48
local SOCKET_OUTER, SOCKET_INNER, SOCKET_SIDES = 0.078, 0.05, 12
local signSockets = {}
for k = 0, 12 do
	table.insert(signSockets, { -1.95 + k * 0.2, -0.2 })
end
for _, p in { { 1.51, 0 }, { 1.51, 0.2 }, { 2.15, -0.2 }, { 2.15, 0 }, { 2.15, 0.2 }, { 2.15, 0.4 } } do
	table.insert(signSockets, p)
end

local function signSocket(mesh, x, z)
	-- Profile from the cup floor edge out to the back rim, swept round the y axis.
	local profile = {
		{ SOCKET_INNER, SOCKET_FLOOR },
		{ SOCKET_INNER, SOCKET_FRONT },
		{ SOCKET_OUTER, SOCKET_FRONT },
		{ SOCKET_OUTER, SOCKET_BACK },
	}
	local rows = {}
	for i = 0, SOCKET_SIDES - 1 do
		local t = i / SOCKET_SIDES * 2 * math.pi
		local row = {}
		for k, p in profile do
			row[k] = mesh:vertex(x + math.sin(t) * p[1], p[2], z + math.cos(t) * p[1])
		end
		rows[i + 1] = row
	end
	for i = 1, SOCKET_SIDES do
		local a, b = rows[i], rows[i % SOCKET_SIDES + 1]
		for k = 1, #profile - 1 do
			mesh:face({ a[k], b[k], b[k + 1], a[k + 1] })
		end
	end
	-- Cup floor as a triangle fan so it never depends on n-gon handling.
	local centre = mesh:vertex(x, SOCKET_FLOOR, z)
	for i = 1, SOCKET_SIDES do
		mesh:face({ centre, rows[i % SOCKET_SIDES + 1][1], rows[i][1] })
	end
	local back = {}
	for i = 1, SOCKET_SIDES do
		table.insert(back, rows[i][#profile])
	end
	mesh:face(back)
end

part("SignSockets", nil, DARK_STEEL, function(mesh)
	mesh = enlarged(mesh)
	local z = TOP + 1.25
	for _, p in signSockets do
		signSocket(mesh, p[1], z + p[2])
	end
end, nil, 0)

-- Glowing LED disc just in front of each cup floor; sockets and LEDs are rust-free so the jitter never buries a disc.
part("SignLeds", nil, GLOW, function(mesh)
	mesh = enlarged(mesh)
	local z = TOP + 1.25
	for _, p in signSockets do
		local x, y, cz = p[1], SOCKET_FLOOR - 0.004, z + p[2]
		local centre = mesh:vertex(x, y, cz)
		local edge = {}
		for i = 0, SOCKET_SIDES - 1 do
			local t = i / SOCKET_SIDES * 2 * math.pi
			edge[i + 1] = mesh:vertex(x + math.sin(t) * SOCKET_INNER, y, cz + math.cos(t) * SOCKET_INNER)
		end
		for i = 1, SOCKET_SIDES do
			mesh:face({ centre, edge[i % SOCKET_SIDES + 1], edge[i] })
		end
	end
end, nil, 0, nil, 1)

part("Yard", nil, CRATE, function(mesh)
	-- Crates stacked by the doors and a pallet out front.
	box(mesh, 5.2, -2.1, 0, 1.0, 1.0, 0.8)
	box(mesh, 5.1, -2.05, 0.8, 0.8, 0.8, 0.6)
	-- Corner battens and a cross brace on each crate face.
	for _, c in { { 5.2, -2.1, 0, 1.0, 0.8 }, { 5.1, -2.05, 0.8, 0.8, 0.6 } } do
		local x, y, z, s, h = c[1], c[2], c[3], c[4] / 2 + 0.02, c[5]
		for _, d in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
			box(mesh, x + d[1] * (s - 0.05), y + d[2] * (s - 0.05), z, 0.12, 0.12, h)
		end
		for _, d in { { 0, -1 }, { -1, 0 } } do
			box(mesh, x + d[1] * s, y + d[2] * s, z + 0.02, if d[1] == 0 then 2 * s else 0.04, if d[1] == 0 then 0.04 else 2 * s, 0.1)
			box(mesh, x + d[1] * s, y + d[2] * s, z + h - 0.12, if d[1] == 0 then 2 * s else 0.04, if d[1] == 0 then 0.04 else 2 * s, 0.1)
			strut(mesh, x + d[1] * s + (if d[1] == 0 then -s + 0.08 else 0), y + d[2] * s + (if d[1] == 0 then 0 else -s + 0.08), z + 0.12, x + d[1] * s + (if d[1] == 0 then s - 0.08 else 0), y + d[2] * s + (if d[1] == 0 then 0 else s - 0.08), z + h - 0.12, 0.06)
		end
	end
	for k = 0, 4 do
		box(mesh, -4.9, -2.3 + k * 0.28, 0.1, 1.4, 0.2, 0.06)
	end
	for _, y in { -2.4, -1.8, -1.2 } do
		box(mesh, -4.9, y, 0, 1.4, 0.12, 0.1)
		for _, x in { -5.5, -4.9, -4.3 } do
			box(mesh, x, y, 0, 0.16, 0.16, 0.1)
		end
	end
end, nil, 0.3)

part("Stock", nil, RUST_ORANGE, function(mesh)
	-- Pipes and rebar bundled on the pallet.
	for k = 0, 5 do
		local y, z = -2.3 + (k % 3) * 0.3, 0.3 + math.floor(k / 3) * 0.24
		cylinder(mesh, -4.9, y, z, 0.12, 1.7, "x", 8)
		ring(mesh, -4.9 + 0.86, y, z, 0.07, 0.125, 0.03, "x", 8)
	end
	-- Strapping round the bundle.
	for _, x in { -5.4, -4.4 } do
		box(mesh, x, -2, 0.16, 0.05, 0.86, 0.5)
	end
end, nil, 0.8)

-- Flat steel band round the drum between radii r0 and r1, half height h,
-- with its outer corners bevelled so the top edge paints light and the
-- bottom edge dark. The section is swept once round the drum axis.
local DRUM_SIDES = 14
-- Every lip has the same section.
local LIP_INNER, LIP_OUTER, LIP_HALF = 0.4, 0.465, 0.035
local function drumLip(mesh, z, r0, r1, h)
	local b = math.min(0.02, (r1 - r0) / 2)
	local section = { { r0, z - h }, { r1 - b, z - h }, { r1, z - h + b }, { r1, z + h - b }, { r1 - b, z + h }, { r0, z + h } }
	local rings = {}
	for k = 0, DRUM_SIDES - 1 do
		local t = k / DRUM_SIDES * math.pi * 2
		rings[k] = {}
		for i, s in section do
			rings[k][i] = mesh:vertex(5.4 + math.cos(t) * s[1], 2.0 + math.sin(t) * s[1], s[2])
		end
	end
	for k = 0, DRUM_SIDES - 1 do
		local a, c = rings[k], rings[(k + 1) % DRUM_SIDES]
		for i = 1, #section do
			local j = i % #section + 1
			mesh:face({ a[i], c[i], c[j], a[j] })
		end
	end
end

local DRUM_BLUE = { 0.2, 0.3, 0.42 }

-- Painted form shading lit from above, so each lip has a bright top
-- running round into a shaded underside. The drum rusts like other metal.
local drumPaint = rusting(0.6, function(_x, _y, _z, _nx, _ny, nz)
	local k = if nz >= 0 then 1 + nz * 0.3 else 1 + nz * 0.9
	return DRUM_BLUE[1] * k, DRUM_BLUE[2] * k, DRUM_BLUE[3] * k
end)

part("Drum", nil, DRUM_BLUE, function(mesh)
	cylinder(mesh, 5.4, 2.0, 0.65, 0.42, 1.3, "z", DRUM_SIDES)
	for _, z in { 0.25, 1.0 } do
		drumLip(mesh, z, LIP_INNER, LIP_OUTER, LIP_HALF)
	end
	-- Chime lips round the lid and the base, the base one sat on the ground.
	drumLip(mesh, 1.3, LIP_INNER, LIP_OUTER, LIP_HALF)
	drumLip(mesh, LIP_HALF, LIP_INNER, LIP_OUTER, LIP_HALF)
	cylinder(mesh, 5.25, 2.0, 1.32, 0.06, 0.05, "z", 8)
	cylinder(mesh, 5.6, 2.0, 1.31, 0.04, 0.04, "z", 6)
end, nil, drumPaint, 1024)

part("Steps", nil, CONCRETE, function(mesh)
	-- Cinder block step under the counter.
	for k = 0, 2 do
		box(mesh, -1.2 + k * 1.2, -HY - 0.9, 0, 1.0, 0.5, 0.35)
	end
	box(mesh, -0.6, -HY - 0.9, 0.35, 1.0, 0.5, 0.35)
	-- Raised webs around the blocks' hollow cores.
	for _, b in { { -1.2, 0.35 }, { 0, 0.35 }, { 1.2, 0.35 }, { -0.6, 0.7 } } do
		for _, dx in { -0.22, 0.22 } do
			ring(mesh, b[1] + dx, -HY - 0.9, b[2], 0.1, 0.17, 0.02, "z", 4)
		end
	end
end, nil, 0.4)

part("Stencil", nil, { 0.9, 0.86, 0.78 }, function(mesh)
	-- Painted ID patch on the end wall.
	box(mesh, -HX - 0.1, -0.5, 2.0, 0.03, 1.2, 0.35)
	box(mesh, -HX - 0.1, 0.5, 1.6, 0.03, 0.5, 0.6)
end, nil, 0.6)

finishParts()
