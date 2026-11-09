-- Hub Tinkerer: an open lean-to workshop where parts are spent on upgrades
-- (art/concepts/town-pieces-sketch.png, plan in HubTinkerer.plan.luau). Local -y
-- is the open front.
-- include: HandFinish
-- include: TownClutter
-- include: WarpedMesh
useTexelDensity(32)

local PLATE = { 0.22, 0.24, 0.28 }
local STAIN = { 0.11, 0.11, 0.13 }
local SEAM = { 0.14, 0.15, 0.18 }
local WALL = { 0.27, 0.42, 0.52 }
local TIN = { 0.44, 0.5, 0.56 }
local PIPE = { 0.23, 0.24, 0.28 }
local PLANK = { 0.5, 0.36, 0.22 }
local YELLOW = { 0.86, 0.66, 0.18 }
local RUSTED = { 0.62, 0.36, 0.19 }
local IRON = { 0.2, 0.2, 0.23 }
local TOOL = { 0.62, 0.64, 0.67 }
local HOSE = { 0.12, 0.12, 0.14 }
local BRASS = { 0.84, 0.62, 0.18 }

local FLOOR = 0.5
local BENCH_TOP = 3.3
local ANVIL_X, ANVIL_Y = 4, -3.6
-- The roof falls toward the back wall.
local ROOF_Z, ROOF_FALL = 8.05, 0.06
local function roofRise(y: number): number
	return (1.5 - y) * ROOF_FALL
end

part("Deck", nil, PLATE, function(mesh)
	box(mesh, 0, 0, 0, 18, 18, FLOOR)
	for x = -6, 6, 6 do
		for y = -8.6, 8.6, 1.9 do
			bolt(mesh, x + 0.25, y, FLOOR, "z", 0.1)
		end
	end
end, nil, function(x, y, _z)
	if math.abs(((x + 3) % 6) - 3) < 0.09 or math.abs(((y + 3) % 6) - 3) < 0.09 then
		return SEAM[1], SEAM[2], SEAM[3]
	end
	-- Thin, uneven oil stains under the bench, where it drips.
	local bench = math.max(math.abs(x) - 6.5, math.abs(y - 3.5) - 1.9)
	local blotch = math.noise(x * 0.7, y * 0.7, 3) + 0.4 * math.noise(x * 2.3, y * 2.3, 8)
	local oil = math.clamp((0.9 - bench - blotch * 2) / 1.6, 0, 1) * 0.72
	return PLATE[1] + (STAIN[1] - PLATE[1]) * oil, PLATE[2] + (STAIN[2] - PLATE[2]) * oil, PLATE[3] + (STAIN[3] - PLATE[3]) * oil
end)

part("BackWall", nil, WALL, function(mesh)
	box(mesh, 0, 7.5, FLOOR, 16, 0.5, 7.1)
	-- Regular corrugation, in sheets that lap over each other with fixings.
	for x = -7.8, 7.8, 0.4 do
		box(mesh, x, 7.27, FLOOR, 0.2, 0.1, 7.1)
		box(mesh, x + 0.2, 7.76, FLOOR, 0.2, 0.1, 7.1)
	end
	for _, x in { -5.3, 0.1, 5.5 } do
		box(mesh, x, 7.2, FLOOR, 0.3, 0.16, 7.1)
		box(mesh, x, 7.82, FLOOR, 0.3, 0.16, 7.1)
		for z = FLOOR + 0.5, 7, 1.3 do
			bolt(mesh, x, 7.12, z, "y", 0.08)
			bolt(mesh, x, 7.91, z, "y", 0.08)
		end
	end
	box(mesh, 0, 7.2, FLOOR + 6.7, 16.2, 0.3, 0.4)
end, nil, 0)

part("ToolRack", nil, PLANK, function(mesh)
	box(mesh, -3.5, 7.1, 3.8, 7, 0.4, 2.9)
	for x = -6.5, -0.5, 1.5 do
		box(mesh, x, 6.8, 5.75, 0.14, 0.3, 0.14)
	end
end, nil, 0)

