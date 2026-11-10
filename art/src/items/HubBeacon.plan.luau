-- Part plan for HubBeacon (art/concepts/town-pieces-sketch.png): The town's landmark: a tower of crushed scrap topped with a giant cog and a lamp, seen from every yard. 16 by 16, 36.5 tall.
-- Origin at the middle of the footprint at ground level, z up.
return {
	parts = {
		{ name = "Plinth", level = "core", at = { 0, 0, 1 }, size = { 16, 16, 2 }, note = "stepped concrete base" },
		{ name = "CrushedBlocks", level = "major", attaches = "Plinth", at = { 0, 0, 8.5 }, size = { 11, 11, 13 }, note = "4 layers of crushed-metal bales, each turned a little" },
		{ name = "Mast", level = "major", attaches = "CrushedBlocks", at = { 0, 0, 18.75 }, size = { 13, 11.4, 33.5 }, note = "riveted girder mast" },
		{ name = "BigCog", level = "major", attaches = "Mast", at = { 0.0044, -3, 26 }, size = { 12, 2, 12 }, note = "giant worn cog, may turn slowly" },
		{ name = "BeaconLamp", level = "major", attaches = "Mast", at = { 0, 0, 34.75 }, size = { 2.1, 2, 2.6 }, note = "caged glowing lamp on top" },
		{ name = "Pipes", level = "detail", attaches = "CrushedBlocks", at = { -4, -5.6, 8.1 }, size = { 1.4, 1.8, 12 }, note = "bent pipes and cable up the side; 2 of them" },
		{ name = "BaleStraps", level = "detail", attaches = "CrushedBlocks", at = { 0, 0, 8.5 }, size = { 10.6, 10.6, 12 }, note = "added after the first review" },
		{ name = "CogBoss", level = "major", attaches = "BigCog", at = { 0, -2.8, 26.5 }, size = { 3, 3, 3 }, note = "added after the first review" },
		{ name = "Cable", level = "detail", attaches = "CrushedBlocks", at = { 3.1, -3.6, 8.9 }, size = { 2.9, 4.2, 14 }, note = "added after the first review" },
		{ name = "Fittings", level = "detail", attaches = "Plinth", at = { 0.0009, 0.0088, 20 }, size = { 15, 15, 38 }, note = "the lived-in detail layer" },
		{ name = "Supplies", level = "detail", attaches = "Plinth", at = { 4.8, 5.2, 1.9 }, size = { 6.3, 5.2, 2.1 }, note = "the lived-in detail layer" },
		{ name = "Cables", level = "detail", attaches = "Plinth", at = { -0.0048, 0.0048, 17 }, size = { 14, 14, 32 }, note = "the lived-in detail layer" },
		{ name = "Bulbs", level = "detail", attaches = "Plinth", at = { 1.6, -1.6, 24 }, size = { 0.48, 0.48, 16 }, note = "the lived-in detail layer" },
		{ name = "Spotlights", level = "detail", attaches = "Plinth", at = { 0, -6.7, 2 }, size = { 9.5, 0.46, 0.06 }, note = "the lived-in detail layer" },
		{ name = "PressedJunk", level = "detail", attaches = "CrushedBlocks", at = { 0.066, -0.073, 8.6 }, size = { 11, 11, 13 }, note = "the lived-in detail layer" },
		{ name = "SheetLayers", level = "major", attaches = "CrushedBlocks", at = { 0, 0, 8.5 }, size = { 14, 13, 13 }, note = "crushed sheet edges on the bale faces" },
	},
}
