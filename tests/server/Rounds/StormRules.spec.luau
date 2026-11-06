--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Game = Source.require("src/shared/Config/Game")
local Rounds = Source.require("src/shared/Config/Rounds")
local Storm = Source.require("src/shared/Config/Storm")
local StormRules = Source.require("src/server/Rounds/StormRules")

describe("Rounds config", function()
	it("has a length for every phase", function()
		for _, phase in Rounds.PHASE_ORDER do
			expect(Game.ROUND_DURATIONS[phase] > 0).toBe(true)
		end
	end)

	it("counts the blackout as part of the storm", function()
		expect(Rounds.isStorm("Storm")).toBe(true)
		expect(Rounds.isStorm("Blackout")).toBe(true)
		expect(Rounds.isStorm("Calm")).toBe(false)
		expect(Rounds.isStorm("Warning")).toBe(false)
	end)
end)

describe("StormRules", function()
	it("pays more parts per pickup at higher ranks", function()
		expect(StormRules.partsFor(0)).toBe(Storm.PART_DROP_PARTS)
		expect(StormRules.partsFor(20) > StormRules.partsFor(0)).toBe(true)
	end)

	it("aims most strikes at capsule carriers", function()
		local carriers, others = { "carrier" }, { "a", "b" }
		expect(StormRules.pickTarget(0, 0, carriers, others)).toBe("carrier")
		expect(StormRules.pickTarget(0.99, 0, carriers, others)).toBe("a")
		expect(StormRules.pickTarget(0.99, 0.99, carriers, others)).toBe("b")
	end)

	it("aims at whoever is out when nobody carries, and at nobody on an empty Line", function()
		expect(StormRules.pickTarget(0, 0.5, {}, { "a" })).toBe("a")
		expect(StormRules.pickTarget(0.99, 0, { "carrier" }, {})).toBe("carrier")
		expect(StormRules.pickTarget(0, 0, {}, {})).toBe(nil)
	end)
end)
