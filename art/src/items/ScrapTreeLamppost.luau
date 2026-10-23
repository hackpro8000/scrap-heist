-- Scrap Tree (Lamppost): a bent city lamppost standing in for a tree. Its
-- crown is a cluster of hubcaps welded onto the lamp arms like leaves, with
-- a rubble root ball of concrete chunks around the base.
local CONCRETE = { 0.6, 0.59, 0.56 }

part("Trunk", nil, DARK_STEEL, function(mesh)
	cylinder(mesh, 0, 0, 0, 0.45, 0.6, "z", 10)
	tube(mesh, { { 0, 0, 0.5 }, { 0.1, 0, 4 }, { 0.4, 0.1, 7.5 }, { 0.2, 0, 10 } }, 0.22, 8)
	-- Lamp arms reaching out as branches.
	tube(mesh, { { 0.3, 0, 8 }, { 1.6, 0.4, 9.2 }, { 2.6, 0.6, 9.4 } }, 0.12, 6)
	tube(mesh, { { 0.3, 0, 8.8 }, { -1.4, -0.6, 10 }, { -2.4, -0.8, 10.1 } }, 0.12, 6)
	tube(mesh, { { 0.2, 0, 9.6 }, { 0.6, 1.6, 10.8 }, { 0.8, 2.2, 11 } }, 0.1, 6)
end, true, 0.6)

part("Hubcaps", nil, STEEL, function(mesh)
	local spots = {
		{ 2.6, 0.6, 9.2 }, { 2, -0.6, 10.2 }, { -2.4, -0.8, 9.9 }, { -1.6, 0.6, 10.8 },
		{ 0.8, 2.2, 10.8 }, { -0.4, -1.8, 10.6 }, { 0.2, 0, 11.4 }, { 1.4, 1, 11.6 },
		{ -1, -0.2, 11.9 }, { 0.6, -1, 12.2 }, { 1.6, -1.6, 9.4 }, { -1.8, 1.8, 9.8 },
	}
	for i, p in spots do
		local axis = if i % 3 == 0 then "x" elseif i % 3 == 1 then "z" else "y"
		ring(mesh, p[1], p[2], p[3], 0.15, 0.9, 0.12, axis, 12)
		cylinder(mesh, p[1], p[2], p[3], 0.3, 0.16, axis, 8)
	end
end, nil, 0.3)

part("Lamp", nil, COPPER, function(mesh)
	box(mesh, 0.2, 0, 10, 0.8, 0.5, 0.3)
end, nil, 0.5)

part("Rubble", nil, CONCRETE, function(mesh)
	box(mesh, 0.8, 0.3, 0, 0.9, 0.7, 0.4)
	box(mesh, -0.7, 0.5, 0, 0.7, 0.8, 0.3)
	box(mesh, 0.1, -0.9, 0, 0.8, 0.6, 0.35)
end, nil, 0.2)

finishParts()
