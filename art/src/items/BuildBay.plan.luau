-- Part plan for the remade BuildBay (art/concepts/build-bay-sketch.png): the
-- yard's hatching bay, exactly 10 x 10 on the ground and 8.1 tall, where a
-- capsule sits on a raised drum and is whacked open with the Big Spanner;
-- raiders grab it from there. Origin at the middle of the footprint at
-- ground level, z up, the front (toward the gate) on the -y side.
--
-- Three things the game fixes:
--   - The capsule's seat is found by dropping a ray from above the bay's
--     middle (PlotService.seatOf), so nothing may stand over x = 0, y = 0:
--     the frame is on the back edge and the lamp arm stops 0.7 short. Only
--     the Deck and Cradle cover the middle: the clamps are one part each and
--     the lamps two parts, so no part reaches across the seat whatever
--     collision shape Roblox gives it.
--   - The art's bounding box is centred on the cells, so nothing reaches
--     past the deck's 10 x 10.
--   - Capsules sit on the seat with their bounding box: the widest is 3.6
--     wide and 2.3 deep (corner 2.14 from the middle), the deepest 2.7, the
--     tallest 3.4, so the clamps stay at radius 2.3 or more and the lamp's
--     shade above z 5.3.
return {
	parts = {
		{
			name = "Deck",
			level = "core",
			at = { 0, 0, 0.25 },
			size = { 10, 10, 0.5 },
			note = "a concrete kerb exactly 10 by 10, a riveted dark steel deck on it with a chequer-plate top, a crisp hazard border and a painted ring round the drum",
		},
		{
			name = "Cradle",
			level = "major",
			attaches = "Deck",
			at = { 0, 0, 1.14 },
			size = { 5.7, 5.7, 1.28 },
			note = "a steel drum 2.6 in radius in the middle, flat on top at z 1.7 for the capsule's seat with a target painted on it, a low rubber ring round the top, a crisp hazard band, a bolted flange at its foot",
		},
		{
			name = "Clamp1",
			level = "major",
			attaches = "Cradle",
			at = { 0, 2.7, 2.1 },
			size = { 0.7, 0.9, 2.6 },
			note = "a bronze claw on a steel hinge boss on the drum's side behind the capsule, rising to z 3.3, its rubber pad stopping at radius 2.3",
		},
		{ name = "Clamp2", level = "major", attaches = "Cradle", at = { -2.4, -1.4, 2.1 }, size = { 1, 0.9, 2.6 }, note = "the same claw on the front left" },
		{ name = "Clamp3", level = "major", attaches = "Cradle", at = { 2.4, -1.4, 2.1 }, size = { 1, 0.9, 2.6 }, note = "the same claw on the front right" },
		{
			name = "Frame",
			level = "major",
			attaches = "Deck",
			at = { 0, 3.9, 4.1 },
			size = { 8.8, 1.1, 7.2 },
			note = "the back of the bay: two riveted box posts at x = -3.7 and 3.7 with a beam across them at z 6.6 to 7.5, bronze cap bands, two braces crossing behind the board, all on the back edge so the front stays open to the gate",
		},
		{
			name = "Board",
			level = "major",
			attaches = "Frame",
			at = { 0, 3.9, 3.5 },
			size = { 6.6, 0.2, 6.1 },
			note = "a blue-grey steel pegboard filling the frame behind the capsule, bolted at its corners, HATCH stencilled low on it where a seated capsule mostly hides it",
		},
		{
			name = "Tools",
			level = "detail",
			attaches = "Board",
			at = { -0.2, 3.8, 4.1 },
			size = { 6, 0.3, 4.8 },
			note = "hung on pegs on the board: the Big Spanner left of the capsule, a small spanner and a hammer along the top",
		},
		{
			name = "Panel",
			level = "major",
			attaches = "Board",
			at = { 2.5, 2.7, 2.7 },
			size = { 1.3, 2.4, 4.4 },
			note = "a control box on the board right of the capsule: a big dial, a red ARMED lamp for the booby trap, a lever, a cable running down and across the deck to the drum",
		},
		{
			name = "Arm",
			level = "major",
			attaches = "Frame",
			at = { 0, 2.1, 6.5 },
			size = { 1.1, 2.7, 1.9 },
			note = "a work lamp on a jointed arm from the beam, reaching forward over the capsule's back and stopping 0.7 short of the middle, its shade tipped at the capsule, above z 5.3",
		},
		{
			name = "Posts",
			level = "major",
			attaches = "Deck",
			at = { 0, -4.4, 2.5 },
			size = { 9.6, 0.7, 4.1 },
			note = "a steel lamp post at each front corner, 4 tall, with a bracket arm reaching in",
		},
		{
			name = "PostLamps",
			level = "detail",
			attaches = "Posts",
			at = { 0, -4.1, 4.55 },
			size = { 8.2, 0.6, 0.6 },
			note = "the amber lamps on the two front posts, glowing",
		},
		{
			name = "BackLamps",
			level = "detail",
			attaches = "Frame",
			at = { 0, 2.7, 5.8 },
			size = { 8.8, 3.1, 4.8 },
			note = "the rest of the glowing lamps, all behind the seat: amber on the beam's ends and in the arm's shade, a row of green indicators along the beam's front, the red ARMED lamp on the panel",
		},
		{
			name = "Crate",
			level = "detail",
			attaches = "Deck",
			at = { -3.6, 2.5, 1.3 },
			size = { 1.7, 1.4, 1.7 },
			note = "a parts crate in the back left corner, gears and pipe ends showing over its rim",
		},
		{
			name = "Drum",
			level = "detail",
			attaches = "Deck",
			at = { 3.6, 2.6, 1.5 },
			size = { 1.4, 1.3, 2 },
			note = "an oil drum in the back right corner, a band round it, a funnel on top",
		},
	},
	-- Nothing is walked through. The player steps up the deck's 0.5 from the
	-- front or either side and stands at the drum: the two front lamps are
	-- 7.7 apart at head height against the 4 wide capsule, and there is
	-- nothing overhead in front of the drum. The back is closed by the frame.
	clearance = {},
}
