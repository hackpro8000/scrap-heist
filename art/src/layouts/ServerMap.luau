-- uses:
-- Server Map: one server's whole map, centered on the origin. Eight yards
-- stand in a ring with their gates facing a central arena, joined to it by
-- a ring road and a spoke from each gate. The arena is the storm fight
-- ground and, between storms, the spawn plaza new players start on.
-- Blockout: gray blocks for footprints only; the real pieces come later.
-- Labels: Ground, Road, Arena, Spawn, Cover1-Cover8, Yard1-Yard8 (each with
-- Slab, Walls, Crate and Pads parts), Spoke1-Spoke8.
local YARD_RADIUS = 90
local ROAD_INNER, ROAD_OUTER = 50, 58
local ARENA_RADIUS = 44

local GROUND = { 0.3, 0.27, 0.22 }
local ROAD = { 0.42, 0.41, 0.4 }
local BLOCK = { 0.62, 0.62, 0.62 }
local MARK = { 0.85, 0.65, 0.15 }

-- Places one blockout piece: its parts are built, shaded and added under
-- its label before the next piece starts.
local function block(label: string, build: () -> (), x: number, y: number, z: number?, turn: number?)
	place(label, function()
		build()
		finishParts()
		table.clear(parts)
	end, x, y, z, turn)
end

block("Ground", function()
	part("Slab", nil, GROUND, function(mesh)
		box(mesh, 0, 0, -0.4, 240, 240, 0.4)
	end, nil, 0)
end, 0, 0)

block("Road", function()
	part("Ring", nil, ROAD, function(mesh)
		ring(mesh, 0, 0, 0, ROAD_INNER, ROAD_OUTER, 0.1, "z", 48)
	end, nil, 0)
end, 0, 0)

block("Arena", function()
	part("Floor", nil, BLOCK, function(mesh)
		cylinder(mesh, 0, 0, 0, ARENA_RADIUS, 0.2, "z", 48)
	end, nil, 0)
end, 0, 0)
block("Spawn", function()
	part("Pad", nil, MARK, function(mesh)
		cylinder(mesh, 0, 0, 0.2, 6, 0.1, "z", 24)
	end, nil, 0)
end, 0, 0)

-- Cover for the storm fights, offset from the spokes so paths stay open.
for i = 1, 8 do
	local angle = math.rad((i - 0.5) * 45)
	block(`Cover{i}`, function()
		part("Block", nil, BLOCK, function(mesh)
			box(mesh, 0, 0, 0, 8, 3, 3)
		end, nil, 0)
	end, math.cos(angle) * 26, math.sin(angle) * 26, 0.2, (i - 0.5) * 45)
end

-- Each yard is turned so its gate (local -y) faces the arena.
for i = 1, 8 do
	local degrees = (i - 1) * 45
	local angle = math.rad(degrees)
	local x, y = math.cos(angle) * YARD_RADIUS, math.sin(angle) * YARD_RADIUS
	block(`Yard{i}`, function()
		part("Slab", nil, BLOCK, function(mesh)
			box(mesh, 0, 0, 0, 32, 32, 0.3)
		end, nil, 0)
		part("Walls", nil, BLOCK, function(mesh)
			box(mesh, 0, 16, 0, 32, 0.4, 5)
			box(mesh, -16, 0, 0, 0.4, 32, 5)
			box(mesh, 16, 0, 0, 0.4, 32, 5)
			box(mesh, -10, -16, 0, 12, 0.4, 5)
			box(mesh, 10, -16, 0, 12, 0.4, 5)
		end, nil, 0)
		part("Crate", nil, MARK, function(mesh)
			box(mesh, 0, 12, 0.3, 6, 4, 3)
		end, nil, 0)
		part("Pads", nil, ROAD, function(mesh)
			for _, pad in { { -9, 2 }, { -9, 10 }, { 9, 2 }, { 9, 10 } } do
				box(mesh, pad[1], pad[2], 0.3, 6, 6, 0.1)
			end
		end, nil, 0)
	end, x, y, 0, degrees - 90)
	block(`Spoke{i}`, function()
		part("Road", nil, ROAD, function(mesh)
			box(mesh, 0, -24, 0, 6, 17, 0.1)
		end, nil, 0)
	end, x, y, 0, degrees - 90)
end
