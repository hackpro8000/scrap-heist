--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local RaidConfig = Source.require("src/shared/Config/Raid")
local RaidRules = Source.require("src/server/Tycoon/RaidRules")

-- A grab that passes every rule; each test breaks one thing.
local function validGrab(overrides: { [string]: any }?)
	local context = {
		isOwner = false,
		raiderHasYard = true,
		raiderInsideYard = true,
		distance = 4,
		alreadyCarrying = false,
		raidsPaused = false,
		crateParts = 400,
		raiderLevel = 3,
		ownerLevel = 3,
		ownerShieldUntil = 0,
		now = 1000,
	}
	for key, value in overrides or {} do
		context[key] = value
	end

	return context
end

describe("RaidRules.canGrab", function()
	it("allows a fair grab", function()
		expect(RaidRules.canGrab(validGrab())).toBe(nil)
	end)

	it("refuses each broken rule with its reason", function()
		local cases = {
			{ { isOwner = true }, "OwnCrate" },
			{ { raiderHasYard = false }, "NoYard" },
			{ { raidsPaused = true }, "RaidsPaused" },
			{ { raiderInsideYard = false }, "NotInYard" },
			{ { distance = RaidConfig.GRAB_DISTANCE + 1 }, "TooFar" },
			{ { alreadyCarrying = true }, "AlreadyCarrying" },
			{ { ownerShieldUntil = 1001 }, "Shielded" },
			{ { raiderLevel = 3 + RaidConfig.MAX_LEVEL_GAP + 1 }, "LevelGap" },
			{ { crateParts = RaidConfig.MIN_CRATE_PARTS - 1 }, "CrateTooEmpty" },
		}
		for _, case in cases do
			expect(RaidRules.canGrab(validGrab(case[1]))).toBe(case[2])
		end
	end)

	it("lets weaker players raid stronger ones", function()
		expect(RaidRules.canGrab(validGrab({ raiderLevel = 1, ownerLevel = 12 }))).toBe(nil)
	end)

	it("lifts the shield when it expires", function()
		expect(RaidRules.canGrab(validGrab({ ownerShieldUntil = 1000 }))).toBe(nil)
	end)

	it("has text for every reason", function()
		for _, reason in { "OwnCrate", "NoYard", "RaidsPaused", "NotInYard", "TooFar", "AlreadyCarrying" } do
			expect(type(RaidRules.REASON_TEXT[reason])).toBe("string")
		end
	end)
end)

describe("RaidRules.bundleSize", function()
	it("takes a share of the crate within the limits", function()
		expect(RaidRules.bundleSize(400)).toBe(math.floor(400 * RaidConfig.BUNDLE_FRACTION))
		expect(RaidRules.bundleSize(100000)).toBe(RaidConfig.BUNDLE_MAX)
		expect(RaidRules.bundleSize(RaidConfig.BUNDLE_MIN)).toBe(RaidConfig.BUNDLE_MIN)
	end)

	it("never takes more than the crate holds", function()
		expect(RaidRules.bundleSize(5.5)).toBe(5)
	end)

	it("shields for the configured time", function()
		expect(RaidRules.shieldUntil(100)).toBe(100 + RaidConfig.SHIELD_SECONDS)
	end)
end)
