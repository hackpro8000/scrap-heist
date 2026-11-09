-- Part plan for HubTinkerer (art/concepts/town-pieces-sketch.png): The tinkerer's stand: an open lean-to workshop. 18 by 18, open on the -y side.
-- Origin at the middle of the footprint at ground level, z up.
return {
	parts = {
		{ name = "Deck", level = "core", at = { 0, 0, 0.25 }, size = { 18, 18, 0.5 }, note = "oil-stained steel floor plates" },
		{ name = "BackWall", level = "major", attaches = "Deck", at = { 0, 7.5, 4.25 }, size = { 16, 1, 7.5 }, note = "corrugated wall with a tool rack" },
		{ name = "Roof", level = "major", attaches = "BackWall", at = { 0, 1.5, 8.1 }, size = { 18, 14, 1.2 }, note = "lean-to roof, sloping back" },
		{ name = "RoofPosts", level = "detail", attaches = "Deck", at = { 0, -5, 4.2 }, size = { 17, 0.81, 7.6 }, note = "front posts; 2 of them" },
		{ name = "Workbench", level = "major", attaches = "Deck", at = { 0, 3.5, 1.9 }, size = { 13, 3.5, 2.8 }, note = "long bench where parts are upgraded" },
		{ name = "RobotArm", level = "major", attaches = "Workbench", at = { -4.5, 3.5, 5.5 }, size = { 2.8, 2.2, 3.8 }, note = "bolted-on arm holding a welding torch" },
		{ name = "PartsBins", level = "detail", attaches = "BackWall", at = { 6, 6.5, 4.5 }, size = { 5, 1.4, 3 }, note = "rows of parts bins on the wall" },
		{ name = "HangingSign", level = "detail", attaches = "Roof", at = { 0, -5.9, 7.4 }, size = { 2, 1, 2 }, note = "cog-shaped sign on the front beam, bottom at 6.5" },
		{ name = "Anvil", level = "detail", attaches = "Deck", at = { 4, -3.6, 1.8 }, size = { 2.5, 1.6, 2.6 }, note = "anvil on a drum" },
		{ name = "ToolRack", level = "detail", attaches = "BackWall", at = { -3.5, 7, 5.2 }, size = { 7, 0.65, 2.9 }, note = "added after the first review" },
		{ name = "RackTools", level = "detail", attaches = "ToolRack", at = { -3.5, 6.7, 5 }, size = { 6.5, 0.62, 2.3 }, note = "added after the first review" },
		{ name = "TorchAndWork", level = "major", attaches = "Workbench", at = { -0.094, 2.5, 4.4 }, size = { 9, 3.1, 2.4 }, note = "added after the first review" },
		{ name = "BinParts", level = "detail", attaches = "PartsBins", at = { 5.4, 6.4, 4 }, size = { 4, 1, 2.5 }, note = "added after the first review" },
		{ name = "SignEmblem", level = "detail", attaches = "HangingSign", at = { 0, -6.2, 7.4 }, size = { 1.4, 0.16, 1.2 }, note = "added after the first review" },
		{ name = "Fittings", level = "detail", attaches = "Deck", at = { -0.47, 2.8, 4.2 }, size = { 16, 9, 7.5 }, note = "the lived-in detail layer" },
		{ name = "Blueprint", level = "detail", attaches = "Deck", at = { 1.4, 7.1, 4.8 }, size = { 1.5, 0.11, 1.7 }, note = "the lived-in detail layer" },
		{ name = "Supplies", level = "detail", attaches = "Deck", at = { 0.093, 2.2, 1.8 }, size = { 17, 12, 2.7 }, note = "the lived-in detail layer" },
		{ name = "Cables", level = "detail", attaches = "Deck", at = { 3.3, 4.3, 4.2 }, size = { 11, 5.7, 7.5 }, note = "the lived-in detail layer" },
		{ name = "LampShade", level = "detail", attaches = "Deck", at = { -0.99, 1.5, 7.1 }, size = { 0.83, 0.84, 0.46 }, note = "the lived-in detail layer" },
		{ name = "Bulbs", level = "detail", attaches = "Deck", at = { -2, 2, 5.3 }, size = { 2.2, 1.3, 3.5 }, note = "the lived-in detail layer" },
		{ name = "Rafters", level = "detail", attaches = "Roof", at = { 0, 1, 7.7 }, size = { 18, 13, 1.2 }, note = "added in review" },
		{ name = "ToolGrips", level = "detail", attaches = "RackTools", at = { -2.7, 6.7, 5 }, size = { 4.8, 0.18, 2.3 }, note = "added in review" },
	},
	clearance = {
		{ part = "Under roof", width = 16, height = 7 },
	},
}
