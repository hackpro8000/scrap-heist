-- Crumbo Poppalot: a two-slot toaster with well-rounded chrome ends, a
-- slice of burnt toast stuck halfway up one slot, the lever and the
-- browning dial down its right end, a crumb tray along its foot and a
-- riveted patch over its left end. 3.1 studs tall.
-- include: JunkrotKit
local FACE = { { -0.38, -0.62, 1.75, 0.22 }, { 0.38, -0.62, 1.78, 0.23 } }
local FEET = { 1.1, 0.55 }
local BASE = 0.55
local TALL = 1.55
part("Body", nil, { 0.72, 0.72, 0.7 }, function(mesh)
	local m = Kit.block(1.9, 1.1, TALL, 0.3)
	m:translate(0, 0, BASE + TALL / 2)
	m:emit(mesh)
end, 50, 0.5)
part("Slots", nil, { 0.08, 0.08, 0.09 }, function(mesh)
	for _, y in { -0.2, 0.2 } do
		local slot = Kit.block(1.2, 0.13, 0.04, 0.015)
		slot:translate(0, y, BASE + TALL - 0.005)
		slot:emit(mesh)
	end
	-- Crumb tray along the foot.
	local tray = Kit.block(1.4, 0.06, 0.12, 0.03)
	tray:translate(0, -0.56, BASE + 0.12)
	tray:emit(mesh)
end, 50, 0.2)
part("Toast", nil, { 0.36, 0.22, 0.1 }, function(mesh)
	local m = Kit.block(1.0, 0.1, 0.8, 0.14)
	m:translate(0, -0.2, BASE + TALL + 0.12)
	m:emit(mesh)
end, 50, RUBBER)
part("Lever", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	-- Its slot down the end, the knob halfway, and the dial below.
	local slot = Kit.block(0.03, 0.12, 0.8, 0.01)
	slot:translate(0.95, 0, BASE + 0.85)
	slot:emit(mesh)
	local knob = Kit.block(0.22, 0.24, 0.12, 0.05)
	knob:translate(1.05, 0, BASE + 0.95)
	knob:emit(mesh)
	local dial = Kit.lathe({ { 0, 0 }, { 0.14, 0 }, { 0.12, 0.08 }, { 0, 0.09 } }, 12)
	Kit.turn(dial, "y", 90)
	dial:translate(0.94, 0, BASE + 0.35)
	dial:emit(mesh)
end, 50, 0.4)
part("Patch", nil, RUST_ORANGE, function(mesh)
	local m = Kit.block(0.04, 0.6, 0.5, 0.02)
	m:translate(-0.95, 0.1, BASE + 0.8)
	m:emit(mesh)
end, 50, 0.8)
part("Cord", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	Kit.tube(Kit.curve({ { 0.3, 0.5, BASE + 0.2 }, { 0.5, 0.9, BASE + 0.08 }, { 0.9, 1.05, 0.04 } }, 4), 0.05, 6):emit(mesh)
end, true, RUBBER)
-- include: JunkrotFace
