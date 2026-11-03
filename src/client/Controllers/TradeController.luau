--!strict
--[[
	TradeController

	The trade UI. Three pieces:
	- Player list (Trade button): pick someone to send a request to.
	- Request prompt: accept or decline an incoming request.
	- Trade window: your items (click to offer), your offer (click to take
	  back), their offer, and Ready / Confirm / Cancel.

	The window always shows what the server last sent. Clicking an item
	sends a whole new offer; nothing changes on screen until the server
	echoes it back in TradeUpdated, so the UI can't show a trade the server
	doesn't agree with.

	Public API: none (driven by remotes and its own buttons).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryTypes = require(ReplicatedStorage.Shared.Inventory.InventoryTypes)
local Remotes = require(ReplicatedStorage.Shared.Net.Trade)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local TradeConfig = require(ReplicatedStorage.Shared.Config.Trade)

local HudController = require(script.Parent.HudController)
local InventoryController = require(script.Parent.InventoryController)
local NotifyController = require(script.Parent.NotifyController)
local ItemText = require(script.Parent.Parent.UI.ItemText)
local Pop = require(script.Parent.Parent.UI.Pop)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local localPlayer = Players.LocalPlayer

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

local TradeController = {}

local snapshot: Snapshot? = nil

local playerListPanel: Frame
local playerList: ScrollingFrame
local requestPanel: Frame
local requestLabel: TextLabel
local pendingRequester: Player? = nil
local window: Frame
local titleLabel: TextLabel
local statusLabel: TextLabel
local myItemsList: ScrollingFrame
local myOfferList: ScrollingFrame
local theirOfferList: ScrollingFrame
local readyButton: TextButton
local confirmButton: TextButton

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

local function addItemButton(list: ScrollingFrame, text: string, color: Color3, order: number, onClick: (() -> ())?)
	local button = Widgets.button(text, onClick or function() end, {
		TextColor3 = color,
		Size = UDim2.new(1, -8, 0, 34),
		LayoutOrder = order,
		AutoButtonColor = onClick ~= nil,
	})
	button.Parent = list
end

-- Lists an offer. Your own offer's items are buttons that take one back.
local function renderOffer(list: ScrollingFrame, offer: InventoryTypes.OfferDescription, canRemove: boolean)
	Widgets.clear(list)

	local order = 0
	for _, itemId in ItemText.sortedStackIds(offer.stacks) do
		order += 1
		local takeBack = function()
			local offerNow = currentOffer()
			local remaining = (offerNow.stacks[itemId] or 0) - 1
			offerNow.stacks[itemId] = if remaining > 0 then remaining else nil
			sendOffer(offerNow)
		end
		local text = ItemText.stackLine(itemId, offer.stacks[itemId])
		addItemButton(list, text, ItemText.color(itemId), order, if canRemove then takeBack else nil)
	end

	for guid, itemId in offer.uniques do
		order += 1
		local takeBack = function()
			local offerNow = currentOffer()
			offerNow.uniques[guid] = nil
			sendOffer(offerNow)
		end
		addItemButton(list, ItemText.name(itemId), ItemText.color(itemId), order, if canRemove then takeBack else nil)
	end
end

-- Items you hold that aren't already offered, each click offering one more.
local function renderMyItems()
	Widgets.clear(myItemsList)
	if not snapshot then
		return
	end

	local inventory = InventoryController.getInventory()
	local offered = snapshot.yourOffer
	local order = 0
	for _, itemId in ItemText.sortedStackIds(inventory.stacks) do
		local available = inventory.stacks[itemId] - (offered.stacks[itemId] or 0)
		if available > 0 then
			order += 1
			addItemButton(myItemsList, ItemText.stackLine(itemId, available), ItemText.color(itemId), order, function()
				local offerNow = currentOffer()
				offerNow.stacks[itemId] = (offerNow.stacks[itemId] or 0) + 1
				sendOffer(offerNow)
			end)
		end
	end
	for guid, item in inventory.uniques do
		if offered.uniques[guid] == nil then
			order += 1
			addItemButton(myItemsList, ItemText.name(item.itemId), ItemText.color(item.itemId), order, function()
				local offerNow = currentOffer()
				offerNow.uniques[guid] = true
				sendOffer(offerNow)
			end)
		end
	end
end

local function statusText(state: Snapshot): string
	if state.phase == "Countdown" then
		return `Both ready... {math.ceil(state.countdownSeconds)}`
	elseif state.phase == "Confirm" then
		if state.youConfirmed then
			return "Waiting for them to confirm"
		end
		return "Check both offers, then Confirm"
	end

	local theirs = if state.theyReady then "They're ready." else "They're not ready."
	return `{theirs} Click items to offer them.`
end

local function render()
	local state = snapshot
	if not state then
		window.Visible = false
		return
	end
	Pop.show(window)

	titleLabel.Text = `Trading with {state.partnerName}`
	statusLabel.Text = statusText(state)
	readyButton.Text = if state.youReady then "Unready" else "Ready"
	readyButton.BackgroundColor3 = if state.youReady then Theme.Colors.Good else Theme.Colors.PanelLight
	confirmButton.Visible = state.phase == "Confirm" and not state.youConfirmed

	renderMyItems()
	renderOffer(myOfferList, state.yourOffer, true)
	renderOffer(theirOfferList, state.theirOffer, false)
end

local function renderPlayerList()
	Widgets.clear(playerList)
	local order = 0
	for _, player in Players:GetPlayers() do
		if player ~= localPlayer then
			order += 1
			local button = Widgets.button(`Trade {player.DisplayName}`, function()
				Remotes.RequestTrade:FireServer(player)
				NotifyController.show(`Trade request sent to {player.DisplayName}`)
				playerListPanel.Visible = false
			end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = order })
			button.Parent = playerList
		end
	end

	if order == 0 then
		local empty = Widgets.label("Nobody else is here yet.", { TextColor3 = Theme.Colors.TextDim })
		empty.Parent = playerList
	end
end

local function column(parent: Instance, heading: string, order: number): ScrollingFrame
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1 / 3, -6, 1, 0)
	holder.LayoutOrder = order
	holder.Parent = parent

	local label = Widgets.label(heading, { Font = Theme.Font, Size = UDim2.new(1, 0, 0, 26) })
	label.Parent = holder

	local list = Widgets.scrollList({
		Position = UDim2.new(0, 0, 0, 30),
		Size = UDim2.new(1, 0, 1, -30),
	})
	list.Parent = holder

	return list
