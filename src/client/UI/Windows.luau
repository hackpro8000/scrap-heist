--!strict
--[[
	Windows

	Which windows are open. Only one window is open at a time: opening
	another closes the first, except a modal window (the trade window),
	which stays open under the next. The world blurs while any is open.

	Public API:
		Windows.open(name, modal?)
		Windows.close(name)
		Windows.toggle(name)
		Windows.isOpen(name): boolean
		Windows.useOpen(name): boolean      -- React hook, re-renders on change
		Windows.opened: Signal(name)
		Windows.closed: Signal(name)
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local BLUR_SIZE = 10

local Windows = {}

Windows.opened = Signal.new()
Windows.closed = Signal.new()

local open: { [string]: boolean } = {}
local modal: { [string]: boolean } = {}
local blur: BlurEffect? = nil

local function updateBlur()
	if not blur then
		local effect = Instance.new("BlurEffect")
		effect.Name = "WindowBlur"
		effect.Size = 0
		effect.Parent = Lighting
		blur = effect
	end
	local any = next(open) ~= nil
	TweenService:Create(blur :: BlurEffect, TweenInfo.new(0.15), { Size = if any then BLUR_SIZE else 0 }):Play()
end

function Windows.isOpen(name: string): boolean
	return open[name] == true
end

function Windows.close(name: string)
	if not open[name] then
		return
	end
	open[name] = nil
	modal[name] = nil
	updateBlur()
	Windows.closed:fire(name)
end

function Windows.open(name: string, isModal: boolean?)
	if open[name] then
		return
	end
	if not isModal then
		for other in open do
			if not modal[other] then
				Windows.close(other)
			end
		end
	end
	open[name] = true
	modal[name] = isModal == true
	updateBlur()
	Windows.opened:fire(name)
end

function Windows.toggle(name: string)
	if open[name] then
		Windows.close(name)
	else
		Windows.open(name)
	end
end

function Windows.useOpen(name: string): boolean
	local isOpen, setOpen = React.useState(open[name] == true)
	React.useEffect(function()
		setOpen(open[name] == true)
		local function sync(changed: string)
			if changed == name then
				setOpen(open[name] == true)
			end
		end
		local a = Windows.opened:connect(sync)
		local b = Windows.closed:connect(sync)
		return function()
			a:disconnect()
			b:disconnect()
		end
	end, { name })
	return isOpen
end

return Windows
