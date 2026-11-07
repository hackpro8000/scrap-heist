-- Telefono Ringaling: a rotary phone in fresh red, a rounded body sloping
-- forward to the cream dial on its chest with its ring of finger holes and
-- the steel finger stop, the handset lying across its head in the
-- cradle's two forks, and the coiled cord trailing off its side. 2.8 studs
-- tall.
-- include: JunkrotKit
local FACE = { { -0.5, -0.82, 1.12, 0.17 }, { 0.5, -0.82, 1.14, 0.17 } }
local FEET = { 1.1, 0.5 }
local PHONE_RED = { 0.8, 0.14, 0.14 }
local BASE = 0.55
local DIAL = { 0, -0.45, BASE + 0.83 } -- the dial's middle
local SLOPE = 19 -- degrees the dial faces forward
part("Base", nil, PHONE_RED, function(mesh)
	local m = Kit.block(1.7, 1.5, 0.95, 0.3, { 2, 3, 1 })
	m:transform(function(p)
		local front = math.clamp(-p[2] / 0.75, 0, 1)
		return { p[1], p[2], p[3] - front * math.max(0, p[3] + 0.1) * 0.45 }
	end)
	m:translate(0, 0, BASE + 0.475)
	m:emit(mesh)
end, 50, 0.12)
-- Lays a piece built facing up (+z) on the dial's face.
local function onDial(m)
	Kit.turn(m, "x", SLOPE)
	m:translate(DIAL[1], DIAL[2], DIAL[3])
	return m
end
part("Dial", nil, { 0.93, 0.9, 0.82 }, function(mesh)
	onDial(Kit.lathe({ { 0, 0 }, { 0.38, 0 }, { 0.38, 0.04 }, { 0.1, 0.05 }, { 0, 0.07 } }, 24)):emit(mesh)
end, 40, 0.05)
part("Holes", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	for k = 0, 9 do
		local a = math.rad(60 + k * 27)
		local hole = EditMesh.cylinder(0.05, 0.03, 8, 1)
		hole:translate(math.cos(a) * 0.27, math.sin(a) * 0.27, 0.045)
		onDial(hole):emit(mesh)
	end
end, true, 0.05)
part("Cradle", nil, BARE_METAL, function(mesh)
	for _, x in { -0.45, 0.45 } do
		Kit.tube({ { x, 0.15, BASE + 0.9 }, { x, 0.15, BASE + 1.2 } }, 0.05, 6):emit(mesh)
	end
	local stop = Kit.block(0.05, 0.12, 0.04, 0.01)
	stop:translate(0.25, -0.25, 0.06)
	onDial(stop):emit(mesh)
end, true, 0.05)
part("Handset", nil, PHONE_RED, function(mesh)
	Kit.tube(Kit.curve({ { -0.62, 0.15, BASE + 1.3 }, { 0, 0.15, BASE + 1.45 }, { 0.62, 0.15, BASE + 1.3 } }, 4), 0.11, 10):emit(mesh)
	for _, x in { -0.62, 0.62 } do
		local cup = Kit.lathe({ { 0, 0 }, { 0.2, 0 }, { 0.22, 0.12 }, { 0.15, 0.22 }, { 0, 0.22 } }, 12)
		Kit.turn(cup, "x", 180)
		cup:translate(x, 0.15, BASE + 1.42)
		cup:emit(mesh)
	end
end, true, 0.12)
part("Cord", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	local coil = EditMesh.coil(0.07, 0.022, 7, 0.09, 6, 12)
	Kit.turn(coil, "x", 180)
	coil:translate(0.95, 0.3, BASE + 1.25)
	coil:emit(mesh)
end, true, RUBBER)
part("Plungers", nil, BARE_METAL, function(mesh)
	for _, x in { -0.2, 0.2 } do
		local m = EditMesh.cylinder(0.06, 0.12, 8, 1)
		m:translate(x, 0.15, BASE + 0.96)
		m:emit(mesh)
	end
end, true, 0.05)
-- include: JunkrotFace
