--!strict
--[[
	Results

	The window a storm ends with: a headline, your damage, top-damage rank
	and scrap earned, the loot found (rare finds ringed in gold), a NICE
	button and a countdown to it closing.

	Props: results (the server's RoundResults, nil before the first storm),
	closesIn (seconds), onClose()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Config.Items)
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Kit = require(script.Parent.Parent.Kit)

local e = React.createElement
local Art = Kit.Art

local PANEL = Art.size("PanelResults")
local ROW_W = PANEL.X - 2 * Art.MARGIN
local HEADLINE_H = 52
local ROWS_Y = Art.BODY_Y + HEADLINE_H + Art.GAP
local ROW_STEP = 56
local PLATE_Y = ROWS_Y + 3 * ROW_STEP + Art.GAP
local PLATE_H = 110
local BUTTON_Y = PLATE_Y + PLATE_H + Art.GAP
local LOOT_SLOTS = 4
local LOOT_STEP = 80
local LOOT_RIGHT = ROW_W - 24
-- Centred on the loot plate's face (3px down to 6px above its foot).
local LOOT_Y = (PLATE_H - 6 - 72) / 2 + 3
local NOTE_GREY = Color3.fromRGB(74, 74, 106)
local RESULT_ROWS = {
	{ icon = "IconBot", label = "DAMAGE DEALT" },
	{ icon = "IconTrophy", label = "TOP DAMAGE" },
	{ icon = "IconScrap", label = "SCRAP EARNED" },
}

export type Loot = { itemId: string, count: number }

export type Props = {
	results: { [string]: any }?,
	loot: { Loot },
	closesIn: number,
	onClose: () -> (),
}

local function isRare(itemId: string): boolean
	local definition = Items.get(itemId)
	return definition ~= nil and (definition.rarity == "Rare" or definition.rarity == "Legendary")
end

local function Results(props: Props)
	local results = props.results or {}
	local survived = results.survived == true
	local values = {
		tostring(results.damage or 0),
		if results.topRank then `#{results.topRank}` else "-",
		`+{results.scrap or 0}`,
	}

	local rows = {}
	for index, spec in RESULT_ROWS do
		rows[index] = e(Kit.Image, {
			element = if index % 2 == 0 then "ResultsRowAlt" else "ResultsRow",
			position = UDim2.fromOffset(Art.MARGIN, ROWS_Y + (index - 1) * ROW_STEP),
		}, {
			Icon = e(Kit.Image, { element = spec.icon, size = 40, position = UDim2.fromOffset(14, 5) }),
			Label = e(Kit.Text, {
				text = spec.label,
				textSize = 21,
				position = UDim2.fromOffset(62, 0),
				size = UDim2.fromOffset(300, 50),
			}),
			Value = e(Kit.Text, {
				text = values[index],
				textSize = 26,
				color = if index == 2 then Theme.Colors.Accent else nil,
				align = Enum.TextXAlignment.Right,
				position = UDim2.fromOffset(ROW_W - 18 - 200, 0),
				size = UDim2.fromOffset(200, 50),
			}),
		})
	end

	-- Loot slots line up from the plate's right margin.
	local shown = math.min(#props.loot, LOOT_SLOTS)
	local foundRare = false
	local slots = {}
	for index = 1, shown do
		local entry = props.loot[index]
		local rare = isRare(entry.itemId)
		foundRare = foundRare or rare
		slots[index] = e(Kit.Slot, {
			size = 72,
			itemId = entry.itemId,
			count = entry.count,
			glow = rare,
			position = UDim2.fromOffset(LOOT_RIGHT - (shown - index + 1) * LOOT_STEP + 8, LOOT_Y),
		})
	end

	return e(Kit.Window, {
		name = "Results",
		panel = "PanelResults",
		header = "HeaderResults",
		title = "STORM OVER",
		icon = "IconTrophy28",
		onClose = props.onClose,
	}, {
		Headline = e(Kit.Text, {
			text = if survived then "YOU SURVIVED!" else "KNOCKED OUT!",
			textSize = 46,
			color = if survived then Theme.Colors.Good else Theme.Colors.Warning,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(0, Art.BODY_Y),
			size = UDim2.fromOffset(PANEL.X, HEADLINE_H),
		}),
		Rows = e(React.Fragment, nil, rows),
		Loot = e(Kit.Image, { element = "PlateRewards", position = UDim2.fromOffset(Art.MARGIN, PLATE_Y) }, {
			Title = e(Kit.Text, {
				text = "STORM LOOT",
				textSize = 22,
				kind = "dark",
				position = UDim2.fromOffset(22, 24),
				size = UDim2.fromOffset(190, 26),
			}),
			Note = e(Kit.Text, {
				text = if #props.loot == 0
					then "No loot this time."
					elseif foundRare then "Rare find! Sent to your bag."
					else "Sent to your bag.",
				textSize = 15,
				kind = "note",
				color = NOTE_GREY,
				position = UDim2.fromOffset(22, 52),
				size = UDim2.fromOffset(190, 38),
			}),
			Slots = e(React.Fragment, nil, slots),
		}),
		Nice = e(Kit.Button, {
			element = Art.LARGE.Action,
			text = "NICE!",
			textSize = 28,
			onClick = props.onClose,
			position = UDim2.fromOffset((PANEL.X - 200) / 2, BUTTON_Y),
		}),
		Footnote = e(Kit.Text, {
			text = `Closes in {math.max(0, math.ceil(props.closesIn))}`,
			textSize = 14,
			kind = "note",
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(0, BUTTON_Y + 52 + 6),
			size = UDim2.fromOffset(PANEL.X, 20),
		}),
	})
end

return Results
