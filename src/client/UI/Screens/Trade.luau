--!strict
--[[
	Trade

	The trade UI, in three pieces:
	- Player picker: one row per player, each with a TRADE button.
	- Request card, bottom right: accept or decline an incoming request
	  before its timer runs out.
	- Trade window: your offer and theirs side by side, each with a ready
	  tick (yours is the button), your bag in a strip below to offer from,
	  and Confirm / Cancel. Tapping an item in your offer takes one back.

	Props: players, request, trade (see the types below) and the handlers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local TradeConfig = require(ReplicatedStorage.Shared.Config.Trade)

local Kit = require(script.Parent.Parent.Kit)

local e = React.createElement
local Art = Kit.Art

local GOLD = Theme.Colors.Accent

-- Picker
local PICK = Art.size("PanelTradePick")
local ROW = Art.size("PlayerRow")
local ROW_STEP = 68
local ROWS_SHOWN = 4
-- Trade window
local PANEL = Art.size("PanelTrade")
local OFFER_W = Art.size("PlateTradeOffer").X
local OFFER_SLOT, OFFER_GAP, OFFER_COLUMNS = 72, 10, 5
local GRID_W = OFFER_COLUMNS * OFFER_SLOT + (OFFER_COLUMNS - 1) * OFFER_GAP
local OFFER_INSET = (OFFER_W - GRID_W) / 2
-- Plates carry their shadow in their last 6px, so the next block starts
-- that much sooner to keep the gap even.
local BAG_Y = Art.BODY_Y + Art.size("PlateTradeOffer").Y - 6 + 8
local BAG_SLOT, BAG_STEP = 56, 66
local ACTION_Y = PANEL.Y - Art.MARGIN - 52
local REQUEST = Art.size("CardTradeRequest")

-- One thing on show in a slot: a stack of an item, or one unique item.
export type Entry = { itemId: string, count: number, guid: string? }

export type PlayerRow = { userId: number, name: string, scrap: string, onTrade: () -> () }

export type Request = { id: number, userId: number, name: string, onRespond: (accept: boolean) -> () }

export type TradeView = {
	partnerName: string,
	status: string,
	mine: { Entry },
	theirs: { Entry },
	youReady: boolean,
	theyReady: boolean,
	bag: { Entry },
	canConfirm: boolean,
	onTakeBack: (entry: Entry) -> (),
	onOffer: (entry: Entry) -> (),
	onReady: () -> (),
	onConfirm: () -> (),
	onCancel: () -> (),
}

export type Props = {
	players: { PlayerRow },
	request: Request?,
	trade: TradeView?,
}

local function headshot(userId: number): string
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

-- A round headshot in an inked ring. The ring is on a frame behind the
-- picture, so the picture itself carries no stroke.
local function Avatar(props: { userId: number, size: number, position: UDim2 })
	return e("Frame", {
		BackgroundColor3 = Theme.Colors.Panel,
		Position = props.position,
		Size = UDim2.fromOffset(props.size, props.size),
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Ink = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Theme.Colors.Ink,
			Thickness = Art.INK,
		}),
		Face = e("ImageLabel", {
			BackgroundTransparency = 1,
			Image = headshot(props.userId),
			Size = UDim2.fromScale(1, 1),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
	})
end

local function Picker(props: { players: { PlayerRow } })
	local rows = {}
	for index, player in props.players do
		rows[player.userId] = e(Kit.Image, {
			element = if index % 2 == 0 then "PlayerRowAlt" else "PlayerRow",
			layoutOrder = index,
		}, {
			Face = e(Avatar, { userId = player.userId, size = 42, position = UDim2.fromOffset(10, 8) }),
			Name = e(Kit.Text, {
				text = player.name,
				textSize = 20,
				position = UDim2.fromOffset(62, 9),
				size = UDim2.fromOffset(140, 24),
			}),
			Scrap = e(Kit.Text, {
				text = player.scrap,
				textSize = 14,
				kind = "note",
				position = UDim2.fromOffset(62, 33),
				size = UDim2.fromOffset(140, 18),
			}),
			Trade = e(Kit.Button, {
				element = Art.SMALL.Action,
				text = "TRADE",
				textSize = 18,
				onClick = player.onTrade,
				position = UDim2.fromOffset(ROW.X - 10 - 120, (ROW.Y - 2 - 40) / 2),
			}),
		})
	end
	if #props.players == 0 then
		rows.Empty = e(Kit.Text, {
			text = "Nobody else is here yet.",
			textSize = 17,
			kind = "note",
			align = Enum.TextXAlignment.Center,
			size = UDim2.fromOffset(ROW.X, ROW.Y),
		})
	end

	return e(Kit.Window, {
		name = "TradePick",
		panel = "PanelTradePick",
		header = "HeaderTradePick",
		title = "TRADE",
		icon = "IconTrade28",
	}, {
		Prompt = e(Kit.Text, {
			text = "Pick someone to trade with",
			textSize = 17,
			kind = "note",
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(Art.MARGIN, Art.BODY_Y),
			size = UDim2.fromOffset(PICK.X - 2 * Art.MARGIN, 22),
		}),
		List = e("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromOffset((PICK.X - ROW.X) / 2, Art.BODY_Y + 34),
			Size = UDim2.fromOffset(ROW.X, ROWS_SHOWN * ROW_STEP - (ROW_STEP - ROW.Y)),
		}, {
			Layout = e("UIListLayout", {
				Padding = UDim.new(0, ROW_STEP - ROW.Y),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Rows = e(React.Fragment, nil, rows),
		}),
	})
end

local function RequestCard(props: { request: Request })
	local request = props.request
	local timerRef = React.useRef(nil :: Frame?)
	React.useEffect(function()
		local timer = timerRef.current
		if not timer then
			return nil
		end
		timer.Size = UDim2.fromScale(1, 1)
		local tween = TweenService:Create(timer, TweenInfo.new(TradeConfig.REQUEST_TIMEOUT, Enum.EasingStyle.Linear), {
			Size = UDim2.fromScale(0, 1),
		})
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, { request.id })

	return e(Kit.Image, {
		element = "CardTradeRequest",
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -24, 1, -150),
	}, {
		Face = e(Avatar, { userId = request.userId, size = 48, position = UDim2.fromOffset(18, 16) }),
		Name = e(Kit.Text, {
			text = string.upper(request.name),
			textSize = 24,
			color = GOLD,
			position = UDim2.fromOffset(78, 16),
			size = UDim2.fromOffset(270, 26),
		}),
		Wants = e(Kit.Text, {
			text = "wants to trade with you",
			textSize = 17,
			kind = "note",
			color = Art.DARK_TEXT,
			position = UDim2.fromOffset(78, 42),
			size = UDim2.fromOffset(270, 22),
		}),
		Accept = e(Kit.Button, {
			element = Art.MEDIUM.Action,
			text = "ACCEPT",
			textSize = 21,
			onClick = function()
				request.onRespond(true)
			end,
			position = UDim2.fromOffset(18, 78),
		}),
		Decline = e(Kit.Button, {
			element = Art.MEDIUM.Danger,
			text = "DECLINE",
			textSize = 21,
			onClick = function()
				request.onRespond(false)
			end,
			position = UDim2.fromOffset(REQUEST.X - 18 - 160, 78),
		}),
		Track = e("Frame", {
			BackgroundColor3 = Theme.Colors.Ink,
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(18, 130),
			Size = UDim2.fromOffset(REQUEST.X - 36, 6),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Timer = e("Frame", {
				ref = timerRef,
				BackgroundColor3 = Theme.Colors.Warning,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
		}),
	})
end

local function OfferSide(props: {
	x: number,
	title: string,
	titleColor: Color3?,
	entries: { Entry },
	ready: boolean,
	onTap: ((entry: Entry) -> ())?,
	onReady: (() -> ())?,
})
	local slots = {}
	for index = 1, TradeConfig.MAX_OFFER_ENTRIES do
		local entry = props.entries[index]
		local column, row = (index - 1) % OFFER_COLUMNS, (index - 1) // OFFER_COLUMNS
		slots[index] = e(Kit.Slot, {
			size = OFFER_SLOT,
			itemId = entry and entry.itemId,
			count = entry and entry.count,
			faded = entry == nil,
			onClick = if props.onTap and entry
				then function()
					(props.onTap :: (Entry) -> ())(entry)
				end
				else nil,
			position = UDim2.fromOffset(
				OFFER_INSET + column * (OFFER_SLOT + OFFER_GAP),
				50 + row * (OFFER_SLOT + OFFER_GAP)
			),
		})
	end
	local readyY = 50 + 2 * OFFER_SLOT + OFFER_GAP + 12
	local tick = if props.ready then "CheckboxOn" else "Checkbox"
	return e(Kit.Image, { element = "PlateTradeOffer", position = UDim2.fromOffset(props.x, Art.BODY_Y) }, {
		Title = e(Kit.Text, {
			text = props.title,
			textSize = 22,
			color = props.titleColor,
			position = UDim2.fromOffset(OFFER_INSET, 12),
			size = UDim2.fromOffset(GRID_W, 30),
		}),
		Slots = e(React.Fragment, nil, slots),
		Tick = if props.onReady
			then e(Kit.Button, {
				element = tick,
				onClick = props.onReady,
				position = UDim2.fromOffset(OFFER_INSET, readyY),
			})
			else e(Kit.Image, { element = tick, position = UDim2.fromOffset(OFFER_INSET, readyY) }),
		Ready = e(Kit.Text, {
			text = if props.ready then "READY!" else "NOT READY",
			textSize = 20,
			color = if props.ready then Theme.Colors.Good else Theme.Colors.TextDim,
			position = UDim2.fromOffset(OFFER_INSET + 48, readyY),
			size = UDim2.fromOffset(300, 40),
		}),
	})
end

local function TradeWindow(props: { trade: TradeView })
	local trade = props.trade
	local partner = string.upper(trade.partnerName)
	local bagSize = Art.size("PlateTradeBag")

	local bag = {}
	for index, entry in trade.bag do
		bag[index] = e(Kit.Slot, {
			size = BAG_SLOT,
			itemId = entry.itemId,
			count = entry.count,
			layoutOrder = index,
			onClick = function()
				trade.onOffer(entry)
			end,
		})
	end

	return e(Kit.Window, {
		name = "Trade",
		panel = "PanelTrade",
		header = "HeaderTrade",
		title = `TRADING WITH {partner}`,
		icon = "IconTrade28",
		sticky = true,
		-- Closing the window (its X) cancels the trade.
		onClose = trade.onCancel,
	}, {
		Mine = e(OfferSide, {
			x = Art.MARGIN,
			title = "YOUR OFFER",
			entries = trade.mine,
			ready = trade.youReady,
			onTap = trade.onTakeBack,
			onReady = trade.onReady,
		}),
		Theirs = e(OfferSide, {
			x = PANEL.X - Art.MARGIN - OFFER_W,
			title = `{partner}'S OFFER`,
			titleColor = GOLD,
			entries = trade.theirs,
			ready = trade.theyReady,
		}),
		Bag = e(Kit.Image, { element = "PlateTradeBag", position = UDim2.fromOffset(Art.MARGIN, BAG_Y) }, {
			Heading = e("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(OFFER_INSET, 10),
				Size = UDim2.fromOffset(600, 24),
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				Title = e(Kit.Text, { text = "YOUR BAG", textSize = 18, fit = true, height = 24, layoutOrder = 1 }),
				Hint = e(Kit.Text, {
					text = "tap an item to offer it",
					textSize = 15,
					kind = "note",
					wrap = false,
					fit = true,
					height = 24,
					layoutOrder = 2,
				}),
			}),
			Strip = e("ScrollingFrame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 0,
				ScrollingDirection = Enum.ScrollingDirection.X,
				AutomaticCanvasSize = Enum.AutomaticSize.X,
				CanvasSize = UDim2.new(),
				Position = UDim2.fromOffset(OFFER_INSET, 40),
				Size = UDim2.fromOffset(bagSize.X - 2 * OFFER_INSET, BAG_SLOT),
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, BAG_STEP - BAG_SLOT),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Slots = e(React.Fragment, nil, bag),
			}),
		}),
		Warning = e(Kit.Image, {
			element = "PlateTradeWarning",
			position = UDim2.fromOffset(Art.MARGIN, ACTION_Y + 2),
		}, {
			-- The hazard plate's face runs 3px down to 6px above its foot.
			Status = e(Kit.Text, {
				text = trade.status,
				textSize = 19,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(0, 3),
				size = UDim2.fromOffset(Art.size("PlateTradeWarning").X, Art.size("PlateTradeWarning").Y - 9),
			}),
		}),
		Confirm = e(Kit.Button, {
			element = Art.LARGE.Action,
			text = "CONFIRM",
			textSize = 24,
			enabled = trade.canConfirm,
			onClick = trade.onConfirm,
			position = UDim2.fromOffset(PANEL.X - Art.MARGIN - 400 - Art.GAP, ACTION_Y),
		}),
		Cancel = e(Kit.Button, {
			element = Art.LARGE.Danger,
			text = "CANCEL",
			textSize = 24,
			onClick = trade.onCancel,
			position = UDim2.fromOffset(PANEL.X - Art.MARGIN - 200, ACTION_Y),
		}),
	})
end

local function Trade(props: Props)
	return e(React.Fragment, nil, {
		Picker = e(Picker, { players = props.players }),
		Request = if props.request then e(RequestCard, { request = props.request }) else nil,
		Window = if props.trade then e(TradeWindow, { trade = props.trade }) else nil,
	})
end

return Trade
