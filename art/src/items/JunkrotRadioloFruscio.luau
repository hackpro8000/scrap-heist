-- Radiolo Fruscio: a crackly portable radio, a rounded case with a carry
-- handle over it, a sunk speaker grille with slats across it for a belly,
-- a tuning window with its red needle and two knobs beside it, and a bent
-- telescopic aerial with a ball on its tip. 3.4 studs tall.
-- include: JunkrotKit
local FACE = { { -0.3, -0.47, 1.62, 0.2 }, { 0.3, -0.47, 1.64, 0.21 } }
local FEET = { 1.2, 0.55 }
local BASE = 0.55
local TALL = 1.35
local TOP = BASE + TALL
part("Case", nil, { 0.6, 0.36, 0.2 }, function(mesh)
	local m = Kit.block(1.9, 0.8, TALL, 0.16)
	m:translate(0, 0, BASE + TALL / 2)
	m:emit(mesh)
	local handle = Kit.curve({ { -0.6, 0, TOP - 0.05 }, { -0.5, 0, TOP + 0.3 }, { 0.5, 0, TOP + 0.3 }, { 0.6, 0, TOP - 0.05 } }, 3)
	Kit.tube(handle, 0.06, 8):emit(mesh)
end, 50, 0.5)
part("Grille", nil, { 0.2, 0.2, 0.21 }, function(mesh)
	local panel = Kit.block(1.0, 0.06, 0.55, 0.05)
	panel:translate(-0.3, -0.41, BASE + 0.42)
	panel:emit(mesh)
	for k = 0, 3 do
		local slat = Kit.block(0.92, 0.05, 0.05, 0.02)
		slat:translate(-0.3, -0.45, BASE + 0.25 + k * 0.12)
		slat:emit(mesh)
	end
end, 50, 0.4)
part("Dials", nil, { 0.85, 0.82, 0.72 }, function(mesh)
	for _, z in { BASE + 0.3, BASE + 0.62 } do
		local knob = Kit.lathe({ { 0, 0 }, { 0.12, 0 }, { 0.11, 0.08 }, { 0, 0.1 } }, 12)
		Kit.turn(knob, "x", 90)
		knob:translate(0.62, -0.4, z)
		knob:emit(mesh)
	end
	local window = Kit.block(0.5, 0.04, 0.2, 0.03)
	window:translate(0.55, -0.41, BASE + 0.95)
	window:emit(mesh)
end, 50, 0.4)
part("Needle", nil, { 0.85, 0.15, 0.1 }, function(mesh)
	local m = Kit.block(0.02, 0.02, 0.16, 0.005)
	m:translate(0.5, -0.44, BASE + 0.95)
	m:emit(mesh)
end, 50, 0)
part("Aerial", nil, BARE_METAL, function(mesh)
	Kit.tube({ { 0.75, 0, TOP - 0.05 }, { 0.8, 0, TOP + 0.7 }, { 1.1, 0.05, TOP + 1.15 } }, function(t)
		return 0.045 - 0.02 * t
	end, 6):emit(mesh)
	local tip = EditMesh.sphere(0.05, 8)
	tip:translate(1.1, 0.05, TOP + 1.17)
	tip:emit(mesh)
end, true, 0.3)
-- include: JunkrotFace
