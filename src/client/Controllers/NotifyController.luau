--!strict
--[[
	NotifyController

	Shows short toast messages at the top of the screen: server messages
	from Notify.Message ("Not enough scrap", debug command results) and any
	controller that calls NotifyController.show. Toasts stack and fade out
	on their own.

	Public API:
		NotifyController.show(text, color?)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Widgets = require(script.Parent.Parent.UI.Widgets)

local TOAST_SECONDS = 3
local FADE_SECONDS = 0.4
local MAX_TOASTS = 4

local NotifyController = {}

local container: Frame
-- Increments per toast so newer toasts sort below older ones.
local toastCount = 0

function NotifyController.show(text: string, color: Color3?)
	if not container then
		return
	end

	local toasts: { TextLabel } = {}
	for _, child in container:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(toasts, child)
		end
	end
	if #toasts >= MAX_TOASTS then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end

	toastCount += 1
	local toast = Widgets.label(text, {
		BackgroundTransparency = 0.2,
		BackgroundColor3 = Theme.Colors.Background,
		TextColor3 = color or Theme.Colors.Text,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = toastCount,
	})
	toast.Parent = container

	task.delay(TOAST_SECONDS, function()
		local fade = TweenInfo.new(FADE_SECONDS)
		TweenService:Create(toast, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.wait(FADE_SECONDS)
		toast:Destroy()
	end)
end

function NotifyController.init()
	local screen = Widgets.screen("Notifications")
	screen.DisplayOrder = 10

	container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Position = UDim2.new(0.5, 0, 0, 60)
	container.Size = UDim2.new(0.5, 0, 0.4, 0)
	container.Parent = screen
	Widgets.list(container, nil, 4)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(260, 0)
	sizeLimit.MaxSize = Vector2.new(520, math.huge)
	sizeLimit.Parent = container
end

function NotifyController.start()
	Notify.Message.OnClientEvent:Connect(function(text: string)
		if type(text) == "string" then
			NotifyController.show(text)
		end
	end)
end

return NotifyController
