-- Part plan for MineLoop, after the reference the user picked
-- (art/concepts/mine-portal-reference.png): a pile of chunky rounded
-- boulders over the track with a timber porch at each mouth. In the model's
-- own studs: origin the hub's middle at deck level, Z up, the cave
-- straddling the track at +X (radius 72), its mouths at Y = -13.7 and
-- +13.7, each porch running about 3.5 on out of its mouth. The rocks are
-- four parts, one per quarter of the pile. Paired pieces
-- (one per mouth) are one part each, so their boxes cover both mouths.
return {
	parts = {
		{
			name = "Rocks1",
			level = "core",
			at = { 66.4, -5.9, 8.3 },
			size = { 21.5, 16.3, 17.6 },
			note = "about 47 chunky boulders and flat slabs of very different sizes (a few big ones, medium walls and roof, small ones at the foot and in the joints) with rounded edges and broad faces, blue-grey, stacked in tiers to a tall peak toward the hub; rocks flank each porch against its boards; the rocks themselves wall and roof the tunnel, overlapping so no gap shows through: nothing but rock. Those on the ground sit flat on it: the hub side, toward the - mouth quarter"
		},
		{
			name = "Rocks2",
			level = "core",
			attaches = "Rocks1",
			at = { 76.4, -7, 6.7 },
			size = { 22.9, 20.7, 14.4 },
			note = "the same pile: the far side, toward the - mouth quarter"
		},
		{
			name = "Rocks3",
			level = "core",
			attaches = "Rocks1",
			at = { 67.7, 6.2, 5.7 },
			size = { 17.9, 14.8, 12.3 },
			note = "the same pile: the hub side, toward the + mouth quarter"
		},
		{
			name = "Rocks4",
			level = "core",
			attaches = "Rocks1",
			at = { 76.5, 8.8, 7 },
			size = { 21.1, 18, 15 },
			note = "the same pile: the far side, toward the + mouth quarter"
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
			name = "Lanterns",
			level = "detail",
			attaches = "Posts",
			count = 1,
			at = { 65.2, 0, 3.15 },
			size = { 0.8, 35, 1.1 },
			note = "a small glowing lantern hung on the hub-side front post of each mouth, painted glow only",
		},
		{
			name = "Stones",
			level = "detail",
			attaches = "Rocks1",
			at = { 71, 0, 0.3 },
			size = { 14, 42, 1.2 },
			note = "a few small rounded pebbles and rocks round each porch's foot",
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
