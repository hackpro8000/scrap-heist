--!strict
--[[
	Build

	Build mode's bar along the bottom of the screen: a line saying what to
	do next, over a row of buttons (what can be placed, or turn, place and
	cancel while something is in hand).

	Props: open, hint, buttons ({ text, kind?, enabled?, onClick })
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Kit = require(script.Parent.Parent.Kit)

local e = React.createElement
local Art = Kit.Art

local BAR_BOTTOM = 110
local BUTTON_GAP = 10
local HINT_H = 34

export type BarButton = {
	text: string,
	-- Which medium button art: "Blue" (default), "Action" or "Danger".
	kind: string?,
	enabled: boolean?,
	onClick: () -> (),
}

export type Props = {
	open: boolean,
	hint: string,
	buttons: { BarButton },
}

local function Build(props: Props)
	if not props.open then
		return nil
	end

	local row = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, BUTTON_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, button in props.buttons do
		row[`Button{index}`] = e(Kit.Button, {
			element = Art.MEDIUM[button.kind or "Blue"] or Art.MEDIUM.Blue,
			text = button.text,
			textSize = 18,
			enabled = button.enabled ~= false,
			onClick = button.onClick,
			layoutOrder = index,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BAR_BOTTOM),
		Size = UDim2.new(1, 0, 0, HINT_H + 8 + 44),
	}, {
		Hint = e("Frame", {
			BackgroundColor3 = Theme.Colors.Background,
			BackgroundTransparency = 0.2,
			AnchorPoint = Vector2.new(0.5, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(0, HINT_H),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
			Text = e(Kit.Text, {
				text = props.hint,
				textSize = 20,
				color = Theme.Colors.Accent,
				fit = true,
				height = HINT_H,
			}),
		}),
		Row = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, HINT_H + 8),
			Size = UDim2.new(1, 0, 0, 44),
		}, row),
	})
end

return Build
