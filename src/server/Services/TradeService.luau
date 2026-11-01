--!strict
--[[
	TradeService

	Player-to-player trades: request, accept, edit offers, ready up, a short
	countdown, both confirm, then one atomic swap.

	The rules (phases, resets, the swap itself) are in Trade/TradeSession.
	This service checks every request against the server's view of the
	world: both players in this server, both profiles loaded, neither
	already trading, every offered item actually owned.

	After a swap both profiles are saved straight away. Each profile is
	session-locked to this server, so no other server can load either copy
	mid-trade; saving both at once keeps the window where only one side has
	saved as short as possible (see docs/systems/inventory-trading.md).

	Public API:
		TradeService.isTrading(player): boolean
		TradeService.tradeCompleted: Signal(playerA, playerB)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local Remotes = require(ReplicatedStorage.Shared.Net.Trade)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local TradeConfig = require(ReplicatedStorage.Shared.Config.Trade)

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local InventoryRules = require(script.Parent.Parent.Inventory.InventoryRules)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)
local TradeSession = require(script.Parent.Parent.Trade.TradeSession)

local SYSTEM = "Trade"
local TRADE_RATE = 4
local OFFER_RATE = 8
-- task.delay can fire a hair early relative to os.clock; wait slightly
-- longer than the countdown so the phase always advances.
local COUNTDOWN_SLACK = 0.05

local TradeService = {}

TradeService.tradeCompleted = Signal.new()

local sessions: { [Player]: TradeSession.Session } = {}
-- requests[target][requester] = os.clock() when the request expires.
local requests: { [Player]: { [Player]: number } } = {}

local function isOnlinePlayer(value: any): boolean
	return typeof(value) == "Instance" and value:IsA("Player") and value.Parent == Players
end

function TradeService.isTrading(player: Player): boolean
	return sessions[player] ~= nil
end

local function snapshotFor(session: TradeSession.Session, player: Player): { [string]: any }?
	local partner = TradeSession.partnerOf(session, player) :: Player
	local myData = DataService.getData(player)
	local theirData = DataService.getData(partner)
	if not myData or not theirData then
		return nil
	end

	return {
		partnerName = partner.DisplayName,
		phase = session.phase,
		countdownSeconds = if session.phase == "Countdown"
			then math.max(0, session.countdownEndsAt - os.clock())
			else 0,
		yourOffer = InventoryRules.describeOffer(myData.inventory, session.offers[player]),
		theirOffer = InventoryRules.describeOffer(theirData.inventory, session.offers[partner]),
		youReady = session.ready[player],
		theyReady = session.ready[partner],
		youConfirmed = session.confirmed[player],
		theyConfirmed = session.confirmed[partner],
	}
end

local function sendUpdate(session: TradeSession.Session)
	for _, player in session.players do
		local snapshot = snapshotFor(session, player)
		if snapshot then
			Remotes.TradeUpdated:FireClient(player, snapshot)
		end
	end
end

local function endSession(session: TradeSession.Session, reason: string)
	for _, player in session.players do
		if sessions[player] == session then
			sessions[player] = nil
		end
		Remotes.TradeEnded:FireClient(player, reason)
	end
end

local function startSession(playerA: Player, playerB: Player)
	local session = TradeSession.new(playerA, playerB)
	sessions[playerA] = session
	sessions[playerB] = session
	if requests[playerA] then
		requests[playerA][playerB] = nil
	end
	if requests[playerB] then
		requests[playerB][playerA] = nil
	end

	sendUpdate(session)
end

local function logTrade(data: ProfileSchema.ProfileData, withUserId: number, gave: any, got: any)
	table.insert(data.tradeLog, 1, {
		at = os.time(),
		withUserId = withUserId,
		gave = gave,
		got = got,
	})
	while #data.tradeLog > TradeConfig.LOG_SIZE do
		table.remove(data.tradeLog)
	end
end

local function completeSession(session: TradeSession.Session)
	local playerA, playerB = session.players[1] :: Player, session.players[2] :: Player
	-- DUPE-SAFE: detach the session before swapping, so no other remote
	-- call can reach it (and, say, confirm it a second time) mid-swap.
	sessions[playerA] = nil
	sessions[playerB] = nil

	local dataA, dataB = DataService.getData(playerA), DataService.getData(playerB)
	if not dataA or not dataB then
		endSession(session, "Failed")
		return
	end

	local offerA, offerB = session.offers[playerA], session.offers[playerB]
	local describedA = InventoryRules.describeOffer(dataA.inventory, offerA)
	local describedB = InventoryRules.describeOffer(dataB.inventory, offerB)

	local ok = TradeSession.swap(dataA.inventory, dataB.inventory, offerA, offerB)
	if not ok then
		endSession(session, "Failed")
		return
	end

	logTrade(dataA, playerB.UserId, describedA, describedB)
	logTrade(dataB, playerA.UserId, describedB, describedA)
	DataService.save(playerA)
	DataService.save(playerB)
	InventoryService.notifyChanged(playerA)
	InventoryService.notifyChanged(playerB)

	endSession(session, "Completed")
	TradeService.tradeCompleted:fire(playerA, playerB)
end

local function onRequestTrade(player: Player, target: any): string?
	-- SECURITY: the target must be a real player in this server, and not
	-- the requester. Trades only happen between two loaded profiles here.
	if not isOnlinePlayer(target) or target == player then
		return "BadTarget"
	end
	if not DataService.isLoaded(player) or not DataService.isLoaded(target) then
		return "NotLoaded"
	end
	if sessions[player] or sessions[target] then
		return "Busy"
	end

	-- Both asked each other: just start.
	local theirRequests = requests[player]
	if theirRequests and (theirRequests[target] or 0) > os.clock() then
		startSession(player, target)
		return nil
	end

	requests[target] = requests[target] or {}
	requests[target][player] = os.clock() + TradeConfig.REQUEST_TIMEOUT
	Remotes.TradeRequested:FireClient(target, player)

	return nil
end

local function onRespondTrade(player: Player, requester: any, accept: any): string?
	if not isOnlinePlayer(requester) or type(accept) ~= "boolean" then
		return "BadArgument"
	end

	local pending = requests[player]
	local expiresAt = pending and pending[requester]
	if not expiresAt or expiresAt < os.clock() then
		return "NoRequest"
	end
	pending[requester] = nil

	if not accept then
		Notify.Message:FireClient(requester, `{player.DisplayName} declined your trade`)
		return nil
	end
	if sessions[player] or sessions[requester] then
		return "Busy"
	end
	if not DataService.isLoaded(player) or not DataService.isLoaded(requester) then
		return "NotLoaded"
	end

	startSession(requester, player)
	return nil
end

local function onSetOffer(player: Player, offer: any): string?
	local session = sessions[player]
	if not session then
		return "NotInTrade"
	end
	-- SECURITY: check the offer's shape, then that every item in it is
	-- really in this player's inventory right now.
	if not InventoryRules.isValidOffer(offer, TradeConfig.MAX_OFFER_ENTRIES) then
		return "BadOffer"
	end
	local inventory = InventoryService.getInventory(player)
	local cleanOffer = { stacks = table.clone(offer.stacks), uniques = table.clone(offer.uniques) }
	if not inventory or not InventoryRules.hasOffer(inventory, cleanOffer) then
		return "MissingItems"
	end

	local reason = TradeSession.setOffer(session, player, cleanOffer)
	sendUpdate(session)

	return reason
end

local function onSetReady(player: Player, isReady: any): string?
	local session = sessions[player]
	if not session then
		return "NotInTrade"
	end
	if type(isReady) ~= "boolean" then
		return "BadArgument"
	end

	local reason = TradeSession.setReady(session, player, isReady, os.clock())
	if session.phase == "Countdown" then
		local countdownEndsAt = session.countdownEndsAt
		task.delay(TradeConfig.COUNTDOWN_SECONDS + COUNTDOWN_SLACK, function()
			-- Only advance if this is still the same countdown: an offer
			-- change or un-ready in the meantime restarts it.
			if sessions[player] == session and session.countdownEndsAt == countdownEndsAt then
				if TradeSession.advance(session, os.clock()) then
					sendUpdate(session)
				end
			end
		end)
	end
	sendUpdate(session)

	return reason
end

local function onConfirm(player: Player): string?
	local session = sessions[player]
	if not session then
		return "NotInTrade"
	end

	local reason, bothConfirmed = TradeSession.confirm(session, player)
	if bothConfirmed then
		completeSession(session)
	else
		sendUpdate(session)
	end

	return reason
end

local function onCancel(player: Player): string?
	local session = sessions[player]
	if not session then
		return "NotInTrade"
	end

	endSession(session, "Cancelled")
	return nil
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if session then
		endSession(session, "PartnerLeft")
	end

	requests[player] = nil
	for _, pending in requests do
		pending[player] = nil
	end
end

function TradeService.init() end

function TradeService.start()
	RemoteGuard.listen(SYSTEM, Remotes.RequestTrade, TRADE_RATE, onRequestTrade)
	RemoteGuard.listen(SYSTEM, Remotes.RespondTrade, TRADE_RATE, onRespondTrade)
	RemoteGuard.listen(SYSTEM, Remotes.SetOffer, OFFER_RATE, onSetOffer)
	RemoteGuard.listen(SYSTEM, Remotes.SetReady, TRADE_RATE, onSetReady)
	RemoteGuard.listen(SYSTEM, Remotes.Confirm, TRADE_RATE, onConfirm)
	RemoteGuard.listen(SYSTEM, Remotes.Cancel, TRADE_RATE, onCancel)

	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return TradeService
