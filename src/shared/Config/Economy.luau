--!strict
--[[
	Economy config

	Money that isn't a junkrot's own: what a new player starts with, how
	often yards earn, and offline earnings. Junkrots and their capsules are
	in Config/Junkrots, the crate in Config/Yard.

	Junkrots earn scrap into their yard's crate. Collecting the crate banks
	it. Scrap sitting in the crate is what raiders steal, so collecting
	often is the defense.

	Game.INCOME_MULTIPLIER and Game.COST_MULTIPLIER scale everything.
]]

local Economy = {}

-- Scrap a brand new player starts with: enough for any Scrap capsule.
Economy.STARTING_SCRAP = 100

-- Seconds between income ticks.
Economy.TICK_SECONDS = 1

-- Offline earnings: junkrots run at this fraction of their rate while the
-- player is away, for at most OFFLINE_CAP_SECONDS.
Economy.OFFLINE_RATE = 0.5
Economy.OFFLINE_CAP_SECONDS = 2 * 60 * 60

return Economy
