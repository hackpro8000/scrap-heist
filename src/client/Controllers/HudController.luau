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

local Format = require(ReplicatedStorage.Shared.Util.Format)
local React = require(ReplicatedStorage.Packages.React)

local Kit = require(script.Parent.Parent.UI.Kit)
local HudScreen = require(script.Parent.Parent.UI.Screens.Hud)

local localPlayer = Players.LocalPlayer

local HudController = {}

local root: Kit.Root
local buttons: { HudScreen.MenuButton } = {}

-- "RANK 2 · 1.2K/S · 34 PARTS", once the server has said what they are.
local function statsText(): string?
	local rank = localPlayer:GetAttribute("Rank")
	local income = localPlayer:GetAttribute("Income")
	local parts = localPlayer:GetAttribute("Parts")
	if type(rank) ~= "number" or type(income) ~= "number" or type(parts) ~= "number" then
		return nil
	end

	return `RANK {rank}  ·  {Format.short(income)}/S  ·  {Format.short(parts)} PARTS`
end

local function render()
	local scrap = localPlayer:GetAttribute("Scrap")
	root.render(React.createElement(HudScreen, {
		scrap = if type(scrap) == "number" then scrap else nil,
		stats = statsText(),
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
	for _, name in { "Scrap", "Rank", "Income", "Parts" } do
		localPlayer:GetAttributeChangedSignal(name):Connect(render)
	end
end

return HudController