end

local function buildWindow(screen: ScreenGui)
	window = Widgets.panel({
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.75),
	})
	window.Parent = screen
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(900, 600)
	sizeLimit.Parent = window

	titleLabel = Widgets.label("Trading", { Font = Theme.Font, Size = UDim2.new(1, 0, 0, 30) })
	titleLabel.Parent = window

	local columns = Instance.new("Frame")
	columns.BackgroundTransparency = 1
	columns.Position = UDim2.new(0, 0, 0, 36)
	columns.Size = UDim2.new(1, 0, 1, -36 - 90)
	columns.Parent = window
	Widgets.list(columns, Enum.FillDirection.Horizontal, 8)

	myItemsList = column(columns, "Your items", 1)
	myOfferList = column(columns, "Your offer", 2)
	theirOfferList = column(columns, "Their offer", 3)

	statusLabel = Widgets.label("", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -50),
		TextColor3 = Theme.Colors.Accent,
	})
	statusLabel.Parent = window

	local buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(0, 1)
	buttons.Position = UDim2.new(0, 0, 1, 0)
	buttons.Size = UDim2.new(1, 0, 0, 44)
	buttons.Parent = window
	Widgets.list(buttons, Enum.FillDirection.Horizontal, 8)

	readyButton = Widgets.button("Ready", function()
		Remotes.SetReady:FireServer(not (snapshot and snapshot.youReady))
	end, { Size = UDim2.new(1 / 3, -6, 1, 0), LayoutOrder = 1 })
	readyButton.Parent = buttons

	confirmButton = Widgets.button("Confirm", function()
		Remotes.Confirm:FireServer()
	end, { Size = UDim2.new(1 / 3, -6, 1, 0), LayoutOrder = 2, BackgroundColor3 = Theme.Colors.Good })
	confirmButton.Parent = buttons

	local cancelButton = Widgets.button("Cancel", function()
		Remotes.Cancel:FireServer()
	end, { Size = UDim2.new(1 / 3, -6, 1, 0), LayoutOrder = 3, BackgroundColor3 = Theme.Colors.Bad })
	cancelButton.Parent = buttons
