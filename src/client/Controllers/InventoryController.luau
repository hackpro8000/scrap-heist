--!strict
--[[
	InventoryController

	Keeps the latest inventory snapshot from the server and shows it in a
	simple panel (Bag button or B). The trade window reads the same snapshot
	to list what you can offer.

	Public API:
		InventoryController.getInventory(): Inventory
		InventoryController.changed: Signal(inventory)
		InventoryController.toggle()
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryTypes = require(ReplicatedStorage.Shared.Inventory.InventoryTypes)
local Remotes = require(ReplicatedStorage.Shared.Net.Inventory)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local HudController = require(script.Parent.HudController)
local ItemText = require(script.Parent.Parent.UI.ItemText)
local Pop = require(script.Parent.Parent.UI.Pop)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local InventoryController = {}

InventoryController.changed = Signal.new()

local inventory: InventoryTypes.Inventory = { stacks = {}, uniques = {} }
local panel: Frame
local list: ScrollingFrame

function InventoryController.getInventory(): InventoryTypes.Inventory
	return inventory
end

local function render()
	Widgets.clear(list)

	local order = 0
	local function addLine(text: string, color: Color3)
		order += 1
		local line = Widgets.label(text, {
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
		})
		line.Parent = list
	end

	for _, itemId in ItemText.sortedStackIds(inventory.stacks) do
		addLine(ItemText.stackLine(itemId, inventory.stacks[itemId]), ItemText.color(itemId))
	end
	for guid, item in inventory.uniques do
		-- The short ID shows two copies of the same item are different items.
		addLine(`{ItemText.name(item.itemId)}  #{string.sub(guid, 1, 6)}`, ItemText.color(item.itemId))
	end

	if order == 0 then
		addLine("Empty. Survive a storm to find loot.", Theme.Colors.TextDim)
	end
end

function InventoryController.toggle()
	if panel.Visible then
		panel.Visible = false
	else
		Pop.show(panel)
	end
end

function InventoryController.init()
	local screen = Widgets.screen("Inventory")

	panel = Widgets.panel({
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.6),
	})
	panel.Parent = screen
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(280, 260)
	sizeLimit.MaxSize = Vector2.new(480, 560)
	sizeLimit.Parent = panel

	local title = Widgets.label("Inventory", {
		Font = Theme.Font,
		Size = UDim2.new(1, -50, 0, 32),
	})
	title.Parent = panel

	local close = Widgets.button("X", InventoryController.toggle, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 40, 0, 32),
	})
	close.Parent = panel

	list = Widgets.scrollList({
		Position = UDim2.new(0, 0, 0, 40),
		Size = UDim2.new(1, 0, 1, -40),
	})
	list.Parent = panel

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

	HudController.addButton("Bag", 1, InventoryController.toggle)
	ContextActionService:BindAction("ToggleInventory", function(_action, state, _input)
		if state == Enum.UserInputState.Begin then
			InventoryController.toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.B)
end

return InventoryController
