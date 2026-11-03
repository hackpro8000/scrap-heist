-- Tank: an olive shop with rust-orange drums stacked out front. The shipping container shell from ShippingContainer, in its own
-- paint, with a sign board on the front top rail and decoration on the ground.
-- Local -y is the front.
local PAINT = { 0.3, 0.34, 0.22 }
local PLANK = { 0.5, 0.36, 0.22 }
local GLOW = { 1, 0.4, 0.2 }
local SIGN = { 0.2, 0.2, 0.2 }

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

part("Drums", nil, { 0.55, 0.25, 0.12 }, function(mesh)
	for _, x in { -2.0, 0, 2.0 } do
		cylinder(mesh, x, -HY - 0.6, 0.4, 0.4, 0.8, "y", 14)
		cylinder(mesh, x, -HY - 0.6, 1.2, 0.4, 0.8, "y", 14)
	end
end, nil, 0.6)

finishParts()
