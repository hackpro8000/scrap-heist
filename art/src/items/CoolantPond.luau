-- Coolant Pond: a pond of toxic green coolant in a ring of tyres and
-- concrete chunks, with a sunken drum. Centered on the origin.
local COOLANT = { 0.3, 0.85, 0.35 }
local CONCRETE = { 0.6, 0.59, 0.56 }

part("Coolant", nil, COOLANT, function(mesh)
	cylinder(mesh, 0, 0, 0.05, 2.6, 0.1, "z", 24)
end, true, 0)

part("Tyres", nil, RUBBER_BLACK, function(mesh)
	for i = 0, 9 do
		local a = i * math.pi / 5
		ring(mesh, math.cos(a) * 2.9, math.sin(a) * 2.9, 0.18, 0.25, 0.5, 0.36, "z", 12)
	end
end, nil, RUBBER)

part("Concrete", nil, CONCRETE, function(mesh)
	box(mesh, 3.4, 1.2, 0, 0.8, 0.6, 0.4)
	box(mesh, -3.3, -1.5, 0, 0.7, 0.7, 0.5)
end, nil, 0.4)

part("Drum", nil, RUST_DARK, function(mesh)
	cylinder(mesh, 0.6, -0.4, 0.2, 0.5, 1.2, "x", 14)
end, nil, 0.85)

finishParts()
