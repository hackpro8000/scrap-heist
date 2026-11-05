--!strict
--[[
	Art

	The ToyKit art's sizes and image IDs, and the layout grid every window
	shares. Every kit element is painted at the size the game shows it, so
	components place it at that size (ToyKitSlices) and never stretch or
	9-slice it.

	Layout grid: MARGIN in from the panel's image edge, GAP between blocks,
	the header at HEADER_Y and content from BODY_Y.

	Public API:
		Art.MARGIN, Art.GAP, Art.HEADER_Y, Art.HEADER_H, Art.BODY_Y, Art.INK, Art.DROP
		Art.LARGE, Art.MEDIUM, Art.SMALL       -- button art by kind, per size
		Art.DARK_TEXT
		Art.size(element): Vector2
		Art.image(element): string             -- the element's image ID
		Art.item(itemId): string               -- an item's picture
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local ToyKitSlices = require(ReplicatedStorage.Shared.UI.ToyKitSlices)

local Art = {}

Art.MARGIN = 20
Art.GAP = 12
Art.HEADER_Y = 18
Art.HEADER_H = 40
Art.BODY_Y = 70
-- Luckiest Guy's caps sit 0.16em above the centre of its line box, so its
-- labels are padded down by DROP of their size to centre on their row.
Art.DROP = 0.16
-- The ink every piece of art and every cream label wears.
Art.INK = 2.5

-- Button art by size: large 200x52, medium 160x44, small 120x40.
Art.LARGE = { Blue = "Button", Action = "ButtonAction", Danger = "ButtonDanger", Disabled = "ButtonDisabled" }
Art.MEDIUM = {
	Blue = "ButtonMedium",
	Action = "ButtonActionMedium",
	Danger = "ButtonDangerMedium",
	Disabled = "ButtonDisabledMedium",
}
Art.SMALL = { Action = "ButtonActionSmall", Disabled = "ButtonDisabledSmall" }

Art.DARK_TEXT = Color3.fromRGB(42, 42, 74)

function Art.size(element: string): Vector2
	local slice = (ToyKitSlices :: any)[element]
	assert(slice, `Art: no ToyKit element {element}`)
	return slice.size
end

function Art.image(element: string): string
	return (Assets.UI :: any)[element] or ""
end

-- Item art by item ID, uploaded as Item<Id> (scripts/item-icons.py).
function Art.item(itemId: string): string
	return (Assets.UI :: any)["Item" .. itemId] or ""
end

return Art
