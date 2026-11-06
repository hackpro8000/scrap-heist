-- Telefono Ringaling: a rotary phone in fresh red, dial on its chest and
-- the handset across its head like a hat, cord trailing, 2.8 studs tall.
local FACE = { { -0.42, -1.02, 1.75, 0.22 }, { 0.42, -1.02, 1.8, 0.25 } }
local FEET = { 1.1, 0.5 }
local PHONE_RED = { 0.8, 0.14, 0.14 }
part("Base", nil, PHONE_RED, function(mesh)
	box(mesh, 0, 0, 0.6, 2.4, 2.0, 0.9)
	box(mesh, 0, 0.1, 1.5, 1.8, 1.5, 0.6)
end, nil, 0.12)
part("Dial", nil, { 0.93, 0.9, 0.82 }, function(mesh)
	cylinder(mesh, 0, -1.02, 1.1, 0.5, 0.08, "y", 18)
end, nil, 0.05)
part("Holes", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	for k = 0, 8 do
		local angle = math.rad(-60 + k * 33)
		cylinder(mesh, math.cos(angle) * 0.36, -1.07, 1.1 + math.sin(angle) * 0.36, 0.07, 0.04, "y", 8)
	end
end, nil, 0.05)
part("Handset", nil, PHONE_RED, function(mesh)
	cylinder(mesh, 0, 0.1, 2.5, 0.2, 2.2, "x", 10)
	for _, x in { -1.1, 1.1 } do
		cylinder(mesh, x, 0.1, 2.3, 0.4, 0.5, "z", 12)
	end
end, nil, 0.12)
part("Cradle", nil, BARE_METAL, function(mesh)
	for _, x in { -0.5, 0.5 } do
		box(mesh, x, 0.1, 2.1, 0.2, 0.5, 0.25)
	end
end, nil, 0.05)
part("Cord", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	local points = {}
	for step = 0, 14 do
		table.insert(points, { -1.2 - step * 0.07, 0.4 + math.sin(step * 1.6) * 0.14, 2.0 - step * 0.11 + math.cos(step * 1.6) * 0.14 })
	end
	tube(mesh, points, 0.04, 5)
end, true, RUBBER)
-- include: JunkrotFace
