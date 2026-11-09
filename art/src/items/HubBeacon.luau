-- Hub Beacon: the town's landmark, crushed scrap bales under a giant worn cog
-- and a lamp (art/concepts/town-pieces-sketch.png, plan in HubBeacon.plan.luau).
-- include: HandFinish
-- include: TownClutter
-- include: WarpedMesh
useTexelDensity(20)

local CONCRETE = { 0.56, 0.54, 0.5 }
local GIRDER = { 0.22, 0.24, 0.28 }
local BRASS = { 0.72, 0.56, 0.24 }
local BOSS = { 0.4, 0.42, 0.45 }
local LAMP = { 1, 0.86, 0.45 }
local PIPE = { 0.44, 0.5, 0.56 }
local CABLE = { 0.1, 0.1, 0.12 }
local STRAP = { 0.2, 0.2, 0.22 }
-- The metals a bale was crushed from.
local BALE_TONES = { { 0.45, 0.28, 0.16 }, { 0.34, 0.42, 0.5 }, { 0.5, 0.48, 0.44 }, { 0.26, 0.28, 0.3 }, { 0.55, 0.42, 0.2 }, { 0.3, 0.38, 0.34 } }

local PLINTH_TOP = 2
local LAYER_HEIGHT = 3.25
local BALES_TOP = PLINTH_TOP + 4 * LAYER_HEIGHT
local MAST_TOP = 33.5
local COG_Z, COG_Y = 26.5, -3

-- Which bale a point lies in, numbered so neighbouring layers never match.
local function baleIndex(x: number, y: number, z: number): number
	local layer = math.floor((z - PLINTH_TOP) / LAYER_HEIGHT)
	local across = math.floor((x + 6) / 4)
	local deep = math.floor((y + 6) / 6)
	return (layer * 11 + across * 5 + deep * 3 + (layer * across) % 4) * 7 + layer
end

-- The press's dents, shared by a layer's bales and the straps round them.
local function pressed(built, layer: number, angle: number)
	local c, s = math.cos(angle), math.sin(angle)
	return warped(built, function(x, y, h)
		local dent = 0.34
		local a = x + dent * math.noise(y * 1.4, h * 1.7, layer)
		local b = y + dent * math.noise(x * 1.4, h * 1.7, layer + 5)
		local up = h + 0.1 * math.noise(x * 1.3, y * 1.3, layer + 9)
		local shiftX, shiftY = (layer % 2 - 0.5) * 0.5, ((layer + 1) % 3 - 1) * 0.25
		return a * c - b * s + shiftX, a * s + b * c + shiftY, up
	end)
end
local BALE_ANGLES = { 0.09, -0.12, 0.14, -0.08 }
local BALE_X, BALE_Y, BALE_WIDE, BALE_DEEP = 3.5, 2.4, 3.34, 4.7

part("Plinth", nil, CONCRETE, function(mesh)
	box(mesh, 0, 0, 0, 16, 16, 1)
	box(mesh, 0, 0, 1, 13, 13, 1)
end, nil, 0.1)

part("CrushedBlocks", nil, BALE_TONES[1], function(built)
	-- Six bales to a layer, about 1.4 times as long as they are tall.
	for layer, angle in BALE_ANGLES do
		local z = PLINTH_TOP + (layer - 1) * LAYER_HEIGHT
		local mesh = pressed(built, layer, angle)
		for across = -1, 1 do
			for _, deep in { -1, 1 } do
				box(mesh, across * BALE_X, deep * BALE_Y, z, BALE_WIDE, BALE_DEEP, LAYER_HEIGHT - 0.06)
			end
		end
		-- Torn sheet ends poking out of the bales.
		local torn = (layer * 3) % 5 - 2
		box(mesh, torn, -4.85, z + 1.2, 1.8, 0.6, 0.16)
		box(mesh, 5.2, torn * 0.8, z + 2.1, 0.5, 1.5, 0.14)
	end
end, nil, rusting(0.05, function(x, y, z)
	-- Dark packed core; the colour comes from the sheets crushed over it.
	local grain = 0.8 + 0.3 * math.noise(x * 1.6, y * 1.6, z * 1.6)
	return 0.3 * grain, 0.25 * grain, 0.2 * grain
end))

