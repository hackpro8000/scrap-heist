-- Scrap Tree (Lamppost): a bent city lamppost standing in for a tree. Its
-- crown is a cluster of hubcaps welded onto the lamp arms like leaves, with
-- a rubble root ball of concrete chunks around the base.
-- include: HandFinish
local CONCRETE = { 0.5, 0.48, 0.44 }

-- Lamp arms reaching out from the pole as branches, each with its radius.
local ARMS = {
	{ points = { { 0.3, 0, 8 }, { 1.6, 0.4, 9.2 }, { 2.6, 0.6, 9.4 } }, radius = 0.12 },
	{ points = { { 0.3, 0, 8.8 }, { -1.4, -0.6, 10 }, { -2.4, -0.8, 10.1 } }, radius = 0.12 },
	{ points = { { 0.2, 0, 9.6 }, { 0.6, 1.6, 10.8 }, { 0.8, 2.2, 11 } }, radius = 0.1 },
}

part("Trunk", nil, DARK_STEEL, function(mesh)
	tube(mesh, { { 0, 0, 0 }, { 0.1, 0, 4 }, { 0.4, 0.1, 7.5 }, { 0.2, 0, 10 } }, 0.22, 8)
	for _, arm in ARMS do
		tube(mesh, arm.points, arm.radius, 6)
	end
	-- The original lamp's neck, curving out to its shade.
	tube(mesh, { { 0.2, 0, 9.9 }, { 0.5, 0, 10.6 }, { 1.2, 0, 10.85 }, { 1.65, 0, 10.8 } }, 0.13, 8)
	sphere(mesh, 1.75, 0, 10.62, 1.12, 0.92, 0.42, 5, 14)
	-- The reflector's lip, standing out round the lamp.
	ring(mesh, 1.75, 0, 10.42, 0.8, 1.22, 0.12, "z", 16)
end, true, 0.6)

-- The point `along` (0 to 1) of the way down an arm by length, and the
-- arm's direction there.
local function alongArm(points, along: number): (number, number, number, number, number, number)
	local lengths, total = {}, 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		lengths[i] = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
		total += lengths[i]
	end
	local left = along * total
	for i = 1, #points - 1 do
		if left <= lengths[i] or i == #points - 1 then
			local a, b = points[i], points[i + 1]
			local t = math.min(left / lengths[i], 1)
			local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
			return a[1] + dx * t, a[2] + dy * t, a[3] + dz * t, dx, dy, dz
		end
		left -= lengths[i]
	end
	error("arm has no segments")
end

