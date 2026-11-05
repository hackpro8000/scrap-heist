--!strict
--[[
	TutorialController

	Shows the current tutorial prompt from the server on a slim cream strip
	just above the health bar: the step number, the tip, and a "Got it"
	button for tips. Action steps disappear by themselves once the server
	sees the player do the thing.

	Public API: none.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Remotes = require(ReplicatedStorage.Shared.Net.Tutorial)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)

local Kit = require(script.Parent.Parent.UI.Kit)
local TutorialScreen = require(script.Parent.Parent.UI.Screens.Tutorial)

local TutorialController = {}

local root: Kit.Root

local function stepNumber(stepName: string): number
	for index, step in Tutorial.STEPS do
		if step.name == stepName then
			return index
		end
	end
	return 0
end

local function show(stepName: string?, kind: string?, text: string?)
	root.render(React.createElement(TutorialScreen, {
		step = if stepName then stepNumber(stepName) else 0,
		steps = #Tutorial.STEPS,
		text = text or "",
		isTip = kind == "Tip",
		onGotIt = function()
			if stepName then
				Remotes.DismissTip:FireServer(stepName)
			end
		end,
	}))
end

function TutorialController.init()
	root = Kit.mount("Tutorial")
	show(nil)
end

function TutorialController.start()
	Remotes.Step.OnClientEvent:Connect(show)
end

return TutorialController