part("RackTools", nil, TOOL, function(mesh)
	local y = 6.74
	-- A long spanner, a claw hammer, a saw and a big wrench, each on its peg.
	box(mesh, -6.5, y, 4, 0.16, 0.1, 1.75)
	ring(mesh, -6.5, y, 5.75, 0.09, 0.22, 0.1, "y", 14)
	ring(mesh, -6.5, y, 3.95, 0.1, 0.24, 0.1, "y", 14)
	box(mesh, -5, y, 5.5, 1.05, 0.2, 0.34)
	strut(mesh, -4.52, y, 5.7, -4.3, y, 5.4, 0.14)
	-- A tapered hand saw.
	strut(mesh, -3.5, y, 5.65, -3.5, y, 4.05, 0.62)
	strut(mesh, -3.5, y, 4.7, -3.5, y, 3.9, 0.3)
	-- Pliers, jaws up.
	strut(mesh, -2.14, y, 4, -1.9, y, 5.5, 0.13)
	strut(mesh, -1.86, y, 4, -2.1, y, 5.5, 0.13)
	strut(mesh, -2.05, y, 5.45, -2.02, y, 5.95, 0.3)
	box(mesh, -0.5, y, 4.7, 0.16, 0.1, 1.1)
	box(mesh, -0.5, y, 4.3, 0.56, 0.14, 0.46)
end, nil, 0)

part("ToolGrips", nil, { 0.32, 0.2, 0.12 }, function(mesh)
	local y = 6.72
	box(mesh, -5, y, 3.9, 0.24, 0.14, 1.65)
	box(mesh, -3.5, y, 5.7, 0.55, 0.18, 0.38)
	box(mesh, -0.5, y, 5.75, 0.26, 0.14, 0.42)
end, nil, 0)

local function tiltedRoof(mesh)
	return warped(mesh, function(x, y, z)
		return x, y, z + roofRise(y)
	end)
end

part("Roof", nil, TIN, function(built)
	local mesh = tiltedRoof(built)
	box(mesh, 0, 1.5, ROOF_Z - 0.1, 18, 14, 0.1)
	for x = -8.5, 8.5, 0.8 do
		box(mesh, x, 1.5, ROOF_Z, 0.34, 14, 0.12)
		box(mesh, x + 0.4, 1.5, ROOF_Z - 0.2, 0.34, 14, 0.12)
	end
	box(mesh, 0, -5.2, ROOF_Z - 0.46, 18, 0.5, 0.36)
end, nil, 0.05)

part("Rafters", nil, { 0.16, 0.17, 0.2 }, function(built)
	local mesh = tiltedRoof(built)
	box(mesh, 0, 7.1, ROOF_Z - 0.52, 18, 0.4, 0.36)
	for x = -7.5, 7.5, 3 do
		box(mesh, x, 1, ROOF_Z - 0.55, 0.42, 12.6, 0.4)
	end
end, nil, 0)

part("RoofPosts", nil, PIPE, function(mesh)
	local top = ROOF_Z - 0.38 + roofRise(-5)
	for _, x in { -8, 8 } do
		cylinder(mesh, x, -5, (FLOOR + top) / 2, 0.25, top - FLOOR, "z", 10)
		box(mesh, x, -5, FLOOR, 0.8, 0.8, 0.12)
		-- A knee brace up to the front beam, and a bracket at the post top.
		strut(mesh, x, -5, 6.6, x - math.sign(x) * 1.5, -5, top - 0.1, 0.18)
		box(mesh, x, -5, top - 0.5, 0.74, 0.74, 0.4)
	end
end, nil, 0.1)

part("Workbench", nil, PLANK, function(mesh)
	box(mesh, 0, 3.5, BENCH_TOP - 0.3, 13, 3.5, 0.3)
	for _, x in { -6, 6 } do
		for _, y in { 2.1, 4.9 } do
			box(mesh, x, y, FLOOR, 0.4, 0.4, 2.5)
		end
	end
	box(mesh, 0, 3.5, 1.3, 12, 3, 0.15)
	-- A middle leg frame and a rail under the long span.
	for _, y in { 2.1, 4.9 } do
		box(mesh, 0.5, y, FLOOR, 0.4, 0.4, 2.5)
	end
	box(mesh, 0, 2.1, BENCH_TOP - 0.62, 12.4, 0.26, 0.34)
	box(mesh, 0, 4.9, BENCH_TOP - 0.62, 12.4, 0.26, 0.34)
end, nil, 0)

