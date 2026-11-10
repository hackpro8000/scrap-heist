-- Part plan for HubStage (art/concepts/town-pieces-sketch.png): The event stage: a raised plate platform with a scrap lighting rig. 26 by 26, stairs on the -y side.
-- Origin at the middle of the footprint at ground level, z up.
return {
	parts = {
		{ name = "Platform", level = "core", at = { 0.0049, 2, 1.4 }, size = { 26, 22, 0.96 }, note = "steel plates on oil drums, top at 1.8" },
		{ name = "PlatformDrums", level = "detail", attaches = "Platform", at = { 0, 2, 0.7 }, size = { 24, 18, 1.4 }, note = "oil drums the plates rest on" },
		{ name = "Steps", level = "major", attaches = "Platform", at = { 0, -10.95, 0.9 }, size = { 10.4, 4.5, 1.9 }, note = "wide steps up the front, with stringers and a lip at the deck's edge" },
		{ name = "Truss", level = "major", attaches = "Platform", at = { 0, 8, 7.2 }, size = { 26, 2.9, 11 }, note = "lattice towers; 2 of them" },
		{ name = "TrussTop", level = "major", attaches = "Truss", at = { 0, 8, 13.5 }, size = { 26, 2, 1.8 }, note = "lattice beam across" },
		{ name = "Backdrop", level = "major", attaches = "Truss", at = { -0.058, 9.1, 7.1 }, size = { 22, 0.52, 11 }, note = "patchwork sheet-metal backdrop" },
		{ name = "Speakers", level = "major", attaches = "Platform", at = { 0, 2, 4.5 }, size = { 26, 3.1, 5.5 }, note = "stacks of salvaged speakers; 2 of them" },
		{ name = "SpeakerCones", level = "detail", attaches = "Speakers", at = { -0.28, 0.7, 4.6 }, size = { 25, 0.64, 4.8 }, note = "speaker cones" },
		{ name = "Lamps", level = "detail", attaches = "TrussTop", at = { 0.047, 7.5, 11.2 }, size = { 21, 1.1, 0.96 }, note = "row of 5 mismatched stage lamps" },
		{ name = "BackdropRivets", level = "detail", attaches = "Backdrop", at = { -0.05, 8.9, 7.1 }, size = { 22, 0.21, 10 }, note = "added after the first review" },
		{ name = "LampHousings", level = "detail", attaches = "TrussTop", at = { 0, 8, 11.8 }, size = { 21, 1.6, 1.8 }, note = "added after the first review" },
		{ name = "SpeakerSurrounds", level = "detail", attaches = "Speakers", at = { -0.28, 0.72, 4.6 }, size = { 25, 0.58, 4.8 }, note = "dark surrounds the drivers sit in" },
		{ name = "Fittings", level = "detail", attaches = "Platform", at = { 0.44, -2.2, 7.4 }, size = { 26, 21, 14 }, note = "the lived-in detail layer" },
		{ name = "Supplies", level = "detail", attaches = "Platform", at = { -0.015, 3.1, 3.1 }, size = { 27, 18, 2.6 }, note = "the lived-in detail layer" },
		{ name = "Cables", level = "detail", attaches = "Platform", at = { 0, 1.1, 7.2 }, size = { 24, 12, 11 }, note = "the lived-in detail layer" },
		{ name = "Banner", level = "detail", attaches = "TrussTop", at = { 0, 7, 13.45 }, size = { 11, 0.18, 1.3 }, note = "the lived-in detail layer" },
	},
	clearance = {
		{ part = "Under the beam", width = 22, height = 11 },
	},
}
