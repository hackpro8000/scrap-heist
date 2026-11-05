--!strict
--[[
	LootService

	Storm rewards. During a storm it tallies damage each player deals to
	bots; when the storm ends it rewards:
	- every survivor: a Survivor loot roll plus scrap that grows each round
	- the top damage dealers: an extra TopDamage roll (the rare stuff)

	Rolls use weighted tables from Config/Loot (Rounds/LootRules). Items are
	created only here on the server, through InventoryService, so rare
	drops become unique items with their own GUIDs.

	Each player is rewarded at most once per round (LootRules.claim), even
	if the storm-end event somehow fired twice.

	Every player gets a results message, so non-survivors see they missed
	out rather than nothing at all.

	Public API: none (driven by RoundService and CombatService signals).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Config.Items)
local LootConfig = require(ReplicatedStorage.Shared.Config.Loot)
local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local Remotes = require(ReplicatedStorage.Shared.Net.Round)

local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local LootRules = require(script.Parent.Parent.Rounds.LootRules)
local RoundService = require(script.Parent.RoundService)
local ShopService = require(script.Parent.ShopService)

local LootService = {}

local damageBy: { [Player]: number } = {}
-- Last round each user ID was rewarded for.
local rewardedRound: { [number]: number } = {}
local random = Random.new()

local function nextNumber(): number
	return random:NextNumber()
end

local function announceRare(player: Player, itemId: string)
	local definition = Items.get(itemId)
	if definition and (definition.rarity == "Rare" or definition.rarity == "Legendary") then
		Notify.Message:FireAllClients(`{player.DisplayName} found a {definition.displayName}!`)
	end
end

local function reward(player: Player, survived: boolean, topRank: number?, stormRound: number)
	-- DUPE-SAFE: one reward per player per round, whatever calls this.
	if not LootRules.claim(rewardedRound, player.UserId, stormRound) then
		return
	end

	local data = DataService.getData(player)
	if not data then
		return
	end

	local rewards = {}
	local scrap = 0
	if survived then
		-- The Storm Luck pass rolls the survivor table twice.
		local rolls = if ShopService.hasPass(player, "StormLuck") then 2 else 1
		for _ = 1, rolls do
			for _, item in LootRules.roll(LootConfig.Tables.Survivor, nextNumber) do
				table.insert(rewards, item)
			end
		end
		scrap = LootRules.survivorScrap(stormRound)
		data.stats.stormsSurvived += 1
	end
	if topRank then
		for _, item in LootRules.roll(LootConfig.Tables.TopDamage, nextNumber) do
			table.insert(rewards, item)
		end
	end

	for _, item in rewards do
		if InventoryService.grant(player, item.itemId, item.count) then
			announceRare(player, item.itemId)
		end
	end
	if scrap > 0 then
		DataService.addScrap(player, scrap)
	end

	Remotes.RoundResults:FireClient(player, {
		survived = survived,
		topRank = topRank,
		scrap = scrap,
		rewards = rewards,
		damage = math.floor(damageBy[player] or 0),
	})
end

local function onStormEnded(survivors: { Player }, stormRound: number)
	local top = LootRules.topDamage(damageBy, LootConfig.TOP_DAMAGE_COUNT, LootConfig.MIN_TOP_DAMAGE)

	for _, player in Players:GetPlayers() do
		local survived = table.find(survivors, player) ~= nil
		local topRank = table.find(top, player)
		if survived or topRank then
			reward(player, survived, topRank, stormRound)
		else
			Remotes.RoundResults:FireClient(player, {
				survived = false,
				scrap = 0,
				rewards = {},
				damage = math.floor(damageBy[player] or 0),
			})
		end
	end

	damageBy = {}
end

function LootService.init() end

function LootService.start()
	CombatService.hitLanded:connect(function(attackerModel: Model, targetModel: Model, result)
		if RoundService.getPhase() ~= "Storm" or not targetModel:GetAttribute("IsBot") then
			return
		end
		local player = Players:GetPlayerFromCharacter(attackerModel)
		if player then
			damageBy[player] = (damageBy[player] or 0) + result.damage
		end
	end)

	RoundService.phaseChanged:connect(function(phase)
		if phase == "Storm" then
			damageBy = {}
		end
	end)
	RoundService.stormEnded:connect(onStormEnded)

	Players.PlayerRemoving:Connect(function(player)
		damageBy[player] = nil
	end)
end

return LootService
