-- Part plan for BeltCrossing (art/concepts/town-pieces-sketch.png): A footbridge over the capsule belt, its stairs on both sides. 21 long, 8 wide. Local x runs across the belt.
-- Origin at the middle of the footprint at ground level, z up.
return {
	parts = {
		{ name = "Span", level = "core", at = { 0, 0, 5 }, size = { 7.1, 8, 0.79 }, note = "plate deck, underside at 4.75, belt capsules top out at 4.0" },
		{ name = "Stairs", level = "major", attaches = "Span", at = { 0, 0, 2.6 }, size = { 21, 8.1, 5.4 }, note = "steel stairs, 2 flights, rise 5.25 over 7" },
		{ name = "Railings", level = "detail", attaches = "Span", at = { 0, 0, 4.2 }, size = { 21, 7.8, 8.4 }, note = "pipe rails following the stairs; 2 of them" },
		{ name = "Legs", level = "detail", attaches = "Span", at = { 0, 0, 2.4 }, size = { 8.1, 7.7, 4.9 }, note = "legs clear of the belt; 4 of them" },
		{ name = "Fittings", level = "detail", attaches = "Span", at = { 0.045, 0.0097, 6.4 }, size = { 7.8, 8.3, 8.7 }, note = "the lived-in detail layer" },
		{ name = "WarningSign", level = "detail", attaches = "Span", at = { 0.0085, -3.9, 7.1 }, size = { 3, 0.14, 1.1 }, note = "the lived-in detail layer" },
		{ name = "Bulbs", level = "detail", attaches = "Span", at = { 0, 0, 10.3 }, size = { 7.5, 8.1, 0.62 }, note = "the lived-in detail layer" },
	},
	clearance = {
		{ part = "Walkway", width = 7.6, height = 6 },
		{ part = "Capsule under span", width = 7, height = 4.75 },
	},
}
