-- Percolatto Ninjatto: Cappuccino Assassino from scrap. A brushed-steel
-- coffee cup for a head, coffee to the brim, a handle at its side; a dark
-- tea-towel mask tied over its lower half and a headband above, its tails
-- flying, and narrowed eyes of its own peering out between them; a slim
-- black ninja body with a sash, arms out with a katana cut from flat bar
-- in each hand, and legs in split-toe boots. No googly face. 3.8 studs
-- tall.
-- include: JunkrotKit
local SUIT = { 0.1, 0.1, 0.13 }
local MASK = { 0.12, 0.12, 0.2 }
local NECK = 2.45 -- the cup's base
part("Cup", nil, BARE_METAL, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.38, 0 }, { 0.42, 0.05 }, { 0.52, 0.85 }, { 0.55, 0.9 }, { 0.5, 0.9 }, { 0.47, 0.82 }, { 0, 0.82 } }, 20)
	m:translate(0, 0, NECK)
	m:emit(mesh)
	local handle = Kit.curve({ { 0.48, 0, NECK + 0.7 }, { 0.75, 0, NECK + 0.62 }, { 0.72, 0, NECK + 0.3 }, { 0.44, 0, NECK + 0.22 } }, 3)
	Kit.tube(handle, 0.05, 8):emit(mesh)
end, 40, 0.03)
part("Coffee", nil, { 0.25, 0.14, 0.07 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.48, 0 }, { 0.48, 0.02 }, { 0, 0.02 } }, 20)
	m:translate(0, 0, NECK + 0.82)
	m:emit(mesh)
end, 40, 0)
part("Mask", nil, MASK, function(mesh)
	-- Over the lower half, and a headband above the eyes.
	for _, band in { { 0.18, 0.47, 0.58, 0.22 }, { 0.68, 0.55, 0.64, 0.1 } } do
		local m = EditMesh.tube(band[3], band[2] - 0.02, band[4], 24)
		m:translate(0, 0, NECK + band[1] + band[4] / 2)
		m:emit(mesh)
	end
	for _, side in { -1, 1 } do
		local tail = EditMesh.sweep({ { -0.02, -0.06 }, { 0.02, -0.06 }, { 0.02, 0.06 }, { -0.02, 0.06 } }, Kit.curve({ { side * 0.1, 0.55, NECK + 0.73 }, { side * 0.3, 0.9, NECK + 0.6 }, { side * 0.45, 1.25, NECK + 0.7 } }, 3))
		tail:emit(mesh)
	end
	local sash = EditMesh.torus(0.31, 0.06, 16, 6)
	sash:translate(0, 0, 1.75)
	sash:emit(mesh)
end, true, RUBBER)
part("Eyes", nil, { 0.95, 0.94, 0.9 }, function(mesh)
	for _, side in { -1, 1 } do
		local eye = EditMesh.sphere(0.1, 8)
		Kit.size(eye, { 1.1, 0.4, 0.6 })
		Kit.turn(eye, "y", side * -14)
		eye:translate(side * 0.18, -0.49, NECK + 0.56)
		eye:emit(mesh)
	end
end, true, 0)
part("Pupils", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, side in { -1, 1 } do
		local pupil = EditMesh.sphere(0.05, 8)
		Kit.size(pupil, { 1, 0.5, 0.9 })
		pupil:translate(side * 0.16, -0.53, NECK + 0.55)
		pupil:emit(mesh)
	end
end, true, 0)
part("Suit", nil, SUIT, function(mesh)
	local torso = Kit.lathe({ { 0, 0 }, { 0.3, 0 }, { 0.38, 0.3 }, { 0.35, 0.75 }, { 0.42, 0.95 }, { 0.24, 1.05 }, { 0, 1.08 } }, 16)
	torso:translate(0, 0, 1.42)
	torso:emit(mesh)
	for _, side in { -1, 1 } do
		Kit.tube(Kit.curve({ { side * 0.32, 0, 2.3 }, { side * 0.62, -0.1, 2.0 }, { side * 0.85, -0.2, 2.3 } }, 3), 0.1, 8):emit(mesh)
		local hand = EditMesh.sphere(0.1, 8)
		hand:translate(side * 0.85, -0.2, 2.3)
		hand:emit(mesh)
		Kit.tube(Kit.curve({ { side * 0.14, 0, 1.5 }, { side * 0.24, -0.05, 0.85 }, { side * 0.25, -0.06, 0.18 } }, 3), 0.13, 8):emit(mesh)
		local boot = Kit.shoe(0.44, 0.22, 0.22)
		Kit.turn(boot, "z", -90)
		boot:translate(side * 0.25, -0.1, 0)
		boot:emit(mesh)
	end
end, true, RUBBER)
part("Blades", nil, BARE_METAL, function(mesh)
	-- A katana in each hand: handle, guard, then the blade.
	for _, hold in { { 1, 18 }, { -1, -55 } } do
		local blade = Kit.block(0.04, 0.12, 1.2, 0.02)
		blade:translate(0, 0, 0.72)
		local guard = EditMesh.cylinder(0.11, 0.04, 8, 1)
		guard:translate(0, 0, 0.1)
		local handle = Kit.block(0.07, 0.07, 0.3, 0.02)
		handle:translate(0, 0, -0.06)
		for _, piece in { blade, guard, handle } do
			Kit.turn(piece, "y", hold[2])
			piece:translate(hold[1] * 0.85, -0.2, 2.3)
			piece:emit(mesh)
		end
	end
end, 40, 0.03)
finishParts()
