-- Junk Mountain: the impassable boundary mountain, a tall stepped slope of
-- crushed car bales, plates and girders. One 16-stud section, back edge
-- along +y so sections line up into a ring. Centered on the origin.
local CAR_COLORS = { { 0.55, 0.14, 0.12 }, { 0.38, 0.42, 0.5 }, { 0.3, 0.36, 0.26 } }

part("Core", nil, RUST_DARK, function(mesh)
	for i = 0, 5 do
		box(mesh, 0, 2 + i * 1.0, i * 2.0, 16, 12 - i * 2, 2.0)
	end
end, nil, 0.9)

for index, color in CAR_COLORS do
	part("Bales" .. index, nil, color, function(mesh)
		for i = 0, 11 do
			if i % 3 + 1 ~= index then
				continue
			end
			local row = i % 4
			local x = -6 + ((i * 5) % 12) + (row % 2) * 1.2
			local y = -3.5 + row * 2
			box(mesh, x, y, row * 2 + 2, 2.2, 1.6, 1.4)
		end
	end, nil, 0.6)
end

part("Girders", nil, RUST_ORANGE, function(mesh)
	strut(mesh, -7, -3, 2.5, -4, 1, 8, 0.3)
	strut(mesh, 5, -2, 3, 7, 3, 10, 0.3)
	strut(mesh, -1, 0, 6, 2, 4, 11.5, 0.25)
end, nil, 0.85)

part("Tyres", nil, RUBBER_BLACK, function(mesh)
	ring(mesh, 2, -4, 2.3, 0.35, 0.7, 0.35, "z", 14)
	ring(mesh, -3, -2, 4.3, 0.35, 0.7, 0.35, "y", 14)
end, nil, RUBBER)

finishParts()
