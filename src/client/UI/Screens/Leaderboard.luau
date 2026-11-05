--!strict
--[[
	Leaderboard

	Top right, in place of Roblox's player list: one plank showing your
	rank, which drops the top rows under it when tapped, with a Scrap /
	Raids switch. Your own row is painted in warmer steel (LeaderboardRowYou).

	Props: myRank, open, stat, rows ({ { rank, name, value, you, vip } }),
	onToggle(), onStat(name)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Kit = require(script.Parent.Parent.Kit)

local e = React.createElement

local EDGE = 16
local TOP = 14
local PLANK_W, PLANK_H = 132, 44
local ICON = 40
local ROW_W, ROW_H, ROW_STEP = 260, 36, 40
local TAB_W, TAB_H = 126, 34
local STATS = { "Scrap", "Raids" }
local MEDALS = { Theme.Colors.Accent, Color3.fromRGB(217, 221, 232), Color3.fromRGB(224, 138, 74) }

export type Row = { rank: number, name: string, value: string, you: boolean, vip: boolean }

export type Props = {
	myRank: number,
	open: boolean,
	stat: string,
	rows: { Row },
	onToggle: () -> (),
	onStat: (name: string) -> (),
}

local function Leaderboard(props: Props)
	local tabs = {}
	for index, name in STATS do
		local active = name == props.stat
		tabs[name] = e(Kit.Button, {
			element = if active then "TabSmallActive" else "TabSmall",
			onClick = function()
				props.onStat(name)
			end,
			position = UDim2.fromOffset((index - 1) * (TAB_W + 8), 0),
		}, {
			Label = e(Kit.Text, {
				text = string.upper(name),
				textSize = 16,
				kind = if active then "dark" else "cream",
				color = if active then nil else Theme.Colors.TextDim,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(0, 3),
				size = UDim2.fromOffset(TAB_W, TAB_H - 3),
				zIndex = 2,
			}),
		})
	end

	local rows = {}
	for index, row in props.rows do
		rows[index] = e(Kit.Image, {
			element = if row.you
				then "LeaderboardRowYou"
				elseif index % 2 == 0 then "LeaderboardRowAlt"
				else "LeaderboardRow",
			position = UDim2.fromOffset(0, TAB_H + 8 + (index - 1) * ROW_STEP),
		}, {
			Rank = e(Kit.Text, {
				text = tostring(row.rank),
				textSize = 19,
				color = MEDALS[row.rank],
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(10, 0),
				size = UDim2.fromOffset(30, ROW_H),
			}),
			Name = e(Kit.Text, {
				text = if row.you then "YOU" else row.name,
				textSize = 18,
				color = if row.you then Theme.Colors.Good elseif row.vip then Theme.Colors.Accent else nil,
				position = UDim2.fromOffset(46, 0),
				size = UDim2.fromOffset(120, ROW_H),
			}),
			Value = e(Kit.Text, {
				text = row.value,
				textSize = 18,
				align = Enum.TextXAlignment.Right,
				position = UDim2.fromOffset(ROW_W - 14 - 90, 0),
				size = UDim2.fromOffset(90, ROW_H),
			}),
		})
	end

	return e(React.Fragment, nil, {
		Plank = e("ImageButton", {
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Image = Kit.Art.image("PlankTimer"),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -EDGE, 0, TOP),
			Size = UDim2.fromOffset(PLANK_W, PLANK_H),
			[React.Event.Activated] = props.onToggle,
		}, {
			-- Drawn at 40px with the raid strip's ink, so it weighs the same
			-- as the bot, cloud and shield beside it.
			Trophy = e(Kit.Image, {
				element = "IconTrophy40",
				size = ICON,
				anchor = Vector2.new(0, 0.5),
				position = UDim2.new(0, -12, 0.5, 0),
				zIndex = 2,
			}),
			-- Centred between the trophy's edge and the nail at the right end.
			Rank = e(Kit.Text, {
				text = `#{if props.myRank > 0 then props.myRank else "-"}`,
				textSize = 26,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(ICON - 12, 0),
				size = UDim2.fromOffset(PLANK_W - (ICON - 12) - 22, PLANK_H),
			}),
		}),
		Board = if props.open
			then e("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -EDGE, 0, TOP + PLANK_H + 8),
				Size = UDim2.fromOffset(ROW_W, TAB_H + 8 + #props.rows * ROW_STEP),
			}, {
				Tabs = e(React.Fragment, nil, tabs),
				Rows = e(React.Fragment, nil, rows),
			})
			else nil,
	})
end

return Leaderboard