-- Builds into a mesh whose z axis points along (nx, ny, nz) from (cx, cy, cz),
-- so round pieces made about "z" at the origin face that way.
local function facing(mesh, cx: number, cy: number, cz: number, nx: number, ny: number, nz: number, crush: number?)
	local tx, ty, tz, ux, uy, uz, vx, vy, vz = crossFrame(nx, ny, nz)
	return setmetatable({
		vertex = function(_, x, y, z)
			local across = y * (crush or 1)
			return mesh:vertex(cx + ux * x + vx * across + tx * z, cy + uy * x + vy * across + ty * z, cz + uz * x + vz * across + tz * z)
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

-- Hubcaps welded flat against the arms like leaves, square to the arm, each
-- turned a different way round it: up, then out to either side.
local HUBCAP_THICK = 0.12
local HUBCAP_SPOTS = { 0.4, 0.72, 1 }
-- Hanging tilt in degrees added per arm, and which caps are half crushed.
local HUBCAP_SIZES = { 0.86, 0.6, 0.42 }
local ARM_TILTS = { -18, 24, 40 }
local CRUSHED_CAPS = { ["1-2"] = true, ["3-1"] = true }
local HUBCAP_TURNS = { 0, math.rad(75), math.rad(-75) }
part("Hubcaps", nil, STEEL, function(mesh)
	for armIndex, arm in ARMS do
		for j, along in HUBCAP_SPOTS do
			local px, py, pz, dx, dy, dz = alongArm(arm.points, along)
			local length = math.sqrt(dx * dx + dy * dy + dz * dz)
			dx, dy, dz = dx / length, dy / length, dz / length
			-- Up, square to the arm, and the arm's side.
			local upX, upY, upZ = -dz * dx, -dz * dy, 1 - dz * dz
			local upLength = math.sqrt(upX * upX + upY * upY + upZ * upZ)
			upX, upY, upZ = upX / upLength, upY / upLength, upZ / upLength
			local sideX, sideY, sideZ = dy * upZ - dz * upY, dz * upX - dx * upZ, dx * upY - dy * upX
			local turn = HUBCAP_TURNS[j] + math.rad(ARM_TILTS[armIndex])
			local c, s = math.cos(turn), math.sin(turn)
			local nx, ny, nz = upX * c + sideX * s, upY * c + sideY * s, upZ * c + sideZ * s
			-- Its back sits on the arm's surface.
			local out = arm.radius + HUBCAP_THICK / 2
			local cap = facing(mesh, px + nx * out, py + ny * out, pz + nz * out, nx, ny, nz, if CRUSHED_CAPS[`{armIndex}-{j}`] then 0.55 else 1)
			-- Dished in steps, with a bolt either side of the hub holding it to the arm.
			local size = HUBCAP_SIZES[j]
			ring(cap, 0, 0, 0, size * 0.55, size, HUBCAP_THICK, "z", 12)
			cylinder(cap, 0, 0, 0.05, size * 0.62, 0.16, "z", 12)
			cylinder(cap, 0, 0, 0.13, size * 0.34, 0.12, "z", 8)
			for _, along2 in { -1, 1 } do
				bolt(cap, along2 * size * 0.45, 0, 0.15, "z", 0.06)
			end
		end
	end
end, nil, 0.3)

part("Lamp", nil, { 1, 0.74, 0.3 }, function(mesh)
	cylinder(mesh, 1.75, 0, 10.26, 0.72, 0.34, "z", 16)
end, nil, 0, nil, 1)

-- The root ball: broken slabs and lumps heaped up round the pole's foot, the
-- higher ones leaning on those below and on the pole. Where, size, then the way
-- each one's top faces.
local RUBBLE = {
	{ 1.15, 0.4, -0.05, 1.5, 1.2, 0.7, 0.15, 0.1, 1 },
	{ -1.1, 0.65, -0.05, 1.3, 1.5, 0.6, -0.2, 0.1, 1 },
	{ 0.2, -1.2, -0.05, 1.6, 1.05, 0.65, 0, -0.2, 1 },
	{ -0.95, -0.85, -0.05, 1.0, 1.0, 0.45, -0.1, -0.1, 1 },
	{ 0.3, 1.25, -0.05, 0.9, 0.75, 0.4, 0, 0.2, 1 },
	{ 1.75, -0.65, -0.05, 0.6, 0.7, 0.28, 0.2, 0, 1 },
	{ -1.95, -0.15, -0.05, 0.5, 0.6, 0.22, -0.2, 0, 1 },
	{ 0.72, 0.28, 0.5, 1.0, 0.75, 0.42, -0.45, -0.15, 0.85 },
	{ -0.68, 0.32, 0.4, 0.8, 0.85, 0.4, 0.5, -0.2, 0.85 },
	{ 0.1, -0.74, 0.46, 0.95, 0.65, 0.38, 0.05, 0.5, 0.85 },
	{ -0.58, -0.5, 0.3, 0.5, 0.48, 0.3, 0.4, 0.35, 0.85 },
	{ 0.42, 0.1, 0.92, 0.56, 0.45, 0.3, -0.55, 0, 0.82 },
	{ -0.42, 0.2, 0.8, 0.45, 0.5, 0.26, 0.55, 0, 0.82 },
}

part("Rubble", nil, CONCRETE, function(mesh)
	for _, r in RUBBLE do
		box(facing(mesh, r[1], r[2], r[3], r[7], r[8], r[9]), 0, 0, 0, r[4], r[5], r[6])
	end
end, nil, 0.2)

handFinish({
	Trunk = "metal",
	Hubcaps = "metal",
	Rubble = "rock",
}, {
	Lamp = true,
}, PROP_FINISH)
finishParts()
