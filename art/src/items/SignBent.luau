-- Sign Bent: a stop sign on a pole bent over by a car, the sign face
-- pointing at the ground. Centered on the origin.
local STOP = { 0.75, 0.12, 0.1 }

part("Pole", nil, STEEL, function(mesh)
	tube(mesh, { { 0, 0, 0 }, { 0, 0, 1.2 }, { 0.4, 0, 2.0 }, { 1.2, 0, 2.3 } }, 0.06, 8)
	box(mesh, 0, 0, 0, 0.4, 0.4, 0.1)
end, nil, 0.5)

part("Face", nil, STOP, function(mesh)
	cylinder(mesh, 1.45, 0, 2.0, 0.5, 0.05, "x", 8)
end, nil, 0.5)

part("Border", nil, { 0.92, 0.92, 0.9 }, function(mesh)
	ring(mesh, 1.48, 0, 2.0, 0.42, 0.5, 0.03, "x", 8)
end, nil, 0.4)

finishParts()
