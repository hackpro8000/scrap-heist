-- Blendro Cigolante: a squeaky blender, its cloudy jug on a chunky base
-- with one big dial, lid askew, 3.5 studs tall.
local FACE = { { -0.3, -0.82, 1.15, 0.24 }, { 0.3, -0.82, 1.2, 0.27 } }
local FEET = { 0.9, 0.5 }
part("Base", nil, { 0.78, 0.74, 0.62 }, function(mesh)
	cylinder(mesh, 0, 0, 1.15, 0.85, 1.2, "z", 16)
	cylinder(mesh, 0, 0, 1.82, 0.6, 0.16, "z", 14)
end, nil, 0.5)
part("Jug", nil, { 0.62, 0.74, 0.76 }, function(mesh)
	cylinder(mesh, 0, 0, 2.6, 0.72, 1.4, "z", 14)
	tube(mesh, { { 0.7, 0, 3.1 }, { 1.15, 0, 2.9 }, { 1.15, 0, 2.3 }, { 0.7, 0, 2.1 } }, 0.09, 6)
end, nil, 0.2)
part("Lid", nil, { 0.14, 0.14, 0.15 }, function(mesh)
	cylinder(mesh, 0.08, -0.05, 3.38, 0.76, 0.18, "z", 14)
	cylinder(mesh, 0.08, -0.05, 3.52, 0.25, 0.14, "z", 10)
end, nil, 0.4)
part("Dial", nil, { 0.85, 0.2, 0.15 }, function(mesh)
	cylinder(mesh, 0, -0.86, 0.72, 0.2, 0.1, "y", 12)
end, nil, 0.3)
-- include: JunkrotFace
