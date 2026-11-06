-- Tickworth Pocketti: a gold pocket watch standing on edge, its crown and
-- bow on top, lid swung open to one side and a chain looping off behind.
-- 3.5 studs tall.
local FACE = { { -0.35, -0.3, 2.3, 0.2 }, { 0.35, -0.3, 2.35, 0.22 } }
local FEET = { 0.9, 0.55 }
local GOLD = { 0.92, 0.72, 0.25 }
part("Case", nil, GOLD, function(mesh)
	cylinder(mesh, 0, 0, 1.9, 1.2, 0.36, "y", 24)
	cylinder(mesh, 0, 0, 3.2, 0.14, 0.3, "z", 8)
	ring(mesh, 0, 0, 3.55, 0.16, 0.28, 0.08, "y", 12)
end, nil, 0.03)
part("Lid", nil, GOLD, function(mesh)
	cylinder(mesh, 1.55, 0.5, 1.9, 1.15, 0.08, "x", 24)
end, nil, 0.03)
part("Dial", nil, { 0.97, 0.96, 0.92 }, function(mesh)
	cylinder(mesh, 0, -0.2, 1.9, 1.05, 0.04, "y", 24)
end, nil, 0)
part("Hands", nil, { 0.08, 0.08, 0.1 }, function(mesh)
	strut(mesh, 0, -0.24, 1.9, 0.3, -0.24, 1.3, 0.06)
	strut(mesh, 0, -0.24, 1.9, -0.7, -0.24, 1.6, 0.04)
	for k = 0, 11 do
		local angle = k * TAU / 12
		cylinder(mesh, math.cos(angle) * 0.92, -0.23, 1.9 + math.sin(angle) * 0.92, 0.04, 0.03, "y", 6)
	end
end, nil, 0)
part("Chain", nil, GOLD, function(mesh)
	for k = 0, 6 do
		ring(mesh, -0.3 - k * 0.2, 0.3 + k * 0.12, 3.5 - k * 0.42, 0.06, 0.12, 0.05, if k % 2 == 0 then "y" else "x", 8)
	end
end, nil, 0.03)
-- include: JunkrotFace
