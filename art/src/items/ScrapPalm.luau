-- Scrap Palm: a leaning trunk of stacked pipe couplings, crowned with long
-- drooping fronds cut from sheet metal strips, with a few rusty paint cans
-- hanging under the crown as coconuts.
-- The trunk's line, from the root at t = 0 to the crown at t = 1: rising
-- 8.5 and bending out 2 along x, steepest at the root. trunkAt gives the
-- point and the direction the trunk runs there.
-- include: HandFinish
local TRUNK_HEIGHT, TRUNK_BEND = 8.5, 2
local function trunkAt(t: number): (number, number, number, number, number, number)
	return TRUNK_BEND * t * t, 0, TRUNK_HEIGHT * t, 2 * TRUNK_BEND * t, 0, TRUNK_HEIGHT
end

-- The trunk's pipe lengths, thinner toward the crown: where each joint falls
-- along it, and each length's radius.
local JOINTS = { 0, 0.16, 0.31, 0.47, 0.62, 0.76, 0.9, 1 }
local PIPE_RADII = { 0.38, 0.34, 0.31, 0.28, 0.25, 0.22, 0.19 }

part("Trunk", nil, DARK_STEEL, function(mesh)
	for i, radius in PIPE_RADII do
		local points = {}
		for step = 0, 4 do
			local x, y, z = trunkAt(JOINTS[i] + (JOINTS[i + 1] - JOINTS[i]) * step / 4)
			table.insert(points, { x, y, z })
		end
		tube(mesh, points, radius, 8)
	end
end, true, 0.6)

-- A coupling: a short band hugging the trunk, square to it wherever it
-- sits, so the bands follow the bend.
local function coupling(mesh, t: number, inner: number, outer: number, depth: number, sides: number)
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
	local inLow, inHigh = ringAt(inner, -h), ringAt(inner, h)
	for k = 1, sides do
		local l = k % sides + 1
		mesh:face({ outLow[k], outLow[l], outHigh[l], outHigh[k] })
		mesh:face({ inHigh[k], inHigh[l], inLow[l], inLow[k] })
		mesh:face({ outHigh[k], outHigh[l], inHigh[l], inHigh[k] })
		mesh:face({ inLow[k], inLow[l], outLow[l], outLow[k] })
	end
end

part("Couplings", nil, STEEL, function(mesh)
	-- A fat coupling at every joint between the pipe lengths.
	for i = 2, #PIPE_RADII do
		local wider = PIPE_RADII[i - 1]
		coupling(mesh, JOINTS[i], PIPE_RADII[i] - 0.03, wider + 0.15, if i == 4 then 0.46 else 0.34, 10)
	end
	-- Guy wires holding the lean back, down to the pad's far edge.
	for _, y in { -1.4, 1.4 } do
		local x, _, z = trunkAt(0.88)
		strut(mesh, x, y * 0.12, z, -1.05, y, 0.3, 0.1)
		-- An eyebolt taking each wire at the pad.
		ring(mesh, -1.05, y, 0.36, 0.07, 0.17, 0.08, "y", 8)
	end
	-- The crown plate the fronds are welded to.
	cylinder(mesh, 2, 0, 8.6, 0.85, 0.24, "z", 12)
	cylinder(mesh, 2, 0, 8.76, 0.34, 0.2, "z", 8)
end, nil, 0.5)

-- A leaflet: a strip of sheet from (ax, ay, az) to (bx, by, bz), tapering to a
-- torn tip and lying flat, its face toward the sky.
local function leaflet(mesh, ax: number, ay: number, az: number, bx: number, by: number, bz: number)
	local dx, dy, dz = bx - ax, by - ay, bz - az
	local long = math.sqrt(dx * dx + dy * dy + dz * dz)
	local ux, uy, uz = dx / long, dy / long, dz / long
	local across = math.sqrt(ux * ux + uy * uy)
	local wx, wy = -uy / across, ux / across
	local vx, vy, vz = wy * uz, -wx * uz, wx * uy - wy * ux
	plate({
		vertex = function(_self, x: number, y: number, z: number)
			return mesh:vertex(ax + ux * x + vx * y + wx * z, ay + uy * x + vy * y + wy * z, az + uz * x + vz * y)
		end,
		face = function(_self, face)
			return mesh:face(face)
		end,
	}, { { 0, 0.17 }, { long * 0.62, 0.15 }, { long * 0.9, 0.06 }, { long, -0.02 }, { long * 0.62, -0.15 }, { 0, -0.17 } }, 0, 0.04, 0.006)
end

