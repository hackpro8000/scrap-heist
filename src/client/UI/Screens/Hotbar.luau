--!strict
--[[
	Hotbar

	The bottom-centre hotbar: a health bar over a row of numbered wooden
	slots. The held weapon's slot wears the cream ring (SlotWoodSelected)
	and pops up a touch; a weapon not bought yet stays in its slot, dimmed.

	Taking damage drops the red fill at once and leaves a pale trail that
	drains after it, so you can see how much a hit took.

	Props: health (0..1), slots ({ { weapon?, name?, owned, held } }),
	onSlot(index)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)

local Kit = require(script.Parent.Parent.Kit)

local e = React.createElement
local Art = Kit.Art

local SLOT_SIZE = 56
local SLOT_GAP = 8
local BOTTOM_MARGIN = 16
local BAR = Art.size("BarTroughHotbar")
local FILL_W, FILL_H = BAR.X - 14, BAR.Y - 14
local FILL_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad)
-- The trail holds a beat, then drains to meet the fill.
local TRAIL_DELAY = 0.4
local TRAIL_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local SELECTED_SCALE = 1.08
local SELECT_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Back)

export type SlotSpec = { name: string?, owned: boolean, held: boolean }

export type Props = {
	health: number,
	slots: { SlotSpec },
	onSlot: (index: number) -> (),
}

local function clipSize(fraction: number): UDim2
	return UDim2.fromOffset(math.round(FILL_W * math.clamp(fraction, 0, 1)), FILL_H)
end

local function HealthBar(props: { health: number })
	local fillRef = React.useRef(nil :: Frame?)
	local trailRef = React.useRef(nil :: Frame?)
	local shownTrail = React.useRef(props.health)

	React.useEffect(function()
		local fill, trail = fillRef.current, trailRef.current
		if not fill or not trail then
			return nil
		end
		local size = clipSize(props.health)
		TweenService:Create(fill, FILL_TWEEN, { Size = size }):Play()
		if props.health >= shownTrail.current then
			-- Healing: the trail just keeps up.
			shownTrail.current = props.health
			TweenService:Create(trail, FILL_TWEEN, { Size = size }):Play()
			return nil
		end
		local thread = task.delay(TRAIL_DELAY, function()
			shownTrail.current = props.health
			TweenService:Create(trail, TRAIL_TWEEN, { Size = size }):Play()
		end)
		return function()
			task.cancel(thread)
		end
	end, { props.health })

	local function clip(name: string, ref: any, z: number)
		return e("Frame", {
			ref = ref,
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(7, 7),
			Size = clipSize(props.health),
			ZIndex = z,
		}, {
			Fill = e(Kit.Image, { element = name, zIndex = z }),
		})
	end

	return e(Kit.Image, { element = "BarTroughHotbar" }, {
		Trail = clip("BarTrailHotbar", trailRef, 2),
		Fill = clip("BarFillHealthHotbar", fillRef, 3),
	})
end

local function Slot(props: { index: number, spec: SlotSpec, onClick: () -> () })
	local scaleRef = React.useRef(nil :: UIScale?)
	local spec = props.spec
	React.useEffect(function()
		local scale = scaleRef.current
		if scale then
			TweenService:Create(scale, SELECT_TWEEN, { Scale = if spec.held then SELECTED_SCALE else 1 }):Play()
		end
	end, { spec.held })

	local dim = if spec.name and not spec.owned then 0.5 else 0
	return e("ImageButton", {
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Image = Art.image(if spec.held then "SlotWoodSelected" else "SlotWood"),
		ImageTransparency = dim,
		LayoutOrder = props.index,
		[React.Event.Activated] = props.onClick,
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Number = e(Kit.Text, {
			text = tostring(props.index),
			textSize = 16,
			alignY = Enum.TextYAlignment.Top,
			position = UDim2.fromOffset(-2, -6),
			size = UDim2.fromOffset(18, 20),
			zIndex = 2,
		}),
		Name = if spec.name
			then e(Kit.Text, {
				text = spec.name,
				textSize = 14,
				wrap = true,
				scaled = true,
				align = Enum.TextXAlignment.Center,
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.55),
				size = UDim2.new(1, -6, 0, 28),
				transparency = dim,
				zIndex = 2,
			})
			else nil,
	})
end

local function Hotbar(props: Props)
	local slots = {}
	for index, spec in props.slots do
		slots[index] = e(Slot, {
			index = index,
			spec = spec,
			onClick = function()
				props.onSlot(index)
			end,
		})
	end
	return e("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM_MARGIN),
		Size = UDim2.fromOffset(BAR.X, BAR.Y + SLOT_GAP + SLOT_SIZE),
	}, {
		Health = e(HealthBar, { health = props.health }),
		Slots = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, BAR.Y + SLOT_GAP),
			Size = UDim2.new(1, 0, 0, SLOT_SIZE),
		}, {
			Grid = e("UIGridLayout", {
				CellSize = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
				CellPadding = UDim2.fromOffset(SLOT_GAP, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			List = e(React.Fragment, nil, slots),
		}),
	})
end

return Hotbar
