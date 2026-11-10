-- Part plan for CapsuleLoop: the hub's capsule belt and the little factory
-- it runs through, replacing MineLoop. In the model's own studs: origin the
-- hub's middle at deck level, Z up, the belt one lap at radius 72, the
-- factory straddling it at +X. Capsules ride the belt counter-clockwise:
-- they go in the shed's -Y mouth to be crushed, and new ones come out of
-- its +Y mouth.
return {
	parts = {
		{ name = "Shed", level = "core", at = { 71.5, 0, 4.2 }, size = { 14.9, 16.9, 8.3 }, note = "riveted corrugated steel walls on a concrete footing, a mouth at each end the belt runs through" },
		{ name = "Roof", level = "major", attaches = "Shed", at = { 71.5, 0, 9.7 }, size = { 15.2, 17.2, 2.7 }, note = "low pitched steel roof with a short overhang, its ridge along the belt" },
		{ name = "Frames", level = "major", attaches = "Shed", at = { 71.5, 0, 3.7 }, size = { 8.6, 16.8, 7.4 }, note = "heavy yellow steel frame round each mouth, hazard stripes painted on the uprights" },
		{ name = "Signs", level = "detail", attaches = "Frames", at = { 71.5, 0, 7.8 }, size = { 6, 16.3, 0.9 }, note = "plate over each mouth: a crushed capsule over the -Y mouth, a fresh capsule over the +Y mouth" },
		{ name = "Curtains", level = "detail", attaches = "Frames", at = { 71.5, 0, 3.7 }, size = { 6.9, 15.8, 5.7 }, note = "black rubber strips hanging over each mouth to just above the rails, capsules and players push through" },
		{ name = "Shades", level = "detail", attaches = "Shed", at = { 71.5, 0, 3.3 }, size = { 6.9, 15.5, 6.5 }, note = "black unlit gradient inside each mouth, so the inside of the shed needs no modelling" },
		{ name = "Press", level = "major", attaches = "Roof", at = { 71.5, -4, 12.9 }, size = { 6, 5.1, 5.7 }, note = "the crusher on the roof over the -Y mouth: a squat housing with a thick hydraulic ram going down through the roof" },
		{ name = "Hopper", level = "major", attaches = "Roof", at = { 71.5, 4, 12.6 }, size = { 5.8, 5.8, 5 }, note = "the maker on the roof over the +Y mouth: a funnel hopper on legs, a chute going down through the roof" },
		{ name = "DrivePlate", level = "detail", attaches = "Shed", at = { 78.67, 0.25, 4 }, size = { 0.3, 7.6, 5.6 }, note = "riveted backing plate for the drive cogs on the outer wall" },
		{ name = "DriveGears", level = "major", attaches = "DrivePlate", at = { 78.9, 0.25, 4.1 }, size = { 0.8, 7, 4.8 }, note = "the sketch's big and small cogs meshing on the outer wall" },
		{ name = "Stack", level = "major", attaches = "Roof", at = { 76.5, 5, 12.4 }, size = { 2.6, 2.6, 7.2 }, note = "a stubby chimney with a banded top at the shed's far corner" },
		{ name = "Pipes", level = "detail", attaches = "Roof", at = { 74.4, 0.5, 12 }, size = { 2.3, 9.4, 4.6 }, note = "pipes from the press across the roof to the hopper and the stack" },
		{ name = "Beacons", level = "detail", attaches = "Frames", at = { 71.5, 0, 7.7 }, size = { 8.4, 16.8, 0.6 }, note = "amber lamps at the top corners of each frame" },
		{ name = "Tread", level = "major", at = { 0, 0, 0.45 }, size = { 149, 149, 0.3 }, note = "the rubber belt, 5 wide, top 0.6 above the deck, one lap at radius 72, passing through the shed" },
		{ name = "BeltRails", level = "major", attaches = "Tread", at = { 0, 0, 0.5 }, size = { 150.2, 150.2, 0.9 }, note = "low steel side rails standing 0.35 above the belt to keep the capsules on" },
		{ name = "BeltFeet", level = "detail", attaches = "BeltRails", at = { -0.5, 0, 0.1 }, size = { 151.2, 152.3, 0.2 }, note = "a steel foot under the rails every few studs, seating them on the deck" },
	},
	-- Each mouth, seen along the belt: 7 wide and 6.6 tall against the 4 by
	-- 5.5 player capsule (1.5 spare each side, 1.1 overhead) and a riding
	-- capsule (3.4 tall on the 0.6 belt, 2.6 under the frame).
	clearance = { { part = "Frames", width = 7, height = 6.6 } },
}
