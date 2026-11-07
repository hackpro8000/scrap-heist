-- Lawnmowo Ruggito: a push mower in showroom red: a low rounded deck
-- tapering to its top, four fat wheels with hub caps, a black engine with
-- an air filter and the pull cord's yellow handle on top, tall handlebars
-- raked back with a crossbar, and a green grass bag hung behind. 3 studs
-- tall.
-- include: JunkrotKit
local FACE = { { -0.42, -0.95, 0.86, 0.19 }, { 0.42, -0.95, 0.88, 0.19 } }
local FEET = { 1.0, 0.35 }
local SHOW_RED = { 0.88, 0.1, 0.1 }
local DECK = 0.5 -- the deck's underside
local WHEEL = 0.36
part("Deck", nil, SHOW_RED, function(mesh)
	local m = Kit.block(2.2, 1.8, 0.5, 0.2)
	m:taper("z", 1, 0.88)
	m:translate(0, 0, DECK + 0.25)
	m:emit(mesh)
end, 50, 0.03)
part("Wheels", nil, RUBBER_BLACK, function(mesh)
	for _, x in { -0.95, 0.95 } do
		for _, y in { -0.98, 0.98 } do
			local m = Kit.lathe({ { 0, -0.11 }, { 0.3, -0.11 }, { 0.35, -0.07 }, { WHEEL, 0 }, { 0.35, 0.07 }, { 0.3, 0.11 }, { 0, 0.11 } }, 16)
			Kit.turn(m, "x", 90)
			m:translate(x, y, WHEEL)
			m:emit(mesh)
		end
	end
end, true, RUBBER)
part("Engine", nil, { 0.14, 0.14, 0.16 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.45, 0 }, { 0.45, 0.5 }, { 0.38, 0.6 }, { 0, 0.62 } }, 16)
	m:translate(0, 0.1, DECK + 0.48)
	m:emit(mesh)
	local filter = Kit.block(0.35, 0.3, 0.3, 0.08)
	filter:translate(0.5, 0.1, DECK + 0.75)
	filter:emit(mesh)
end, 40, 0.03)
part("Cord", nil, { 0.98, 0.8, 0.15 }, function(mesh)
	local grip = Kit.block(0.35, 0.1, 0.1, 0.04)
	grip:translate(0, 0.1, DECK + 1.2)
	grip:emit(mesh)
	Kit.tube({ { 0, 0.1, DECK + 1.08 }, { 0, 0.1, DECK + 1.15 } }, 0.02, 4):emit(mesh)
end, 50, 0)
part("Bars", nil, BARE_METAL, function(mesh)
	for _, side in { -1, 1 } do
		Kit.tube({ { side * 0.65, 0.82, DECK + 0.4 }, { side * 0.7, 1.6, 2.55 } }, 0.05, 6):emit(mesh)
		local cap = Kit.lathe({ { 0, 0 }, { 0.16, 0 }, { 0.12, 0.06 }, { 0, 0.08 } }, 12)
		Kit.turn(cap, "x", side * 90)
		for _, x in { -0.95, 0.95 } do
			local c = cap:copy()
			c:translate(x, side * 1.09, WHEEL)
			c:emit(mesh)
		end
	end
	Kit.tube({ { -0.7, 1.6, 2.55 }, { 0.7, 1.6, 2.55 } }, 0.05, 6):emit(mesh)
	Kit.tube({ { -0.68, 1.3, 1.85 }, { 0.68, 1.3, 1.85 } }, 0.04, 6):emit(mesh)
end, true, 0.03)
part("Bag", nil, { 0.2, 0.36, 0.22 }, function(mesh)
	local m = Kit.block(1.1, 0.9, 0.8, 0.3)
	m:translate(0, 1.25, DECK + 0.62)
	m:emit(mesh)
end, true, RUBBER)
-- include: JunkrotFace
