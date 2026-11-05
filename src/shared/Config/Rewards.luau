--!strict
--[[
	Rewards config

	Daily streak: one claim per UTC day. Claiming on the day after your last
	claim moves you a day along the streak; miss a day and it starts over at
	day 1. After day 7 it goes round again.

	Playtime gifts: play for so many minutes in a UTC day and the gift can be
	claimed. Playtime and claimed gifts reset at the start of each UTC day.
]]

local Rewards = {}

export type Reward = {
	-- Scrap paid into the balance, or an item into the bag.
	scrap: number?,
	itemId: string?,
	count: number?,
}

Rewards.DAILY = {
	{ scrap = 50 },
	{ itemId = "RustyGear", count = 5 },
	{ scrap = 100 },
	{ itemId = "CopperCoil", count = 3 },
	{ scrap = 250 },
	{ itemId = "CircuitBoard", count = 1 },
	{ itemId = "GoldenCog", count = 1 },
} :: { Reward }

export type Gift = Reward & { minutes: number }

Rewards.GIFTS = {
	{ minutes = 10, itemId = "OldBattery", count = 2 },
	{ minutes = 30, itemId = "ServoMotor", count = 1 },
	{ minutes = 60, itemId = "ReactorCore", count = 1 },
} :: { Gift }

Rewards.DAY_SECONDS = 24 * 60 * 60

return Rewards
