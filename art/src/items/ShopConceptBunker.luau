-- Bunker: a grey shop with a course of oil drums out front. The shipping container shell from ShippingContainer, in its own
-- paint, with a sign board on the front top rail and decoration on the ground.
-- Local -y is the front.
local PAINT = { 0.5, 0.5, 0.47 }
local PLANK = { 0.5, 0.36, 0.22 }
local GLOW = { 1, 0.85, 0.5 }
local SIGN = { 0.6, 0.1, 0.1 }

-- include: ShippingContainer

-- A sign board hung off the top front rail on two short brackets.
part("Sign", nil, SIGN, function(mesh)
	box(mesh, 0, -HY - 0.12, TOP - 0.2, 3.4, 0.12, 0.8)
	for _, x in { -1.2, 1.2 } do
		strut(mesh, x, -HY - 0.05, TOP - 0.1, x, -HY - 0.12, TOP - 0.1, 0.05)
	end
end, nil, 0.4)

part("Lights", nil, GLOW, function(mesh)
	for x = -1.2, 1.2, 0.6 do
		sphere(mesh, x, -HY - 0.2, TOP - 0.2, 0.1, 0.1, 0.1, 4, 6)
	end
end, nil, 0, nil, 2)

part("Drums", nil, { 0.2, 0.3, 0.42 }, function(mesh)
	for _, x in { -2.2, -0.73, 0.73, 2.2 } do
		cylinder(mesh, x, -HY - 0.6, 0.4, 0.4, 0.8, "y", 14)
	end
end, nil, 0.6)

finishParts()
