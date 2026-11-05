--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Economy = Source.require("src/shared/Config/Economy")
local Game = Source.require("src/shared/Config/Game")
local MachineRules = Source.require("src/server/Tycoon/MachineRules")

-- The specs assume default multipliers; if tuning changes them, the
-- expected numbers below still read straight from config.
local INCOME = Game.INCOME_MULTIPLIER
local COST = Game.COST_MULTIPLIER

describe("MachineRules costs", function()
	it("prices each pad from config", function()
		for _, padName in Economy.PADS do
			expect(MachineRules.buyCost(padName)).toBe(math.ceil(Economy.BUY_COSTS[padName] * COST))
		end
		expect(MachineRules.buyCost("Pad99")).toBe(nil)
	end)

	it("prices upgrades and stops at max level", function()
		local base = Economy.BUY_COSTS.Pad1
		expect(MachineRules.upgradeCost("Pad1", 1)).toBe(math.ceil(base * Economy.UPGRADE_COST_FACTORS[2] * COST))
		expect(MachineRules.upgradeCost("Pad1", Economy.MAX_LEVEL)).toBe(nil)
	end)

	it("makes later pads cost more", function()
		for index = 2, #Economy.PADS do
			local previous = MachineRules.buyCost(Economy.PADS[index - 1])
			expect(MachineRules.buyCost(Economy.PADS[index]) > previous).toBe(true)
		end
	end)

	it("lets a new player afford the first machine", function()
		expect(Economy.STARTING_SCRAP >= MachineRules.buyCost(Economy.PADS[1])).toBe(true)
	end)
end)

describe("MachineRules production", function()
	it("sums income from every owned machine", function()
		local machines = { Pad1 = { level = 1 }, Pad2 = { level = 3 } }

		expect(MachineRules.incomePerSecond(machines)).toBe((Economy.LEVEL_RATES[1] + Economy.LEVEL_RATES[3]) * INCOME)
	end)

	it("ignores machines saved on pads that no longer exist", function()
		expect(MachineRules.incomePerSecond({ OldPad = { level = 3 } })).toBe(0)
	end)

	it("fills the crate and stops at capacity", function()
		local machines = { Pad1 = { level = 1 } }

		expect(MachineRules.produce(0, machines, 10)).toBe(10 * Economy.LEVEL_RATES[1] * INCOME)
		expect(MachineRules.produce(Economy.CRATE_CAPACITY - 1, machines, 1000)).toBe(Economy.CRATE_CAPACITY)
	end)

	it("pays capped, reduced offline earnings", function()
		local machines = { Pad1 = { level = 2 } }
		local perSecond = Economy.LEVEL_RATES[2] * INCOME * Economy.OFFLINE_RATE * Economy.PART_VALUE

		expect(MachineRules.offlineEarnings(machines, 100)).toBe(math.floor(perSecond * 100))
		expect(MachineRules.offlineEarnings(machines, 10 ^ 9)).toBe(math.floor(perSecond * Economy.OFFLINE_CAP_SECONDS))
		expect(MachineRules.offlineEarnings(machines, -50)).toBe(0)
		expect(MachineRules.offlineEarnings({}, 1000)).toBe(0)
	end)

	it("adds machine levels into a yard level", function()
		expect(MachineRules.yardLevel({ Pad1 = { level = 3 }, Pad2 = { level = 1 } })).toBe(4)
		expect(MachineRules.yardLevel({})).toBe(0)
	end)

	it("reports crate fill between 0 and 1", function()
		expect(MachineRules.crateFill(0)).toBe(0)
		expect(MachineRules.crateFill(Economy.CRATE_CAPACITY / 2)).toBe(0.5)
		expect(MachineRules.crateFill(Economy.CRATE_CAPACITY * 2)).toBe(1)
	end)
end)