part("RobotArm", nil, YELLOW, function(mesh)
	local x, y = -4.5, 3.5
	cylinder(mesh, x, y, BENCH_TOP + 0.2, 1.1, 0.4, "z", 16)
	-- A shoulder clevis with a visible pivot pin.
	for _, side in { -0.32, 0.32 } do
		box(mesh, x, y + side, BENCH_TOP + 0.4, 0.8, 0.16, 0.95)
	end
	cylinder(mesh, x, y, BENCH_TOP + 0.95, 0.2, 0.9, "y", 10)
	strut(mesh, x, y, BENCH_TOP + 0.95, x + 0.3, y + 0.6, 6, 0.4)
	strut(mesh, x + 0.3, y + 0.6, 6, x + 1.5, y - 1, 6.9, 0.38)
	strut(mesh, x + 1.5, y - 1, 6.9, x + 1.5, y - 1, 5.6, 0.3)
	sphere(mesh, x + 0.3, y + 0.6, 6, 0.42, 0.42, 0.42, 6, 10)
end, nil, 0.1)

part("TorchAndWork", nil, IRON, function(mesh)
	-- The torch held at the arm's tip, aimed down at a cog on the bench.
	local x, y = -3, 2.5
	box(mesh, x, y, 5.45, 0.3, 0.36, 0.2)
	cylinder(mesh, x, y, 5, 0.2, 1, "z", 10)
	cylinder(mesh, x, y, 4.42, 0.13, 0.2, "z", 8)
	strut(mesh, x, y, 4.35, x + 0.05, y, 3.78, 0.1)
	tube(mesh, roundedPath({ { x + 0.2, y + 0.1, 5.3 }, { x - 0.7, y + 1.6, 5.6 }, { x - 1.5, y + 1.3, BENCH_TOP + 0.5 } }, 0.5, 4), 0.07, 6)
	gear(mesh, x, y, BENCH_TOP + 0.14, 0.95, 0.28, 10, "z")
	-- A vice clamped at the far end of the bench.
	box(mesh, 3.6, 2.6, BENCH_TOP, 1.5, 0.9, 0.5)
	box(mesh, 3.6, 2.15, BENCH_TOP + 0.5, 1.5, 0.3, 0.6)
	box(mesh, 3.6, 3, BENCH_TOP + 0.5, 1.5, 0.3, 0.6)
	cylinder(mesh, 3.6, 1.55, BENCH_TOP + 0.75, 0.13, 1.1, "y", 8)
	cylinder(mesh, 3.6, 1.05, BENCH_TOP + 0.75, 0.08, 1.2, "x", 6)
end, nil, 0.1)

part("PartsBins", nil, RUSTED, function(mesh)
	for row = 0, 1 do
		local z = 3 + row * 1.5
		for column = 0, 2 do
			local x = 3.9 + column * 1.5
			box(mesh, x, 6.45, z, 1.24, 1.2, 0.1)
			box(mesh, x, 7.08, z, 1.3, 0.14, 1.2)
			box(mesh, x, 5.9, z + 0.02, 1.3, 0.1, 0.53)
			for _, side in { -1, 1 } do
				box(mesh, x + side * 0.64, 6.5, z, 0.08, 1.3, 1.2)
			end
		end
	end
	box(mesh, 5.4, 7.2, 2.9, 4.7, 0.16, 3)
end, nil, 0.1)

