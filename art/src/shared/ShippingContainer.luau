-- The shipping container shell shared by the shop concepts: a rusted box with
-- its long side cut open, the cut panel propped up as an awning on pipe legs and
-- chains, a plank counter in the opening, shelves and a workbench inside, and a
-- roof frame with bulbs. Each item sets its colours before including this, and
-- adds its own signage and decoration. Local -y is the front.
-- One texel density for every part, so wear patterns line up across seams.
useTexelDensity(128)
local DIM = { 0.16, 0.14, 0.13 }

-- Container shell: x -4..4, y -1.45..1.45, z 0..3.1.
local HX, HY, TOP = 4, 1.45, 3.1
-- Serving opening cut in the front wall.
local OX, OZ0, OZ1 = 2.8, 1.0, 2.9

-- The corner posts and rails stand this far proud of the walls, so the
-- corrugation stops short of them instead of poking through.
local TRIM = 0.08
-- How far an out rib stands from the wall, kept just inside the trim.
local RIB = 0.045

-- Ribs along a wall at y, alternating in and out, between x0 and x1.
local function ribsY(mesh, y, sign, x0, x1, z0, z1)
	local n = math.floor((x1 - x0) / 0.3)
	for k = 0, n - 1 do
		box(mesh, x0 + (k + 0.5) * (x1 - x0) / n, y + sign * (k % 2) * RIB, z0, (x1 - x0) / n, 0.06, z1 - z0)
	end
end

local function ribsX(mesh, x, sign, y0, y1, z0, z1)
	local n = math.floor((y1 - y0) / 0.3)
	for k = 0, n - 1 do
		box(mesh, x + sign * (k % 2) * RIB, y0 + (k + 0.5) * (y1 - y0) / n, z0, 0.06, (y1 - y0) / n, z1 - z0)
	end
end

chunkedPart("Container", nil, PAINT, function(mesh)
	ribsY(mesh, HY, 1, -HX + TRIM, HX - TRIM, 0.15, TOP - 0.23)
	ribsX(mesh, -HX, -1, -HY + TRIM, HY - TRIM, 0.15, TOP - 0.23)
	ribsY(mesh, -HY, -1, -HX + TRIM, HX - TRIM, 0.15, OZ0)
	ribsY(mesh, -HY, -1, -HX + TRIM, -OX, OZ0, TOP - 0.23)
	ribsY(mesh, -HY, -1, OX, HX - TRIM, OZ0, TOP - 0.23)
	-- Roof panel with shallow dents.
	box(mesh, 0, 0, TOP - 0.1, 2 * HX, 2 * HY, 0.1)
	for k = 0, 6 do
		box(mesh, -3.4 + k * 1.13, 0, TOP, 0.8, 2.6, 0.04)
	end
end, nil, 0.75)

-- How far the ajar cargo door has swung open on its outer hinge.
local DOOR_SWING = math.rad(35)
-- The ajar leaf's top hinge has snapped, so it sags about its bottom hinge
-- and leans out from the frame.
local DOOR_SAG = math.rad(4)
local DOOR_LEAN = 0.06
local SAG_PIVOT = 0.5

-- Moves a point built on the shut ajar leaf to where the broken leaf hangs.
local function leafAt(x, y, z)
	local u, dz = HY - y, z - SAG_PIVOT
	local c, s = math.cos(DOOR_SAG), math.sin(DOOR_SAG)
	local sagU, sagZ = u * c + dz * s, SAG_PIVOT + dz * c - u * s
	local dx = x - HX + sagZ * DOOR_LEAN
	local cs, ss = math.cos(DOOR_SWING), math.sin(DOOR_SWING)
	return HX + dx * cs + sagU * ss, HY + dx * ss - sagU * cs, sagZ
end

-- Builds into `mesh` as if on the shut ajar leaf, landing on the broken one.
local function onLeaf(mesh)
	return {
		vertex = function(_, x, y, z)
			return mesh:vertex(leafAt(x, y, z))
		end,
		face = function(_, verts, uvs)
			return mesh:face(verts, uvs)
		end,
	}
