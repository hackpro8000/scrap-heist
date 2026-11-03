--!strict
--[[
	Loot config

	Weighted loot tables for storm rewards. Every survivor rolls the
	Survivor table; the top damage dealers against bots also roll the
	TopDamage table. Each entry's chance is its weight divided by the
	table's total weight.
]]

local Loot = {}

export type Entry = {
	itemId: string,
	weight: number,
	-- Stack size range for stackable items; uniques always give one.
	min: number?,
	max: number?,
}

export type Table = {
	rolls: number,
	entries: { Entry },
}

Loot.Tables = {
	Survivor = {
		rolls = 2,
		entries = {
			{ itemId = "RustyGear", weight = 40, min = 3, max = 6 },
			{ itemId = "BentBolt", weight = 30, min = 3, max = 6 },
			{ itemId = "CopperCoil", weight = 15, min = 1, max = 3 },
			{ itemId = "OldBattery", weight = 10, min = 1, max = 2 },
			{ itemId = "CircuitBoard", weight = 3 },
			{ itemId = "ServoMotor", weight = 2 },
		},
	},
	TopDamage = {
		rolls = 1,
		entries = {
			{ itemId = "CircuitBoard", weight = 40 },
			{ itemId = "ServoMotor", weight = 40 },
			{ itemId = "ReactorCore", weight = 10 },
			{ itemId = "GoldenCog", weight = 10 },
		},
	},
} :: { [string]: Table }

-- How many of the top damage dealers get the TopDamage roll.
Loot.TOP_DAMAGE_COUNT = 3
-- Damage against bots needed to place in the top damage list at all.
Loot.MIN_TOP_DAMAGE = 50

-- Scrap every survivor gets, plus a bonus per round number.
Loot.SURVIVOR_SCRAP = 100
Loot.SURVIVOR_SCRAP_PER_ROUND = 25

return Loot
