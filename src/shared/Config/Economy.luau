--!strict
--[[
	Economy config

	Machine costs, output and the storage crate. Every yard has the same
	four pads (Pad1-Pad4, matching the yard layout art); each pad holds one
	salvage machine with three upgrade tiers (the machine art's three
	tiers). Later pads cost more, so a yard grows pad by pad.

	Parts are produced into the yard's storage crate. Collecting the crate
	turns parts into scrap at PART_VALUE each. Parts sitting in the crate
	are what raiders steal, so collecting often is the defense.

	Game.INCOME_MULTIPLIER and Game.COST_MULTIPLIER scale everything here.
]]

local Economy = {}

-- Scrap a brand new player starts with: enough for the first machine.
Economy.STARTING_SCRAP = 50

-- In unlock order.
Economy.PADS = { "Pad1", "Pad2", "Pad3", "Pad4" }

-- Scrap to buy the machine on each pad.
Economy.BUY_COSTS = {
	Pad1 = 50,
	Pad2 = 300,
	Pad3 = 1200,
	Pad4 = 4000,
} :: { [string]: number }

-- Upgrade to level N costs the pad's buy cost times UPGRADE_COST_FACTORS[N].
Economy.UPGRADE_COST_FACTORS = {
	[2] = 2,
	[3] = 5,
} :: { [number]: number }

Economy.MAX_LEVEL = 3

-- Parts per second for one machine at each level.
Economy.LEVEL_RATES = { 1, 2.5, 6 } :: { number }

-- Seconds between production ticks.
Economy.TICK_SECONDS = 1

-- Most parts a crate holds. A full crate stops production until collected.
Economy.CRATE_CAPACITY = 2000

-- Scrap per part when collecting or banking a stolen bundle.
Economy.PART_VALUE = 1

-- Offline earnings: machines run at this fraction of their rate while the
-- player is away, for at most OFFLINE_CAP_SECONDS.
Economy.OFFLINE_RATE = 0.5
Economy.OFFLINE_CAP_SECONDS = 2 * 60 * 60

return Economy