end

part("Doors", nil, PAINT, function(mesh)
	-- Cargo doors on the +x end, one hanging slightly ajar.
	ribsX(mesh, HX, 1, -HY, -0.02, 0.15, TOP - 0.15)
	-- The ajar leaf is the same ribbed wall, hanging off its last hinge.
	ribsX(onLeaf(mesh), HX, 1, 0.02, HY, 0.15, TOP - 0.15)
end, nil, 0.75)

chunkedPart("Frame", nil, DARK_STEEL, function(mesh)
	-- Rails along every edge and cast corner blocks.
	for _, y in { -HY, HY } do
		for _, z in { 0, TOP - 0.15 } do
			box(mesh, 0, y, z, 2 * HX + 0.1, 0.16, 0.16)
		end
	end
	for _, x in { -HX, HX } do
		for _, z in { 0, TOP - 0.15 } do
			box(mesh, x, 0, z, 0.16, 2 * HY, 0.16)
		end
		for _, y in { -HY, HY } do
			box(mesh, x, y, 0, 0.16, 0.16, TOP)
			for _, z in { 0, TOP - 0.25 } do
				box(mesh, x, y, z, 0.3, 0.3, 0.25)
			end
		end
	end
	-- Rough cut frame round the opening, welded angle.
	box(mesh, 0, -HY - 0.05, OZ0 - 0.08, 2 * OX + 0.2, 0.12, 0.1)
	box(mesh, 0, -HY - 0.05, OZ1, 2 * OX + 0.2, 0.12, 0.1)
	for _, x in { -OX, OX } do
		box(mesh, x, -HY - 0.05, OZ0, 0.12, 0.12, OZ1 - OZ0)
	end
	-- Door lock bars and handles, the ajar leaf's carried along with it.
	-- Each bar rides in bolted keepers on the ribs, its handle clamped to it.
	for _, target in { mesh, onLeaf(mesh) } do
		local y = if target == mesh then -0.6 else HY - 0.9
		cylinder(target, HX + 0.12, y, TOP / 2, 0.04, TOP - 0.2, "z", 8)
		for _, z in { 0.35, 1.55, 2.7 } do
			box(target, HX + 0.09, y, z, 0.1, 0.16, 0.08)
			for _, dy in { -0.06, 0.06 } do
				bolt(target, HX + 0.14, y + dy, z + 0.04, "x", 0.025)
			end
		end
		cylinder(target, HX + 0.12, y, 0.08, 0.055, 0.08, "z", 8)
		cylinder(target, HX + 0.12, y, TOP - 0.18, 0.055, 0.08, "z", 8)
		box(target, HX + 0.15, y - 0.03, 1.25, 0.08, 0.1, 0.1)
		box(target, HX + 0.18, y - 0.2, 1.27, 0.05, 0.36, 0.05)
		cylinder(target, HX + 0.18, y - 0.36, 1.295, 0.035, 0.12, "x", 6)
	end
	-- Hinges: the shut leaf's are whole, each a strap bolted to the leaf.
	for _, z in { 0.5, 1.5, 2.5 } do
		cylinder(mesh, HX + 0.12, -HY + 0.12, z, 0.05, 0.25, "z", 8)
		cylinder(mesh, HX + 0.12, -HY + 0.12, z, 0.02, 0.33, "z", 6)
		box(mesh, HX + 0.07, -HY + 0.32, z - 0.08, 0.06, 0.38, 0.16)
		for _, dy in { 0.28, 0.44 } do
			bolt(mesh, HX + 0.1, -HY + dy, z, "x", 0.03)
		end
	end
	-- The ajar leaf hangs off its bottom hinge; the middle one has torn
	-- loose and the top one has snapped, leaving a stub on the frame.
	cylinder(mesh, HX + 0.12, HY - 0.05, 0.5, 0.05, 0.25, "z", 6)
	cylinder(onLeaf(mesh), HX + 0.12, HY - 0.05, 1.5, 0.05, 0.25, "z", 6)
	box(mesh, HX + 0.12, HY - 0.05, 2.45, 0.1, 0.1, 0.08)
	box(onLeaf(mesh), HX + 0.12, HY - 0.05, 2.4, 0.08, 0.08, 0.1)
	-- A crude strap plate welded from the corner post across to the leaf.
	local sx, sy, sz = leafAt(HX + 0.05, HY - 0.35, 2.3)
	strut(mesh, HX + 0.1, HY, 2.45, sx, sy, sz, 0.12)
	-- Wire lashing from the free top corner back to the corner casting.
	local fx, fy, fz = leafAt(HX + 0.04, 0.05, TOP - 0.25)
	rope(mesh, { { fx, fy, fz }, { (fx + HX) / 2 + 0.05, (fy + HY) / 2, (fz + TOP) / 2 - 0.15 }, { HX + 0.15, HY + 0.15, TOP - 0.12 } }, 0.025)
end, nil, 0.6)

