-- Dronetto Buzzatti: a quadcopter in matte grey, an oval pod of a body
-- with a hatch sunk into its top, four arms rising out to motor pods with
-- a two-bladed rotor on each, a camera ball under its chin and red and
-- green nav lights on its front pods. 2.6 studs tall, 3.6 across.
-- include: JunkrotKit
local FACE = { { -0.26, -0.84, 1.42, 0.19 }, { 0.26, -0.84, 1.44, 0.19 } }
local FEET = { 0.8, 0.72 }
local MID = 1.3
local CORNERS = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
local POD = 1.15 -- how far out the pods stand, along x and y
local POD_TOP = MID + 0.85
part("Body", nil, { 0.42, 0.44, 0.48 }, function(mesh)
	local m = EditMesh.sphere(1, 16)
	Kit.size(m, { 0.7, 0.8, 0.4 })
	local top = m:select("face", "facing", { 0, 0, 1 }, 25)
	if top:count() > 0 then
		Kit.recess(m, top, 0.05, 0.03)
	end
	m:translate(0, 0, MID)
	m:emit(mesh)
	for _, c in CORNERS do
		local arm = Kit.curve({ { c[1] * 0.35, c[2] * 0.4, MID + 0.05 }, { c[1] * 0.8, c[2] * 0.82, MID + 0.4 }, { c[1] * POD, c[2] * POD, MID + 0.62 } }, 3)
		Kit.tube(arm, 0.08, 8):emit(mesh)
		local pod = EditMesh.cylinder(0.15, 0.3, 12, 1)
		pod:translate(c[1] * POD, c[2] * POD, POD_TOP - 0.15)
		pod:emit(mesh)
	end
end, true, 0.03)
part("Rotors", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	for index, c in CORNERS do
		local hub = EditMesh.cylinder(0.06, 0.1, 8, 1)
		hub:translate(c[1] * POD, c[2] * POD, POD_TOP + 0.04)
		hub:emit(mesh)
		local blade = Kit.block(0.95, 0.12, 0.03, 0.015)
		Kit.turn(blade, "z", 25 + index * 40)
		blade:translate(c[1] * POD, c[2] * POD, POD_TOP + 0.09)
		blade:emit(mesh)
	end
end, 50, 0)
part("Camera", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	local ball = EditMesh.sphere(0.18, 12)
	ball:translate(0, -0.52, MID - 0.36)
	ball:emit(mesh)
end, true, 0)
part("NavRed", nil, { 1.0, 0.15, 0.1 }, function(mesh)
	local light = EditMesh.sphere(0.07, 8)
	light:translate(-POD, -POD - 0.16, POD_TOP - 0.15)
	light:emit(mesh)
end, true, 0, nil, 2.0)
part("NavGreen", nil, { 0.2, 1.0, 0.4 }, function(mesh)
	local light = EditMesh.sphere(0.07, 8)
	light:translate(POD, -POD - 0.16, POD_TOP - 0.15)
	light:emit(mesh)
end, true, 0, nil, 2.0)
part("Guards", nil, { 0.42, 0.44, 0.48 }, function(mesh)
	for _, c in CORNERS do
		local ring = EditMesh.torus(0.5, 0.025, 24, 4)
		ring:translate(c[1] * POD, c[2] * POD, POD_TOP + 0.09)
		ring:emit(mesh)
		Kit.tube({ { c[1] * POD, c[2] * POD, POD_TOP - 0.05 }, { c[1] * (POD + 0.35), c[2] * (POD + 0.35), POD_TOP + 0.09 } }, 0.02, 4):emit(mesh)
	end
	Kit.tube({ { 0, 0.3, MID + 0.36 }, { 0, 0.35, MID + 0.75 } }, 0.02, 4):emit(mesh)
	local tip = EditMesh.sphere(0.04, 6)
	tip:translate(0, 0.35, MID + 0.78)
	tip:emit(mesh)
end, true, 0.03)
-- include: JunkrotFace
