-- Weapon Smith: an olive shop with a rebar rack out front. The shipping container shell from ShippingContainer, in its own
-- paint, with a sign board on the front top rail and decoration on the ground.
-- Local -y is the front.
local PAINT = { 0.35, 0.36, 0.2 }
local PLANK = { 0.5, 0.36, 0.22 }
local GLOW = { 1, 0.7, 0.35 }
local SIGN = { 0.25, 0.14, 0.08 }

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

part("Rebar", nil, RUST_ORANGE, function(mesh)
	for _, x in { -2.8, -1.9, -1.0, 1.0, 1.9, 2.8 } do
		strut(mesh, x, -HY - 0.6, 0.05, x, -HY - 0.6, 2.2, 0.05)
	end
end, nil, 0.5)

finishParts()