part("Fronds", nil, STEEL, function(mesh)
	-- Each frond: bearing in degrees, length, how far it rises, how far its tip
	-- falls, its strips, sideways kink, and which strips have torn off. A snapped
	-- frond breaks partway and its outer end hangs straight down.
	for _, frond in {
		{ 8, 3.9, 0.7, 1.5, 7, 0.5, {} },
		{ 47, 3.0, 0.9, 0.9, 5, 0, { [2] = true } },
		{ 122, 3.7, 0.45, 2.0, 6, -0.6, { [4] = true, [5] = true } },
		{ 168, 1.3, 0.35, 0.2, 2, 0, {} },
		{ 229, 2.5, 1.0, 0.4, 4, 0.3, {} },
		{ 262, 4.1, 0.55, 1.9, 7, 0, { [3] = true }, true },
		{ 331, 3.2, 0.75, 1.2, 5, -0.35, { [1] = true, [3] = true } },
	} do
		local a = math.rad(frond[1])
		local dx, dy = math.cos(a), math.sin(a)
		local long, rise, fall, strips, kink, torn, snapped = frond[2], frond[3], frond[4], frond[5], frond[6], frond[7], frond[8]
		local base = 8.72
		local function point(out: number, side: number, z: number)
			return { 2 + dx * out - dy * side, dy * out + dx * side, z }
		end
		local spine = if snapped
			then { point(0.2, 0, base), point(long * 0.4, 0, base + rise), point(long * 0.62, 0.1, base + rise * 0.5), point(long * 0.66, 0.2, base - 1.7) }
			else { point(0.2, 0, base), point(long * 0.4, 0, base + rise), point(long * 0.78, kink, base), point(long, kink * 1.5, base - fall) }
		tube(mesh, spine, 0.1, 4)
		-- Strips cut along each frond, drooping off both sides like leaflets.
		local reach = if snapped then 2 else 3
		for step = 1, strips do
			if torn[step] then
				continue
			end
			local along = step / (strips + 1) * reach
			local at = math.floor(along) + 1
			local a0, a1 = spine[at], spine[at + 1]
			local f = along - math.floor(along)
			local x, y, z = a0[1] + (a1[1] - a0[1]) * f, a0[2] + (a1[2] - a0[2]) * f, a0[3] + (a1[3] - a0[3]) * f
			local stripLong = 0.55 + (step * 37 % 5) * 0.09
			for _, side in { -1, 1 } do
				leaflet(mesh, x, y, z, x - dy * side * stripLong + dx * 0.2, y + dx * side * stripLong + dy * 0.2, z - 0.5)
			end
		end
	end
end, nil, 0.3)

part("Cans", nil, RUST_ORANGE, function(mesh)
	-- Hanging apart on straps from the crown plate's rim, at different heights.
	for _, p in { { 2.9, 0.2, 8.0 }, { 1.45, 0.95, 7.05 }, { 1.65, -0.95, 7.55 } } do
		local x, y, z = p[1], p[2], p[3]
		cylinder(mesh, x, y, z, 0.26, 0.5, "z", 10)
		-- The lid's rim and the base's, standing out from the body.
		cylinder(mesh, x, y, z + 0.27, 0.3, 0.06, "z", 10)
		cylinder(mesh, x, y, z - 0.27, 0.3, 0.06, "z", 10)
		local out = math.sqrt((x - 2) ^ 2 + y * y)
		local lugX, lugY = 2 + (x - 2) / out * 0.5, y / out * 0.5
		strut(mesh, lugX, lugY, 8.58, x, y, z + 0.3, 0.14)
		-- The lug on the plate's rim the strap hangs from.
		box(mesh, lugX, lugY, 8.5, 0.24, 0.24, 0.2)
	end
end, nil, 0.6)

part("Footing", nil, { 0.5, 0.48, 0.44 }, function(mesh)
	-- A wide pad under the lean, reaching out past the crown's weight.
	box(mesh, 1.0, 0, 0, 4.4, 3.2, 0.3)
	cylinder(mesh, 0, 0, 0.3, 0.74, 0.6, "z", 14)
	box(mesh, 0.85, 0.35, 0, 0.5, 0.45, 0.22)
	box(mesh, -0.7, -0.55, 0, 0.42, 0.5, 0.18)
end, nil, 0.25)

part("TyreCollar", nil, RUBBER_BLACK, function(mesh)
	ring(mesh, 0, 0, 0.3, 0.68, 1.3, 0.6, "z", 16)
end, nil, RUBBER)

handFinish({
	Trunk = "metal",
	Couplings = "metal",
	Fronds = "metal",
	Cans = "metal",
	Footing = "rock",
	TyreCollar = "rock",
}, {}, PROP_FINISH)
finishParts()
