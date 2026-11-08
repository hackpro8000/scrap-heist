-- Part plan for the remade RebirthPress (art/concepts/rebirth-press-sketch.png):
-- the yard's landmark, a hydraulic press 16 x 8 on the ground and 15.2 tall
-- that flattens the yard's scrap pile into a medal. Origin at the middle
-- of the footprint at ground level, z up, the front (console, medal tray)
-- on the -y side. Twice the old one's height: a plinth with a hazard band,
-- two riveted box columns under a crown beam, the cylinder on top, its ram
-- holding the hazard-taped platen over a heap of scrap on the anvil, the
-- medal sliding down a ramp to the front, a console with a caged red button
-- at the +x end. Everything stays inside the 16 x 8: the game centres a yard
-- thing's bounding box on its cells.
return {
	parts = {
		{
			name = "Plinth",
			level = "core",
			at = { 0, 0, 0.6 },
			size = { 16, 8, 1.2 },
			note = "a concrete pad exactly the press's 16 by 8 cells, the dark riveted steel bed on it, set back 1.4 from the pad's front edge, a crisp hazard band round the bed's top edge",
		},
		{
			name = "Anvil",
			level = "major",
			attaches = "Plinth",
			at = { -1.5, 0.4, 1.9 },
			size = { 7.4, 5.4, 1.4 },
			note = "the bed block under the platen, bare steel with darker sides, its top scarred, on a wider base lip",
		},
		{
			name = "Columns",
			level = "major",
			attaches = "Plinth",
			at = { -1.5, 0.4, 5.9 },
			size = { 11.8, 3.4, 9.4 },
			note = "two box columns at x = -6.2 and 3.2, each 2.4 by 3.4 in steel a step lighter than the plinth and crown, riveted along the edges, a wide bronze cap band and a bronze foot plate bolted to the plinth",
		},
		{
			name = "Crown",
			level = "major",
			attaches = "Columns",
			at = { -1.5, 0.4, 11.7 },
			size = { 12.2, 4, 2.2 },
			note = "the top beam across the columns, riveted, a bronze plate reading REBIRTH on its front, a round pressure gauge beside it",
		},
		{
			name = "Cylinder",
			level = "major",
			attaches = "Crown",
			at = { -1.7, 0.4, 14 },
			size = { 4, 3.8, 2.4 },
			note = "the hydraulic cylinder standing on the crown, a domed cap with a bolt ring, two hose fittings",
		},
		{
			name = "Ram",
			level = "major",
			attaches = "Cylinder",
			at = { -1.5, 0.4, 8.5 },
			size = { 2.6, 2.6, 4.1 },
			note = "the bare steel rod from the crown down to the platen, a collar where it meets each",
		},
		{
			name = "Platen",
			level = "major",
			attaches = "Ram",
			at = { -1.5, 0.4, 6 },
			size = { 7, 5, 0.9 },
			note = "the press plate hanging 3.4 above the pile, dark steel with a crisp hazard tape rim, bolt heads along its sides",
		},
		{
			name = "Pile",
			level = "major",
			attaches = "Anvil",
			at = { -1.5, 0.3, 2.4 },
			size = { 7.3, 4.7, 4 },
			note = "the yard's scrap heap on the anvil, 2.4 proud of it (each mound's lower half is buried in the anvil): dented cans, a gear, pipe ends, a hubcap, springs, in rusty steel and bright paint flecks, heaped to a low peak",
		},
		{
			name = "PileJunk",
			level = "detail",
			attaches = "Pile",
			at = { -1.3, 0.1, 4.2 },
			size = { 4.1, 4, 2.9 },
			note = "the heap's big pieces, each in its own finish: a brass gear standing in it, a silver hubcap leaning on the side, a stack of three painted cans with label bands, a steel spring",
		},
		{
			name = "Tray",
			level = "detail",
			attaches = "Plinth",
			at = { -1.5, -3, 1.3 },
			size = { 3.2, 1.9, 2.1 },
			note = "a steel ramp from a dark mouth at the anvil's front edge down to a floor and a lip at the pad's front, its middle worn bright; seated into the bed's front",
		},
		{
			name = "Medal",
			level = "detail",
			attaches = "Tray",
			at = { -1.5, -3, 1.5 },
			size = { 2.2, 1.5, 1.9 },
			note = "a bright brass medal 2.2 across at the ramp's foot, leaning back on it so its face is toward whoever walks up, a raised rim and boss",
		},
		{
			name = "Console",
			level = "major",
			attaches = "Plinth",
			at = { 6.3, -1.2, 3.4 },
			size = { 2.5, 2.6, 4.5 },
			note = "a pedestal at the +x end with a sloped top panel: the big red button's bezel, four hinge posts for its cage, a lever, a small gauge on the front, the lamp's stalk",
		},
		{
			name = "Cage",
			level = "detail",
			attaches = "Console",
			at = { 6, -1.4, 5.45 },
			size = { 1.4, 1.5, 0.1 },
			note = "a hinged yellow cage of thin bars over the button, on the console's posts",
		},
		{
			name = "Button",
			level = "detail",
			attaches = "Console",
			at = { 6.1, -0.95, 5.2 },
			size = { 1.9, 1.6, 1.6 },
			note = "the big red button under the cage and the red lamp on its stalk, both glowing",
		},
		{
			name = "Hoses",
			level = "detail",
			attaches = "Cylinder",
			at = { -5.5, 1.6, 8.4 },
			size = { 4.2, 3.7, 11 },
			note = "two black hydraulic hoses from the cylinder's fittings over the crown's back edge and down the back of the -x column to the pump",
		},
		{
			name = "Pump",
			level = "detail",
			attaches = "Plinth",
			at = { -7.1, 3, 2.2 },
			size = { 1.8, 1.6, 2 },
			note = "the hydraulic pump box behind and beyond the -x column so it shows from the back, a motor dome, a filler cap, a collar where each hose enters",
		},
		{
			name = "Collars",
			level = "detail",
			attaches = "Hoses",
			at = { -5.5, 1.6, 8.4 },
			size = { 4.4, 3.7, 11 },
			note = "brass bands on the hoses at the cylinder, over the crown and at the column's foot, so their route reads",
		},
		{
			name = "Beacons",
			level = "detail",
			attaches = "Crown",
			at = { -1.5, 0.4, 13.1 },
			size = { 11.8, 3.6, 0.6 },
			note = "four orange beacons, one on each crown corner, glowing",
		},
	},
	-- No space a player walks through: the platen hangs 3.4 above the pile
	-- and 5.6 above the bed, under the capsule's 5.5 but over no walkway. The
	-- player stands on the ground at the front (y below -4) at the console and
	-- the tray; the plinth is a 1.2 step.
	clearance = {},
}
