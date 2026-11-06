-- Grindo Beanbasher: a bean-to-cup coffee machine, glossy black with a
-- steel front, a hopper of beans on top and a cup under its spout, sticker
-- still on. 3.6 studs tall.
local FACE = { { -0.4, -0.86, 2.55, 0.25 }, { 0.4, -0.86, 2.6, 0.28 } }
local FEET = { 1.0, 0.5 }
part("Body", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	box(mesh, 0, 0.1, 0.6, 2.0, 1.7, 2.5)
	box(mesh, 0, -0.5, 0.6, 2.0, 0.9, 0.3)
end, nil, 0)
part("Front", nil, BARE_METAL, function(mesh)
	box(mesh, 0, -0.78, 2.2, 1.9, 0.06, 0.85)
	cylinder(mesh, 0, -0.75, 1.95, 0.22, 0.3, "z", 10)
	box(mesh, 0, -0.5, 0.9, 1.5, 0.8, 0.05)
end, nil, 0.03)
part("Hopper", nil, { 0.36, 0.22, 0.12 }, function(mesh)
	cylinder(mesh, 0, 0.2, 3.4, 0.6, 0.6, "z", 14)
	cylinder(mesh, 0, 0.2, 3.74, 0.64, 0.08, "z", 14)
end, nil, 0)
part("Cup", nil, { 0.95, 0.94, 0.9 }, function(mesh)
	cylinder(mesh, 0, -0.6, 1.2, 0.3, 0.5, "z", 12)
	ring(mesh, 0.36, -0.6, 1.2, 0.1, 0.18, 0.08, "y", 8)
end, nil, 0)
part("Sticker", nil, { 0.98, 0.85, 0.2 }, function(mesh)
	cylinder(mesh, 0.7, -0.83, 2.8, 0.2, 0.03, "y", 12)
end, nil, 0)
-- include: JunkrotFace
