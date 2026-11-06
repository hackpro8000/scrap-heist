--!strict
--[[
	Game config

	The top-level knobs for a server: who counts as an admin, how many yards
	there are, how long rounds last and how generous the economy is. The
	detailed tables (Economy, Rounds, Bots, Loot) read their headline values
	from here, so tuning a whole server starts in this file.

	Public API: the constants below.
]]

local Game = {}

-- User IDs allowed to use debug commands and showcase mode outside Studio.
-- In Studio everyone is allowed.
Game.ADMIN_USER_IDS = {} :: { number }

-- Yards per server. The map has room for eight.
Game.YARD_COUNT = 8

-- Seconds for each round phase.
Game.ROUND_DURATIONS = {
	Calm = 240,
	Warning = 20,
	Storm = 90,
	Blackout = 30,
}

-- Multiplies every junkrot's output.
Game.INCOME_MULTIPLIER = 1
-- Multiplies every capsule's price.
Game.COST_MULTIPLIER = 1

return Game
