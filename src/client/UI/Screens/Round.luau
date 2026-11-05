--!strict
--[[
	Round

	The raid strip at the top: a plank with the bots still standing beside a
	plank with the countdown to the next phase, and a third with your yard's
	raid shield while it lasts. Each plank's icon straddles its left end.

	Props: count, timer, shield (text, or nil while there's no shield)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local Kit = require(script.Parent.Parent.Kit)

local e = React.createElement

local STRIP_TOP = 12
local STRIP_GAP = 12
local STRIP_ICON = 40
local SHIELD_BLUE = Color3.fromRGB(143, 216, 255)

export type Props = {
	count: string,
	timer: string,
	shield: string?,
}

-- A plank with its icon straddling the left end and a number filling the
-- rest, short of the nail on the right.
local function IconPlank(props: { order: number, plank: string, icon: string, text: string, color: Color3? })
	return e(Kit.Image, { element = props.plank, layoutOrder = props.order }, {
		Icon = e(Kit.Image, {
			element = props.icon,
			size = STRIP_ICON,
			anchor = Vector2.new(0, 0.5),
			position = UDim2.new(0, -10, 0.5, 0),
			zIndex = 2,
		}),
		Text = e(Kit.Text, {
			text = props.text,
			textSize = 28,
			color = props.color,
			position = UDim2.fromOffset(STRIP_ICON - 10, 2),
			size = UDim2.new(1, -(STRIP_ICON - 10) - 22, 1, -4),
			zIndex = 2,
		}),
	})
end

local function Round(props: Props)
	return e("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, STRIP_TOP),
		-- Sized to its visible planks, so it stays centred when the shield shows.
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, Kit.Art.size("PlankCount").Y),
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, STRIP_GAP),
		}),
		Count = e(IconPlank, { order = 1, plank = "PlankCount", icon = "IconBot", text = props.count }),
		Timer = e(IconPlank, { order = 2, plank = "PlankTimer", icon = "IconStorm", text = props.timer }),
		Shield = if props.shield
			then e(IconPlank, {
				order = 3,
				plank = "PlankTimer",
				icon = "IconShield",
				text = props.shield,
				color = SHIELD_BLUE,
			})
			else nil,
	})
end

return Round
