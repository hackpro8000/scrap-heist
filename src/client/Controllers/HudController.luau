--!strict
--[[
	HudController

	The always-on HUD: the scrap counter (top left) and a column of menu
	buttons down the left edge that other controllers add to (Bag, Trade).
	Scrap comes from the player's "Scrap" attribute, which DataService
	keeps up to date.

	Public API:
		HudController.addButton(text, order, onClick): TextButton
		HudController.screen: ScreenGui
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Widgets = require(script.Parent.Parent.UI.Widgets)

local localPlayer = Players.LocalPlayer

local HudController = {}

local buttonColumn: Frame
local scrapLabel: TextLabel

function HudController.addButton(text: string, order: number, onClick: () -> ()): TextButton
	local button = Widgets.button(text, onClick, {
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = order,
	})
	button.Parent = buttonColumn

	return button
end

local function refreshScrap()
	local scrap = localPlayer:GetAttribute("Scrap")
	scrapLabel.Text = if type(scrap) == "number" then `Scrap: {scrap}` else "Scrap: ..."
end

function HudController.init()
	local screen = Widgets.screen("Hud")
	HudController.screen = screen

	local scrapPanel = Widgets.panel({
		Position = UDim2.new(0, 12, 0, 12),
		Size = UDim2.new(0, 200, 0, 48),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.2,
	})
	scrapPanel.Parent = screen

	scrapLabel = Widgets.label("Scrap: ...", {
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Font,
		TextColor3 = Theme.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	scrapLabel.Parent = scrapPanel

	buttonColumn = Instance.new("Frame")
	buttonColumn.BackgroundTransparency = 1
	buttonColumn.AnchorPoint = Vector2.new(0, 0.5)
	buttonColumn.Position = UDim2.new(0, 12, 0.5, 0)
	buttonColumn.Size = UDim2.new(0, 110, 0, 200)
	buttonColumn.Parent = screen
	Widgets.list(buttonColumn, nil, 6)
end

function HudController.start()
	refreshScrap()
	localPlayer:GetAttributeChangedSignal("Scrap"):Connect(refreshScrap)
end

return HudController
