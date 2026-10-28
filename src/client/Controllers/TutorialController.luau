--!strict
--[[
	TutorialController

	Shows the current tutorial prompt from the server near the bottom of the
	screen. Tips get a "Got it" button; action steps disappear by
	themselves once the server sees the player do the thing.

	Public API: none.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Tutorial)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Widgets = require(script.Parent.Parent.UI.Widgets)

local TutorialController = {}

local panel: Frame
local textLabel: TextLabel
local gotItButton: TextButton
local currentStep: string? = nil

local function show(stepName: string?, kind: string?, text: string?)
	currentStep = stepName
	panel.Visible = stepName ~= nil
	if not stepName then
		return
	end

	textLabel.Text = text or ""
	gotItButton.Visible = kind == "Tip"
	textLabel.Size = if kind == "Tip" then UDim2.new(1, -110, 1, 0) else UDim2.fromScale(1, 1)
end

function TutorialController.init()
	local screen = Widgets.screen("Tutorial")

	panel = Widgets.panel({
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -160),
		Size = UDim2.new(0.6, 0, 0, 64),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.15,
	})
	panel.Parent = screen
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(300, 64)
	sizeLimit.MaxSize = Vector2.new(700, 64)
	sizeLimit.Parent = panel

	textLabel = Widgets.label("", {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Theme.Colors.Accent,
		TextWrapped = true,
	})
	textLabel.Parent = panel

	gotItButton = Widgets.button("Got it", function()
		if currentStep then
			Remotes.DismissTip:FireServer(currentStep)
		end
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 100, 0, 44),
		Visible = false,
	})
	gotItButton.Parent = panel
end

function TutorialController.start()
	Remotes.Step.OnClientEvent:Connect(show)
end

return TutorialController
