-- Capsule, Prototype tier: a vacuum-sealed lab pod, 3 studs tall: a white
-- canister with rounded ends, a glowing glass window, a dark base ring and
-- a test-unit tag. Stands on the origin.
local LAB_WHITE = { 0.93, 0.95, 0.96 }
local GLASS_GLOW = { 0.45, 0.92, 1.0 }
local TAG_ORANGE = { 0.98, 0.55, 0.12 }
part("Pod", nil, LAB_WHITE, function(mesh)
	cylinder(mesh, 0, 0, 1.5, 1.0, 1.7, "z", 20)
	sphere(mesh, 0, 0, 2.35, 1.0, 1.0, 0.62, 6, 20)
	sphere(mesh, 0, 0, 0.65, 1.0, 1.0, 0.5, 6, 20)
end, true, 0)
part("Window", nil, GLASS_GLOW, function(mesh)
	-- A band of glass set into the front half.
	for i = 0, 6 do
		local angle = math.rad(-150 + i * 20)
		box(mesh, math.cos(angle) * 0.985, math.sin(angle) * 0.985, 1.2, 0.36, 0.1, 0.9)
	end
end, nil, 0, nil, 1.6)
part("Rings", nil, DARK_STEEL, function(mesh)
	ring(mesh, 0, 0, 0.14, 0.7, 1.04, 0.28, "z", 20)
	ring(mesh, 0, 0, 0.95, 1.0, 1.05, 0.1, "z", 20)
	ring(mesh, 0, 0, 2.3, 1.0, 1.05, 0.1, "z", 20)
	cylinder(mesh, 0, 0, 3.0, 0.3, 0.12, "z", 12)
end, nil, 0.05)
part("Tag", nil, TAG_ORANGE, function(mesh)
	box(mesh, 0.55, -0.9, 2.42, 0.5, 0.04, 0.3)
end, nil, 0)
finishParts()
