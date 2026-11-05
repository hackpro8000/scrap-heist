--!strict
--[[
	TradeController

	The trade UI, in three pieces:
	- Player picker (Trade button, or "Trade it" in the bag): pick someone
	  to send a request to.
	- Request card, bottom right: accept or decline an incoming request
	  before its timer runs out.
	- Trade window: your offer and theirs side by side, each with a ready
	  tick (yours is the button), your bag in a strip below to offer from,
	  and Confirm / Cancel. Tapping an item in your offer takes one back.

	The window always shows what the server last sent. Tapping an item sends
	a whole new offer; nothing changes on screen until the server echoes it
	back in TradeUpdated, so the UI can't show a trade the server doesn't
	agree with.

	Public API: none (driven by remotes and its own buttons).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryTypes = require(ReplicatedStorage.Shared.Inventory.InventoryTypes)
local React = require(ReplicatedStorage.Packages.React)
local Remotes = require(ReplicatedStorage.Shared.Net.Trade)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local TradeConfig = require(ReplicatedStorage.Shared.Config.Trade)

local HudController = require(script.Parent.HudController)
local InventoryController = require(script.Parent.InventoryController)
local NotifyController = require(script.Parent.NotifyController)
local ItemText = require(script.Parent.Parent.UI.ItemText)
local Kit = require(script.Parent.Parent.UI.Kit)
local TradeScreen = require(script.Parent.Parent.UI.Screens.Trade)
local Windows = require(script.Parent.Parent.UI.Windows)

local localPlayer = Players.LocalPlayer

local PICKER = "TradePick"
local WINDOW = "Trade"

local END_MESSAGES: { [string]: string } = {
	Completed = "Trade complete!",
	Cancelled = "Trade cancelled",
	PartnerLeft = "Your trade partner left",
	Failed = "Trade failed: an item changed. Nothing was moved.",
}

type Snapshot = {
	partnerName: string,
	phase: string,
	countdownSeconds: number,
	yourOffer: InventoryTypes.OfferDescription,
	theirOffer: InventoryTypes.OfferDescription,
	youReady: boolean,
	theyReady: boolean,
	youConfirmed: boolean,
	theyConfirmed: boolean,
}

type Entry = TradeScreen.Entry

local TradeController = {}

local snapshot: Snapshot? = nil
local request: TradeScreen.Request? = nil
local requestCount = 0
local root: Kit.Root

-- The offer the server last confirmed, in the shape SetOffer expects.
local function currentOffer(): InventoryTypes.Offer
	local offer: InventoryTypes.Offer = { stacks = {}, uniques = {} }
	if snapshot then
		offer.stacks = table.clone(snapshot.yourOffer.stacks)
		for guid in snapshot.yourOffer.uniques do
			offer.uniques[guid] = true
		end
	end
	return offer
end

local function countEntries(offer: InventoryTypes.Offer): number
	local entries = 0
	for _ in offer.stacks do
		entries += 1
	end
	for _ in offer.uniques do
		entries += 1
	end
	return entries
end

local function sendOffer(offer: InventoryTypes.Offer)
	if countEntries(offer) > TradeConfig.MAX_OFFER_ENTRIES then
		NotifyController.show("That's as many items as one trade can hold", Theme.Colors.Warning)
		return
	end
	Remotes.SetOffer:FireServer(offer)
end

local function offerEntries(offer: InventoryTypes.OfferDescription): { Entry }
	local list: { Entry } = {}
	for _, itemId in ItemText.sortedStackIds(offer.stacks) do
		table.insert(list, { itemId = itemId, count = offer.stacks[itemId] })
	end
	for guid, itemId in offer.uniques do
		table.insert(list, { itemId = itemId, count = 1, guid = guid })
	end
	return list
end

-- Items you hold that aren't already offered.
local function bagEntriesFor(state: Snapshot): { Entry }
	local inventory = InventoryController.getInventory()
	local list: { Entry } = {}
	for _, itemId in ItemText.sortedStackIds(inventory.stacks) do
		local available = inventory.stacks[itemId] - (state.yourOffer.stacks[itemId] or 0)
		if available > 0 then
			table.insert(list, { itemId = itemId, count = available })
		end
	end
	for guid, item in inventory.uniques do
		if state.yourOffer.uniques[guid] == nil then
			table.insert(list, { itemId = item.itemId, count = 1, guid = guid })
		end
	end
	return list
end

local function takeBack(entry: Entry)
	local offer = currentOffer()
	if entry.guid then
		offer.uniques[entry.guid] = nil
	else
		local remaining = (offer.stacks[entry.itemId] or 0) - 1
		offer.stacks[entry.itemId] = if remaining > 0 then remaining else nil
	end
	sendOffer(offer)
end

local function offerOne(entry: Entry)
	local offer = currentOffer()
	if entry.guid then
		offer.uniques[entry.guid] = true
	else
		offer.stacks[entry.itemId] = (offer.stacks[entry.itemId] or 0) + 1
	end
	sendOffer(offer)
end

local function statusText(state: Snapshot): string
	if state.phase == "Countdown" then
		return `BOTH READY... {math.ceil(state.countdownSeconds)}`
	elseif state.phase == "Confirm" then
		if state.youConfirmed then
			return `WAITING FOR {string.upper(state.partnerName)}`
		end
		return "CHECK BOTH OFFERS, THEN CONFIRM!"
	end
	return "CHECK BOTH OFFERS! TRADES ARE FINAL."
end

local render: () -> ()

local function pickerRows(): { TradeScreen.PlayerRow }
	local rows = {}
	for _, player in Players:GetPlayers() do
		if player == localPlayer then
			continue
		end
		local stats = player:FindFirstChild("leaderstats")
		local scrap = stats and stats:FindFirstChild("Scrap")
		table.insert(rows, {
			userId = player.UserId,
			name = player.DisplayName,
			scrap = if scrap then `{(scrap :: any).Value} scrap` else "",
			onTrade = function()
				Remotes.RequestTrade:FireServer(player)
				NotifyController.show(`Trade request sent to {player.DisplayName}`)
				Windows.close(PICKER)
			end,
		})
	end
	return rows
end

local function tradeView(state: Snapshot): TradeScreen.TradeView
	return {
		partnerName = state.partnerName,
		status = statusText(state),
		mine = offerEntries(state.yourOffer),
		theirs = offerEntries(state.theirOffer),
		youReady = state.youReady,
		theyReady = state.theyReady,
		bag = bagEntriesFor(state),
		canConfirm = state.phase == "Confirm" and not state.youConfirmed,
		onTakeBack = takeBack,
		onOffer = offerOne,
		onReady = function()
			Remotes.SetReady:FireServer(not (snapshot and snapshot.youReady))
		end,
		onConfirm = function()
			Remotes.Confirm:FireServer()
		end,
		onCancel = function()
			Remotes.Cancel:FireServer()
		end,
	}
end

function render()
	root.render(React.createElement(TradeScreen, {
		players = pickerRows(),
		request = request,
		trade = if snapshot then tradeView(snapshot) else nil,
	}))
end

local function hideRequest()
	request = nil
	render()
end

local function togglePicker()
	if Windows.isOpen(PICKER) then
		Windows.close(PICKER)
	else
		render()
		Windows.open(PICKER)
	end
end

function TradeController.init()
	root = Kit.mount("Trade", 10)
	render()
end

function TradeController.start()
	Remotes.TradeRequested.OnClientEvent:Connect(function(fromPlayer: Player)
		if typeof(fromPlayer) ~= "Instance" or snapshot then
			return
		end
		requestCount += 1
		local id = requestCount
		request = {
			id = id,
			userId = fromPlayer.UserId,
			name = fromPlayer.DisplayName,
			onRespond = function(accept: boolean)
				Remotes.RespondTrade:FireServer(fromPlayer, accept)
				hideRequest()
			end,
		}
		render()
		task.delay(TradeConfig.REQUEST_TIMEOUT, function()
			if request and request.id == id then
				hideRequest()
			end
		end)
	end)

	Remotes.TradeUpdated.OnClientEvent:Connect(function(newSnapshot: Snapshot)
		snapshot = newSnapshot
		request = nil
		Windows.close(PICKER)
		render()
		Windows.open(WINDOW, true)
	end)

	Remotes.TradeEnded.OnClientEvent:Connect(function(reason: string)
		snapshot = nil
		Windows.close(WINDOW)
		render()
		local color = if reason == "Completed" then Theme.Colors.Good else Theme.Colors.Warning
		NotifyController.show(END_MESSAGES[reason] or "Trade ended", color)
	end)

	InventoryController.changed:connect(function()
		if snapshot then
			render()
		end
	end)
	InventoryController.tradeRequested:connect(function()
		render()
		Windows.open(PICKER)
	end)
	Players.PlayerAdded:Connect(render)
	Players.PlayerRemoving:Connect(function()
		task.defer(render)
	end)

	-- Keep the countdown number ticking between server updates.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local state = snapshot
			if state and state.phase == "Countdown" then
				state.countdownSeconds = math.max(0, state.countdownSeconds - 0.25)
				render()
			end
		end
	end)

	HudController.addButton("Trade", 1, togglePicker)
end

return TradeController
