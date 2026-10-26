-- Yard Path: one 4x8 stud stretch of walkway, running along y and centered
-- on the origin. Worn concrete pavers laid two across on a gravel bed, a
-- few cracked, sunk or missing, so segments laid end to end don't repeat
-- too obviously. Paver tops sit just above z 0 so they read over a ground
-- tile.
BRUSHED = true
local CONCRETE = { 0.6, 0.59, 0.56 }
local GRAVEL = { 0.36, 0.34, 0.31 }

part("Gravel", nil, GRAVEL, function(mesh)
	box(mesh, 0, 0, -0.04, 4, 8, 0.06)
end, nil, 0.2)

part("Pavers", nil, CONCRETE, function(mesh)
	for row = 0, 3 do
		for column = 0, 1 do
			local key = row * 2 + column
			if key == 5 then
				continue
			end
			local x = -1 + column * 2 + (if key % 3 == 0 then 0.06 else -0.04)
			local y = -3 + row * 2 + (if key % 2 == 0 then 0.05 else -0.05)
			local sink = if key == 2 then -0.05 else 0
			if key == 6 then
				-- Cracked paver: two halves with a gap between them.
				box(mesh, x - 0.47, y, sink, 0.86, 1.84, 0.1)
				box(mesh, x + 0.47, y + 0.04, sink - 0.02, 0.86, 1.8, 0.1)
			else
				box(mesh, x, y, sink, 1.84, 1.84, 0.1)
			end
		end
	end
	-- Broken corner left where the missing paver was.
	box(mesh, -0.6, 1.4, -0.02, 0.6, 0.5, 0.08)
end, nil, 0.35)

part("Grit", nil, DARK_STEEL, function(mesh)
	bolt(mesh, 1.3, 1.2, 0.02, "z", 0.06)
	box(mesh, -1.5, 1.0, 0.02, 0.3, 0.18, 0.05)
	ring(mesh, 0.9, 0.6, 0.02, 0.06, 0.13, 0.04, "z", 8)
end, nil, 0.7)

finishParts()
