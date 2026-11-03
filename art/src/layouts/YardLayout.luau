-- uses: ColumnIsland GroundTile MachinePad YardFence YardFenceHalf YardGate PlotMarker StorageCrate YardPath YardPathStub
-- Yard Layout: the template every player's 48x48 stud yard is built from,
-- centered on the origin with the gate at the front (-y). The gate is
-- centered in the front fence, a main path runs from it to the storage crate
-- centered at the back, and two machine pads stand on each side with a short
-- branch path to each. Pads are empty; machines are placed on them in game.
-- Labels: Gate, Crate, Pad1-Pad4 (left front, left back, right front, right
-- back), PlotMarker, plus Tile, Path and Fence pieces.

-- The yard stands on a Column Island, its grass top level with the yard
-- floor, turned so the island's lobes sit under the fence corners and its
-- bays fall between them.
local ISLAND_TURN = 305
place("Island", buildColumnIsland, 0, 0, -0.45, ISLAND_TURN)

-- The yard's pieces are laid out on a 32-stud plan and built YARD_SCALE
-- times their own size, so the avatar clears the gate.
local YARD_SCALE = 1.5
local function piece(label: string, build: () -> (), x: number, y: number, z: number?, turn: number?)
	place(label, build, x * YARD_SCALE, y * YARD_SCALE, (z or 0) * YARD_SCALE, turn, nil, nil, YARD_SCALE)
end

-- The crate shows empty in the template.
skipPart = function(name)
	return name:match("^Fill_") ~= nil
end

for i, x in { -12, -4, 4, 12 } do
	for j, y in { -12, -4, 4, 12 } do
		piece(`Tile{(i - 1) * 4 + j}`, buildGroundTile, x, y, 0, ((x + y * 3) // 8 % 4) * 90)
	end
end

for i, pad in { { -9, 2 }, { -9, 10 }, { 9, 2 }, { 9, 10 } } do
	piece(`Pad{i}`, buildMachinePad, pad[1], pad[2])
end
piece("Crate", buildStorageCrate, 0, 12)

-- Main path from the gate to the crate, and a branch to each pad.
for i, y in { -12, -4, 4 } do
	piece(`Path{i}`, buildYardPath, 0, y, 0.01)
end
for i, y in { 2, 10 } do
	piece(`Branch{i * 2 - 1}`, buildYardPathStub, -4, y, 0.01, 90)
	piece(`Branch{i * 2}`, buildYardPathStub, 4, y, 0.01, 90)
end

for i, c in { -12, -4, 4, 12 } do
	piece(`FenceBack{i}`, buildYardFence, c, 16)
	piece(`FenceLeft{i}`, buildYardFence, -16, c, 0, 90)
	piece(`FenceRight{i}`, buildYardFence, 16, c, 0, 90)
end
for i, side in { -1, 1 } do
	piece(`FenceFront{i}`, buildYardFence, side * 8, -16)
	piece(`FenceFrontHalf{i}`, buildYardFenceHalf, side * 14, -16)
end
piece("Gate", buildYardGate, 0, -16)
piece("PlotMarker", buildPlotMarker, 6, -17.5)
