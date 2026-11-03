--!strict
--[[
	Trade remotes

	Client to server:
		RequestTrade(targetPlayer)
		RespondTrade(requesterPlayer, accept)
		SetOffer(offer)          -- the whole offer, every time it changes
		SetReady(isReady)
		Confirm()
		Cancel()

	Server to client:
		TradeRequested(fromPlayer)
		TradeUpdated(snapshot)   -- see TradeService.snapshotFor
		TradeEnded(reason)       -- "Completed", "Cancelled", "PartnerLeft", "Failed"
]]

local Net = require(script.Parent.Net)

local SYSTEM = "Trade"

return {
	RequestTrade = Net.event(SYSTEM, "RequestTrade"),
	RespondTrade = Net.event(SYSTEM, "RespondTrade"),
	SetOffer = Net.event(SYSTEM, "SetOffer"),
	SetReady = Net.event(SYSTEM, "SetReady"),
	Confirm = Net.event(SYSTEM, "Confirm"),
	Cancel = Net.event(SYSTEM, "Cancel"),
	TradeRequested = Net.event(SYSTEM, "TradeRequested"),
	TradeUpdated = Net.event(SYSTEM, "TradeUpdated"),
	TradeEnded = Net.event(SYSTEM, "TradeEnded"),
}
