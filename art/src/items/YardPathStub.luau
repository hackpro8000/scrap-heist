-- Yard Path Stub: a 4x4 stud stretch of walkway for short branches off the
-- main path, running along y and centered on the origin. Same pavers and
-- gravel bed as YardPath, with one sunk paver and a cracked one.
BRUSHED = true
local CONCRETE = { 0.6, 0.59, 0.56 }
local GRAVEL = { 0.36, 0.34, 0.31 }

part("Gravel", nil, GRAVEL, function(mesh)
	box(mesh, 0, 0, -0.04, 4, 4, 0.06)
end, nil, 0.2)

part("Pavers", nil, CONCRETE, function(mesh)
	for row = 0, 1 do
		for column = 0, 1 do
			local key = row * 2 + column
			local x = -1 + column * 2 + (if key % 3 == 0 then 0.06 else -0.04)
			local y = -1 + row * 2 + (if key % 2 == 0 then 0.05 else -0.05)
			local sink = if key == 1 then -0.05 else 0
			if key == 2 then
				-- Cracked paver: two halves with a gap between them.
				box(mesh, x - 0.47, y, sink, 0.86, 1.84, 0.1)
				box(mesh, x + 0.47, y + 0.04, sink - 0.02, 0.86, 1.8, 0.1)
			else
				box(mesh, x, y, sink, 1.84, 1.84, 0.1)
			end
		end
	end
end, nil, 0.35)

part("Grit", nil, DARK_STEEL, function(mesh)
	bolt(mesh, 1.2, -0.1, 0.02, "z", 0.06)
	box(mesh, -1.4, 0.05, 0.02, 0.3, 0.18, 0.05)
end, nil, 0.7)

finishParts()
