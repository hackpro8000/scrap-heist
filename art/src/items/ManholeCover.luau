-- Manhole Cover: a cover popped half out of its frame, leaning on the rim,
-- with steam vent slots. Sits on z 0, centered on the origin.
part("Frame", nil, DARK_STEEL, function(mesh)
	ring(mesh, 0, 0, 0.03, 0.55, 0.75, 0.06, "z", 20)
	cylinder(mesh, 0, 0, 0.0, 0.55, 0.02, "z", 20)
end, nil, 0.6)

part("Hole", nil, { 0.05, 0.05, 0.06 }, function(mesh)
	cylinder(mesh, 0, 0, 0.02, 0.55, 0.02, "z", 20)
end, true, 0)

part("Cover", nil, RUST_DARK, function(mesh)
	-- Tipped up, resting on the rim.
	for i = 0, 7 do
		local t = i / 7
		box(mesh, 0.3 + t * 0.85, 0, 0.05 + t * 0.55, 0.12, 1.1 - math.abs(t - 0.5) * 0.9, 0.06)
	end
end, nil, 0.85)

finishParts()
