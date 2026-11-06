--!strict
--[[
	Rebirth config ("Scrap the Yard")

	The ladder of ranks. Reaching a rank costs scrap (all the player's scrap
	is reset to 0) and needs certain junkrots standing on pads. A need names
	a junkrot by id, or any junkrot of a tier, at a number of stars or more.
	Numbers follow docs/plans/gameplay-content.md.
]]

local Rebirth = {}

export type Need = {
	-- One of these: a junkrot's id, or a tier any junkrot of which will do.
	id: string?,
	tier: string?,
	stars: number,
	limited: boolean?,
	count: number,
}

export type Rank = {
	cost: number,
	needs: { Need },
	-- What the rank unlocks, for the press's card.
	unlocks: string,
}

-- Each rank adds this much to the income multiplier: rank 20 earns x11.
Rebirth.INCOME_PER_RANK = 0.5

local function named(stars: number, ...: string): { Need }
	local needs = {}
	for _, id in { ... } do
		table.insert(needs, { id = id, stars = stars, count = 1 })
	end
	return needs
end

local function any(tier: string, stars: number, count: number): { Need }
	return { { tier = tier, stars = stars, count = count } }
end

Rebirth.LADDER = {
	{ cost = 400e3, needs = named(1, "CanettoRustini", "TyroFlattino", "RemotinoMuto"), unlocks = "Pad 7, more land" },
	{ cost = 5.25e6, needs = named(1, "CrumboPoppalot", "JackoloCrickato", "RadioloFruscio"), unlocks = "Pad 8, more land" },
	{ cost = 15e6, needs = named(1, "PannettoPatchato", "OilcannaGluglu", "FanettoWobblino"), unlocks = "Pad 9, more land" },
	{ cost = 62.5e6, needs = named(1, "BlendroCigolante", "MuffleroTossetto", "ClockoTictacco"), unlocks = "Pad 10, more land" },
	{ cost = 100e6, needs = named(1, "FrostboxGelatone", "MopaMopetta", "TelefonoRingaling"), unlocks = "Pad 11, second build bay" },
	{ cost = 425e6, needs = named(1, "MicrondoBippetto", "DrilloTrapanino", "TypewrittoClackini"), unlocks = "Pad 12, more land" },
	{ cost = 2.25e9, needs = named(1, "MixerellaVroom", "GrindellaScintilla", "CamerinoFlashetto"), unlocks = "Pad 13" },
	{ cost = 4.75e9, needs = named(3, "FrostboxGelatone", "DrilloTrapanino", "TypewrittoClackini"), unlocks = "Pad 14, more land" },
	{ cost = 12.5e9, needs = named(4, "MixerellaVroom", "MopaMopetta", "TelefonoRingaling"), unlocks = "Pad 15" },
	{ cost = 22.5e9, needs = named(1, "GrindoBeanbasher", "LawnmowoRuggito", "ConsoloJoypaddino"), unlocks = "Pad 16, more land" },
	{ cost = 37.5e9, needs = named(1, "AirfryoCroccante", "LeafblowaWhooshini", "SpeakeroneBoomba"), unlocks = "Pad 17, third build bay" },
	{ cost = 50e9, needs = named(1, "DishwashinoSplashetto", "PressurwashoSprizzo", "RobovaccoGirotondo"), unlocks = "Pad 18, more land" },
	{ cost = 67.5e9, needs = named(3, "GrindoBeanbasher", "LawnmowoRuggito", "ConsoloJoypaddino"), unlocks = "Pad 19" },
	{ cost = 125e9, needs = named(4, "AirfryoCroccante", "PressurwashoSprizzo", "SpeakeroneBoomba"), unlocks = "Pad 20, more land" },
	{ cost = 250e9, needs = any("Factory", 5, 3), unlocks = "Longer offline earnings" },
	{ cost = 400e9, needs = named(1, "ChefbotPrecisio", "TorquoWrenchelli", "DronettoBuzzatti"), unlocks = "Lucky Badge III" },
	{ cost = 650e9, needs = named(1, "SousvideSilvano", "LaserlevelLineo", "TickworthPocketti"), unlocks = "Brushed-steel fence" },
	{ cost = 950e9, needs = named(1, "KnifeblockSlicetta", "WeldettaSparkalot", "HeadphonoBassimo"), unlocks = "Bigger storm haul" },
	{ cost = 1.25e12, needs = any("Precision", 3, 3), unlocks = "Lab glow" },
	{
		cost = 1.5e12,
		needs = { { tier = "Precision", stars = 1, limited = true, count = 1 }, { tier = "Precision", stars = 5, count = 2 } },
		unlocks = "The Scrap Baron title",
	},
} :: { Rank }

Rebirth.MAX_RANK = #Rebirth.LADDER

return Rebirth
