--!strict
--[[
	ItemText

	How items read in the UI: display names and rarity colors, shared by
	the inventory, trade and loot screens.

	Public API:
		ItemText.name(itemId): string
		ItemText.color(itemId): Color3
		ItemText.stackLine(itemId, count): string    -- "Rusty Gear x12"
		ItemText.sortedStackIds(stacks): { string }  -- rarest first, then by name
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Config.Items)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local ItemText = {}

function ItemText.name(itemId: string): string
	local definition = Items.get(itemId)
	return if definition then definition.displayName else itemId
end

function ItemText.color(itemId: string): Color3
	local definition = Items.get(itemId)
	return if definition then Theme.RarityColors[definition.rarity] else Theme.Colors.TextDim
end

function ItemText.stackLine(itemId: string, count: number): string
	return `{ItemText.name(itemId)} x{count}`
end

local function rarityRank(itemId: string): number
	local definition = Items.get(itemId)
	return if definition then table.find(Items.RARITY_ORDER, definition.rarity) or 0 else 0
end

function ItemText.sortedStackIds(stacks: { [string]: any }): { string }
	local ids = {}
	for itemId in stacks do
		table.insert(ids, itemId)
	end
	table.sort(ids, function(a, b)
		local rankA, rankB = rarityRank(a), rarityRank(b)
		if rankA ~= rankB then
			return rankA > rankB
		end
		return a < b
	end)

	return ids
end

return ItemText
