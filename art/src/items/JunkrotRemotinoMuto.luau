-- Remotino Muto: a dead TV remote standing on end, a rounded body a little
-- wider at the top, a red power button and a dark sensor window up top, a
-- grid of rubber buttons down its front, and its battery door gone: two
-- copper batteries showing in the bay sunk into its back. 3 studs tall.
-- include: JunkrotKit
local FACE = { { -0.17, -0.22, 2.33, 0.15 }, { 0.17, -0.22, 2.35, 0.15 } }
local FEET = { 0.5, 0.55 }
local BASE = 0.6
local TALL = 2.1
part("Body", nil, { 0.16, 0.16, 0.18 }, function(mesh)
	local m = Kit.block(0.74, 0.3, TALL, 0.12, { 2, 1, 6 })
	m:taper("z", 0.9, 1.05)
	local bay = m:select("face", "facing", { 0, 1, 0 }, 20):filter(function(p)
		return p[3] > -TALL / 2 + 0.2 and p[3] < -0.1 and math.abs(p[1]) < 0.3
	end)
	if bay:count() > 0 then
		Kit.recess(m, bay, 0.03, 0.08)
	end
	m:translate(0, 0, BASE + TALL / 2)
	m:emit(mesh)
end, 50, 0.5)
part("Buttons", nil, { 0.55, 0.55, 0.58 }, function(mesh)
	for row = 0, 3 do
		for column = -1, 1 do
			local b = Kit.block(0.13, 0.06, 0.1, 0.03)
			b:translate(column * 0.2, -0.155, BASE + 0.4 + row * 0.22)
			b:emit(mesh)
		end
	end
end, 50, 0.4)
part("Power", nil, { 0.9, 0.16, 0.12 }, function(mesh)
	local m = EditMesh.cylinder(0.07, 0.06, 12, 1)
	Kit.turn(m, "x", 90)
	m:translate(0.18, -0.17, BASE + TALL - 0.22)
	m:emit(mesh)
end, true, 0.2)
part("Window", nil, { 0.05, 0.05, 0.06 }, function(mesh)
	local m = Kit.block(0.4, 0.04, 0.12, 0.02)
	m:translate(0, -0.15, BASE + TALL - 0.06)
	m:emit(mesh)
end, 50, 0)
part("Battery", nil, COPPER, function(mesh)
	for _, x in { -0.09, 0.09 } do
		local m = EditMesh.capsule(0.07, 0.38, 8)
		m:translate(x, 0.1, BASE + 0.62)
		m:emit(mesh)
	end
end, true, 0.7)
-- include: JunkrotFace