part("DoorProp", nil, PLANK, function(mesh)
	-- A timber leaning in against the free edge to hold the leaf up, with a
	-- block wedged under its sagging corner.
	local px, py, pz = leafAt(HX + 0.08, 0.15, 2.1)
	local nx, ny = math.cos(DOOR_SWING), math.sin(DOOR_SWING)
	strut(mesh, px + nx * 1.3, py + ny * 1.3 - 0.2, 0, px, py, pz, 0.14)
	local bx, by = leafAt(HX + 0.1, 0.3, 0)
	box(mesh, bx, by, 0, 0.35, 0.3, 0.18)
end, nil, 0.7)

-- Oval twistlock holes in the outer faces of each corner casting.
part("CastingHoles", nil, DIM, function(mesh)
	for _, x in { -HX, HX } do
		for _, y in { -HY, HY } do
			for _, z in { 0, TOP - 0.25 } do
				box(mesh, x + math.sign(x) * 0.15, y, z + 0.07, 0.02, 0.07, 0.11)
				box(mesh, x, y + math.sign(y) * 0.15, z + 0.07, 0.11, 0.02, 0.11)
			end
			box(mesh, x, y, TOP + 0.001, 0.07, 0.13, 0.01)
		end
	end
end, nil, 0.2)

chunkedPart("Interior", nil, DIM, function(mesh)
	box(mesh, 0, 0, 0.15, 2 * HX - 0.2, 2 * HY - 0.2, 0.05)
	box(mesh, 0, HY - 0.12, OZ0, 2 * OX, 0.04, OZ1 - OZ0)
end, nil, 0.2)

chunkedPart("Flap", nil, PAINT, function(mesh)
	-- The cut panel hinged at the opening's top edge, propped out and down.
	local ribs = 18
	for k = 0, ribs - 1 do
		local x = -OX + (k + 0.5) * 2 * OX / ribs
		local lift = (k % 2) * 0.06
		strut(mesh, x, -HY - 0.08, OZ1 + 0.1 + lift, x, -HY - 2.2, OZ1 - 0.45 + lift, 2 * OX / ribs)
	end
end, nil, 0.7)

