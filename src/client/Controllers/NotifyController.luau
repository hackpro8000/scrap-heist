--!strict
--[[
	NotifyController

	Shows short messages just under the raid strip: server messages from
	Notify.Message ("Not enough scrap", debug command results) and any
	controller that calls NotifyController.show. Each is a slim navy tag
	sized to its text; they stack and fade out on their own. While the raid
	sign hangs under the strip, messages drop below it.

	Public API:
		NotifyController.show(text, color?)
		NotifyController.setTop(y)    -- pixels from the top the stack starts at
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local React = require(ReplicatedStorage.Packages.React)

local Kit = require(script.Parent.Parent.UI.Kit)
local NotifyScreen = require(script.Parent.Parent.UI.Screens.Notify)

local MAX_TOASTS = 3
-- Under the raid strip (14px down, 44px tall) with a 10px gap.
local DEFAULT_TOP = 68

local NotifyController = {}

local root: Kit.Root?
local top = DEFAULT_TOP
local toasts: { NotifyScreen.Toast } = {}
-- Increments per toast so newer toasts sort below older ones.
local toastCount = 0

local function render()
	if not root then
		return
	end
	root.render(React.createElement(NotifyScreen, {
		top = top,
		toasts = table.clone(toasts),
		onGone = function(id: number)
			for index, toast in toasts do
				if toast.id == id then
					table.remove(toasts, index)
					break
				end
			end
			render()
		end,
	}))
end

function NotifyController.setTop(y: number?)
	top = y or DEFAULT_TOP
	render()
end

function NotifyController.show(text: string, color: Color3?)
	toastCount += 1
	table.insert(toasts, { id = toastCount, text = text, color = color })
	if #toasts > MAX_TOASTS then
		table.remove(toasts, 1)
	end
	render()
end

function NotifyController.init()
	root = Kit.mount("Notifications", 20)
	render()
end

function NotifyController.start()
	Notify.Message.OnClientEvent:Connect(function(text: string)
		if type(text) == "string" then
			NotifyController.show(text)
		end
	end)
end

return NotifyController
