-- Machine Shop: sells salvage machines. The shipping container shell from
-- ShippingContainer in blue-grey paint, a sign board on the front top rail,
-- two display plinths out front where the machines stand, and a price board
-- on the counter. Local -y is the front.
local PAINT = { 0.3, 0.38, 0.46 }
local PLANK = { 0.5, 0.36, 0.22 }
local GLOW = { 0.6, 0.9, 1 }
local SIGN = { 0.12, 0.14, 0.18 }
local CONCRETE = { 0.55, 0.54, 0.5 }

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

-- Two display plinths out front, one each side of the opening, with a gear
-- set on top of each where the machine stands.
part("Plinths", nil, CONCRETE, function(mesh)
	for _, x in { -2.4, 2.4 } do
		box(mesh, x, -HY - 0.8, 0, 1.4, 1.2, 0.7)
		gear(mesh, x, -HY - 0.8, 0.85, 0.3, 0.08, 10, "z")
	end
end, nil, 0.5)

-- The price board on the counter front, with a row of glowing digits.
part("PriceBoard", nil, RUBBER_BLACK, function(mesh)
	box(mesh, 0, -HY - 0.4, 0.75, 2.6, 0.08, 0.5)
end, nil, 0.2)

part("Digits", nil, GLOW, function(mesh)
	for n = 0, 3 do
		box(mesh, -0.9 + n * 0.6, -HY - 0.46, 0.8, 0.4, 0.02, 0.2)
	end
end, nil, 0, nil, 2)

finishParts()
