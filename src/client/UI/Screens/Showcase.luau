--!strict
--[[
	Showcase

	The admin showcase panel down the right edge, a list of one-tap command
	buttons, and the debug overlay's tally of rejected remote calls in the
	bottom-right corner. Plain navy debug styling, not kit art: players
	never see it.

	Props: open, buttons ({ { label, onClick } }), stats ({ [reason]: count }?
	nil hides the tally)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Kit = require(script.Parent.Parent.Kit)

local e = React.createElement

local PANEL_W = 200
local BUTTON_H = 38
local PAD = 8

export type Button = { label: string, onClick: () -> () }

export type Props = {
	open: boolean,
	buttons: { Button },
	stats: { [string]: number }?,
}

local function DebugFrame(props: { [string]: any })
	return e("Frame", {
		BackgroundColor3 = props.color or Theme.Colors.Panel,
		BackgroundTransparency = props.transparency or 0,
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.CornerRadius }),
		Ink = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Theme.Colors.Ink,
			Thickness = Kit.Art.INK,
		}),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, PAD),
			PaddingBottom = UDim.new(0, PAD),
			PaddingLeft = UDim.new(0, PAD),
			PaddingRight = UDim.new(0, PAD),
		}),
		Title = e(Kit.Text, { text = props.title, textSize = 20, size = UDim2.new(1, 0, 0, 26) }),
		List = e("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, 0, 1, -32),
		}, {
			Layout = e("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
			Items = e(React.Fragment, nil, props.items),
		}),
	})
end

local function Showcase(props: Props)
	local buttons = {}
	for index, button in props.buttons do
		buttons[index] = e("TextButton", {
			Text = button.label,
			TextColor3 = Theme.Colors.Text,
			BackgroundColor3 = Theme.Colors.PanelLight,
			Font = Theme.Font,
			TextSize = 17,
			Size = UDim2.new(1, -8, 0, BUTTON_H),
			LayoutOrder = index,
			[React.Event.Activated] = button.onClick,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		})
	end

	local lines = {}
	if props.stats then
		local keys = {}
		for key in props.stats do
			table.insert(keys, key)
		end
		table.sort(keys)
		if #keys == 0 then
			lines.None = e(
				Kit.Text,
				{ text = "No rejected calls yet", textSize = 15, kind = "note", size = UDim2.new(1, 0, 0, 22) }
			)
		end
		for index, key in keys do
			lines[key] = e(Kit.Text, {
				text = `{key}: {props.stats[key]}`,
				textSize = 15,
				kind = "note",
				color = Theme.Colors.Text,
				size = UDim2.new(1, 0, 0, 22),
				layoutOrder = index,
			})
		end
	end

	return e(React.Fragment, nil, {
		Panel = if props.open
			then e(DebugFrame, {
				title = "Showcase",
				anchor = Vector2.new(1, 0.5),
				position = UDim2.new(1, -12, 0.5, 0),
				size = UDim2.new(0, PANEL_W, 0.7, 0),
				items = buttons,
			})
			else nil,
		Stats = if props.stats
			then e(DebugFrame, {
				title = "Rejected remote calls",
				color = Theme.Colors.Background,
				transparency = 0.2,
				anchor = Vector2.new(1, 1),
				position = UDim2.new(1, -12, 1, -12),
				size = UDim2.fromOffset(260, 200),
				items = lines,
			})
			else nil,
	})
end

return Showcase
