--!strict
--[[
	TradeSession

	One trade between two players, as a small state machine, plus the
	atomic swap that ends it. TradeService handles players, remotes and
	timers; this module only holds the rules.

	Phases:
		Open       players edit offers and toggle ready
		Countdown  both are ready; a short countdown runs
		Confirm    the countdown finished; both must press confirm

	Any offer change, by either side, drops both players back to Open with
	ready and confirm cleared. That stops the classic scam of swapping a
	rare item for a common one right before the other player clicks accept.

	Public API:
		TradeSession.new(playerA, playerB): Session
		TradeSession.partnerOf(session, player): any?
		TradeSession.setOffer(session, player, offer): reason?
		TradeSession.setReady(session, player, isReady, now): reason?
		TradeSession.advance(session, now): boolean   -- true if the phase changed
		TradeSession.confirm(session, player): (reason?, bothConfirmed)
		TradeSession.swap(inventoryA, inventoryB, offerA, offerB): (ok, reason?)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryTypes = require(ReplicatedStorage.Shared.Inventory.InventoryTypes)
local TradeConfig = require(ReplicatedStorage.Shared.Config.Trade)

local InventoryRules = require(script.Parent.Parent.Inventory.InventoryRules)

type Offer = InventoryTypes.Offer
type Inventory = InventoryTypes.Inventory

export type Phase = "Open" | "Countdown" | "Confirm"

-- Players are `any` so specs can use plain strings for them.
export type Session = {
	players: { any },
	offers: { [any]: Offer },
	ready: { [any]: boolean },
	confirmed: { [any]: boolean },
	phase: Phase,
	countdownEndsAt: number,
}

local TradeSession = {}

local function isMember(session: Session, player: any): boolean
	return session.players[1] == player or session.players[2] == player
end

local function resetAgreement(session: Session)
	session.phase = "Open"
	session.countdownEndsAt = 0
	for _, player in session.players do
		session.ready[player] = false
		session.confirmed[player] = false
	end
end

function TradeSession.new(playerA: any, playerB: any): Session
	local session: Session = {
		players = { playerA, playerB },
		offers = {
			[playerA] = InventoryRules.emptyOffer(),
			[playerB] = InventoryRules.emptyOffer(),
		},
		ready = {},
		confirmed = {},
		phase = "Open",
		countdownEndsAt = 0,
	}
	resetAgreement(session)

	return session
end

function TradeSession.partnerOf(session: Session, player: any): any?
	if session.players[1] == player then
		return session.players[2]
	elseif session.players[2] == player then
		return session.players[1]
	end

	return nil
end

function TradeSession.setOffer(session: Session, player: any, offer: Offer): string?
	if not isMember(session, player) then
		return "NotInTrade"
	end

	session.offers[player] = offer
	-- SECURITY: any change resets both sides' ready and confirm, so neither
	-- player can be tricked into accepting an offer they didn't see.
	resetAgreement(session)

	return nil
end

function TradeSession.setReady(session: Session, player: any, isReady: boolean, now: number): string?
	if not isMember(session, player) then
		return "NotInTrade"
	end
	if session.phase == "Confirm" then
		return "AlreadyConfirming"
	end

	session.ready[player] = isReady
	if not isReady then
		resetAgreement(session)
		return nil
	end

	local partner = TradeSession.partnerOf(session, player)
	if session.ready[partner] then
		session.phase = "Countdown"
		session.countdownEndsAt = now + TradeConfig.COUNTDOWN_SECONDS
	end

	return nil
end

function TradeSession.advance(session: Session, now: number): boolean
	if session.phase == "Countdown" and now >= session.countdownEndsAt then
		session.phase = "Confirm"
		return true
	end

	return false
end

function TradeSession.confirm(session: Session, player: any): (string?, boolean)
	if not isMember(session, player) then
		return "NotInTrade", false
	end
	if session.phase ~= "Confirm" then
		return "NotConfirming", false
	end

	session.confirmed[player] = true
	local partner = TradeSession.partnerOf(session, player)

	return nil, session.confirmed[partner] == true
end

-- DUPE-SAFE: the whole swap is verify-then-move with no yields. Both
-- inventories are re-checked right before anything moves (an item may
-- have been spent or traded since it was offered). If either check fails,
-- nothing moves at all. Once both pass, the moves can't fail, so the trade
-- is all or nothing.
function TradeSession.swap(
	inventoryA: Inventory,
	inventoryB: Inventory,
	offerA: Offer,
	offerB: Offer
): (boolean, string?)
	if not InventoryRules.hasOffer(inventoryA, offerA) then
		return false, "FirstPlayerMissingItems"
	end
	if not InventoryRules.hasOffer(inventoryB, offerB) then
		return false, "SecondPlayerMissingItems"
	end
	if not InventoryRules.canReceive(inventoryB, offerA, inventoryA) then
		return false, "SecondPlayerCantReceive"
	end
	if not InventoryRules.canReceive(inventoryA, offerB, inventoryB) then
		return false, "FirstPlayerCantReceive"
	end

	InventoryRules.moveOffer(inventoryA, inventoryB, offerA)
	InventoryRules.moveOffer(inventoryB, inventoryA, offerB)

	return true, nil
end

return TradeSession
