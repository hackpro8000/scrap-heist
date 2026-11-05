--!strict
--[[
	RewardsRules

	The daily streak and playtime gift rules, as plain functions over a
	player's saved rewards (profile.rewards). Days are UTC day numbers
	(os.time() // DAY_SECONDS), so everyone's day turns over together.

	Public API:
		RewardsRules.dayOf(time): number
		RewardsRules.daily(rewards, today): DailyState
		RewardsRules.claimDaily(rewards, today): number?        -- streak day claimed
		RewardsRules.rollPlaytime(rewards, today): boolean     -- true when a new day began
		RewardsRules.giftReason(rewards, index): string?       -- why a gift can't be claimed
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)

local RewardsRules = {}

export type SavedRewards = {
	-- Streak day (1-7) of the last daily claim, 0 before the first.
	streakDay: number,
	lastClaimDay: number,
	-- The UTC day playSeconds and giftsClaimed count for.
	playDay: number,
	playSeconds: number,
	giftsClaimed: { [string]: boolean },
}

export type DailyState = {
	claimable: boolean,
	-- The streak day on offer, or the one claimed today.
	day: number,
	-- Earlier days of this run already claimed (shown ticked), 0 to 7.
	claimed: number,
}

function RewardsRules.dayOf(time: number): number
	return time // Rewards.DAY_SECONDS
end

function RewardsRules.daily(rewards: SavedRewards, today: number): DailyState
	local last, streak = rewards.lastClaimDay, rewards.streakDay
	if streak > 0 and last == today then
		return { claimable = false, day = streak, claimed = streak }
	end
	if streak > 0 and last == today - 1 then
		local day = streak % #Rewards.DAILY + 1
		return { claimable = true, day = day, claimed = if day == 1 then 0 else streak }
	end
	return { claimable = true, day = 1, claimed = 0 }
end

-- DUPE-SAFE: stamps today before returning, so a second claim the same
-- day finds nothing claimable.
function RewardsRules.claimDaily(rewards: SavedRewards, today: number): number?
	local state = RewardsRules.daily(rewards, today)
	if not state.claimable then
		return nil
	end
	rewards.streakDay = state.day
	rewards.lastClaimDay = today
	return state.day
end

function RewardsRules.rollPlaytime(rewards: SavedRewards, today: number): boolean
	if rewards.playDay == today then
		return false
	end
	rewards.playDay = today
	rewards.playSeconds = 0
	rewards.giftsClaimed = {}
	return true
end

-- Gifts are keyed by their position as a string: DataStores save tables
-- as JSON, where a sparse number-keyed table doesn't survive.
function RewardsRules.giftReason(rewards: SavedRewards, index: any): string?
	local gift = type(index) == "number" and Rewards.GIFTS[index]
	if not gift then
		return "UnknownGift"
	end
	if rewards.giftsClaimed[tostring(index)] then
		return "AlreadyClaimed"
	end
	if rewards.playSeconds < gift.minutes * 60 then
		return "NotYet"
	end
	return nil
end

return RewardsRules
