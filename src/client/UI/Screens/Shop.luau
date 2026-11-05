--!strict
--[[
	Shop

	The shop window: four tabs over a 3x2 grid of cream cards. Each card
	shows its item's icon in a dark well, its name, then either stat pips
	(weapons) or one short line, and the price button or OWNED.

	Props: lists (one list of CardSpecs per tab), tab, onTab(index)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Kit = require(script.Parent.Parent.Kit)

local e = React.createElement
local Art = Kit.Art

local TABS = { "WEAPONS", "BOOSTS", "PASSES", "SCRAP" }
local TAB_W, TAB_H, TAB_GAP = 156, 36, 8
local CARDS_Y = Art.BODY_Y + TAB_H + 8
local CARD_W, CARD_H = 208, 142
local COLUMNS = 3
-- The card art carries its shadow in its last 5px across and 6px down, so
-- cards step by their visible size plus the gap, centred across the panel.
local STEP_X, STEP_Y = CARD_W - 5 + Art.GAP, CARD_H - 6 + Art.GAP
local CARDS_X = Art.MARGIN + (648 - ((COLUMNS - 1) * STEP_X + CARD_W - 5)) / 2
local WELL = 12
local ICON = 64
local TEXT_X = WELL + 72 + 10
local TEXT_W = 196 - TEXT_X
local PIPS = 5
local PIP_STEP = 14
local MEDIUM_W, MEDIUM_H = 160, 44
local PRICE_ICON = 30

export type Stat = { label: string, pips: number }

-- What one card shows. `action` is nil when there's nothing to press.
export type CardSpec = {
	icon: string,
	badge: string?,
	name: string,
	line: string?,
	stats: { Stat }?,
	price: string?,
	scrapPrice: boolean,
	owned: boolean,
	action: (() -> ())?,
}

local function statRows(stats: { Stat })
	local rows = {}
	for index, stat in stats do
		local y = 54 + (index - 1) * 16
		local pips = {}
		for pip = 1, PIPS do
			pips[pip] = e(Kit.Image, {
				element = if pip <= stat.pips then "StatPipOn" else "StatPip",
				position = UDim2.fromOffset(TEXT_X + 34 + (pip - 1) * PIP_STEP, y + 2),
			})
		end
		rows[stat.label] = e(React.Fragment, nil, {
			Label = e(Kit.Text, {
				text = stat.label,
				textSize = 13,
				kind = "dark",
				position = UDim2.fromOffset(TEXT_X, y),
				size = UDim2.fromOffset(32, 16),
			}),
			Pips = e(React.Fragment, nil, pips),
		})
	end
	return rows
end

local function PriceButton(props: { spec: CardSpec })
	local spec = props.spec
	return e(Kit.Button, {
		element = Art.MEDIUM.Action,
		onClick = function()
			if spec.action then
				spec.action()
			end
		end,
		enabled = spec.action ~= nil,
		position = UDim2.fromOffset((CARD_W - 5 - MEDIUM_W) / 2, 88),
	}, {
		-- Scrap prices read with the bolt ahead of the number.
		Row = e("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Bolt = if spec.scrapPrice
				then e(Kit.Image, { element = "IconScrap", size = PRICE_ICON, layoutOrder = 1, zIndex = 2 })
				else nil,
			Price = e(Kit.Text, {
				text = spec.price or "",
				textSize = 19,
				fit = true,
				height = MEDIUM_H,
				layoutOrder = 2,
				zIndex = 2,
			}),
		}),
	})
end

local function Card(props: { spec: CardSpec, position: UDim2 })
	local spec = props.spec
	return e(Kit.Image, { element = "CardShop", position = props.position }, {
		Well = e(Kit.Image, { element = "PreviewWell", position = UDim2.fromOffset(WELL, WELL) }, {
			Icon = e(Kit.Image, {
				element = spec.icon,
				size = ICON,
				position = UDim2.fromOffset(4, 4),
			}),
			Badge = if spec.badge
				then e(Kit.Text, {
					text = spec.badge,
					textSize = 20,
					color = Theme.Colors.Accent,
					align = Enum.TextXAlignment.Right,
					position = UDim2.fromOffset(36, 2),
					size = UDim2.fromOffset(32, 24),
					zIndex = 2,
				})
				else nil,
		}),
		Name = e(Kit.Text, {
			text = spec.name,
			textSize = 18,
			kind = "dark",
			wrap = true,
			alignY = Enum.TextYAlignment.Top,
			position = UDim2.fromOffset(TEXT_X, WELL + 2),
			size = UDim2.fromOffset(TEXT_W, 40),
		}),
		Stats = if spec.stats then e(React.Fragment, nil, statRows(spec.stats)) else nil,
		Line = if spec.line
			then e(Kit.Text, {
				text = spec.line,
				textSize = 13,
				kind = "note",
				color = Art.DARK_TEXT,
				alignY = Enum.TextYAlignment.Top,
				position = UDim2.fromOffset(TEXT_X, 52),
				size = UDim2.fromOffset(TEXT_W, 32),
			})
			else nil,
		Owned = if spec.owned
			then e(Kit.Text, {
				text = "OWNED",
				textSize = 20,
				color = Theme.Colors.Good,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(0, 88),
				size = UDim2.fromOffset(CARD_W - 5, MEDIUM_H),
			})
			else e(PriceButton, { spec = spec }),
	})
end

export type Props = {
	lists: { { CardSpec } },
	tab: number,
	onTab: (index: number) -> (),
}

local function Shop(props: Props)
	local tabs = {}
	for index, name in TABS do
		local active = index == props.tab
		tabs[name] = e(Kit.Button, {
			element = if active then "TabActive" else "Tab",
			onClick = function()
				props.onTab(index)
			end,
			position = UDim2.fromOffset(Art.MARGIN + (index - 1) * (TAB_W + TAB_GAP), Art.BODY_Y),
		}, {
			-- A tab's face runs from 3px down to its bottom edge.
			Label = e(Kit.Text, {
				text = name,
				textSize = 18,
				color = if active then Art.DARK_TEXT else Theme.Colors.TextDim,
				kind = if active then "dark" else "cream",
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(0, 3),
				size = UDim2.fromOffset(TAB_W, TAB_H - 3),
				zIndex = 2,
			}),
		})
	end

	local cards = {}
	local list: { CardSpec } = props.lists[props.tab] or {}
	for index, spec in list do
		local column, row = (index - 1) % COLUMNS, (index - 1) // COLUMNS
		cards[`{props.tab}-{index}`] = e(Card, {
			spec = spec,
			position = UDim2.fromOffset(CARDS_X + column * STEP_X, CARDS_Y + row * STEP_Y),
		})
	end

	return e(Kit.Window, {
		name = "Shop",
		panel = "PanelShop",
		header = "HeaderShop",
		title = "SHOP",
		icon = "IconShop28",
	}, {
		Tabs = e(React.Fragment, nil, tabs),
		Cards = e(React.Fragment, nil, cards),
	})
end

return Shop
