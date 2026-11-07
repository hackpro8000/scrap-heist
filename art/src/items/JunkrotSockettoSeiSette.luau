-- Socketto Sei-Sette: a raccoon whose belly is an open socket set, tail
-- striped like a cable, juggling a 6 and a 7 cut from number plates. 3.7
-- studs tall. Our own character.
-- floats: Numbers
local FACE = { { -0.28, -0.74, 2.75, 0.2 }, { 0.28, -0.74, 2.8, 0.23 } }
local FEET = { 0.9, 0.55 }
local FUR = { 0.5, 0.5, 0.52 }
part("Body", nil, FUR, function(mesh)
	sphere(mesh, 0, 0, 1.55, 0.95, 0.8, 1.0, 8, 14)
	sphere(mesh, 0, -0.1, 2.75, 0.75, 0.68, 0.6, 8, 14)
	for _, side in { -1, 1 } do
		cylinder(mesh, side * 0.5, 0, 3.3, 0.22, 0.14, "y", 3)
	end
end, true, 0.2)
part("Mask", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	sphere(mesh, 0, -0.62, 2.78, 0.66, 0.16, 0.24, 5, 12)
	sphere(mesh, 0, -0.8, 2.5, 0.12, 0.1, 0.1, 4, 8)
end, true, 0)
part("SocketTray", nil, { 0.82, 0.14, 0.12 }, function(mesh)
	box(mesh, 0, -0.78, 1.05, 1.2, 0.12, 1.0)
end, nil, 0.03)
part("Sockets", nil, BARE_METAL, function(mesh)
	for row = 0, 1 do
		for column = -2, 2 do
			cylinder(mesh, column * 0.22, -0.88, 1.3 + row * 0.45, 0.07 + (column + 2) * 0.012, 0.12, "y", 8)
		end
	end
end, nil, 0.03)
part("Tail", nil, FUR, function(mesh)
	tube(mesh, { { 0, 0.7, 1.0 }, { 0.3, 1.4, 1.2 }, { 0.2, 1.7, 2.0 } }, 0.24, 8)
end, true, 0.2)
part("TailRings", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	sphere(mesh, 0.25, 1.2, 1.12, 0.27, 0.12, 0.27, 4, 8)
	sphere(mesh, 0.26, 1.62, 1.75, 0.27, 0.27, 0.12, 4, 8)
end, true, 0)
part("Numbers", nil, { 0.98, 0.86, 0.2 }, function(mesh)
	-- A 6 over the left paw: a loop with a tail. A 7 over the right.
	ring(mesh, -1.3, -0.3, 3.5, 0.14, 0.26, 0.1, "y", 10)
	tube(mesh, { { -1.5, -0.3, 3.6 }, { -1.45, -0.3, 4.0 }, { -1.15, -0.3, 4.15 } }, 0.06, 5)
	strut(mesh, 1.05, -0.3, 4.3, 1.6, -0.3, 4.3, 0.12)
	strut(mesh, 1.55, -0.3, 4.28, 1.2, -0.3, 3.5, 0.12)
end, nil, 0.05)
-- include: JunkrotFace
