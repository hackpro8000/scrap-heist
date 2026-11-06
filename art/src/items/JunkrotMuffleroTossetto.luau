-- Mufflero Tossetto: a coughing exhaust silencer standing on end, tailpipe
-- up, heat-blued and holed, with a soot cloud at its lip, 3.5 studs tall.
local FACE = { { -0.3, -0.72, 1.7, 0.25 }, { 0.3, -0.72, 1.75, 0.28 } }
local FEET = { 0.8, 0.55 }
part("Silencer", nil, { 0.42, 0.4, 0.42 }, function(mesh)
	sphere(mesh, 0, 0, 1.6, 0.85, 0.75, 1.0, 8, 14)
	ring(mesh, 0, 0, 1.2, 0.8, 0.9, 0.1, "z", 14)
	ring(mesh, 0, 0, 2.0, 0.8, 0.9, 0.1, "z", 14)
end, true, 0.8)
part("Pipe", nil, RUST_DARK, function(mesh)
	tube(mesh, { { 0, 0, 2.5 }, { 0, 0, 3.0 }, { 0.3, 0, 3.4 } }, 0.24, 10)
	cylinder(mesh, 0, 0, 0.72, 0.24, 0.3, "z", 10)
end, true, 0.85)
part("Soot", nil, { 0.2, 0.19, 0.19 }, function(mesh)
	sphere(mesh, 0.55, 0, 3.75, 0.3, 0.3, 0.26, 5, 8)
	sphere(mesh, 0.85, 0.1, 4.0, 0.22, 0.22, 0.2, 5, 8)
end, true, 0)
-- include: JunkrotFace
