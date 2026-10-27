-- A market stall at the origin, patched together from scrap: a corrugated
-- back wall and side panels on steel pipe posts, a concrete counter with a
-- plank top, a sloped striped awning with a scalloped edge, a shop sign
-- board, a hanging lamp and crates under the counter. Local +y is the back
-- wall. The including file sets AWNING, the shop's stripe color.
local CONCRETE = { 0.55, 0.54, 0.5 }
local PLANK = { 0.5, 0.36, 0.22 }
local CREAM = { 0.9, 0.86, 0.78 }

-- The awning slopes from 3.7 at the back wall down to 3.2 at the front edge.
local function awningZ(y: number): number
	return 3.2 + (y + 1) / 4.5 * 0.5
end

part("Counter", nil, CONCRETE, function(mesh)
	box(mesh, 0, 0, 0, 7, 0.9, 1.0)
	box(mesh, 0, -0.5, 0, 7.2, 0.15, 0.15)
end, nil, 0.4)

part("CounterTop", nil, PLANK, function(mesh)
	for n = 0, 3 do
		box(mesh, 0, -0.39 + n * 0.26, 1.0, 7.3, 0.24, 0.1)
	end
end, nil, 0.3)

part("Walls", nil, STEEL, function(mesh)
	for n = 0, 15 do
		box(mesh, -3.75 + n * 0.5, 3.55 + (n % 2) * 0.06, 0, 0.5, 0.06, 3.7)
	end
	for _, side in { -1, 1 } do
		for n = 0, 5 do
			box(mesh, side * 3.95 + (n % 2) * 0.06 * side, 1.15 + n * 0.45, 0, 0.06, 0.45, 2.4)
		end
	end
end, nil, 0.7)

part("Posts", nil, DARK_STEEL, function(mesh)
	for _, p in { { -3.85, -0.85 }, { 3.85, -0.85 }, { -3.85, 3.4 }, { 3.85, 3.4 } } do
		cylinder(mesh, p[1], p[2], awningZ(p[2]) / 2, 0.12, awningZ(p[2]), "z", 8)
		box(mesh, p[1], p[2], 0, 0.4, 0.4, 0.1)
	end
	-- Beams under the awning, front and back.
	cylinder(mesh, 0, -0.85, awningZ(-0.85) - 0.12, 0.1, 7.9, "x", 6)
	cylinder(mesh, 0, 3.4, awningZ(3.4) - 0.12, 0.1, 7.9, "x", 6)
	for _, x in { -3.85, 3.85 } do
		strut(mesh, x, -0.85, awningZ(-0.85) - 0.12, x, 3.4, awningZ(3.4) - 0.12, 0.08)
	end
	-- Lamp arm and shade.
	strut(mesh, 0, -0.6, awningZ(-0.6) - 0.1, 0, -0.6, awningZ(-0.6) - 0.6, 0.03)
	cylinder(mesh, 0, -0.6, awningZ(-0.6) - 0.65, 0.25, 0.12, "z", 10)
end, nil, 0.6)

local function awningStrips(mesh, first: number)
	for n = first, 7, 2 do
		local x = -4 + n + 0.5
		for k = 0, 8 do
			local y = -1 + k * 0.5
			box(mesh, x, y + 0.25, awningZ(y + 0.25), 1, 0.52, 0.08)
		end
		-- Scalloped flap hanging off the front edge.
		box(mesh, x, -1.05, awningZ(-1) - 0.35, 1, 0.04, 0.35)
		cylinder(mesh, x, -1.05, awningZ(-1) - 0.35, 0.5, 0.04, "y", 10)
	end
end

part("Awning", nil, AWNING, function(mesh)
	awningStrips(mesh, 0)
end, true, 0.2)

part("AwningStripes", nil, CREAM, function(mesh)
	awningStrips(mesh, 1)
end, true, 0.2)

part("SignBoard", nil, PLANK, function(mesh)
	box(mesh, 0, -1.15, awningZ(-1) + 0.05, 3.4, 0.1, 0.8)
	for _, x in { -1.4, 1.4 } do
		bolt(mesh, x, -1.21, awningZ(-1) + 0.45, "y", 0.08)
	end
end, nil, 0.3)

part("SignPanel", nil, AWNING, function(mesh)
	box(mesh, 0, -1.22, awningZ(-1) + 0.15, 3.0, 0.04, 0.6)
end, nil, 0.4)

part("Lamp", nil, { 1.0, 0.85, 0.5 }, function(mesh)
	sphere(mesh, 0, -0.6, awningZ(-0.6) - 0.78, 0.12, 0.12, 0.12, 4, 8)
end, true, 0, nil, 2)

part("Crates", nil, { 0.55, 0.42, 0.28 }, function(mesh)
	box(mesh, -3.0, 0.9, 0, 0.9, 0.8, 0.7)
	box(mesh, -2.95, 0.9, 0.7, 0.7, 0.6, 0.5)
end, nil, 0.3)
