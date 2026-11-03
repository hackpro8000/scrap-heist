-- Bush Cans: a low clump of crushed paint and soda cans heaped into a bush
-- shape, centered on the origin. Crushed cans are squat, tilted cylinders;
-- a few whole ones sit on top.
local CAN_RED = { 0.62, 0.16, 0.12 }
local CAN_BLUE = { 0.18, 0.3, 0.55 }
local CAN_YELLOW = { 0.9, 0.72, 0.1 }

-- Deterministic dome scatter so the heap doesn't change between builds;
-- colors are dealt round-robin so they mix through the whole clump.
local function cans(colorIndex)
	local list = {}
	for i = 1, 54 do
		if (i * 5) % 3 + 1 ~= colorIndex then
			continue
		end
		local a = i * 2.399
		local ring = math.sqrt(i / 54)
		local r = ring * 1.4
		local z = 0.15 + math.sqrt(1 - ring * ring * 0.9) * 1.1
		table.insert(list, { math.cos(a) * r, math.sin(a) * r, z, i })
	end
	return list
end

local function crushedCan(mesh, x, y, z, k)
	local axis = if k % 2 == 0 then "x" else "y"
	local length = 0.22 + (k % 4) * 0.05
	cylinder(mesh, x, y, z, 0.2, length, axis, 10)
end

for index, color in { CAN_RED, CAN_BLUE, STEEL } do
	part("Cans" .. index, nil, color, function(mesh)
		for _, can in cans(index) do
			crushedCan(mesh, can[1], can[2], can[3], can[4])
		end
	end, nil, 0.5)
end

part("WholeCans", nil, CAN_YELLOW, function(mesh)
	cylinder(mesh, 0.1, 0.2, 1.65, 0.2, 0.45, "z", 12)
	cylinder(mesh, -0.4, -0.2, 1.45, 0.2, 0.45, "x", 12)
	cylinder(mesh, 0.5, -0.3, 1.4, 0.2, 0.45, "y", 12)
end, nil, 0.3)

part("Lids", nil, DARK_STEEL, function(mesh)
	ring(mesh, 0.1, 0.2, 1.9, 0.12, 0.2, 0.03, "z", 12)
	cylinder(mesh, 1.3, 0.4, 0.03, 0.22, 0.04, "z", 12)
	cylinder(mesh, -1.2, 0.7, 0.03, 0.22, 0.04, "z", 12)
end, nil, 0.6)

finishParts()
