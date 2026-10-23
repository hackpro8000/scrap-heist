-- Stump Drum: a cut-down oil drum stump with a torn ragged rim, roots of
-- bent hose and a hazard stripe, standing in for a tree stump. Centered on
-- the origin.
local HAZARD = { 0.9, 0.72, 0.1 }

part("Drum", nil, RUST_DARK, function(mesh)
	ring(mesh, 0, 0, 0.45, 0.6, 0.66, 0.9, "z", 16)
	cylinder(mesh, 0, 0, 0.03, 0.62, 0.06, "z", 16)
	-- Torn teeth around the rim.
	for i = 0, 11 do
		local a = i * math.pi / 6
		box(mesh, math.cos(a) * 0.63, math.sin(a) * 0.63, 0.9, 0.18, 0.18, 0.08 + (i % 3) * 0.1)
	end
end, nil, 0.85)

part("Stripe", nil, HAZARD, function(mesh)
	ring(mesh, 0, 0, 0.5, 0.65, 0.68, 0.14, "z", 16)
end, nil, 0.6)

part("Roots", nil, RUBBER_BLACK, function(mesh)
	for i = 0, 4 do
		local a = i * 1.3
		local c, s = math.cos(a), math.sin(a)
		tube(mesh, { { c * 0.6, s * 0.6, 0.25 }, { c * 0.95, s * 0.95, 0.08 }, { c * 1.4, s * 1.4, 0.06 } }, 0.07, 6)
	end
end, nil, RUBBER)

finishParts()
