-- Brick Ruin: the corner of a collapsed brick building, two broken walls
-- with a window gap and rubble at the base. Centered on the origin.
local BRICK = { 0.5, 0.24, 0.18 }
local CONCRETE = { 0.6, 0.59, 0.56 }

local HEIGHTS = { 4, 3.6, 2.8, 3.2, 2, 1.4, 0.8 }

part("Bricks", nil, BRICK, function(mesh)
	for i, h in HEIGHTS do
		local x = -3 + (i - 1) * 0.8
		if i == 3 then
			box(mesh, x, -2.4, 0, 0.8, 0.5, 1.0)
			box(mesh, x, -2.4, 2.2, 0.8, 0.5, h - 2.2)
		else
			box(mesh, x, -2.4, 0, 0.8, 0.5, h)
		end
		box(mesh, -3.2, -2.4 + i * 0.7, 0, 0.5, 0.7, h * 0.85)
	end
	-- Rubble.
	for i = 0, 9 do
		local a = i * 2.4
		box(mesh, -1.2 + math.cos(a) * 1.4, -1.1 + math.sin(a) * 1.0, 0, 0.4, 0.25, 0.2 + (i % 3) * 0.08)
	end
end, nil, 0.3)

part("Lintel", nil, CONCRETE, function(mesh)
	box(mesh, -1.4, -2.4, 2.1, 1.2, 0.55, 0.15)
	box(mesh, 0.2, -1.6, 0, 1.4, 0.6, 0.3)
end, nil, 0.4)

part("Rebar", nil, RUST_DARK, function(mesh)
	strut(mesh, 0.2, -2.4, 0.8, 1.0, -2.2, 2.0, 0.05)
	strut(mesh, -3.2, 2.5, 0.6, -3.0, 3.1, 1.4, 0.05)
end, nil, 0.9)

finishParts()
