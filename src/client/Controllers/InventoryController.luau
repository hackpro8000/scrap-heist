--!strict
--[[
	InventoryController

	Keeps the latest inventory snapshot from the server and shows it in the
	Bag window (Bag button or B): a scrolling grid of slots framed by
	rarity, and a detail card for the selected item. The trade window reads
	the same snapshot to list what you can offer.

	Public API:
		InventoryController.getInventory(): Inventory
		InventoryController.changed: Signal(inventory)
		InventoryController.tradeRequested: Signal()   -- "Trade it" pressed
		InventoryController.toggle()
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryTypes = require(ReplicatedStorage.Shared.Inventory.InventoryTypes)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local React = require(ReplicatedStorage.Packages.React)
local Remotes = require(ReplicatedStorage.Shared.Net.Inventory)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local HudController = require(script.Parent.HudController)
local InventoryScreen = require(script.Parent.Parent.UI.Screens.Inventory)
local ItemText = require(script.Parent.Parent.UI.ItemText)
local Kit = require(script.Parent.Parent.UI.Kit)
local Windows = require(script.Parent.Parent.UI.Windows)

type Entry = InventoryScreen.Entry

local WINDOW = "Bag"

local InventoryController = {}

InventoryController.changed = Signal.new()
InventoryController.tradeRequested = Signal.new()

local inventory: InventoryTypes.Inventory = { stacks = {}, uniques = {} }
local sortByName = false
local selected = 1
local root: Kit.Root

function InventoryController.getInventory(): InventoryTypes.Inventory
	return inventory
end

local function rarityRank(itemId: string): number
	local definition = Items.get(itemId)
	return if definition then table.find(Items.RARITY_ORDER, definition.rarity) or 0 else 0
end

-- One entry per stack and per unique item, rarest first (or by name).
local function entries(): { Entry }
	local list: { Entry } = {}
	for _, itemId in ItemText.sortedStackIds(inventory.stacks) do
		table.insert(list, { itemId = itemId, count = inventory.stacks[itemId] })
	end
	for guid, item in inventory.uniques do
		table.insert(list, { itemId = item.itemId, count = 1, guid = guid })
	end
	table.sort(list, function(a, b)
		if sortByName then
			return ItemText.name(a.itemId) < ItemText.name(b.itemId)
		end
		local rankA, rankB = rarityRank(a.itemId), rarityRank(b.itemId)
		if rankA ~= rankB then
			return rankA > rankB
		end
		if a.itemId ~= b.itemId then
			return a.itemId < b.itemId
		end
		return (a.guid or "") < (b.guid or "")
	end)
	return list
end

local function render()
	local list = entries()
	selected = math.clamp(selected, 1, math.max(#list, 1))
	root.render(React.createElement(InventoryScreen, {
		entries = list,
		selected = selected,
		sortByName = sortByName,
		onSelect = function(index: number)
			selected = index
			render()
		end,
		onSort = function()
			sortByName = not sortByName
			render()
		end,
		onTrade = function()
			Windows.close(WINDOW)
			InventoryController.tradeRequested:fire()
		end,
	}))
end

function InventoryController.toggle()
	Windows.toggle(WINDOW)
end

function InventoryController.init()
	root = Kit.mount("Inventory", 10)
	Windows.opened:connect(function(name: string)
		if name == WINDOW then
			render()
		end
	end)
	render()
end

function InventoryController.start()
	Remotes.InventoryUpdated.OnClientEvent:Connect(function(snapshot: InventoryTypes.Inventory)
		if type(snapshot) ~= "table" then
			return
		end
		inventory = snapshot
		render()
		InventoryController.changed:fire(inventory)
	end)
	Remotes.RequestInventory:FireServer()

	HudController.addButton("Bag", 4, InventoryController.toggle)
	ContextActionService:BindAction("ToggleInventory", function(_action, state, _input)
		if state == Enum.UserInputState.Begin then
			InventoryController.toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.B)
end

return InventoryController