chunkedPart("FlapFrame", nil, DARK_STEEL, function(mesh)
	strut(mesh, -OX, -HY - 0.08, OZ1 + 0.02, OX, -HY - 0.08, OZ1 + 0.02, 0.12)
	strut(mesh, -OX, -HY - 2.2, OZ1 - 0.53, OX, -HY - 2.2, OZ1 - 0.53, 0.12)
	for _, x in { -OX, OX } do
		strut(mesh, x, -HY - 0.08, OZ1 + 0.02, x, -HY - 2.2, OZ1 - 0.53, 0.12)
	end
	-- Hinges.
	for _, x in { -2, 0, 2 } do
		cylinder(mesh, x, -HY - 0.1, OZ1 + 0.05, 0.07, 0.4, "x", 8)
		cylinder(mesh, x, -HY - 0.1, OZ1 + 0.05, 0.03, 0.5, "x", 6)
		for _, dx in { -0.12, 0.12 } do
			box(mesh, x + dx, -HY - 0.02, OZ1 + 0.05, 0.12, 0.08, 0.2)
			bolt(mesh, x + dx, -HY - 0.06, OZ1 + 0.15, "y", 0.025)
		end
	end
	-- Pipe legs with base plates and clamps.
	for _, x in { -OX + 0.2, OX - 0.2 } do
		cylinder(mesh, x, -HY - 2.05, (OZ1 - 0.5) / 2, 0.07, OZ1 - 0.5, "z", 8)
		box(mesh, x, -HY - 2.05, 0, 0.4, 0.4, 0.05)
		for _, d in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
			bolt(mesh, x + d[1] * 0.14, -HY - 2.05 + d[2] * 0.14, 0.05, "z", 0.04)
		end
		-- Saddle clamp gripping the flap's underside, with a gusset.
		cylinder(mesh, x, -HY - 2.05, OZ1 - 0.6, 0.1, 0.16, "z", 8)
		box(mesh, x, -HY - 2.05, OZ1 - 0.55, 0.26, 0.26, 0.06)
		strut(mesh, x, -HY - 2.05, OZ1 - 1.0, x, -HY - 1.75, OZ1 - 0.5, 0.05)
		ring(mesh, x, -HY - 2.05, 0.3, 0.07, 0.1, 0.06, "z", 8)
	end
	-- Taut chains from pad-eyes on the roof rail to pad-eyes on the flap's
	-- outer corners, each link hooked through the one before.
	local LINKS = 30
	for _, x in { -OX + 0.1, OX - 0.1 } do
		local y0, z0, y1, z1 = -HY - 0.06, TOP + 0.03, -HY - 2.1, OZ1 - 0.2
		for k = 0, LINKS do
			local t = k / LINKS
			local isEye = k == 0 or k == LINKS
			ring(mesh, x, y0 + (y1 - y0) * t, z0 + (z1 - z0) * t, if isEye then 0.025 else 0.03, if isEye then 0.06 else 0.055, if isEye then 0.04 else 0.025, if k % 2 == 0 then "x" else "z", 8)
		end
		box(mesh, x, y0, TOP - 0.03, 0.05, 0.1, 0.05)
		box(mesh, x, y1, z1 - 0.1, 0.05, 0.12, 0.08)
	end
end, nil, 0.6)

chunkedPart("Counter", nil, PLANK, function(mesh)
	for k = 0, 3 do
		box(mesh, 0, -HY - 0.55 + k * 0.24, OZ0 + 0.02, 2 * OX - 0.1, 0.22, 0.08)
	end
	-- Rounded front lip and battens under the planks.
	cylinder(mesh, 0, -HY - 0.66, OZ0 + 0.06, 0.05, 2 * OX - 0.1, "x", 8)
	for _, x in { -OX + 0.2, 0, OX - 0.2 } do
		box(mesh, x, -HY - 0.2, OZ0 - 0.06, 0.12, 0.8, 0.08)
	end
	-- Inner shelves on the back wall.
	for _, z in { 1.6, 2.3 } do
		box(mesh, 0, HY - 0.35, z, 2 * OX - 0.4, 0.5, 0.06)
		box(mesh, 0, HY - 0.6, z - 0.04, 2 * OX - 0.4, 0.04, 0.12)
	end
	-- Workbench at the left end.
	for k = 0, 3 do
		box(mesh, -3.2, -0.2 + k * 0.4, 1.0, 1.2, 0.38, 0.1)
	end
	box(mesh, -3.2, 0.4, 0.4, 1.0, 1.4, 0.04)
	-- Battens under the bench planks, resting on the leg tops.
	for _, x in { -3.65, -2.75 } do
		box(mesh, x, 0.4, 0.92, 0.1, 1.58, 0.09)
	end
end, nil, 0.3)

