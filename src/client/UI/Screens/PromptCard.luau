--!strict
--[[
	PromptCard

	One ProximityPrompt drawn as a cream kit card floating over what it acts
	on. It pops up from nothing when shown, breathes with a slow, slight
	pulse while it stays, and shrinks away when hidden.
	- Pads: the level change, the parts per second before and after, and the
	  price on a green button (the prompt's Level, Cost, RateFrom and RateTo
	  attributes).
	- Everything else: what it is, and the action on the button.
	Beside the button sits the key to press. Holding the key or the button
	fills the button as the hold runs; tapping the button works on touch.

	Props: prompt, inputType, closing (shrink away, then onGone()), onGone()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Kit = require(script.Parent.Parent.Kit)

local e = React.createElement
local Art = Kit.Art

local INSET = 16
local CARD_LIFT = 4.5
local KEY_W, KEY_H = 44, 40
local MEDIUM_W, MEDIUM_H = 160, 44
local BUTTON_Y = 66
local SCRAP_ICON = 30
local POP_IN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_OUT = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
-- A slow swell of a few percent, there and back, for as long as it shows.
local PULSE = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local PULSE_SCALE = 1.03

export type Props = {
	prompt: ProximityPrompt,
	inputType: Enum.ProximityPromptInputType,
	closing: boolean,
	onGone: () -> (),
}

local function formatRate(rate: number): string
	return if rate == math.floor(rate) then tostring(rate) else string.format("%.1f", rate)
end

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string?
	if inputType == Enum.ProximityPromptInputType.Touch then
		return nil
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return (string.gsub(prompt.GamepadKeyCode.Name, "^Button", ""))
	end
	return prompt.KeyboardKeyCode.Name
end

-- The card's two lines: a gold heading and a dark note under it.
local function headings(prompt: ProximityPrompt): (string, string)
	if prompt:GetAttribute("Pad") then
		local level = prompt:GetAttribute("Level") :: number? or 0
		local rateFrom = prompt:GetAttribute("RateFrom") :: number?
		local rateTo = prompt:GetAttribute("RateTo") :: number? or 0
		local heading = if level == 0 then "NEW MACHINE" else `LEVEL {level} → {level + 1}`
		local note = if rateFrom
			then `{formatRate(rateFrom)} → {formatRate(rateTo)} parts / sec`
			else `Makes {formatRate(rateTo)} parts / sec`
		return heading, note
	end
	return string.upper(prompt.ObjectText), ""
end

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- Re-renders when the prompt changes while showing (an upgrade).
local function usePromptChanges(prompt: ProximityPrompt)
	local _, setVersion = React.useState(0)
	React.useEffect(function()
		local function bump()
			setVersion(function(v: number)
				return v + 1
			end)
		end
		local connections = {
			prompt.AttributeChanged:Connect(bump),
			prompt:GetPropertyChangedSignal("ActionText"):Connect(bump),
			prompt:GetPropertyChangedSignal("ObjectText"):Connect(bump),
		}
		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, { prompt })
end

-- Pops the card in on mount and pulses it; shrinks it away when closing.
local function usePop(scaleRef: { current: UIScale? }, closing: boolean, onGone: () -> ())
	React.useEffect(function()
		local scale = scaleRef.current
		if not scale then
			return nil
		end
		if not Juice.UI_TWEENS then
			scale.Scale = 1
			if closing then
				onGone()
			end
			return nil
		end
		if closing then
			local tween = TweenService:Create(scale, POP_OUT, { Scale = 0 })
			local done = tween.Completed:Connect(onGone)
			tween:Play()
			return function()
				done:Disconnect()
				tween:Cancel()
			end
		end
		scale.Scale = 0
		local popIn = TweenService:Create(scale, POP_IN, { Scale = 1 })
		local pulse = TweenService:Create(scale, PULSE, { Scale = PULSE_SCALE })
		local started = popIn.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				pulse:Play()
			end
		end)
		popIn:Play()
		return function()
			started:Disconnect()
			popIn:Cancel()
			pulse:Cancel()
		end
	end, { closing })
end

-- The hold fills the button from the left as the prompt's hold runs.
local function useHoldFill(prompt: ProximityPrompt, fillRef: { current: Frame? })
	React.useEffect(function()
		local tween: Tween? = nil
		local began = prompt.PromptButtonHoldBegan:Connect(function()
			local fill = fillRef.current
			if not fill then
				return
			end
			fill.Size = UDim2.fromOffset(0, MEDIUM_H - 10)
			tween = TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {
				Size = UDim2.fromOffset(MEDIUM_W - 10, MEDIUM_H - 10),
			});
			(tween :: Tween):Play()
		end)
		local ended = prompt.PromptButtonHoldEnded:Connect(function()
			if tween then
				tween:Cancel()
			end
			local fill = fillRef.current
			if fill then
				fill.Size = UDim2.fromOffset(0, MEDIUM_H - 10)
			end
		end)
		return function()
			began:Disconnect()
			ended:Disconnect()
			if tween then
				tween:Cancel()
			end
		end
	end, { prompt })
