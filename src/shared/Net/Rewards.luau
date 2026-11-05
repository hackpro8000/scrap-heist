--!strict
--[[
	Rewards remotes

	Client to server:
		ClaimDaily()
		ClaimGift(index)             -- position in Rewards.GIFTS
		RequestRewards()             -- "send me my rewards state" (on join)

	Server to client:
		RewardsUpdated(state)        -- see RewardsService.stateFor
]]

local Net = require(script.Parent.Net)

local SYSTEM = "Rewards"

return {
	ClaimDaily = Net.event(SYSTEM, "ClaimDaily"),
	ClaimGift = Net.event(SYSTEM, "ClaimGift"),
	RequestRewards = Net.event(SYSTEM, "RequestRewards"),
	RewardsUpdated = Net.event(SYSTEM, "RewardsUpdated"),
}
