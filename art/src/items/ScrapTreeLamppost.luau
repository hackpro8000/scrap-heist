-- Scrap Tree (Lamppost): a bent city lamppost standing in for a tree. Its
-- crown is a cluster of hubcaps welded onto the lamp arms like leaves, with
-- a rubble root ball of concrete chunks around the base.
local CONCRETE = { 0.6, 0.59, 0.56 }

-- Lamp arms reaching out from the pole as branches, each with its radius.
local ARMS = {
	{ points = { { 0.3, 0, 8 }, { 1.6, 0.4, 9.2 }, { 2.6, 0.6, 9.4 } }, radius = 0.12 },
	{ points = { { 0.3, 0, 8.8 }, { -1.4, -0.6, 10 }, { -2.4, -0.8, 10.1 } }, radius = 0.12 },
	{ points = { { 0.2, 0, 9.6 }, { 0.6, 1.6, 10.8 }, { 0.8, 2.2, 11 } }, radius = 0.1 },
}

part("Trunk", nil, DARK_STEEL, function(mesh)
	cylinder(mesh, 0, 0, 0, 0.45, 0.6, "z", 10)
	tube(mesh, { { 0, 0, 0.5 }, { 0.1, 0, 4 }, { 0.4, 0.1, 7.5 }, { 0.2, 0, 10 } }, 0.22, 8)
	for _, arm in ARMS do
		tube(mesh, arm.points, arm.radius, 6)
	end
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
local function facing(mesh, cx: number, cy: number, cz: number, nx: number, ny: number, nz: number)
	local tx, ty, tz, ux, uy, uz, vx, vy, vz = crossFrame(nx, ny, nz)
	return setmetatable({
		vertex = function(_, x, y, z)
			return mesh:vertex(cx + ux * x + vx * y + tx * z, cy + uy * x + vy * y + ty * z, cz + uz * x + vz * y + tz * z)
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
local HUBCAP_SPOTS = { 0.35, 0.6, 0.82, 1 }
local HUBCAP_TURNS = { 0, math.rad(75), math.rad(-75), math.rad(20) }
part("Hubcaps", nil, STEEL, function(mesh)
	for _, arm in ARMS do
		for j, along in HUBCAP_SPOTS do
			local px, py, pz, dx, dy, dz = alongArm(arm.points, along)
			local length = math.sqrt(dx * dx + dy * dy + dz * dz)
			dx, dy, dz = dx / length, dy / length, dz / length
			-- Up, square to the arm, and the arm's side.
			local upX, upY, upZ = -dz * dx, -dz * dy, 1 - dz * dz
			local upLength = math.sqrt(upX * upX + upY * upY + upZ * upZ)
			upX, upY, upZ = upX / upLength, upY / upLength, upZ / upLength
			local sideX, sideY, sideZ = dy * upZ - dz * upY, dz * upX - dx * upZ, dx * upY - dy * upX
			local turn = HUBCAP_TURNS[j]
			local c, s = math.cos(turn), math.sin(turn)
			local nx, ny, nz = upX * c + sideX * s, upY * c + sideY * s, upZ * c + sideZ * s
			-- Its back sits on the arm's surface.
			local out = arm.radius + HUBCAP_THICK / 2
			local cap = facing(mesh, px + nx * out, py + ny * out, pz + nz * out, nx, ny, nz)
			ring(cap, 0, 0, 0, 0.15, 0.9, HUBCAP_THICK, "z", 12)
			cylinder(cap, 0, 0, 0.02, 0.3, 0.16, "z", 8)
		end
	end
end, nil, 0.3)

part("Lamp", nil, COPPER, function(mesh)
	box(mesh, 0.2, 0, 10, 0.8, 0.5, 0.3)
end, nil, 0.5)

part("Rubble", nil, CONCRETE, function(mesh)
	box(mesh, 0.8, 0.3, 0, 0.9, 0.7, 0.4)
	box(mesh, -0.7, 0.5, 0, 0.7, 0.8, 0.3)
	box(mesh, 0.1, -0.9, 0, 0.8, 0.6, 0.35)
end, nil, 0.2)

finishParts()
