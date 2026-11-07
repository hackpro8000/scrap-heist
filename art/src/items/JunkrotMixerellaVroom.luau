-- Mixerella Vroom: a stand mixer in fresh cherry red, a rounded foot with a
-- column up the back, the head tipped forward over a polished bowl with a
-- handle, a balloon whisk down into it from the head's hub, and the speed
-- knob on its side. 3.4 studs tall.
-- include: JunkrotKit
local FACE = { { -0.22, -1.03, 2.98, 0.18 }, { 0.22, -1.03, 3.0, 0.18 } }
local FEET = { 1.0, 0.5 }
local CHERRY = { 0.82, 0.12, 0.16 }
local BASE = 0.55
local HEAD = BASE + 2.35 -- the head's middle
part("Stand", nil, CHERRY, function(mesh)
	local foot = Kit.block(1.3, 2.0, 0.3, 0.12)
	foot:translate(0, -0.2, BASE + 0.15)
	foot:emit(mesh)
	local column = Kit.block(0.75, 0.6, 1.9, 0.25)
	column:translate(0, 0.55, BASE + 1.2)
	column:emit(mesh)
end, 50, 0.15)
part("Head", nil, CHERRY, function(mesh)
	local m = EditMesh.sphere(1, 16)
	Kit.size(m, { 0.48, 0.95, 0.45 })
	Kit.turn(m, "x", 8)
	m:translate(0, -0.15, HEAD)
	m:emit(mesh)
	local hub = EditMesh.cylinder(0.14, 0.2, 12, 1)
	hub:translate(0, -0.65, HEAD - 0.42)
	hub:emit(mesh)
end, true, 0.12)
part("Bowl", nil, BARE_METAL, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.35, 0 }, { 0.55, 0.25 }, { 0.62, 0.6 }, { 0.65, 0.65 }, { 0.6, 0.65 }, { 0.55, 0.3 }, { 0.34, 0.06 }, { 0, 0.06 } }, 20)
	m:translate(0, -0.6, BASE + 0.3)
	m:emit(mesh)
	Kit.tube(Kit.curve({ { 0.6, -0.6, BASE + 0.82 }, { 0.85, -0.6, BASE + 0.75 }, { 0.58, -0.6, BASE + 0.5 } }, 3), 0.045, 6):emit(mesh)
end, true, 0.05)
part("Whisk", nil, BARE_METAL, function(mesh)
	for k = 0, 2 do
		local a = math.rad(k * 60)
		local c, s = math.cos(a) * 0.25, math.sin(a) * 0.25
		local path = Kit.curve({ { -c, -0.6 - s, HEAD - 0.5 }, { -c * 1.2, -0.6 - s * 1.2, BASE + 1.2 }, { 0, -0.6, BASE + 0.62 }, { c * 1.2, -0.6 + s * 1.2, BASE + 1.2 }, { c, -0.6 + s, HEAD - 0.5 } }, 4)
		Kit.tube(path, 0.018, 4):emit(mesh)
	end
end, true, 0.05)
part("Knob", nil, { 0.95, 0.93, 0.86 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.12, 0 }, { 0.1, 0.1 }, { 0, 0.11 } }, 12)
	Kit.turn(m, "y", 90)
	m:translate(0.45, 0.2, HEAD)
	m:emit(mesh)
end, true, 0.05)
-- include: JunkrotFace
