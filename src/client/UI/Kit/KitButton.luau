--!strict
--[[
	KitButton

	A kit button at its painted size with a centred Luckiest label. Plastic
	buttons swell a touch under the cursor and sink while held. A disabled
	button shows the grey art of the same size and ignores taps.

	Props: element, text?, textSize?, onClick, enabled?, position?, anchor?,
	zIndex?, layoutOrder?, visible?, children?
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)

local Sfx = require(script.Parent.Parent.Parent.Sfx)
local Art = require(script.Parent.Art)
local KitText = require(script.Parent.KitText)

local e = React.createElement

local HOVER_SCALE = 1.05
local PRESS_SCALE = 0.85
local PRESS_TINT = Color3.fromRGB(215, 215, 215)
local REACT_TWEEN = TweenInfo.new(0.08, Enum.EasingStyle.Quad)
-- Letting go springs the button back past its size before it settles.
local RELEASE_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local DISABLED_BY_WIDTH = { [200] = Art.LARGE.Disabled, [160] = Art.MEDIUM.Disabled, [120] = Art.SMALL.Disabled }

export type Props = {
	element: string,
	text: string?,
	textSize: number?,
	onClick: () -> (),
	enabled: boolean?,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	layoutOrder: number?,
	visible: boolean?,
	children: any?,
}

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function KitButton(props: Props)
	local size = Art.size(props.element)
	local enabled = props.enabled ~= false
	local disabledElement = DISABLED_BY_WIDTH[size.X]
	local element = if enabled or not disabledElement then props.element else disabledElement

	local buttonRef = React.useRef(nil :: ImageButton?)
	local scaleRef = React.useRef(nil :: UIScale?)
	local hovered = React.useRef(false)
	local pressed = React.useRef(false)
	local enabledRef = React.useRef(enabled)
	enabledRef.current = enabled

	local react = React.useCallback(function()
		local button, scale = buttonRef.current, scaleRef.current
		if not button or not scale then
			return
		end
		local live = enabledRef.current
		local down = pressed.current and live
		local target = if down then PRESS_SCALE elseif hovered.current and live then HOVER_SCALE else 1
		local released = not down and scale.Scale < 1
		TweenService:Create(scale, if released then RELEASE_TWEEN else REACT_TWEEN, { Scale = target }):Play()
		TweenService:Create(button, REACT_TWEEN, { ImageColor3 = if down then PRESS_TINT else Color3.new(1, 1, 1) })
			:Play()
	end, {})

	return e("ImageButton", {
		ref = buttonRef,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Image = Art.image(element),
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		ZIndex = props.zIndex or 1,
		LayoutOrder = props.layoutOrder or 0,
		Visible = if props.visible == nil then true else props.visible,
		[React.Event.MouseEnter] = function()
			hovered.current = true
			react()
		end,
		[React.Event.MouseLeave] = function()
			hovered.current, pressed.current = false, false
			react()
		end,
		[React.Event.InputBegan] = function(_gui, input: InputObject)
			if isPointer(input) then
				pressed.current = true
				react()
			end
		end,
		[React.Event.InputEnded] = function(_gui, input: InputObject)
			if isPointer(input) then
				pressed.current = false
				if input.UserInputType == Enum.UserInputType.Touch then
					hovered.current = false
				end
				react()
			end
		end,
		[React.Event.Activated] = function()
			if enabledRef.current then
				Sfx.play("UiClick")
				props.onClick()
			end
		end,
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Label = if props.text and props.text ~= ""
			then e(KitText, {
				text = props.text,
				textSize = props.textSize or 24,
				align = Enum.TextXAlignment.Center,
				zIndex = (props.zIndex or 1) + 1,
			})
			else nil,
		Content = if props.children then e(React.Fragment, nil, props.children) else nil,
	})
end

return KitButton
