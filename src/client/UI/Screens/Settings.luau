--!strict
--[[
	Settings

	The settings window: a volume slider or a switch per row, labels on the
	left margin and every control ending on the right margin; and the cog
	in the bottom-left corner that opens it.

	Props: rows ({ { key, label, kind } }), values, onChange(key, value)
	while dragging or switching, onCommit() when a change is done
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Kit = require(script.Parent.Parent.Kit)
local Windows = require(script.Parent.Parent.Windows)

local e = React.createElement
local Art = Kit.Art

local WINDOW = "Settings"
local PANEL = Art.size("PanelSettings")
local ROW_H = 44
local ROW_STEP = 52
local SLIDER = Art.size("BarTroughSlider")
local KNOB_W, KNOB_H = 26, 36
local CHECK = 40
local GEAR = 56
local EDGE = 16

export type Row = { key: string, label: string, kind: "Volume" | "Switch" }

export type Props = {
	rows: { Row },
	values: { [string]: any },
	onChange: (key: string, value: any) -> (),
	onCommit: () -> (),
}

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- The knob's centre rides along the fill's 7px-inset track; dragging
-- anywhere on the bar or knob sets the value, and letting go commits it.
local function Slider(props: { value: number, y: number, onChange: (number) -> (), onCommit: () -> () })
	local barRef = React.useRef(nil :: ImageLabel?)
	local dragging = React.useRef(false)
	local x = PANEL.X - Art.MARGIN - SLIDER.X

	local function setFrom(screenX: number)
		local bar = barRef.current
		if not bar then
			return
		end
		local scale = bar.AbsoluteSize.X / SLIDER.X
		local left = bar.AbsolutePosition.X + 7 * scale
		props.onChange(math.clamp((screenX - left) / ((SLIDER.X - 14) * scale), 0, 1))
	end

	React.useEffect(function()
		local moved = UserInputService.InputChanged:Connect(function(input)
			local moving = input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			if dragging.current and moving then
				setFrom(input.Position.X)
			end
		end)
		local ended = UserInputService.InputEnded:Connect(function(input)
			if dragging.current and isPointer(input) then
				dragging.current = false
				props.onCommit()
			end
		end)
		return function()
			moved:Disconnect()
			ended:Disconnect()
		end
	end, { props.onChange, props.onCommit } :: { any })

	local function begin(_gui, input: InputObject)
		if isPointer(input) then
			dragging.current = true
			setFrom(input.Position.X)
		end
	end

	return e(React.Fragment, nil, {
		Bar = e("Frame", {
			ref = barRef,
			BackgroundTransparency = 1,
			Active = true,
			Position = UDim2.fromOffset(x, props.y + (ROW_H - SLIDER.Y) / 2),
			Size = UDim2.fromOffset(SLIDER.X, SLIDER.Y),
			[React.Event.InputBegan] = begin,
		}, {
			Trough = e(Kit.Bar, { name = "Slider", fraction = props.value }),
		}),
		Knob = e("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Colors.PanelLight,
			Position = UDim2.fromOffset(
				x + 7 + (SLIDER.X - 14) * props.value - KNOB_W / 2,
				props.y + (ROW_H - KNOB_H) / 2
			),
			Size = UDim2.fromOffset(KNOB_W, KNOB_H),
			ZIndex = 3,
			[React.Event.InputBegan] = begin,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Ink = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Theme.Colors.Ink,
				Thickness = Art.INK,
			}),
		}),
	})
end

local function Settings(props: Props)
	local rows = {}
	for index, row in props.rows do
		local y = Art.BODY_Y + (index - 1) * ROW_STEP
		local value = props.values[row.key]
		rows[row.key] = e(React.Fragment, nil, {
			Label = e(Kit.Text, {
				text = row.label,
				textSize = 21,
				position = UDim2.fromOffset(Art.MARGIN, y),
				size = UDim2.fromOffset(PANEL.X - 2 * Art.MARGIN, ROW_H),
			}),
			Control = if row.kind == "Volume"
				then e(Slider, {
					value = value,
					y = y,
					onChange = function(newValue: number)
						props.onChange(row.key, newValue)
					end,
					onCommit = props.onCommit,
				})
				else e(Kit.Button, {
					element = if value then "CheckboxOn" else "Checkbox",
					onClick = function()
						props.onChange(row.key, not value)
						props.onCommit()
					end,
					position = UDim2.fromOffset(PANEL.X - Art.MARGIN - CHECK, y + (ROW_H - CHECK) / 2),
				}),
		})
	end

	return e(React.Fragment, nil, {
		-- The cog sits in the bottom-left corner, clear of the hotbar.
		Gear = e("ImageButton", {
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Image = Art.image("IconSettings"),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, EDGE, 1, -EDGE),
			Size = UDim2.fromOffset(GEAR, GEAR),
			[React.Event.Activated] = function()
				Windows.toggle(WINDOW)
			end,
		}),
		Window = e(Kit.Window, {
			name = WINDOW,
			panel = "PanelSettings",
			header = "HeaderSettings",
			title = "SETTINGS",
			icon = "IconSettings28",
		}, {
			Rows = e(React.Fragment, nil, rows),
			Footnote = e(Kit.Text, {
				text = "Saved to your profile",
				textSize = 14,
				kind = "note",
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(Art.MARGIN, Art.BODY_Y + #props.rows * ROW_STEP + 6),
				size = UDim2.fromOffset(PANEL.X - 2 * Art.MARGIN, 20),
			}),
		}),
	})
end

return Settings
