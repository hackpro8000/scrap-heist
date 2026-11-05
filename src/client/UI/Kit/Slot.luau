--!strict
--[[
	Slot

	A slot framed in its item's rarity, the item's picture in its well and
	its count in the corner. Empty slots show the plain dark frame. A
	selected slot wears the painted gold ring (Slot<Size>Glow), not an
	engine stroke, so its ink matches the art.

	Props: size (80, 72 or 56), itemId?, count?, rarity?, countText?, glow?,
	faded?, onClick?, position?, anchor?, layoutOrder?, zIndex?
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Items = require(ReplicatedStorage.Shared.Config.Items)

local Art = require(script.Parent.Art)
local KitButton = require(script.Parent.KitButton)
local KitImage = require(script.Parent.KitImage)
local KitText = require(script.Parent.KitText)

local e = React.createElement

local PREFIX = { [80] = "Slot", [72] = "SlotMedium", [56] = "SlotSmall" }

export type Props = {
	size: number,
	itemId: string?,
	count: number?,
	rarity: string?,
	-- Replaces the "x12" count, e.g. an amount of scrap.
	countText: string?,
	glow: boolean?,
	faded: boolean?,
	onClick: (() -> ())?,
	position: UDim2?,
	anchor: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
}

local function Slot(props: Props)
	local size = props.size
	local prefix = PREFIX[size]
	assert(prefix, `Slot: no slot art at {size}px`)
	local definition = props.itemId and Items.get(props.itemId)
	local rarity = if definition then definition.rarity else props.rarity
	local element = prefix .. (rarity or "")
	local count = props.countText or if props.count and props.count > 1 then `x{props.count}` else ""
	local z = props.zIndex or 1

	local contents = {
		Item = if props.itemId
			then e("ImageLabel", {
				BackgroundTransparency = 1,
				Image = Art.item(props.itemId),
				ImageTransparency = if props.faded then 0.5 else 0,
				Position = UDim2.fromOffset(size * 0.16, size * 0.14),
				Size = UDim2.fromOffset(size * 0.68, size * 0.68),
				ZIndex = z + 1,
			})
			else nil,
		Count = if count ~= ""
			then e(KitText, {
				text = count,
				textSize = math.round(size * 0.24),
				align = Enum.TextXAlignment.Right,
				position = UDim2.fromOffset(0, size * 0.62),
				size = UDim2.fromOffset(size * 0.9, size * 0.34),
				zIndex = z + 3,
			})
			else nil,
		Glow = if props.glow then e(KitImage, { element = prefix .. "Glow", zIndex = z + 2 }) else nil,
	}

	if props.onClick and props.itemId then
		return e(KitButton, {
			element = element,
			onClick = props.onClick,
			position = props.position,
			anchor = props.anchor,
			layoutOrder = props.layoutOrder,
			zIndex = z,
		}, contents)
	end
	return e(KitImage, {
		element = element,
		transparency = if props.faded then 0.5 else 0,
		position = props.position,
		anchor = props.anchor,
		layoutOrder = props.layoutOrder,
		zIndex = z,
	}, contents)
end

return Slot
