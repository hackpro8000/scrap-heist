-- Simple Car: a rounded hatchback about 4.3 studs long, 2.2 wide and 2.2 tall. A rust-streaked body
-- with a curved hood and trunk, a cabin with a sloped roof and a glass band, four rubber wheels under
-- arched fenders and two headlights. Local -y is the front.
local PAINT = { 0.62, 0.6, 0.55 }
local GLASS = { 0.2, 0.24, 0.27 }
local GLOW = { 1, 0.85, 0.5 }
local BUMPER = { 0.18, 0.17, 0.16 }

local WHEEL_Y = 1.4
local WHEEL_Z = 0.5
local ARCH_RADIUS = 0.58

-- `plate` drawn side-on: the outline runs in y-z (y first) and the plate is extruded across x,
-- centred on `x`. A quarter turn about z, so faces keep their winding.
local function sidePlate(mesh, outline, x, width, bevel)
	local turned = {
		vertex = function(_, px, py, pz)
			return mesh:vertex(-py, px, pz)
		end,
		face = function(_, verts)
			return mesh:face(verts)
		end,
	}
	plate(turned, outline, -x, width, bevel)
end

-- A thin pane lying along a cabin edge from (y0, z0) to (y1, z1), standing just proud of it.
-- The edge must run clockwise round the cabin outline, so its outward side is to the left.
local function pane(mesh, y0, z0, y1, z1, width)
	local dy, dz = y1 - y0, z1 - z0
	local len = math.sqrt(dy * dy + dz * dz)
	local ny, nz = -dz / len, dy / len
	local out, back = 0.05, -0.02
	sidePlate(mesh, {
		{ y0 + ny * out, z0 + nz * out },
		{ y1 + ny * out, z1 + nz * out },
		{ y1 + ny * back, z1 + nz * back },
		{ y0 + ny * back, z0 + nz * back },
	}, 0, width, 0.015)
end

-- Appends arc points (in y-z) to an outline.
local function addArc(outline, cy, cz, radius, a0, a1, steps)
	for _, p in arc(cy, cz, radius, a0, a1, steps) do
		table.insert(outline, p)
	end
end

-- Side profile of the body, clockwise from the bottom of the nose: a rounded nose, a curved hood
-- rising to the cabin, a curved trunk falling to the tail, and an arch cut over each wheel.
local bodyOutline = {
	{ -2.1, 0.6 },
	{ -2.16, 0.82 },
	{ -2.12, 1.0 },
	{ -2.0, 1.14 },
	{ -1.75, 1.24 },
	{ -1.3, 1.32 },
	{ -0.8, 1.37 },
	{ 0.3, 1.4 },
	{ 1.4, 1.38 },
	{ 1.8, 1.32 },
	{ 2.04, 1.18 },
	{ 2.15, 0.95 },
	{ 2.12, 0.62 },
	{ 2.05, 0.5 },
}
addArc(bodyOutline, WHEEL_Y, WHEEL_Z, ARCH_RADIUS, 0, 180, 10)
addArc(bodyOutline, -WHEEL_Y, WHEEL_Z, ARCH_RADIUS, 0, 180, 10)
table.insert(bodyOutline, { -2.05, 0.5 })

-- Side profile of the cabin, clockwise from the foot of the windshield: a raked windshield, a
-- crowned roof and a steep hatch. The wide bevel tapers the roof in toward the top.
local WINDSHIELD = { -0.9, 1.3, -0.32, 2.04 }
local HATCH = { 1.22, 2.06, 1.45, 1.4 }
local cabinOutline = {
	{ WINDSHIELD[1], WINDSHIELD[2] },
	{ WINDSHIELD[3], WINDSHIELD[4] },
	{ -0.1, 2.12 },
	{ 0.3, 2.16 },
	{ 0.75, 2.16 },
	{ 1.05, 2.12 },
	{ HATCH[1], HATCH[2] },
	{ HATCH[3], HATCH[4] },
	{ 1.45, 1.3 },
}

part("Body", nil, RUST_ORANGE, function(mesh)
	sidePlate(mesh, bodyOutline, 0, 2.2, 0.1)
end, 50, 0.6)

part("Cabin", nil, PAINT, function(mesh)
	sidePlate(mesh, cabinOutline, 0, 1.9, 0.2)
end, 50, 0.5)

-- Side windows standing just outside the cabin walls, following the roof line, so they read
-- from the game camera.
part("Glass", nil, GLASS, function(mesh)
	sidePlate(mesh, {
		{ -0.5, 1.52 },
		{ -0.2, 1.88 },
		{ 0.3, 1.94 },
		{ 0.9, 1.94 },
		{ 1.12, 1.86 },
		{ 1.2, 1.52 },
	}, 0, 1.96, 0.03)
end, 50, 0)

-- A raked pane along the cabin's windshield slope.
part("Windshield", nil, GLASS, function(mesh)
	local y0, z0, y1, z1 = table.unpack(WINDSHIELD)
	pane(mesh, y0 + (y1 - y0) * 0.12, z0 + (z1 - z0) * 0.12, y0 + (y1 - y0) * 0.9, z0 + (z1 - z0) * 0.9, 1.5)
end, 50, 0)

-- A matching pane along the hatch slope at the back of the cabin.
part("RearWindow", nil, GLASS, function(mesh)
	local y0, z0, y1, z1 = table.unpack(HATCH)
	pane(mesh, y0 + (y1 - y0) * 0.1, z0 + (z1 - z0) * 0.1, y0 + (y1 - y0) * 0.8, z0 + (z1 - z0) * 0.8, 1.5)
end, 50, 0)