end

local function buildPlayerList(screen: ScreenGui)
	playerListPanel = Widgets.panel({
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.4, 0.5),
	})
	playerListPanel.Parent = screen
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(260, 220)
	sizeLimit.MaxSize = Vector2.new(420, 480)
	sizeLimit.Parent = playerListPanel

	local title = Widgets.label("Trade with...", { Font = Theme.Font, Size = UDim2.new(1, -50, 0, 30) })
	title.Parent = playerListPanel

	local close = Widgets.button("X", function()
		playerListPanel.Visible = false
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 40, 0, 30) })
	close.Parent = playerListPanel

	playerList = Widgets.scrollList({ Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(1, 0, 1, -38) })
	playerList.Parent = playerListPanel
end

local function buildRequestPrompt(screen: ScreenGui)
	requestPanel = Widgets.panel({
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.new(0, 320, 0, 110),
	})
	requestPanel.Parent = screen

	requestLabel = Widgets.label("", { Size = UDim2.new(1, 0, 0, 40) })
	requestLabel.Parent = requestPanel

	local function respond(accept: boolean)
		if pendingRequester then
			Remotes.RespondTrade:FireServer(pendingRequester, accept)
		end
		pendingRequester = nil
		requestPanel.Visible = false
	end

	local accept = Widgets.button("Accept", function()
		respond(true)
	end, {
		Position = UDim2.new(0, 0, 1, -44),
		Size = UDim2.new(0.5, -4, 0, 44),
		BackgroundColor3 = Theme.Colors.Good,
	})
	accept.Parent = requestPanel

	local decline = Widgets.button("Decline", function()
		respond(false)
	end, {
		Position = UDim2.new(0.5, 4, 1, -44),
		Size = UDim2.new(0.5, -4, 0, 44),
		BackgroundColor3 = Theme.Colors.Bad,
	})
	decline.Parent = requestPanel
end

function TradeController.init()
	local screen = Widgets.screen("Trade")
	buildWindow(screen)
	buildPlayerList(screen)
	buildRequestPrompt(screen)
end

function TradeController.start()
	Remotes.TradeRequested.OnClientEvent:Connect(function(fromPlayer: Player)
		if typeof(fromPlayer) ~= "Instance" or snapshot then
			return
		end
		pendingRequester = fromPlayer
		requestLabel.Text = `{fromPlayer.DisplayName} wants to trade`
		requestPanel.Visible = true

		task.delay(TradeConfig.REQUEST_TIMEOUT, function()
			if pendingRequester == fromPlayer then
				pendingRequester = nil
				requestPanel.Visible = false
			end
		end)
	end)

	Remotes.TradeUpdated.OnClientEvent:Connect(function(newSnapshot: Snapshot)
		snapshot = newSnapshot
		playerListPanel.Visible = false
		requestPanel.Visible = false
		render()
	end)

	Remotes.TradeEnded.OnClientEvent:Connect(function(reason: string)
		snapshot = nil
		render()
		local color = if reason == "Completed" then Theme.Colors.Good else Theme.Colors.Warning
		NotifyController.show(END_MESSAGES[reason] or "Trade ended", color)
	end)

	InventoryController.changed:connect(function()
		if snapshot then
			renderMyItems()
		end
	end)

	-- Keep the countdown number ticking between server updates.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local state = snapshot
			if state and state.phase == "Countdown" then
				state.countdownSeconds = math.max(0, state.countdownSeconds - 0.25)
				statusLabel.Text = statusText(state)
			end
		end
	end)

	HudController.addButton("Trade", 2, function()
		renderPlayerList()
		playerListPanel.Visible = not playerListPanel.Visible
	end)
end

return TradeController
