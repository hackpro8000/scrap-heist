-- Oilcanna Gluglu: a squat oil can, a wide drum with rolled rims and a
-- domed top, a thumb pump on a bracket at the back, a long thin spout out
-- of the top bent over at its end with a drip hanging off, and a loop
-- handle round the back. 3.2 studs tall.
-- include: JunkrotKit
local FACE = { { -0.32, -0.88, 1.32, 0.22 }, { 0.32, -0.88, 1.35, 0.23 } }
local FEET = { 0.9, 0.5 }
local CAN_GREEN = { 0.2, 0.42, 0.3 }
local BASE = 0.6
local TOP = BASE + 1.6
local SPOUT = { 0, -0.97, BASE + 2.36 } -- the spout's tip
part("Can", nil, CAN_GREEN, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.84, 0 }, { 0.9, 0.06 }, { 0.86, 0.12 }, { 0.86, 0.95 }, { 0.9, 1.0 }, { 0.84, 1.05 }, { 0.55, 1.35 }, { 0.22, 1.48 }, { 0.2, 1.6 }, { 0, 1.6 } }, 24)
	m:translate(0, 0, BASE)
	m:emit(mesh)
	local handle = Kit.curve({ { -0.35, 0.7, BASE + 1.15 }, { -0.3, 1.12, BASE + 0.92 }, { 0, 1.22, BASE + 0.7 }, { 0.3, 1.12, BASE + 0.92 }, { 0.35, 0.7, BASE + 1.15 } }, 3)
	Kit.tube(handle, 0.06, 8):emit(mesh)
end, true, 0.6)
part("Spout", nil, STEEL, function(mesh)
	local path = Kit.curve({ { 0, 0, TOP - 0.05 }, { 0, -0.15, TOP + 0.45 }, { 0, -0.45, TOP + 0.75 }, { 0, -0.78, TOP + 0.78 }, { SPOUT[1], SPOUT[2], SPOUT[3] } }, 4)
	Kit.tube(path, function(t)
		return 0.1 - 0.06 * t
	end, 8):emit(mesh)
end, true, 0.5)
part("Pump", nil, STEEL, function(mesh)
	local barrel = EditMesh.cylinder(0.12, 0.4, 12, 1)
	barrel:translate(0, 0.45, BASE + 1.45)
	barrel:emit(mesh)
	local lever = Kit.block(0.12, 0.5, 0.06, 0.02)
	Kit.turn(lever, "x", 20)
	lever:translate(0, 0.35, BASE + 1.72)
	lever:emit(mesh)
end, 40, 0.5)
part("Drip", nil, { 0.1, 0.08, 0.05 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.06, 0.04 }, { 0.07, 0.1 }, { 0.03, 0.2 }, { 0, 0.25 } }, 12)
	m:translate(SPOUT[1], SPOUT[2], SPOUT[3] - 0.27)
	m:emit(mesh)
end, true, 0)
part("Label", nil, { 0.9, 0.85, 0.7 }, function(mesh)
	local m = EditMesh.tube(0.875, 0.85, 0.34, 24)
	m:translate(0, 0, BASE + 0.42)
	m:emit(mesh)
end, true, 0.5)
-- include: JunkrotFace
