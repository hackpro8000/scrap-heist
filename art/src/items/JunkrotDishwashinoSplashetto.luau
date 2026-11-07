-- Dishwashino Splashetto: a slimline dishwasher, bright white with
-- rounded edges, its door dropped open a crack at the top so the plates in
-- the rack show over it, a dark control strip along the top with its row
-- of green lights, a long steel handle across the door and a dark kick
-- plate along its foot. 3.5 studs tall.
-- include: JunkrotKit
local FEET = { 1.0, 0.5 }
local WHITE = { 0.95, 0.96, 0.97 }
local BASE = 0.55
local TALL = 2.75
local HINGE = BASE + 0.25 -- the door's bottom hinge
local DOOR = TALL - 0.6 -- the door's height
local AJAR = 6 -- degrees the door leans open
-- The door's front, which comes further out the higher up it is.
local function doorY(z)
	return -0.74 - (z - HINGE) * math.tan(math.rad(AJAR))
end
local FACE = { { -0.34, doorY(2.3) - 0.07, 2.3, 0.22 }, { 0.34, doorY(2.32) - 0.07, 2.32, 0.22 } }
part("Cabinet", nil, WHITE, function(mesh)
	local m = Kit.block(1.5, 1.3, TALL, 0.1)
	m:translate(0, 0, BASE + TALL / 2)
	m:emit(mesh)
end, 50, 0)
part("Door", nil, WHITE, function(mesh)
	local m = Kit.block(1.42, 0.08, DOOR, 0.04)
	-- Built standing on its hinge, then tipped open.
	m:translate(0, -0.04, DOOR / 2)
	Kit.turn(m, "x", AJAR)
	m:translate(0, -0.66, HINGE)
	m:emit(mesh)
end, 50, 0)
part("Panel", nil, { 0.15, 0.16, 0.18 }, function(mesh)
	local strip = Kit.block(1.44, 0.06, 0.28, 0.03)
	strip:translate(0, -0.67, BASE + TALL - 0.2)
	strip:emit(mesh)
	local kick = Kit.block(1.44, 0.05, 0.22, 0.02)
	kick:translate(0, -0.66, BASE + 0.12)
	kick:emit(mesh)
end, 50, 0)
part("Lights", nil, { 0.35, 0.95, 0.5 }, function(mesh)
	for k = 0, 4 do
		local light = EditMesh.cylinder(0.035, 0.04, 8, 1)
		Kit.turn(light, "x", 90)
		light:translate(0.1 + k * 0.12, -0.71, BASE + TALL - 0.2)
		light:emit(mesh)
	end
end, true, 0, nil, 1.2)
part("Plates", nil, { 0.8, 0.9, 0.95 }, function(mesh)
	-- In the rack behind the door's top edge.
	for k = 0, 3 do
		local plate = Kit.lathe({ { 0, 0 }, { 0.32, 0 }, { 0.34, 0.03 }, { 0, 0.03 } }, 16)
		Kit.turn(plate, "y", 90)
		Kit.turn(plate, "z", 8)
		plate:translate(-0.45 + k * 0.3, -0.5, BASE + DOOR + 0.12)
		plate:emit(mesh)
	end
end, true, 0)
part("Handle", nil, BARE_METAL, function(mesh)
	local z = HINGE + DOOR - 0.25
	local y = doorY(z) - 0.08
	Kit.tube({ { -0.5, y, z }, { 0.5, y, z } }, 0.035, 8):emit(mesh)
	for _, x in { -0.5, 0.5 } do
		Kit.tube({ { x, y + 0.1, z }, { x, y, z } }, 0.03, 6):emit(mesh)
	end
end, true, 0.03)
-- include: JunkrotFace
