-- Microndo Bippetto: a microwave with its door's dark glass window for a
-- face in a raised door frame with a long handle, a keypad panel down the
-- right with its keys and a dial, vent slots in its side, and its
-- turntable plate worn as a hat, tipped at an angle. 2.9 studs tall.
-- include: JunkrotKit
local FACE = { { -0.72, -0.85, 1.35, 0.24 }, { -0.22, -0.85, 1.37, 0.24 } }
local FEET = { 1.3, 0.55 }
local CREAM = { 0.9, 0.87, 0.78 }
local BASE = 0.55
local TALL = 1.4
part("Case", nil, CREAM, function(mesh)
	local m = Kit.block(2.2, 1.4, TALL, 0.1)
	m:translate(0, 0, BASE + TALL / 2)
	m:emit(mesh)
	local door = Kit.block(1.45, 0.06, 1.2, 0.05)
	door:translate(-0.33, -0.72, BASE + TALL / 2)
	door:emit(mesh)
end, 50, 0.15)
part("Glass", nil, { 0.1, 0.12, 0.14 }, function(mesh)
	local m = Kit.block(1.1, 0.04, 0.85, 0.06)
	m:translate(-0.4, -0.76, BASE + TALL / 2)
	m:emit(mesh)
end, 50, 0.05)
part("Handle", nil, BARE_METAL, function(mesh)
	Kit.tube({ { 0.3, -0.84, BASE + 0.3 }, { 0.3, -0.84, BASE + 1.1 } }, 0.04, 8):emit(mesh)
	for _, z in { BASE + 0.3, BASE + 1.1 } do
		Kit.tube({ { 0.3, -0.74, z }, { 0.3, -0.85, z } }, 0.03, 6):emit(mesh)
	end
end, true, 0.05)
part("Keypad", nil, { 0.25, 0.27, 0.3 }, function(mesh)
	local panel = Kit.block(0.5, 0.05, 1.2, 0.04)
	panel:translate(0.78, -0.71, BASE + TALL / 2)
	panel:emit(mesh)
	local dial = Kit.lathe({ { 0, 0 }, { 0.13, 0 }, { 0.11, 0.07 }, { 0, 0.08 } }, 12)
	Kit.turn(dial, "x", 90)
	dial:translate(0.78, -0.73, BASE + 1.1)
	dial:emit(mesh)
	for k = 0, 3 do
		local slot = Kit.block(0.03, 0.7, 0.06, 0.01)
		slot:translate(1.1, 0.1, BASE + 0.45 + k * 0.17)
		slot:emit(mesh)
	end
end, 50, 0.1)
part("Keys", nil, { 0.5, 0.9, 0.6 }, function(mesh)
	for row = 0, 3 do
		for column = -1, 1 do
			local key = Kit.block(0.12, 0.04, 0.09, 0.02)
			key:translate(0.78 + column * 0.14, -0.75, BASE + 0.25 + row * 0.15)
			key:emit(mesh)
		end
	end
end, 50, 0.05)
part("Plate", nil, { 0.8, 0.88, 0.9 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.6, 0 }, { 0.64, 0.05 }, { 0.6, 0.06 }, { 0, 0.04 } }, 24)
	Kit.turn(m, "y", 12)
	m:translate(0.1, 0, BASE + TALL + 0.04)
	m:emit(mesh)
end, 40, 0.05)
-- include: JunkrotFace
