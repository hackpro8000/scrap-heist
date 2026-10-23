-- Traffic Cones: a knocked-over cluster of road cones, one standing, one on
-- its side, one crushed flat. Centered on the origin.
local CONE = { 0.95, 0.42, 0.1 }
local STRIPE = { 0.92, 0.92, 0.9 }

local function cone(mesh, x, y)
	for i = 0, 5 do
		local r = 0.32 - i * 0.05
		cylinder(mesh, x, y, 0.15 + i * 0.18, r, 0.19, "z", 12)
	end
end

part("Cones", nil, CONE, function(mesh)
	cone(mesh, 0, 0)
	-- Fallen cone along x.
	for i = 0, 5 do
		cylinder(mesh, 0.7 + i * 0.18, 0.7, 0.3, 0.32 - i * 0.05, 0.19, "x", 12)
	end
	box(mesh, -0.9, 0.3, 0, 0.7, 0.5, 0.12)
end, nil, 0.4)

part("Bases", nil, RUBBER_BLACK, function(mesh)
	box(mesh, 0, 0, 0, 0.8, 0.8, 0.08)
	box(mesh, 0.6, 0.7, 0, 0.08, 0.8, 0.7)
end, nil, RUBBER)

part("Stripes", nil, STRIPE, function(mesh)
	cylinder(mesh, 0, 0, 0.6, 0.25, 0.12, "z", 12)
	cylinder(mesh, 1.1, 0.7, 0.3, 0.25, 0.12, "x", 12)
end, nil, 0.4)

finishParts()