-- The bales' faces: layers of crushed sheet with sharp edges, each its own old
-- paint, in runs of uneven length that stop and overlap.
local SHEET_STEP = 0.3
part("SheetLayers", nil, BALE_TONES[1], function(built)
	for layer, angle in BALE_ANGLES do
		local z0 = PLINTH_TOP + (layer - 1) * LAYER_HEIGHT
		local mesh = pressed(built, layer, angle)
		for row = 0, 9 do
			local z = z0 + 0.1 + row * SHEET_STEP
			for face = 1, 4 do
				local along = -5.3 + ((row * 7 + face * 3 + layer) % 5) * 0.3
				local n = 0
				while along < 5 do
					n += 1
					local long = math.min(0.9 + ((row * 3 + n * 7 + face + layer * 5) % 7) * 0.45, 5.3 + ((row + face) % 3) * 0.12 - along)
					local stand = 0.05 + ((row + n * 3 + face) % 3) * 0.05
					local thick = 0.22 + ((row * 5 + n) % 3) * 0.035
					local middle = along + long / 2
					if face == 1 then
						box(mesh, middle, -4.75 - stand, z, long, 0.14, thick)
					elseif face == 2 then
						box(mesh, middle, 4.75 + stand, z, long, 0.14, thick)
					elseif face == 3 then
						box(mesh, 5.17 + stand, middle * 0.92, z, 0.14, long, thick)
					else
						box(mesh, -5.17 - stand, middle * 0.92, z, 0.14, long, thick)
					end
					along += long + ((row + n) % 7 == 0 and 0.2 or 0.02)
				end
			end
		end
	end
end, nil, function(x, y, z)
	-- One colour to a sheet, picked by its row and a coarse run along it.
	local row = math.floor((z - PLINTH_TOP) / SHEET_STEP)
	local run = math.floor((x + y) * 0.62)
	local tone = BALE_TONES[(row * 5 + run * 3 + (row * run) % 4) % #BALE_TONES + 1]
	local grain = 0.82 + 0.3 * math.noise(x * 2.4, y * 2.4, z * 2.4)
	return tone[1] * grain, tone[2] * grain, tone[3] * grain
end)

part("BaleStraps", nil, STRAP, function(built)
	-- Two bands round each bale, in the same dents, each closed with a clip.
	for layer, angle in BALE_ANGLES do
		local z = PLINTH_TOP + (layer - 1) * LAYER_HEIGHT
		local mesh = pressed(built, layer, angle)
		for across = -1, 1 do
			for _, deep in { -1, 1 } do
				local x, y = across * BALE_X, deep * BALE_Y
				for _, h in { 1.45 } do
					box(mesh, x, y - BALE_DEEP / 2 - 0.02, z + h, BALE_WIDE + 0.08, 0.1, 0.16)
					box(mesh, x, y + BALE_DEEP / 2 + 0.02, z + h, BALE_WIDE + 0.08, 0.1, 0.16)
					box(mesh, x - BALE_WIDE / 2 - 0.02, y, z + h, 0.1, BALE_DEEP + 0.08, 0.16)
					box(mesh, x + BALE_WIDE / 2 + 0.02, y, z + h, 0.1, BALE_DEEP + 0.08, 0.16)
				end
				box(mesh, x + 0.4, y - BALE_DEEP / 2 - 0.08, z + 1.42, 0.42, 0.14, 0.24)
			end
		end
	end
end, nil, 0)

-- Things you can still recognise, crushed into the bales' faces.
part("PressedJunk", nil, { 0.5, 0.45, 0.4 }, function(built)
	for layer, angle in BALE_ANGLES do
		local z = PLINTH_TOP + (layer - 1) * LAYER_HEIGHT
		local mesh = pressed(built, layer, angle)
		-- A few dense pockets of recognisable wreckage, gaps elsewhere.
		if layer == 1 or layer == 3 then
			for n = 0, 3 do
				strut(mesh, -4.2 + n * 0.7, -4.9, z + 0.4 + n * 0.4, -2.6 + n * 0.5, -4.9, z + 2.4 - n * 0.3, 0.22 + n % 2 * 0.1)
			end
			ring(mesh, -3.2, -4.92, z + 1.4, 0.5, 1, 0.3, "y", 16)
			strut(mesh, 5.3, 2.8, z + 0.5, 5.3, 1.1, z + 2.6, 0.3)
			strut(mesh, 5.3, 3.4, z + 2.5, 5.3, 0.9, z + 0.7, 0.22)
		else
			for n = 0, 2 do
				strut(mesh, 2 + n * 0.8, -4.9, z + 2.6 - n * 0.5, 3.4 + n * 0.4, -4.9, z + 0.5 + n * 0.3, 0.26)
			end
			strut(mesh, -3.4, 4.95, z + 0.6, -1.6, 4.95, z + 2.5, 0.3)
			strut(mesh, -2.2, 4.95, z + 0.5, -3.1, 4.95, z + 2.6, 0.2)
			strut(mesh, -5.3, -2, z + 2.4, -5.3, -0.2, z + 0.7, 0.28)
		end
	end
end, nil, function(x, y, z)
	-- Muted, dirty metals, so nothing pops out like a new toy.
	local grain = 0.5 + 0.25 * math.noise(x * 2, y * 2, z * 2)
	local tone = BALE_TONES[(math.floor(x + y) + math.floor(z)) % #BALE_TONES + 1]
	return tone[1] * grain + 0.1, tone[2] * grain + 0.09, tone[3] * grain + 0.08
end)

part("Mast", nil, GIRDER, function(mesh)
	box(mesh, 0, 0, BALES_TOP, 4.2, 4.2, 0.3)
	local z0 = BALES_TOP + 0.3
	for _, x in { -1.3, 1.3 } do
		for _, y in { -1.3, 1.3 } do
			box(mesh, x, y, z0, 0.4, 0.4, MAST_TOP - z0)
		end
	end
	for z = z0, MAST_TOP - 3, 3 do
		strut(mesh, -1.3, -1.3, z, 1.3, -1.3, z + 3, 0.2)
		strut(mesh, 1.3, 1.3, z, -1.3, 1.3, z + 3, 0.2)
		strut(mesh, -1.3, 1.3, z, -1.3, -1.3, z + 3, 0.2)
		strut(mesh, 1.3, -1.3, z, 1.3, 1.3, z + 3, 0.2)
	end
	-- The shaft runs back through the mast into a second bearing beam.
	box(mesh, 0, 1.3, COG_Z - 0.6, 3.6, 0.5, 1.2)
	box(mesh, 0, -1.3, COG_Z - 0.75, 4.2, 0.5, 1.5)
	cylinder(mesh, 0, 0.3, COG_Z, 0.46, 3.4, "y", 14)
	cylinder(mesh, 0, 2.05, COG_Z, 0.72, 0.2, "y", 14)
	-- The crossmember that carries the cog's axle.
	box(mesh, 0, -1.3, COG_Z - 0.55, 3.2, 0.5, 1.1)
	for _, side in { -1, 1 } do
		strut(mesh, side * 1.2, -1.3, COG_Z - 0.5, side * 1.3, 1.3, COG_Z - 3.2, 0.22)
	end
	box(mesh, 0, 0, MAST_TOP - 0.4, 3, 3, 0.4)
	for _, x in { -1.25, 1.25 } do
		for _, y in { -1.25, 1.25 } do
			box(mesh, x, y, MAST_TOP, 0.16, 0.16, 3)
		end
	end
	box(mesh, 0, 0, MAST_TOP + 2.85, 3, 3, 0.15)
	-- Guard bars round the lamp.
	for _, z in { MAST_TOP + 0.9, MAST_TOP + 1.9 } do
		ring(mesh, 0, 0, z, 1.42, 1.54, 0.12, "z", 16)
	end
end, nil, 0)

-- Turns what is built round the cog's axle, for its teeth.
local function aroundCog(built, angle: number)
	local c, s = math.cos(angle), math.sin(angle)
	return warped(built, function(x, y, z)
		local dz = z - COG_Z
		return x * c - dz * s, y, COG_Z + x * s + dz * c
	end)
end

part("BigCog", nil, BRASS, function(mesh)
	-- Open-work: a stepped rim and a hub joined by spokes, with real gaps.
	ring(mesh, 0, COG_Y, COG_Z, 4.3, 5.05, 1.1, "y", 40)
	ring(mesh, 0, COG_Y, COG_Z, 4.05, 4.5, 1.5, "y", 40)
	ring(mesh, 0, COG_Y, COG_Z, 1.1, 2.1, 1.4, "y", 24)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + 0.26
		strut(mesh, math.cos(a) * 1.9, COG_Y, COG_Z + math.sin(a) * 1.9, math.cos(a) * 4.2, COG_Y, COG_Z + math.sin(a) * 4.2, 0.8)
	end
	-- Teeth, a few of them chipped short.
	for k = 0, 13 do
		local tooth = aroundCog(mesh, k / 14 * math.pi * 2)
		local high = if k % 5 == 2 then 0.75 else 1.3
		local tapered = warped(tooth, function(x, y, z)
			local out = math.clamp((z - COG_Z - 4.85) / 1.3, 0, 1)
			return x * (1 - 0.42 * out), y, z
		end)
		box(tapered, 0, COG_Y, COG_Z + 4.85, 1.35, 1.1, high)
	end
end, nil, function(x, _y, z)
	-- Polished bare metal on the worn tooth tips, darker bronze inside the rim.
	local r = math.sqrt(x * x + (z - COG_Z) ^ 2)
	local wear = math.noise(x * 1.3, z * 1.3, 5)
	if r > 5.25 and wear > -0.2 then
		return 0.9, 0.78, 0.46
	end
	if r < 4.05 then
		return 0.5, 0.38, 0.17
	end
	if wear > 0.35 then
		return 0.34, 0.25, 0.12
	end
	return BRASS[1], BRASS[2], BRASS[3]
end)

part("CogBoss", nil, BOSS, function(mesh)
	cylinder(mesh, 0, COG_Y - 0.95, COG_Z, 1.5, 0.7, "y", 18)
	-- The axle, through the hub and back to the bearing block on the mast.
	cylinder(mesh, 0, COG_Y + 0.4, COG_Z, 1.14, 2.1, "y", 16)
	-- A bearing block on the crossmember takes the axle.
	box(mesh, 0, -1.72, COG_Z - 0.85, 1.9, 0.45, 1.7)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + 0.26
		bolt(mesh, math.cos(a) * 1.05, COG_Y - 1.33, COG_Z + math.sin(a) * 1.05, "y", 0.2)
	end
end, nil, 0.1)

part("BeaconLamp", nil, LAMP, function(mesh)
	cylinder(mesh, 0, 0, MAST_TOP + 1.25, 1.05, 2.6, "z", 12)
end, true, 0, nil, 0.7)

part("Pipes", nil, PIPE, function(mesh)
	local x = -4
	tube(mesh, roundedPath({ { x, -5.4, PLINTH_TOP + 0.1 }, { x, -6.1, PLINTH_TOP + 1.5 }, { x, -6.1, 12.5 }, { x, -4.8, 13.6 } }, 0.45, 6), 0.42, 12)
	cylinder(mesh, x, -5.4, PLINTH_TOP + 0.1, 0.72, 0.22, "z", 12)
	cylinder(mesh, x, -4.9, 13.62, 0.68, 0.22, "y", 12)
end, nil, 0.1)

part("Cable", nil, CABLE, function(mesh)
	local x = 4
	tube(mesh, roundedPath({ { x, -5.3, PLINTH_TOP + 0.05 }, { x + 0.1, -5.05, 5 }, { x - 0.1, -5.05, 9 }, { x + 0.2, -4.9, 14.3 }, { x - 0.5, -2.6, 15.25 }, { 1.7, -1.6, 15.7 } }, 1, 5), 0.17, 8)
	-- Clipped to the bales at uneven heights.
	for _, z in { 3.7, 6.9, 8, 11.6 } do
		box(mesh, x, -5, z, 0.75, 0.62, 0.2)
	end
	box(mesh, x, -5.3, PLINTH_TOP, 0.8, 0.8, 0.2)
	box(mesh, x + 0.2, -4.95, 14.05, 0.7, 0.5, 0.55)
end, nil, 0)

-- The lived-in layer: ladders, a service box and warning lights on the mast,
-- a plaque, bollards and chain round the plinth, and scrap left at its foot.
part("Fittings", nil, { 0.3, 0.32, 0.36 }, function(mesh)
	ladderOnY(mesh, 0, 5.95, PLINTH_TOP, BALES_TOP + 0.3, 1.1)
	ladderOnY(mesh, 0, 1.92, BALES_TOP + 0.3, MAST_TOP - 0.4, 0.42)
	-- Service runs and a patched plate on the back and sides.
	box(mesh, 2.4, 4.9, 9, 0.5, 0.5, 0.3)
	cylinder(mesh, 3.6, 5.75, 8.5, 0.24, 12.6, "z", 8)
	for _, z in { 4, 8, 12 } do
		box(mesh, 3.6, 5.25, z, 0.7, 1.2, 0.2)
	end
	-- A big access panel with a locking wheel, bolted to the bales' back.
	box(mesh, -3.2, 5.05, 5.4, 3.6, 0.9, 4.2)
	box(mesh, -3.2, 5.55, 5.8, 3, 0.14, 3.4)
	ring(mesh, -3.2, 5.68, 7.5, 0.3, 0.7, 0.14, "y", 14)
	for _, x in { -4.8, -1.6 } do
		for _, z in { 5.7, 9.3 } do
			bolt(mesh, x, 5.53, z, "y", 0.12)
		end
	end
	box(mesh, -3, 5.1, 11.4, 2.6, 0.9, 2)
	box(mesh, 5.2, 3, 8.8, 0.24, 2.4, 2.2)
	box(mesh, -5.2, -2.2, 9.6, 0.24, 2.2, 2)
	box(mesh, 5.35, -1.2, 12, 0.5, 1.3, 1.6)
	-- Gussets at the mast's feet.
	for _, x in { -1.3, 1.3 } do
		for _, y in { -1.3, 1.3 } do
			strut(mesh, x + math.sign(x) * 0.9, y + math.sign(y) * 0.9, BALES_TOP + 0.3, x, y, BALES_TOP + 2, 0.2)
		end
	end
	-- A service box on the mast and its conduit down the leg.
	box(mesh, -1.72, -1.3, 19, 0.5, 1.2, 1.6)
	cylinder(mesh, -1.62, -1.3, 17.25, 0.08, 1.9, "z", 6)
	-- A plaque on the plinth, bollards round its lower step.
	box(mesh, 0, -6.55, 1.15, 3.4, 0.12, 0.7)
	for _, x in { -7.2, 7.2 } do
		for _, y in { -7.2, 7.2 } do
			cylinder(mesh, x, y, 1.6, 0.28, 1.2, "z", 10)
			cylinder(mesh, x, y, 2.24, 0.34, 0.12, "z", 10)
		end
	end
	-- An aerial on the lamp's cage.
	cylinder(mesh, 1.2, 1.2, MAST_TOP + 4.1, 0.05, 2.5, "z", 5)
	-- Spotlights on the plinth, aimed up at the bales.
	for _, x in { -4.5, 4.5 } do
		box(mesh, x, -6.9, 1, 0.5, 0.5, 0.18)
		strut(mesh, x, -6.9, 1.18, x, -6.75, 1.72, 0.5)
	end
end, nil, 0.1)

part("Supplies", nil, { 0.5, 0.45, 0.3 }, function(mesh)
	-- Scrap heaped in one corner at the foot of the tower.
	-- Worn tracks and a crate round the back of the plinth.
	box(mesh, 2.4, 7.25, 1, 1.5, 1, 0.7)
	box(mesh, 3.4, 7.3, 1, 0.8, 0.8, 1.1)
	barrel(mesh, 7.25, 5.6, 1)
	box(mesh, 7.25, 4.1, 1, 1.2, 1.3, 0.8)
	strut(mesh, 7.7, 3.4, 1, 6.9, 4.8, 2.4, 0.5)
	gear(mesh, 7.25, 3.9, 1.9, 0.6, 0.2, 9, "x")
	strut(mesh, 6.9, 2.6, 1, 7.6, 3.5, 1.5, 0.2)
end, nil, supplyTones)

part("Cables", nil, { 0.08, 0.08, 0.1 }, function(mesh)
	tube(mesh, sagging(-7.2, -7.2, 2, 7.2, -7.2, 2, 0.42, 12), 0.05, 5)
	tube(mesh, sagging(-7.2, 7.2, 2, 7.2, 7.2, 2, 0.42, 12), 0.05, 5)
	tube(mesh, sagging(-7.2, -7.2, 2, -7.2, 7.2, 2, 0.42, 12), 0.05, 5)
	tube(mesh, sagging(7.2, -7.2, 2, 7.2, 7.2, 2, 0.42, 12), 0.05, 5)
	tube(mesh, { { -1.72, -1.3, 19.8 }, { -1.72, -1.3, 32 }, { -1.26, -1.26, 33.3 } }, 0.05, 5)
end, nil, 0)

part("Bulbs", nil, { 1, 0.26, 0.16 }, function(mesh)
	-- Red warning lights up the mast.
	for _, z in { 17.5, 19.5, 32.9 } do
		sphere(mesh, 1.56, -1.56, z, 0.24, 0.24, 0.24, 4, 8)
	end
end, true, 0, nil, 1)

part("Spotlights", nil, { 1, 0.88, 0.6 }, function(mesh)
	for _, x in { -4.5, 4.5 } do
		cylinder(mesh, x, -6.74, 1.99, 0.24, 0.06, "z", 10)
	end
end, true, 0, nil, 0.9)

handFinish({
	Fittings = "metal",
	Supplies = "metal",
	Plinth = "rock",
	BaleStraps = "metal",
	Mast = "metal",
	BigCog = "metal",
	CogBoss = "metal",
	Pipes = "metal",
}, { Cables = true, Bulbs = true, Spotlights = true, BeaconLamp = true, Cable = true, SheetLayers = true })
-- Wear the cog's tooth edges unevenly, so no even outline runs round it.
for _, entry in parts do
	if entry.name == "BigCog" then
		entry.litUneven, entry.litUnevenStep = 0.95, 0.3
	end
end

finishParts()
