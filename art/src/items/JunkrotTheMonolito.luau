-- The Monolito: a black slab with no seams, no feet and no face but one
-- slit of violet light, hanging a little off the ground over a faint
-- ring. 4.6 studs tall. Nobody knows who made it.
part("Slab", nil, { 0.03, 0.03, 0.045 }, function(mesh)
	box(mesh, 0, 0, 0.6, 1.8, 0.7, 4.0)
end, nil, 0, nil, nil, true)
part("Eye", nil, { 0.65, 0.4, 1.0 }, function(mesh)
	box(mesh, 0, -0.355, 3.4, 1.0, 0.03, 0.14)
end, nil, 0, nil, 2.5, true)
part("Hum", nil, { 0.5, 0.3, 0.9 }, function(mesh)
	ring(mesh, 0, 0, 0.08, 1.1, 1.22, 0.05, "z", 28)
end, nil, 0, nil, 1.5, true)
finishParts()
