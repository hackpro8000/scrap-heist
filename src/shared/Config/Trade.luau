--!strict
--[[
	Trade config

	Timing and limits for player trades.
]]

local Trade = {}

-- Seconds both players must stay ready before they can confirm. Gives time
-- to spot a last-second change in the other offer.
Trade.COUNTDOWN_SECONDS = 3
-- Seconds a trade request stays open.
Trade.REQUEST_TIMEOUT = 30
-- Most different entries (stack types plus unique items) in one offer:
-- the trade window's offer grid, 5 by 2.
Trade.MAX_OFFER_ENTRIES = 10
-- Trades kept in each player's profile for support.
Trade.LOG_SIZE = 20

return Trade
