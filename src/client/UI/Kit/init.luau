--!strict
--[[
	Kit

	React components drawn from the ToyKit art (art/ui/ToyKit), and the
	art's sizes and layout grid. Screens require this one module.

	Public API:
		Kit.Art                       -- sizes, image IDs, layout grid (Art.luau)
		Kit.Image, Kit.Text, Kit.Button, Kit.Slot, Kit.Bar, Kit.Window
		Kit.mount(name, displayOrder?): Root   -- a ScreenGui with a React root
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

export type Root = {
	gui: ScreenGui,
	render: (element: any) -> (),
}

local Kit = {
	Art = require(script.Art),
	Image = require(script.KitImage),
	Text = require(script.KitText),
	Button = require(script.KitButton),
	Slot = require(script.Slot),
	Bar = require(script.Bar),
	Window = require(script.Window),
}

-- One ScreenGui per screen, rendered synchronously so a controller can
-- re-render whenever its state changes.
function Kit.mount(name: string, displayOrder: number?): Root
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder or 0
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local root = ReactRoblox.createLegacyRoot(gui)
	return {
		gui = gui,
		render = function(element: any)
			root:render(element)
		end,
	}
end

return Kit
