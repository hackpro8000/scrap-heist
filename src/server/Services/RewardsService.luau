--!strict
--[[
	RewardsService

	The daily streak and playtime gifts (Config/Rewards, rules in
	Rewards/RewardsRules). Playtime is counted on the server while the
	player is in game, in profile.rewards, and starts over each UTC day.

	The client gets a snapshot whenever something changes and counts the
	playtime on by itself between snapshots.

	Public API: none (driven by its remotes).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Config.Items)
local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local Remotes = require(ReplicatedStorage.Shared.Net.Rewards)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)
local RewardsRules = require(script.Parent.Parent.Rewards.RewardsRules)

local SYSTEM = "Rewards"
local CLAIM_RATE = 2
local REQUEST_RATE = 1
local TICK_SECONDS = 5

local RewardsService = {}

local function today(): number
	return RewardsRules.dayOf(os.time())
end

-- What the rewards window shows. `at` is when playSeconds was counted, so
-- the client can keep counting from there.
local function stateFor(player: Player): { [string]: any }?
	local data = DataService.getData(player)
	if not data then
		return nil
	end
	local day = today()
	RewardsRules.rollPlaytime(data.rewards, day)
	local claimed = {}
	for index in Rewards.GIFTS do
		claimed[index] = data.rewards.giftsClaimed[tostring(index)] == true
	end
	return {
		daily = RewardsRules.daily(data.rewards, day),
		playSeconds = data.rewards.playSeconds,
		giftsClaimed = claimed,
		at = os.time(),
		nextDayAt = (day + 1) * Rewards.DAY_SECONDS,
	}
end

local function sendState(player: Player)
	local state = stateFor(player)
	if state then
		Remotes.RewardsUpdated:FireClient(player, state)
	end
end

local function pay(player: Player, reward: Rewards.Reward): string
	if reward.scrap then
		DataService.addScrap(player, reward.scrap)
		return `+{reward.scrap} scrap`
	end
	local itemId = reward.itemId :: string
	local count = reward.count or 1
	InventoryService.grant(player, itemId, count)
	local definition = Items.get(itemId)
	return `+{count} {if definition then definition.displayName else itemId}`
end

local function onClaimDaily(player: Player): string?
	local data = DataService.getData(player)
	if not data then
		return "NotLoaded"
	end
	local day = RewardsRules.claimDaily(data.rewards, today())
	if not day then
		return "AlreadyClaimed"
	end
	local text = pay(player, Rewards.DAILY[day])
	Notify.Message:FireClient(player, `Day {day} reward: {text}`)
	Notify.Sound:FireClient(player, "Collect")
	sendState(player)
	return nil
end

local function onClaimGift(player: Player, index: any): string?
	local data = DataService.getData(player)
	if not data then
		return "NotLoaded"
	end
	RewardsRules.rollPlaytime(data.rewards, today())
	local reason = RewardsRules.giftReason(data.rewards, index)
	if reason then
		return reason
	end
	-- DUPE-SAFE: marked claimed before paying, so a repeat finds it claimed.
	data.rewards.giftsClaimed[tostring(index)] = true
	local text = pay(player, Rewards.GIFTS[index])
	Notify.Message:FireClient(player, `Playtime gift: {text}`)
	Notify.Sound:FireClient(player, "Collect")
	sendState(player)
	return nil
end

-- Adds playtime for everyone in game; a new UTC day resets it and tells
-- the client.
local function tick()
	local day = today()
	for _, player in Players:GetPlayers() do
		local data = DataService.getData(player)
		if data then
			local rolled = RewardsRules.rollPlaytime(data.rewards, day)
			data.rewards.playSeconds += TICK_SECONDS
			if rolled then
				sendState(player)
			end
		end
	end
end

function RewardsService.init() end

function RewardsService.start()
	RemoteGuard.listen(SYSTEM, Remotes.ClaimDaily, CLAIM_RATE, onClaimDaily)
	RemoteGuard.listen(SYSTEM, Remotes.ClaimGift, CLAIM_RATE, onClaimGift)
	RemoteGuard.listen(SYSTEM, Remotes.RequestRewards, REQUEST_RATE, function(player: Player)
		sendState(player)
		return nil
	end)
	DataService.forEachLoaded(function(player)
		sendState(player)
	end)
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			tick()
		end
	end)
end

return RewardsService
