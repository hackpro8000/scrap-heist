-- Gear Panel: a steampunk wall panel about 6.8 studs square and 0.6 deep, built from the approved
-- sketch. A copper pipe frame round the edge with collars and corner bolts, nine brass and steel
-- gears stacked at different depths, each with a hub and spokes, two riveted steel boilers down
-- the right side and a brass dial bottom left. Centred on the origin, facing -y, with z up.
local BRASS = { 0.78, 0.6, 0.3 }
local PIPE_RADIUS = 0.13
local PIPE_AT = 3.25
local PANEL_HALF = PIPE_AT + PIPE_RADIUS
local PLATE_Y = 0.42
local PLATE_FRONT = PLATE_Y - 0.03

-- A gear with a hub and `spokes` beams running from the hub out to the teeth, all in the plane
-- across `axis`, so it reads as a spoked wheel from the game camera.
local function spokedGear(mesh, cx, cy, cz, radius, thick, teeth, spokes, axis)
	gear(mesh, cx, cy, cz, radius, thick, teeth, axis)
	local hub = radius * 0.3
	cylinder(mesh, cx, cy, cz, hub, thick * 1.4, axis, 10)
	for k = 0, spokes - 1 do
		local t = k / spokes * TAU
		local ax, ay, az = onAxis(cx, cy, cz, axis, hub * 0.8, t, 0)
		local bx, by, bz = onAxis(cx, cy, cz, axis, radius * 0.8, t, 0)
		strut(mesh, ax, ay, az, bx, by, bz, radius * 0.12)
	end
end

-- A ring of rivets round a cylinder along `axis`, at `z` along the axis of the boiler.
local function rivetBand(mesh, cx, cy, cz, radius, axis, count, size)
	for k = 0, count - 1 do
		local t = k / count * TAU
		local x, y, z = onAxis(cx, cy, cz, axis, radius, t, 0)
		stud(mesh, x, y, z, (x - cx) / radius, (y - cy) / radius, (z - cz) / radius, size)
	end
end

-- The dark back plate the gears and frame are mounted on, with a rivet along each edge and a
-- bolt in each corner.
part("BackPlate", nil, DARK_STEEL, function(mesh)
	box(mesh, 0, PLATE_Y, 0, PANEL_HALF * 2, 0.06, PANEL_HALF * 2)
	for k = -3, 3 do
		local p = k * 0.9
		stud(mesh, p, PLATE_FRONT, PANEL_HALF - 0.12, 0, -1, 0, 0.05)
		stud(mesh, p, PLATE_FRONT, -PANEL_HALF + 0.12, 0, -1, 0, 0.05)
		stud(mesh, PANEL_HALF - 0.12, PLATE_FRONT, p, 0, -1, 0, 0.05)
		stud(mesh, -PANEL_HALF + 0.12, PLATE_FRONT, p, 0, -1, 0, 0.05)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			bolt(mesh, sx * (PANEL_HALF - 0.2), PLATE_FRONT, sz * (PANEL_HALF - 0.2), "y", 0.1)
		end
	end
end, nil, 0.8)

-- Four straight copper pipes with a collar at each end and at the middle of each run, and a joint
-- at each corner.
part("Frame", nil, COPPER, function(mesh)
	local corners = { { -PIPE_AT, 0.3, PIPE_AT }, { PIPE_AT, 0.3, PIPE_AT }, { PIPE_AT, 0.3, -PIPE_AT }, { -PIPE_AT, 0.3, -PIPE_AT } }
	for i, a in corners do
		local b = corners[i % 4 + 1]
		tube(mesh, { a, b }, PIPE_RADIUS, 10)
		sphere(mesh, a[1], a[2], a[3], PIPE_RADIUS * 1.5, PIPE_RADIUS * 1.5, PIPE_RADIUS * 1.5, 6, 10)
		local mx, my, mz = (a[1] + b[1]) / 2, a[2], (a[3] + b[3]) / 2
		ring(mesh, mx, my, mz, PIPE_RADIUS, PIPE_RADIUS * 1.7, 0.1, if math.abs(b[1] - a[1]) > 0 then "x" else "z", 10)
	end
end, nil, 0.7)

