--!strict
--[[
	Shop config

	Everything the shop sells, tab by tab:
	- Weapons, bought once with scrap and kept (the Bat is free).
	- Boosts, bought with scrap, each lasting a while.
	- Passes, Robux game passes with a lasting perk.
	- Scrap packs, Robux developer products that pay scrap.

	Passes and packs need their Roblox IDs. Until an ID is set (0 here), its
	card shows "SOON" and can't be bought; create the pass or product on the
	experience's Monetization page and put its ID here.
]]

local Shop = {}

export type Weapon = { weapon: string, description: string, price: number }

-- In the order the Weapons tab lists them; weapon names are WeaponConfig's.
Shop.WEAPONS = {
	{ weapon = "Bat", description = "Quick three-hit combo", price = 0 },
	{ weapon = "Spanner", description = "Slow, heavy two-hit combo", price = 2500 },
} :: { Weapon }

export type Boost = {
	name: string,
	displayName: string,
	description: string,
	icon: string,
	price: number,
	seconds: number,
}

Shop.BOOSTS = {
	{
		name = "Overdrive",
		displayName = "OVERDRIVE",
		description = "Machines run twice as fast",
		icon = "IconOverdrive",
		price = 3000,
		seconds = 10 * 60,
	},
	{
		name = "Shield",
		displayName = "YARD SHIELD",
		description = "Nobody can raid your yard",
		icon = "IconShield64",
		price = 1500,
		seconds = 10 * 60,
	},
} :: { Boost }

export type Pass = {
	name: string,
	displayName: string,
	description: string,
	icon: string,
	badge: string?,
	-- Shown on the card; Roblox charges the price set on the pass itself.
	robux: number,
	gamePassId: number,
}

Shop.PASSES = {
	{
		name = "DoubleScrap",
		displayName = "2X SCRAP",
		description = "Double scrap from crates",
		icon = "IconScrap64",
		badge = "x2",
		robux = 199,
		gamePassId = 0,
	},
	{
		name = "BigCrate",
		displayName = "BIG CRATE",
		description = "Crate holds 50% more",
		icon = "IconCrate",
		robux = 149,
		gamePassId = 0,
	},
	{
		name = "AutoCollect",
		displayName = "AUTO COLLECT",
		description = "Crate banks itself",
		icon = "IconMagnet",
		robux = 249,
		gamePassId = 0,
	},
	{
		name = "VIP",
		displayName = "VIP",
		description = "Gold name, +10% scrap",
		icon = "IconCrown",
		robux = 299,
		gamePassId = 0,
	},
	{
		name = "LongShield",
		displayName = "LONG SHIELD",
		description = "Shields last twice as long",
		icon = "IconShield64",
		badge = "x2",
		robux = 99,
		gamePassId = 0,
	},
	{
		name = "StormLuck",
		displayName = "STORM LUCK",
		description = "Extra loot roll each storm",
		icon = "IconClover",
		robux = 249,
		gamePassId = 0,
	},
} :: { Pass }

export type ScrapPack = {
	name: string,
	displayName: string,
	icon: string,
	scrap: number,
	robux: number,
	productId: number,
}

Shop.SCRAP_PACKS = {
	{ name = "Pile", displayName = "SCRAP PILE", icon = "IconScrap64", scrap = 1000, robux = 49, productId = 0 },
	{ name = "Heap", displayName = "SCRAP HEAP", icon = "IconScrapHeap", scrap = 5000, robux = 199, productId = 0 },
	{ name = "Mountain", displayName = "SCRAP MOUNTAIN", icon = "IconScrapMountain", scrap = 20000, robux = 599, productId = 0 },
} :: { ScrapPack }

-- Perk sizes.
Shop.DOUBLE_SCRAP = 2
Shop.VIP_SCRAP = 1.1
Shop.BIG_CRATE = 1.5
Shop.OVERDRIVE = 2
Shop.AUTO_COLLECT_SECONDS = 60
Shop.LONG_SHIELD = 2

function Shop.boost(name: string): Boost?
	for _, boost in Shop.BOOSTS do
		if boost.name == name then
			return boost
		end
	end
	return nil
end

function Shop.weaponPrice(weapon: string): number?
	for _, entry in Shop.WEAPONS do
		if entry.weapon == weapon then
			return entry.price
		end
	end
	return nil
end

return Shop
