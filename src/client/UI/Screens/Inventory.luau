--!strict
--[[
	Inventory

	The Bag window: a scrolling grid of slots framed by rarity with a painted
	scroll thumb, and a detail card for the selected item.

	Props: entries ({ { itemId, count } }), selected, sortByName,
	onSelect(index), onSort(), onTrade()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Config.Items)
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Kit = require(script.Parent.Parent.Kit)

local e = React.createElement
local Art = Kit.Art

local PANEL = Art.size("PanelInventory")
local PLATE_H = 396
local PLATE_Y = PANEL.Y - Art.MARGIN - PLATE_H
local DETAIL_W = 212
local SLOT = 80
local SLOT_GAP = 10
local COLUMNS = 5
local MIN_ROWS = 4
local GRID_INSET_X = 24
local GRID_INSET_Y = 20
local GRID_W = COLUMNS * SLOT + (COLUMNS - 1) * SLOT_GAP
local GRID_H = MIN_ROWS * SLOT + (MIN_ROWS - 1) * SLOT_GAP
local THUMB_H = 110
local SOURCE_GREY = Color3.fromRGB(106, 106, 138)

export type Entry = { itemId: string, count: number, guid: string? }

export type Props = {
	entries: { Entry },
	selected: number,
	sortByName: boolean,
	onSelect: (index: number) -> (),
	onSort: () -> (),
	onTrade: () -> (),
}

local function Detail(props: { entry: Entry?, onTrade: () -> () })
	local entry = props.entry
	local definition = entry and Items.get(entry.itemId)
	local children: { [string]: any } = {}
	if entry and definition then
		local rarityColor = Theme.RarityColors[definition.rarity]
		children = {
			Picture = e("ImageLabel", {
				BackgroundTransparency = 1,
				Image = Art.item(entry.itemId),
				Position = UDim2.fromOffset((DETAIL_W - 132) / 2, 22),
				Size = UDim2.fromOffset(132, 132),
			}),
			Name = e(Kit.Text, {
				text = string.upper(definition.displayName),
				textSize = 24,
				color = rarityColor,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(0, 164),
				size = UDim2.fromOffset(DETAIL_W, 30),
			}),
			Pill = e("Frame", {
				BackgroundColor3 = rarityColor,
				AnchorPoint = Vector2.new(0.5, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.fromOffset(DETAIL_W / 2, 200),
				Size = UDim2.fromOffset(0, 28),
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Ink = e("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Theme.Colors.Ink,
					Thickness = Art.INK,
				}),
				Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
				Text = e(Kit.Text, { text = string.upper(definition.rarity), textSize = 15, fit = true, height = 28 }),
			}),
			Description = e(Kit.Text, {
				text = definition.description,
				textSize = 17,
				kind = "note",
				color = Art.DARK_TEXT,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(18, 240),
				size = UDim2.fromOffset(DETAIL_W - 36, 48),
			}),
			Source = e(Kit.Text, {
				text = if entry.count > 1
					then `You have {entry.count} · Tradeable`
					else "Found in storms · Tradeable",
				textSize = 14,
				kind = "note",
				color = SOURCE_GREY,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(0, 292),
				size = UDim2.fromOffset(DETAIL_W, 20),
			}),
			Trade = e(Kit.Button, {
				element = Art.MEDIUM.Blue,
				text = "TRADE IT",
				textSize = 21,
				onClick = props.onTrade,
				position = UDim2.fromOffset((DETAIL_W - 160) / 2, PLATE_H - 26 - 44),
			}),
		}
	else
		children.Empty = e(Kit.Text, {
			text = "Your bag is empty. Survive a storm to find loot!",
			textSize = 17,
			kind = "note",
			color = Art.DARK_TEXT,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(18, 0),
			size = UDim2.fromOffset(DETAIL_W - 36, PLATE_H - 6),
		})
	end
	return e(Kit.Image, {
		element = "PlateInventoryDetail",
		position = UDim2.fromOffset(PANEL.X - Art.MARGIN - DETAIL_W, PLATE_Y),
	}, children)
end

local function Inventory(props: Props)
	-- The painted thumb follows the grid's scroll.
	local scroll, setScroll = React.useBinding(0)

	local rows = math.max(MIN_ROWS, math.ceil(#props.entries / COLUMNS))
	local slots = {}
	for index = 1, rows * COLUMNS do
		local entry = props.entries[index]
		slots[index] = e(Kit.Slot, {
			size = SLOT,
			itemId = entry and entry.itemId,
			count = entry and entry.count,
			glow = entry ~= nil and index == props.selected,
			layoutOrder = index,
			onClick = function()
				props.onSelect(index)
			end,
		})
	end

	local function onScroll(grid: ScrollingFrame)
		local travel = grid.AbsoluteCanvasSize.Y - grid.AbsoluteWindowSize.Y
		setScroll(if travel > 0 then grid.CanvasPosition.Y / travel else 0)
	end

	return e(Kit.Window, {
		name = "Bag",
		panel = "PanelInventory",
		header = "HeaderInventory",
		title = "BAG",
		icon = "IconBag28",
	}, {
		Sort = e(Kit.Button, {
			element = Art.MEDIUM.Blue,
			text = if props.sortByName then "SORT: NAME" else "SORT: RARITY",
			textSize = 17,
			onClick = props.onSort,
			position = UDim2.fromOffset(Art.MARGIN, Art.BODY_Y),
		}),
		Count = e(Kit.Text, {
			text = `{#props.entries} ITEMS`,
			textSize = 24,
			align = Enum.TextXAlignment.Right,
			position = UDim2.fromOffset(PANEL.X - Art.MARGIN - 220, Art.BODY_Y),
			size = UDim2.fromOffset(220, 44),
		}),
		Plate = e(Kit.Image, {
			element = "PlateInventoryGrid",
			position = UDim2.fromOffset(Art.MARGIN, PLATE_Y),
		}, {
			Grid = e("ScrollingFrame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 0,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				Position = UDim2.fromOffset(GRID_INSET_X, GRID_INSET_Y),
				Size = UDim2.fromOffset(GRID_W, GRID_H),
				[React.Change.CanvasPosition] = onScroll,
				[React.Change.AbsoluteCanvasSize] = onScroll,
			}, {
				Layout = e("UIGridLayout", {
					CellSize = UDim2.fromOffset(SLOT, SLOT),
					CellPadding = UDim2.fromOffset(SLOT_GAP, SLOT_GAP),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Slots = e(React.Fragment, nil, slots),
			}),
			Track = e(Kit.Image, {
				element = "ScrollTrack",
				position = UDim2.fromOffset(GRID_INSET_X + GRID_W + 16, GRID_INSET_Y),
			}, {
				Thumb = e("ImageLabel", {
					BackgroundTransparency = 1,
					Image = Art.image("ScrollThumb"),
					Size = UDim2.fromOffset(16, THUMB_H),
					Position = scroll:map(function(fraction: number)
						return UDim2.fromOffset(0, math.round((GRID_H - THUMB_H) * fraction))
					end),
				}),
			}),
		}),
		Detail = e(Detail, { entry = props.entries[props.selected], onTrade = props.onTrade }),
	})
end

return Inventory
