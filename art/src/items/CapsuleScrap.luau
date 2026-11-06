-- Capsule, Scrap tier: a dented paint can, 2.6 studs tall, with dried paint
-- run down its side, a pried lid and a wire handle. Stands on the origin.
local OLD_PAINT = { 0.42, 0.55, 0.5 }
part("Can", nil, BARE_METAL, function(mesh)
	cylinder(mesh, 0, 0, 1.2, 1.1, 2.4, "z", 18)
	ring(mesh, 0, 0, 0.08, 1.0, 1.16, 0.16, "z", 18)
	ring(mesh, 0, 0, 2.36, 0.95, 1.16, 0.16, "z", 18)
end, nil, 0.85)
part("Lid", nil, RUST_ORANGE, function(mesh)
	cylinder(mesh, 0.06, -0.04, 2.46, 0.93, 0.12, "z", 18)
	cylinder(mesh, 0.06, -0.04, 2.55, 0.35, 0.06, "z", 12)
end, nil, 0.9)
part("Paint", nil, OLD_PAINT, function(mesh)
	-- A band of old label paint and three runs down from the rim.
	ring(mesh, 0, 0, 1.25, 1.1, 1.13, 1.0, "z", 18)
	for i, angle in { 4.2, 4.9, 5.5 } do
		local x, y = math.cos(angle) * 1.12, math.sin(angle) * 1.12
		cylinder(mesh, x, y, 2.3 - i * 0.12, 0.12, 0.5 + i * 0.25, "z", 8)
	end
end, nil, 0.5)
part("Handle", nil, DARK_STEEL, function(mesh)
	tube(mesh, { { -1.14, 0, 2.0 }, { -1.3, 0, 2.7 }, { -0.7, 0, 3.15 }, { 0.7, 0, 3.15 }, { 1.3, 0, 2.7 }, { 1.14, 0, 2.0 } }, 0.05, 6)
	bolt(mesh, -1.12, 0, 2.0, "x", 0.09)
	bolt(mesh, 1.12, 0, 2.0, "x", 0.09)
end, nil, 0.6)
finishParts()