-- How heaped each bin is, so some are full and some nearly empty.
local BIN_FILL = { 12, 0, 5, 1, 18, 3 }
part("BinParts", nil, TOOL, function(mesh)
	for row = 0, 1 do
		for column = 0, 2 do
			local x = 3.9 + column * 1.5
			local z = 3.1 + row * 1.5
			for n = 1, BIN_FILL[row * 3 + column + 1] do
				local a, b = (n * 37 % 10) / 10 - 0.5, (n * 53 % 10) / 10 - 0.5
				local high = 0.21 + (n * 3 % 4) * 0.131 + n * 0.0173
				if n % 2 == 0 then
					cylinder(mesh, x + a * 0.9, 6.45 + b * 0.8, z + high / 2, 0.15 + n % 3 * 0.05, high, "z", 8)
				else
					if n % 3 == 0 then
						strut(mesh, x + a * 0.9, 6.3 + b * 0.5, z + 0.05, x - a * 0.5, 6.7 - b * 0.5, z + 0.4 + high, 0.09)
					else
						box(mesh, x + a * 0.9 + n * 0.0071, 6.45 + b * 0.8 - n * 0.0043, z + n * 0.0037, 0.34 + n % 3 * 0.1, 0.3, high)
					end
				end
			end
		end
	end
end, nil, 0)

part("HangingSign", nil, BRASS, function(mesh)
	-- Its lowest tooth is 6.55 up, clear of a 5.5-tall player's head.
	gear(mesh, 0, -6, 7.4, 0.85, 0.3, 8, "y")
	-- Two arms off the front beam, and the eye the cog hangs from.
	for _, x in { -0.5, 0.5 } do
		box(mesh, x, -5.65, 8.08, 0.18, 1, 0.2)
		box(mesh, x, -6, 8.08, 0.18, 0.14, 0.2)
	end
	box(mesh, 0, -6, 8.08, 1.2, 0.14, 0.18)
	box(mesh, 0, -6, 8.08, 0.2, 0.14, 0.25)
end, nil, 0.1)

part("SignEmblem", nil, IRON, function(mesh)
	strut(mesh, -0.36, -6.2, 7, 0.36, -6.2, 7.75, 0.13)
	strut(mesh, 0.36, -6.2, 7, -0.36, -6.2, 7.75, 0.13)
	ring(mesh, 0.42, -6.2, 7.82, 0.06, 0.17, 0.14, "y", 12)
	box(mesh, -0.42, -6.2, 7.75, 0.36, 0.16, 0.19)
end, nil, 0)

part("Anvil", nil, IRON, function(mesh)
	box(mesh, ANVIL_X, ANVIL_Y, FLOOR, 1.5, 1.5, 0.14)
	cylinder(mesh, ANVIL_X, ANVIL_Y, FLOOR + 0.94, 0.56, 1.6, "z", 14)
	-- A flared foot, a waist, and a deep body with its horn.
	box(mesh, ANVIL_X, ANVIL_Y, FLOOR + 1.74, 1.2, 0.86, 0.22)
	box(mesh, ANVIL_X, ANVIL_Y, FLOOR + 1.96, 0.5, 0.44, 0.26)
	box(mesh, ANVIL_X - 0.2, ANVIL_Y, FLOOR + 2.22, 1.5, 0.56, 0.75)
	strut(mesh, ANVIL_X + 0.55, ANVIL_Y, FLOOR + 2.75, ANVIL_X + 1.25, ANVIL_Y, FLOOR + 2.86, 0.24)
end, nil, 0.1)