-- Large brass gears, the top two and the bottom right, each spoked.
part("LargeGears", nil, BRASS, function(mesh)
	spokedGear(mesh, -1.42, 0.1, 1.97, 1.48, 0.3, 14, 5, "y")
	spokedGear(mesh, 0.66, 0.0, 2.44, 1.64, 0.3, 16, 6, "y")
	spokedGear(mesh, 1.6, -0.1, -1.07, 1.41, 0.3, 14, 5, "y")
end, nil, 0.5)

-- Medium brass gears through the middle and bottom left, each spoked.
part("MediumGears", nil, BRASS, function(mesh)
	spokedGear(mesh, -1.19, 0.05, -2.1, 1.17, 0.26, 12, 4, "y")
	spokedGear(mesh, 0.61, -0.05, 0.09, 0.94, 0.26, 12, 4, "y")
	spokedGear(mesh, 0.45, 0.1, -1.3, 0.86, 0.24, 10, 4, "y")
	spokedGear(mesh, -0.56, -0.1, 0.33, 0.7, 0.22, 9, 3, "y")
	spokedGear(mesh, 1.45, 0.0, 0.7, 0.63, 0.2, 9, 3, "y")
end, nil, 0.5)

-- The steel-rimmed gear at the bottom, with a rim standing proud of its teeth, a spoked hub and a
-- rivet on the rim.
part("SteelGear", nil, STEEL, function(mesh)
	spokedGear(mesh, 0.38, -0.15, -3.0, 0.7, 0.24, 9, 3, "y")
	ring(mesh, 0.38, -0.15, -3.0, 0.62, 0.8, 0.14, "y", 14)
	rivetBand(mesh, 0.38, -0.15, -3.0, 0.71, "y", 6, 0.04)
end, nil, 0.4)

-- Two riveted steel boilers on the right: a tall one above and a longer one below, each with rivet
-- bands at its ends and a cap.
part("Boilers", nil, STEEL, function(mesh)
	cylinder(mesh, 2.6, -0.2, 2.2, 0.6, 1.8, "z", 14)
	sphere(mesh, 2.6, -0.2, 3.1, 0.6, 0.6, 0.5, 6, 14)
	cylinder(mesh, 2.6, -0.2, -0.4, 0.75, 2.8, "z", 14)
	ring(mesh, 2.6, -0.2, -0.4, 0.75, 0.85, 0.12, "z", 14)
	ring(mesh, 2.6, -0.2, -1.0, 0.75, 0.85, 0.12, "z", 14)
	for _, z in { 1.5, 2.9 } do
		rivetBand(mesh, 2.6, -0.2, z, 0.6, "z", 12, 0.04)
	end
	for _, z in { -1.9, 0.2, 0.9 } do
		rivetBand(mesh, 2.6, -0.2, z, 0.75, "z", 14, 0.045)
	end
end, nil, 0.6)

-- Brass dial at the bottom left: a rim, a face, twelve ticks, a hand and a centre pin.
part("Dial", nil, BRASS, function(mesh)
	local cx, cy, cz = -2.35, -0.2, -1.6
	ring(mesh, cx, cy, cz, 0.8, 0.95, 0.16, "y", 16)
	cylinder(mesh, cx, cy - 0.1, cz, 0.8, 0.1, "y", 16)
	cylinder(mesh, cx, cy - 0.3, cz, 0.12, 0.1, "y", 8)
	for k = 0, 11 do
		local t = k / 12 * TAU
		local ax, ay, az = onAxis(cx, cy - 0.2, cz, "y", 0.62, t, 0)
		local bx, by, bz = onAxis(cx, cy - 0.2, cz, "y", 0.74, t, 0)
		strut(mesh, ax, ay, az, bx, by, bz, 0.04)
	end
	strut(mesh, cx, cy - 0.3, cz, cx + 0.4, cy - 0.3, cz + 0.3, 0.04)
end, nil, 0.45)

finishParts()
