--!strict
--[[
	Items

	Every item in the game. Common and uncommon parts stack (a count per
	player); rare and legendary loot is unique, so each copy gets its own
	ID when it's created and can be traced through trades.

	Item IDs match the art models in art/models (RustyGear, GoldenCog, ...).

	Public API:
		Items.RARITY_ORDER: { Rarity }
		Items.Definitions.<ItemId>: ItemDefinition
		Items.MAX_STACK
		Items.get(itemId): ItemDefinition?
]]

local Items = {}

export type Rarity = "Common" | "Uncommon" | "Rare" | "Legendary"

export type ItemDefinition = {
	displayName: string,
	rarity: Rarity,
	-- Stackable items are counts; others are unique, one ID per copy.
	stackable: boolean,
	description: string,
}

Items.RARITY_ORDER = { "Common", "Uncommon", "Rare", "Legendary" } :: { Rarity }

-- Most of one stackable item a player can hold.
Items.MAX_STACK = 9999

Items.Definitions = {
	RustyGear = {
		displayName = "Rusty Gear",
		rarity = "Common",
		stackable = true,
		description = "Still turns. Mostly.",
	},
	BentBolt = {
		displayName = "Bent Bolt",
		rarity = "Common",
		stackable = true,
		description = "The nut is never coming off.",
	},
	CopperCoil = {
		displayName = "Copper Coil",
		rarity = "Uncommon",
		stackable = true,
		description = "Wound tight, still conducts.",
	},
	OldBattery = {
		displayName = "Old Battery",
		rarity = "Uncommon",
		stackable = true,
		description = "Some charge left. Don't lick it.",
	},
	CircuitBoard = {
		displayName = "Circuit Board",
		rarity = "Rare",
		stackable = false,
		description = "Pulled from a storm bot's chest.",
	},
	ServoMotor = {
		displayName = "Servo Motor",
		rarity = "Rare",
		stackable = false,
		description = "Twitches when the storm is near.",
	},
	ReactorCore = {
		displayName = "Reactor Core",
		rarity = "Legendary",
		stackable = false,
		description = "Glows green. Warm to the touch.",
	},
	GoldenCog = {
		displayName = "Golden Cog",
		rarity = "Legendary",
		stackable = false,
		description = "Nobody knows what machine it came from.",
	},
} :: { [string]: ItemDefinition }

function Items.get(itemId: any): ItemDefinition?
	if type(itemId) ~= "string" then
		return nil
	end

	return Items.Definitions[itemId]
end

return Items
