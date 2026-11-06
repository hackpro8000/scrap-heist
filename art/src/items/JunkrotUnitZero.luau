-- Unit Zero: a perfect chrome sphere hanging in the air inside two thin
-- rings of light, one white eye-dot on its face. 3.6 studs tall. Too
-- perfect; nobody knows who made it.
part("Sphere", nil, { 0.9, 0.91, 0.93 }, function(mesh)
	sphere(mesh, 0, 0, 2.2, 1.2, 1.2, 1.2, 14, 24)
end, true, 0)
part("Eye", nil, { 1.0, 1.0, 1.0 }, function(mesh)
	sphere(mesh, 0, -1.16, 2.35, 0.16, 0.06, 0.16, 5, 10)
end, true, 0, nil, 2.5)
part("Rings", nil, { 0.6, 0.95, 1.0 }, function(mesh)
	ring(mesh, 0, 0, 2.2, 1.55, 1.62, 0.04, "z", 32)
	ring(mesh, 0, 0, 2.2, 1.72, 1.78, 0.04, "x", 32)
end, nil, 0, nil, 2.0, true)
part("Shadow", nil, { 0.5, 0.8, 1.0 }, function(mesh)
	ring(mesh, 0, 0, 0.06, 0.5, 0.6, 0.04, "z", 20)
end, nil, 0, nil, 1.2, true)
finishParts()