-- The lived-in layer: wall services, a chain hoist, a work lamp, a tool chest,
-- gas bottles and things left out on the bench.
part("Fittings", nil, { 0.3, 0.32, 0.36 }, function(mesh)
	-- A pipe along the wall into a gauge, and a junction box.
	cylinder(mesh, 0, 7.08, 7.15, 0.1, 15, "x", 8)
	for x = -6, 6, 4 do
		box(mesh, x, 7.18, 7.05, 0.2, 0.2, 0.22)
	end
	cylinder(mesh, 1.4, 7.08, 6.75, 0.08, 0.8, "z", 6)
	cylinder(mesh, 1.4, 6.98, 6.2, 0.36, 0.14, "y", 14)
	box(mesh, 3, 7.14, 6.15, 1, 0.24, 1)
	-- A chain hoist from the roof, its hook well above head height.
	cylinder(mesh, 3.4, 0, 7.55, 0.05, 0.9, "z", 5)
	box(mesh, 3.4, 0, 7.05, 0.8, 0.5, 0.55)
	cylinder(mesh, 3.4, 0, 6.85, 0.05, 0.4, "z", 5)
	tube(mesh, roundedPath({ { 3.4, 0, 6.72 }, { 3.4, 0, 6.54 }, { 3.7, 0, 6.54 }, { 3.7, 0, 6.76 } }, 0.1, 3), 0.05, 6)
	-- Things left out on the bench.
	cylinder(mesh, 5.3, 3, BENCH_TOP + 0.3, 0.26, 0.6, "z", 10)
	cylinder(mesh, 5.3, 3, BENCH_TOP + 0.7, 0.07, 0.3, "z", 6)
	box(mesh, 0.8, 4.2, BENCH_TOP, 1.6, 0.34, 0.1)
	box(mesh, 0.2, 3.1, BENCH_TOP, 1.1, 0.16, 0.08)
	box(mesh, -0.3, 3.1, BENCH_TOP, 0.4, 0.42, 0.14)
	box(mesh, -0.7, 4.6, BENCH_TOP, 0.9, 0.6, 0.36)
	-- The back of the wall: a brace, a patch, conduit and stored lengths.
	strut(mesh, -7, 8.02, FLOOR, -2, 8.02, 7.3, 0.2)
	strut(mesh, 7, 8.02, FLOOR, 2, 8.02, 7.3, 0.2)
	-- Framing rails, and patches with their edges and fixings.
	for _, z in { 2.6, 5.4 } do
		box(mesh, 0, 8, z, 15.6, 0.3, 0.3)
	end
	box(mesh, 3.6, 8.02, 1.6, 3, 0.2, 2.2)
	box(mesh, -3.2, 8.02, 4.4, 2, 0.2, 1.5)
	for k = 0, 3 do
		bolt(mesh, 2.3 + k * 0.87, 8.13, 1.75, "y", 0.08)
		bolt(mesh, 2.3 + k * 0.87, 8.13, 3.65, "y", 0.08)
		bolt(mesh, -4.05 + k * 0.57, 8.13, 4.55, "y", 0.08)
		bolt(mesh, -4.05 + k * 0.57, 8.13, 5.75, "y", 0.08)
	end
	cylinder(mesh, 0, 8.14, 6.2, 0.08, 13, "x", 6)
	box(mesh, 5.8, 8.14, 5.5, 0.9, 0.3, 1.1)
	for _, x in { -5.6, -5.1, -4.7 } do
		strut(mesh, x, 8.75, FLOOR, x + 0.5, 8.2, FLOOR + 3.4, 0.17)
	end
	-- A stool.
	cylinder(mesh, -2.2, -1, FLOOR + 1.85, 0.55, 0.14, "z", 12)
	for _, a in { 0.5, 2.6, 4.7 } do
		strut(mesh, -2.2 + math.cos(a) * 0.3, -1 + math.sin(a) * 0.3, FLOOR + 1.8, -2.2 + math.cos(a) * 0.62, -1 + math.sin(a) * 0.62, FLOOR, 0.12)
	end
	-- Scrap corner.
	strut(mesh, -8.3, 2.1, FLOOR, -7.5, 1.5, FLOOR + 2, 0.22)
	strut(mesh, -7.9, 1.2, FLOOR, -8.2, 1.9, FLOOR + 1.4, 0.16)
end, nil, 0.1)

part("Blueprint", nil, { 0.2, 0.36, 0.6 }, function(mesh)
	box(mesh, 1.4, 7.16, 3.9, 1.5, 0.08, 1.7)
end, nil, function(_x, _y, z)
	if z % 0.34 < 0.04 then
		return 0.74, 0.8, 0.9
	end
	return 0.2, 0.36, 0.6
end)

