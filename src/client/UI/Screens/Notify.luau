--!strict
--[[
	Notify

	Short messages stacked under the raid strip, each a slim navy tag sized
	to its text that fades out on its own. The stack glides to a new top
	when the raid sign hangs under the strip.

	Props: top (pixels from the top), toasts ({ { id, text, color } }),
	onGone(id) when a toast has faded
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Kit = require(script.Parent.Parent.Kit)

local e = React.createElement

local TOAST_SECONDS = 3
local FADE_SECONDS = 0.4
local TOAST_H = 36
local TEXT_INSET = 16
local MOVE_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad)

export type Toast = { id: number, text: string, color: Color3? }

export type Props = {
	top: number,
	toasts: { Toast },
	onGone: (id: number) -> (),
}

local function ToastView(props: { toast: Toast, onGone: (id: number) -> () })
	local fade, setFade = React.useBinding(0)
	React.useEffect(function()
		local value = Instance.new("NumberValue")
		local connection = value.Changed:Connect(setFade)
		local thread = task.delay(TOAST_SECONDS, function()
			local tween = TweenService:Create(value, TweenInfo.new(FADE_SECONDS), { Value = 1 })
			tween.Completed:Once(function()
				props.onGone(props.toast.id)
			end)
			tween:Play()
		end)
		return function()
			task.cancel(thread)
			connection:Disconnect()
			value:Destroy()
		end
	end, {})

	return e("Frame", {
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = fade,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, TOAST_H),
		LayoutOrder = props.toast.id,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Ink = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Theme.Colors.Ink,
			Thickness = Kit.Art.INK,
			Transparency = fade,
		}),
		Padding = e("UIPadding", { PaddingLeft = UDim.new(0, TEXT_INSET), PaddingRight = UDim.new(0, TEXT_INSET) }),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			Text = props.toast.text,
			Font = Theme.BodyFont,
			TextSize = 17,
			TextColor3 = props.toast.color or Theme.Colors.Accent,
			TextTransparency = fade,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, TOAST_H),
		}),
	})
end

local function Notify(props: Props)
	local stackRef = React.useRef(nil :: Frame?)
	React.useEffect(function()
		local stack = stackRef.current
		if stack then
			TweenService:Create(stack, MOVE_TWEEN, { Position = UDim2.new(0.5, 0, 0, props.top) }):Play()
		end
	end, { props.top })

	local toasts = {}
	for _, toast in props.toasts do
		toasts[tostring(toast.id)] = e(ToastView, { toast = toast, onGone = props.onGone })
	end
	return e("Frame", {
		ref = stackRef,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(1, 0, 0, 3 * (TOAST_H + 6)),
	}, {
		Layout = e("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Toasts = e(React.Fragment, nil, toasts),
	})
end

return Notify
