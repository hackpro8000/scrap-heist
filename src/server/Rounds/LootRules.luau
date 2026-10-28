--!strict
--[[
	LootRules

	Storm rewards with no Roblox objects involved: weighted rolls, who gets
	rewarded, and the once-per-round guard. LootService does the granting.

	Random numbers come in as a function returning 0 <= n < 1, so tests can
	pass a fixed sequence and the server passes Random.new():NextNumber.

	Public API:
		LootRules.roll(lootTable, random): { Reward }
		LootRules.topDamage(damageBy, count, minDamage): { any }   -- best first
		LootRules.claim(ledger, playerKey, round): boolean
		LootRules.survivorScrap(round): number
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Config.Items)
local LootConfig = require(ReplicatedStorage.Shared.Config.Loot)

local LootRules = {}

export type Reward = {
	itemId: string,
	count: number,
}

local function pickEntry(entries: { LootConfig.Entry }, random: () -> number): LootConfig.Entry
	local totalWeight = 0
	for _, entry in entries do
		totalWeight += entry.weight
	end

	local pick = random() * totalWeight
	for _, entry in entries do
		pick -= entry.weight
		if pick < 0 then
			return entry
		end
	end

	-- Only reachable through floating point rounding at the very top.
	return entries[#entries]
end

function LootRules.roll(lootTable: LootConfig.Table, random: () -> number): { Reward }
	local rewards: { Reward } = {}
	for _ = 1, lootTable.rolls do
		local entry = pickEntry(lootTable.entries, random)
		local definition = Items.get(entry.itemId)
		local count = 1
		if definition and definition.stackable then
			local low = entry.min or 1
			local high = entry.max or low
			count = low + math.floor(random() * (high - low + 1))
		end
		table.insert(rewards, { itemId = entry.itemId, count = count })
	end

	return rewards
end

function LootRules.topDamage(damageBy: { [any]: number }, count: number, minDamage: number): { any }
	local ranked = {}
	for player, damage in damageBy do
		if damage >= minDamage then
			table.insert(ranked, player)
		end
	end
	table.sort(ranked, function(a, b)
		return damageBy[a] > damageBy[b]
	end)

	while #ranked > count do
		table.remove(ranked)
	end

	return ranked
end

-- DUPE-SAFE: records that this player has been rewarded for this round
-- and returns false if they already were, so loot can't be granted twice
-- for one storm (by a double event, a rejoin or a bug elsewhere).
function LootRules.claim(ledger: { [any]: number }, playerKey: any, round: number): boolean
	if ledger[playerKey] == round then
		return false
	end

	ledger[playerKey] = round
	return true
end

function LootRules.survivorScrap(round: number): number
	return LootConfig.SURVIVOR_SCRAP + LootConfig.SURVIVOR_SCRAP_PER_ROUND * math.max(0, round - 1)
end

return LootRules
