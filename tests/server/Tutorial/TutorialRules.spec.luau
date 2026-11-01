--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local TutorialRules = Source.require("src/server/Tutorial/TutorialRules")

local function stepName(done, phase): string?
	local step = TutorialRules.currentStep(done, phase)
	return if step then step.name else nil
end

describe("TutorialRules", function()
	it("starts a new player on buying a machine", function()
		expect(stepName({}, "Calm")).toBe("BuyMachine")
	end)

	it("moves through the steps in order", function()
		expect(stepName({ BuyMachine = true }, "Calm")).toBe("CollectCrate")
		expect(stepName({ BuyMachine = true, CollectCrate = true }, "Calm")).toBe("RaidTip")
	end)

	it("holds a storm tip until the warning phase", function()
		local done = { BuyMachine = true, CollectCrate = true, RaidTip = true }

		expect(stepName(done, "Calm")).toBe(nil)
		expect(stepName(done, "Warning")).toBe("StormTip")
	end)

	it("shows nothing once everything is done", function()
		local done = { BuyMachine = true, CollectCrate = true, RaidTip = true, StormTip = true }
		expect(stepName(done, "Warning")).toBe(nil)
	end)

	it("only lets the current tip be dismissed", function()
		expect(TutorialRules.canDismiss({}, "Calm", "BuyMachine")).toBe(false)
		expect(TutorialRules.canDismiss({ BuyMachine = true, CollectCrate = true }, "Calm", "RaidTip")).toBe(true)
		expect(TutorialRules.canDismiss({ BuyMachine = true, CollectCrate = true }, "Calm", "StormTip")).toBe(false)
		expect(TutorialRules.canDismiss({}, "Calm", 42)).toBe(false)
	end)
end)
