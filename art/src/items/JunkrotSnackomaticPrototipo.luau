-- Snackomatic Prototipo: a food replicator, a seamless white cabinet with
-- a glowing chamber in its chest, one perfect doughnut floating inside
-- and a test-unit tag. 4 studs tall.
local FACE = { { -0.4, -0.82, 3.2, 0.24 }, { 0.4, -0.82, 3.25, 0.26 } }
local FEET = { 1.0, 0.5 }
part("Cabinet", nil, { 0.96, 0.97, 0.98 }, function(mesh)
	box(mesh, 0, 0, 0.6, 2.2, 1.6, 2.6)
	sphere(mesh, 0, 0, 3.2, 1.1, 0.8, 0.5, 6, 16)
end, true, 0)
part("Chamber", nil, { 0.45, 0.95, 1.0 }, function(mesh)
	box(mesh, 0, -0.78, 1.2, 1.5, 0.08, 1.5)
end, nil, 0, nil, 1.6)
part("Doughnut", nil, { 1.0, 0.55, 0.75 }, function(mesh)
	ring(mesh, 0, -0.9, 1.95, 0.18, 0.46, 0.2, "y", 14)
end, nil, 0, nil, 0.6)
part("Trim", nil, { 0.3, 0.32, 0.36 }, function(mesh)
	box(mesh, 0, 0, 0.55, 2.26, 1.66, 0.12)
end, nil, 0)
part("Tag", nil, { 0.98, 0.55, 0.12 }, function(mesh)
	box(mesh, 0.75, -0.82, 2.85, 0.5, 0.03, 0.22)
end, nil, 0)
-- include: JunkrotFace
