-- Part plan for MineLoop, after the reference the user picked
-- (Column Island's carved stone columns): a hill of carved columns over the
-- track, with a timber porch at each mouth. In the model's own studs: origin
-- the hub's middle at deck level, Z up, the cave straddling the track at +X
-- (radius 72), its mouths at Y = -13.7 and +13.7, each porch running about
-- 3.5 on out of its mouth. The rocks are four parts, one per quarter of
-- the pile, so each texture holds the item's texel density. Paired pieces
-- (one per mouth) are one part each, so their boxes cover both mouths.
return {
	parts = {
		{
			name = "Lintels",
			level = "core",
			at = { 71.4, 0, 8.2 },
			size = { 9.9, 28.8, 2.8 },
			note = "big squared stone blocks laid flat across the tunnel just over the 6.6 opening, front to back, roofing it and carrying the columns above; their ends show over each porch",
		},
		{
			name = "Rocks1",
			level = "major",
			attaches = "Lintels",
			at = { 65.4, -10.5, 6.9 },
			size = { 15.8, 24.4, 14.9 },
			note = "a hill of carved stone columns built the Column Island way: a power diagram of stones (small near a summit on the far side, big toward the foot), each cell a column rising to the slope's height with one flat tilted top, its edges chamfered unevenly and sub-chamfered, chipped at corners and along edges, and bitten by a cut or two facing out from the summit; cells crossing the tunnel split at its walls, the part over it standing on the lintels; the hill carries on past each mouth and the tunnel bores on through it, the stone over each porch standing on its roof, each porch sticking out of the hill's face about 3.5, its frame covering the bore's edges; a ridge about 13.5 tall along the track keeps the hill high over the tunnel and porches, under a crown of columns about 18.5 tall: the hub side, toward the - mouth quarter",
		},
		{
			name = "Rocks2",
			level = "major",
			attaches = "Lintels",
			at = { 77.5, -15.2, 8 },
			size = { 17.7, 27, 17 },
			note = "the same pile: the far side, toward the - mouth quarter",
		},
		{
			name = "Rocks3",
			level = "major",
			attaches = "Lintels",
			at = { 65, 11.8, 7.1 },
			size = { 14.9, 28.6, 15.1 },
			note = "the same pile: the hub side, toward the + mouth quarter",
		},
		{
			name = "Rocks4",
			level = "major",
			attaches = "Lintels",
			at = { 76.6, 12, 8.1 },
			size = { 17, 31.3, 17.1 },
			note = "the same pile: the far side, toward the + mouth quarter",
		},
		{
			name = "Posts",
			level = "major",
			attaches = "Rocks1",
			at = { 71, 0, 3.6 },
			size = { 10, 35, 7.4 },
			note = "round log posts, 1.2 thick, two each side of each mouth: one against the rock face, one 3.5 out in front",
		},
		{
			name = "Beams",
			level = "major",
			attaches = "Posts",
			at = { 71, 0, 7.3 },
			size = { 9.7, 39, 1.5 },
			note = "square header beams across the front and back posts and along each side, just above the 6.6 opening",
		},
		{
			name = "Roofs",
			level = "major",
			attaches = "Beams",
			at = { 70, 0, 8.3 },
			size = { 11, 39, 0.6 },
			note = "a deck of separate planks on each porch, each its own shade of orange-brown, overhanging the beams by about 0.5, a nail head where each crosses a side beam",
		},
		{
			name = "Boards",
			level = "detail",
			attaches = "Posts",
			at = { 71.5, 0, 4.5 },
			size = { 13, 31, 9.5 },
			note = "upright boards behind the back posts closing the gap between the porch and the rocks",
		},
		{
			name = "Stones",
			level = "detail",
			attaches = "Rocks1",
			at = { 68.4, 0.2, 0.2 },
			size = { 10.7, 52.8, 0.9 },
			note = "a few small broken-off column chunks, squared with chipped edges, beside the track past each porch's front",
		},
		{
			name = "Shades",
			level = "detail",
			attaches = "Rocks1",
			at = { 72, 0, 3.3 },
			size = { 6.2, 26, 6.4 },
			note = "black unlit inside of each mouth, clear at the mouth, opaque 4.5 in (kept as the user asked)",
		},
		{
			name = "Rails",
			level = "major",
			at = { 0, 0, -1.3 },
			size = { 147.4, 147.4, 4.2 },
			note = "one lap of rails at radius 72, gauge 3, both ends diving 3.5 down inside the tunnel",
		},
		{
			name = "Sleepers",
			level = "detail",
			attaches = "Rails",
			at = { 0, 0, -1.6 },
			size = { 150.2, 150.2, 4 },
			note = "timber sleeper every 1.6 degrees under the rails",
		},
	},
	-- Each porch, seen along the track: 6.4 wide between the posts and 6.6
	-- under the beams, against the 4 by 5.5 capsule (1.2 spare each side,
	-- 1.1 overhead) and the cart (3.6 wide, 4.9 tall with its capsule).
	clearance = { { part = "Posts", width = 6.4, height = 6.6 } },
}
