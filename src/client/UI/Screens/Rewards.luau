--!strict
--[[
	Rewards

	The rewards window:
	- Daily streak: the seven days in a row, claimed days ticked, today's
	  glowing, and a claim button that counts down to tomorrow once used.
	- Playtime gifts: one row each, a bar filling with today's playtime and
	  a button that opens when the bar is full.

	Props: state (the server's snapshot, nil until it comes), played
	(seconds of playtime today), now (server time), onClaimDaily(),
	onClaimGift(index)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Kit = require(script.Parent.Parent.Kit)

local e = React.createElement
local Art = Kit.Art

local PANEL = Art.size("PanelRewards")
local ROW_W = PANEL.X - 2 * Art.MARGIN
local DAY_SLOT = 72
local DAY_STEP = (ROW_W - DAY_SLOT) / 6
local DAY_Y = Art.BODY_Y + 56
local GIFTS_Y = DAY_Y + DAY_SLOT + 12 + 52 + 16
local GIFT_STEP = 74
-- A gift plate's face runs from 3px down to 6px above its foot.
local GIFT_MIDDLE = 32.5
local GIFT_SLOT = 56
local MEDIUM_W, MEDIUM_H = 160, 44

export type Props = {
	state: { [string]: any }?,
	played: number,
	now: number,
	onClaimDaily: () -> (),
	onClaimGift: (index: number) -> (),
}

local function formatClock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	if whole >= 3600 then
		return string.format("%d:%02d:%02d", whole // 3600, whole // 60 % 60, whole % 60)
	end
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- A heading and its dim note, side by side on the left margin.
local function SectionHeading(props: { y: number, title: string, note: string })
	return e("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(Art.MARGIN, props.y),
		Size = UDim2.fromOffset(ROW_W, 26),
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		Title = e(Kit.Text, { text = props.title, textSize = 21, fit = true, height = 26, layoutOrder = 1 }),
		Note = e(Kit.Text, {
			text = props.note,
			textSize = 15,
			kind = "note",
			wrap = false,
			fit = true,
			height = 26,
			layoutOrder = 2,
		}),
	})
end

local function Gift(props: { index: number, played: number, claimed: boolean, onClaim: () -> () })
	local gift = Rewards.GIFTS[props.index]
	local needed = gift.minutes * 60
	local ready = props.played >= needed
	local buttonX = ROW_W - 14 - MEDIUM_W
	return e(Kit.Image, {
		element = "PlateGift",
		position = UDim2.fromOffset(Art.MARGIN, GIFTS_Y + 34 + (props.index - 1) * GIFT_STEP),
	}, {
		Slot = e(Kit.Slot, {
			size = GIFT_SLOT,
			itemId = gift.itemId,
			count = gift.count,
			position = UDim2.fromOffset(12, GIFT_MIDDLE - GIFT_SLOT / 2),
		}),
		Label = e(Kit.Text, {
			text = `PLAY {gift.minutes} MIN`,
			textSize = 19,
			kind = "dark",
			position = UDim2.fromOffset(80, GIFT_MIDDLE - 26),
			size = UDim2.fromOffset(280, 24),
		}),
		Bar = e(Kit.Bar, {
			name = "Gift",
			fraction = props.played / needed,
			position = UDim2.fromOffset(80, GIFT_MIDDLE + 2),
		}),
		Claim = if props.claimed
			then e(Kit.Text, {
				text = "CLAIMED",
				textSize = 20,
				color = Theme.Colors.Good,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(buttonX, GIFT_MIDDLE - MEDIUM_H / 2),
				size = UDim2.fromOffset(MEDIUM_W, MEDIUM_H),
			})
			else e(Kit.Button, {
				element = Art.MEDIUM.Action,
				text = if ready then "CLAIM" else formatClock(needed - props.played),
				textSize = 20,
				enabled = ready,
				onClick = props.onClaim,
				position = UDim2.fromOffset(buttonX, GIFT_MIDDLE - MEDIUM_H / 2),
			}),
	})
end

local function Rewards_(props: Props)
	local state = props.state
	local children: { [string]: any } = {}
	if state then
		local daily = state.daily
		children.DailyHeading = e(SectionHeading, {
			y = Art.BODY_Y,
			title = "DAILY STREAK",
			note = `day {daily.day} of {#Rewards.DAILY}`,
		})
		for index, reward in Rewards.DAILY do
			local x = Art.MARGIN + (index - 1) * DAY_STEP
			local claimed = index <= daily.claimed
			children[`Day{index}`] = e(React.Fragment, nil, {
				Label = e(Kit.Text, {
					text = `DAY {index}`,
					textSize = 15,
					color = if claimed then Theme.Colors.TextDim else Theme.Colors.Text,
					align = Enum.TextXAlignment.Center,
					position = UDim2.fromOffset(x - 6, DAY_Y - 26),
					size = UDim2.fromOffset(DAY_SLOT + 12, 20),
				}),
				Slot = e(Kit.Slot, {
					size = DAY_SLOT,
					itemId = reward.itemId,
					count = reward.count,
					rarity = "Common",
					countText = if reward.scrap then tostring(reward.scrap) else nil,
					faded = claimed,
					glow = daily.claimable and index == daily.day,
					position = UDim2.fromOffset(x, DAY_Y),
				}),
				-- Scrap days show the bolt in the well, the amount in the corner.
				Bolt = if reward.scrap
					then e(Kit.Image, {
						element = "IconScrap",
						size = DAY_SLOT * 0.72,
						position = UDim2.fromOffset(x + DAY_SLOT * 0.14, DAY_Y + DAY_SLOT * 0.1),
						transparency = if claimed then 0.5 else 0,
						zIndex = 2,
					})
					else nil,
				Tick = if claimed
					then e(Kit.Image, {
						element = "TickBadge",
						position = UDim2.fromOffset(x + DAY_SLOT - 24, DAY_Y - 6),
						zIndex = 6,
					})
					else nil,
			})
		end
		children.Claim = e(Kit.Button, {
			element = Art.LARGE.Action,
			text = if daily.claimable
				then `CLAIM DAY {daily.day}`
				else `NEXT IN {formatClock(state.nextDayAt - props.now)}`,
			textSize = 22,
			enabled = daily.claimable,
			onClick = props.onClaimDaily,
			position = UDim2.fromOffset((PANEL.X - 200) / 2, DAY_Y + DAY_SLOT + 12),
		})
		children.GiftsHeading = e(SectionHeading, { y = GIFTS_Y, title = "PLAYTIME GIFTS", note = "resets daily" })
		for index in Rewards.GIFTS do
			children[`Gift{index}`] = e(Gift, {
				index = index,
				played = props.played,
				claimed = state.giftsClaimed[index] == true,
				onClaim = function()
					props.onClaimGift(index)
				end,
			})
		end
	end

	return e(Kit.Window, {
		name = "Rewards",
		panel = "PanelRewards",
		header = "HeaderResults",
		title = "REWARDS",
		icon = "IconRewards28",
	}, children)
end

return Rewards_
