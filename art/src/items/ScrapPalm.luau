-- Scrap Palm: a leaning trunk of stacked pipe couplings, crowned with long
-- drooping fronds cut from sheet metal strips, with a few rusty paint cans
-- hanging under the crown as coconuts.
-- The trunk's line, from the root at t = 0 to the crown at t = 1: rising
-- 8.5 and bending out 2 along x, steepest at the root. trunkAt gives the
-- point and the direction the trunk runs there.
local TRUNK_HEIGHT, TRUNK_BEND = 8.5, 2
local TRUNK_RADIUS = 0.28
local function trunkAt(t: number): (number, number, number, number, number, number)
	return TRUNK_BEND * t * t, 0, TRUNK_HEIGHT * t, 2 * TRUNK_BEND * t, 0, TRUNK_HEIGHT
end

part("Trunk", nil, DARK_STEEL, function(mesh)
	local points = {}
	for step = 0, 16 do
		local x, y, z = trunkAt(step / 16)
		table.insert(points, { x, y, z })
	end
	tube(mesh, points, TRUNK_RADIUS, 8)
end, true, 0.6)

-- A coupling: a short band hugging the trunk, square to it wherever it
-- sits, so the bands follow the bend.
local function coupling(mesh, t: number, outer: number, depth: number, sides: number)
	local px, py, pz, dx, dy, dz = trunkAt(t)
	local tx, ty, tz, ux, uy, uz, vx, vy, vz = crossFrame(dx, dy, dz)
	local function ringAt(radius: number, along: number)
		local ring = {}
		for k = 0, sides - 1 do
			local a = k / sides * TAU
			local c, n = math.cos(a) * radius, math.sin(a) * radius
			ring[k + 1] = mesh:vertex(px + tx * along + ux * c + vx * n, py + ty * along + uy * c + vy * n, pz + tz * along + uz * c + vz * n)
		end
		return ring
	end
	local h = depth / 2
	local outLow, outHigh = ringAt(outer, -h), ringAt(outer, h)
	local inLow, inHigh = ringAt(TRUNK_RADIUS, -h), ringAt(TRUNK_RADIUS, h)
	for k = 1, sides do
		local l = k % sides + 1
		mesh:face({ outLow[k], outLow[l], outHigh[l], outHigh[k] })
		mesh:face({ inHigh[k], inHigh[l], inLow[l], inLow[k] })
		mesh:face({ outHigh[k], outHigh[l], inHigh[l], inHigh[k] })
		mesh:face({ inLow[k], inLow[l], outLow[l], outLow[k] })
	end
end

part("Couplings", nil, STEEL, function(mesh)
	for step = 1, 7 do
		coupling(mesh, step / 8, 0.36, 0.2, 8)
	end
end, nil, 0.5)

part("Fronds", nil, STEEL, function(mesh)
	for i = 0, 6 do
		local a = i * math.pi * 2 / 7
		local dx, dy = math.cos(a), math.sin(a)
		tube(mesh, {
			{ 2, 0, 8.6 },
			{ 2 + dx * 1.4, dy * 1.4, 9.2 },
			{ 2 + dx * 2.8, dy * 2.8, 8.6 },
			{ 2 + dx * 3.6, dy * 3.6, 7.4 },
		}, 0.1, 4)
		-- Strips cut along each frond, drooping off both sides like leaflets.
		for step = 1, 6 do
			local d = step * 0.55
			local x, y = 2 + dx * d, dy * d
			local z = 8.6 + math.sin(step / 7 * math.pi) * 0.7 - (if step > 4 then (step - 4) * 0.4 else 0)
			for _, side in { -1, 1 } do
				strut(mesh, x, y, z, x - dy * side * 0.7 + dx * 0.2, y + dx * side * 0.7 + dy * 0.2, z - 0.5, 0.12)
			end
		end
	end
end, nil, 0.3)

part("Cans", nil, RUST_ORANGE, function(mesh)
	for _, p in { { 1.8, 0.4 }, { 2.2, -0.3 }, { 1.7, -0.4 } } do
		cylinder(mesh, p[1], p[2], 8, 0.22, 0.45, "z", 8)
	end
end, nil, 0.6)

finishParts()
