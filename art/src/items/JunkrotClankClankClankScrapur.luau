-- Clank Clank Clank Scrapur: a figure made from a length of rusty pipe,
-- pipe-stub arms, a rebar bat over one shoulder that it bangs on its own
-- side. 3.9 studs tall. Rebuilt from scrap, in our own look.
local FACE = { { -0.28, -0.74, 2.75, 0.26 }, { 0.3, -0.74, 2.8, 0.3 } }
local FEET = { 0.8, 0.6 }
part("Pipe", nil, RUST_ORANGE, function(mesh)
	cylinder(mesh, 0, 0, 2.15, 0.78, 3.0, "z", 16)
	ring(mesh, 0, 0, 3.62, 0.5, 0.9, 0.16, "z", 16)
	ring(mesh, 0, 0, 0.72, 0.7, 0.9, 0.16, "z", 16)
end, nil, 0.9)
part("Mouth", nil, { 0.1, 0.07, 0.05 }, function(mesh)
	box(mesh, 0, -0.76, 2.05, 0.7, 0.06, 0.12)
end, nil, 0.3)
part("Arms", nil, RUST_DARK, function(mesh)
	tube(mesh, { { -0.75, 0, 2.3 }, { -1.2, -0.2, 1.9 }, { -1.3, -0.5, 1.5 } }, 0.16, 8)
	tube(mesh, { { 0.75, 0, 2.3 }, { 1.25, -0.1, 2.5 }, { 1.4, -0.3, 2.95 } }, 0.16, 8)
end, true, 0.85)
part("Bat", nil, DARK_STEEL, function(mesh)
	strut(mesh, 1.4, -0.3, 2.7, 1.1, 0.5, 4.6, 0.16)
	for k = 0, 5 do
		local t = 0.25 + k * 0.13
		ring(mesh, 1.4 - 0.3 * t, -0.3 + 0.8 * t, 2.7 + 1.9 * t, 0.07, 0.13, 0.05, "z", 8)
	end
end, nil, 0.7)
part("Bolts", nil, STEEL, function(mesh)
	for k = 0, 5 do
		local angle = k * TAU / 6
		bolt(mesh, math.cos(angle) * 0.7, math.sin(angle) * 0.7, 3.72, "z", 0.08)
	end
end, nil, 0.6)
-- include: JunkrotFace