-- Round bars across the front and the back, curving round the corners into the body.
part("Bumper", nil, BUMPER, function(mesh)
	for _, side in { -1, 1 } do
		tube(mesh, {
			{ -1.05, side * 2.0, 0.6 },
			{ -0.85, side * 2.17, 0.6 },
			{ -0.4, side * 2.22, 0.6 },
			{ 0.4, side * 2.22, 0.6 },
			{ 0.85, side * 2.17, 0.6 },
			{ 1.05, side * 2.0, 0.6 },
		}, 0.12, 10)
	end
end, 50, 0.3)

-- A dark rounded grille panel between the headlights, resting on the front bumper.
part("Grille", nil, BUMPER, function(mesh)
	local outline = {}
	for _, corner in { { 0.36, 0.9, 90, 0 }, { 0.36, 0.78, 0, -90 }, { -0.36, 0.78, -90, -180 }, { -0.36, 0.9, 180, 90 } } do
		for _, p in arc(corner[1], corner[2], 0.09, corner[3], corner[4], 3) do
			table.insert(outline, p)
		end
	end
	plate(mesh, outline, -2.17, 0.1, 0.03)
end, 50, 0.3)

-- Three pale slats bowed slightly forward across the face of the grille.
part("GrilleSlats", nil, PAINT, function(mesh)
	for _, z in { 0.75, 0.84, 0.93 } do
		tube(mesh, { { -0.38, -2.2, z }, { 0, -2.24, z }, { 0.38, -2.2, z } }, 0.022, 6)
	end
end, 50, 0.5)

-- A round dark rocker bar along the bottom of each side, between the arches.
part("Sills", nil, BUMPER, function(mesh)
	for _, x in { -1.08, 1.08 } do
		tube(mesh, { { x, -0.8, 0.56 }, { x, 0, 0.55 }, { x, 0.8, 0.56 } }, 0.07, 8)
	end
end, 50, 0.3)

-- A curved shell over each wheel: a half ring that wraps the tire, overlapping the body arch.
part("Fenders", nil, RUST_ORANGE, function(mesh)
	local inner, outer = ARCH_RADIUS, ARCH_RADIUS + 0.09
	for _, x in { -1.2, 1.2 } do
		for _, y in { -WHEEL_Y, WHEEL_Y } do
			local x0, x1 = x - 0.18, x + 0.18
			local rows = {}
			for i, p in arc(0, 0, 1, 0, 180, 12) do
				local cy, cz = p[1], p[2]
				rows[i] = {
					mesh:vertex(x0, y + cy * outer, WHEEL_Z + cz * outer),
					mesh:vertex(x1, y + cy * outer, WHEEL_Z + cz * outer),
					mesh:vertex(x1, y + cy * inner, WHEEL_Z + cz * inner),
					mesh:vertex(x0, y + cy * inner, WHEEL_Z + cz * inner),
				}
			end
			for i = 1, #rows - 1 do
				local a, b = rows[i], rows[i + 1]
				for k = 1, 4 do
					local l = k % 4 + 1
					mesh:face({ a[k], b[k], b[l], a[l] })
				end
			end
			local first, last = rows[1], rows[#rows]
			mesh:face({ first[1], first[2], first[3], first[4] })
			mesh:face({ last[4], last[3], last[2], last[1] })
		end
	end
end, 50, 0.6)

-- A round flared lip along the outer edge of each fender.
part("ArchLips", nil, RUST_ORANGE, function(mesh)
	for _, x in { -1.37, 1.37 } do
		for _, y in { -WHEEL_Y, WHEEL_Y } do
			local points = {}
			for _, p in arc(y, WHEEL_Z, ARCH_RADIUS + 0.07, 0, 180, 12) do
				table.insert(points, { x, p[1], p[2] })
			end
			tube(mesh, points, 0.04, 6)
		end
	end
end, 50, 0.6)

-- Two thin dark door seams on each side of the body, rounded so they read as grooves.
part("DoorSeams", nil, BUMPER, function(mesh)
	for _, x in { -1.1, 1.1 } do
		for _, y in { -0.6, 0.5 } do
			tube(mesh, { { x, y, 0.66 }, { x, y - 0.01, 0.95 }, { x, y - 0.03, 1.24 } }, 0.018, 6)
		end
	end
end, 50, 0)

-- A rounded side mirror pod on each side of the cabin front.
part("Mirrors", nil, PAINT, function(mesh)
	for _, x in { -1.05, 1.05 } do
		sphere(mesh, x, -0.4, 1.52, 0.15, 0.06, 0.08, 4, 8)
	end
end, 50, 0.5)

part("Lights", nil, GLOW, function(mesh)
	for _, x in { -0.7, 0.7 } do
		sphere(mesh, x, -2.1, 0.95, 0.12, 0.08, 0.12, 4, 6)
	end
end, nil, 0, nil, 2)

-- Wheels stick out past the body so they read as separate parts. The axle runs along x.
part("Wheels", nil, RUBBER_BLACK, function(mesh)
	for _, x in { -1.2, 1.2 } do
		for _, y in { -WHEEL_Y, WHEEL_Y } do
			cylinder(mesh, x, y, WHEEL_Z, 0.5, 0.3, "x", 14)
		end
	end
end, nil, 0.3)

finishParts()