part("Supplies", nil, { 0.5, 0.45, 0.3 }, function(mesh)
	toolChest(mesh, 7.2, -1.4, FLOOR)
	gasBottle(mesh, 7.3, 2.5, FLOOR)
	gasBottle(mesh, 7.4, 3.3, FLOOR)
	barrel(mesh, -7.5, 4.3, FLOOR)
	box(mesh, -7.2, 6, FLOOR, 1.7, 1.5, 1.3)
	-- Stock on the bench's lower shelf, and offcuts where the anvil's been used.
	box(mesh, -4.6, 3.5, 1.42, 1.8, 1.6, 0.8)
	box(mesh, -4.7, 3.5, 2.22, 1.3, 1.1, 0.42)
	box(mesh, -2.9, 3.7, 1.42, 1, 1.2, 0.5)
	cylinder(mesh, 2.2, 3.5, 1.82, 0.42, 0.8, "z", 10)
	cylinder(mesh, 3.2, 3.2, 1.72, 0.3, 0.6, "z", 10)
	strut(mesh, 2.4, -3.4, FLOOR + 0.02, 3.3, -2.5, FLOOR + 0.1, 0.16)
	strut(mesh, 2.1, -4.6, FLOOR + 0.02, 3, -4.4, FLOOR + 0.08, 0.13)
	box(mesh, -3.2, -5, FLOOR, 1.6, 1.1, 0.18)
	strut(mesh, -6.5, -2.6, FLOOR, -4.9, -3.5, FLOOR + 0.2, 0.2)
end, nil, supplyTones)

part("Cables", nil, { 0.08, 0.08, 0.1 }, function(mesh)
	-- Power to the junction box, and the torch hose from the bottles.
	tube(mesh, roundedPath({ { 3, 7.1, 6.15 }, { 3, 7, 3 }, { 4.5, 5.6, FLOOR + 0.05 }, { 6.8, 5, FLOOR + 0.05 } }, 0.6, 3), 0.05, 6)
	tube(mesh, roundedPath({ { 7.3, 2.5, FLOOR + 3 }, { 6.8, 2, FLOOR + 3.1 }, { 6.6, 1.7, BENCH_TOP + 0.05 }, { 1, 1.75, BENCH_TOP + 0.05 }, { -3, 2.4, BENCH_TOP + 0.05 }, { -3.1, 2.5, 5.3 } }, 0.5, 3), 0.05, 6)
	-- A chain round the bottles to the bench leg.
	tube(mesh, { { 7.7, 2.2, 2.2 }, { 7.72, 3.6, 2.2 }, { 6.2, 3.8, 2.2 } }, 0.04, 5)
	cylinder(mesh, -1, 1.5, 7.6, 0.03, 0.8, "z", 5)
end, nil, 0)

part("LampShade", nil, { 0.72, 0.56, 0.2 }, function(mesh)
	cylinder(mesh, -1, 1.5, 7.0, 0.42, 0.3, "z", 12)
	cylinder(mesh, -1, 1.5, 7.22, 0.2, 0.16, "z", 10)
end, nil, 0.1)

part("Bulbs", nil, { 1, 0.86, 0.5 }, function(mesh)
	sphere(mesh, -1, 1.5, 6.84, 0.15, 0.15, 0.15, 4, 8)
	-- The torch's working flame on the cog.
	sphere(mesh, -2.95, 2.5, BENCH_TOP + 0.42, 0.13, 0.13, 0.2, 4, 8)
end, true, 0, nil, 1)

handFinish({
	Fittings = "metal",
	Supplies = "metal",
	LampShade = "metal",
	BackWall = "metal",
	ToolRack = "wood",
	RackTools = "metal",
	Roof = "metal",
	RoofPosts = "metal",
	Workbench = "wood",
	RobotArm = "metal",
	TorchAndWork = "metal",
	PartsBins = "metal",
	BinParts = "metal",
	HangingSign = "metal",
	SignEmblem = "metal",
	Anvil = "metal",
}, { Cables = true, Bulbs = true, Blueprint = true, Rafters = true, ToolGrips = true })

finishParts()
