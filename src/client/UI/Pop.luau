--!strict
--[[
	Pop

	Shows a panel with a quick scale-up "pop" (Config/Juice.UI_TWEENS), or
	instantly when tweens are off.

	Public API:
		Pop.show(gui)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Juice = require(ReplicatedStorage.Shared.Config.Juice)

local START_SCALE = 0.85

local Pop = {}

function Pop.show(gui: GuiObject)
	local wasVisible = gui.Visible
	gui.Visible = true
	if wasVisible or not Juice.UI_TWEENS then
		return
	end

	local scale = gui:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = gui
	end

	local uiScale = scale :: UIScale
	uiScale.Scale = START_SCALE
	local tween = TweenInfo.new(Juice.POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(uiScale, tween, { Scale = 1 }):Play()
end

return Pop
