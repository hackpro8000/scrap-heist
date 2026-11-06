-- Scrap Crate: the yard's storage crate, 8 x 8 studs and 4.2 tall. An
-- open-topped plank box banded and cornered in steel, with a painted green
-- stripe so it reads as "bank here" from across the yard. Stands on the
-- origin.
local PLANK = { 0.52, 0.38, 0.24 }
local BANK_GREEN = { 0.3, 0.62, 0.3 }
part("Planks", nil, PLANK, function(mesh)
	for _, side in { -1, 1 } do
		for k = 0, 3 do
			box(mesh, 0, side * 3.7, 0.3 + k * 0.95, 7.8, 0.4, 0.88)
			box(mesh, side * 3.7, 0, 0.3 + k * 0.95, 0.4, 7.0, 0.88)
		end
	end
	box(mesh, 0, 0, 0, 7.8, 7.8, 0.3)
end, nil, RUBBER)
part("Bands", nil, DARK_STEEL, function(mesh)
	for _, x in { -3.85, 3.85 } do
		for _, y in { -3.85, 3.85 } do
			box(mesh, x, y, 0, 0.5, 0.5, 4.2)
		end
	end
	for _, side in { -1, 1 } do
		box(mesh, 0, side * 3.93, 3.9, 7.4, 0.08, 0.3)
		box(mesh, side * 3.93, 0, 3.9, 0.08, 7.4, 0.3)
		for _, k in { -2.4, 0, 2.4 } do
			bolt(mesh, k, side * 3.98, 4.05, "y", 0.08)
			bolt(mesh, side * 3.98, k, 4.05, "x", 0.08)
		end
	end
end, nil, 0.55)
part("Stripe", nil, BANK_GREEN, function(mesh)
	for _, side in { -1, 1 } do
		box(mesh, 0, side * 3.92, 1.5, 7.0, 0.05, 0.9)
		box(mesh, side * 3.92, 0, 1.5, 0.05, 7.0, 0.9)
	end
end, nil, 0.45)
part("Heap", nil, RUST_DARK, function(mesh)
	-- A little scrap always shows over the rim.
	box(mesh, 0, 0, 0.3, 7.0, 7.0, 2.6)
	box(mesh, 0.5, -0.4, 2.9, 4.6, 4.2, 0.6)
	box(mesh, -0.6, 0.5, 3.5, 2.6, 2.4, 0.5)
end, nil, 0.9)
part("Bits", nil, STEEL, function(mesh)
	ring(mesh, 1.6, -1.2, 3.75, 0.25, 0.6, 0.25, "z", 12)
	cylinder(mesh, -1.8, -1.6, 3.2, 0.3, 1.6, "x", 10)
	tube(mesh, { { -2.4, 2.0, 3.0 }, { -1.4, 1.6, 4.3 }, { -0.2, 1.9, 4.6 } }, 0.09, 6)
end, nil, 0.6)
finishParts()
