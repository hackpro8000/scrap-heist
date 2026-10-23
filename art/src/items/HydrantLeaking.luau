-- Hydrant Leaking: a dented fire hydrant with a cap knocked off and a
-- puddle spreading round its base. Centered on the origin.
local HYDRANT = { 0.75, 0.15, 0.1 }
local WATER = { 0.35, 0.55, 0.7 }

part("Body", nil, HYDRANT, function(mesh)
	cylinder(mesh, 0, 0, 0.5, 0.3, 1.0, "z", 12)
	cylinder(mesh, 0, 0, 1.05, 0.34, 0.1, "z", 12)
	sphere(mesh, 0, 0, 1.12, 0.28, 0.28, 0.2, 5, 12)
	cylinder(mesh, 0, 0, 0.05, 0.38, 0.1, "z", 12)
	cylinder(mesh, 0.38, 0, 0.7, 0.12, 0.2, "x", 10)
end, nil, 0.6)

part("Nozzles", nil, STEEL, function(mesh)
	cylinder(mesh, -0.38, 0, 0.7, 0.13, 0.12, "x", 10)
	cylinder(mesh, 0, 0, 1.33, 0.06, 0.1, "z", 6)
	cylinder(mesh, 0.7, 0.4, 0.07, 0.13, 0.12, "z", 10)
end, nil, 0.5)

part("Water", nil, WATER, function(mesh)
	cylinder(mesh, 0.4, 0, 0.01, 1.1, 0.02, "z", 18)
	tube(mesh, { { 0.48, 0, 0.7 }, { 0.75, 0, 0.6 }, { 0.95, 0, 0.05 } }, 0.05, 6)
end, true, 0)

finishParts()
