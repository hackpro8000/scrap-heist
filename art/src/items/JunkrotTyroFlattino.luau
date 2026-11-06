-- Tyro Flattino: a flat tyre slumped on its rim, 2.6 studs tall, with a
-- nail still in it.
local FACE = { { -0.3, -0.42, 1.75, 0.24 }, { 0.3, -0.42, 1.8, 0.27 } }
local FEET = { 0.9, 0.5 }
part("Tyre", nil, RUBBER_BLACK, function(mesh)
	ring(mesh, 0, 0, 1.6, 0.6, 1.15, 0.7, "y", 18)
	-- The flat: a sagging pad where it meets the ground.
	box(mesh, 0, 0, 0.5, 1.5, 0.74, 0.3)
end, nil, RUBBER)
part("Rim", nil, RUST_DARK, function(mesh)
	cylinder(mesh, 0, 0, 1.6, 0.62, 0.5, "y", 14)
	for k = 0, 4 do
		local angle = k * TAU / 5
		bolt(mesh, math.cos(angle) * 0.3, -0.27, 1.6 + math.sin(angle) * 0.3, "y", 0.06)
	end
end, nil, 0.85)
part("Nail", nil, BARE_METAL, function(mesh)
	strut(mesh, 0.7, -0.1, 2.5, 0.95, -0.2, 2.95, 0.06)
	cylinder(mesh, 0.96, -0.2, 2.97, 0.12, 0.04, "z", 8)
end, nil, 0.4)
-- include: JunkrotFace