part("CounterIron", nil, DARK_STEEL, function(mesh)
	box(mesh, 0, -HY - 0.6, OZ0, 2 * OX, 0.05, 0.12)
	for _, x in { -2.3, -0.8, 0.8, 2.3 } do
		strut(mesh, x, -HY - 0.05, OZ0 - 0.5, x, -HY - 0.5, OZ0, 0.06)
	end
	for _, z in { 1.6, 2.3 } do
		for _, x in { -2, 0, 2 } do
			strut(mesh, x, HY - 0.08, z - 0.3, x, HY - 0.5, z, 0.04)
		end
	end
	for _, x in { -3.7, -2.7 } do
		for _, y in { -0.3, 1.1 } do
			box(mesh, x, y, 0.15, 0.08, 0.08, 0.85)
		end
	end
	-- Nail heads where the planks cross their battens.
	for k = 0, 3 do
		for _, x in { -OX + 0.2, 0, OX - 0.2 } do
			bolt(mesh, x, -HY - 0.55 + k * 0.24, OZ0 + 0.1, "z", 0.02)
		end
		for _, x in { -3.65, -2.75 } do
			bolt(mesh, x, -0.2 + k * 0.4, 1.1, "z", 0.02)
		end
	end
	-- Bench vice.
	box(mesh, -2.75, -0.25, 1.09, 0.3, 0.2, 0.22)
	cylinder(mesh, -2.75, -0.45, 1.2, 0.03, 0.3, "y", 6)
end, nil, 0.6)

part("Wares", nil, STEEL, function(mesh)
	-- Spanners laid out on the counter.
	for k = 0, 4 do
		local x = -2.2 + k * 0.42
		strut(mesh, x, -HY - 0.6, OZ0 + 0.13, x + 0.12, -HY - 0.1, OZ0 + 0.13, 0.06)
		ring(mesh, x + 0.14, -HY - 0.02, OZ0 + 0.13, 0.04, 0.09, 0.04, "z", 8)
	end
	-- Pipe lengths and a hacksaw.
	for k = 0, 2 do
		cylinder(mesh, 1.2, -HY - 0.45 + k * 0.14, OZ0 + 0.17, 0.07, 1.6, "x", 8)
	end
	strut(mesh, 0.2, -HY - 0.2, OZ0 + 0.13, 0.9, -HY - 0.2, OZ0 + 0.13, 0.03)
	strut(mesh, 0.2, -HY - 0.2, OZ0 + 0.13, 0.2, -HY - 0.2, OZ0 + 0.35, 0.04)
	strut(mesh, 0.9, -HY - 0.2, OZ0 + 0.13, 0.9, -HY - 0.2, OZ0 + 0.35, 0.04)
	strut(mesh, 0.2, -HY - 0.2, OZ0 + 0.35, 0.9, -HY - 0.2, OZ0 + 0.35, 0.04)
	-- Shelf stock: blades, cans, gears and bars.
	for k = 0, 5 do
		cylinder(mesh, -2.2 + k * 0.85, HY - 0.35, 1.8, 0.13, 0.3, "z", 8)
		ring(mesh, -2.2 + k * 0.85, HY - 0.35, 1.95, 0.1, 0.14, 0.03, "z", 8)
	end
	for k = 0, 3 do
		gear(mesh, -2 + k * 1.3, HY - 0.25, 2.58, 0.25, 0.06, 9, "y")
	end
	for k = 0, 5 do
		strut(mesh, 1 + k * 0.1, HY - 0.35, 2.34, 1 + k * 0.1, HY - 0.35, 2.34 + 0.4, 0.05)
	end
	-- Grinder on the bench.
	cylinder(mesh, -3.4, 0.6, 1.3, 0.12, 0.4, "x", 10)
	cylinder(mesh, -3.4, 0.6, 1.3, 0.2, 0.03, "x", 14)
	-- Motor body bolted to a foot plate, with a half guard over the disc.
	box(mesh, -3.4, 0.6, 1.08, 0.3, 0.2, 0.12)
	cylinder(mesh, -3.4, 0.82, 1.3, 0.1, 0.32, "y", 10)
	box(mesh, -3.4, 0.82, 1.08, 0.14, 0.18, 0.14)
	for _, dx in { -0.11, 0.11 } do
		bolt(mesh, -3.4 + dx, 0.6, 1.2, "z", 0.025)
	end
	ring(mesh, -3.4, 0.6, 1.3, 0.21, 0.24, 0.05, "x", 14)
end, nil, 0.5)

