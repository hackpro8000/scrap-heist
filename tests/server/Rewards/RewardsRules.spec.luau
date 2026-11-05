--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local RewardsRules = Source.require("src/server/Rewards/RewardsRules")

local function saved(streakDay: number, lastClaimDay: number)
	return { streakDay = streakDay, lastClaimDay = lastClaimDay, playDay = 0, playSeconds = 0, giftsClaimed = {} }
end

describe("RewardsRules daily streak", function()
	it("offers day 1 to a new player", function()
		local state = RewardsRules.daily(saved(0, 0), 100)
		expect(state.claimable).toBe(true)
		expect(state.day).toBe(1)
		expect(state.claimed).toBe(0)
	end)

	it("moves a day along when claimed the day after", function()
		local state = RewardsRules.daily(saved(3, 99), 100)
		expect(state.day).toBe(4)
		expect(state.claimed).toBe(3)
	end)

	it("starts over after a missed day", function()
		expect(RewardsRules.daily(saved(5, 97), 100).day).toBe(1)
	end)

	it("goes round again after day 7", function()
		local state = RewardsRules.daily(saved(7, 99), 100)
		expect(state.day).toBe(1)
		expect(state.claimed).toBe(0)
	end)

	it("claims once a day", function()
		local rewards = saved(2, 99)
		expect(RewardsRules.claimDaily(rewards, 100)).toBe(3)
		expect(RewardsRules.claimDaily(rewards, 100)).toBe(nil)
		local state = RewardsRules.daily(rewards, 100)
		expect(state.claimable).toBe(false)
		expect(state.day).toBe(3)
	end)
end)

describe("RewardsRules playtime gifts", function()
	it("resets playtime and gifts on a new day", function()
		local rewards = saved(0, 0)
		rewards.playDay, rewards.playSeconds, rewards.giftsClaimed = 99, 4000, { ["1"] = true }
		expect(RewardsRules.rollPlaytime(rewards, 100)).toBe(true)
		expect(rewards.playSeconds).toBe(0)
		expect(rewards.giftsClaimed["1"]).toBe(nil)
		expect(RewardsRules.rollPlaytime(rewards, 100)).toBe(false)
	end)

	it("opens a gift once its minutes are played, once", function()
		local rewards = saved(0, 0)
		rewards.playSeconds = 9 * 60
		expect(RewardsRules.giftReason(rewards, 1)).toBe("NotYet")
		rewards.playSeconds = 10 * 60
		expect(RewardsRules.giftReason(rewards, 1)).toBe(nil)
		rewards.giftsClaimed["1"] = true
		expect(RewardsRules.giftReason(rewards, 1)).toBe("AlreadyClaimed")
	end)

	it("refuses gifts that don't exist", function()
		expect(RewardsRules.giftReason(saved(0, 0), 99)).toBe("UnknownGift")
		expect(RewardsRules.giftReason(saved(0, 0), "1")).toBe("UnknownGift")
	end)
end)
