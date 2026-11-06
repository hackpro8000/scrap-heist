--!strict
--[[
	Plot

	The yard HUD:
	- A sign that drops in under the raid strip when someone raids your yard,
	  red with hazard signs rocking at its ends, or green once it's safe.
	- A "carrying" tag while you haul a stolen bundle or a capsule home.

	Props: alert ({ id, kind, text }?, nil lifts the sign away), carrying
	(parts, or nil)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Kit = require(script.Parent.Parent.Kit)

local e = React.createElement
local Art = Kit.Art

-- The sign hangs just under the raid strip, and hides above the screen.
local ALERT_TOP = 66
local ALERT_HIDDEN = -120
local ALERT_ICON = 40
-- The hazard signs stand bigger than the board is tall, hanging off its ends.
local HAZARD_SIZE = 76
-- ToyKit icons are painted 104px square.
local ICON_ART = 104
-- The triangle sits 3 art pixels above its image's centre (the padding
-- below makes room for its shadow), so the signs drop that much to centre
-- on the board.
local HAZARD_DROP = 3 * HAZARD_SIZE / ICON_ART
local DROP_IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local LIFT_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
-- The hazard signs rock back and forth while the sign is up.
local WOBBLE_DEGREES = 10
local WOBBLE = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local CARRY_H = 36

export type Alert = { id: number, kind: string, text: string }

export type Props = {
	alert: Alert?,
	carrying: string?,
}

-- A hazard sign over one end of the board, rocking while it's up.
local function Hazard(props: { side: number })
	local ref = React.useRef(nil :: ImageLabel?)
	local lean = if props.side == 0 then -WOBBLE_DEGREES else WOBBLE_DEGREES
	React.useEffect(function()
		local icon = ref.current
		if not icon then
			return nil
		end
		icon.Rotation = -lean
		local wobble = TweenService:Create(icon, WOBBLE, { Rotation = lean })
		wobble:Play()
		return function()
			wobble:Cancel()
		end
	end, {})
	return e("ImageLabel", {
		ref = ref,
		BackgroundTransparency = 1,
		Image = Art.image("IconAlert"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(props.side, if props.side == 0 then 12 else -12, 0.5, HAZARD_DROP),
		Size = UDim2.fromOffset(HAZARD_SIZE, HAZARD_SIZE),
		-- The art leans left; flip the left sign so both lean in at the text.
		ImageRectOffset = if props.side == 0 then Vector2.new(ICON_ART, 0) else Vector2.zero,
		ImageRectSize = if props.side == 0 then Vector2.new(-ICON_ART, ICON_ART) else Vector2.zero,
		ZIndex = 2,
	})
end

local function Plot(props: Props)
	local signRef = React.useRef(nil :: ImageLabel?)
	-- The last alert stays drawn while the sign lifts away.
	local shownAlert = React.useRef(props.alert)
	if props.alert then
		shownAlert.current = props.alert
	end
	local alert = shownAlert.current
	local alertId = if props.alert then props.alert.id else 0

	React.useEffect(function()
		local sign = signRef.current
		if not sign then
			return
		end
		if props.alert then
			-- Drop in from above, overshooting a little like a sign on a spring.
			sign.Position = UDim2.new(0.5, 0, 0, ALERT_HIDDEN)
			TweenService:Create(sign, DROP_IN, { Position = UDim2.new(0.5, 0, 0, ALERT_TOP) }):Play()
		else
			TweenService:Create(sign, LIFT_OUT, { Position = UDim2.new(0.5, 0, 0, ALERT_HIDDEN) }):Play()
		end
	end, { alertId })

	local raid = alert ~= nil and alert.kind ~= "Clear"
	return e(React.Fragment, nil, {
		Sign = e(Kit.Image, {
			element = if raid or not alert then "BannerRaid" else "BannerClear",
			anchor = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, ALERT_HIDDEN),
			imageRef = signRef,
		}, {
			Label = e(Kit.Text, {
				text = if alert then string.upper(alert.text) else "",
				textSize = 26,
				color = Theme.Colors.Accent,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(ALERT_ICON - 6, 4),
				size = UDim2.new(1, -2 * (ALERT_ICON - 6), 1, -8),
				zIndex = 2,
			}),
			Left = if raid and props.alert then e(Hazard, { side = 0 }) else nil,
			Right = if raid and props.alert then e(Hazard, { side = 1 }) else nil,
		}),
		Carry = if props.carrying
			then e("Frame", {
				BackgroundColor3 = Theme.Colors.Background,
				BackgroundTransparency = 0.2,
				AnchorPoint = Vector2.new(0.5, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.new(0.5, 0, 1, -116),
				Size = UDim2.fromOffset(0, CARRY_H),
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
				Text = e(Kit.Text, {
					text = props.carrying,
					textSize = 20,
					color = Theme.Colors.Accent,
					fit = true,
					height = CARRY_H,
				}),
			})
			else nil,
	})
end

return Plot
