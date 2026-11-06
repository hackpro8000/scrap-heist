-- Radiolo Fruscio: a crackly portable radio, a speaker grille for a belly,
-- two dials and a bent aerial, 3.4 studs tall.
local FACE = { { -0.5, -0.5, 2.05, 0.26 }, { 0.5, -0.5, 2.1, 0.3 } }
local FEET = { 1.2, 0.55 }
part("Case", nil, { 0.6, 0.36, 0.2 }, function(mesh)
	box(mesh, 0, 0, 0.65, 2.6, 0.9, 1.9)
end, nil, 0.5)
part("Grille", nil, { 0.2, 0.2, 0.21 }, function(mesh)
	cylinder(mesh, 0, -0.46, 1.25, 0.5, 0.06, "y", 16)
	for k = -2, 2 do
		box(mesh, k * 0.2, -0.5, 0.82, 0.07, 0.03, 0.86)
	end
end, nil, 0.4)
part("Dials", nil, { 0.85, 0.82, 0.72 }, function(mesh)
	for _, x in { -0.95, 0.95 } do
		cylinder(mesh, x, -0.5, 1.2, 0.22, 0.12, "y", 12)
	end
	box(mesh, 0, 0, 2.55, 2.4, 0.5, 0.08)
end, nil, 0.4)
part("Aerial", nil, BARE_METAL, function(mesh)
	tube(mesh, { { 1.1, 0.2, 2.55 }, { 1.2, 0.2, 3.4 }, { 1.6, 0.2, 4.0 } }, 0.04, 6)
	sphere(mesh, 1.6, 0.2, 4.03, 0.09, 0.09, 0.09, 4, 8)
	tube(mesh, { { -0.9, 0, 2.6 }, { -0.9, 0, 2.95 }, { 0.9, 0, 2.95 }, { 0.9, 0, 2.6 } }, 0.07, 6)
end, nil, 0.3)
-- include: JunkrotFace
