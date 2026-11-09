-- Part plan for HubShop (art/concepts/town-pieces-sketch.png): The town's shop: stacked salvaged containers cut open behind a long counter. 34 by 20, front (-y) faces the landmark.
-- Origin at the middle of the footprint at ground level, z up.
return {
	parts = {
		{ name = "Slab", level = "core", at = { 0, 0, 0.4 }, size = { 34, 20, 0.8 }, note = "cracked concrete pad the shop stands on" },
		{ name = "LowerContainers", level = "major", attaches = "Slab", at = { 0, 4, 4.8 }, size = { 30, 10, 8 }, note = "two welded containers, corrugated, front cut away behind the counter" },
		{ name = "UpperContainer", level = "major", attaches = "LowerContainers", at = { -4, 4, 12.8 }, size = { 20, 10, 8 }, note = "a third container stacked off-centre, rust-orange" },
		{ name = "Counter", level = "major", attaches = "Slab", at = { 0.025, -3.6, 3.1 }, size = { 22, 2.4, 0.6 }, note = "plank top on steel drums, top at 3.4; where players buy" },
		{ name = "CounterDrums", level = "detail", attaches = "Slab", at = { -0.0051, -3.6, 2.9 }, size = { 18, 1.6, 4.2 }, note = "oil drums under the counter; 3 of them" },
		{ name = "Awning", level = "major", attaches = "LowerContainers", at = { -0.0022, -5.6, 8.9 }, size = { 32, 10, 0.67 }, note = "sloped patched corrugated sheet, 8.1 of headroom" },
		{ name = "AwningPosts", level = "detail", attaches = "Slab", at = { 0.01, -5.5, 5.1 }, size = { 31, 9.1, 8.7 }, note = "pipe posts holding the awning's front edge; 4 of them" },
		{ name = "Sign", level = "major", attaches = "UpperContainer", at = { -4, 0.2, 19 }, size = { 18, 0.57, 4.5 }, note = "big hand-painted board on the roof, readable from the yards" },
		{ name = "Crane", level = "major", attaches = "LowerContainers", at = { 12, -1, 15 }, size = { 2, 16, 15 }, note = "little yard crane on the roof, a jib with a dangling hook" },
		{ name = "CraneHook", level = "detail", attaches = "Crane", at = { 12, -0.38, 18 }, size = { 0.69, 13, 9.5 }, note = "cable and hook hanging off the jib" },
		{ name = "StockPiles", level = "detail", attaches = "Slab", at = { 0, -6.6, 1.9 }, size = { 29, 2.9, 2.3 }, note = "crates and scrap stacked either side of the counter" },
		{ name = "Shelves", level = "detail", attaches = "LowerContainers", at = { 0, 7.9, 4.5 }, size = { 27, 1.4, 6 }, note = "added after the first review" },
		{ name = "ShelfStock", level = "detail", attaches = "Shelves", at = { 0, 7.8, 4.5 }, size = { 27, 1.1, 4.9 }, note = "added after the first review" },
		{ name = "AwningPatches", level = "detail", attaches = "Awning", at = { 1, -5.4, 9.1 }, size = { 24, 7.9, 0.53 }, note = "added after the first review" },
		{ name = "SignBraces", level = "detail", attaches = "UpperContainer", at = { -4, 2, 18.5 }, size = { 15, 4.3, 3.5 }, note = "added after the first review" },
		{ name = "CraneWeight", level = "detail", attaches = "Crane", at = { 12, 7, 20.5 }, size = { 1.7, 3.4, 3 }, note = "added after the first review" },
		{ name = "Fittings", level = "detail", attaches = "Slab", at = { 0.34, 3.4, 11 }, size = { 30, 10, 21 }, note = "the lived-in detail layer" },
		{ name = "PriceBoards", level = "detail", attaches = "Slab", at = { 0.044, -1, 8.2 }, size = { 24, 0.47, 1.1 }, note = "the lived-in detail layer" },
		{ name = "Supplies", level = "detail", attaches = "Slab", at = { 0.19, 2, 5.3 }, size = { 34, 12, 9.1 }, note = "the lived-in detail layer" },
		{ name = "Cables", level = "detail", attaches = "Slab", at = { -0.023, -5.1, 4.4 }, size = { 30, 9.1, 7.1 }, note = "the lived-in detail layer" },
		{ name = "Bulbs", level = "detail", attaches = "Slab", at = { 0, -4.9, 14 }, size = { 26, 9.7, 14 }, note = "the lived-in detail layer" },
		{ name = "Stencil", level = "detail", attaches = "UpperContainer", at = { -9.8, -0.94, 14 }, size = { 4.6, 0.33, 1.7 }, note = "added in review" },
	},
	clearance = {
		{ part = "Counter front", width = 28, height = 8 },
	},
}
