-- Percolatto Ninjatto: a brushed-steel coffee cup with a ninja's body, a
-- tea-towel mask tied round its rim and a spanner blade in each hand. 3.8
-- studs tall. Rebuilt from scrap, in our own look.
local FACE = { { -0.26, -0.7, 3.0, 0.2 }, { 0.26, -0.7, 3.05, 0.22 } }
local FEET = { 0.7, 0.7 }
part("Cup", nil, BARE_METAL, function(mesh)
	cylinder(mesh, 0, 0, 3.0, 0.72, 1.1, "z", 16)
	ring(mesh, 0, 0, 3.55, 0.64, 0.76, 0.08, "z", 16)
	ring(mesh, 0.86, 0, 3.0, 0.16, 0.3, 0.12, "y", 10)
end, nil, 0.03)
part("Coffee", nil, { 0.25, 0.14, 0.07 }, function(mesh)
	cylinder(mesh, 0, 0, 3.5, 0.64, 0.06, "z", 16)
end, nil, 0)
part("Mask", nil, { 0.12, 0.12, 0.2 }, function(mesh)
	ring(mesh, 0, 0, 3.02, 0.72, 0.78, 0.5, "z", 16)
	-- The knot's tails.
	strut(mesh, 0.2, 0.75, 3.0, 0.6, 1.3, 2.7, 0.1)
	strut(mesh, -0.1, 0.75, 3.0, 0.1, 1.4, 3.1, 0.1)
end, nil, RUBBER)
part("Suit", nil, { 0.1, 0.1, 0.13 }, function(mesh)
	sphere(mesh, 0, 0, 1.75, 0.55, 0.45, 0.8, 6, 12)
	tube(mesh, { { -0.45, 0, 2.2 }, { -1.0, -0.3, 2.0 }, { -1.25, -0.6, 2.4 } }, 0.12, 6)
	tube(mesh, { { 0.45, 0, 2.2 }, { 1.0, -0.3, 2.0 }, { 1.25, -0.6, 2.4 } }, 0.12, 6)
end, true, RUBBER)
part("Blades", nil, BARE_METAL, function(mesh)
	for _, side in { -1, 1 } do
		strut(mesh, side * 1.25, -0.6, 2.3, side * 1.6, -0.9, 4.0, 0.12)
		ring(mesh, side * 1.63, -0.93, 4.15, 0.1, 0.24, 0.1, "y", 8)
	end
end, nil, 0.03)
-- include: JunkrotFace
