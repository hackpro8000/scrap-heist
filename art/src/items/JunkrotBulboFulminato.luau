-- Bulbo Fulminato: a blown light bulb, smoked glass over a broken
-- filament, standing on its screw cap, 2.9 studs tall.
local FACE = { { -0.3, -0.8, 2.05, 0.25 }, { 0.32, -0.78, 2.1, 0.28 } }
local FEET = { 0.55, 0.55 }
part("Glass", nil, { 0.56, 0.54, 0.46 }, function(mesh)
	sphere(mesh, 0, 0, 2.0, 0.95, 0.95, 0.95, 8, 16)
	cylinder(mesh, 0, 0, 1.25, 0.55, 0.5, "z", 14)
end, true, 0.25)
part("Soot", nil, { 0.16, 0.14, 0.12 }, function(mesh)
	sphere(mesh, 0.1, 0.05, 2.72, 0.5, 0.5, 0.26, 5, 10)
end, true, 0.3)
part("Cap", nil, { 0.72, 0.6, 0.3 }, function(mesh)
	cylinder(mesh, 0, 0, 0.82, 0.48, 0.44, "z", 14)
	for k = 0, 2 do
		ring(mesh, 0, 0, 0.68 + k * 0.14, 0.46, 0.54, 0.06, "z", 14)
	end
end, nil, 0.6)
-- include: JunkrotFace
