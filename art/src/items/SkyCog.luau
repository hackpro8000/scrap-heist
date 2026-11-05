-- Sky Cog: the huge cogwheel that turns half hidden behind the planet. It is
-- a working machine, kept up and still spinning, so it is whole and only
-- lightly weathered: bronze all over: a toothed rim with a raised inner lip, five
-- tapered spokes tied by a brace ring, a stepped hub and brass bolt
-- heads. It stands upright in the x-z plane, turning about y, 8.5 studs in
-- radius; the game scales it up a few hundred times, so it is painted at the
-- kit's full detail: edge highlights, contact shadows and a little grime.

local TEETH = 16
local BASE, TIP = 7.1, 8.5
local INNER = 5.5
local THICK = 1.3
local BRONZE = { 0.66, 0.46, 0.26 }
local BRASS = { 0.86, 0.68, 0.32 }

-- Ring round the y axis: `outerAt(i, steps)` gives the outer radius at each
-- step, so the same builder makes plain rings and the toothed rim.
local function band(mesh, outerAt, inner, thick, steps)
	local rows = {}
	for i = 0, steps - 1 do
		local t = i / steps * TAU
		local r = outerAt(i, steps)
		rows[i + 1] = {
			mesh:vertex(onAxis(0, 0, 0, "y", r, t, -thick / 2)),
			mesh:vertex(onAxis(0, 0, 0, "y", r, t, thick / 2)),
			mesh:vertex(onAxis(0, 0, 0, "y", inner, t, thick / 2)),
			mesh:vertex(onAxis(0, 0, 0, "y", inner, t, -thick / 2)),
		}
	end
	for i = 1, steps do
		local a, b = rows[i], rows[i % steps + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
end

-- Eight steps a tooth: sloped flanks up to a flat top.
local function toothed(i, _steps)
	local step = i % 8
	return if step >= 2 and step <= 4 then TIP else BASE
end

local function plain(radius)
	return function()
		return radius
	end
end

-- A spoke from radius r0 to r1 at `angle`, tapering in width and depth.
local function spoke(mesh, angle, r0, r1, w0, w1, d0, d1)
	local v = {}
	for _, e in { { r0, w0, d0 }, { r1, w1, d1 } } do
		local r, w, d = e[1], e[2] / 2, e[3] / 2
		for _, s in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			-- Along the spoke, across it, and through the wheel.
			local x = math.sin(angle) * r + math.cos(angle) * w * s[1]
			local z = math.cos(angle) * r - math.sin(angle) * w * s[1]
			table.insert(v, mesh:vertex(x, d * s[2], z))
		end
	end
	for k = 1, 4 do
		local l = k % 4 + 1
		mesh:face({ v[k], v[l], v[l + 4], v[k + 4] })
	end
end

local function at(angle, radius)
	return math.sin(angle) * radius, math.cos(angle) * radius
end

part("Rim", nil, BRONZE, function(mesh)
	band(mesh, toothed, INNER + 0.5, THICK, TEETH * 8)
	-- The raised lip round the inside.
	band(mesh, plain(INNER + 0.6), INNER, THICK * 1.25, 48)
	-- A shallow stiffening ridge on each face.
	band(mesh, plain(BASE - 0.35), BASE - 0.6, THICK * 1.1, 48)
end, nil, 0.2, 1024, nil, true, 0.5)

part("Spokes", nil, BRONZE, function(mesh)
	for k = 0, 4 do
		spoke(mesh, k / 5 * TAU + 0.3, 1.2, INNER + 0.2, 1.5, 0.95, 1.0, 0.8)
	end
	-- The brace ring tying the spokes together.
	band(mesh, plain(3.45), 3.0, 0.7, 40)
end, nil, 0.15, 1024, nil, true, 0.4)

part("Hub", nil, BRONZE, function(mesh)
	cylinder(mesh, 0, 0, 0, 1.9, 1.7, "y", 20)
	cylinder(mesh, 0, 0, 0, 1.25, 2.1, "y", 16)
	cylinder(mesh, 0, 0, 0, 0.55, 2.6, "y", 8)
end, nil, 0.15, 512, nil, true, 0.3)

part("Bolts", nil, BRASS, function(mesh)
	for _, side in { -1, 1 } do
		for k = 0, 7 do
			local x, z = at(k / 8 * TAU, 1.58)
			cylinder(mesh, x, side * 0.9, z, 0.13, 0.16, "y", 6)
		end
		for k = 0, 4 do
			-- A pair where each spoke meets the rim, one on the brace ring.
			local angle = k / 5 * TAU + 0.3
			for _, shift in { -0.07, 0.07 } do
				local x, z = at(angle + shift, INNER + 0.3)
				cylinder(mesh, x, side * THICK * 0.66, z, 0.16, 0.18, "y", 6)
			end
			local x, z = at(angle, 3.22)
			cylinder(mesh, x, side * 0.4, z, 0.12, 0.14, "y", 6)
		end
		for k = 0, TEETH - 1 do
			local x, z = at((k + 0.82) / TEETH * TAU, BASE - 0.9)
			cylinder(mesh, x, side * THICK * 0.52, z, 0.1, 0.12, "y", 6)
		end
	end
end, nil, 0.1, 256, nil, true)

finishParts()
