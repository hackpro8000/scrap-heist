-- Car Stack: three flattened car shells stacked at angles, the classic
-- scrapyard tower. Centered on the origin.
local COLORS = { { 0.55, 0.14, 0.12 }, { 0.2, 0.32, 0.5 }, { 0.82, 0.8, 0.74 } }

local function shell(mesh, x, y, z, flip)
	box(mesh, x, y, z, 4.2, 1.9, 0.7)
	box(mesh, x + flip * 0.2, y, z + 0.7, 2.2, 1.7, 0.35)
end

for index, color in COLORS do
	part("Car" .. index, nil, color, function(mesh)
		local i = index - 1
		shell(mesh, (i % 2) * 0.4 - 0.2, i * 0.15, 0.45 + i * 1.05, if i % 2 == 0 then 1 else -1)
	end, nil, 0.7)
end

part("Wheels", nil, RUBBER_BLACK, function(mesh)
	for _, x in { -1.3, 1.3 } do
		for _, y in { -0.95, 0.95 } do
			cylinder(mesh, x - 0.2, y, 0.42, 0.42, 0.3, "y", 12)
		end
	end
end, nil, RUBBER)

part("Glass", nil, DARK_STEEL, function(mesh)
	for i = 0, 2 do
		box(mesh, (i % 2) * 0.4 - 0.2, i * 0.15 - 0.86, 1.2 + i * 1.05, 2.0, 0.04, 0.25)
	end
end, nil, 0.3)

finishParts()
