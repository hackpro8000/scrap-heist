--!strict
--[[
	HudController

	The always-on HUD (UI/Screens/Hud): the scrap count and the menu grid
	other controllers add buttons to (Trade, Shop, Rewards, Bag). Scrap
	comes from the player's "Scrap" attribute, which DataService keeps up
	to date.

	Public API:
		HudController.addButton(text, order, onClick)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local Kit = require(script.Parent.Parent.UI.Kit)
local HudScreen = require(script.Parent.Parent.UI.Screens.Hud)

local localPlayer = Players.LocalPlayer

local HudController = {}

local root: Kit.Root
local buttons: { HudScreen.MenuButton } = {}

local function render()
	local scrap = localPlayer:GetAttribute("Scrap")
	root.render(React.createElement(HudScreen, {
		scrap = if type(scrap) == "number" then scrap else nil,
		buttons = buttons,
	}))
end

function HudController.addButton(text: string, order: number, onClick: () -> ())
	table.insert(buttons, { text = text, order = order, onClick = onClick })
	render()
end

function HudController.init()
	root = Kit.mount("Hud")
	render()
end

function HudController.start()
	render()
	localPlayer:GetAttributeChangedSignal("Scrap"):Connect(render)
end

return HudController
