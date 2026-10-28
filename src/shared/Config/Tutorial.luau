--!strict
--[[
	Tutorial config

	The new-player prompts, in order. "Action" steps finish when the player
	does the thing (the server watches for it); "Tip" steps are information
	and finish when the player dismisses them. A tip with showDuring only
	appears in that round phase.
]]

local Tutorial = {}

export type Step = {
	name: string,
	kind: "Action" | "Tip",
	text: string,
	showDuring: string?,
}

Tutorial.STEPS = {
	{
		name = "BuyMachine",
		kind = "Action",
		text = "Welcome to your yard! Walk onto a pad and buy your first salvage machine.",
	},
	{
		name = "CollectCrate",
		kind = "Action",
		text = "Your machine fills the green storage crate with parts. Collect it for scrap.",
	},
	{
		name = "RaidTip",
		kind = "Tip",
		text = "Parts left in your crate can be stolen! Raid other yards' crates and carry the bundle home.",
	},
	{
		name = "StormTip",
		kind = "Tip",
		text = "A storm is coming! Fight the scrap bots outside your yard and survive for rare loot.",
		showDuring = "Warning",
	},
} :: { Step }

return Tutorial