part("Roof", nil, DARK_STEEL, function(mesh)
	-- Vent stack and a cable run to the sign.
	cylinder(mesh, 2.8, 0.7, TOP + 0.35, 0.18, 0.7, "z", 10)
	ring(mesh, 2.8, 0.7, TOP + 0.05, 0.18, 0.26, 0.06, "z", 10)
	ring(mesh, 2.8, 0.7, TOP + 0.55, 0.18, 0.21, 0.04, "z", 10)
	for a = 0, 2 do
		local r = a * 2 * math.pi / 3
		strut(mesh, 2.8 + math.cos(r) * 0.17, 0.7 + math.sin(r) * 0.17, TOP + 0.68, 2.8 + math.cos(r) * 0.22, 0.7 + math.sin(r) * 0.22, TOP + 0.76, 0.03)
	end
	cylinder(mesh, 2.8, 0.7, TOP + 0.8, 0.3, 0.06, "z", 10)
	cylinder(mesh, 2.8, 0.7, TOP + 0.86, 0.15, 0.06, "z", 10)
	tube(mesh, { { 2.6, 0.7, TOP + 0.05 }, { 1.8, 0.4, TOP + 0.08 }, { 1.7, -0.25, TOP + 0.4 }, { 1.6, -0.3, TOP + 1.0 } }, 0.03, 6)
	-- Drum on the roof.
	cylinder(mesh, -3, 0.6, TOP + 0.45, 0.4, 0.9, "z", 14)
	for _, z in { TOP + 0.02, TOP + 0.3, TOP + 0.6, TOP + 0.88 } do
		ring(mesh, -3, 0.6, z, 0.4, 0.43, 0.05, "z", 14)
	end
	cylinder(mesh, -2.82, 0.6, TOP + 0.92, 0.06, 0.04, "z", 8)
end, nil, 0.7)

-- Wire sags from the flap's front rail; bulbs hang straight off it.
local function wireZ(x)
	return OZ1 - 0.58 - math.sin((x + OX) / (2 * OX) * math.pi) * 0.9
end

part("Bulbs", nil, GLOW, function(mesh)
	for k = 0, 8 do
		local x = -OX + 0.3 + k * (2 * OX - 0.6) / 8
		sphere(mesh, x, -HY - 2.2, wireZ(x) - 0.09, 0.07, 0.07, 0.1, 4, 6)
	end
end, nil, 0, nil, 0.5)

part("Wire", nil, RUBBER_BLACK, function(mesh)
	local points = {}
	for k = 0, 16 do
		local x = -OX + k * 2 * OX / 16
		table.insert(points, { x, -HY - 2.2, wireZ(x) })
	end
	tube(mesh, points, 0.02, 4)
	-- Lamp holders clamped on the wire, each holding its bulb.
	for k = 0, 8 do
		local x = -OX + 0.3 + k * (2 * OX - 0.6) / 8
		cylinder(mesh, x, -HY - 2.2, wireZ(x) - 0.03, 0.035, 0.08, "z", 6)
	end
end, nil, 0.1)

