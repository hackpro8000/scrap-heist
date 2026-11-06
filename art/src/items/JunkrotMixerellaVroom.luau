-- Mixerella Vroom: a stand mixer in fresh cherry red, head tipped
-- forward over a polished bowl, whisk down, 3.6 studs tall.
local FACE = { { -0.3, -1.0, 3.0, 0.24 }, { 0.3, -1.0, 3.05, 0.27 } }
local FEET = { 1.0, 0.5 }
local CHERRY = { 0.82, 0.12, 0.16 }
part("Stand", nil, CHERRY, function(mesh)
	box(mesh, 0, 0, 0.6, 1.6, 2.6, 0.35)
	box(mesh, 0, 0.9, 0.95, 0.9, 0.7, 1.7)
end, nil, 0.15)
part("Head", nil, CHERRY, function(mesh)
	sphere(mesh, 0, -0.1, 3.0, 0.7, 1.35, 0.55, 8, 14)
end, true, 0.12)
part("Bowl", nil, BARE_METAL, function(mesh)
	sphere(mesh, 0, -0.5, 1.55, 0.85, 0.85, 0.6, 8, 16)
	ring(mesh, 0, -0.5, 1.95, 0.8, 0.9, 0.08, "z", 16)
end, true, 0.05)
part("Whisk", nil, BARE_METAL, function(mesh)
	cylinder(mesh, 0, -0.5, 2.35, 0.06, 0.6, "z", 6)
	for k = 0, 2 do
		local angle = k * TAU / 6
		local x, y = math.cos(angle) * 0.3, math.sin(angle) * 0.3
		tube(mesh, { { x, -0.5 + y, 2.2 }, { x * 1.4, -0.5 + y * 1.4, 1.9 }, { 0, -0.5, 1.6 }, { -x * 1.4, -0.5 - y * 1.4, 1.9 }, { -x, -0.5 - y, 2.2 } }, 0.02, 4)
	end
end, nil, 0.05)
part("Knob", nil, { 0.95, 0.93, 0.86 }, function(mesh)
	cylinder(mesh, 0.72, 0.2, 2.9, 0.16, 0.14, "x", 10)
end, nil, 0.05)
-- include: JunkrotFace
