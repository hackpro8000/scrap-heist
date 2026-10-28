-- Simple Car: a low-poly hatchback about 4.4 studs long, 2.2 wide and 2.1 tall. A faceted
-- rust-streaked body with a flat sloped hood, a tall cabin of sloped planes with a glass band, a
-- black cladding band round the bottom, rectangular headlights with amber indicators, red rear
-- lights and four rubber wheels with silver hubcaps. Local -y is the front.
local PAINT = { 0.62, 0.6, 0.55 }
local GLASS = { 0.2, 0.24, 0.27 }
local GLOW = { 1, 0.85, 0.5 }
local AMBER = { 1, 0.55, 0.1 }
local TAIL_RED = { 0.85, 0.12, 0.08 }
local BUMPER = { 0.18, 0.17, 0.16 }
local VENT = { 0.06, 0.06, 0.06 }

local WHEEL_Y = 1.4
local WHEEL_Z = 0.5
local ARCH_RADIUS = 0.52

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

-- A convex solid from corner points ({x, y, z} each) and faces (index lists). Each face is wound
-- to point away from the centre of the points, so faces can be listed in any order.
local function solid(mesh, points, faces)
	local cx, cy, cz = 0, 0, 0
	for _, p in points do
		cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
	end
	cx, cy, cz = cx / #points, cy / #points, cz / #points
	local ids = {}
	for i, p in points do
		ids[i] = mesh:vertex(p[1], p[2], p[3])
	end
	for _, face in faces do
		local nx, ny, nz, fx, fy, fz = 0, 0, 0, 0, 0, 0
		for k, i in face do
			local a, b = points[i], points[face[k % #face + 1]]
			nx += (a[2] - b[2]) * (a[3] + b[3])
			ny += (a[3] - b[3]) * (a[1] + b[1])
			nz += (a[1] - b[1]) * (a[2] + b[2])
			fx, fy, fz = fx + a[1], fy + a[2], fz + a[3]
		end
		local outward = nx * (fx / #face - cx) + ny * (fy / #face - cy) + nz * (fz / #face - cz) >= 0
		local verts = {}
		for k = 1, #face do
			verts[k] = ids[face[if outward then k else #face + 1 - k]]
		end
		mesh:face(verts)
	end
end

-- Faces of a stack of four-corner rings: the walls between each ring and the next, plus both caps.
local function ringFaces(rings)
	local faces = { { 1, 2, 3, 4 }, { rings * 4 - 3, rings * 4 - 2, rings * 4 - 1, rings * 4 } }
	for r = 0, rings - 2 do
		for c = 1, 4 do
			local d = c % 4 + 1
			table.insert(faces, { r * 4 + c, r * 4 + d, r * 4 + 4 + d, r * 4 + 4 + c })
		end
	end
	return faces
end

-- Side profile of the body, clockwise from the bottom of the nose: a near-upright nose, a short
-- chamfer, a flat hood sloping up to the windscreen, a level waist, a chamfered tail and an arch
-- of straight facets over each wheel.
local bodyOutline = {
	{ -2.15, 0.45 },
	{ -2.2, 0.95 },
	{ -2.0, 1.07 },
	{ -0.85, 1.32 },
	{ 1.98, 1.36 },
	{ 2.14, 1.28 },
	{ 2.18, 0.8 },
	{ 2.14, 0.45 },
}
for _, p in arc(WHEEL_Y, WHEEL_Z, ARCH_RADIUS, 0, 180, 6) do
	table.insert(bodyOutline, p)
end
for _, p in arc(-WHEEL_Y, WHEEL_Z, ARCH_RADIUS, 0, 180, 6) do
	table.insert(bodyOutline, p)
end

-- The cabin as three rings of corners (front-left, front-right, back-right, back-left), each
-- { z, front y, back y, half width }: the waist sunk into the body, the top of the glass, and a
-- narrower roof. The sloped planes between them are the windscreen, hatch and tumbled-in sides.
local CABIN_RINGS = {
	{ 1.28, -0.9, 1.98, 1.04 },
	{ 2.02, -0.1, 1.86, 0.9 },
	{ 2.12, 0.02, 1.76, 0.8 },
}
local cabinPoints = {}
for _, ring in CABIN_RINGS do
	local z, front, back, half = table.unpack(ring)
	table.insert(cabinPoints, { -half, front, z })
	table.insert(cabinPoints, { half, front, z })
	table.insert(cabinPoints, { half, back, z })
	table.insert(cabinPoints, { -half, back, z })
end
local CABIN_CENTER = { 0, 0.9, 1.6 }

-- A glass pane lying on a cabin wall between its waist and glass-top rings. `a`, `b` index the
-- waist corners in order, so `a + 4`, `b + 4` are the corners above; `u` runs a to b and `v` up
-- the wall. The pane stands just proud of the wall, with its back sunk in.
local function cabinPane(mesh, a, b, u0, u1, v0, v1)
	local function at(u, v)
		local p = {}
		for k = 1, 3 do
			local bottom = cabinPoints[a][k] + (cabinPoints[b][k] - cabinPoints[a][k]) * u
			local top = cabinPoints[a + 4][k] + (cabinPoints[b + 4][k] - cabinPoints[a + 4][k]) * u
			p[k] = bottom + (top - bottom) * v
		end
		return p
	end
	local corners = { at(u0, v0), at(u1, v0), at(u1, v1), at(u0, v1) }
	local e1 = { corners[2][1] - corners[1][1], corners[2][2] - corners[1][2], corners[2][3] - corners[1][3] }
	local e2 = { corners[4][1] - corners[1][1], corners[4][2] - corners[1][2], corners[4][3] - corners[1][3] }
	local n = { e1[2] * e2[3] - e1[3] * e2[2], e1[3] * e2[1] - e1[1] * e2[3], e1[1] * e2[2] - e1[2] * e2[1] }
	local len = math.sqrt(n[1] * n[1] + n[2] * n[2] + n[3] * n[3])
	local side = (corners[1][1] - CABIN_CENTER[1]) * n[1] + (corners[1][2] - CABIN_CENTER[2]) * n[2] + (corners[1][3] - CABIN_CENTER[3]) * n[3]
	local scale = if side >= 0 then 1 / len else -1 / len
	local points = {}
	for _, offset in { 0.03, -0.02 } do
		for _, c in corners do
			table.insert(points, { c[1] + n[1] * scale * offset, c[2] + n[2] * scale * offset, c[3] + n[3] * scale * offset })
		end
	end
	solid(mesh, points, ringFaces(2))
end

part("Body", nil, RUST_ORANGE, function(mesh)
	sidePlate(mesh, bodyOutline, 0, 2.2, 0.1)
end, false, 0.6)

part("Cabin", nil, PAINT, function(mesh)
	solid(mesh, cabinPoints, ringFaces(#CABIN_RINGS))
end, false, 0.5)

-- Two side windows split by a pillar on each cabin wall, so they read from the game camera.
part("Glass", nil, GLASS, function(mesh)
	for _, wall in { { 1, 4 }, { 2, 3 } } do
		cabinPane(mesh, wall[1], wall[2], 0.07, 0.44, 0.12, 0.9)
		cabinPane(mesh, wall[1], wall[2], 0.5, 0.96, 0.12, 0.9)
	end
end, false, 0)

-- A raked pane across the windscreen plane.
part("Windshield", nil, GLASS, function(mesh)
	cabinPane(mesh, 1, 2, 0.07, 0.93, 0.1, 0.92)
end, false, 0)

-- A matching pane across the hatch at the back of the cabin.
part("RearWindow", nil, GLASS, function(mesh)
	cabinPane(mesh, 3, 4, 0.08, 0.92, 0.25, 0.9)
end, false, 0)

-- A black band round the bottom of the body: a bumper wrapping the nose, a sill between the
-- arches and a bumper wrapping the tail, with a row of vents painted across the front bumper.
part("Cladding", nil, BUMPER, function(mesh)
	sidePlate(mesh, { { -2.24, 0.4 }, { -2.27, 0.74 }, { -1.96, 0.74 }, { -2.02, 0.4 } }, 0, 2.26, 0.05)
	sidePlate(mesh, { { -0.82, 0.4 }, { -0.84, 0.66 }, { 0.84, 0.66 }, { 0.82, 0.4 } }, 0, 2.26, 0.05)
	sidePlate(mesh, { { 2.02, 0.4 }, { 1.96, 0.74 }, { 2.27, 0.74 }, { 2.24, 0.4 } }, 0, 2.26, 0.05)
end, false, rusting(0.3, function(x, _y, z, _nx, ny, _nz)
	local isVent = ny < -0.6 and z > 0.5 and z < 0.6 and math.abs(x) < 0.85 and (x + 0.85) % 0.24 < 0.18
	local color = if isVent then VENT else BUMPER
	return color[1], color[2], color[3]
end))

-- A flared fender over each wheel: a five-sided section swept round the arch from the body side.
part("Fenders", nil, RUST_ORANGE, function(mesh)
	local section = { { 1.0, 0.52 }, { 1.4, 0.5 }, { 1.4, 0.57 }, { 1.29, 0.64 }, { 1.0, 0.66 } }
	local steps = 8
	local function angle(k)
		return math.rad(8 + 164 * k / steps)
	end
	for _, side in { -1, 1 } do
		for _, wheelY in { -WHEEL_Y, WHEEL_Y } do
			local function centre(a)
				return { side * 1.2, wheelY + math.cos(a) * 0.58, WHEEL_Z + math.sin(a) * 0.58 }
			end
			local function face(corners, inside)
				local nx, ny, nz, fx, fy, fz = 0, 0, 0, 0, 0, 0
				for k, c in corners do
					local a, b = c.p, corners[k % #corners + 1].p
					nx += (a[2] - b[2]) * (a[3] + b[3])
					ny += (a[3] - b[3]) * (a[1] + b[1])
					nz += (a[1] - b[1]) * (a[2] + b[2])
					fx, fy, fz = fx + a[1], fy + a[2], fz + a[3]
				end
				local n = #corners
				local outward = nx * (fx / n - inside[1]) + ny * (fy / n - inside[2]) + nz * (fz / n - inside[3]) >= 0
				local verts = {}
				for k = 1, n do
					verts[k] = corners[if outward then k else n + 1 - k].id
				end
				mesh:face(verts)
			end
			local rings = {}
			for k = 0, steps do
				local a = angle(k)
				local ring = {}
				for i, s in section do
					local p = { side * s[1], wheelY + math.cos(a) * s[2], WHEEL_Z + math.sin(a) * s[2] }
					ring[i] = { id = mesh:vertex(p[1], p[2], p[3]), p = p }
				end
				rings[k] = ring
			end
			for k = 0, steps - 1 do
				local inside = centre(angle(k + 0.5))
				for i = 1, #section do
					local j = i % #section + 1
					face({ rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i] }, inside)
				end
			end
			face(rings[0], centre(angle(0.5)))
			face(rings[steps], centre(angle(steps - 0.5)))
		end
	end
end, false, 0.6)

-- A dark slot across the nose between the headlights.
part("Grille", nil, BUMPER, function(mesh)
	box(mesh, 0, -2.2, 0.8, 0.7, 0.05, 0.06)
end, false, 0.3)

-- A boxy side mirror on each side, standing on the waist at the foot of the windscreen.
part("Mirrors", nil, BUMPER, function(mesh)
	for _, x in { -1.12, 1.12 } do
		box(mesh, x, -0.62, 1.3, 0.22, 0.08, 0.14)
	end
end, false, 0.3)

-- Rectangular headlights set into the nose under the hood edge.
part("Lights", nil, GLOW, function(mesh)
	for _, x in { -0.68, 0.68 } do
		box(mesh, x, -2.2, 0.78, 0.4, 0.06, 0.14)
	end
end, nil, 0, nil, 2)

-- An amber indicator at the outer end of each headlight.
part("Indicators", nil, AMBER, function(mesh)
	for _, x in { -0.94, 0.94 } do
		box(mesh, x, -2.19, 0.78, 0.12, 0.06, 0.14)
	end
end, nil, 0, nil, 1)

-- Tall red lights at the top corners of the tail.
part("RearLights", nil, TAIL_RED, function(mesh)
	for _, x in { -0.85, 0.85 } do
		box(mesh, x, 2.17, 0.9, 0.26, 0.06, 0.3)
	end
end, nil, 0, nil, 1)

-- Wheels stick out past the body so they read as separate parts. The axle runs along x.
part("Wheels", nil, RUBBER_BLACK, function(mesh)
	for _, x in { -1.2, 1.2 } do
		for _, y in { -WHEEL_Y, WHEEL_Y } do
			cylinder(mesh, x, y, WHEEL_Z, 0.42, 0.3, "x", 14)
		end
	end
end, nil, 0.3)

-- A silver disc on the outer face of each wheel.
part("Hubcaps", nil, BARE_METAL, function(mesh)
	for _, x in { -1.36, 1.36 } do
		for _, y in { -WHEEL_Y, WHEEL_Y } do
			cylinder(mesh, x, y, WHEEL_Z, 0.25, 0.04, "x", 10)
		end
	end
end, nil, 0.3)

finishParts()
