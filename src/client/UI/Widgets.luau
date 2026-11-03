--!strict
--[[
	Widgets

	Tiny builders for the code-built placeholder UI, so every screen shares
	the same look from Config/Theme. Each returns the Instance it made;
	callers set Position, Size and Parent like any GuiObject.

	Text uses TextScaled with a size cap (UITextSizeConstraint) so labels
	shrink to fit on phones but don't balloon on big monitors.

	Public API:
		Widgets.screen(name): ScreenGui
		Widgets.panel(props?): Frame
		Widgets.label(text, props?): TextLabel
		Widgets.button(text, onClick, props?): TextButton
		Widgets.list(parent, direction?, padding?): UIListLayout
		Widgets.scrollList(props?): ScrollingFrame   -- vertical list that grows to fit
		Widgets.clear(container)                     -- remove GuiObjects, keep layouts
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Widgets = {}

export type Props = { [string]: any }

local function applyProps(instance: Instance, props: Props?)
	if not props then
		return
	end
	for key, value in props do
		(instance :: any)[key] = value
	end
end

local function round(instance: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius
	corner.Parent = instance
end

local function capTextSize(instance: GuiObject, maxSize: number)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize
	constraint.MinTextSize = math.min(10, maxSize)
	constraint.Parent = instance
end

function Widgets.screen(name: string): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = name
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	return screen
end

function Widgets.panel(props: Props?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Theme.Colors.Panel
	frame.BorderSizePixel = 0
	round(frame)

	local padding = Instance.new("UIPadding")
	local inset = UDim.new(0, Theme.Padding)
	padding.PaddingTop, padding.PaddingBottom = inset, inset
	padding.PaddingLeft, padding.PaddingRight = inset, inset
	padding.Parent = frame

	applyProps(frame, props)
	return frame
end

function Widgets.label(text: string, props: Props?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Theme.Colors.Text
	label.Font = Theme.BodyFont
	label.TextScaled = true
	label.Size = UDim2.new(1, 0, 0, Theme.TextSize.Body + 6)
	capTextSize(label, Theme.TextSize.Body)

	applyProps(label, props)
	return label
end

function Widgets.button(text: string, onClick: () -> (), props: Props?): TextButton
	local button = Instance.new("TextButton")
	button.Text = text
	button.TextColor3 = Theme.Colors.Text
	button.BackgroundColor3 = Theme.Colors.PanelLight
	button.Font = Theme.Font
	button.TextScaled = true
	button.AutoButtonColor = true
	-- 44 px is the smallest comfortable touch target on phones.
	button.Size = UDim2.new(1, 0, 0, 44)
	round(button)
	capTextSize(button, Theme.TextSize.Body)
	button.Activated:Connect(onClick)

	applyProps(button, props)
	return button
end

function Widgets.list(parent: Instance, direction: Enum.FillDirection?, padding: number?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction or Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, padding or Theme.Padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent

	return layout
end

function Widgets.scrollList(props: Props?): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.BackgroundColor3 = Theme.Colors.Background
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 6
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	round(frame)
	Widgets.list(frame, nil, 4)

	applyProps(frame, props)
	return frame
end

function Widgets.clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return Widgets
