-- Spoonzo Bentolo: a bent spoon standing on its handle, its bowl for a
-- face, 3 studs tall.
local FACE = { { -0.22, -0.3, 2.45, 0.2 }, { 0.24, -0.3, 2.5, 0.23 } }
local FEET = { 0.5, 0.5 }
part("Spoon", nil, BARE_METAL, function(mesh)
	sphere(mesh, 0, 0, 2.4, 0.62, 0.24, 0.8, 8, 14)
	-- The handle kinks twice on its way down.
	tube(mesh, { { 0, 0.05, 1.7 }, { 0.12, 0.3, 1.3 }, { -0.1, 0.1, 0.9 }, { 0, 0, 0.5 } }, 0.13, 8)
	box(mesh, 0, 0, 0.42, 0.7, 0.3, 0.2)
end, true, 0.7)
part("Stain", nil, RUST_ORANGE, function(mesh)
	sphere(mesh, 0.2, 0.12, 2.75, 0.3, 0.14, 0.34, 5, 8)
end, true, 0.9)
-- include: JunkrotFace
