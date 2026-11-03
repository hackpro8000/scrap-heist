-- uses: ColumnIsland GroundTile MachinePad YardFence YardFenceHalf YardGate PlotMarker StorageCrate YardPath YardPathStub
-- Column Island Yard: a preview copy of the Yard Layout on the Column
-- Island.
-- Yard Layout: the template every player's 32x32 stud yard is built from,
-- centered on the origin with the gate at the front (-y). The gate is
-- centered in the front fence, a main path runs from it to the storage crate
-- centered at the back, and two machine pads stand on each side with a short
-- branch path to each. Pads are empty; machines are placed on them in game.
-- Labels: Gate, Crate, Pad1-Pad4 (left front, left back, right front, right
-- back), PlotMarker, plus Tile, Path and Fence pieces.

-- Preview of the yard standing on the column island, its grass top level
-- with the yard floor.
place("Island", buildColumnIsland, 0, 0, -0.45)

-- The crate shows empty in the template.
skipPart = function(name)
	return name:match("^Fill_") ~= nil
end

for i, x in { -12, -4, 4, 12 } do
	for j, y in { -12, -4, 4, 12 } do
		place(`Tile{(i - 1) * 4 + j}`, buildGroundTile, x, y, 0, ((x + y * 3) // 8 % 4) * 90)
	end
end

for i, pad in { { -9, 2 }, { -9, 10 }, { 9, 2 }, { 9, 10 } } do
	place(`Pad{i}`, buildMachinePad, pad[1], pad[2])
end
place("Crate", buildStorageCrate, 0, 12)

-- Main path from the gate to the crate, and a branch to each pad.
for i, y in { -12, -4, 4 } do
	place(`Path{i}`, buildYardPath, 0, y, 0.01)
end
for i, y in { 2, 10 } do
	place(`Branch{i * 2 - 1}`, buildYardPathStub, -4, y, 0.01, 90)
	place(`Branch{i * 2}`, buildYardPathStub, 4, y, 0.01, 90)
end

for i, c in { -12, -4, 4, 12 } do
	place(`FenceBack{i}`, buildYardFence, c, 16)
	place(`FenceLeft{i}`, buildYardFence, -16, c, 0, 90)
	place(`FenceRight{i}`, buildYardFence, 16, c, 0, 90)
end
for i, side in { -1, 1 } do
	place(`FenceFront{i}`, buildYardFence, side * 8, -16)
	place(`FenceFrontHalf{i}`, buildYardFenceHalf, side * 14, -16)
end
place("Gate", buildYardGate, 0, -16)
place("PlotMarker", buildPlotMarker, 6, -17.5)
