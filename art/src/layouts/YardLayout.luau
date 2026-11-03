-- uses: YardIsland GroundTile MachinePad YardFence YardFenceHalf YardFooting YardGate PlotMarker StorageCrate YardPath YardPathStub
-- Yard Layout: the template every player's 48x48 stud yard is built from,
-- centered on the origin with the gate at the front (-y). The gate is
-- centered in the front fence, a main path runs from it to the storage crate
-- centered at the back, and two machine pads stand on each side with a short
-- branch path to each. Pads are empty; machines are placed on them in game.
-- Labels: Gate, Crate, Pad1-Pad4 (left front, left back, right front, right
-- back), PlotMarker, plus Tile, Path and Fence pieces.

-- The yard stands on a Yard Island, its grass top level with the yard
-- floor, turned so the island's lobes sit under the fence corners and its
-- bays fall between them. Its turf stands 1.43 studs above its origin.
local ISLAND_TURN = 305
place("Island", buildYardIsland, 0, 0, -1.43, ISLAND_TURN)

-- The yard's pieces are laid out on a 32-stud plan and built YARD_SCALE
-- times their own size, so the avatar clears the gate.
local YARD_SCALE = 1.5
local function piece(label: string, build: () -> (), x: number, y: number, z: number?, turn: number?, stretch: number?, axis: string?)
	place(label, build, x * YARD_SCALE, y * YARD_SCALE, (z or 0) * YARD_SCALE, turn, stretch, axis, YARD_SCALE)
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

-- Pads stand clear of each other, the fences and the crate by at least 6
-- studs (4 on the plan), room for a player (4 x 5.5 x 4) to walk round.
local PAD_X = 8
local PAD_ROWS = { -8, 3.5 }
for i, pad in { { -PAD_X, PAD_ROWS[1] }, { -PAD_X, PAD_ROWS[2] }, { PAD_X, PAD_ROWS[1] }, { PAD_X, PAD_ROWS[2] } } do
	piece(`Pad{i}`, buildMachinePad, pad[1], pad[2])
end
piece("Crate", buildStorageCrate, 0, 12.95)

-- Main path from the gate to the crate, and a branch to each pad. The main
-- path's last piece is cut to reach the crate's front (y 10.57); each branch
-- is cut to span the gap between the path (half 2.03 wide) and its pad (half
-- 3.03 wide). Path pieces are 4.02 long.
for i, y in { -12, -4, 4 } do
	piece(`Path{i}`, buildYardPath, 0, y, 0.01)
end
local PATH_END, CRATE_FRONT = 8, 10.57
piece("Path4", buildYardPathStub, 0, (PATH_END + CRATE_FRONT) / 2, 0.01, 0, (CRATE_FRONT - PATH_END) / 4.02, "y")
local branchFrom, branchTo = 2.03, PAD_X - 3.03
for i, y in PAD_ROWS do
	local x, stretch = (branchFrom + branchTo) / 2, (branchTo - branchFrom) / 4.02
	piece(`Branch{i * 2 - 1}`, buildYardPathStub, -x, y, 0.01, 90, stretch, "y")
	piece(`Branch{i * 2}`, buildYardPathStub, x, y, 0.01, 90, stretch, "y")
end

for i, c in { -12, -4, 4, 12 } do
	piece(`FenceBack{i}`, buildYardFence, c, 16)
	piece(`FenceLeft{i}`, buildYardFence, -16, c, 0, 90)
	piece(`FenceRight{i}`, buildYardFence, 16, c, 0, 90)
	piece(`FootingBack{i}`, buildYardFooting, c, 16)
	piece(`FootingLeft{i}`, buildYardFooting, -16, c, 0, 90)
	piece(`FootingRight{i}`, buildYardFooting, 16, c, 0, 90)
end
for i, side in { -1, 1 } do
	piece(`FenceFront{i}`, buildYardFence, side * 8, -16)
	piece(`FenceFrontHalf{i}`, buildYardFenceHalf, side * 14, -16)
	piece(`FootingFront{i}`, buildYardFooting, side * 8, -16)
	piece(`FootingFrontHalf{i}`, buildYardFooting, side * 14, -16, 0, 0, 0.5)
end
piece("Gate", buildYardGate, 0, -16)
piece("PlotMarker", buildPlotMarker, 6, -17.5)
