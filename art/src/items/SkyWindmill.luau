-- Sky Windmill: the turning structures on the horizon. A lattice tower of
-- four legs and cross braces under a small engine house, and a four-bladed
-- rotor the game spins about y. The rotor is its own part, even all round,
-- so its middle is its axle. 15 studs tall; the game scales it up and
-- stands it on a far-off island.

local STEEL = { 0.36, 0.38, 0.45 }
local CREAM = { 0.88, 0.82, 0.7 }
local RED = { 0.78, 0.26, 0.2 }
local BRONZE = { 0.66, 0.46, 0.26 }

local HEIGHT = 12
local FOOT, HEAD = 2.4, 0.55
local AXLE_Z = HEIGHT + 0.9
local ROTOR_Y = -1.5
local BLADE = 6.2

-- A leg corner at height z: the tower narrows as it rises.
local function corner(sx, sy, z)
	local half = FOOT + (HEAD - FOOT) * z / HEIGHT
	return sx * half, sy * half, z
end

part("Tower", nil, STEEL, function(mesh)
	local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
	for _, c in corners do
		local x0, y0, z0 = corner(c[1], c[2], 0)
		local x1, y1, z1 = corner(c[1], c[2], HEIGHT)
		strut(mesh, x0, y0, z0, x1, y1, z1, 0.3)
	end
	-- Each side: a rail and a diagonal per level, the diagonals alternating.
	local levels = 5
	for side = 1, 4 do
		local a, b = corners[side], corners[side % 4 + 1]
		for level = 0, levels - 1 do
			local low, high = level / levels * HEIGHT, (level + 1) / levels * HEIGHT
			local ax, ay, az = corner(a[1], a[2], low)
			local bx, by, bz = corner(b[1], b[2], low)
			strut(mesh, ax, ay, az + 0.05, bx, by, bz + 0.05, 0.16)
			local from, to = if level % 2 == 0 then a else b, if level % 2 == 0 then b else a
			local fx, fy, fz = corner(from[1], from[2], low)
			local tx, ty, tz = corner(to[1], to[2], high)
			strut(mesh, fx, fy, fz, tx, ty, tz, 0.13)
		end
	end
	-- The deck and the engine house on it, its axle pointing forward.
	box(mesh, 0, 0, HEIGHT, 1.7, 1.7, 0.2)
	box(mesh, 0, 0.2, AXLE_Z - 0.7, 1.2, 1.9, 1.4)
	box(mesh, 0, 0.2, AXLE_Z + 0.7, 1.4, 2.1, 0.2)
	cylinder(mesh, 0, -1, AXLE_Z, 0.22, 0.7, "y", 8)
end, nil, 0.3, 512, nil, true)

-- A blade from radius r0 to r1 at `angle`, a flat board widening outward.
local function blade(mesh, angle, r0, r1, w0, w1, depth)
	local v = {}
	for _, e in { { r0, w0 }, { r1, w1 } } do
		local r, w = e[1], e[2] / 2
		for _, s in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			local x = math.sin(angle) * r + math.cos(angle) * w * s[1]
			local z = math.cos(angle) * r - math.sin(angle) * w * s[1]
			table.insert(v, mesh:vertex(x, ROTOR_Y + depth / 2 * s[2], AXLE_Z + z))
		end
	end
	for k = 1, 4 do
		local l = k % 4 + 1
		mesh:face({ v[k], v[l], v[l + 4], v[k + 4] })
	end
	mesh:face({ v[8], v[7], v[6], v[5] })
	mesh:face({ v[1], v[2], v[3], v[4] })
end

-- Cream boards with red tips round a bronze hub.
local rotorPaint = rusting(0.25, function(x, _y, z)
	local reach = math.sqrt(x * x + (z - AXLE_Z) ^ 2)
	local color = if reach < 0.75 then BRONZE elseif reach > BLADE - 1 then RED else CREAM
	return color[1], color[2], color[3]
end)

part("Rotor", nil, CREAM, function(mesh)
	cylinder(mesh, 0, ROTOR_Y, AXLE_Z, 0.6, 0.5, "y", 10)
	cylinder(mesh, 0, ROTOR_Y - 0.3, AXLE_Z, 0.3, 0.3, "y", 8)
	for k = 0, 3 do
		local angle = k / 4 * TAU + 0.4
		-- The spar, then the board set a little to one side of it.
		blade(mesh, angle, 0.4, BLADE, 0.22, 0.16, 0.22)
		blade(mesh, angle + 0.07, 1.3, BLADE, 0.7, 1.5, 0.1)
	end
end, nil, rotorPaint, 512, nil, true)

finishParts()
