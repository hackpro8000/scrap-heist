--!strict
--[[
	PromptController

	Draws every ProximityPrompt (the server sets them to Custom style) as a
	cream kit card floating over what it acts on (UI/Screens/PromptCard),
	popping in when shown and shrinking away when hidden.

	Roblox still reads the key and gamepad input itself; the card is only
	what the prompt looks like, plus a tap target.

	Public API: none.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local PromptCard = require(script.Parent.Parent.UI.Screens.PromptCard)

type Shown = { inputType: Enum.ProximityPromptInputType, closing: boolean, key: number }

local PromptController = {}

local shown: { [ProximityPrompt]: Shown } = {}
local root: any
-- A fresh key per showing, so a prompt shown again while it shrinks away
-- pops in as a new card.
local showings = 0

local function render()
	local children = {}
	for prompt, entry in shown do
		children[`Prompt{entry.key}`] = React.createElement(PromptCard, {
			prompt = prompt,
			inputType = entry.inputType,
			closing = entry.closing,
			onGone = function()
				if shown[prompt] == entry then
					shown[prompt] = nil
					render()
				end
			end,
		})
	end
	root:render(React.createElement(React.Fragment, nil, children))
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return
	end
	showings += 1
	shown[prompt] = { inputType = inputType, closing = false, key = showings }
	render()
end

local function hide(prompt: ProximityPrompt)
	local entry = shown[prompt]
	if entry then
		entry.closing = true
		render()
	end
end

function PromptController.init()
	-- Billboards can't live in a ScreenGui, so the cards get a folder.
	local folder = Instance.new("Folder")
	folder.Name = "PromptCards"
	folder.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	root = ReactRoblox.createLegacyRoot(folder)
end

function PromptController.start()
	ProximityPromptService.PromptShown:Connect(show)
	ProximityPromptService.PromptHidden:Connect(hide)
end

return PromptController