end

local function PromptCard(props: Props)
	local prompt = props.prompt
	local scaleRef = React.useRef(nil :: UIScale?)
	local fillRef = React.useRef(nil :: Frame?)
	usePromptChanges(prompt)
	usePop(scaleRef, props.closing, props.onGone)
	useHoldFill(prompt, fillRef)

	local isPad = prompt:GetAttribute("Pad") == true
	local element = if isPad then "TooltipUpgrade" else "TooltipBuyPad"
	local size = Art.size(element)
	local heading, note = headings(prompt)
	local key = keyText(prompt, props.inputType)
	local cost = prompt:GetAttribute("Cost") :: number?
	local priced = isPad and cost ~= nil
	-- No key on touch: the button sits in the middle of the card.
	local buttonX = if key then INSET else (size.X - MEDIUM_W) / 2

	return e("BillboardGui", {
		Adornee = prompt.Parent,
		AlwaysOnTop = true,
		Active = true,
		Size = UDim2.fromOffset(size.X, size.Y),
		StudsOffset = Vector3.new(0, CARD_LIFT, 0),
		ResetOnSpawn = false,
	}, {
		-- Scaling about the card's centre, so it pops from the middle.
		Card = e(Kit.Image, {
			element = element,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
		}, {
			Pop = e("UIScale", { ref = scaleRef }),
			Heading = e(Kit.Text, {
				text = heading,
				textSize = 20,
				color = Theme.Colors.Accent,
				position = UDim2.fromOffset(INSET, 12),
				size = UDim2.fromOffset(size.X - 2 * INSET, 24),
			}),
			Note = if note ~= ""
				then e(Kit.Text, {
					text = note,
					textSize = 16,
					kind = "note",
					wrap = false,
					color = Art.DARK_TEXT,
					position = UDim2.fromOffset(INSET, 38),
					size = UDim2.fromOffset(size.X - 2 * INSET, 22),
				})
				else nil,
			Button = e("ImageButton", {
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Image = Art.image(Art.MEDIUM.Action),
				Position = UDim2.fromOffset(buttonX, BUTTON_Y),
				Size = UDim2.fromOffset(MEDIUM_W, MEDIUM_H),
				[React.Event.InputBegan] = function(_gui, input: InputObject)
					if isPointer(input) then
						prompt:InputHoldBegin()
					end
				end,
				[React.Event.InputEnded] = function(_gui, input: InputObject)
					if isPointer(input) then
						prompt:InputHoldEnd()
					end
				end,
			}, {
				-- The price reads as scrap: the bolt sits ahead of the number.
				Row = e("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					Bolt = if priced
						then e(Kit.Image, { element = "IconScrap", size = SCRAP_ICON, layoutOrder = 1, zIndex = 3 })
						else nil,
					Label = e(Kit.Text, {
						text = if priced then tostring(cost) else string.upper(prompt.ActionText),
						textSize = 21,
						fit = true,
						height = MEDIUM_H,
						layoutOrder = 2,
						zIndex = 3,
					}),
				}),
				Hold = e("Frame", {
					ref = fillRef,
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0.6,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(5, 4),
					Size = UDim2.fromOffset(0, MEDIUM_H - 10),
					ZIndex = 2,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				}),
			}),
			Key = if key
				then e("Frame", {
					BackgroundColor3 = Theme.Colors.Background,
					Position = UDim2.fromOffset(size.X - INSET - KEY_W, BUTTON_Y + (MEDIUM_H - KEY_H) / 2),
					Size = UDim2.fromOffset(KEY_W, KEY_H),
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
					Ink = e("UIStroke", {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Theme.Colors.Ink,
						Thickness = Art.INK,
					}),
					Text = e(Kit.Text, { text = key, textSize = 22, align = Enum.TextXAlignment.Center }),
				})
				else nil,
		}),
	})
end

return PromptCard
