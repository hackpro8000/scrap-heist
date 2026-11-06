-- Grindella Scintilla: an angle grinder in fresh green, disc spinning at
-- one end and a spray of sparks off it, 3 studs tall and 3.6 long.
local FACE = { { -0.6, -0.5, 1.75, 0.24 }, { 0.0, -0.5, 1.8, 0.27 } }
local FEET = { 1.0, 0.6 }
local TOOL_GREEN = { 0.2, 0.6, 0.36 }
part("Body", nil, TOOL_GREEN, function(mesh)
	cylinder(mesh, -0.4, 0, 1.6, 0.5, 2.4, "x", 14)
	box(mesh, 1.0, 0, 1.2, 0.7, 0.9, 0.8)
end, nil, 0.15)
part("Handle", nil, { 0.13, 0.13, 0.14 }, function(mesh)
	cylinder(mesh, 0.5, 0.9, 1.6, 0.16, 0.9, "y", 8)
	cylinder(mesh, -1.75, 0, 1.6, 0.3, 0.3, "x", 10)
end, nil, RUBBER)
part("Disc", nil, { 0.5, 0.48, 0.45 }, function(mesh)
	cylinder(mesh, 1.0, 0, 1.08, 0.95, 0.07, "z", 20)
	cylinder(mesh, 1.0, 0, 1.03, 0.2, 0.12, "z", 8)
end, nil, 0.2)
part("Guard", nil, BARE_METAL, function(mesh)
	for k = 0, 8 do
		local angle = math.rad(80 + k * 25)
		box(mesh, 1.0 + math.cos(angle) * 1.0, math.sin(angle) * 1.0, 1.02, 0.24, 0.24, 0.3)
	end
end, nil, 0.05)
part("Sparks", nil, { 1.0, 0.7, 0.2 }, function(mesh)
	for k = 0, 5 do
		local reach = 0.3 + k * 0.22
		strut(mesh, 1.9, -0.3, 1.1, 1.9 + reach, -0.4 - reach * 0.5, 1.1 + (k % 3) * 0.2, 0.05)
	end
end, nil, 0)
-- include: JunkrotFace
