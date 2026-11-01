--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local LootConfig = Source.require("src/shared/Config/Loot")
local LootRules = Source.require("src/server/Rounds/LootRules")
local Items = Source.require("src/shared/Config/Items")

-- Returns the given numbers in order, so a roll lands where the test wants.
local function sequence(...)
	local values = { ... }
	local index = 0
	return function(): number
		index += 1
		return values[index] or 0
	end
end

local TABLE = {
	rolls = 1,
	entries = {
		{ itemId = "RustyGear", weight = 3, min = 2, max = 4 },
		{ itemId = "GoldenCog", weight = 1 },
	},
}

describe("LootRules.roll", function()
	it("picks entries by weight", function()
		-- Total weight 4: below 0.75 is RustyGear, from 0.75 GoldenCog.
		expect(LootRules.roll(TABLE, sequence(0.74, 0))[1].itemId).toBe("RustyGear")
		expect(LootRules.roll(TABLE, sequence(0.75))[1].itemId).toBe("GoldenCog")
	end)

	it("rolls stack sizes inside the range, uniques as one", function()
		expect(LootRules.roll(TABLE, sequence(0, 0))[1].count).toBe(2)
		expect(LootRules.roll(TABLE, sequence(0, 0.999))[1].count).toBe(4)
		expect(LootRules.roll(TABLE, sequence(0.9))[1].count).toBe(1)
	end)

	it("matches the weights over many rolls", function()
		math.randomseed(7)
		local cogs = 0
		local rolls = 20000
		for _ = 1, rolls do
			if LootRules.roll(TABLE, math.random)[1].itemId == "GoldenCog" then
				cogs += 1
			end
		end

		expect(math.abs(cogs / rolls - 0.25) < 0.02).toBe(true)
	end)

	it("only lists real items in the config tables", function()
		for _, lootTable in LootConfig.Tables do
			for _, entry in lootTable.entries do
				expect(Items.get(entry.itemId) ~= nil).toBe(true)
			end
		end
	end)
end)

describe("LootRules rewards", function()
	it("ranks top damage, skipping low damage, best first", function()
		local damage = { ana = 300, ben = 40, cat = 120, dan = 500 }

		expect(LootRules.topDamage(damage, 2, 50)).toEqual({ "dan", "ana" })
		expect(LootRules.topDamage(damage, 10, 50)).toEqual({ "dan", "ana", "cat" })
	end)

	it("rewards each player once per round", function()
		local ledger = {}

		expect(LootRules.claim(ledger, 123, 4)).toBe(true)
		expect(LootRules.claim(ledger, 123, 4)).toBe(false)
		expect(LootRules.claim(ledger, 456, 4)).toBe(true)
		expect(LootRules.claim(ledger, 123, 5)).toBe(true)
	end)

	it("grows survivor scrap with the round", function()
		expect(LootRules.survivorScrap(1)).toBe(LootConfig.SURVIVOR_SCRAP)
		expect(LootRules.survivorScrap(3)).toBe(LootConfig.SURVIVOR_SCRAP + 2 * LootConfig.SURVIVOR_SCRAP_PER_ROUND)
	end)
end)
