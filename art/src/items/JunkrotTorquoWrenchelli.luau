-- Torquo Wrenchelli: a chrome torque wrench standing on its handle, the
-- black rubber grip at its foot, the long shaft up to the ratchet head
-- with its round boss, square drive and reversing lever, and a dial gauge
-- with a red needle on its chest. 4.1 studs tall.
-- include: JunkrotKit
local FACE = { { -0.16, -0.28, 3.68, 0.15 }, { 0.16, -0.28, 3.7, 0.15 } }
local FEET = { 0.5, 0.5 }
local BASE = 0.6
local HEAD = BASE + 3.0 -- the head's middle
local GAUGE = BASE + 2.0
part("Grip", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.24, 0 }, { 0.27, 0.08 }, { 0.25, 0.4 }, { 0.28, 0.75 }, { 0.22, 0.95 }, { 0, 0.95 } }, 16)
	m:translate(0, 0, BASE)
	m:emit(mesh)
end, true, RUBBER)
part("Shaft", nil, BARE_METAL, function(mesh)
	local shaft = Kit.lathe({ { 0, 0 }, { 0.16, 0 }, { 0.14, 1.9 }, { 0, 1.9 } }, 12)
	shaft:translate(0, 0, BASE + 0.9)
	shaft:emit(mesh)
	local head = Kit.block(0.55, 0.42, 0.62, 0.16)
	head:translate(0, 0, HEAD)
	head:emit(mesh)
	local boss = Kit.lathe({ { 0, 0 }, { 0.26, 0 }, { 0.26, 0.08 }, { 0, 0.1 } }, 16)
	Kit.turn(boss, "x", -90)
	boss:translate(0, 0.2, HEAD)
	boss:emit(mesh)
	local drive = Kit.block(0.14, 0.18, 0.14, 0.02)
	drive:translate(0, 0.38, HEAD)
	drive:emit(mesh)
	local lever = Kit.block(0.24, 0.08, 0.08, 0.02)
	Kit.turn(lever, "y", 15)
	lever:translate(0.05, 0, HEAD + 0.34)
	lever:emit(mesh)
	local bezel = EditMesh.torus(0.3, 0.035, 20, 6)
	Kit.turn(bezel, "x", 90)
	bezel:translate(0, -0.16, GAUGE)
	bezel:emit(mesh)
end, true, 0.03)
part("Gauge", nil, { 0.96, 0.96, 0.94 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.3, 0 }, { 0.3, 0.1 }, { 0, 0.1 } }, 20)
	Kit.turn(m, "x", 90)
	m:translate(0, -0.06, GAUGE)
	m:emit(mesh)
end, 40, 0)
part("Needle", nil, { 0.95, 0.15, 0.12 }, function(mesh)
	local m = Kit.plate({ { -0.02, -0.03 }, { 0.02, -0.03 }, { 0.008, 0.24 }, { -0.008, 0.24 } }, 0.015)
	Kit.turn(m, "y", 35)
	m:translate(0, -0.18, GAUGE)
	m:emit(mesh)
end, 40, 0)
-- include: JunkrotFace
