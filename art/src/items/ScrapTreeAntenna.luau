-- Scrap Tree (Antenna): a rooftop TV antenna mast planted in a tyre and guyed
-- to the ground, its crossbars clamped on in rough tiers like a battered pine.
-- Each tier: height, how far the bar reaches each way, its turn and droop.
-- Some ends have snapped short; the fallen piece lies against the tyre.
-- include: HandFinish
local TIERS = {
	{ 2.9, 1.9, 1.5, 0.2, 0.2 },
	{ 3.4, 1.2, 2.0, 0.75, 0.12 },
	{ 3.95, 1.8, 0.5, 1.6, 0.16 },
	{ 5.5, 1.6, 1.3, 2.35, 0.1 },
	{ 6.0, 0.45, 1.5, 3.0, 0.2 },
	{ 7.7, 1.2, 1.1, 3.7, 0.12 },
	{ 8.15, 1.05, 0.4, 0.6, 0.1 },
	{ 9.8, 0.8, 0.85, 1.3, 0.05 },
	{ 10.3, 0.3, 0.6, 2.2, 0.05 },
}
local GUY_TURNS = { 0, 2.1, 4.2 }

part("Mast", nil, DARK_STEEL, function(mesh)
	cylinder(mesh, 0, 0, 5.5, 0.14, 11, "z", 8)
	for _, a in GUY_TURNS do
		local x, y = math.cos(a) * 2.1, math.sin(a) * 2.1
		strut(mesh, 0, 0, 6, x, y, 0.06, 0.06)
		-- A stake holding the wire down.
		box(mesh, x, y, 0, 0.36, 0.36, 0.22)
	end
	-- A clamp round the mast at every tier.
	for _, tier in TIERS do
		cylinder(mesh, 0, 0, tier[1], 0.26, 0.3, "z", 8)
	end
end, nil, 0.5)

part("Elements", nil, STEEL, function(mesh)
	for i, tier in TIERS do
		local z, back, forward, turn, droop = tier[1], tier[2], tier[3], tier[4], tier[5]
		local dx, dy = math.cos(turn), math.sin(turn)
		strut(mesh, -dx * back, -dy * back, z - droop * 0.6, dx * forward, dy * forward, z - droop, 0.13)
		-- A shorter bar across every other tier, and a bent-down tip on the low ones.
		if i % 2 == 1 then
			strut(mesh, -dy * forward * 0.6, dx * forward * 0.6, z + 0.12, dy * back * 0.5, -dx * back * 0.5, z + 0.1, 0.09)
		end
		if i <= 2 then
			strut(mesh, dx * forward, dy * forward, z - droop, dx * (forward + 0.3), dy * (forward + 0.3), z - droop - 0.4, 0.09)
		end
	end
	ring(mesh, 0, 0, 11, 0.2, 0.5, 0.08, "z", 10)
	-- A snapped-off bar, fallen against the tyre.
	strut(mesh, 2.1, 1.15, 0.04, 0.98, 0.62, 0.62, 0.13)
end, nil, 0.4)

part("Fill", nil, { 0.5, 0.48, 0.44 }, function(mesh)
	cylinder(mesh, 0, 0, 0.26, 0.64, 0.52, "z", 14)
end, nil, 0.25)

part("Tyre", nil, RUBBER_BLACK, function(mesh)
	ring(mesh, 0, 0, 0.3, 0.6, 1.2, 0.6, "z", 14)
end, nil, RUBBER)

part("Cable", nil, COPPER, function(mesh)
	tube(mesh, { { 0.1, 0.1, 10.5 }, { 0.3, 0.2, 6 }, { 0.6, 0.4, 1 }, { 1.4, 0.8, 0.05 } }, 0.04, 5)
end, nil, 0.2)

handFinish({
	Mast = "metal",
	Elements = "metal",
	Fill = "rock",
	Tyre = "rock",
	Cable = "metal",
}, {}, PROP_FINISH)
finishParts()
