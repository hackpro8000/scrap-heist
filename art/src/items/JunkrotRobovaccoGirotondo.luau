-- Robovacco Girotondo: a robot vacuum up on its side like a wheel, a
-- glossy white disc domed toward us, a grey bumper band round its rim, the
-- dark sensor turret standing out of its middle for a nose, a green start
-- button below it and one yellow side brush still spinning at its lower
-- edge. 3.3 studs tall.
-- include: JunkrotKit
local FACE = { { -0.36, -0.36, 2.15, 0.22 }, { 0.36, -0.36, 2.17, 0.22 } }
local FEET = { 0.9, 0.55 }
local MID = 1.78
part("Disc", nil, { 0.94, 0.95, 0.97 }, function(mesh)
	local m = Kit.lathe({ { 0, -0.22 }, { 1.12, -0.22 }, { 1.2, -0.15 }, { 1.22, 0.1 }, { 1.12, 0.2 }, { 0.6, 0.27 }, { 0, 0.3 } }, 32)
	Kit.turn(m, "x", 90)
	m:translate(0, 0, MID)
	m:emit(mesh)
end, true, 0)
part("Bumper", nil, { 0.4, 0.42, 0.45 }, function(mesh)
	local m = EditMesh.torus(1.2, 0.1, 32, 8)
	Kit.size(m, { 1, 1, 1.6 })
	Kit.turn(m, "x", 90)
	m:translate(0, 0, MID)
	m:emit(mesh)
end, true, 0)
part("Turret", nil, { 0.12, 0.12, 0.14 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.24, 0 }, { 0.24, 0.14 }, { 0.18, 0.2 }, { 0, 0.21 } }, 16)
	Kit.turn(m, "x", 90)
	m:translate(0, -0.27, MID - 0.05)
	m:emit(mesh)
end, true, 0)
part("Button", nil, { 0.3, 0.9, 0.5 }, function(mesh)
	local m = EditMesh.cylinder(0.1, 0.05, 12, 1)
	Kit.turn(m, "x", 90)
	m:translate(0, -0.27, MID - 0.55)
	m:emit(mesh)
end, true, 0, nil, 0.8)
part("Brush", nil, { 0.95, 0.75, 0.1 }, function(mesh)
	local hub = EditMesh.cylinder(0.08, 0.08, 8, 1)
	Kit.turn(hub, "x", 90)
	hub:translate(0.7, -0.22, MID - 0.85)
	hub:emit(mesh)
	for k = 0, 2 do
		local bristle = Kit.plate({ { -0.03, 0 }, { 0.03, 0 }, { 0.06, 0.45 }, { -0.06, 0.45 } }, 0.02)
		Kit.turn(bristle, "y", 120 * k + 20)
		bristle:translate(0.7, -0.26, MID - 0.85)
		bristle:emit(mesh)
	end
end, 40, 0)
part("Wheels", nil, RUBBER_BLACK, function(mesh)
	-- Its underside faces the back: two drive wheels and the brush roll.
	for _, x in { -0.6, 0.6 } do
		local wheel = Kit.lathe({ { 0, -0.06 }, { 0.15, -0.06 }, { 0.2, 0 }, { 0.15, 0.06 }, { 0, 0.06 } }, 12)
		Kit.turn(wheel, "y", 90)
		wheel:translate(x, 0.3, MID)
		wheel:emit(mesh)
	end
	local roll = EditMesh.capsule(0.08, 0.6, 8)
	Kit.turn(roll, "y", 90)
	roll:translate(0, 0.27, MID - 0.45)
	roll:emit(mesh)
end, true, RUBBER)
-- include: JunkrotFace
