-- Chimneyzini Spannerini: a tin chimp peeking out of a length of
-- yellow-painted stove pipe whose top is peeled back in strips like a
-- banana. 4 studs tall. Rebuilt from scrap, in our own look.
local FACE = { { -0.26, -0.66, 3.2, 0.22 }, { 0.26, -0.66, 3.25, 0.25 } }
local FEET = { 0.8, 0.55 }
local PIPE_YELLOW = { 0.98, 0.84, 0.18 }
local TIN = { 0.72, 0.68, 0.6 }
part("Pipe", nil, PIPE_YELLOW, function(mesh)
	cylinder(mesh, 0, 0, 1.7, 0.72, 2.2, "z", 14)
	ring(mesh, 0, 0, 0.66, 0.66, 0.8, 0.12, "z", 14)
end, nil, 0.2)
part("Peel", nil, PIPE_YELLOW, function(mesh)
	-- Four strips curling out and down from the rim.
	for k = 0, 3 do
		local angle = k * TAU / 4 + TAU / 8
		local x, y = math.cos(angle), math.sin(angle)
		tube(mesh, { { x * 0.7, y * 0.7, 2.7 }, { x * 1.05, y * 1.05, 3.05 }, { x * 1.5, y * 1.5, 2.9 }, { x * 1.7, y * 1.7, 2.4 } }, 0.2, 6)
	end
end, true, 0.2)
part("PeelTips", nil, { 0.3, 0.22, 0.1 }, function(mesh)
	for k = 0, 3 do
		local angle = k * TAU / 4 + TAU / 8
		sphere(mesh, math.cos(angle) * 1.72, math.sin(angle) * 1.72, 2.3, 0.2, 0.2, 0.14, 4, 8)
	end
end, true, 0.3)
part("Chimp", nil, TIN, function(mesh)
	sphere(mesh, 0, -0.05, 3.15, 0.62, 0.6, 0.62, 8, 14)
	sphere(mesh, 0, -0.55, 2.85, 0.36, 0.22, 0.26, 5, 12)
	for _, side in { -1, 1 } do
		cylinder(mesh, side * 0.66, 0, 3.2, 0.24, 0.12, "y", 10)
	end
end, true, 0.3)
part("Spanner", nil, BARE_METAL, function(mesh)
	strut(mesh, 0.5, -0.5, 2.6, 1.0, -0.9, 3.5, 0.1)
	ring(mesh, 1.05, -0.94, 3.62, 0.1, 0.22, 0.1, "y", 8)
end, nil, 0.1)
-- include: JunkrotFace
