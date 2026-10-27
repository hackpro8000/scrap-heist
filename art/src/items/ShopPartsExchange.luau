-- Parts Exchange: a green stall of sorted scrap bins in front, with a price board. The shipping container shell from ShippingContainer, in its own
-- paint, with a sign board on the front top rail and decoration on the ground.
-- Local -y is the front.
local PAINT = { 0.2, 0.45, 0.25 }
local PLANK = { 0.5, 0.36, 0.22 }
local GLOW = { 0.5, 1, 0.55 }
local SIGN = { 0.1, 0.12, 0.12 }

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

part("Bins", nil, { 0.25, 0.42, 0.6 }, function(mesh)
	for n = 0, 2 do
		box(mesh, -2.2 + n * 1.1, -HY - 0.5, 0, 1.0, 0.9, 0.9)
	end
end, nil, 0.4)

finishParts()
