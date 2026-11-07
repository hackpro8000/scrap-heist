-- Leafblowa Whooshini: a leaf blower in hi-vis orange, a round fan housing
-- with a black grille of bars over its intake, a loop handle on top and a
-- long black nozzle out one side, flaring at its mouth, a couple of leaves
-- caught in its draught. 3 studs tall, 4 long.
-- include: JunkrotKit
-- floats: Leaves
local FACE = { { -0.82, -0.45, 1.98, 0.2 }, { -0.28, -0.45, 2.0, 0.2 } }
local FEET = { 1.0, 0.6 }
local HIVIS = { 1.0, 0.5, 0.08 }
local MX, MZ = -0.55, 1.62 -- the housing's middle
part("Housing", nil, HIVIS, function(mesh)
	local m = Kit.lathe({ { 0, -0.36 }, { 0.82, -0.36 }, { 0.9, -0.28 }, { 0.92, 0 }, { 0.9, 0.28 }, { 0.82, 0.36 }, { 0, 0.36 } }, 24)
	Kit.turn(m, "x", 90)
	m:translate(MX, 0, MZ)
	m:emit(mesh)
end, true, 0.03)
part("Grille", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	local disc = Kit.lathe({ { 0, 0 }, { 0.5, 0 }, { 0.5, 0.03 }, { 0, 0.03 } }, 20)
	Kit.turn(disc, "x", 90)
	disc:translate(MX, -0.36, MZ - 0.12)
	disc:emit(mesh)
	for k = -2, 2 do
		local bar = Kit.block(0.95, 0.04, 0.05, 0.02)
		bar:translate(MX, -0.4, MZ - 0.12 + k * 0.18)
		bar:emit(mesh)
	end
end, 50, 0)
part("Handle", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	local path = Kit.curve({ { MX - 0.45, 0, MZ + 0.82 }, { MX - 0.4, 0, MZ + 1.2 }, { MX + 0.25, 0, MZ + 1.2 }, { MX + 0.35, 0, MZ + 0.8 } }, 4)
	Kit.tube(path, 0.08, 8):emit(mesh)
end, true, RUBBER)
part("Nozzle", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	local path = Kit.curve({ { MX + 0.75, 0, MZ - 0.15 }, { 0.8, 0, 1.35 }, { 1.6, 0, 1.15 }, { 2.05, 0, 1.08 } }, 4)
	Kit.tube(path, function(t)
		return if t > 0.9 then 0.16 + (t - 0.9) * 0.8 else 0.24 - 0.08 * t
	end, 12):emit(mesh)
end, true, 0)
part("Leaves", nil, { 0.55, 0.7, 0.2 }, function(mesh)
	for _, leaf in { { 2.45, -0.15, 1.3, 30 }, { 2.75, 0.1, 0.95, -20 } } do
		local m = Kit.plate({ { 0, -0.15 }, { 0.12, -0.05 }, { 0.1, 0.12 }, { 0, 0.18 }, { -0.1, 0.12 }, { -0.12, -0.05 } }, 0.02)
		Kit.turn(m, "y", leaf[4])
		m:translate(leaf[1], leaf[2], leaf[3])
		m:emit(mesh)
	end
end, 40, 0)
part("Trigger", nil, { 0.85, 0.15, 0.12 }, function(mesh)
	local m = Kit.block(0.15, 0.08, 0.18, 0.03)
	m:translate(MX - 0.05, 0, MZ + 1.05)
	m:emit(mesh)
end, 50, 0.03)
-- include: JunkrotFace
